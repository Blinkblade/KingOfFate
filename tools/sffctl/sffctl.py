#!/usr/bin/env python3
"""sffctl -- read an SFF sprite container, or export its sprites to PNG.

    python tools/sffctl/sffctl.py inspect <file.sff> [--json] [--limit N]
    python tools/sffctl/sffctl.py export  <file.sff> --out DIR [--sprite G,N]... [--all]
                                                     [--palette N] [--overwrite] [--json]
    python tools/sffctl/sffctl.py montage <file.sff> --out FILE.png [--max N] [--scale N]

Read-only: ``inspect`` and ``montage`` never write anything except the file you
name, and ``export`` only ever writes into the directory you name. There is no
"write back to SFF" mode -- P5 does not need one (see
docs/character_asset_tooling.md, "What P5 deliberately does not do").

Exit codes: see kofassets/report.py.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from kofassets import pngio, report, sff  # noqa: E402
from kofassets.report import (EXIT_CORRUPT, EXIT_FINDINGS, EXIT_IO,  # noqa: E402
                              EXIT_OK, EXIT_UNSUPPORTED, EXIT_USAGE)


def fail(code, message, hint=None):
    print("ERROR: %s" % message, file=sys.stderr)
    if hint:
        print("       %s" % hint, file=sys.stderr)
    return code


def load_sff(path, rep):
    """Load a container, mapping library errors onto the documented exit codes."""
    if not os.path.exists(path):
        raise _Abort(EXIT_IO, "no such file: %s" % path)
    if os.path.isdir(path):
        raise _Abort(EXIT_IO, "%s is a directory, expected an .sff file" % path)
    try:
        return sff.Sff.load(path)
    except sff.SffUnsupportedError as exc:
        raise _Abort(EXIT_UNSUPPORTED, str(exc))
    except sff.SffFormatError as exc:
        raise _Abort(EXIT_CORRUPT, str(exc))
    except sff.SffCorruptError as exc:
        raise _Abort(EXIT_CORRUPT, str(exc))


class _Abort(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code
        self.message = message


# ---------------------------------------------------------------------------
# inspect
# ---------------------------------------------------------------------------


def cmd_inspect(args):
    rep = report.Report()
    try:
        container = load_sff(args.file, rep)
    except _Abort as abort:
        return fail(abort.code, abort.message)

    sprites = container.sorted_sprites()
    shown = sprites[:args.limit] if args.limit else sprites

    if args.json:
        payload = {
            "file": container.path,
            "size": os.path.getsize(container.path),
            "version": container.version_string,
            "sprite_count": container.sprite_count,
            "unique_sprite_keys": len(container.by_key),
            "palette_count": container.palette_count,
            "data_offset": container.data_offset,
            "external_data_offset": container.external_data_offset,
            "duplicate_sprite_keys": [{"group": g, "image": n}
                                      for g, n in container.duplicate_keys],
            "palettes": [p.to_dict() for p in container.palettes],
            "sprites": [s.to_dict() for s in shown],
            "warnings": container.warnings,
        }
        if args.limit and len(sprites) > args.limit:
            payload["sprites_truncated_to"] = args.limit
        report.emit_json(payload)
        return EXIT_OK

    print("File:      %s" % container.path)
    print("Size:      %d bytes" % os.path.getsize(container.path))
    print("Version:   %s" % container.version_string)
    print("Sprites:   %d  (%d unique group,image keys)" % (container.sprite_count,
                                                           len(container.by_key)))
    print("Palettes:  %d" % container.palette_count)
    print("Data:      lofs=%d  tofs=%d" % (container.data_offset,
                                           container.external_data_offset))
    print("")
    print("   index  group image  width height  axisx axisy  format        depth palette")
    print("  ------  ----- -----  ----- ------  ----- -----  ------------  ----- -------")
    for sprite in shown:
        print("  %6d  %5d %5d  %5d %6d  %5d %5d  %-12s  %5d %7d"
              % (sprite.index, sprite.group, sprite.number, sprite.width, sprite.height,
                 sprite.axis_x, sprite.axis_y, sprite.format_name, sprite.coldepth,
                 sprite.pal_index))
    if args.limit and len(sprites) > args.limit:
        print("  ... %d more (use --limit to change)" % (len(sprites) - args.limit))

    if container.palettes and not args.no_palettes:
        print("")
        print("palettes (colours is the padded power-of-two length the engine allocates):")
        for pal in container.palettes:
            print("  %2d  key=(%d,%d)  declared=%d  colours=%d  shares_with=%d"
                  % (pal.index, pal.group, pal.number, pal.declared_colours,
                     len(pal.colours), pal.source_index))

    problems = list(container.warnings)
    for sprite in container.sprites:
        problems.extend("sprite %d: %s" % (sprite.index, w) for w in sprite.warnings)
    for pal in container.palettes:
        problems.extend("palette %d: %s" % (pal.index, w) for w in pal.warnings)
    if problems:
        print("")
        print("warnings from the reader:")
        for text in problems:
            print("  - %s" % text)
    print("")
    print("OK: parsed %d sprites" % container.sprite_count)
    return EXIT_OK


# ---------------------------------------------------------------------------
# export
# ---------------------------------------------------------------------------


def parse_sprite_arg(text):
    parts = text.replace(" ", "").split(",")
    if len(parts) != 2:
        raise argparse.ArgumentTypeError("expected GROUP,IMAGE, got %r" % text)
    try:
        return (int(parts[0]), int(parts[1]))
    except ValueError:
        raise argparse.ArgumentTypeError("expected integer GROUP,IMAGE, got %r" % text)


def sprite_filename(group, image):
    """Deterministic, collision-free name for one exported sprite."""
    return "%d_%d.png" % (group, image)


def cmd_export(args):
    rep = report.Report()
    try:
        container = load_sff(args.file, rep)
    except _Abort as abort:
        return fail(abort.code, abort.message)

    if args.sprite:
        wanted = []
        for group, image in args.sprite:
            sprite = container.sprite(group, image)
            if sprite is None:
                return fail(EXIT_FINDINGS,
                            "sprite %d,%d is not in %s" % (group, image, container.path),
                            "use 'inspect' to list what the container has")
            wanted.append(sprite)
    else:
        wanted = container.sorted_sprites()

    out_dir = os.path.abspath(args.out)
    if os.path.exists(out_dir) and not os.path.isdir(out_dir):
        return fail(EXIT_USAGE, "--out %s exists and is not a directory" % out_dir)

    entries = []
    failures = []
    try:
        os.makedirs(out_dir, exist_ok=True)
    except OSError as exc:
        return fail(EXIT_IO, "cannot create output directory %s: %s" % (out_dir, exc))

    if _inside_character_tree(out_dir):
        print("note: writing inside a character directory (%s); production art belongs in "
              "assets/, not next to the character" % out_dir, file=sys.stderr)

    for sprite in wanted:
        name = sprite_filename(sprite.group, sprite.number)
        target = os.path.join(out_dir, name)
        if os.path.exists(target) and not args.overwrite:
            failures.append(report.Finding(
                report.ERROR, "SFF_EXPORT_NO_OVERWRITE",
                "%s already exists" % target, group=sprite.group, image=sprite.number,
                hint="pass --overwrite to replace it, or choose a different --out"))
            continue
        try:
            rgba, palette = container.rgba(sprite, args.palette)
        except (sff.SffUnsupportedError, sff.SffCorruptError) as exc:
            failures.append(report.Finding(
                report.ERROR, "SFF_SPRITE_DECODE_FAILED", str(exc),
                group=sprite.group, image=sprite.number))
            continue
        try:
            pngio.write_rgba(target, sprite.width, sprite.height, rgba)
        except (OSError, pngio.PngError) as exc:
            failures.append(report.Finding(
                report.ERROR, "SFF_EXPORT_WRITE_FAILED", "cannot write %s: %s" % (target, exc),
                group=sprite.group, image=sprite.number))
            continue

        visible = sum(1 for i in range(3, len(rgba), 4) if rgba[i] != 0)
        entries.append({
            "file": name,
            "path": target,
            "group": sprite.group,
            "image": sprite.number,
            "width": sprite.width,
            "height": sprite.height,
            "axis_x": sprite.axis_x,
            "axis_y": sprite.axis_y,
            "format": sprite.format_name,
            "palette_index": args.palette if args.palette is not None else sprite.pal_index,
            "bytes": os.path.getsize(target),
            "visible_pixels": visible,
            "transparent_pixels": sprite.width * sprite.height - visible,
        })

    if args.json:
        report.emit_json({
            "source": container.path,
            "output_directory": out_dir,
            "requested": len(wanted),
            "exported": len(entries),
            "failed": len(failures),
            "sprites": entries,
            "errors": [f.to_dict() for f in failures],
        })
    else:
        print("source:  %s" % container.path)
        print("output:  %s" % out_dir)
        for entry in entries:
            print("  %-14s %4dx%-4d axis=(%3d,%3d) palette=%-3d visible=%-7d %s"
                  % (entry["file"], entry["width"], entry["height"], entry["axis_x"],
                     entry["axis_y"], entry["palette_index"], entry["visible_pixels"],
                     entry["format"]))
        print("")
        print("exported %d of %d sprite(s) to %s" % (len(entries), len(wanted), out_dir))
        if failures:
            print("")
            for finding in failures:
                print(finding.format())

    return EXIT_FINDINGS if failures else EXIT_OK


def _inside_character_tree(path):
    normalised = os.path.normcase(os.path.normpath(path))
    marker = os.path.normcase(os.path.join("game", "chars"))
    return marker in normalised


# ---------------------------------------------------------------------------
# montage
# ---------------------------------------------------------------------------


def cmd_montage(args):
    """Render every sprite into one contact sheet, so a human can actually look."""
    try:
        container = load_sff(args.file, report.Report())
    except _Abort as abort:
        return fail(abort.code, abort.message)

    sprites = container.sorted_sprites()
    if args.max:
        sprites = sprites[:args.max]
    if not sprites:
        return fail(EXIT_FINDINGS, "%s has no sprites to draw" % args.file)

    scale = max(1, args.scale)
    cell_w = max(s.width for s in sprites) + 4
    cell_h = max(s.height for s in sprites) + 4
    columns = max(1, args.columns)
    rows = (len(sprites) + columns - 1) // columns
    sheet_w = cell_w * columns * scale
    sheet_h = cell_h * rows * scale
    if sheet_w * sheet_h > 64 * 1024 * 1024:
        return fail(EXIT_USAGE, "montage would be %dx%d pixels; reduce --scale or --columns"
                    % (sheet_w, sheet_h))

    # Checkerboard background so the transparent regions are unmistakable.
    # Built row-wise with slice assignment: a per-pixel Python loop over a
    # 2000x2600 sheet would take tens of seconds for no benefit.
    sheet = bytearray(sheet_w * sheet_h * 4)
    row_bytes = sheet_w * 4
    light = bytes([200, 200, 200, 255])
    dark = bytes([160, 160, 160, 255])
    row_patterns = []
    for parity in (0, 1):
        pattern = bytearray(row_bytes)
        for block in range(0, (sheet_w + 7) // 8):
            chunk = light if (block + parity) % 2 == 0 else dark
            start = block * 8 * 4
            for k in range(start, min(start + 32, row_bytes), 4):
                pattern[k:k + 4] = chunk
        row_patterns.append(bytes(pattern))
    for y in range(sheet_h):
        sheet[y * row_bytes:(y + 1) * row_bytes] = row_patterns[(y // 8) % 2]

    skipped = []
    for i, sprite in enumerate(sprites):
        try:
            rgba, _ = container.rgba(sprite, args.palette)
        except (sff.SffUnsupportedError, sff.SffCorruptError) as exc:
            skipped.append((sprite, str(exc)))
            continue
        col = i % columns
        row = i // columns
        origin_x = col * cell_w * scale
        origin_y = row * cell_h * scale
        for y in range(sprite.height):
            src = y * sprite.width * 4
            line = rgba[src:src + sprite.width * 4]
            alphas = line[3::4]
            if max(alphas) == 0:
                continue
            for dy in range(scale):
                py = origin_y + y * scale + dy
                if py >= sheet_h:
                    break
                dst = (py * sheet_w + origin_x) * 4
                if min(alphas) == 255:
                    if scale == 1:
                        sheet[dst:dst + len(line)] = line
                    else:
                        for dx in range(sprite.width):
                            chunk = line[dx * 4:dx * 4 + 4]
                            o = dst + dx * scale * 4
                            for k in range(scale):
                                sheet[o + k * 4:o + k * 4 + 4] = chunk
                else:
                    for dx in range(sprite.width):
                        px = origin_x + dx * scale
                        if px >= sheet_w:
                            break
                        alpha = line[dx * 4 + 3]
                        if alpha == 0:
                            continue
                        src_px = line[dx * 4:dx * 4 + 3]
                        for k in range(scale):
                            o = (py * sheet_w + px + k) * 4
                            sheet[o:o + 3] = src_px
                            sheet[o + 3] = alpha

    out = os.path.abspath(args.out)
    parent = os.path.dirname(out)
    if parent:
        os.makedirs(parent, exist_ok=True)
    try:
        pngio.write_rgba(out, sheet_w, sheet_h, bytes(sheet))
    except (OSError, pngio.PngError) as exc:
        return fail(EXIT_IO, "cannot write %s: %s" % (out, exc))

    print("montage: %s" % out)
    print("  %d sprite(s) drawn, %dx%d cells of %dx%d px, scale x%d"
          % (len(sprites) - len(skipped), columns, rows, cell_w, cell_h, scale))
    for sprite, message in skipped:
        print("  skipped sprite %d,%d: %s" % (sprite.group, sprite.number, message))
    return EXIT_OK


# ---------------------------------------------------------------------------
# entry point
# ---------------------------------------------------------------------------


def build_parser():
    parser = argparse.ArgumentParser(
        prog="sffctl.py",
        description="Inspect SFF sprite containers and export their sprites to PNG.")
    sub = parser.add_subparsers(dest="command")

    inspect = sub.add_parser("inspect", help="summarise a container and list its sprites")
    inspect.add_argument("file", help="path to the .sff file")
    inspect.add_argument("--json", action="store_true", help="machine-readable output")
    inspect.add_argument("--limit", type=int, default=0,
                         help="only list the first N sprites (0 = all)")
    inspect.add_argument("--no-palettes", action="store_true", help="skip the palette table")
    inspect.set_defaults(func=cmd_inspect)

    export = sub.add_parser("export", help="write sprites out as PNG files")
    export.add_argument("file", help="path to the .sff file")
    export.add_argument("--out", required=True, help="output directory (required)")
    export.add_argument("--sprite", action="append", type=parse_sprite_arg, default=None,
                        metavar="G,N", help="export one sprite; repeatable")
    export.add_argument("--palette", type=int, default=None,
                        help="force a palette index instead of each sprite's own")
    export.add_argument("--overwrite", action="store_true",
                        help="allow replacing existing PNG files")
    export.add_argument("--json", action="store_true", help="machine-readable output")
    export.set_defaults(func=cmd_export)

    montage = sub.add_parser("montage", help="draw every sprite into one contact sheet PNG")
    montage.add_argument("file", help="path to the .sff file")
    montage.add_argument("--out", required=True, help="output PNG path")
    montage.add_argument("--max", type=int, default=0, help="only the first N sprites")
    montage.add_argument("--columns", type=int, default=16, help="sprites per row")
    montage.add_argument("--scale", type=int, default=1, help="integer zoom factor")
    montage.add_argument("--palette", type=int, default=None,
                         help="force a palette index instead of each sprite's own")
    montage.set_defaults(func=cmd_montage)

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
