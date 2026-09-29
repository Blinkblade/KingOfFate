#!/usr/bin/env python3
"""airtool -- read a character's animation table, and validate it against its SFF.

    python tools/airtool/airtool.py inspect  <file.air> [--action N] [--json] [--all-elements]
    python tools/airtool/airtool.py validate <file.air> [--sff FILE.sff] [--json] [--strict]

Read-only: nothing is written, ever. ``validate`` reports; it does not repair.

The collision columns are the point of this tool. ``Clsn1``/``Clsn2`` apply to the
single element that follows them, ``Clsn1Default``/``Clsn2Default`` to every element
of the action -- so a projectile animation whose attack box comes from ``Clsn1``
shows ``per-frame`` on one element and ``none`` on the ``-1`` hold frame, which is
exactly the P4 bug. Modes are printed per element as
``default`` / ``per-frame`` / ``cleared`` / ``none``.

Exit codes: see kofassets/report.py.
"""

from __future__ import annotations

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from kofassets import air as air_mod  # noqa: E402
from kofassets import checks, report, sff as sff_mod  # noqa: E402
from kofassets.report import (EXIT_CORRUPT, EXIT_FINDINGS, EXIT_IO,  # noqa: E402
                              EXIT_OK, EXIT_UNSUPPORTED, EXIT_USAGE)


def load_air(path):
    if not os.path.exists(path):
        raise _Abort(EXIT_IO, "no such file: %s" % path)
    if os.path.isdir(path):
        raise _Abort(EXIT_IO, "%s is a directory, expected an .air file" % path)
    try:
        return air_mod.Air.load(path)
    except air_mod.AirError as exc:
        raise _Abort(EXIT_CORRUPT, str(exc))


class _Abort(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code
        self.message = message


def fail(code, message, hint=None):
    print("ERROR: %s" % message, file=sys.stderr)
    if hint:
        print("       %s" % hint, file=sys.stderr)
    return code


def find_sff_for(air_path, explicit=None):
    """Locate the SFF that belongs to this .air.

    Explicit path wins. Otherwise the sibling file with the same stem is used,
    which is how every character in this project is laid out
    (test_fighter_b.air next to test_fighter_b.sff).
    """
    if explicit:
        return explicit, True
    stem = os.path.splitext(air_path)[0]
    candidate = stem + ".sff"
    if os.path.exists(candidate):
        return candidate, False
    return None, False


def raise_on_sff_problem(path):
    try:
        return sff_mod.Sff.load(path)
    except sff_mod.SffUnsupportedError as exc:
        raise _Abort(EXIT_UNSUPPORTED, str(exc))
    except (sff_mod.SffFormatError, sff_mod.SffCorruptError) as exc:
        raise _Abort(EXIT_CORRUPT, str(exc))


# ---------------------------------------------------------------------------
# inspect
# ---------------------------------------------------------------------------


def cmd_inspect(args):
    try:
        air = load_air(args.file)
    except _Abort as abort:
        return fail(abort.code, abort.message)

    actions = air.group_actions() if args.all_elements else air.group_actions()
    selected = [a for a in actions if args.action is None or a.number in args.action]
    if args.action:
        missing = sorted(set(args.action) - {a.number for a in actions})
        if missing:
            return fail(EXIT_FINDINGS,
                        "action(s) %s are not in %s" % (", ".join(str(m) for m in missing),
                                                        args.file),
                        "run without --action to list what the file defines")

    if args.json:
        payload = {
            "file": air.path,
            "lines": air.line_count,
            "encoding": air.encoding,
            "action_count": len(air.actions),
            "unique_actions": len(air.by_number),
            "duplicate_actions": sorted(set(air.duplicates)),
            "actions": [a.to_dict(include_elements=bool(args.action)) for a in selected],
        }
        report.emit_json(payload)
        return EXIT_OK

    print("File:     %s" % air.path)
    print("Lines:    %d" % air.line_count)
    print("Actions:  %d  (%d unique numbers)" % (len(air.actions), len(air.by_number)))
    if air.duplicates:
        print("Duplicate action numbers: %s" % sorted(set(air.duplicates)))
    print("")

    if args.action:
        for action in selected:
            _print_action_detail(action)
    else:
        print("  action elements  ticks  duration   loopstart  clsn1 modes")
        print("  ------ --------  -----  ---------  ---------  --------------------------")
        for action in selected:
            duration = "infinite" if action.total_ticks is None else str(action.total_ticks)
            modes = sorted({e.clsn1_mode for e in action.elements})
            print("  %6d %8d  %5d  %-9s  %-9s  %s"
                  % (action.number, action.element_count, action.finite_ticks, duration,
                     "-" if action.loopstart is None else action.loopstart,
                     ",".join(modes) or "-"))
        print("")
        print("  'ticks' is the sum of positive element times; 'infinite' means the action")
        print("  contains a -1 hold, so it has no finite duration.")

    if air.problems:
        print("")
        for problem in air.problems:
            print(problem.format())
    return EXIT_OK


def _print_action_detail(action):
    duration = "infinite (has a -1 hold)" if action.total_ticks is None \
        else "%d ticks" % action.total_ticks
    print("Action %d   (line %d)" % (action.number, action.line))
    print("  Elements:  %d" % action.element_count)
    print("  Duration:  %s" % duration)
    print("  Infinite element: %s" % ("yes" if action.has_infinite_frame else "no"))
    print("  Finite ticks: %d" % action.finite_ticks)
    if action.loopstart is not None:
        print("  Loopstart: element %d" % action.loopstart)
    if action.copy_action is not None:
        print("  Copy action: %d" % action.copy_action)
    if action.interpolate:
        print("  Interpolation: %s" % ", ".join(sorted(set(action.interpolate))))
    print("")
    print("   elem  sprite    x    y  time  clsn1        n  clsn2        n")
    print("   ----  ------  ---  ---  ----  -----------  -  -----------  -")
    for element in action.elements:
        print("   %4d  %3d,%3d %4d %4d  %4d  %-11s  %d  %-11s  %d"
              % (element.index, element.group, element.image, element.x, element.y,
                 element.time, element.clsn1_mode, len(element.clsn1),
                 element.clsn2_mode, len(element.clsn2)))
    for element in action.elements:
        if element.clsn1:
            print("    element %d Clsn1: %s"
                  % (element.index, ", ".join("(%d,%d,%d,%d)" % (b.left, b.top, b.right, b.bottom)
                                              for b in element.clsn1)))
    for element in action.elements:
        if element.clsn2:
            print("    element %d Clsn2: %s"
                  % (element.index, ", ".join("(%d,%d,%d,%d)" % (b.left, b.top, b.right, b.bottom)
                                              for b in element.clsn2)))
    print("")


# ---------------------------------------------------------------------------
# validate
# ---------------------------------------------------------------------------


def cmd_validate(args):
    try:
        air = load_air(args.file)
    except _Abort as abort:
        return fail(abort.code, abort.message)

    rep = report.Report()
    rep.extend(checks.check_air_structure(air))

    sff_path, explicit = find_sff_for(air.path, args.sff)
    if sff_path is None:
        rep.warn("AIR_SFF_NOT_FOUND",
                 "no SFF found next to %s, so sprite references were not checked; pass --sff"
                 % os.path.basename(air.path), file=air.path)
    else:
        try:
            container = raise_on_sff_problem(sff_path)
        except _Abort as abort:
            return fail(abort.code, abort.message)
        rep.extend(checks.check_sprite_references(air, container))
        rep.info("AIR_SFF_USED",
                 "sprite references checked against %s (%d sprites)"
                 % (sff_path, container.sprite_count), file=air.path)

    rep.extend(checks.check_collision_semantics(air))

    counts = rep.summary()
    if args.json:
        report.emit_json({
            "file": air.path,
            "sff": sff_path,
            "action_count": len(air.actions),
            "summary": counts,
            "findings": [f.to_dict() for f in rep.sorted_findings()],
        })
    else:
        print("File:     %s" % air.path)
        print("Actions:  %d" % len(air.actions))
        if sff_path:
            print("SFF:      %s%s" % (sff_path, "" if explicit else "  (auto-detected)"))
        print("")
        report.print_findings(rep)
        if not rep.findings:
            print("no findings: the animation table is structurally clean")

    return rep.exit_code(strict=args.strict)


# ---------------------------------------------------------------------------
# entry point
# ---------------------------------------------------------------------------


def build_parser():
    parser = argparse.ArgumentParser(
        prog="airtool.py",
        description="Inspect .air animation tables and validate them against their SFF.")
    sub = parser.add_subparsers(dest="command")

    inspect = sub.add_parser("inspect", help="list actions, elements and collision modes")
    inspect.add_argument("file", help="path to the .air file")
    inspect.add_argument("--action", type=int, action="append", default=None,
                         help="show one action in full; repeatable")
    inspect.add_argument("--all-elements", action="store_true",
                         help="keep per-element data in --json output")
    inspect.add_argument("--json", action="store_true", help="machine-readable output")
    inspect.set_defaults(func=cmd_inspect)

    validate = sub.add_parser("validate", help="run the static animation checks")
    validate.add_argument("file", help="path to the .air file")
    validate.add_argument("--sff", default=None,
                          help="SFF to check sprite references against (default: sibling file)")
    validate.add_argument("--json", action="store_true", help="machine-readable output")
    validate.add_argument("--strict", action="store_true",
                          help="treat warnings as failures (exit 1)")
    validate.set_defaults(func=cmd_validate)

    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)
    if not getattr(args, "func", None):
        parser.print_help()
        return EXIT_USAGE
    try:
        return args.func(args)
    except _Abort as abort:
        return fail(abort.code, abort.message)
    except KeyboardInterrupt:
        return EXIT_USAGE


if __name__ == "__main__":
    sys.exit(main())
