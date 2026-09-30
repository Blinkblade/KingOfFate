"""SFF reader (read-only) -- v2 and v1.

What is supported
-----------------
SFF **v2** containers -- the format every character in this repository actually
uses (`game/chars/_template/_template.sff`, `test_fighter_a.sff`,
`test_fighter_b.sff` and the P1 lab `kfm.sff` are all `2.0.1.0` with 282 sprites
and 16 palettes).

SFF **v1** containers (added in P6 for the Archer asset import) -- the classic
WinMUGEN format with PCX sprites stored inline after each 32-byte subheader,
subheaders chained through their `ofs` field. Read-only, same guarantees as v2.

Per-sprite image formats:

    1   PCX (SFF v1)  palette indices, PCX RLE, palette at the end of the block
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
    format 0 with depth 24/32   -- raw true-colour; no asset here uses it and its
                                   byte order cannot be verified from the project's
                                   own data, so the tool refuses rather than lie
    interlaced PNG inside an SFF

Algorithms are ports of ``engine/ikemen-go/src/image.go`` (``SffHeader.Read``,
``readHeader``, ``read`` (v1 PCX path), ``readPcxHeader``, ``RlePcxDecode``,
``readHeaderV2``, ``readV2``, ``Rle8Decode``, ``Rle5Decode``, ``Lz5Decode``,
``loadPalettes``, ``ReadPalette``), with the difference that every decoder keeps
its bounds checks and raises instead of panicking.
"""

from __future__ import annotations

import os
import struct

from . import pngio

SIGNATURE = b"ElecbyteSpr\x00"

# SFF per-sprite formats we can decode. Format 1 is unused in v2; we use it to
# tag v1 PCX sprites so the pixel decoder can branch.
FMT_V1_PCX = 1
FMT_RLE8 = 2
FMT_RLE5 = 3
FMT_LZ5 = 4
FMT_PNG_PALETTE = 10
FMT_PNG_RGBA = 11
FMT_PNG_RGBA2 = 12
FMT_RAW = 0

FORMAT_NAMES = {
    FMT_V1_PCX: "pcx (sff v1)",
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
        "v1_rle_offset", "v1_rle_size",
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
        # SFF v1 only: where this sprite's PCX RLE stream lives (PCX header is at
        # v1_rle_offset - 128). None for v2 sprites.
        self.v1_rle_offset = None
        self.v1_rle_size = None

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


def pcx_decode(rle: bytes, pixel_count: int, width: int, bpl: int) -> bytes:
    """Port of ``Sprite.RlePcxDecode`` (SFF v1 PCX RLE).

    The stream is row-based: ``bpl`` is the PCX bytes-per-line value; bytes
    beyond ``width`` in a row are padding and skipped, exactly like the engine
    (``k`` counts bytes in the row, ``j`` counts emitted pixels). The Go
    source's ``if i < len(rle)-1 { i++ }`` quirk (the last byte can be read
    twice) is reproduced.
    """
    if not rle or bpl <= 0:
        return rle
    out = bytearray(pixel_count)
    i = j = k = 0
    budget = _DECODE_ITERATION_BUDGET
    while j < pixel_count:
        budget -= 1
        if budget <= 0:
            raise SffCorruptError("pcx decoder exceeded its iteration budget")
        _need(rle, i, "pcx")
        n = 1
        d = rle[i]
        if i < len(rle) - 1:
            i += 1
        if d >= 0xC0:
            n = d & 0x3F
            _need(rle, i, "pcx")
            d = rle[i]
            if i < len(rle) - 1:
                i += 1
        while n > 0:
            if k < width and j < pixel_count:
                out[j] = d
                j += 1
            k += 1
            if k == bpl:
                k = 0
                n = 1
            n -= 1
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
            # SFF v1: classic WinMUGEN container (PCX sprites, chained subheaders).
            self.reserved = raw[16:36]
            self.sprite_count = self._u32(20, "sprite count")
            self.first_sprite_offset = self._u32(24, "first sprite header offset")
            if self.sprite_count == 0:
                raise SffCorruptError("%s: header declares 0 sprites" % self.path)
            if self.sprite_count > 100000:
                raise SffCorruptError(
                    "%s: header declares an implausible number of sprites (%d)"
                    % (self.path, self.sprite_count))
            self._parse_sprites_v1()
            self._finalize_sprites()
            return
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
        self._finalize_sprites()

    # -- SFF v1 -------------------------------------------------------------

    def _parse_sprites_v1(self):
        """Parse an SFF v1 container (PCX sprites, chained 32-byte subheaders).

        Layout (verified against engine/ikemen-go/src/image.go ``preloadSff`` /
        ``loadSff`` and against a real 1047-sprite file): subheader i sits at a
        chained position; its PCX data is stored inline right after it (32-byte
        header + PCX); the subheader's ``ofs`` field points at the *next*
        subheader (= end of this sprite's data block).

        Subheader (32 bytes): ofs u32 (next subheader), size u32 (data block
        size), axis_x i16, axis_y i16, group u16, number u16, link u16
        (indexOfPrevious for linked sprites), ps u8 (non-zero = share the
        previous sprite's palette), 13 bytes padding.
        """
        raw = self._raw
        pos = self.first_sprite_offset
        seen = {}
        for i in range(self.sprite_count):
            if pos <= 0 or pos + 32 > len(raw):
                raise SffCorruptError(
                    "%s: v1 sprite header %d at offset %d runs past the end of the file "
                    "(%d bytes); the subheader chain is broken"
                    % (self.path, i, pos, len(raw)))
            ofs, size, axis_x, axis_y, group, number, link = struct.unpack_from(
                "<IIhhHHH", raw, pos)
            ps = raw[pos + 18]

            data_start = pos + 32
            if data_start < ofs <= len(raw):
                block_end = ofs
            elif size and data_start + size <= len(raw):
                block_end = data_start + size
            elif size == 0:
                block_end = data_start
            else:
                raise SffCorruptError(
                    "%s: v1 sprite %d (group %d image %d) data block is out of range "
                    "(chain offset %d, size %d, file %d bytes)"
                    % (self.path, i, group, number, ofs, size, len(raw)))

            if size == 0:
                # Linked sprite (indexOfPrevious): pixels come from `link`.
                sprite = Sprite(i, group, number, 0, 0, axis_x, axis_y, link,
                                FMT_V1_PCX, 8, data_start, 0, 0, 0)
                if link < len(self.sprites):
                    sprite.linked_source_index = link
                else:
                    sprite.warnings.append(
                        "empty pixel data and link index %d is out of range" % link)
                    self.warnings.append(
                        "sprite %d has no pixel data and an invalid link index %d"
                        % (i, link))
                self.sprites.append(sprite)
                pos = ofs if ofs > pos else block_end
                continue

            # Real sprite: PCX header at data_start, RLE stream after it, palette
            # (768 bytes) at the end of the block unless `ps` says it is shared.
            width, height, bpl = self._read_pcx_header(data_start, i)
            rle_offset = data_start + 128
            is_char_first = (i == 0) or (group == 0 and number == 0)
            marker_fallback = False

            if is_char_first:
                # Legacy path (Sprite.read, isCharFirstSprite): the palette is the
                # last 768 bytes of the block, no 0x0C marker.
                pal_offset = block_end - 768
                palette_data_at = pal_offset
                rle_size = pal_offset - rle_offset
            elif ps != 0:
                # Shares the previous real sprite's palette; the block is all RLE.
                pal_offset = None
                palette_data_at = None
                rle_size = block_end - rle_offset
            else:
                # Own palette with a 0x0C marker: scan backwards from
                # block_end-769 for the marker, like the engine does; the palette
                # data starts right after the marker byte.
                pal_offset = None
                for p in range(block_end - 769, rle_offset - 1, -1):
                    if raw[p] == 0x0C:
                        pal_offset = p
                        break
                if pal_offset is None:
                    pal_offset = block_end - 769
                    marker_fallback = True
                palette_data_at = pal_offset + 1
                rle_size = pal_offset - rle_offset

            if rle_size < 0:
                raise SffCorruptError(
                    "%s: v1 sprite %d (group %d image %d) has a negative RLE size; "
                    "the block layout is inconsistent" % (self.path, i, group, number))

            if is_char_first or ps == 0:
                if palette_data_at < 0 or palette_data_at + 768 > len(raw):
                    raise SffCorruptError(
                        "%s: v1 sprite %d (group %d image %d) palette at offset %d runs "
                        "past the end of the file (%d bytes)"
                        % (self.path, i, group, number, palette_data_at, len(raw)))
                pal_index = self._add_v1_palette(palette_data_at)
            else:
                # Shared palette: same as the previous real sprite.
                pal_index = self.sprites[-1].pal_index if self.sprites else 0

            sprite = Sprite(i, group, number, width, height, axis_x, axis_y, link,
                            FMT_V1_PCX, 8, data_start, size, pal_index, 0)
            sprite.v1_rle_offset = rle_offset
            sprite.v1_rle_size = rle_size
            if bpl:
                sprite.flags = bpl  # reuse the flags field to carry bytes-per-line
            if width == 0 or height == 0:
                sprite.warnings.append("sprite is %dx%d" % (width, height))
            if marker_fallback:
                sprite.warnings.append(
                    "0x0C palette marker not found; palette taken from the last "
                    "768 bytes of the block")
            self.sprites.append(sprite)
            pos = ofs if ofs > pos else block_end

        # Resolve linked sprites' dimensions from their source (a v1 linked
        # subheader carries no PCX header, so no width/height of its own).
        for sprite in self.sprites:
            if sprite.is_linked and sprite.linked_source_index is not None:
                src = self.sprites[sprite.linked_source_index]
                sprite.width = src.width
                sprite.height = src.height
                sprite.pal_index = src.pal_index
                sprite.v1_rle_offset = src.v1_rle_offset
                sprite.v1_rle_size = src.v1_rle_size
                sprite.flags = src.flags

    def _read_pcx_header(self, offset, index):
        """Port of ``Sprite.readPcxHeader``. Returns (width, height, bpl)."""
        raw = self._raw
        if offset + 128 > len(raw):
            raise SffCorruptError(
                "%s: v1 sprite %d PCX header at offset %d runs past the end of the file "
                "(%d bytes)" % (self.path, index, offset, len(raw)))
        encoding = raw[offset + 2]
        bpp = raw[offset + 3]
        if bpp != 8:
            raise SffUnsupportedError(
                "%s: v1 sprite %d has an invalid PCX colour depth: expected 8-bit, got %d"
                % (self.path, index, bpp))
        xmin, ymin, xmax, ymax = struct.unpack_from("<HHHH", raw, offset + 4)
        bpl = struct.unpack_from("<H", raw, offset + 66)[0]
        width = xmax - xmin + 1
        height = ymax - ymin + 1
        if encoding != 1:
            bpl = 0
        return width, height, bpl

    def _add_v1_palette(self, offset):
        """Read 768 bytes of RGB palette data and register it as a Palette.

        Alpha follows the engine's v1 rule: index 0 is transparent, everything
        else opaque (``read`` / ``readSffv1Palette``).
        """
        raw = self._raw[offset:offset + 768]
        colours = []
        for i in range(256):
            r, g, b = raw[i * 3], raw[i * 3 + 1], raw[i * 3 + 2]
            colours.append((r, g, b, 0 if i == 0 else 255))
        index = len(self.palettes)
        pal = Palette(index, 1, index + 1, 256, 0, offset, 768)
        pal.colours = colours
        self.palettes.append(pal)
        return index

    # -- shared sprite-table finalisation -----------------------------------

    def _finalize_sprites(self):
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

        if sprite.format == FMT_V1_PCX:
            # SFF v1: PCX RLE stream; `flags` carries the PCX bytes-per-line value
            # (0 means the engine would use the payload as-is).
            if sprite.v1_rle_offset is None or sprite.v1_rle_size is None:
                raise SffCorruptError(
                    "%s: v1 sprite %d (group %d image %d) has no RLE stream information"
                    % (self.path, sprite.index, sprite.group, sprite.number))
            start = sprite.v1_rle_offset
            end = start + sprite.v1_rle_size
            if end > len(self._raw):
                raise SffCorruptError(
                    "%s: v1 sprite %d (group %d image %d) RLE data at offset %d size %d "
                    "runs past the end of the file (%d bytes)"
                    % (self.path, sprite.index, sprite.group, sprite.number, start,
                       sprite.v1_rle_size, len(self._raw)))
            body = self._raw[start:end]
            decoded = pcx_decode(body, expected, sprite.width, sprite.flags)
            if len(decoded) != expected:
                raise SffCorruptError(
                    "%s: v1 sprite %d (group %d image %d) decoded to %d pixels, expected "
                    "%d for %dx%d" % (self.path, sprite.index, sprite.group, sprite.number,
                                      len(decoded), expected, sprite.width, sprite.height))
            result = ("indices", decoded)
            self._pixel_cache[sprite.index] = result
            return result

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
