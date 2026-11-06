"""SFF v2 writer -- the minimal "pack" half of the asset pipeline.

Why this exists (P6): the Archer art arrives as an SFF **v1** container (and,
later, as hand-drawn PNGs). The game characters all use SFF **v2**, so the
import path needs a writer that can assemble one. This module writes exactly
two sprite encodings:

    0   raw, colour depth 8   -- palette indices, uncompressed. Pixel-exact for
                                 sprites that already are palette indices (the
                                 v1 transcode path).
    12  PNG RGBA                -- a PNG stream embedded after a 4-byte length
                                 prefix (the prefix value is not interpreted by
                                 the engine; we write the true PNG length).
                                 Used for hand-drawn RGBA art, no quantizer.

Linked sprites (data size 0, ``link`` = index of an earlier sprite) are
supported so duplicate frames stay shared, exactly like the source files.

The container layout mirrors ``SffHeader.Read`` / ``readHeaderV2`` /
``readV2`` in ``engine/ikemen-go/src/image.go`` (the same code the reader in
``kofassets/sff.py`` was ported from), and ``tests/fixtures/make_fixtures.py``
``build_sff_v2``, which has been producing engine-valid v2 files since P5.
"""

from __future__ import annotations

import struct

SIGNATURE = b"ElecbyteSpr\x00"

FMT_RAW = 0
FMT_PNG_RGBA2 = 12


class SffWriteError(Exception):
    """The inputs cannot form a valid container."""


def build_sff_v2(sprites, palettes):
    """Assemble an SFF v2 (2.0.1.0) container and return its bytes.

    ``palettes`` is a list of up-to-256-colour lists of ``(r, g, b, a)``
    tuples; palette ``i`` is registered with the conventional key ``(1, i+1)``.

    ``sprites`` is a list of dicts:

        group, number            -- sprite key (u16 each)
        width, height            -- pixel dimensions
        axis_x, axis_y           -- axis (signed 16-bit)
        pal_index                -- index into ``palettes``
        payload                  -- bytes to embed:
                                    format 0: width*height palette indices
                                    format 12: a complete PNG stream
                                    verbatim: the exact bytes the container
                                    stores, length prefix included
        format                   -- 0 (raw depth 8) or 12 (PNG RGBA)
        link (optional)          -- index of an earlier sprite in this list
                                    whose pixels this sprite shares; the sprite
                                    is then written with data size 0 and no
                                    payload is read.
        verbatim (optional)      -- write ``payload`` byte-for-byte, with no
                                    length prefix added and no validation.
                                    Used by ``sffpack set-sprite``, which swaps
                                    one sprite and copies every other one
                                    untouched (lz5, PNG or raw alike).
        depth (optional)         -- colour depth for verbatim sprites (raw is
                                    8, PNG 32, lz5 5); defaults as before.
        flags (optional)         -- sprite flag word; defaults to 0. Bit 0
                                    selects the base for ``data_at``: set means
                                    the offset is relative to "tofs" instead of
                                    "lofs" (``sff.py:774``, ported from
                                    ``image.go``). This writer always emits
                                    lofs-relative offsets, so callers passing a
                                    source's flag word must mask bit 0 off.

    Sprites must be given in file order; ``link`` must point backwards.
    """
    if not sprites:
        raise SffWriteError("refusing to write an empty container")
    if len(palettes) > 65535:
        raise SffWriteError("too many palettes (%d)" % len(palettes))

    palette_header_offset = 64
    palette_header_size = 16
    data_offset = palette_header_offset + palette_header_size * len(palettes)

    palette_headers = bytearray()
    palette_data = bytearray()
    for i, colours in enumerate(palettes):
        if not colours or len(colours) > 256:
            raise SffWriteError("palette %d must hold 1..256 colours, has %d"
                                % (i, len(colours)))
        palette_headers += struct.pack("<HHHHII", 1, i + 1, len(colours), 0,
                                       len(palette_data), len(colours) * 4)
        for colour in colours:
            if len(colour) != 4:
                raise SffWriteError("palette %d has a non-RGBA colour %r" % (i, colour))
            palette_data += bytes(colour)

    sprite_header_offset = data_offset + len(palette_data)
    payload_start = sprite_header_offset + 28 * len(sprites)

    headers = bytearray()
    payloads = bytearray()
    for i, sprite in enumerate(sprites):
        link = sprite.get("link")
        if link is not None:
            if not (0 <= link < i):
                raise SffWriteError(
                    "sprite %d links to %d, which is not an earlier sprite" % (i, link))
            payload = b""
            data_at = 0
        else:
            fmt = sprite["format"]
            payload = sprite["payload"]
            if sprite.get("verbatim"):
                # Byte-for-byte passthrough: the caller already holds the exact
                # bytes the source container stores, including the 4-byte length
                # prefix that every compressed v2 format carries.
                pass
            elif fmt == FMT_RAW:
                if len(payload) != sprite["width"] * sprite["height"]:
                    raise SffWriteError(
                        "sprite %d (%d,%d): raw payload is %d bytes, expected %d for %dx%d"
                        % (i, sprite["group"], sprite["number"], len(payload),
                           sprite["width"] * sprite["height"],
                           sprite["width"], sprite["height"]))
            elif fmt == FMT_PNG_RGBA2:
                if not payload.startswith(b"\x89PNG\r\n\x1a\n"):
                    raise SffWriteError(
                        "sprite %d (%d,%d): format 12 payload is not a PNG stream"
                        % (i, sprite["group"], sprite["number"]))
                payload = struct.pack("<I", len(payload)) + payload
            else:
                raise SffWriteError(
                    "sprite %d (%d,%d): the writer only supports format 0 (raw depth 8), "
                    "12 (PNG RGBA) and verbatim passthrough, got %d"
                    % (i, sprite["group"], sprite["number"], fmt))
            data_at = payload_start + len(payloads) - data_offset

        headers += struct.pack(
            "<HHHHhhHBBIIHH",
            sprite["group"], sprite["number"],
            sprite["width"], sprite["height"],
            sprite["axis_x"], sprite["axis_y"],
            link if link is not None else 0,
            sprite["format"],
            sprite.get("depth", 8 if sprite["format"] == FMT_RAW else 32),
            data_at,
            len(payload),
            sprite["pal_index"],
            sprite.get("flags", 0),  # flags bit 0 = data offset based on tofs, not lofs
        )
        payloads += payload

    file_size = payload_start + len(payloads)

    header = bytearray(SIGNATURE)
    header += bytes([0, 1, 0, 2])           # verlo3, verlo2, verlo1, verhi = 2.0.1.0
    header += b"\x00" * 20                  # reserved (the engine skips these)
    header += struct.pack("<IIII", sprite_header_offset, len(sprites),
                          palette_header_offset, len(palettes))
    header += struct.pack("<I", data_offset)   # lofs
    header += struct.pack("<I", 0)
    header += struct.pack("<I", file_size)     # tofs
    if len(header) != 64:
        raise SffWriteError("internal error: header is %d bytes, expected 64" % len(header))

    return bytes(header) + bytes(palette_headers) + bytes(palette_data) \
        + bytes(headers) + bytes(payloads)
