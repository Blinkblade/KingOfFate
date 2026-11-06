#!/usr/bin/env python3
"""make_projectile_art -- generate the ki-blast frames for test_fighter_b.

Why this exists
---------------
Fighter B's projectile borrowed a sprite from the placeholder pack: ``1000,4``,
a **whole human figure**, 123x84 and fully opaque. The character is 96 px tall and
jumps 80.2 px (``8.4^2 / (2 * 0.44)``), so an 84 px-tall object floating at chest
height was **mathematically impossible to jump over** -- no amount of hitbox
tuning can fix that. It also looked like a person being fired out of a cannon.

So the projectile gets its own art, generated (not hand-painted) so it can be
reproduced and tweaked from source:

    python tools/make_projectile_art.py --out .tmp/orb
    python tools/sffpack/sffpack.py set-sprite \
        game/chars/test_fighter_b/test_fighter_b.sff \
        --out game/chars/test_fighter_b/test_fighter_b.sff \
        --sprite 1900,0=.tmp/orb/orb_00.png --sprite 1900,1=.tmp/orb/orb_01.png \
        --sprite 1900,2=.tmp/orb/orb_02.png --sprite 1900,3=.tmp/orb/orb_03.png \
        --axis 1900,0=24,24 --axis 1900,1=24,24 --axis 1900,2=24,24 --axis 1900,3=24,24

Frame geometry
--------------
48x48, axis at the centre (24,24) ⇒ the art occupies air-space x -24..23 and
y -24..23. With a projectile ``offset`` of ``34,-40`` the orb therefore floats
from y 16 to 63 -- below the 80.2 px jump apex, which is what makes it dodgeable.

The four frames pulse the core radius and shift the rim hue slightly, which is
enough motion to read as "live" at 3 ticks per frame (~0.2 s per loop).

Pure standard library (``kofassets.pngio``); no Pillow.
"""

from __future__ import annotations

import argparse
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from kofassets import pngio  # noqa: E402


def _lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def render(size, phase):
    """One frame of the orb. ``phase`` in [0,1) drives the pulse."""
    cx = cy = (size - 1) / 2.0
    # Radius pulses between 19.5 and 22.5 on a 48 px canvas.
    outer = 21.0 + 1.5 * math.sin(phase * 2.0 * math.pi)
    # Rim colour drifts between a cool cyan and a hot blue-violet.
    rim_hot = (120, 225, 255)
    rim_cold = (60, 110, 255)
    rim = _lerp(rim_cold, rim_hot, (math.sin(phase * 2.0 * math.pi) + 1.0) / 2.0)
    core = (255, 255, 255)
    mid = (170, 230, 255)
    edge = (25, 60, 150)

    pixels = bytearray(size * size * 4)
    for y in range(size):
        for x in range(size):
            dx = x - cx
            dy = y - cy
            d = math.hypot(dx, dy)
            if d > outer + 1.6:
                continue
            if d <= outer * 0.35:
                t = d / (outer * 0.35)
                colour = _lerp(core, mid, t * t)
                alpha = 255
            elif d <= outer * 0.78:
                t = (d - outer * 0.35) / (outer * 0.43)
                colour = _lerp(mid, rim, t)
                alpha = 255
            elif d <= outer:
                t = (d - outer * 0.78) / (outer * 0.22)
                colour = _lerp(rim, edge, t)
                alpha = int(round(255 - 90 * t))
            else:
                # Soft one-and-a-bit pixel halo so the edge does not alias hard.
                t = (d - outer) / 1.6
                colour = edge
                alpha = int(round(165 * (1.0 - t)))
            if alpha <= 0:
                continue
            i = (y * size + x) * 4
            pixels[i] = colour[0]
            pixels[i + 1] = colour[1]
            pixels[i + 2] = colour[2]
            pixels[i + 3] = min(255, max(0, alpha))
    return bytes(pixels)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", required=True, help="directory to write the PNGs into")
    parser.add_argument("--size", type=int, default=48, help="canvas edge in pixels (default 48)")
    parser.add_argument("--frames", type=int, default=4, help="how many frames (default 4)")
    parser.add_argument("--prefix", default="orb", help="file name prefix (default orb)")
    args = parser.parse_args(argv)

    if args.size < 8 or args.size > 256:
        print("ERROR: --size must be 8..256, got %d" % args.size)
        return 2
    if not 1 <= args.frames <= 32:
        print("ERROR: --frames must be 1..32, got %d" % args.frames)
        return 2

    try:
        os.makedirs(args.out, exist_ok=True)
    except OSError as exc:
        print("ERROR: %s" % exc)
        return 3

    written = []
    for n in range(args.frames):
        phase = n / float(args.frames)
        rgba = render(args.size, phase)
        path = os.path.join(args.out, "%s_%02d.png" % (args.prefix, n))
        try:
            pngio.write_rgba(path, args.size, args.size, rgba)
        except (pngio.PngError, OSError) as exc:
            print("ERROR: %s" % exc)
            return 3
        written.append(path)

    axis = args.size // 2
    span = (args.size - 1) - axis          # rightmost / lowest drawn pixel offset
    print("make_projectile_art: %d frame(s) of %dx%d -> %s"
          % (len(written), args.size, args.size, args.out))
    for path in written:
        print("  %s" % path)
    print("  axis:  %d,%d   (art occupies x %d..%d, y %d..%d in air space)"
          % (axis, axis, -axis, span, -axis, span))
    print("  Clsn:  Clsn1[0] = %d,%d, %d,%d" % (-axis, -axis, span, span))
    return 0


if __name__ == "__main__":
    sys.exit(main())
