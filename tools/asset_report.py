#!/usr/bin/env python3
"""Produce one report about one character, using the P5 asset tools.

The workflow P6 is supposed to follow is validate -> inspect -> export -> look ->
inspect the animations -> validate the animations. Doing that by hand is six
commands whose output nobody remembers how to reproduce. This script owns the
sequence and writes every step, with the exact command line above it, into one
text file.

It adds no new logic: every section is a call to one of the existing tools
(tools/character_validate, tools/sffctl, tests/tools/check_export, tools/airtool),
so the report can never disagree with what those tools say on their own.

Which animations get a detailed section is chosen automatically: every action
that carries an attack box, plus every action with a -1 hold, capped so the
report stays readable.

    python tools/asset_report.py game/chars/test_fighter_b
    python tools/asset_report.py game/chars/test_fighter_b --out logs/p5/demo --montage
    python tools/asset_report.py game/chars/test_fighter_b --report docs/evidence/p5/x.txt

Exit code: 0 when the character validates and the exported sprites verify,
1 otherwise (the report is written either way -- a failing report is the point).
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, ".."))
sys.path.insert(0, HERE)

VALIDATE = os.path.join(HERE, "character_validate", "validate_character.py")
SFFCTL = os.path.join(HERE, "sffctl", "sffctl.py")
AIRTOOL = os.path.join(HERE, "airtool", "airtool.py")
CHECK_EXPORT = os.path.join(REPO, "tests", "tools", "check_export.py")

MAX_ATTACK_ACTIONS = 8
MAX_HOLD_ACTIONS = 6


def rel(path):
    """Repo-relative, so the report reads the same on every machine."""
    try:
        return os.path.relpath(path, REPO).replace("\\", "/")
    except ValueError:
        return path


class Report:
    def __init__(self, stream):
        self.stream = stream
        self.failures = 0

    def line(self, text=""):
        print(text, file=self.stream)

    def section(self, title):
        self.line()
        self.line("#" * 78)
        self.line("# %s" % title)
        self.line("#" * 78)

    def run(self, argv):
        """Show the exact command, run it, and capture the output."""
        shown = " ".join(rel(a) if os.path.exists(a) else a for a in argv)
        self.line("$ %s" % shown)
        proc = subprocess.run([sys.executable] + argv, capture_output=True,
                              text=True, cwd=REPO)
        text = (proc.stdout or "").rstrip("\n")
        if not text.strip() and proc.stderr and proc.stderr.strip():
            text = proc.stderr.strip()
        self.line(text)
        self.line("exit=%d" % proc.returncode)
        if proc.returncode != 0:
            self.failures += 1
        return proc.returncode


def interesting_actions(air_path):
    """Attack actions and -1 hold actions, read from airtool's own JSON."""
    proc = subprocess.run([sys.executable, AIRTOOL, "inspect", air_path, "--json"],
                          capture_output=True, text=True, cwd=REPO)
    if proc.returncode != 0:
        return [], []
    try:
        data = json.loads(proc.stdout)
    except ValueError:
        return [], []
    attacks, holds = [], []
    for entry in data.get("actions", []):
        number = entry.get("action")
        if entry.get("has_infinite_frame"):
            holds.append(number)
        elif any(m in ("per-frame", "default") for m in (entry.get("clsn1_modes") or [])):
            attacks.append(number)
    return sorted(attacks)[:MAX_ATTACK_ACTIONS], sorted(holds)[:MAX_HOLD_ACTIONS]


def _find_by_def(target, key):
    """Resolve a [Files] entry the same way character_validate does."""
    from kofassets import chardef
    def_path = target if os.path.isfile(target) else _locate_def(target)
    if not def_path:
        return None
    try:
        parsed = chardef.parse(def_path)
    except chardef.DefError:
        return None
    declared = parsed.files().get(key)
    if not declared:
        return None
    candidate = os.path.join(parsed.directory, declared)
    return candidate if os.path.exists(candidate) else None


def _locate_def(directory):
    base = os.path.basename(os.path.normpath(directory))
    preferred = os.path.join(directory, base + ".def")
    if os.path.isfile(preferred):
        return preferred
    found = sorted(n for n in os.listdir(directory) if n.lower().endswith(".def"))
    return os.path.join(directory, found[0]) if len(found) == 1 else None


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Write one report about one character using the P5 asset tools.")
    parser.add_argument("target", help="character directory, or the .def file itself")
    parser.add_argument("--out", default=os.path.join("logs", "p5", "asset_report"),
                        help="where to put the exported sprites and the montage")
    parser.add_argument("--report", default=None,
                        help="write the report to this file instead of stdout")
    parser.add_argument("--montage", action="store_true",
                        help="also render a contact sheet of every sprite")
    args = parser.parse_args(argv)

    target = os.path.abspath(args.target)
    out_dir = os.path.abspath(args.out)
    export_dir = os.path.join(out_dir, "export")

    stream = open(args.report, "w", encoding="utf-8") if args.report else sys.stdout
    report = Report(stream)
    try:
        report.line("KingOfFate asset report")
        report.line("character: %s" % rel(target))
        report.line("produced by tools/asset_report.py (P5)")

        # Everything is handed to the tools as a repo-relative path and run from the
        # repo root, so the report reads the same wherever it is regenerated.
        report.section("STEP 1  character_validate")
        report.run([VALIDATE, rel(target)])

        sff_path = _find_by_def(target, "sprite")
        air_path = _find_by_def(target, "anim")
        sff_arg = rel(sff_path) if sff_path else None
        air_arg = rel(air_path) if air_path else None

        report.section("STEP 2  sffctl inspect")
        if sff_arg:
            report.run([SFFCTL, "inspect", sff_arg, "--limit", "20", "--no-palettes"])
        else:
            report.line("no sprite container found in %s" % rel(target))
            report.failures += 1

        report.section("STEP 3  sffctl export")
        if sff_arg:
            report.run([SFFCTL, "export", sff_arg, "--out", rel(export_dir), "--overwrite"])
            report.line()
            report.run([CHECK_EXPORT, "--sff", sff_arg, "--out", rel(export_dir)])
            if args.montage:
                report.line()
                report.run([SFFCTL, "montage", sff_arg,
                            "--out", rel(os.path.join(out_dir, "montage.png"))])

        if air_arg:
            attacks, holds = interesting_actions(air_arg)
            for number in attacks:
                report.section("STEP 4  airtool inspect --action %d (attack)" % number)
                report.run([AIRTOOL, "inspect", air_arg, "--action", str(number)])
            for number in holds:
                report.section("STEP 4  airtool inspect --action %d (holds forever)" % number)
                report.run([AIRTOOL, "inspect", air_arg, "--action", str(number)])
            report.section("STEP 5  airtool validate")
            report.run([AIRTOOL, "validate", air_arg])
        else:
            report.section("STEP 4/5  airtool")
            report.line("no animation table found in %s" % rel(target))
            report.failures += 1

        report.line()
        report.line("report: %d step(s) reported a failure" % report.failures)
    finally:
        if args.report:
            stream.close()
            print("report written: %s" % rel(args.report))
            print("exports:        %s" % rel(export_dir))
            if args.montage:
                print("montage:        %s" % rel(os.path.join(out_dir, "montage.png")))
            print("failures:       %d" % report.failures)

    return 1 if report.failures else 0


if __name__ == "__main__":
    sys.exit(main())
