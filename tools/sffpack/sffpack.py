#!/usr/bin/env python3
"""sffpack -- assemble SFF v2 containers from existing sprites (P6).

This is the pack half of the Archer asset import: read a source container
(SFF v1 or v2, decoded by ``kofassets/sff.py``) and write a new SFF v2 whose
sprite numbering matches the target character's animation table.

    python tools/sffpack/sffpack.py transcode <in.sff> --out <out.sff>
        [--remap map.csv] [--report FILE]

Without ``--remap`` every sprite keeps its (group, image) key -- a faithful
format conversion, used to prove the pipeline byte-for-byte before any
remapping happens. With ``--remap`` the CSV decides the mapping:

    target_group,target_image,source_group,source_image[,axis_x,axis_y]

    * one row per sprite in the output, in file order
    * axis columns optional: source axis is kept when they are blank
    * a source key may appear in several rows (the pixels are written once and
      later rows become linked sprites, like the source files do)

Every sprite is re-encoded as raw depth 8 (pixel-exact for palette-indexed
sources). Palettes are deduplicated by content.

Exit codes: 0 OK / 1 verification failed / 2 usage / 3 IO.
"""

from __future__ import annotations

import argparse
import csv
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

from kofassets import sff, sffwrite  # noqa: E402


def _fail(message, code):
    print("ERROR: %s" % message)
    return code


def _load_remap(path):
    rows = []
    with open(path, "r", encoding="utf-8-sig", newline="") as handle:
        for lineno, row in enumerate(csv.reader(handle), start=1):
            if not row or not row[0].strip() or row[0].strip().startswith("#"):
                continue
            if lineno == 1 and not row[0].strip().isdigit():
                continue   # header row
            if len(row) < 4:
                raise ValueError("%s line %d: need at least 4 columns "
                                 "(target_group,target_image,source_group,source_image)"
                                 % (path, lineno))
            tg, ti, sg, si = (int(row[k].strip()) for k in range(4))
            axis = None
            # Columns 5 and 6 are optional axis overrides. The asset_map.csv
            # that ships with a character also carries `action` and `notes`
            # columns there, so only take the override when both parse as ints.
            if len(row) >= 6 and row[4].strip() and row[5].strip():
                try:
                    axis = (int(row[4].strip()), int(row[5].strip()))
                except ValueError:
                    axis = None
            rows.append((tg, ti, sg, si, axis, lineno))
    if not rows:
        raise ValueError("%s: no mapping rows found" % path)
    return rows


def cmd_transcode(args):
    if not os.path.isfile(args.input):
        return _fail("no such file: %s" % args.input, 3)
    try:
        source = sff.Sff.load(args.input)
    except sff.SffError as exc:
        return _fail(str(exc), 3)

    # Resolve the mapping: identity, or the CSV.
    if args.remap:
        if not os.path.isfile(args.remap):
            return _fail("no such file: %s" % args.remap, 3)
        try:
            mapping = _load_remap(args.remap)
        except (ValueError, OSError) as exc:
            return _fail(str(exc), 2)
    else:
        mapping = [(spr.group, spr.number, spr.group, spr.number, None, None)
                   for spr in source.sprites]

    # Deduplicate palettes by content; every sprite references one.
    palette_ids = []
    palette_index_of = {}
    for pal in source.palettes:
        key = tuple(pal.colours)
        if key not in palette_index_of:
            palette_index_of[key] = len(palette_ids)
            palette_ids.append(pal.colours)

    # Build the output sprite list. Pixels for a repeated source sprite are
    # written once; later occurrences become linked sprites (engine shareCopy),
    # exactly like the source containers do.
    out_sprites = []
    written_key = {}          # (target group, image) -> output index
    pixel_bytes = {}          # output index -> (indices bytes, palette colours)
    problems = []
    for tg, ti, sg, si, axis, lineno in mapping:
        src = source.sprite(sg, si)
        if src is None:
            problems.append("source sprite (%d,%d) does not exist%s"
                            % (sg, si, " (remap line %d)" % lineno if lineno else ""))
            continue
        if (tg, ti) in written_key:
            out_sprites.append({
                "group": tg, "number": ti,
                "width": src.width, "height": src.height,
                "axis_x": axis[0] if axis else src.axis_x,
                "axis_y": axis[1] if axis else src.axis_y,
                "pal_index": 0,
                "link": written_key[(tg, ti)],
                "format": sffwrite.FMT_RAW,
                "payload": b"",
            })
            continue
        if src.is_linked:
            # Resolve through the source's own link chain: the new container
            # links to the output row that carries the source's pixels, if the
            # source's chain root was already emitted; otherwise emit the
            # pixels directly.
            root = source.sprites[src.linked_source_index] \
                if src.linked_source_index is not None else None
            if root is not None and (root.group, root.number) in written_key:
                out_sprites.append({
                    "group": tg, "number": ti,
                    "width": src.width, "height": src.height,
                    "axis_x": axis[0] if axis else src.axis_x,
                    "axis_y": axis[1] if axis else src.axis_y,
                    "pal_index": 0,
                    "link": written_key[(root.group, root.number)],
                    "format": sffwrite.FMT_RAW,
                    "payload": b"",
                })
                continue
        kind, indices = source._resolve_pixels(src)
        if kind != "indices":
            problems.append("source sprite (%d,%d) is RGBA (format %s); transcode only "
                            "supports palette-indexed sources"
                            % (sg, si, src.format_name))
            continue
        colours = source.palettes[src.pal_index].colours
        pal_key = tuple(colours)
        out_index = len(out_sprites)
        out_sprites.append({
            "group": tg, "number": ti,
            "width": src.width, "height": src.height,
            "axis_x": axis[0] if axis else src.axis_x,
            "axis_y": axis[1] if axis else src.axis_y,
            "pal_index": palette_index_of[pal_key],
            "format": sffwrite.FMT_RAW,
            "payload": bytes(indices),
        })
        written_key[(tg, ti)] = out_index
        pixel_bytes[out_index] = (bytes(indices), colours)

    if problems:
        for problem in problems[:10]:
            print("ERROR: %s" % problem)
        return _fail("%d mapping problem(s)" % len(problems), 1)
    if not out_sprites:
        return _fail("nothing to write", 2)

    try:
        blob = sffwrite.build_sff_v2(out_sprites, palette_ids)
    except sffwrite.SffWriteError as exc:
        return _fail(str(exc), 1)

    out_dir = os.path.dirname(os.path.abspath(args.out))
    if out_dir and not os.path.isdir(out_dir):
        os.makedirs(out_dir, exist_ok=True)
    with open(args.out, "wb") as handle:
        handle.write(blob)

    # Verification: re-read what we wrote and compare every sprite's decoded
    # indices AND palette-mapped RGBA against the source, byte for byte.
    try:
        written = sff.Sff.load(args.out)
    except sff.SffError as exc:
        return _fail("wrote %s but cannot read it back: %s" % (args.out, exc), 1)
    mismatch = []
    for out_index, entry in enumerate(out_sprites):
        if entry.get("link") is not None:
            continue
        spr = written.sprites[out_index]
        indices_expected, colours = pixel_bytes[out_index]
        kind, indices = written._resolve_pixels(spr)
        if kind != "indices" or indices != indices_expected:
            mismatch.append("sprite %d (%d,%d): pixels differ after re-read"
                            % (out_index, entry["group"], entry["number"]))
            continue
        rgba, _ = written.rgba(spr)
        expected_rgba = bytearray()
        for value in indices_expected:
            r, g, b, a = colours[value]
            expected_rgba += bytes((r, g, b, a))
        if rgba != bytes(expected_rgba):
            mismatch.append("sprite %d (%d,%d): palette-mapped RGBA differs"
                            % (out_index, entry["group"], entry["number"]))
    if mismatch:
        for line in mismatch[:10]:
            print("ERROR: %s" % line)
        return _fail("%d verification failure(s)" % len(mismatch), 1)

    linked = sum(1 for e in out_sprites if e.get("link") is not None)
    lines = [
        "transcode: %s -> %s" % (args.input, args.out),
        "  source:   %s, %d sprites (%d linked), %d palettes"
        % (source.version_string, len(source.sprites),
           sum(1 for s in source.sprites if s.is_linked), len(source.palettes)),
        "  written:  2.0.1.0, %d sprites (%d linked), %d palettes, %d bytes"
        % (len(out_sprites), linked, len(palette_ids), len(blob)),
        "  verify:   re-read OK; %d sprites compared pixel- and palette-exact, 0 mismatch"
        % len(pixel_bytes),
    ]
    if args.remap:
        lines.append("  remap:    %s (%d rows)" % (args.remap, len(mapping)))
    output = "\n".join(lines)
    print(output)
    if args.report:
        with open(args.report, "w", encoding="utf-8") as handle:
            handle.write(output + "\n")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    tr = sub.add_parser("transcode", help="convert a source SFF to SFF v2")
    tr.add_argument("input")
    tr.add_argument("--out", required=True)
    tr.add_argument("--remap")
    tr.add_argument("--report")
    args = parser.parse_args(argv)
    if args.command == "transcode":
        return cmd_transcode(args)
    return 2


if __name__ == "__main__":
    sys.exit(main())
