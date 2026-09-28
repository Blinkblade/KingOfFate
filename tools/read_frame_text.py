"""Read the text drawn by the engine's debug overlay straight out of a PNG.

Why this tool exists
--------------------
Up to and including P4, every runtime number in our docs ("LIFE 1000 -> 940",
"POW 2000 -> 1000", "State No: 1000", ...) was transcribed by looking at a
screenshot. That cannot be audited, and one round of it turned out to be made
up. This tool closes the hole: the overlay is drawn with a known TrueType face
(Open Sans Bold -- see engine/ikemen-go/font/debug.def) and its rows are built
by fixed string.format() calls
(engine/ikemen-go/external/script/debug.lua), so every glyph can be rendered
locally and matched against the pixels. The result is one string per text row
that anyone can reproduce from the PNG.

How it works
------------
1. bright, low-saturation pixels = overlay ink -> horizontal bands = text rows
2. each band is cut into glyph bitmaps on empty columns
3. every character of a small charset is rendered from the same TTF at every
   plausible size (plus a half-pixel offset, because the engine scales the
   overlay fractionally)
4. a glyph is classified by grayscale agreement on a shared canvas -- the
   template must explain ALL of the observed ink, otherwise small glyphs win
   every time (that bug made the first version read everything as 'f')
5. the second pass uses the known row vocabulary: labels are restored by fuzzy
   match, and inside a value a close-scoring DIGIT alternative beats a letter

Both the raw reading and the repaired reading are printed, together with every
change made, so a wrong guess is visible instead of hidden.

Dependencies: numpy + Pillow only.

Usage
-----
    python read_frame_text.py <png> [--verbose] [--minrow N]
"""
from __future__ import annotations

import os
import re
import sys
import difflib

import numpy as np
from PIL import Image, ImageDraw, ImageFont

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, '..'))
DEFAULT_FONT = os.path.join(
    REPO_ROOT, 'engine', 'ikemen-go', 'font', 'Open_Sans', 'OpenSans-Bold.ttf')

# Only what the overlay can plausibly print. Smaller charset = fewer wrong
# matches.
CHARSET = (
    'abcdefghijklmnopqrstuvwxyz'
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    '0123456789'
    ':.,;/-_()[]#%+=<>?!*"\''
)
SIZES = tuple(range(8, 20))
OFFSETS = (0.0, 0.5)

# Words that appear in the overlay rows verbatim (from debug.lua). They are
# known in advance, so we do not need to read them correctly.
LABELS = [
    'LIF', 'POW', 'ATK', 'DEF', 'RED', 'GRD', 'STN', 'SPR', 'ElemNo', 'Time',
    'State', 'No', 'ActionID', 'CTRL', 'Type', 'MoveType', 'Physics',
    'Frames', 'VSync', 'Speed', 'FPS', 'ID', 'Player',
]

# Labels whose VALUE is a letter (S/C/A/...). Every other label is followed by
# a number, so for those we may safely let a digit alternative win.
LETTER_VALUE_LABELS = {'Type', 'MoveType', 'Physics'}


def _canon(word):
    """Map the render's favourite mistakes back to the obvious letter.

    'I' is the single most confused glyph on screen: the engine's own rows come
    out as 'L!F', 'Actlon!D', 'P!IysIC5'. Since each of these is a length-1
    substitution, canonicalising before comparing to the known labels is safe.
    """
    table = {'!': 'I', ']': 'I', '[': 'I', '|': 'I', '1': 'I', 'l': 'I'}
    return ''.join(table.get(c, c) for c in word)


# --------------------------------------------------------------------------
# image -> glyph coverage maps
# --------------------------------------------------------------------------
def load_ink(path):
    """Return (size, boolean ink mask, per-pixel coverage estimate)."""
    im = Image.open(path).convert('RGB')
    a = np.asarray(im)
    mx = a.max(axis=2).astype(np.int16)
    mn = a.min(axis=2).astype(np.int16)
    ink = (mn > 140) & ((mx - mn) < 45)
    return im.size, ink, mn


def ink_bands(ink, minrow=2):
    """Horizontal runs of ink = text rows."""
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


# --------------------------------------------------------------------------
# font -> template bitmaps
# --------------------------------------------------------------------------
def build_templates(font_path, sizes=SIZES, charset=CHARSET, offsets=OFFSETS):
    """Render every char at every plausible size; keep its coverage bitmap."""
    templates = []
    for size in sizes:
        try:
            font = ImageFont.truetype(font_path, size)
        except Exception:
            continue
        for ch in charset:
            for ox in offsets:
                # the engine draws the overlay at a fractional scale, so a
                # glyph may land on a half pixel; render both alignments
                canvas = Image.new('L', (size * 4, size * 4), 0)
                ImageDraw.Draw(canvas).text((size + ox, size), ch,
                                            font=font, fill=255)
                arr = np.asarray(canvas).astype(np.float32) / 255.0
                if arr.max() <= 0:
                    continue
                ys, xs = np.nonzero(arr > 0.02)
                if len(ys) == 0:
                    continue
                templates.append((ch, size,
                                  arr[ys.min():ys.max() + 1,
                                      xs.min():xs.max() + 1]))
    return templates


def _normalise(a):
    lo, hi = float(a.min()), float(a.max())
    if hi - lo < 1e-6:
        return np.zeros_like(a, dtype=np.float32)
    return ((a - lo) / (hi - lo)).astype(np.float32)


def best_match(cov, templates, topk=4):
    """Classify one glyph; return (char, score, size, [(char, score), ...]).

    Keeping the close alternatives is what later lets the repair pass decide an
    'o' is really a '0' *because the pixels nearly said so*, rather than because
    a global look-alike table said so.
    """
    bh, bw = cov.shape
    obs = _normalise(cov)
    scored, size_of = {}, {}
    for ch, size, tpl in templates:
        th, tw = tpl.shape
        # the rendered glyph must cover the observed one, give or take rounding
        if abs(th - bh) > 1 or abs(tw - bw) > 1:
            continue
        H, W = max(bh, th) + 2, max(bw, tw) + 2
        obs_c = np.zeros((H, W), dtype=np.float32)
        obs_c[1:1 + bh, 1:1 + bw] = obs
        best_here = -1.0
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                ty, tx = 1 + dy, 1 + dx
                if ty < 0 or tx < 0 or ty + th > H or tx + tw > W:
                    continue
                can = np.zeros((H, W), dtype=np.float32)
                can[ty:ty + th, tx:tx + tw] = tpl
                score = 1.0 - float(np.abs(obs_c - can).mean())
                if score > best_here:
                    best_here = score
        if best_here > scored.get(ch, -1.0):
            scored[ch] = best_here
            size_of[ch] = size
    if not scored:
        return None, -1.0, None, []
    alts = sorted(((c, round(s, 4)) for c, s in scored.items()),
                  key=lambda kv: -kv[1])[:topk]
    top_char, top_score = alts[0]
    return top_char, top_score, size_of[top_char], alts


# --------------------------------------------------------------------------
# band -> glyph list
# --------------------------------------------------------------------------
def read_band(size, ink, gray, y0, y1, templates, min_conf=0.80):
    w = size[0]
    sub = ink[y0:y1, 0:w]
    cols = glyph_columns(sub)
    if not cols:
        return []
    gaps = [cols[i + 1][0] - cols[i][1] for i in range(len(cols) - 1)]
    med_gap = float(np.median(gaps)) if gaps else 1.0
    space_gap = max(2.0, med_gap + 1.5)   # a word space beats a letter gap

    glyphs, prev_end = [], None
    for (a, b) in cols:
        col_bit = sub[:, a:b]
        ys = np.nonzero(col_bit.any(axis=1))[0]
        cov = gray[y0 + ys.min(): y0 + ys.max() + 1, a:b]
        ch, score, tsize, alts = best_match(cov, templates)
        if prev_end is not None and (a - prev_end) >= space_gap:
            glyphs.append({'char': ' ', 'space': True, 'score': 1.0,
                           'alts': [], 'x': prev_end, 'conf': 'ok'})
        glyphs.append({'char': ch if ch else '?', 'score': round(float(score), 3),
                       'alts': alts, 'space': False, 'size': tsize, 'x': a,
                       'conf': 'ok' if score >= min_conf else 'low'})
        prev_end = b
    return glyphs


# --------------------------------------------------------------------------
# second pass: repair against the known overlay vocabulary
# --------------------------------------------------------------------------
def _tokens(glyphs):
    """Group consecutive value glyphs into ('word', [indices]).

    '!' '[' ']' '|' are treated as part of a word on purpose: they are what a
    9-pixel render does to 'I', so treating them as separators would break
    every label that contains one ('L!F', 'Actlon!D', 'E]emNo').
    """
    VALID = r'[A-Za-z0-9!\[\]|]'
    out, cur = [], []
    for i, g in enumerate(glyphs):
        ch = g['char'] or ''
        if g['space'] or not re.match(VALID, ch):
            if cur:
                out.append(('word', cur))
                cur = []
            if not g['space']:
                out.append(('sep', [i]))
        else:
            cur.append(i)
    if cur:
        out.append(('word', cur))
    return out


# how close a runner-up digit has to be before we trust it over a letter
ALT_MARGIN = 0.02


def _looks_numeric(glyphs, idxs, prev_label=None):
    """Is this token a number we are allowed to correct towards digits?

    A token that already contains a digit is easy ('1DUU' -> '1000'). A token
    with no digit at all ('BBB' -> '888', 'D' -> '0') is only trusted when it
    follows a label whose value really is numeric -- otherwise this pass would
    happily rewrite 'Type: S' as 'Type: 5'.
    """
    chars = ''.join((glyphs[i]['char'] or '') for i in idxs)
    if not chars:
        return False
    if any(c.isdigit() for c in chars):
        return True
    if not prev_label or prev_label in LETTER_VALUE_LABELS:
        return False
    return all(any(a[0].isdigit() for a in glyphs[i]['alts']) for i in idxs)


def repair_row(glyphs):
    """Return (repaired_text, notes). Prefers close-scoring alternatives."""
    notes = []
    chars = [g['char'] for g in glyphs]
    out = list(chars)
    prev_label = None

    for kind, idxs in _tokens(glyphs):
        if kind != 'word':
            continue
        word = ''.join(chars[i] for i in idxs)
        # 1) restore a known label -- these words are known in advance
        if len(word) >= 2:
            hit = None
            close = difflib.get_close_matches(word, LABELS, n=1, cutoff=0.6)
            if close and len(close[0]) == len(word):
                hit = close[0]
            elif len(word) >= 3:
                # Only fall back to canonicalising '!'->'I' when the token
                # really looks like a word: two letters that survived the
                # render intact. Without this guard a value like '1D' would be
                # "repaired" into the label 'ID'.
                canon = _canon(word)
                if word != canon:
                    src = {'!', '[', ']', '|', '1', 'l'}
                    kept = [c for c in word if c.isalpha() and c not in src]
                    if len(kept) >= 2:
                        close = difflib.get_close_matches(canon, LABELS, n=1,
                                                          cutoff=0.6)
                        if close and len(close[0]) == len(word):
                            hit = close[0]
            if hit:
                for off, c in enumerate(hit):
                    out[idxs[off]] = c
                if hit != word:
                    notes.append('%s->%s' % (word, hit))
                prev_label = hit
                continue
            prev_label = word
        # 2) a value: prefer a digit alternative when the pixels nearly said it
        if _looks_numeric(glyphs, idxs, prev_label):
            before = ''.join(out[i] for i in idxs)
            for i in idxs:
                top = glyphs[i]['score']
                digits = [a for a in glyphs[i]['alts'] if a[0].isdigit()]
                if digits and digits[0][1] >= top - ALT_MARGIN:
                    out[i] = digits[0][0]
            after = ''.join(out[i] for i in idxs)
            if after != before:
                notes.append('%s->%s' % (before, after))
    return ''.join(c if c else '?' for c in out), notes


def read_frame(path, templates, minrow=2, min_conf=0.80):
    size, ink, gray = load_ink(path)
    rows = []
    for (y0, y1) in ink_bands(ink, minrow=minrow):
        glyphs = read_band(size, ink, gray, y0, y1, templates, min_conf)
        rows.append({'y0': y0, 'y1': y1 - 1, 'glyphs': glyphs})
    return size, rows


# --------------------------------------------------------------------------
def main():
    argv = sys.argv[1:]
    if not argv:
        print(__doc__)
        return 0
    path = argv[0]

    def val(name, default=None):
        return argv[argv.index(name) + 1] if name in argv else default

    font_path = val('--font', DEFAULT_FONT)
    minrow = int(val('--minrow', 2))
    verbose = '--verbose' in argv
    templates = build_templates(font_path)

    # batch mode: a directory -> every png inside it, in name order
    if os.path.isdir(path):
        files = sorted(f for f in os.listdir(path) if f.lower().endswith('.png'))
        print('dir   : %s   %d png(s)' % (path, len(files)))
        for f in files:
            print('\n' + '-' * 78)
            size, rows = read_frame(os.path.join(path, f), templates,
                                    minrow=minrow)
            print('file  : %s   %dx%d' % (f, size[0], size[1]))
            _print_rows(rows, verbose)
        return 0

    size, rows = read_frame(path, templates, minrow=minrow)
    print('file  : %s   %dx%d   templates=%d' % (path, size[0], size[1],
                                                 len(templates)))
    _print_rows(rows, verbose)
    return 0


def _print_rows(rows, verbose=False):
    for r in rows:
        glyphs = r['glyphs']
        raw = ''.join(g['char'] if g['char'] else '?' for g in glyphs)
        if not raw.strip(' ?'):
            continue
        lows = sum(1 for g in glyphs if g.get('conf') == 'low')
        print('  y=%4d..%-4d%s' % (r['y0'], r['y1'],
                                   '  (%d low-confidence)' % lows if lows else ''))
        print('      raw     : %s' % raw)
        fixed, notes = repair_row(glyphs)
        if fixed != raw:
            print('      repaired: %s' % fixed)
            print('      changes  : %s' % ' '.join(notes))
        if verbose:
            for g in glyphs:
                print('        x=%4d %-3r %.3f  alts=%s'
                      % (g['x'], g['char'], g['score'], g['alts'][:3]))


if __name__ == '__main__':
    sys.exit(main())
