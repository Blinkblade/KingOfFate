"""Read a MUGEN/IKEMEN SND sound container.

Format (ported from the engine's ``src/sound.go``: ``LoadSndFiltered`` and
``readSound``):

    header        12 bytes  "ElecbyteSnd\\x00"
                  uint16    ver
                  uint16    ver2
                  uint32    numberOfSounds
                  uint32    subHeaderOffset
    sub-header    uint32    nextSubHeaderOffset      (0 = last)
                  uint32    subFileLength
                  int32     group
                  int32     sound
                  bytes     subFileLength bytes of a plain WAV file

Every entry is a complete WAV, so the sample rate and duration can be read
straight out of its ``fmt `` and ``data`` chunks without decoding audio. The
engine decodes each entry once on load to reject broken ones; we do not need
that, because the question this library answers is "what is in the bank and
can we map our hits onto it".

Read-only. No writer: nothing in P6 needs to *write* an SND yet (the remap
plan keeps the source bank and only renumbers the references in the script).
"""

from __future__ import annotations

import os
import struct

HEADER_MAGIC = b"ElecbyteSnd\x00"
HEADER_SIZE = 12 + 2 + 2 + 4 + 4   # magic, ver, ver2, count, sub-header offset
WAV_FORMAT_PCM = 1
WAV_FORMAT_MS_ADPCM = 2
WAV_FORMAT_IMA_ADPCM = 0x11

_FORMAT_NAMES = {
    WAV_FORMAT_PCM: "pcm",
    WAV_FORMAT_MS_ADPCM: "ms-adpcm",
    WAV_FORMAT_IMA_ADPCM: "ima-adpcm",
}

# A sub-header that claims to be longer than this is treated as corrupt: the
# largest entry in any real bank is a few hundred KB.
_MAX_ENTRY_BYTES = 16 * 1024 * 1024


class SndError(Exception):
    """Base class for SND problems."""


class SndFormatError(SndError):
    """The file is not an SND container at all."""


class SndCorruptError(SndError):
    """The file starts like an SND but its structure does not hold up."""


class SoundEntry:
    __slots__ = ("group", "number", "index", "offset", "length", "wav",
                 "sample_rate", "channels", "bits", "format_tag", "duration",
                 "wav_error")

    def __init__(self, group, number, index, offset, length, wav):
        self.group = group
        self.number = number
        self.index = index
        self.offset = offset
        self.length = length
        self.wav = wav
        self.sample_rate = 0
        self.channels = 0
        self.bits = 0
        self.format_tag = 0
        self.duration = 0.0
        self.wav_error = None

    @property
    def key(self):
        return (self.group, self.number)

    @property
    def format_name(self):
        return _FORMAT_NAMES.get(self.format_tag,
                                 "0x%04x" % self.format_tag)

    def __repr__(self):                                          # pragma: no cover
        return "SoundEntry(%d,%d,%d bytes)" % (self.group, self.number,
                                               self.length)


def _read_wav_header(data):
    """Return (format_tag, channels, sample_rate, bits, seconds) or raise."""
    if len(data) < 44:
        raise SndCorruptError("wav shorter than 44 bytes")
    if data[0:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise SndCorruptError("not a RIFF/WAVE payload")
    pos = 12
    fmt = None
    data_size = None
    while pos + 8 <= len(data):
        tag = data[pos:pos + 4]
        (size,) = struct.unpack_from("<I", data, pos + 4)
        body = pos + 8
        if tag == b"fmt " and body + 16 <= len(data):
            (format_tag, channels, sample_rate, _byte_rate, _align,
             bits) = struct.unpack_from("<HHIIHH", data, body)
            fmt = (format_tag, channels, sample_rate, bits)
        elif tag == b"data":
            data_size = size
            break
        pos = body + size + (size & 1)
    if fmt is None:
        raise SndCorruptError("no fmt chunk")
    format_tag, channels, sample_rate, bits = fmt
    seconds = 0.0
    if data_size and sample_rate and channels:
        seconds = data_size / float(sample_rate * channels * max(bits // 8, 1))
    return format_tag, channels, sample_rate, bits, seconds


def load(path):
    """Parse an SND file into a list of SoundEntry (read-only)."""
    if not os.path.exists(path):
        raise SndError("no such file: %s" % path)
    if os.path.isdir(path):
        raise SndError("%s is a directory, expected an .snd file" % path)

    with open(path, "rb") as handle:
        blob = handle.read()

    # 12 magic + 2 ver + 2 ver2 + 4 count + 4 subHeaderOffset
    if len(blob) < HEADER_SIZE:
        raise SndFormatError(
            "file is too small to be an SND container (%d bytes, need at least "
            "%d)" % (len(blob), HEADER_SIZE))
    if not blob.startswith(HEADER_MAGIC):
        raise SndFormatError("bad SND header (expected 'ElecbyteSnd')")

    ver, ver2, count, sub_offset = struct.unpack_from("<HHII", blob, 12)
    entries = []
    seen = set()
    offset = sub_offset
    for index in range(count):
        if offset == 0 or offset + 16 > len(blob):
            raise SndCorruptError(
                "sub-header %d (of %d) points outside the file at 0x%X"
                % (index, count, offset))
        next_offset, length, group, number = struct.unpack_from("<IIii", blob,
                                                                offset)
        if length > _MAX_ENTRY_BYTES:
            raise SndCorruptError(
                "sub-header %d declares %d bytes, refusing to trust it"
                % (index, length))
        start = offset + 16
        if start + length > len(blob):
            raise SndCorruptError(
                "sub-header %d runs past the end of the file "
                "(%d + %d > %d)" % (index, start, length, len(blob)))
        wav = blob[start:start + length]
        entry = SoundEntry(group, number, index, start, length, wav)
        try:
            (entry.format_tag, entry.channels, entry.sample_rate, entry.bits,
             entry.duration) = _read_wav_header(wav)
        except SndCorruptError as exc:
            entry.wav_error = str(exc)
        if entry.key in seen:
            entry.wav_error = (entry.wav_error + "; " if entry.wav_error else "") \
                + "duplicate key"
        seen.add(entry.key)
        entries.append(entry)
        offset = next_offset
        if offset == 0:
            break
        if index + 1 < count and offset >= len(blob):
            raise SndCorruptError("sub-header chain leaves the file early")

    container = Snd()
    container.path = path
    container.ver = ver
    container.ver2 = ver2
    container.declared_count = count
    container.entries = entries
    container.size = len(blob)
    return container


class Snd:
    """A parsed SND container."""

    def __init__(self):
        self.path = ""
        self.ver = 0
        self.ver2 = 0
        self.declared_count = 0
        self.entries = []
        self.size = 0

    def entry(self, group, number):
        for item in self.entries:
            if item.key == (group, number):
                return item
        return None

    def total_seconds(self):
        return sum(e.duration for e in self.entries)

    def formats(self):
        seen = {}
        for item in self.entries:
            seen[item.format_name] = seen.get(item.format_name, 0) + 1
        return seen

    def problems(self):
        return [e for e in self.entries if e.wav_error]
