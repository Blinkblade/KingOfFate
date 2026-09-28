"""Minimal PNG reader/writer built on the standard library only.

Why not Pillow?
---------------
Pillow is already used by ``tools/read_frame_text.py``, but that tool is an
optional runtime-observation helper. The P5 asset tools must run on any machine
that can run the project's own test suite, so they stay dependency-free: zlib is
enough for both directions.

Writer
------
8-bit RGBA, filter type 0 on every row, no interlacing -- the format every tool
that consumes MUGEN/IKEMEN art (Aseprite, Photoshop, GIMP, fighter factories)
reads without complaint.

Reader
------
Enough of the PNG spec to (a) read the PNG images embedded in an SFF v2
container and (b) read exported PNGs back in the tests, so the export can be
verified without trusting the writer:

    bit depths 1/2/4/8 (palette) and 8/16 (grey, RGB, RGBA)
    colour types 0 (grey), 2 (RGB), 3 (palette), 4 (grey+alpha), 6 (RGBA)
    non-interlaced only -- interlaced input is reported as unsupported instead
    of being mis-decoded
"""

from __future__ import annotations

import struct
import zlib

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


class PngError(Exception):
    """Raised for input that is not a PNG we can handle."""


# ---------------------------------------------------------------------------
# Writing
# ---------------------------------------------------------------------------


def _chunk(tag: bytes, payload: bytes) -> bytes:
    body = tag + payload
    return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


def encode_rgba(width: int, height: int, rgba: bytes) -> bytes:
    """Encode raw 8-bit RGBA pixels (row-major, 4 bytes/px) as a PNG file."""
    if width <= 0 or height <= 0:
        raise PngError("image size must be positive, got %dx%d" % (width, height))
    expected = width * height * 4
    if len(rgba) != expected:
        raise PngError("pixel buffer is %d bytes, expected %d for %dx%d RGBA"
                       % (len(rgba), expected, width, height))

    out = bytearray(PNG_SIGNATURE)
    out += _chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))

    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)  # filter type 0 (None)
        raw += rgba[y * stride:(y + 1) * stride]
    out += _chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    out += _chunk(b"IEND", b"")
    return bytes(out)


def write_rgba(path: str, width: int, height: int, rgba: bytes) -> None:
    data = encode_rgba(width, height, rgba)
    with open(path, "wb") as f:
        f.write(data)


# ---------------------------------------------------------------------------
# Reading
# ---------------------------------------------------------------------------

_CHANNELS = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}


def _paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def _unfilter(raw: bytes, height: int, stride: int, bpp: int) -> bytes:
    """Reverse the per-row PNG filters. Returns height*stride bytes."""
    out = bytearray(height * stride)
    pos = 0
    for y in range(height):
        if pos >= len(raw):
            raise PngError("truncated image data at row %d" % y)
        ftype = raw[pos]
        pos += 1
        row = bytearray(raw[pos:pos + stride])
        if len(row) != stride:
            raise PngError("truncated image data at row %d" % y)
        pos += stride
        base = y * stride
        prev = base - stride
        if ftype == 0:
            pass
        elif ftype == 1:  # Sub
            for i in range(bpp, stride):
                row[i] = (row[i] + row[i - bpp]) & 0xFF
        elif ftype == 2:  # Up
            if y > 0:
                for i in range(stride):
                    row[i] = (row[i] + out[prev + i]) & 0xFF
        elif ftype == 3:  # Average
            for i in range(stride):
                a = row[i - bpp] if i >= bpp else 0
                b = out[prev + i] if y > 0 else 0
                row[i] = (row[i] + ((a + b) >> 1)) & 0xFF
        elif ftype == 4:  # Paeth
            for i in range(stride):
                a = row[i - bpp] if i >= bpp else 0
                b = out[prev + i] if y > 0 else 0
                c = out[prev + i - bpp] if (y > 0 and i >= bpp) else 0
                row[i] = (row[i] + _paeth(a, b, c)) & 0xFF
        else:
            raise PngError("unknown PNG filter type %d at row %d" % (ftype, y))
        out[base:base + stride] = row
    return bytes(out)


class Image:
    """Decoded PNG.

    ``indices`` is set only for palette images (colour type 3) and holds one
    8-bit palette index per pixel -- this is what an SFF v2 "format 10" sprite
    stores, and what the engine reads out of it.
    """

    __slots__ = ("width", "height", "colour_type", "bit_depth", "rgba", "indices", "palette")

    def __init__(self, width, height, colour_type, bit_depth, rgba, indices, palette):
        self.width = width
        self.height = height
        self.colour_type = colour_type
        self.bit_depth = bit_depth
        self.rgba = rgba
        self.indices = indices
        self.palette = palette


def _expand_bits(row: bytes, bit_depth: int, width: int) -> bytearray:
    out = bytearray(width)
    if bit_depth == 8:
        out[:] = row[:width]
        return out
    per_byte = 8 // bit_depth
    mask = (1 << bit_depth) - 1
    for x in range(width):
        byte = row[x // per_byte]
        shift = 8 - bit_depth * ((x % per_byte) + 1)
        out[x] = (byte >> shift) & mask
    return out


def decode(data: bytes) -> Image:
    if not data.startswith(PNG_SIGNATURE):
        raise PngError("not a PNG file (bad signature)")

    pos = len(PNG_SIGNATURE)
    ihdr = None
    idat = bytearray()
    palette = None
    trns = None

    while pos + 8 <= len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        tag = data[pos + 4:pos + 8]
        start = pos + 8
        end = start + length
        if end + 4 > len(data):
            raise PngError("truncated PNG chunk %.4s" % tag)
        payload = data[start:end]
        pos = end + 4  # skip CRC

        if tag == b"IHDR":
            if length != 13:
                raise PngError("bad IHDR length")
            width, height, bit_depth, colour_type, comp, filt, interlace = struct.unpack(">IIBBBBB", payload)
            if comp != 0 or filt != 0:
                raise PngError("unsupported PNG compression/filter method")
            if interlace != 0:
                raise PngError("interlaced PNG is not supported")
            if colour_type not in _CHANNELS:
                raise PngError("unsupported PNG colour type %d" % colour_type)
            if colour_type == 3 and bit_depth not in (1, 2, 4, 8):
                raise PngError("unsupported palette bit depth %d" % bit_depth)
            if colour_type != 3 and bit_depth not in (8, 16):
                raise PngError("unsupported PNG bit depth %d" % bit_depth)
            ihdr = (width, height, bit_depth, colour_type)
        elif tag == b"PLTE":
            palette = payload
        elif tag == b"tRNS":
            trns = payload
        elif tag == b"IDAT":
            idat += payload
        elif tag == b"IEND":
            break

    if ihdr is None:
        raise PngError("PNG has no IHDR chunk")
    width, height, bit_depth, colour_type = ihdr
    if width <= 0 or height <= 0:
        raise PngError("PNG has a non-positive size")
    if not idat:
        raise PngError("PNG has no IDAT data")

    try:
        raw = zlib.decompress(bytes(idat))
    except zlib.error as exc:
        raise PngError("PNG image data failed to decompress: %s" % exc)

    channels = _CHANNELS[colour_type]
    bits_per_pixel = channels * bit_depth
    stride = (width * bits_per_pixel + 7) // 8
    bpp = max(1, bits_per_pixel // 8)
    flat = _unfilter(raw, height, stride, bpp)

    rgba = bytearray(width * height * 4)
    indices = None

    if colour_type == 3:
        if palette is None:
            raise PngError("palette PNG has no PLTE chunk")
        entries = len(palette) // 3
        if entries == 0:
            raise PngError("palette PNG has an empty PLTE chunk")
        alpha = bytearray(entries)
        for i in range(entries):
            alpha[i] = 255
        if trns is not None:
            for i in range(min(entries, len(trns))):
                alpha[i] = trns[i]
        indices = bytearray(width * height)
        for y in range(height):
            row = _expand_bits(flat[y * stride:(y + 1) * stride], bit_depth, width)
            base = y * width
            for x in range(width):
                idx = row[x]
                if idx >= entries:
                    raise PngError("palette index %d out of range at (%d,%d)" % (idx, x, y))
                indices[base + x] = idx
                p = idx * 3
                o = (base + x) * 4
                rgba[o] = palette[p]
                rgba[o + 1] = palette[p + 1]
                rgba[o + 2] = palette[p + 2]
                rgba[o + 3] = alpha[idx]
    else:
        step = 2 if bit_depth == 16 else 1
        for y in range(height):
            row = flat[y * stride:(y + 1) * stride]
            base = y * width
            for x in range(width):
                o = (base + x) * 4
                i = x * channels * step
                if colour_type == 0:
                    g = row[i]
                    rgba[o] = rgba[o + 1] = rgba[o + 2] = g
                    rgba[o + 3] = 255
                elif colour_type == 2:
                    rgba[o] = row[i]
                    rgba[o + 1] = row[i + step]
                    rgba[o + 2] = row[i + 2 * step]
                    rgba[o + 3] = 255
                elif colour_type == 4:
                    g = row[i]
                    rgba[o] = rgba[o + 1] = rgba[o + 2] = g
                    rgba[o + 3] = row[i + step]
                else:  # 6
                    rgba[o] = row[i]
                    rgba[o + 1] = row[i + step]
                    rgba[o + 2] = row[i + 2 * step]
                    rgba[o + 3] = row[i + 3 * step]

    return Image(width, height, colour_type, bit_depth, bytes(rgba), indices, palette)


def read(path: str) -> Image:
    with open(path, "rb") as f:
        return decode(f.read())
