#!/usr/bin/env python3
"""Render one animation as a horizontal strip of its frames.

Why this exists
---------------
Mapping a source character's animations onto ours is a *semantic* job: the
sprite numbers do not tell you which pose is a punch and which is a kick, and
guessing from the numbers is exactly how we once put a "raised swords" pose on
the heavy kick. The person who can answer the question is the owner, and what
they need is to *see* the frames -- not a sprite dump of 1800 files.

This draws, per requested action, one PNG with the action's frames laid out
left to right in playing order, on a mid-grey background (so light and dark
art are both visible). The file name carries the action number, which keeps
the label honest without needing a font.

Pure standard library, like the rest of the tools: it composes RGBA buffers and
writes PNG through `kofassets.pngio`.

Usage
-----
    python tools/anim_strip.py <sff> <air> --out DIR --actions 200,210,230
    python tools/anim_strip.py <sff> <air> --out DIR --actions 200 --height 240
"""

from __future__ import annotations

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from kofassets import pngio, sff as sffmod

BACKGROUND = (96, 96, 104, 255)
GAP = 3


def parse_air(path):
    """action number -> [(group, image, ticks, flip)] in playing order."""
    text = None
    for encoding in ("utf-8-sig", "cp932", "latin-1"):
        try:
            with open(path, "r", encoding=encoding) as handle:
                text = handle.read()
            break
        except UnicodeDecodeError:
            continue
    if text is None:
        raise SystemExit("cannot decode %s" % path)

    actions = {}
    current = None
    for line in text.splitlines():
        line = line.split(";")[0].strip()
        if not line:
            continue
        m = re.match(r"^\[\s*Begin\s+Action\s+(-?\d+)\s*\]", line, re.I)
        if m:
            current = int(m.group(1))
            actions[current] = []
            continue
        if current is None:
            continue
        m = re.match(r"^(-?\d+)\s*,\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*(-?\d+)"
                     r"(?:\s*,\s*(-?\d+))?(?:\s*,\s*([A-Za-z]+))?", line)
        if not m:
            continue
        group, image = int(m.group(1)), int(m.group(2))
        if group == -1:                      # end of action
            current = None
            continue
        flip = "H" if (m.group(6) or "").upper().startswith("H") else ""
        actions[current].append((group, image, int(m.group(5) or 0), flip))
    return actions


def scale_nearest(rgba, width, height, factor):
    """Integer nearest-neighbour upscale (factor >= 1)."""
    if factor == 1:
        return rgba, width, height
    out_w, out_h = width * factor, height * factor
    out = bytearray(out_w * out_h * 4)
    for y in range(out_h):
        src_row = (y // factor) * width * 4
        row_start = y * out_w * 4
        for x in range(out_w):
            src = src_row + (x // factor) * 4
            dst = row_start + x * 4
            out[dst:dst + 4] = rgba[src:src + 4]
    return bytes(out), out_w, out_h


def fit_factor(width, height, target_height):
    if height <= 0:
        return 1
    factor = max(1, int(target_height // height))
    return factor


def blit(canvas, canvas_w, canvas_h, rgba, w, h, at_x, at_y):
    for y in range(h):
        cy = at_y + y
        if cy < 0 or cy >= canvas_h:
            continue
        row = y * w * 4
        crow = cy * canvas_w * 4
        for x in range(w):
            cx = at_x + x
            if cx < 0 or cx >= canvas_w:
                continue
            src = row + x * 4
            alpha = rgba[src + 3]
            if alpha == 0:
                continue
            dst = crow + cx * 4
            if alpha == 255:
                canvas[dst:dst + 4] = rgba[src:src + 4]
            else:
                for k in range(3):
                    canvas[dst + k] = (rgba[src + k] * alpha
                                       + canvas[dst + k] * (255 - alpha)) // 255
                canvas[dst + 3] = 255


def render_action(container, frames, out_path, target_height, max_frames):
    kept = frames[:max_frames] if max_frames > 0 else frames
    tiles = []
    for group, image, _ticks, _flip in kept:
        sprite = container.sprite(group, image)
        if sprite is None:
            continue
        # rgba() returns (rgba_bytes, palette_used_or_None)
        rgba, _palette = container.rgba(sprite)
        factor = fit_factor(sprite.width, sprite.height, target_height)
        scaled, w, h = scale_nearest(rgba, sprite.width, sprite.height, factor)
        tiles.append((scaled, w, h))
    if not tiles:
        return None

    canvas_w = sum(t[1] for t in tiles) + GAP * (len(tiles) + 1)
    canvas_h = max(t[2] for t in tiles) + GAP * 2
    canvas = bytearray(BACKGROUND * (canvas_w * canvas_h))
    x = GAP
    for scaled, w, h in tiles:
        blit(canvas, canvas_w, canvas_h, scaled, w, h, x, canvas_h - GAP - h)
        x += w + GAP
    pngio.write_rgba(out_path, canvas_w, canvas_h, bytes(canvas))
    return canvas_w, canvas_h, len(tiles)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("sff")
    parser.add_argument("air")
    parser.add_argument("--out", required=True, help="output directory")
    parser.add_argument("--actions", required=True,
                        help="comma or space separated action numbers")
    parser.add_argument("--height", type=int, default=200,
                        help="target height per frame in pixels (default 200)")
    parser.add_argument("--max-frames", type=int, default=16,
                        help="cap the frames drawn per action (0 = all)")
    args = parser.parse_args(argv)

    numbers = [int(t) for t in re.split(r"[,;\s]+", args.actions) if t.strip()]
    if not numbers:
        parser.error("--actions is empty")
    if not os.path.isdir(args.out):
        os.makedirs(args.out, exist_ok=True)

    container = sffmod.Sff.load(args.sff)
    actions = parse_air(args.air)

    made, missing = [], []
    for number in numbers:
        frames = actions.get(number)
        if not frames:
            missing.append(number)
            continue
        out_path = os.path.join(args.out, "action_%d.png" % number)
        result = render_action(container, frames, out_path, args.height,
                               args.max_frames)
        if result:
            w, h, n = result
            made.append((number, n, w, h))
            print("action %-5d %2d frame(s) -> %s  (%dx%d)"
                  % (number, n, out_path, w, h))
        else:
            missing.append(number)
    if missing:
        print("no frames drawn for: %s" % ", ".join(str(m) for m in missing))
    return 0


if __name__ == "__main__":
    sys.exit(main())
