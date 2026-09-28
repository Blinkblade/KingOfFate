#!/usr/bin/env python3
"""Generate the P5 test fixtures.

This file is a *test* helper, not a product feature. It writes tiny, fully
synthetic SFF/AIR/DEF files so the asset tools can be checked against inputs whose
expected output is known exactly -- something the real characters cannot provide
(their SFF is a placeholder borrowed from IKEMEN's KFM, and every pixel in it
depends on a compressed stream whose intended content nobody wrote down).

It is deliberately the only place in the repository that *writes* an SFF. The
product tools never do: P5 is read-only by design (docs/character_asset_tooling.md).

Everything it produces is original (16 flat colours and simple index patterns), so
the fixtures carry no licence obligations and are safe to commit.

Usage:
    python tests/fixtures/make_fixtures.py            # write, or refresh, everything
    python tests/fixtures/make_fixtures.py --check     # verify the files on disk match
"""

from __future__ import annotations

import argparse
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "assets")

SIG = b"ElecbyteSpr\x00"

# Palette shared by every fixture sprite. Index 0 is transparent, the rest are
# distinct flat colours so a mis-mapped palette cannot go unnoticed.
PALETTE = [
    (0, 0, 0, 0),
    (255, 0, 0, 255),
    (0, 255, 0, 255),
    (0, 0, 255, 255),
    (255, 255, 0, 255),
    (255, 255, 255, 255),
] + [(0, 0, 0, 0)] * 10    # padded to 16


def sprite_pattern_a(width=8, height=8):
    """A deterministic index pattern used by the raw sprite."""
    return bytes(0 if x >= width - 3 else ((x + y) % 5) + 1
                 for y in range(height) for x in range(width))


def sprite_pattern_b(width=8, height=8):
    """A different pattern, for the LZ5-compressed sprite."""
    return bytes(0 if (x + y) % 7 == 0 else ((2 * x + y) % 3) + 1
                 for y in range(height) for x in range(width))


# A 5x3 sprite that is one flat colour plus a single transparent pixel, so the
# non-square case still exercises both alpha states.
SOLID_PATTERN = bytes([2] * 14 + [0])


def lz5_literal_stream(indices):
    """Encode indices as an LZ5 stream that uses literal runs only.

    The decoder (engine/ikemen-go/src/image.go Lz5Decode) reads one control byte,
    then eight instructions; a control bit of 0 means "literal run", encoded as
    ``(length << 5) | value`` for lengths 1..7 and values 0..31. That is all this
    encoder needs to produce a stream the real decoder accepts.
    """
    for value in indices:
        if value > 31:
            raise ValueError("literal-only LZ5 encoding supports values 0..31")
    instructions = []
    i = 0
    while i < len(indices):
        value = indices[i]
        run = 1
        while i + run < len(indices) and indices[i + run] == value and run < 7:
            run += 1
        instructions.append(((run << 5) | value) & 0xFF)
        i += run

    out = bytearray()
    for start in range(0, len(instructions), 8):
        out.append(0)  # control byte: the next 8 instructions are all literal runs
        out.extend(instructions[start:start + 8])
    if len(instructions) % 8 == 0:
        out.append(0)  # the decoder reads a fresh control byte after every 8
    return bytes(out)


def build_sff_v2(sprites):
    """Assemble an SFF v2 container.

    ``sprites`` is a list of dicts:
        group, number, width, height, axis_x, axis_y, format, depth, payload,
        has_length_prefix
    """
    palette_header_offset = 64
    palette_header_size = 16                                      # one palette entry
    palette_data_size = len(PALETTE) * 4
    data_offset = palette_header_offset + palette_header_size     # "lofs"
    sprite_header_offset = data_offset + palette_data_size

    headers = bytearray()
    payloads = bytearray()
    payload_start = sprite_header_offset + 28 * len(sprites)
    for sprite in sprites:
        payload = sprite["payload"]
        if sprite.get("has_length_prefix"):
            payload = struct.pack("<I", len(payload)) + payload
        # The engine reads pixel data at lofs + offset (flags bit 0 clear), so the
        # header value must be relative to lofs, not to the start of the payloads.
        headers += struct.pack(
            "<HHHHhhHBBIIHH",
            sprite["group"], sprite["number"], sprite["width"], sprite["height"],
            sprite["axis_x"], sprite["axis_y"],
            0,                                      # link
            sprite["format"], sprite["depth"],
            payload_start + len(payloads) - data_offset,
            len(payload),
            0,                                      # palette index
            0,                                      # flags: offset is relative to lofs
        )
        payloads += payload

    lofs = data_offset
    file_size = payload_start + len(payloads)

    header = bytearray(SIG)
    header += bytes([0, 1, 0, 2])          # verlo3, verlo2, verlo1, verhi = 2.0.1.0
    header += b"\x00" * 20                 # reserved (the engine skips these)
    header += struct.pack("<IIII", sprite_header_offset, len(sprites),
                          palette_header_offset, 1)
    header += struct.pack("<I", lofs)
    header += struct.pack("<I", 0)
    header += struct.pack("<I", file_size)  # "tofs"
    assert len(header) == 64, len(header)

    palette_header = struct.pack("<HHHHII", 1, 1, len(PALETTE), 0, 0, palette_data_size)
    palette_data = b"".join(bytes(colour) for colour in PALETTE)
    return bytes(header) + palette_header + palette_data + bytes(headers) + bytes(payloads)


def build_sff_v1():
    """A minimal, *valid* SFF v1 file -- used to check that v1 is refused clearly."""
    header = bytearray(SIG)
    header += bytes([0, 1, 0, 1])       # verlo3, verlo2, verlo1, verhi = 1.0.1.0
    header += struct.pack("<I", 0)      # dummy
    header += struct.pack("<I", 1)      # sprite count
    header += struct.pack("<I", 512)    # first sprite header offset
    header += struct.pack("<I", 0)      # dummy
    header += b"\x00" * (512 - len(header))
    header += struct.pack("<IIhhHHH", 520, 0, 0, 0, 0, 0, 0)
    return bytes(header)


def minimal_sff():
    """3 sprites: raw 8-bit, LZ5, and a non-square raw sprite."""
    a = sprite_pattern_a()
    b = sprite_pattern_b()
    return build_sff_v2([
        {"group": 0, "number": 0, "width": 8, "height": 8, "axis_x": 3, "axis_y": 7,
         "format": 0, "depth": 8, "payload": a, "has_length_prefix": False},
        {"group": 1, "number": 0, "width": 8, "height": 8, "axis_x": 1, "axis_y": 2,
         "format": 4, "depth": 5, "payload": lz5_literal_stream(b),
         "has_length_prefix": True},
        {"group": 2, "number": 0, "width": 5, "height": 3, "axis_x": 5, "axis_y": 0,
         "format": 0, "depth": 8, "payload": SOLID_PATTERN, "has_length_prefix": False},
    ])


# ---------------------------------------------------------------------------
# AIR fixtures
# ---------------------------------------------------------------------------

AIR_OK = """
; a clean, small animation table
[Begin Action 0]
Clsn2Default: 1
 Clsn2[0] = -3, 0, 3, -7
0,0, 0,0, 6
1,0, 0,0, 6

[Begin Action 200]
Clsn2: 2
 Clsn2[0] = -3, 0, 3, -7
 Clsn2[1] = 4, 0, 7, -5
0,0, 0,0, 2
Clsn1: 1
 Clsn1[0] = 4,-6, 9,-3
2,0, 0,0, 3
Clsn1: 0
0,0, 0,0, 3
"""

AIR_P4_NEGATIVE = """
; P4 negative case: a per-frame attack box in front of an -1 hold.
; The box covers one element only, so the hold carries no attack box at all.
[Begin Action 1005]
Clsn1: 1
 Clsn1[0] = -4,-3, 4,3
1,0, 0,0, 3
1,0, 0,0, -1
"""

AIR_P4_POSITIVE = """
; P4 positive case: the same animation, but the attack box is a default,
; so every element -- including the -1 hold -- carries it.
[Begin Action 1005]
Clsn1Default: 1
 Clsn1[0] = -4,-3, 4,3
1,0, 0,0, 3
1,0, 0,0, -1
"""

AIR_DUPLICATE = """
[Begin Action 0]
0,0, 0,0, 4
[Begin Action 0]
1,0, 0,0, 4
"""

AIR_EMPTY = """
[Begin Action 0]
1,0, 0,0, 4
[Begin Action 55]
; nothing here at all
[Begin Action 0]
"""

AIR_BAD_COUNT = """
[Begin Action 0]
Clsn1: 3
 Clsn1[0] = 0,0, 1,1
 Clsn1[1] = 1,1, 2,2
0,0, 0,0, 4
"""

AIR_ORPHAN_BOX = """
[Begin Action 0]
0,0, 0,0, 4
 Clsn1[0] = 0,0, 1,1
"""

AIR_MISSING_SPRITE = """
[Begin Action 0]
0,0, 0,0, 4
99,99, 0,0, 4
"""

AIR_BAD_TIME = """
[Begin Action 0]
0,0, 0,0, -2
1,0, 0,0, 4
"""

AIR_EXTRA_FILES = {
    "dup_action.air": AIR_DUPLICATE,
    "empty_action.air": AIR_EMPTY,
    "bad_box_count.air": AIR_BAD_COUNT,
    "orphan_box.air": AIR_ORPHAN_BOX,
    "missing_sprite.air": AIR_MISSING_SPRITE,
    "bad_time.air": AIR_BAD_TIME,
    "p4_per_frame_hold.air": AIR_P4_NEGATIVE,
    "p4_default_hold.air": AIR_P4_POSITIVE,
    "ok.air": AIR_OK,
}


# ---------------------------------------------------------------------------
# Character fixtures
# ---------------------------------------------------------------------------

DEF_TEMPLATE = """\
; P5 fixture character -- generated by tests/fixtures/make_fixtures.py
[Info]
name         = "{name}"
displayname  = "Fixture {name}"
mugenversion = 1.0

[Files]
cmd      = {name}.cmd
cns      = {name}.const
st       = {name}.zss
sprite   = {name}.sff
anim     = {name}.air
{extra}
"""

DEF_MISSING_FILES = """\
; P5 fixture character with deliberately broken file references
[Info]
name         = "char_missing_files"
displayname  = "Fixture missing files"
mugenversion = 1.0

[Files]
cmd      = char_missing_files.cmd
cns      = char_missing_files.const
st       = char_missing_files.zss
sprite   = does_not_exist.sff
anim     = does_not_exist.air
"""

DEF_ZSS_BAD_ANIM = """\
; P5 fixture character whose script asks for an animation the AIR does not define
[Info]
name         = "char_zss_missing_anim"
displayname  = "Fixture zss missing anim"
mugenversion = 1.0

[Files]
cmd      = char_zss_missing_anim.cmd
cns      = char_zss_missing_anim.const
st       = char_zss_missing_anim.zss
sprite   = char_zss_missing_anim.sff
anim     = char_zss_missing_anim.air
"""

ZSS_TEMPLATE = """\
# P5 fixture state script
[StateDef 200; anim: 200;]
if time = 0 {{
\tchangeAnim{{value: {anim}}}
}}
"""


def write(path, data, mode="wb"):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if isinstance(data, str):
        data = data.encode("utf-8")
    with open(path, mode) as handle:
        handle.write(data)
    return path


def build_all():
    """Return {relative path: bytes} so --check can compare without touching disk."""
    files = {}

    container = minimal_sff()
    files["minimal_v2.sff"] = container
    # Same container under the name airtool auto-detects next to ok.air.
    files["ok.sff"] = container
    files["unsupported_v1.sff"] = build_sff_v1()
    files["truncated.sff"] = container[:200]           # header promises more than exists
    files["bad_signature.sff"] = b"NOT AN SFF FILE" + b"\x00" * 48

    for name, text in AIR_EXTRA_FILES.items():
        files[name] = text.lstrip("\n").encode("utf-8")

    # A character that is entirely consistent: it loads, and every asset is there.
    files["char_ok/char_ok.def"] = DEF_TEMPLATE.format(
        name="char_ok", extra="sound    = char_ok.snd\n").encode("utf-8")
    files["char_ok/char_ok.sff"] = container
    files["char_ok/char_ok.air"] = AIR_OK.lstrip("\n").encode("utf-8")
    files["char_ok/char_ok.cmd"] = b"# fixture command file\n"
    files["char_ok/char_ok.const"] = b"# fixture constants file\n"
    files["char_ok/char_ok.zss"] = ZSS_TEMPLATE.format(anim=200).encode("utf-8")
    files["char_ok/char_ok.snd"] = b""

    files["char_missing_files/char_missing_files.def"] = DEF_MISSING_FILES.encode("utf-8")
    files["char_missing_files/char_missing_files.cmd"] = b"# fixture\n"
    files["char_missing_files/char_missing_files.const"] = b"# fixture\n"
    files["char_missing_files/char_missing_files.zss"] = b"# fixture\n"

    files["char_zss_missing_anim/char_zss_missing_anim.def"] = \
        DEF_ZSS_BAD_ANIM.encode("utf-8")
    files["char_zss_missing_anim/char_zss_missing_anim.sff"] = container
    files["char_zss_missing_anim/char_zss_missing_anim.air"] = AIR_OK.lstrip("\n").encode("utf-8")
    files["char_zss_missing_anim/char_zss_missing_anim.cmd"] = b"# fixture\n"
    files["char_zss_missing_anim/char_zss_missing_anim.const"] = b"# fixture\n"
    files["char_zss_missing_anim/char_zss_missing_anim.zss"] = \
        ZSS_TEMPLATE.format(anim=9999).encode("utf-8")

    # A character whose SFF is a version the tooling refuses.
    files["char_v1_sprite/char_v1_sprite.def"] = DEF_TEMPLATE.format(
        name="char_v1_sprite", extra="").encode("utf-8")
    files["char_v1_sprite/char_v1_sprite.sff"] = build_sff_v1()
    files["char_v1_sprite/char_v1_sprite.air"] = AIR_OK.lstrip("\n").encode("utf-8")
    files["char_v1_sprite/char_v1_sprite.cmd"] = b"# fixture\n"
    files["char_v1_sprite/char_v1_sprite.const"] = b"# fixture\n"
    files["char_v1_sprite/char_v1_sprite.zss"] = ZSS_TEMPLATE.format(anim=200).encode("utf-8")
    return files


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true",
                        help="verify the files on disk instead of writing them")
    args = parser.parse_args(argv)

    files = build_all()
    problems = []
    written = 0

    for relative, data in sorted(files.items()):
        path = os.path.join(ASSETS, *relative.split("/"))
        if args.check:
            if not os.path.exists(path):
                problems.append("missing: %s" % relative)
                continue
            with open(path, "rb") as handle:
                on_disk = handle.read()
            if on_disk != data:
                problems.append("differs: %s (%d bytes on disk, %d generated)"
                                % (relative, len(on_disk), len(data)))
            continue
        write(path, data)
        written += 1

    if args.check:
        for problem in problems:
            print("FAIL %s" % problem)
        print("fixtures checked: %d file(s), %d problem(s)" % (len(files), len(problems)))
        return 1 if problems else 0

    print("wrote %d fixture file(s) under %s" % (written, ASSETS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
