#!/usr/bin/env python3
"""sndctl -- read a MUGEN/IKEMEN SND sound container.

    python tools/sndctl/sndctl.py inspect <file.snd> [--limit N] [--json]
    python tools/sndctl/sndctl.py export  <file.snd> --out DIR [--sound G,N]...
                                                        [--overwrite]

Read-only: ``inspect`` prints, and ``export`` only ever writes the WAV files
you asked for into the directory you named. There is no "write back to SND"
mode -- P6 only renumbers the *references* in the character script, so the
source bank stays untouched (see docs/P6-review-and-plan.md, item B).

Exit codes: shared with the other tools, see kofassets/report.py.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from kofassets import report, snd  # noqa: E402
from kofassets.report import (EXIT_CORRUPT, EXIT_FINDINGS, EXIT_IO,  # noqa: E402
                              EXIT_OK, EXIT_USAGE)


def fail(code, message, hint=None):
    print("ERROR: %s" % message, file=sys.stderr)
    if hint:
        print("       %s" % hint, file=sys.stderr)
    return code


def load(path):
    if not os.path.exists(path):
        raise _Abort(EXIT_IO, "no such file: %s" % path)
    if os.path.isdir(path):
        raise _Abort(EXIT_IO, "%s is a directory, expected an .snd file" % path)
    try:
        return snd.load(path)
    except snd.SndFormatError as exc:
        raise _Abort(EXIT_CORRUPT, str(exc))
    except snd.SndCorruptError as exc:
        raise _Abort(EXIT_CORRUPT, str(exc))
    except snd.SndError as exc:
        raise _Abort(EXIT_IO, str(exc))


class _Abort(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code
        self.message = message


def cmd_inspect(args):
    rep = report.Report()
    try:
        container = load(args.file)
    except _Abort as abort:
        return fail(abort.code, abort.message)

    shown = container.entries[:args.limit] if args.limit else container.entries

    if args.json:
        print(json.dumps({
            "file": container.path,
            "size": container.size,
            "version": "%d.%d" % (container.ver, container.ver2),
            "declared": container.declared_count,
            "sounds": [
                {"group": e.group, "number": e.number, "bytes": e.length,
                 "rate": e.sample_rate, "channels": e.channels, "bits": e.bits,
                 "format": e.format_name, "seconds": round(e.duration, 4),
                 "problem": e.wav_error}
                for e in shown],
            "sounds_truncated_to": args.limit if len(shown) < len(container.entries) else None,
        }, indent=2))
        return EXIT_OK

    print("File:      %s" % container.path)
    print("Size:      %d bytes" % container.size)
    print("Version:   %d.%d" % (container.ver, container.ver2))
    print("Sounds:    %d  (header declares %d)" % (len(container.entries),
                                                   container.declared_count))
    print("Duration:  %.1f s total" % container.total_seconds())
    print("Formats:   %s" % ", ".join("%s x%d" % (k, v)
                                      for k, v in sorted(container.formats().items())))
    print("")
    print("   index  group sound   bytes    rate  ch  bits  format      seconds")
    print("  ------  ----- -----  ------  ------  --  ----  ----------  -------")
    for item in shown:
        print("  %6d  %5d %5d  %6d  %6d  %2d  %4d  %-10s  %7.2f%s"
              % (item.index, item.group, item.number, item.length,
                 item.sample_rate, item.channels, item.bits, item.format_name,
                 item.duration, "   (bad wav)" if item.wav_error else ""))
    if len(shown) < len(container.entries):
        print("  ... %d more (use --limit to change)"
              % (len(container.entries) - len(shown)))

    for item in container.problems():
        rep.warn("SND_ENTRY_PROBLEM",
                 "sound %d,%d: %s" % (item.group, item.number, item.wav_error))
    if container.declared_count != len(container.entries):
        rep.warn("SND_COUNT_MISMATCH",
                 "header declares %d sounds but the chain holds %d"
                 % (container.declared_count, len(container.entries)))
    if rep.sorted_findings():
        print("")
        report.print_findings(rep)
    print("")
    print("verdict: %s" % ("OK" if not rep.sorted_findings() else "WARN"))
    return rep.exit_code()


def cmd_export(args):
    try:
        container = load(args.file)
    except _Abort as abort:
        return fail(abort.code, abort.message)

    if not os.path.isdir(args.out):
        os.makedirs(args.out, exist_ok=True)

    wanted = []
    for group, number in args.sound or []:
        entry = container.entry(group, number)
        if entry is None:
            return fail(EXIT_FINDINGS,
                        "sound %d,%d is not in %s" % (group, number, args.file))
        wanted.append(entry)
    if not wanted:
        wanted = container.entries

    written = 0
    for entry in wanted:
        path = os.path.join(args.out, "%d_%d.wav" % (entry.group,
                                                     entry.number))
        if os.path.exists(path) and not args.overwrite:
            print("skip   : %s exists (pass --overwrite to replace)" % path)
            continue
        with open(path, "wb") as handle:
            handle.write(entry.wav)
        written += 1
    print("exported %d of %d sound(s) to %s" % (written, len(wanted), args.out))
    return EXIT_OK


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command")

    p_inspect = sub.add_parser("inspect", help="print the sound table")
    p_inspect.add_argument("file")
    p_inspect.add_argument("--limit", type=int, default=40)
    p_inspect.add_argument("--json", action="store_true")
    p_inspect.set_defaults(func=cmd_inspect)

    p_export = sub.add_parser("export", help="write entries out as WAV files")
    p_export.add_argument("file")
    p_export.add_argument("--out", required=True)
    p_export.add_argument("--sound", nargs=2, type=int, action="append",
                          metavar=("GROUP", "NUMBER"))
    p_export.add_argument("--overwrite", action="store_true")
    p_export.set_defaults(func=cmd_export)

    args = parser.parse_args(argv)
    if not getattr(args, "func", None):
        parser.print_help()
        return EXIT_USAGE
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
