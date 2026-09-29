#!/usr/bin/env python3
"""Check the PNG files sffctl just wrote, against the SFF they came from.

``sffctl export`` reports what it *intended* to write. This script re-opens the
files on disk and compares them with the container, so a bug in the writer cannot
hide behind a matching report:

    every file name parses as <group>_<image>.png and maps to a real sprite
    width and height in the PNG header equal the SFF metadata
    the pixels equal what the reader produces from the SFF (exact, pixel for pixel)
    the sprite is not entirely transparent
    no two sprites claim the same file name

Usage:
    python tests/tools/check_export.py --sff FILE.sff --out DIR [--palette N] [--json]
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "tools")))

from kofassets import pngio, sff  # noqa: E402

NAME_RE = re.compile(r"^(-?\d+)_(-?\d+)\.png$")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--sff", required=True, help="the container the export came from")
    parser.add_argument("--out", required=True, help="the directory that was exported to")
    parser.add_argument("--palette", type=int, default=None,
                        help="palette index that was forced during the export")
    parser.add_argument("--allow-empty-alpha", action="store_true",
                        help="do not fail on fully transparent sprites")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)

    problems = []
    checked = []
    names = {}

    if not os.path.isdir(args.out):
        print("FAIL output directory not found: %s" % args.out)
        return 1

    try:
        container = sff.Sff.load(args.sff)
    except sff.SffError as exc:
        print("FAIL cannot read %s: %s" % (args.sff, exc))
        return 1

    pngs = sorted(name for name in os.listdir(args.out) if name.lower().endswith(".png"))
    if not pngs:
        problems.append("no PNG files in %s" % args.out)

    for name in pngs:
        match = NAME_RE.match(name)
        if not match:
            problems.append("%s: does not follow the <group>_<image>.png naming rule" % name)
            continue
        group, image = int(match.group(1)), int(match.group(2))
        if name in names:
            problems.append("%s: produced twice" % name)
        names[name] = (group, image)

        sprite = container.sprite(group, image)
        if sprite is None:
            problems.append("%s: sprite %d,%d is not in %s" % (name, group, image, args.sff))
            continue

        path = os.path.join(args.out, name)
        try:
            decoded = pngio.read(path)
        except (OSError, pngio.PngError) as exc:
            problems.append("%s: cannot be read back: %s" % (name, exc))
            continue

        if (decoded.width, decoded.height) != (sprite.width, sprite.height):
            problems.append("%s: PNG is %dx%d, the SFF says %dx%d"
                            % (name, decoded.width, decoded.height,
                               sprite.width, sprite.height))
            continue

        expected, _ = container.rgba(sprite, args.palette)
        if decoded.rgba != expected:
            first = next((i for i in range(0, len(expected), 4)
                          if decoded.rgba[i:i + 4] != expected[i:i + 4]), -1)
            problems.append("%s: pixels differ from the SFF (first mismatch at byte %d)"
                            % (name, first))
            continue

        visible = sum(1 for i in range(3, len(decoded.rgba), 4) if decoded.rgba[i] != 0)
        if visible == 0 and not args.allow_empty_alpha:
            problems.append("%s: the exported sprite is entirely transparent" % name)
            continue
        checked.append({"file": name, "group": group, "image": image,
                        "width": decoded.width, "height": decoded.height,
                        "visible_pixels": visible})

    if args.json:
        json.dump({"sff": args.sff, "output": args.out, "checked": checked,
                   "problems": problems}, sys.stdout, indent=2)
        sys.stdout.write("\n")
    else:
        for entry in checked:
            print("  ok %-14s %4dx%-4d visible=%d"
                  % (entry["file"], entry["width"], entry["height"],
                     entry["visible_pixels"]))
        for problem in problems:
            print("  FAIL %s" % problem)
        print("")
        print("export check: %d file(s) verified, %d problem(s)" % (len(checked), len(problems)))

    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
