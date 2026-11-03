"""Audit a character's whole moveset for the mistakes this project has already made.

Every check here exists because the mistake it catches was shipped at least
once, and most of them produce no error in the engine -- the move simply does
nothing, or looks wrong, and nothing complains:

- a projectile whose animation has no hitbox deals no damage at all
- a projectile can fly clear over the opponent's hurtbox and never connect
- a frame with no hurtbox declared is invulnerable, whether intended or not
- a hitDef guarded by an animElem that has no hitbox never fires
- a move with no recovery cannot be punished, which removes the punish layer
- an effect frame mapped where a character frame belongs looks like a smear

Usage: python tools/audit_moveset.py [character_directory]
Exits 0 when clean, 1 when it finds something.

Every box coordinate is converted to world units with the character's **own**
[Size] xscale, read from its .const. It used to be a hardcoded 0.48 (Archer's
value), which silently scaled every other character by 0.48 and produced five
bogus "projectile never connects" reports for test_fighter_b (2026-11-03).
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kofassets import air as airmod, sff  # noqa: E402

TARGET = sys.argv[1] if len(sys.argv) > 1 else "game/chars/archer"
from kofassets import air as airmod, sff
AIR_PATH = os.path.join(TARGET, os.path.basename(TARGET) + ".air")
SFF_PATH = os.path.join(TARGET, os.path.basename(TARGET) + ".sff")
A = airmod.Air.load(AIR_PATH); S = sff.Sff.load(SFF_PATH)


def _read_xscale(char_dir, name):
    """[Size] xscale 从角色自己的 .const 读 —— 绝不硬编码。

    2026-11-03：原本写死 0.48（Archer 的值），对其他角色会把所有判定框
    按 0.48 缩放，于是 test_fighter_b 的 5 条投射物检查全是假警报。
    缩放规则见 char.go:updateClsnScale()。
    """
    const = os.path.join(char_dir, name + '.const')
    if not os.path.isfile(const):
        return 1.0
    sect = None
    with open(const, encoding='utf-8', errors='replace') as fh:
        for raw in fh:
            line = raw.split(';', 1)[0].strip()
            m = re.match(r'^\[(.+)\]$', line)
            if m:
                sect = m.group(1).strip().lower()
                continue
            if sect == 'size' and '=' in line:
                k, v = line.split('=', 1)
                if k.strip().lower() == 'xscale':
                    try:
                        return float(v.strip())
                    except ValueError:
                        return 1.0
    return 1.0


SC = _read_xscale(TARGET, os.path.basename(TARGET))
AIR = open(AIR_PATH, encoding="utf-8").read()
ZS  = open(os.path.join(TARGET, os.path.basename(TARGET) + ".zss"), encoding="utf-8").read()
issues = []
def bad(w, d): issues.append((w, d))
ys = []
for ln in re.search(r"\[Begin Action 0\]\n([\s\S]*?)(?=\n\[Begin Action)", AIR).group(1).split("\n"):
    m = re.match(r"^\s*Clsn2\[[0-9]+\]\s*=\s*(-?[0-9]+)\s*,\s*(-?[0-9]+)\s*,\s*(-?[0-9]+)\s*,\s*(-?[0-9]+)", ln)
    if m: v=[int(x)*SC for x in m.groups()]; ys += [v[1],v[3]]
LO, HI = min(ys), max(ys)
states = {}
for m in re.finditer(r"\[StateDef ([0-9]+);", ZS):
    st = int(m.group(1)); seg = ZS[m.end():]
    nxt = re.search(r"\n\[StateDef ", seg); seg = seg[:nxt.start()] if nxt else seg
    am = re.search(r"\banim:[ ]*([0-9]+)", seg)
    states[st] = dict(anim=int(am.group(1)) if am else None, seg=seg,
        dmg=re.findall(r"damage:[ ]*([0-9]+)", seg),
        proj=re.findall(r"projanim:[ ]*([0-9]+)", seg),
        off=re.findall(r"offset:[ ]*(-?[0-9]+)[ ]*,[ ]*(-?[0-9]+)", seg),
        vel=re.findall(r"velocity:[ ]*(-?[0-9.]+)[ ]*,[ ]*(-?[0-9.]+)", seg))
for st, d in sorted(states.items()):
    for pj in d['proj']:
        a = A.action(int(pj))
        if not a: bad("投射物动画缺失", "状态 %d projanim %s 不存在" % (st, pj)); continue
        bs = [b for e in a.elements for b in e.clsn1]
        if not bs: bad("投射物无判定框", "projanim %s（状态 %d）无 Clsn1 → 不造成伤害" % (pj, st)); continue
        vy = float(d['vel'][0][1]) if d['vel'] else 0.0
        if vy > 0: continue
        top = min(min(b.top,b.bottom) for b in bs)*SC; bot = max(max(b.top,b.bottom) for b in bs)*SC
        oy = int(d['off'][0][1]) if d['off'] else 0
        if (oy+bot) < LO or (oy+top) > HI:
            bad("投射物打不到人", "projanim %s 飞行 %.0f~%.0f 不重叠受击框" % (pj, oy+top, oy+bot))
MELEE = [200,210,230,240,400,410,430,440,600,610,630,640,1100,1150,1200,1300,1400]
for st in MELEE:
    d = states.get(st)
    if not d or not d['anim']: continue
    a = A.action(d['anim'])
    if not a: bad("动画缺失", "状态 %d anim %s 不存在" % (st, d['anim'])); continue
    act_i = [e.index for e in a.elements if e.clsn1]
    if not act_i: bad("无判定框", "状态 %d（anim %d）无 Clsn1" % (st, d['anim'])); continue
    k0, k1 = min(act_i), max(act_i)
    tp = sum(e.time for e in a.elements if e.time>0 and e.index<k0)
    ta = sum(e.time for e in a.elements if e.time>0 and k0<=e.index<=k1)
    tr = sum(e.time for e in a.elements if e.time>0 and e.index>k1)
    if tr < 4: bad("收招过短", "状态 %d 收招 %d tick" % (st, tr))
    if ta < 2: bad("判定过薄", "状态 %d 判定 %d tick" % (st, ta))
    if tp == 0: bad("无起手", "状态 %d 起手 0 tick（瞬发）" % st)
    for m in re.finditer(r"if animElem = ([0-9]+)[^{]*\{([\s\S]{0,200}?)\}", d['seg']):
        if ("hitDef" in m.group(2) or "projectile" in m.group(2)) and int(m.group(1)) not in act_i:
            bad("判定帧错位", "状态 %d hitDef 在 animElem=%s，判定帧是 %s" % (st, m.group(1), act_i))
    if not d['dmg']: bad("无伤害值", "状态 %d 无 damage 行" % st)
    if st not in (110,115,117):
        nc = [e.index for e in a.elements if not e.clsn2]
        if nc: bad("受击框缺口", "状态 %d 第 %s 帧无受击框" % (st, nc))
    a2 = A.action(d['anim']); far = 0
    for e in a2.elements:
        sp = S.sprite(e.group, e.image)
        if not sp: continue
        rgba,_ = S.rgba(sp)
        for y in range(sp.height):
            row=y*sp.width*4
            for x in range(182, sp.width):
                if rgba[row+x*4+3]>128: far=max(far,(x-sp.axis_x)*SC); break
    bx = max(max(b.left,b.right)*SC for e in a2.elements for b in e.clsn1)
    if far>0 and (bx < far*0.6 or bx > far*1.9):
        bad("判定框与素材不符", "状态 %d 框 %.0f vs 素材 %.0f" % (st, bx, far))
for st, d in sorted(states.items()):
    if st in (110,115,117) or not d['anim']: continue
    a = A.action(d['anim'])
    if not a or not a.elements: continue
    for e in a.elements:
        sp = S.sprite(e.group, e.image)
        if not sp: continue
        rgba,_ = S.rgba(sp)
        tot = sum(1 for p in range(0,len(rgba),4) if rgba[p+3]>128)
        fill = tot/(sp.width*sp.height)
        if not (0.15 <= fill <= 0.65):
            bad("疑似特效帧", "状态 %d（anim %d）某帧填充%.0f%% %dx%d" % (st, d['anim'], fill*100, sp.width, sp.height))
# --- 投技必须有伤害：grab 型 hitDef 少了 damage 就是抓住但不掉血 ---
for m in re.finditer(r"\[StateDef ([0-9]+);([\s\S]*?)(?=\n\[StateDef |\Z)", ZS):
    st = int(m.group(1)); seg = m.group(2)
    if "hitflag: M-" in seg and "damage:" not in seg:
        bad("投技无伤害", "状态 %d 是抓投（hitflag: M-）但没有 damage 行 → 抓住却不掉血" % st)

print("=== 体检: %s ===" % TARGET)
for w,d in issues: print("  [%s] %s" % (w,d))
print("共 %d 项" % len(issues))
sys.exit(1 if issues else 0)
