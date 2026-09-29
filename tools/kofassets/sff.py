"""SFF v2 reader (read-only).

What is supported
-----------------
SFF **v2** containers -- the format every character in this repository actually
uses (`game/chars/_template/_template.sff`, `test_fighter_a.sff`,
`test_fighter_b.sff` and the P1 lab `kfm.sff` are all `2.0.1.0` with 282 sprites
and 16 palettes).

Per-sprite image formats:

    2   RLE8          palette indices, RLE8 compressed
    3   RLE5          palette indices, RLE5 compressed
    4   LZ5           palette indices, LZ5 compressed   <- 280/282 sprites here
    10  PNG palette   PNG whose *indices* are used, palette comes from the SFF
                                                        <- 2/282 sprites here
    11  PNG RGBA      PNG, 8-bit RGBA, used as-is
    12  PNG RGBA      PNG, 8-bit RGBA, used as-is
    0   raw           only colour depth 8 (palette indices)

What is deliberately *not* supported (and is reported as such, never guessed at)
------------------------------------------------------------------------------
    SFF v1                      -- detected, then refused with a clear message
    format 0 with depth 24/32   -- raw true-colour; no asset here uses it and its
                                   byte order cannot be verified from the project's
                                   own data, so the tool refuses rather than lie
    interlaced PNG inside an SFF

Algorithms are ports of ``engine/ikemen-go/src/image.go`` (``SffHeader.Read``,
``readHeaderV2``, ``readV2``, ``Rle8Decode``, ``Rle5Decode``, ``Lz5Decode``,
``loadPalettes``, ``ReadPalette``), with the difference that every decoders keep
their bounds checks and raise instead of panicking.
"""

from __future__ import annotations

import os
import struct

from . import pngio

SIGNATURE = b"ElecbyteSpr\x00"

# SFF v2 per-sprite formats we can decode.
FMT_RLE8 = 2
FMT_RLE5 = 3
FMT_LZ5 = 4
FMT_PNG_PALETTE = 10
FMT_PNG_RGBA = 11
FMT_PNG_RGBA2 = 12
FMT_RAW = 0

FORMAT_NAMES = {
    FMT_RLE8: "rle8",
    FMT_RLE5: "rle5",
    FMT_LZ5: "lz5",
    FMT_PNG_PALETTE: "png-palette",
    FMT_PNG_RGBA: "png-rgba",
    FMT_PNG_RGBA2: "png-rgba",
    FMT_RAW: "raw",
}

DEPTH_NAMES = {5: "5 (compressed 8-bit index)", 8: "8 (index)", 24: "24 (RGB)", 32: "32 (RGBA)"}

# Guard so a corrupt stream can never spin forever (see report rules: no hangs).
_DECODE_ITERATION_BUDGET = 64 * 1024 * 1024


class SffError(Exception):
    """Base class for anything this reader refuses to accept."""


class SffFormatError(SffError):
    """The file is not an SFF at all (bad signature, too short, ...)."""


class SffUnsupportedError(SffError):
    """A valid SFF that P5 tooling deliberately does not support."""


class SffCorruptError(SffError):
    """The file looks like an SFF v2 but the data inside it is broken."""


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------


class Sprite:
    __slots__ = (
        "index", "group", "number", "width", "height", "axis_x", "axis_y",
        "link", "format", "coldepth", "data_offset", "data_size", "pal_index",
        "flags", "linked_source_index", "warnings",
    )

    def __init__(self, index, group, number, width, height, axis_x, axis_y, link,
                 fmt, coldepth, data_offset, data_size, pal_index, flags):
        self.index = index
        self.group = group
        self.number = number
        self.width = width
        self.height = height
        self.axis_x = axis_x
        self.axis_y = axis_y
        self.link = link
        self.format = fmt
        self.coldepth = coldepth
        self.data_offset = data_offset
        self.data_size = data_size
        self.pal_index = pal_index
        self.flags = flags
        self.linked_source_index = None
        self.warnings = []

    @property
    def key(self):
        return (self.group, self.number)

    @property
    def format_name(self):
        return FORMAT_NAMES.get(self.format, "format-%d" % self.format)

    @property
    def is_linked(self):
        return self.data_size == 0

    def to_dict(self):
        return {
            "index": self.index,
            "group": self.group,
            "image": self.number,
            "width": self.width,
            "height": self.height,
            "axis_x": self.axis_x,
            "axis_y": self.axis_y,
            "format": self.format_name,
            "colour_depth": self.coldepth,
            "data_offset": self.data_offset,
            "data_size": self.data_size,
            "palette_index": self.pal_index,
            "linked_to_index": self.linked_source_index,
            "link_field": self.link,
            "flags": self.flags,
        }


class Palette:
    __slots__ = ("index", "group", "number", "declared_colours", "link",
                 "data_offset", "data_size", "colours", "source_index", "warnings")

    def __init__(self, index, group, number, declared_colours, link, data_offset, data_size):
        self.index = index
        self.group = group
        self.number = number
        self.declared_colours = declared_colours
        self.link = link
        self.data_offset = data_offset
        self.data_size = data_size
        self.colours = []          # list of (r, g, b, a)
        self.source_index = index  # which palette index actually holds the data
        self.warnings = []

    def to_dict(self):
        return {
            "index": self.index,
            "group": self.group,
            "number": self.number,
            "declared_colours": self.declared_colours,
            "colours": len(self.colours),
            "shares_with_index": self.source_index,
            "data_offset": self.data_offset,
            "data_size": self.data_size,
        }


# ---------------------------------------------------------------------------
# Decoders (ports of the engine's, with bounds checks)
# ---------------------------------------------------------------------------


def _need(buf, i, what):
    if i >= len(buf):
        raise SffCorruptError("%s ran out of compressed data at byte %d of %d"
                              % (what, i, len(buf)))


def rle8_decode(rle: bytes, pixel_count: int) -> bytes:
    out = bytearray(pixel_count)
    i = j = 0
    budget = _DECODE_ITERATION_BUDGET
    while j < pixel_count:
        budget -= 1
        if budget <= 0:
            raise SffCorruptError("rle8 decoder exceeded its iteration budget")
        _need(rle, i, "rle8")
        run = 1
        value = rle[i]
        if i < len(rle) - 1:
            i += 1
        if value & 0xC0 == 0x40:
            run = value & 0x3F
            _need(rle, i, "rle8")
            value = rle[i]
            if i < len(rle) - 1:
                i += 1
        while run > 0:
            if j < pixel_count:
                out[j] = value
                j += 1
            run -= 1
    return bytes(out)


def rle5_decode(rle: bytes, pixel_count: int) -> bytes:
    out = bytearray(pixel_count)
    i = j = 0
    budget = _DECODE_ITERATION_BUDGET
    while j < pixel_count:
        budget -= 1
        if budget <= 0:
            raise SffCorruptError("rle5 decoder exceeded its iteration budget")
        _need(rle, i, "rle5")
        rl = rle[i]
        if i < len(rle) - 1:
            i += 1
        _need(rle, i, "rle5")
        dl = rle[i] & 0x7F
        colour = 0
        if rle[i] >> 7 != 0:
            if i < len(rle) - 1:
                i += 1
            _need(rle, i, "rle5")
            colour = rle[i]
        if i < len(rle) - 1:
            i += 1
        while True:
            budget -= 1
            if budget <= 0:
                raise SffCorruptError("rle5 decoder exceeded its iteration budget")
            if j < pixel_count:
                out[j] = colour
                j += 1
            rl -= 1
            if rl < 0:
                dl -= 1
                if dl < 0:
                    break
                _need(rle, i, "rle5")
                colour = rle[i] & 0x1F
                rl = rle[i] >> 5
                if i < len(rle) - 1:
                    i += 1
    return bytes(out)


def lz5_decode(rle: bytes, pixel_count: int) -> bytes:
    """Port of ``Sprite.Lz5Decode``.

    Note ``d & 0xc0 >> rbc`` in the Go source: in Go ``&`` and ``>>`` share the
    same precedence level and associate left to right, so it means
    ``(d & 0xc0) >> rbc``. That is reproduced here.
    """
    if not rle:
        return bytes(pixel_count)

    out = bytearray(pixel_count)
    i = j = 0
    n = 0
    control = rle[0]
    control_shift = 0
    back = 0
    back_bits = 0
    if i < len(rle) - 1:
        i += 1

    budget = _DECODE_ITERATION_BUDGET
    while j < pixel_count:
        budget -= 1
        if budget <= 0:
            raise SffCorruptError("lz5 decoder exceeded its iteration budget")
        _need(rle, i, "lz5")
        d = rle[i]
        if i < len(rle) - 1:
            i += 1

        if control & (1 << control_shift) != 0:
            # Back-reference (copy already produced pixels).
            if d & 0x3F == 0:
                _need(rle, i, "lz5")
                d = ((d << 2) | rle[i]) + 1
                if i < len(rle) - 1:
                    i += 1
                _need(rle, i, "lz5")
                n = rle[i] + 2
                if i < len(rle) - 1:
                    i += 1
            else:
                back |= ((d & 0xC0) >> back_bits) & 0xFF
                back_bits += 2
                n = d & 0x3F
                if back_bits < 8:
                    _need(rle, i, "lz5")
                    d = rle[i] + 1
                    if i < len(rle) - 1:
                        i += 1
                else:
                    d = back + 1
                    back, back_bits = 0, 0

            if d <= 0 or d > j:
                raise SffCorruptError(
                    "lz5 back-reference of %d at output position %d is out of range" % (d, j))
            while True:
                budget -= 1
                if budget <= 0:
                    raise SffCorruptError("lz5 decoder exceeded its iteration budget")
                if j < pixel_count:
                    out[j] = out[j - d]
                    j += 1
                n -= 1
                if n < 0:
                    break
        else:
            # Literal run.
            if d & 0xE0 == 0:
                _need(rle, i, "lz5")
                n = rle[i] + 8
                if i < len(rle) - 1:
                    i += 1
            else:
                n = d >> 5
                d &= 0x1F
            while n > 0:
                if j < pixel_count:
                    out[j] = d & 0xFF
                    j += 1
                n -= 1

        control_shift += 1
        if control_shift >= 8:
            _need(rle, i, "lz5")
            control = rle[i]
            control_shift = 0
            if i < len(rle) - 1:
                i += 1

    return bytes(out)


# ---------------------------------------------------------------------------
# Container
# ---------------------------------------------------------------------------


class Sff:
    """A parsed, read-only SFF v2 container."""

    def __init__(self, path):
        self.path = path
        self.version = None             # (verhi, verlo1, verlo2, verlo3)
        self.version_string = "?"
        self.reserved = b""
        self.first_sprite_offset = 0
        self.sprite_count = 0
        self.first_palette_offset = 0
        self.palette_count = 0
        self.data_offset = 0            # "lofs"
        self.external_data_offset = 0   # "tofs"
        self.sprites = []
        self.palettes = []
        self.by_key = {}
        self.duplicate_keys = []
        self.warnings = []
        self._raw = b""
        self._pixel_cache = {}

    # -- loading ----------------------------------------------------------

    @classmethod
    def load(cls, path):
        sff = cls(path)
        try:
            with open(path, "rb") as f:
                sff._raw = f.read()
        except OSError as exc:
            raise SffFormatError("cannot read %s: %s" % (path, exc)) from exc
        sff._parse()
        return sff

    def _u32(self, offset, what):
        if offset + 4 > len(self._raw):
            raise SffFormatError("%s: file ends before %s (offset %d, size %d)"
                                 % (self.path, what, offset, len(self._raw)))
        return struct.unpack_from("<I", self._raw, offset)[0]

    def _parse(self):
        raw = self._raw
        if len(raw) < 16:
            raise SffFormatError("%s: file is %d bytes, too short to be an SFF"
                                 % (self.path, len(raw)))
        if raw[:12] != SIGNATURE:
            raise SffFormatError("%s: bad SFF signature (expected 'ElecbyteSpr', got %r)"
                                 % (self.path, raw[:12]))

        verlo3, verlo2, verlo1, verhi = raw[12], raw[13], raw[14], raw[15]
        self.version = (verhi, verlo1, verlo2, verlo3)
        self.version_string = "%d.%d.%d.%d" % (verhi, verlo1, verlo2, verlo3)

        if verhi == 1:
            self.reserved = raw[16:36]
            self.sprite_count = self._u32(20, "sprite count")
            self.first_sprite_offset = self._u32(24, "first sprite header offset")
            raise SffUnsupportedError(
                "%s: SFF v1 (%s) is not supported by the P5 asset tooling; only SFF v2 is. "
                "The engine still loads v1 files, so this is a tool limitation, not a "
                "corrupt file." % (self.path, self.version_string))
        if verhi != 2:
            raise SffUnsupportedError(
                "%s: unrecognised SFF version %s (only v2 is supported)"
                % (self.path, self.version_string))

        # v2 header. Offsets verified against the four SFFs in this repository and
        # against SffHeader.Read in engine/ikemen-go/src/image.go.
        if len(raw) < 64:
            raise SffFormatError("%s: v2 header needs 64 bytes, file has %d"
                                 % (self.path, len(raw)))
        self.reserved = raw[16:36]
        self.first_sprite_offset = self._u32(36, "first sprite header offset")
        self.sprite_count = self._u32(40, "sprite count")
        self.first_palette_offset = self._u32(44, "first palette header offset")
        self.palette_count = self._u32(48, "palette count")
        self.data_offset = self._u32(52, "lofs")
        self.external_data_offset = self._u32(60, "tofs")

        if self.sprite_count == 0:
            raise SffCorruptError("%s: header declares 0 sprites" % self.path)
        if self.sprite_count > 100000:
            raise SffCorruptError("%s: header declares an implausible number of sprites (%d)"
                                  % (self.path, self.sprite_count))
        if self.palette_count > 1024:
            raise SffCorruptError("%s: header declares an implausible number of palettes (%d)"
                                  % (self.path, self.palette_count))

        self._parse_palettes()
        self._parse_sprites()

    def _parse_palettes(self):
        base = self.first_palette_offset
        end_of_headers = base + self.palette_count * 16
        if self.palette_count and end_of_headers > len(self._raw):
            raise SffCorruptError(
                "%s: palette header table (%d entries at offset %d) runs past the end of the file"
                % (self.path, self.palette_count, base))

        seen = {}
        for i in range(self.palette_count):
            off = base + i * 16
            group, number, declared, link = struct.unpack_from("<HHHH", self._raw, off)
            pdofs, pdsize = struct.unpack_from("<II", self._raw, off + 8)
            pal = Palette(i, group, number, declared, link, pdofs, pdsize)

            if (group, number) in seen:
                pal.source_index = seen[(group, number)]
                pal.warnings.append("palette key (%d,%d) is a duplicate of entry %d"
                                    % (group, number, pal.source_index))
                self.warnings.append("duplicate palette key (%d,%d) at entry %d"
                                     % (group, number, i))
            elif pdsize == 0:
                # Linked palette: shares the data of an earlier entry.
                if link >= len(self.palettes):
                    raise SffCorruptError(
                        "%s: palette %d links to entry %d which does not exist"
                        % (self.path, i, link))
                pal.source_index = link
            else:
                pal.colours = self._read_palette(pdofs, pdsize)

            seen[(group, number)] = pal.source_index
            self.palettes.append(pal)

        for pal in self.palettes:
            if not pal.colours and pal.source_index < len(self.palettes):
                pal.colours = self.palettes[pal.source_index].colours
            if pal.colours and pal.colours[0][3] != 0:
                pal.warnings.append(
                    "palette colour 0 is not transparent (alpha=%d); the engine relies on "
                    "index 0 for transparency" % pal.colours[0][3])

    def _read_palette(self, pdofs, pdsize):
        start = self.data_offset + pdofs
        end = start + pdsize
        if pdsize % 4:
            raise SffCorruptError("%s: palette data size %d is not a multiple of 4"
                                  % (self.path, pdsize))
        if end > len(self._raw):
            raise SffCorruptError(
                "%s: palette data (offset %d, size %d) runs past the end of the file (%d bytes)"
                % (self.path, start, pdsize, len(self._raw)))
        raw = self._raw[start:end]
        colours = [tuple(raw[i:i + 4]) for i in range(0, pdsize, 4)]

        # Mirror ReadPalette(): pad up to the next power of two, clamped to [16, 256].
        needed = len(colours)
        depth = 1
        while depth < needed:
            depth *= 2
        depth = max(16, min(256, depth))
        if needed < depth:
            colours = colours + [(0, 0, 0, 0)] * (depth - needed)
        return colours

    def _parse_sprites(self):
        offset = self.first_sprite_offset
        for i in range(self.sprite_count):
            if offset + 28 > len(self._raw):
                raise SffCorruptError(
                    "%s: sprite header %d at offset %d runs past the end of the file (%d bytes)"
                    % (self.path, i, offset, len(self._raw)))
            group, number, width, height, axis_x, axis_y = struct.unpack_from(
                "<HHHHhh", self._raw, offset)
            link, fmt, coldepth = struct.unpack_from("<HBB", self._raw, offset + 12)
            data_offset, data_size, pal_index, flags = struct.unpack_from(
                "<IIHH", self._raw, offset + 16)

            if flags & 1:
                absolute = self.external_data_offset + data_offset
            else:
                absolute = self.data_offset + data_offset

            sprite = Sprite(i, group, number, width, height, axis_x, axis_y, link,
                            fmt, coldepth, absolute, data_size, pal_index, flags)
            if data_size and absolute + data_size > len(self._raw):
                raise SffCorruptError(
                    "%s: sprite %d (group %d image %d) pixel data at offset %d size %d runs "
                    "past the end of the file (%d bytes) -- the file is truncated or corrupt"
                    % (self.path, i, group, number, absolute, data_size, len(self._raw)))
            if width == 0 or height == 0:
                sprite.warnings.append("sprite is %dx%d" % (width, height))
            self.sprites.append(sprite)
            offset += 28

        for sprite in self.sprites:
            if sprite.data_size == 0:
                # Empty data means "reuse the pixels of sprite `link`".
                if sprite.link < len(self.sprites):
                    sprite.linked_source_index = sprite.link
                else:
                    sprite.warnings.append(
                        "empty pixel data and link index %d is out of range" % sprite.link)
                    self.warnings.append(
                        "sprite %d has no pixel data and an invalid link index %d"
                        % (sprite.index, sprite.link))

        for sprite in self.sprites:
            existing = self.by_key.get(sprite.key)
            if existing is not None:
                self.duplicate_keys.append(sprite.key)
                self.warnings.append(
                    "duplicate sprite key (%d,%d): header %d ignored (first one wins, matching "
                    "the engine)" % (sprite.group, sprite.number, sprite.index))
                sprite.warnings.append("duplicate key (%d,%d); shadowed by header %d"
                                       % (sprite.group, sprite.number, existing.index))
            else:
                self.by_key[sprite.key] = sprite

    # -- accessors --------------------------------------------------------

    def sprite(self, group, number):
        return self.by_key.get((group, number))

    def has_sprite(self, group, number):
        return (group, number) in self.by_key

    def sorted_sprites(self):
        return sorted(self.sprites, key=lambda s: (s.group, s.number, s.index))

    def palette(self, index):
        if not self.palettes:
            return None
        if index < 0 or index >= len(self.palettes):
            return None
        pal = self.palettes[index]
        return pal.colours or None

    # -- pixel decoding ---------------------------------------------------

    def _resolve_pixels(self, sprite, depth=0):
        """Return ('indices', bytes) or ('rgba', bytes) for one sprite."""
        if sprite.index in self._pixel_cache:
            return self._pixel_cache[sprite.index]
        if depth > 8:
            raise SffCorruptError("%s: sprite link chain from %d is too deep (cycle?)"
                                  % (self.path, sprite.index))

        if sprite.is_linked:
            if sprite.linked_source_index is None:
                # The engine falls back to "no texture" here (loadSff sets palidx 0 and
                # leaves the sprite blank). Do the same and let the validator report it,
                # instead of making the whole container unreadable.
                result = ("indices", b"")
                self._pixel_cache[sprite.index] = result
                return result
            result = self._resolve_pixels(self.sprites[sprite.linked_source_index], depth + 1)
            self._pixel_cache[sprite.index] = result
            return result

        expected = sprite.width * sprite.height
        start = sprite.data_offset
        end = start + sprite.data_size
        raw_payload = self._raw[start:end]

        # Every compressed SFF v2 format stores a 4-byte length prefix in front of
        # the stream; the engine seeks past it (readV2: "f.Seek(offset+4, 0)") and
        # then reads data_size-4 bytes for RLE/LZ5, or decodes the PNG in place.
        if sprite.format in (FMT_RLE8, FMT_RLE5, FMT_LZ5, FMT_PNG_PALETTE,
                             FMT_PNG_RGBA, FMT_PNG_RGBA2):
            if len(raw_payload) < 4:
                raise SffCorruptError(
                    "%s: sprite %d (%s) payload is %d bytes, need at least 4 for the length "
                    "prefix; the engine clamps this to 4 and leaves the sprite blank"
                    % (self.path, sprite.index, sprite.format_name, len(raw_payload)))
            body = raw_payload[4:]
        else:
            body = raw_payload

        if sprite.format == FMT_RAW:
            if sprite.coldepth != 8:
                raise SffUnsupportedError(
                    "%s: sprite %d (group %d image %d) is raw true colour (format 0, depth %d), "
                    "which the P5 tooling does not support" % (self.path, sprite.index,
                                                               sprite.group, sprite.number,
                                                               sprite.coldepth))
            if len(body) != expected:
                raise SffCorruptError(
                    "%s: sprite %d raw data is %d bytes, expected %d for %dx%d"
                    % (self.path, sprite.index, len(body), expected,
                       sprite.width, sprite.height))
            result = ("indices", body)

        elif sprite.format == FMT_RLE8:
            result = ("indices", rle8_decode(body, expected))
        elif sprite.format == FMT_RLE5:
            result = ("indices", rle5_decode(body, expected))
        elif sprite.format == FMT_LZ5:
            result = ("indices", lz5_decode(body, expected))

        elif sprite.format == FMT_PNG_PALETTE:
            image = self._decode_embedded_png(self._raw[start + 4:], sprite)
            if image.indices is None:
                raise SffUnsupportedError(
                    "%s: sprite %d claims format 10 (PNG palette) but the embedded PNG is "
                    "not an indexed image (colour type %d)"
                    % (self.path, sprite.index, image.colour_type))
            if len(image.indices) != expected:
                raise SffCorruptError(
                    "%s: sprite %d PNG holds %d indices, expected %d for %dx%d"
                    % (self.path, sprite.index, len(image.indices), expected,
                       sprite.width, sprite.height))
            result = ("indices", bytes(image.indices))

        elif sprite.format in (FMT_PNG_RGBA, FMT_PNG_RGBA2):
            image = self._decode_embedded_png(self._raw[start + 4:], sprite)
            if len(image.rgba) != expected * 4:
                raise SffCorruptError(
                    "%s: sprite %d PNG holds %d bytes, expected %d for %dx%d RGBA"
                    % (self.path, sprite.index, len(image.rgba), expected * 4,
                       sprite.width, sprite.height))
            result = ("rgba", image.rgba)

        else:
            raise SffUnsupportedError(
                "%s: sprite %d (group %d image %d) uses format %d, which the P5 tooling does "
                "not support" % (self.path, sprite.index, sprite.group, sprite.number,
                                 sprite.format))

        self._pixel_cache[sprite.index] = result
        return result

    def _decode_embedded_png(self, payload, sprite):
        try:
            return pngio.decode(payload)
        except pngio.PngError as exc:
            raise SffCorruptError("%s: sprite %d has an undecodable PNG payload: %s"
                                  % (self.path, sprite.index, exc)) from exc

    def rgba(self, sprite, palette_index=None):
        """Return ``(rgba_bytes, palette_used_or_None)`` for one sprite.

        Palette sprites are mapped through ``palette_index`` (default: the
        sprite's own ``palette_index`` field -- exactly what ``Sprite.GetPal``
        does at runtime). Transparency comes from the palette's own alpha for
        index 0; the reader does not force it, so that the tool shows the same
        thing the engine would draw.
        """
        kind, data = self._resolve_pixels(sprite)
        expected = sprite.width * sprite.height
        stride = 4 if kind == "rgba" else 1

        if len(data) != expected * stride:
            # Only reachable for sprites the engine also leaves blank (no payload and
            # no usable link, or a payload shorter than its length prefix). Keep the
            # declared size so the exported PNG still matches the metadata, and let the
            # reader's warning explain why it is empty.
            if len(data) > expected * stride:
                data = data[:expected * stride]
            else:
                data = bytes(data) + bytes(expected * stride - len(data))

        if kind == "rgba":
            out = bytearray(data)
            for i in range(0, len(out) - 3, 4):
                if out[i + 3] == 0:
                    out[i] = out[i + 1] = out[i + 2] = 0
            return bytes(out), None

        idx = sprite.pal_index if palette_index is None else palette_index
        colours = self.palette(idx)
        if not colours:
            raise SffCorruptError(
                "%s: sprite %d needs palette %d but this container has no such palette"
                % (self.path, sprite.index, idx))

        out = bytearray(len(data) * 4)
        for pos, value in enumerate(data):
            if value >= len(colours):
                raise SffCorruptError(
                    "%s: sprite %d uses palette index %d but palette %d only has %d colours"
                    % (self.path, sprite.index, value, idx, len(colours)))
            r, g, b, a = colours[value]
            o = pos * 4
            out[o] = r
            out[o + 1] = g
            out[o + 2] = b
            out[o + 3] = a
        return bytes(out), colours
