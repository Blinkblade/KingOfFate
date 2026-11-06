#!/usr/bin/env python3
"""sffpack -- assemble SFF v2 containers from existing sprites (P6).

This is the pack half of the Archer asset import: read a source container
(SFF v1 or v2, decoded by ``kofassets/sff.py``) and write a new SFF v2 whose
sprite numbering matches the target character's animation table.

    python tools/sffpack/sffpack.py transcode <in.sff> --out <out.sff>
        [--remap map.csv] [--report FILE]

    python tools/sffpack/sffpack.py set-sprite <in.sff> --out <out.sff>
        --sprite GROUP,NUMBER=art.png [--sprite ...] [--axis GROUP,NUMBER=X,Y ...]

Without ``--remap`` every sprite keeps its (group, image) key -- a faithful
format conversion, used to prove the pipeline byte-for-byte before any
remapping happens. With ``--remap`` the CSV decides the mapping:

    target_group,target_image,source_group,source_image[,axis_x,axis_y]

A named ``palette_index`` column may contain a source palette number or
``source`` to keep that sprite's own palette, overriding --force-palette.

    * one row per sprite in the output, in file order
    * axis columns optional: source axis is kept when they are blank
    * a source key may appear in several rows (the pixels are written once and
      later rows become linked sprites, like the source files do)

Every sprite is re-encoded as raw depth 8 (pixel-exact for palette-indexed
sources). Palettes are deduplicated by content.

``set-sprite`` is the "换一张图" path: every sprite is copied **byte for byte**
(lz5 / PNG / raw alike, palettes untouched) and only the named keys are
replaced — or appended, if the key is new, which is how a character gets art
its placeholder source never had. The output is re-read and every untouched
sprite is compared pixel-exact against the source; a mismatch fails the command
instead of quietly shipping a shifted sprite.

Exit codes: 0 OK / 1 verification failed / 2 usage / 3 IO.
"""

from __future__ import annotations

import argparse
import csv
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

from kofassets import pngio, sff, sffwrite  # noqa: E402


def _fail(message, code):
    print("ERROR: %s" % message)
    return code


def _load_remap(path):
    rows = []
    palette_column = None
    targets = set()
    with open(path, "r", encoding="utf-8-sig", newline="") as handle:
        for lineno, row in enumerate(csv.reader(handle), start=1):
            if not row or not row[0].strip() or row[0].strip().startswith("#"):
                continue
            if lineno == 1 and not row[0].strip().isdigit():
                header = [value.strip().lower() for value in row]
                if "palette_index" in header:
                    palette_column = header.index("palette_index")
                continue   # header row
            if len(row) < 4:
                raise ValueError("%s line %d: need at least 4 columns "
                                 "(target_group,target_image,source_group,source_image)"
                                 % (path, lineno))
            tg, ti, sg, si = (int(row[k].strip()) for k in range(4))
            if (tg, ti) in targets:
                raise ValueError("%s line %d: duplicate target sprite (%d,%d)"
                                 % (path, lineno, tg, ti))
            targets.add((tg, ti))
            axis = None
            # Columns 5 and 6 are optional axis overrides. The asset_map.csv
            # that ships with a character also carries `action` and `notes`
            # columns there, so only take the override when both parse as ints.
            if len(row) >= 6 and row[4].strip() and row[5].strip():
                try:
                    axis = (int(row[4].strip()), int(row[5].strip()))
                except ValueError:
                    axis = None
            palette = None
            if palette_column is not None and len(row) > palette_column:
                value = row[palette_column].strip()
                if value:
                    if value.lower() == "source":
                        palette = "source"
                    else:
                        palette = int(value)
                        if palette < 0:
                            raise ValueError("%s line %d: palette_index must be non-negative or source"
                                             % (path, lineno))
            rows.append((tg, ti, sg, si, axis, palette, lineno))
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
        mapping = [(spr.group, spr.number, spr.group, spr.number, None, None, None)
                   for spr in source.sprites]

    # Deduplicate palettes by content; every sprite references one.
    palette_ids = []
    palette_index_of = {}
    # Reserve the selectable character banks before any effect palettes.
    # Otherwise mirror matches can select an imported effect/debug bank.
    if args.selection_palette:
        base = args.force_palette if args.force_palette is not None else 0
        if not 0 <= base < len(source.palettes):
            return _fail("invalid base palette %d" % base, 2)
        palette_ids.append(source.palettes[base].colours)
        for path in args.selection_palette:
            try:
                with open(path, "rb") as handle:
                    act = handle.read()
            except OSError as exc:
                return _fail(str(exc), 3)
            if len(act) != 768:
                return _fail("%s: an ACT palette must have 768 bytes" % path, 2)
            # MUGEN ACT stores index 255 first; image.go:readActPalette.
            palette_ids.append([tuple(act[765-i*3:768-i*3]) + (0 if i == 0 else 255,)
                                for i in range(256)])
        for index, colours in enumerate(palette_ids):
            palette_index_of.setdefault(tuple(colours), index)
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
    for tg, ti, sg, si, axis, palette_override, lineno in mapping:
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
        if src.is_linked and palette_override is None and not args.selection_palette:
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
        # --force-palette exists because a source container's per-sprite palette
        # bank cannot be trusted blindly: some packs carry a stale debug bank on
        # a few sprites (the high-res Archer has 69 sprites -- idle, walk, jump --
        # pointing at a bank of pure green/magenta/blue, while the other 643 use
        # the real palette). Forcing one bank makes the whole set consistent.
        if palette_override == "source":
            pal_index = src.pal_index
        elif palette_override is not None:
            pal_index = palette_override
        else:
            pal_index = (args.force_palette if args.force_palette is not None
                         else src.pal_index)
        if pal_index >= len(source.palettes):
            problems.append("sprite (%d,%d) wants palette %d but the source has "
                            "only %d" % (sg, si, pal_index, len(source.palettes)))
            continue
        colours = source.palettes[pal_index].colours
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


def cmd_set_sprite(args):
    """Swap (or append) a handful of sprites, copying every other one verbatim."""
    if not os.path.isfile(args.input):
        return _fail("no such file: %s" % args.input, 3)
    try:
        source = sff.Sff.load(args.input)
    except sff.SffError as exc:
        return _fail(str(exc), 3)

    wanted = []           # (group, number, png path)
    for spec in args.sprite:
        if "=" not in spec:
            return _fail("--sprite wants GROUP,NUMBER=PATH, got %r" % spec, 2)
        key, path = spec.split("=", 1)
        parts = key.split(",")
        if len(parts) != 2 or not all(p.strip().isdigit() for p in parts):
            return _fail("--sprite key must be GROUP,NUMBER, got %r" % key, 2)
        if not os.path.isfile(path):
            return _fail("no such PNG: %s" % path, 3)
        wanted.append((int(parts[0]), int(parts[1]), path))
    if not wanted:
        return _fail("nothing to do: pass at least one --sprite", 2)

    axis_override = {}
    for spec in args.axis:
        if "=" not in spec:
            return _fail("--axis wants GROUP,NUMBER=X,Y, got %r" % spec, 2)
        key, value = spec.split("=", 1)
        parts = key.split(",")
        nums = value.split(",")
        if len(parts) != 2 or len(nums) != 2:
            return _fail("--axis wants GROUP,NUMBER=X,Y, got %r" % spec, 2)
        try:
            axis_override[(int(parts[0]), int(parts[1]))] = (int(nums[0]), int(nums[1]))
        except ValueError:
            return _fail("--axis coordinates must be integers, got %r" % value, 2)

    # Copy every existing sprite exactly as stored (lz5 / PNG / raw), so the
    # only difference in the output is the sprites named on the command line.
    entries = []
    for spr in source.sprites:
        entry = {
            "group": spr.group, "number": spr.number,
            "width": spr.width, "height": spr.height,
            "axis_x": spr.axis_x, "axis_y": spr.axis_y,
            "pal_index": spr.pal_index,
            "format": spr.format,
            "depth": spr.coldepth,
            # Bit 0 of the flag word switches the offset base from lofs to tofs;
            # this writer always emits lofs-relative offsets, so drop it.
            "flags": spr.flags & ~1,
            "verbatim": True,
            "payload": b"" if spr.is_linked else bytes(
                source._raw[spr.data_offset:spr.data_offset + spr.data_size]),
        }
        if spr.is_linked:
            entry["link"] = spr.linked_source_index
        entries.append(entry)
    index_of = {(e["group"], e["number"]): i for i, e in enumerate(entries)}

    replaced, added = [], []
    for group, number, path in wanted:
        try:
            image = pngio.read(path)
        except (pngio.PngError, OSError) as exc:
            return _fail("%s: %s" % (path, exc), 3)
        try:
            payload = pngio.encode_rgba(image.width, image.height, image.rgba)
        except pngio.PngError as exc:
            return _fail("%s: %s" % (path, exc), 2)
        key = (group, number)
        old = entries[index_of[key]] if key in index_of else None
        axis = axis_override.get(key)
        if axis is None:
            axis = (old["axis_x"], old["axis_y"]) if old else (
                image.width // 2, image.height // 2)
        entry = {
            "group": group, "number": number,
            "width": image.width, "height": image.height,
            "axis_x": axis[0], "axis_y": axis[1],
            "pal_index": 0,
            "format": sffwrite.FMT_PNG_RGBA2,
            "depth": 32,
            "flags": 0,
            "payload": payload,
        }
        if old is None:
            index_of[key] = len(entries)
            entries.append(entry)
            added.append(key)
        else:
            entries[index_of[key]] = entry
            replaced.append(key)

    palettes = [pal.colours for pal in source.palettes]
    try:
        blob = sffwrite.build_sff_v2(entries, palettes)
        with open(args.out, "wb") as handle:
            handle.write(blob)
    except (sffwrite.SffWriteError, OSError) as exc:
        return _fail(str(exc), 3)

    # Verify: re-read the output and compare every untouched sprite against the
    # source **byte for byte** -- the stored payload, not a decoded bitmap. A
    # silent shift (an offset recomputed one block too far, a length prefix
    # added twice) is the failure mode that matters here, and it is invisible
    # without this pass. Comparing decoded pixels would miss it, and would also
    # false-alarm on PNG8 sprites, which carry their own palette and therefore
    # have a pal_index the container palette cannot satisfy.
    try:
        written = sff.Sff.load(args.out)
    except sff.SffError as exc:
        return _fail("the output cannot be re-read: %s" % exc, 1)
    touched = set((g, n) for g, n, _ in wanted)
    mismatch = []
    if len(written.sprites) != len(entries):
        mismatch.append("sprite count %d, expected %d"
                        % (len(written.sprites), len(entries)))
    compared = 0
    for spr in written.sprites:
        if (spr.group, spr.number) in touched:
            continue
        old = source.sprite(spr.group, spr.number)
        if old is None:
            mismatch.append("(%d,%d) did not exist in the source" % (spr.group, spr.number))
            continue
        if (spr.width, spr.height, spr.axis_x, spr.axis_y) != (
                old.width, old.height, old.axis_x, old.axis_y):
            mismatch.append("(%d,%d): geometry changed" % (spr.group, spr.number))
            continue
        if old.is_linked != spr.is_linked:
            mismatch.append("(%d,%d): link state changed" % (spr.group, spr.number))
            continue
        if old.is_linked:
            if spr.link != old.link:
                mismatch.append("(%d,%d): link target %d, expected %d"
                                % (spr.group, spr.number, spr.link, old.link))
            compared += 1
            continue
        if (spr.format, spr.coldepth, spr.pal_index) != (
                old.format, old.coldepth, old.pal_index):
            mismatch.append("(%d,%d): format/depth/palette changed" % (spr.group, spr.number))
            continue
        got = written._raw[spr.data_offset:spr.data_offset + spr.data_size]
        want = source._raw[old.data_offset:old.data_offset + old.data_size]
        if got != want:
            mismatch.append("(%d,%d): %d stored bytes differ from the source's %d"
                            % (spr.group, spr.number, len(got), len(want)))
            continue
        compared += 1
    if mismatch:
        for line in mismatch[:10]:
            print("ERROR: %s" % line)
        return _fail("%d verification failure(s)" % len(mismatch), 1)

    print("set-sprite: %s -> %s" % (args.input, args.out))
    print("  source:   %s, %d sprites, %d palettes"
          % (source.version_string, len(source.sprites), len(source.palettes)))
    print("  replaced: %s" % (", ".join("%d,%d" % k for k in replaced) or "-"))
    print("  added:    %s" % (", ".join("%d,%d" % k for k in added) or "-"))
    print("  written:  2.0.1.0, %d sprites, %d bytes" % (len(entries), len(blob)))
    print("  verify:   re-read OK; %d untouched sprites compared byte-exact, 0 mismatch"
          % compared)
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    tr = sub.add_parser("transcode", help="convert a source SFF to SFF v2")
    tr.add_argument("input")
    tr.add_argument("--out", required=True)
    tr.add_argument("--remap")
    tr.add_argument("--report")
    tr.add_argument("--force-palette", type=int, default=None, metavar="N",
                    help="render every sprite through palette N instead of "
                         "each sprite's own bank (some packs ship stale banks)")
    tr.add_argument("--selection-palette", action="append", default=[], metavar="ACT",
                    help="reserve a selectable ACT bank after the base palette; repeat for further banks")
    ss = sub.add_parser("set-sprite",
                        help="replace or append sprites, copying the rest verbatim")
    ss.add_argument("input")
    ss.add_argument("--out", required=True)
    ss.add_argument("--sprite", action="append", default=[], metavar="G,N=PATH",
                    help="replace sprite (G,N) with this PNG, or append it if new; repeatable")
    ss.add_argument("--axis", action="append", default=[], metavar="G,N=X,Y",
                    help="override the axis for that sprite; defaults to the "
                         "replaced sprite's axis, or the PNG centre when new")
    args = parser.parse_args(argv)
    if args.command == "transcode":
        return cmd_transcode(args)
    if args.command == "set-sprite":
        return cmd_set_sprite(args)
    return 2


if __name__ == "__main__":
    sys.exit(main())
