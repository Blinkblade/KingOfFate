#!/usr/bin/env python3
"""Read the per-phase screenshots produced by tests/p6/demo_moves.ps1.

For every `<prefix>_pNN_<keys>_after.png` still, read the engine's debug
overlay (the harness enables it with Ctrl+D) and pick out the two rows that
matter:

    ActionID: <anim> (P1); SPR: <g>.<i>; ElemNo: ...; Time: ...
    State No: <state> (P1); CTRL: ...; Type: ...; MoveType: ...

then join them with the legend file that maps phase numbers to the move that
was injected, and say whether that move's state actually came out.

Nothing here looks at a sprite by eye: the verdict is a string comparison
between the state/animation readout and the state the command routes to (the
routing table was read out of emiya.cmd, see docs/evidence/p6/).

Reads the overlay in-process via tools/read_frame_text.py (its glyph templates
are built once and reused), so it is fast enough for a few hundred stills.
That also means this script needs the same dependencies as read_frame_text.py:
numpy + Pillow. Run it with an interpreter that has them:

    D:/Anaconda/python.exe tests/p6/read_move_evidence.py logs/p6/moves --all --only-moves

Usage:
    python tests/p6/read_move_evidence.py logs/p6/moves --all
    python tests/p6/read_move_evidence.py logs/p6/moves p6m_s1 --only-moves
"""

from __future__ import annotations

import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools"))

try:
    import read_frame_text as rft
except ImportError as exc:                                       # pragma: no cover
    sys.stderr.write("cannot import tools/read_frame_text.py (%s).\n"
                     "Run this script with an interpreter that has numpy and "
                     "Pillow, e.g. D:/Anaconda/python.exe\n" % exc)
    raise SystemExit(3)

_TEMPLATES = None
_CROP_TMP = None


def overlay_text(png_path):
    """Return the overlay's text rows of one screenshot as a single string.

    The debug block lives in the bottom ~60 rows of the 1280x720 frame, so the
    image is cropped to that strip first: band detection then looks at four
    rows instead of fifteen, which is what makes a few hundred stills cheap
    enough to read.
    """
    global _TEMPLATES, _CROP_TMP
    if _TEMPLATES is None:
        _TEMPLATES = rft.build_templates(rft.DEFAULT_FONT)
    target = png_path
    try:
        from PIL import Image
        import tempfile
        if _CROP_TMP is None:
            _CROP_TMP = os.path.join(tempfile.gettempdir(), "p6_overlay_crop.png")
        with Image.open(png_path) as image:
            width, height = image.size
            strip = image.crop((0, max(0, height - 80), min(width, 1000), height))
            strip.save(_CROP_TMP)
        target = _CROP_TMP
    except Exception:                                            # noqa: BLE001
        target = png_path
    try:
        _size, rows = rft.read_frame(target, _TEMPLATES, minrow=2)
    except Exception as exc:                                     # noqa: BLE001
        return "", "%s: %s" % (type(exc).__name__, exc)
    lines = []
    for row in rows:
        raw = "".join(g["char"] if g["char"] else "?" for g in row["glyphs"])
        fixed, _notes = rft.repair_row(row["glyphs"])
        if raw.strip(" ?"):
            lines.append(raw)
        if fixed.strip(" ?") and fixed != raw:
            lines.append(fixed)
    return "\n".join(lines), ""

# The OCR of this font routinely confuses ':' with ';', '(' with 'l'/'I', and
# digits with similar letters. Map them back before comparing.
CHAR_FIX = str.maketrans({"O": "0", "o": "0", "I": "1", "l": "1", "|": "1",
                          "Z": "2", "z": "2", "B": "8", "S": "5", "G": "6",
                          "g": "9", "q": "9"})

# State(s) each injected move routes to, from emiya.cmd's [State -1] blocks.
EXPECTED_STATES = {
    "x_light_punch": {"200"},
    "y_heavy_punch": {"220"},
    "z_heavy_punch": {"250"},
    "a_light_kick": {"210"},
    "b_heavy_kick": {"230"},
    "traceP_D_D_x": {"1000"},
    "traceS_D_D_y": {"1002"},
    "traceK_D_D_a": {"1001"},
    "hassya_D_D_b": {"1005", "1011", "1021", "1031"},
    "taikuuS_623_y": {"1050"},
    "taikuuHS_623_b": {"1051"},
    "yumiS_41236_y": {"1101", "1150"},
    "yumiHS_41236_b": {"1100", "1102"},
    "kakato_214_a": {"1200"},
    "kusari_2141236_b": {"1300"},
    "ComboRash_2141236_y": {"3100"},
    "tokusyu_F_b": {"240"},
    "tuika_FF_c": {"852"},
    "nage_F_c": {"800", "850"},
    "nage_b_B_c": {"800", "850"},
    "UBW_41236_x": {"3300", "3301"},
    "UBW_S_41236_z": {"3320"},
    "UBW_R_41236_a": {"3500"},
    "UBWX_236236_z": {"3900"},
    "RO_236236_x": {"3700", "3701"},
    "DC_236236_a": {"3400"},
    # AIR is wired only as a cancel (state 3200, entered from 1051/1150/1200 on
    # contact), so a neutral input is expected NOT to reach it.
    "AIR_236236_y": {"3200"},
    "FF_dash": {"8", "100"},
    "BB_backhop": {"9", "105"},
    "BREAK_back_x_a": {"1050", "3701"},
}


def _digits(token):
    return token.translate(CHAR_FIX)


def extract_fields(overlay_text):
    """Pull ActionID / State No / SPR / character out of the overlay text."""
    fields = {}
    m = re.search(r"ActionID[;:,\s]*([0-9A-Za-z]{1,6})", overlay_text)
    if m:
        value = _digits(m.group(1))
        if value.isdigit():
            fields["action"] = value
    m = re.search(r"State No[;:,\s]*([0-9A-Za-z]{1,6})", overlay_text)
    if m:
        value = _digits(m.group(1))
        if value.isdigit():
            fields["state"] = value
    m = re.search(r"SPR[;:,\s]*([0-9A-Za-z]{1,5})\s*[.,;:]\s*([0-9A-Za-z]{1,5})",
                  overlay_text)
    if m:
        fields["spr"] = "%s.%s" % (_digits(m.group(1)), _digits(m.group(2)))
    m = re.search(r"^([A-Za-z0-9 _]+),\s*Player\s*(\d)", overlay_text, re.M)
    if m:
        fields["char"] = m.group(1).strip()
    return fields


def load_legend(prefix, folder):
    path = os.path.join(folder, "%s_legend.txt" % prefix)
    moves = {}
    if not os.path.exists(path):
        return moves
    with open(path, "r", encoding="utf-8-sig") as handle:
        for line in handle:
            m = re.match(r"^(\d\d) = (.*?)(?:\s+\[(.*)\])?\s*$", line.rstrip("\n"))
            if not m:
                continue
            moves[int(m.group(1))] = {"keys": m.group(2).strip(),
                                      "move": (m.group(3) or "").strip()}
    return moves


def read_per_move(folder, args):
    """One engine run per move: shots are `<prefix>_NN.png` in `folder`."""
    index_path = os.path.join(folder, "moves_index.txt")
    if not os.path.exists(index_path):
        print("no moves_index.txt in %s -- nothing to read" % folder)
        return 1
    # The move list comes from the shots themselves: moves_index.txt is
    # rewritten by every demo run, so with -Only it only lists that one move.
    names = []
    with open(index_path, "r", encoding="utf-8-sig") as handle:
        for line in handle:
            parts = line.rstrip("\n").split("\t")
            if parts and parts[0].strip():
                names.append(parts[0].strip())
    seen_prefixes = sorted({re.sub(r"^p6mv_|_\d\d\.png$", "", f)
                            for f in os.listdir(folder)
                            if re.match(r"^p6mv_.+_\d\d\.png$", f)})
    if seen_prefixes:
        # keep the index order first, then anything else that has shots
        names = names + [n for n in seen_prefixes if n not in names]

    print("%-26s %-9s %-30s %s" % ("move", "verdict", "observed state/anim", "frames"))
    fired, missed = [], []
    for name in names:
        if args.names and name not in args.names:
            continue
        prefix = "p6mv_%s" % name
        shots = sorted(f for f in os.listdir(folder)
                       if re.match(r"^%s_\d\d\.png$" % re.escape(prefix), f))
        expected = EXPECTED_STATES.get(name)
        seen_states, seen_anims, used = [], [], 0
        hit = None
        for shot in shots:
            text, err = overlay_text(os.path.join(folder, shot))
            if err:
                continue
            used += 1
            fields = extract_fields(text)
            state, action = fields.get("state"), fields.get("action")
            if state:
                seen_states.append(state)
            if action:
                seen_anims.append(action)
            if expected and hit is None:
                if (state and state in expected):
                    hit = "state %s" % state
                elif (action and action in expected):
                    hit = "anim %s" % action
        observed = "state=%s anim=%s" % (
            ",".join(dict.fromkeys(seen_states)) or "-",
            ",".join(dict.fromkeys(seen_anims)) or "-")
        if hit:
            verdict = "FIRED"
            fired.append((name, hit))
        else:
            verdict = "NOT SEEN"
            missed.append((name, observed))
        print("%-26s %-9s %-30s %d" % (name, verdict, observed[:30], used))

    print()
    print("== summary: %d fired, %d not seen" % (len(fired), len(missed)))
    for name, hit in fired:
        print("  FIRED  %-26s %s" % (name, hit))
    for name, observed in missed:
        print("  MISSED %-26s (%s)" % (name, observed))
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("folder")
    parser.add_argument("prefixes", nargs="*")
    parser.add_argument("--all", action="store_true", help="every prefix in the folder")
    parser.add_argument("--per-move", action="store_true",
                        help="read one-run-per-move shots (see moves_index.txt)")
    parser.add_argument("--names", nargs="*", default=None,
                        help="restrict the per-move reader to these move names")
    parser.add_argument("--only-moves", action="store_true", help="skip fill/wait phases")
    args = parser.parse_args(argv)

    if args.per_move:
        return read_per_move(args.folder, args)

    folder = args.folder
    prefixes = args.prefixes
    if args.all or not prefixes:
        prefixes = sorted({f.split("_p")[0] for f in os.listdir(folder)
                           if re.match(r"^p6m_s\d+_p\d\d_", f)})

    summary = []
    for prefix in prefixes:
        legend = load_legend(prefix, folder)
        shots = sorted(f for f in os.listdir(folder)
                       if f.startswith(prefix + "_p") and f.endswith("_after.png"))
        if not shots:
            print("== %s: no phase stills found\n" % prefix)
            continue
        print("== %s  (%d phase stills)" % (prefix, len(shots)))
        print("%-4s %-20s %-30s %-8s %-7s %s" %
              ("ph", "keys", "move", "ActionID", "State", "verdict"))
        for shot in shots:
            index = int(re.match(r"^%s_p(\d\d)_" % re.escape(prefix), shot).group(1))
            info = legend.get(index, {})
            move = info.get("move", "")
            if args.only_moves and not move:
                continue          # do not spend an OCR pass on a wait phase
            text, err = overlay_text(os.path.join(folder, shot))
            fields = extract_fields(text)
            action = fields.get("action", "?")
            state = fields.get("state", "?")
            note = ""
            if move:
                expected = EXPECTED_STATES.get(move)
                if not expected:
                    note = "observed state=%s anim=%s (no expectation recorded)" % (state, action)
                elif action in expected or state in expected:
                    hit = action if action in expected else state
                    note = "FIRED (state/anim %s)" % hit
                    summary.append((prefix, move, hit))
                elif action == "?" and state == "?":
                    note = "unreadable readout"
                else:
                    note = "NOT SEEN: state=%s anim=%s, expected %s" % (
                        state, action, "/".join(sorted(expected)))
                    summary.append((prefix, move, None))
            print("%-4d %-20s %-30s %-8s %-7s %s" %
                  (index, info.get("keys", "?")[:20], (move or "(wait)")[:30],
                   action, state, note))
            if err:
                print("     reader error: %s" % err[:100])
        print()

    if summary:
        print("== summary")
        fired = [s for s in summary if s[2]]
        missed = [s for s in summary if not s[2]]
        for prefix, move, hit in fired:
            print("  FIRED  %-24s %s" % (move, hit))
        for prefix, move, _ in missed:
            print("  MISSED %-24s (%s)" % (move, prefix))
        print("  %d fired, %d not seen" % (len(fired), len(missed)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
