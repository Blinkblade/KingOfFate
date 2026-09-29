#!/usr/bin/env python3
"""validate_character -- one character, all of its assets, one verdict.

    python tools/character_validate/validate_character.py <character-dir | file.def>
                                                          [--json] [--strict] [--quiet]

Answers the only question P6 needs answered before assets go into the game:
*are these files complete, consistent and loadable by the tooling?*

It checks, and reports each one separately so a failure is never just "validation
failed":

    DEF            the .def parses and its [Info] block is usable
    files          every [Files] entry resolves inside the character directory
    SFF            the sprite container opens, and its version is supported
    AIR            the animation table parses without structural errors
    sprite refs    every element of every action points at a sprite the SFF has
    key animations the actions the engine asks for by number exist
    collision      the collision-scope checks (see kofassets/checks.py)

This is a validator, not a repair tool: it never writes to the character.

Exit codes: 0 = clean, 1 = findings (ERROR, or WARNING with --strict),
2 = usage error, 3 = the character or its .def cannot be read at all.
"""

from __future__ import annotations

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from kofassets import air as air_mod  # noqa: E402
from kofassets import chardef, checks, report, sff as sff_mod  # noqa: E402
from kofassets.report import EXIT_FINDINGS, EXIT_IO, EXIT_OK, EXIT_USAGE  # noqa: E402

STATUS_OK = "PASS"
STATUS_FAIL = "FAIL"
STATUS_SKIP = "SKIP"


def fail(code, message, hint=None):
    print("ERROR: %s" % message, file=sys.stderr)
    if hint:
        print("       %s" % hint, file=sys.stderr)
    return code


def locate_def(target):
    """Accept a character directory or a .def file."""
    if os.path.isfile(target):
        return target, os.path.dirname(os.path.abspath(target))
    if not os.path.isdir(target):
        return None, None
    base = os.path.basename(os.path.normpath(target))
    preferred = os.path.join(target, base + ".def")
    if os.path.isfile(preferred):
        return preferred, os.path.abspath(target)
    candidates = sorted(name for name in os.listdir(target)
                        if name.lower().endswith(".def"))
    if len(candidates) == 1:
        return os.path.join(target, candidates[0]), os.path.abspath(target)
    if not candidates:
        return None, os.path.abspath(target)
    return None, os.path.abspath(target)  # ambiguous


def run(args):
    rep = report.Report()
    status = []          # (label, state, detail)
    facts = {}

    target = args.target
    if not os.path.exists(target):
        return fail(EXIT_IO, "no such character directory or .def: %s" % target)

    def_path, char_dir = locate_def(target)
    if def_path is None:
        if char_dir and os.path.isdir(char_dir):
            return fail(EXIT_IO,
                        "cannot pick a .def in %s: none found, or more than one" % char_dir,
                        "pass the .def file explicitly")
        return fail(EXIT_IO, "not a character directory or .def file: %s" % target)

    character_name = os.path.basename(char_dir)
    facts["character"] = character_name
    facts["directory"] = char_dir
    facts["def"] = def_path

    # -- DEF ---------------------------------------------------------------
    try:
        parsed = chardef.parse(def_path)
    except chardef.DefError as exc:
        return fail(EXIT_IO, str(exc))
    facts["name"] = parsed.name
    facts["display_name"] = parsed.display_name

    # -- file resolution ---------------------------------------------------
    engine_root = chardef.find_engine_root(char_dir)
    facts["engine_root"] = engine_root
    resolved = chardef.resolve_files(parsed, engine_root)
    facts["files"] = {key: entry.to_dict() for key, entry in sorted(resolved.items())}

    rep.extend(checks.check_def(parsed, resolved, expected_name=character_name))
    missing_required = [key for key, entry in resolved.items()
                        if chardef.FILE_KEYS.get(key) and not entry.exists]

    def files_state(key, required=True):
        entry = resolved.get(key)
        if entry is None or not entry.declared:
            return (STATUS_FAIL if required else STATUS_SKIP), "not declared"
        if not entry.exists:
            return (STATUS_FAIL if required else STATUS_SKIP), "not found: %s" % entry.declared
        detail = os.path.relpath(entry.path, char_dir).replace("\\", "/")
        if entry.location == "engine":
            detail += "  (from the engine tree, not the character)"
        return STATUS_OK, detail

    status.append(("DEF", STATUS_OK if not [f for f in rep.errors
                                            if f.code in ("DEF_MISSING_NAME", "DEF_NO_FILES")]
                   else STATUS_FAIL, os.path.relpath(def_path, char_dir).replace("\\", "/")))
    for key, label, required in (("cmd", "CMD", True), ("sprite", "SFF", True),
                                 ("anim", "AIR", True), ("sound", "SND", False),
                                 ("cns", "Constants", False), ("st", "States (st)", True),
                                 ("stcommon", "stcommon", False), ("movelist", "movelist", False)):
        state, detail = files_state(key, required)
        status.append((label, state, detail))

    # -- SFF ---------------------------------------------------------------
    sff_entry = resolved.get("sprite")
    container = None
    if sff_entry is not None and sff_entry.exists:
        try:
            container = sff_mod.Sff.load(sff_entry.path)
            status.append(("SFF content", STATUS_OK,
                           "version %s, %d sprites, %d palettes"
                           % (container.version_string, container.sprite_count,
                              container.palette_count)))
            facts["sff"] = {"path": sff_entry.path, "version": container.version_string,
                            "sprites": container.sprite_count,
                            "palettes": container.palette_count}
            for warning in container.warnings:
                rep.warn("SFF_WARNING", warning, file=sff_entry.path)
        except sff_mod.SffUnsupportedError as exc:
            rep.error("SFF_UNSUPPORTED", str(exc), file=sff_entry.path)
            status.append(("SFF content", STATUS_FAIL, "unsupported version"))
        except (sff_mod.SffFormatError, sff_mod.SffCorruptError) as exc:
            rep.error("SFF_CORRUPT", str(exc), file=sff_entry.path)
            status.append(("SFF content", STATUS_FAIL, "unreadable"))
    else:
        status.append(("SFF content", STATUS_SKIP, "sprite file unavailable"))

    # -- AIR ---------------------------------------------------------------
    air_entry = resolved.get("anim")
    air = None
    if air_entry is not None and air_entry.exists:
        try:
            air = air_mod.Air.load(air_entry.path)
        except air_mod.AirError as exc:
            rep.error("AIR_UNREADABLE", str(exc), file=air_entry.path)
            status.append(("AIR content", STATUS_FAIL, "unreadable"))
        else:
            facts["air"] = {"path": air_entry.path, "actions": len(air.actions),
                            "duplicates": sorted(set(air.duplicates))}
            rep.extend(checks.check_air_structure(air))
            rep.extend(checks.check_collision_semantics(air))
            structure_errors = [f for f in rep.errors
                                if f.code in ("AIR_EMPTY_ACTION", "AIR_BAD_TIME",
                                              "AIR_BOX_COUNT_MISMATCH",
                                              "AIR_ELEMENT_PROBLEM",
                                              "AIR_DUPLICATE_ACTION",
                                              "AIR_ACTION_PROBLEM")]
            status.append(("AIR content", STATUS_FAIL if structure_errors else STATUS_OK,
                           "%d actions" % len(air.actions)))
    else:
        status.append(("AIR content", STATUS_SKIP, "animation file unavailable"))

    # -- scripts -> animation references -----------------------------------
    script_keys = ("st", "st2", "st3", "st4")
    script_paths = [resolved[key].path for key in script_keys
                    if key in resolved and resolved[key].exists]
    if air is not None and script_paths:
        before = len(rep.errors)
        rep.extend(checks.check_zss_animation_references(air, script_paths))
        new_errors = len(rep.errors) - before
        status.append(("scripts -> AIR", STATUS_FAIL if new_errors else STATUS_OK,
                       "%d script file(s), %s" % (len(script_paths),
                                                  "%d missing animation(s)" % new_errors
                                                  if new_errors
                                                  else "every literal animation reference resolves")))
    elif air is not None:
        status.append(("scripts -> AIR", STATUS_SKIP, "no state scripts resolved"))
    else:
        status.append(("scripts -> AIR", STATUS_SKIP, "needs the animation table"))

    # -- sprite references -------------------------------------------------
    if air is not None and container is not None:
        before = len(rep.errors)
        rep.extend(checks.check_sprite_references(air, container))
        new_errors = len(rep.errors) - before
        status.append(("AIR -> SFF sprites", STATUS_FAIL if new_errors else STATUS_OK,
                       "all %d referenced sprites exist"
                       % len(air.sprite_references()) if not new_errors
                       else "%d missing reference(s)" % new_errors))
    else:
        status.append(("AIR -> SFF sprites", STATUS_SKIP, "needs both SFF and AIR"))

    counts = rep.summary()
    facts["summary"] = counts

    # -- output ------------------------------------------------------------
    if args.json:
        report.emit_json({
            "character": character_name,
            "def": def_path,
            "directory": char_dir,
            "info": {"name": parsed.name, "display_name": parsed.display_name},
            "checks": [{"name": name, "status": state, "detail": detail}
                       for name, state, detail in status],
            "files": facts["files"],
            "sff": facts.get("sff"),
            "air": facts.get("air"),
            "summary": counts,
            "findings": [f.to_dict() for f in rep.sorted_findings()],
        })
    else:
        width = max(len(name) for name, _, _ in status)
        print("Character: %s" % character_name)
        print("")
        for name, state, detail in status:
            print("  %-*s  %-4s  %s" % (width, name, state, detail))
        print("")
        if args.quiet:
            interesting = [f for f in rep.sorted_findings() if f.severity != report.INFO]
        else:
            interesting = rep.sorted_findings()
        if interesting:
            for finding in interesting:
                print(finding.format())
            print("")
        print("errors: %d   warnings: %d   info: %d"
              % (counts["errors"], counts["warnings"], counts["infos"]))
        verdict = "FAIL" if rep.errors else ("WARN" if rep.warnings else "PASS")
        print("verdict: %s" % verdict)

    return rep.exit_code(strict=args.strict)


def build_parser():
    parser = argparse.ArgumentParser(
        prog="validate_character.py",
        description="Validate one character's asset set as a whole.")
    parser.add_argument("target", help="character directory, or the .def file itself")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    parser.add_argument("--strict", action="store_true",
                        help="treat warnings as failures (exit 1)")
    parser.add_argument("--quiet", action="store_true",
                        help="hide INFO findings in the text output")
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        return run(args)
    except KeyboardInterrupt:
        return EXIT_USAGE


if __name__ == "__main__":
    sys.exit(main())
