# -*- coding: utf-8 -*-
"""Print (and check) a character's frame data: startup / active / recovery / frame advantage.

Why this exists
---------------
Two whole classes of "the move feels wrong" complaints are pure arithmetic, and
neither shows up in any existing check:

1. **Hit advantage.** After a hit lands, the defender regains control after
   ``hittime`` ticks; the attacker regains control when the animation ends.
   The difference decides whether *any* combo can exist:

       adv_hit = hittime - (total - startup - 1)

   Hitpause freezes both sides for the same number of ticks, so it cancels out.
   A negative number means "I hit him and he gets to act first" -- which reads
   to a player as "his moves stun me for three hits, mine stun him for none".

2. **Hitbox vs artwork.** A box that is shorter than the drawn blade produces
   "the sword clearly went through him" with no damage, and no tool complains.

Usage
-----
    python tools/frame_data.py [character_dir]
    python tools/frame_data.py game/chars/archer --check

``--check`` exits 1 when a ground normal has negative hit advantage or a hitbox
shorter than the artwork it is supposed to represent. Everything is computed
from the character's own files; the scale comes from [Size] xscale, never
hardcoded.

Frame data convention (60 ticks = 1 second):
  startup  ticks before the first hitbox frame
  active   ticks in which a hitbox exists
  recovery ticks after the last hitbox frame (total - startup - active)
  total    the whole animation: EndState() fires when animTime = 0
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kofassets import air as airmod          # noqa: E402
from kofassets import sff as sffmod          # noqa: E402


def read_ini_sections(path):
    """Very small INI reader: {section_lower: {key_lower: value}} with comments stripped."""
    out = {}
    cur = None
    with open(path, encoding='utf-8', errors='replace') as fh:
        for raw in fh:
            line = raw.split(';', 1)[0].strip()
            if not line:
                continue
            m = re.match(r'^\[(.+)\]$', line)
            if m:
                cur = m.group(1).strip().lower()
                out.setdefault(cur, {})
                continue
            if cur is None or '=' not in line:
                continue
            k, v = line.split('=', 1)
            out[cur][k.strip().lower()] = v.strip()
    return out


def char_files(char_dir):
    """Resolve cns / air / sprite paths from the .def, falling back to <name>.*."""
    name = os.path.basename(os.path.normpath(char_dir))
    def_path = os.path.join(char_dir, name + '.def')
    files = {}
    if os.path.isfile(def_path):
        files = read_ini_sections(def_path).get('files', {})
    def pick(key, ext):
        v = files.get(key)
        if v:
            p = os.path.join(char_dir, v)
            if os.path.isfile(p):
                return p
        p = os.path.join(char_dir, name + ext)
        return p if os.path.isfile(p) else None
    return pick('cns', '.const'), pick('anim', '.air'), pick('sprite', '.sff')


def read_xscale(cns_path):
    if not cns_path:
        return 1.0
    size = read_ini_sections(cns_path).get('size', {})
    try:
        return float(size.get('xscale', 1.0))
    except ValueError:
        return 1.0


def parse_states(zss_text):
    """{state: {'anim': int, 'hitdef': {...}, 'attacks': [...]}} for every StateDef."""
    out = {}
    blocks = re.split(r'\n(?=\[StateDef )', zss_text)
    for b in blocks:
        m = re.match(r'\[StateDef (\d+);', b)
        if not m:
            continue
        st = int(m.group(1))
        am = re.search(r'\banim:\s*(-?\d+)', b)
        rec = {'state': st, 'anim': int(am.group(1)) if am else None, 'hitdefs': []}
        for hd in re.finditer(r'hitDef\{(.*?)\n\s*\}', b, re.S):
            body = hd.group(1)

            def num(key, default=None):
                mm = re.search(key + r'\s*:\s*(-?\d+)', body)
                return int(mm.group(1)) if mm else default
            rec['hitdefs'].append({
                'hittime': num(r'ground\.hittime'),
                'airhittime': num(r'air\.hittime'),
                'slidetime': num(r'ground\.slidetime'),
                'pausetime': num(r'pausetime'),
                'damage': num(r'damage'),
                'guardflag': (re.search(r'guardflag\s*:\s*(\w*)', body) or [None, ''])[1]
                if re.search(r'guardflag\s*:\s*(\w*)', body) else '',
            })
        out[st] = rec
    return out


def atlas_tip_px(sff, key, cache):
    """Rightmost opaque pixel column of a sprite, in sprite pixels (0-based)."""
    if key in cache:
        return cache[key]
    sp = next((s for s in sff.sprites if (s.group, s.number) == key), None)
    tip = None
    if sp is not None:
        rgba, _ = sff.rgba(sp, 0)
        w, h = sp.width, sp.height
        for x in range(w - 1, -1, -1):
            col = rgba[x * 4:(h - 1) * w * 4 + x * 4 + 4: w * 4]
            if any(col):
                tip = x
                break
    cache[key] = tip
    return tip


def main(argv):
    args = [a for a in argv[1:] if not a.startswith('--')]
    check = '--check' in argv
    char_dir = args[0] if args else os.path.join('game', 'chars', 'archer')
    cns, air_path, sff_path = char_files(char_dir)
    if not air_path:
        print('!! no .air found for %s' % char_dir)
        return 2

    xscale = read_xscale(cns)
    air = airmod.Air.load(air_path)
    sff = sffmod.Sff.load(sff_path) if sff_path and os.path.isfile(sff_path) else None
    zss_name = char_files(char_dir)[0]
    zss_path = os.path.join(char_dir, os.path.basename(os.path.normpath(char_dir)) + '.zss')
    if not os.path.isfile(zss_path):
        print('!! no .zss found for %s' % char_dir)
        return 2
    states = parse_states(open(zss_path, encoding='utf-8', errors='replace').read())

    print('# %s — frame data (xscale = %.4g)' % (os.path.basename(os.path.normpath(char_dir)), xscale))
    print()
    print('| state | anim | total | startup | active | recovery | hittime | adv_hit | damage | 刀尖(世界) | Clsn1(世界) | 框 vs 画面 |')
    print('|---|---|---|---|---|---|---|---|---|---|---|---|')
    problems = []
    tip_cache = {}
    for st, rec in sorted(states.items()):
        if not rec['hitdefs'] or rec['anim'] is None:
            continue
        act = air.by_number.get(rec['anim'])
        if act is None:
            continue
        # Only the animation elements with a hitbox matter for the frame data.
        frames = act.elements
        hit_idx = [i for i, el in enumerate(frames) if el.clsn1]
        if not hit_idx:
            continue
        total = sum(el.time for el in frames)
        startup = sum(el.time for el in frames[:hit_idx[0]])
        active = sum(frames[i].time for i in hit_idx)
        recovery = total - startup - active
        hd = rec['hitdefs'][0]
        ht = hd['hittime']
        adv = None if ht is None else ht - (total - startup - 1)

        art_tip = 0.0
        if sff is not None:
            for i in hit_idx:
                el = frames[i]
                tip = atlas_tip_px(sff, (int(el.sprite[0]), int(el.sprite[1])), tip_cache)
                if tip is not None:
                    sp = next(s for s in sff.sprites
                              if (s.group, s.number) == (int(el.sprite[0]), int(el.sprite[1])))
                    art_tip = max(art_tip, (tip - sp.axis_x) * xscale)
        box = max((b.right for i in hit_idx for b in frames[i].clsn1), default=0) * xscale
        delta = box - art_tip
        verdict = 'ok'
        if sff is not None and delta < -2:
            verdict = '**短 %.1f**' % (-delta)
            problems.append('%s: hitbox is %.1f units shorter than the artwork' % (st, -delta))
        if adv is not None and st < 600 and adv < 0:
            # 只查地面普通技。空中招（600~699）落地前本来就不可能连段，
            # 负帧优势是"跳进去要付代价"的一部分，不该当成缺陷。
            problems.append('%s: negative hit advantage (%d)' % (st, adv))
            verdict += ' **adv<0**'
        print('| %d | %d | %d | %d | %d | %d | %s | %s | %s | %.1f | %.1f | %s |' % (
            st, rec['anim'], total, startup, active, recovery,
            '' if ht is None else ht,
            '' if adv is None else adv,
            hd['damage'],
            art_tip, box, verdict))

    print()
    print('adv_hit = hittime - (total - startup - 1)  正 = 打中后你先能动（能接招）')
    print('刀尖 = 判定帧里画面实际伸到的最远处；框 vs 画面为负表示框比画面短')
    if check:
        print()
        if problems:
            print('FAIL (%d)' % len(problems))
            for p in problems:
                print('  - ' + p)
            return 1
        print('PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
