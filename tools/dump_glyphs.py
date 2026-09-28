"""Print the pixels of a screenshot region as ASCII art, or dump every glyph of a
text row as its own little bitmap.

Why this exists
---------------
tools/read_frame_text.py turns the debug overlay into text automatically, and for
day-to-day work that is what you want. But an automatic reading still needs a way
to be *checked*. This is that check: it prints the actual pixel matrix, so any
number anyone quotes can be traced back to ink on a specific frame instead of to
somebody's impression. It is also the tool that first showed the overlay was
readable at all (glyphs are about 5x9 pixels at 1280x720).

Usage
-----
    python dump_glyphs.py <png> --bands                  # list ink rows
    python dump_glyphs.py <png> --box 0,30,200,60        # ascii art of a region
    python dump_glyphs.py <png> --band 1                 # every glyph of a row
    python dump_glyphs.py <png> --band 1 --verbose       # ...with pixel counts

Dependencies: numpy + Pillow.
"""
from __future__ import annotations

import sys

import numpy as np
from PIL import Image

INK_CHAR = '#'
BG_CHAR = '.'


def load_ink(path):
    """Overlay text is bright and low-saturation; everything else is not."""
    im = Image.open(path).convert('RGB')
    a = np.asarray(im)
    mx = a.max(axis=2).astype(np.int16)
    mn = a.min(axis=2).astype(np.int16)
    ink = (mn > 140) & ((mx - mn) < 45)
    return im.size, ink


def ink_bands(ink, minrow=2):
    rowsum = ink.sum(axis=1)
    out, start = [], None
    for y in range(ink.shape[0]):
        on = rowsum[y] > minrow
        if on and start is None:
            start = y
        if not on and start is not None:
            out.append((start, y))
            start = None
    if start is not None:
        out.append((start, ink.shape[0]))
    return out


def glyph_columns(sub):
    """Split a row bitmap into glyph spans on empty columns."""
    colsum = sub.any(axis=0)
    cols, start = [], None
    for i, on in enumerate(colsum):
        if on and start is None:
            start = i
        if not on and start is not None:
            cols.append((start, i))
            start = None
    if start is not None:
        cols.append((start, sub.shape[1]))
    return cols


def main():
    argv = sys.argv[1:]
    if not argv:
        print(__doc__)
        return 0
    path = argv[0]

    def val(name, default=None):
        return argv[argv.index(name) + 1] if name in argv else default

    size, ink = load_ink(path)
    print('file : %s   %dx%d' % (path, size[0], size[1]))

    if '--bands' in sys.argv:
        for i, (y0, y1) in enumerate(ink_bands(ink)):
            sub = ink[y0:y1]
            xs = np.nonzero(sub.any(axis=0))[0]
            print('  band %2d  y=%4d..%-4d h=%2d  x=%4d..%-4d ink=%5d'
                  % (i, y0, y1 - 1, y1 - y0, xs.min(), xs.max(), int(sub.sum())))
        return 0

    if '--box' in sys.argv:
        # one value, comma separated: --box 0,30,200,60
        box = [int(v) for v in val('--box').replace(',', ' ').split()]
        x0, y0, x1, y1 = box
        tx = int(val('--tx', 1))
        ty = int(val('--ty', 1))
        print('   box x[%d..%d] y[%d..%d]' % (x0, x1 - 1, y0, y1 - 1))
        for y in range(y0, y1, ty):
            line = []
            for x in range(x0, x1, tx):
                blk = ink[y:min(y + ty, y1), x:min(x + tx, x1)]
                line.append(INK_CHAR if blk.any() else BG_CHAR)
            print('   ' + ''.join(line))
        return 0

    if '--band' in sys.argv:
        n = int(val('--band'))
        y0, y1 = ink_bands(ink)[n]
        sub = ink[y0:y1, 0:size[0]]
        cols = glyph_columns(sub)
        print('band %d  y=%d..%d   %d glyph(s)' % (n, y0, y1 - 1, len(cols)))
        for i, (a, b) in enumerate(cols):
            bit = sub[:, a:b]
            h, w = bit.shape
            print('  glyph %2d  x=%4d..%-4d  %dx%d' % (i, a, b - 1, w, h))
            for row in bit:
                print('     ' + ''.join(INK_CHAR if p else BG_CHAR for p in row))
            print('     ' + '-' * min(w, 60))
        return 0

    print(__doc__)
    return 0


if __name__ == '__main__':
    sys.exit(main())
