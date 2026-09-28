#!/usr/bin/env python3
"""Verify the asset reader against inputs whose correct output is known.

Two independent kinds of evidence:

1. **Generated fixtures** -- tiny SFF files built by ``make_fixtures.py`` from a
   known index pattern and a known palette. The decoded RGBA must equal the
   pattern expanded through the palette, byte for byte. This is exact, and it
   covers the raw path and the LZ5 path.

2. **Golden hashes of the real character containers** -- sha256 of the decoded
   RGBA of a few sprites, recorded once in ``expected/decoder_goldens.json``.
   These do not prove the decode is *right*; they prove it has not *changed*.
   Correctness for the real files rests on the human check of the montage
   produced in the P6-ready run (docs/phase_reports/P5-character-asset-tooling.md)
   plus the structural invariants asserted here.

Usage:
    python tests/fixtures/verify_decoders.py            # check
    python tests/fixtures/verify_decoders.py --update   # rewrite the goldens
    python tests/fixtures/verify_decoders.py --json
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools"))
sys.path.insert(0, HERE)

from kofassets import pngio, sff  # noqa: E402
import make_fixtures as fixtures  # noqa: E402

ASSETS = os.path.join(HERE, "assets")
GOLDENS = os.path.join(HERE, "expected", "decoder_goldens.json")

# Sprites from the real containers, chosen because they exercise different things:
# a character body, the projectile sprite (which is a whole borrowed KFM figure),
# and the palette-indexed PNG path (the portrait sprite).
REAL_SPRITES = [
    ("game/chars/test_fighter_b/test_fighter_b.sff", 0, 0, 47, 106, 18, 105),
    ("game/chars/test_fighter_b/test_fighter_b.sff", 1000, 4, 123, 84, 54, 83),
    ("game/chars/test_fighter_b/test_fighter_b.sff", 9000, 1, 120, 140, 0, 0),
    ("game/chars/test_fighter_a/test_fighter_a.sff", 0, 0, 47, 106, 18, 105),
]


class Results:
    def __init__(self):
        self.entries = []

    def check(self, name, passed, detail=""):
        self.entries.append({"name": name, "passed": bool(passed), "detail": detail})
        return passed

    @property
    def failures(self):
        return [e for e in self.entries if not e["passed"]]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def load_goldens():
    if not os.path.exists(GOLDENS):
        return {}
    with open(GOLDENS, "r", encoding="utf-8") as handle:
        return json.load(handle)


def collect_goldens():
    goldens = {"note": "sha256 of the decoded RGBA of selected real sprites. "
                       "Regenerate with: python tests/fixtures/verify_decoders.py --update",
               "fixture_patterns": {}, "real_sprites": {}}
    for key, pattern in (("0,0", fixtures.sprite_pattern_a()),
                         ("1,0", fixtures.sprite_pattern_b()),
                         ("2,0", fixtures.SOLID_PATTERN)):
        expanded = b"".join(bytes(fixtures.PALETTE[index]) for index in pattern)
        goldens["fixture_patterns"][key] = digest(expanded)
    for path, group, image, *_ in REAL_SPRITES:
        container = sff.Sff.load(os.path.join(REPO, path))
        sprite = container.sprite(group, image)
        rgba, _ = container.rgba(sprite)
        goldens["real_sprites"]["%s:%d,%d" % (path, group, image)] = digest(rgba)
    return goldens


def check_fixture_pixels(results):
    container_path = os.path.join(ASSETS, "minimal_v2.sff")
    container = sff.Sff.load(container_path)
    cases = [(0, 0, fixtures.sprite_pattern_a(), 8, 8, 3, 7),
             (1, 0, fixtures.sprite_pattern_b(), 8, 8, 1, 2),
             (2, 0, fixtures.SOLID_PATTERN, 5, 3, 5, 0)]
    for group, image, pattern, width, height, axis_x, axis_y in cases:
        sprite = container.sprite(group, image)
        label = "fixture %d,%d" % (group, image)
        if not results.check("%s exists" % label, sprite is not None):
            continue
        results.check("%s size is %dx%d" % (label, width, height),
                      (sprite.width, sprite.height) == (width, height),
                      "%dx%d" % (sprite.width, sprite.height))
        results.check("%s axis is (%d,%d)" % (label, axis_x, axis_y),
                      (sprite.axis_x, sprite.axis_y) == (axis_x, axis_y),
                      "(%d,%d)" % (sprite.axis_x, sprite.axis_y))
        rgba, _ = container.rgba(sprite)
        expected = b"".join(bytes(fixtures.PALETTE[index]) for index in pattern)
        results.check("%s decodes to the expected pixels" % label, rgba == expected,
                      "sha256 %s vs expected %s" % (digest(rgba)[:16], digest(expected)[:16]))
        transparent = sum(1 for i in range(3, len(rgba), 4) if rgba[i] == 0)
        results.check("%s has both opaque and transparent pixels" % label,
                      0 < transparent < sprite.width * sprite.height,
                      "%d transparent of %d" % (transparent, sprite.width * sprite.height))


def check_png_roundtrip(results):
    width, height = 7, 5
    pixels = bytearray()
    for y in range(height):
        for x in range(width):
            pixels += bytes([(x * 30) % 256, (y * 50) % 256, (x * y) % 256,
                             0 if (x + y) % 3 == 0 else 255])
    encoded = pngio.encode_rgba(width, height, bytes(pixels))
    decoded = pngio.decode(encoded)
    results.check("PNG round-trip keeps the exact pixels",
                  (decoded.width, decoded.height) == (width, height)
                  and decoded.rgba == bytes(pixels),
                  "%dx%d, %d bytes" % (decoded.width, decoded.height, len(decoded.rgba)))
    results.check("PNG round-trip is deterministic",
                  pngio.encode_rgba(width, height, bytes(pixels)) == encoded)


def check_real_containers(results, goldens, update):
    for path, group, image, width, height, axis_x, axis_y in REAL_SPRITES:
        absolute = os.path.join(REPO, path)
        label = "%s %d,%d" % (os.path.basename(path), group, image)
        try:
            container = sff.Sff.load(absolute)
        except sff.SffError as exc:
            results.check("%s loads" % label, False, str(exc))
            continue
        sprite = container.sprite(group, image)
        if not results.check("%s exists" % label, sprite is not None):
            continue
        results.check("%s metadata" % label,
                      (sprite.width, sprite.height, sprite.axis_x, sprite.axis_y)
                      == (width, height, axis_x, axis_y),
                      "%dx%d axis (%d,%d)" % (sprite.width, sprite.height,
                                              sprite.axis_x, sprite.axis_y))
        rgba, _ = container.rgba(sprite)
        results.check("%s decoded size" % label, len(rgba) == width * height * 4)
        key = "%s:%d,%d" % (path, group, image)
        expected = goldens.get("real_sprites", {}).get(key)
        if update:
            results.check("%s golden recorded" % label, True, digest(rgba)[:16])
        elif expected is None:
            results.check("%s golden present" % label, False, "no golden for %s" % key)
        else:
            results.check("%s matches its golden" % label, digest(rgba) == expected,
                          "recorded %s, found %s" % (expected[:16], digest(rgba)[:16]))

    # Structural invariants over every sprite of the real containers: a broad
    # exercise of both decoders, and a guard against silent truncation.
    for path in ("game/chars/_template/_template.sff",
                 "game/chars/test_fighter_a/test_fighter_a.sff",
                 "game/chars/test_fighter_b/test_fighter_b.sff"):
        absolute = os.path.join(REPO, path)
        container = sff.Sff.load(absolute)
        failures = []
        visible_total = 0
        for sprite in container.sprites:
            try:
                rgba, _ = container.rgba(sprite)
            except sff.SffError as exc:
                failures.append("sprite %d: %s" % (sprite.index, exc))
                continue
            if len(rgba) != sprite.width * sprite.height * 4:
                failures.append("sprite %d: %d bytes for %dx%d"
                                % (sprite.index, len(rgba), sprite.width, sprite.height))
            if any(rgba[i] for i in range(3, len(rgba), 4)):
                visible_total += 1
        results.check("%s: all %d sprites decode" % (os.path.basename(path),
                                                     container.sprite_count),
                      not failures, "; ".join(failures[:3]))
        results.check("%s: every sprite has visible pixels" % os.path.basename(path),
                      visible_total == container.sprite_count,
                      "%d of %d" % (visible_total, container.sprite_count))


def check_error_handling(results):
    cases = [
        (os.path.join(ASSETS, "unsupported_v1.sff"), sff.SffUnsupportedError, "v1 refused"),
        (os.path.join(ASSETS, "truncated.sff"), sff.SffCorruptError, "truncated refused"),
        (os.path.join(ASSETS, "bad_signature.sff"), sff.SffFormatError, "bad signature refused"),
    ]
    for path, expected, label in cases:
        try:
            sff.Sff.load(path)
        except expected as exc:
            results.check("%s with a clear message" % label, bool(str(exc)), str(exc)[:80])
        except sff.SffError as exc:
            results.check("%s with the right error type" % label, False,
                          "%s instead of %s" % (type(exc).__name__, expected.__name__))
        except Exception as exc:                      # noqa: BLE001 - that is the point
            results.check("%s without crashing" % label, False,
                          "%s: %s" % (type(exc).__name__, exc))
        else:
            results.check("%s" % label, False, "the file was accepted")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--update", action="store_true", help="rewrite the golden file")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    args = parser.parse_args(argv)

    if args.update:
        os.makedirs(os.path.dirname(GOLDENS), exist_ok=True)
        with open(GOLDENS, "w", encoding="utf-8") as handle:
            json.dump(collect_goldens(), handle, indent=2, sort_keys=True)
            handle.write("\n")
        print("wrote %s" % GOLDENS)
        return 0

    results = Results()
    goldens = load_goldens()
    check_fixture_pixels(results)
    check_png_roundtrip(results)
    check_error_handling(results)
    check_real_containers(results, goldens, update=False)

    if args.json:
        json.dump({"checks": results.entries,
                   "passed": len(results.entries) - len(results.failures),
                   "failed": len(results.failures)},
                  sys.stdout, indent=2)
        sys.stdout.write("\n")
    else:
        for entry in results.entries:
            mark = "PASS" if entry["passed"] else "FAIL"
            line = "  [%s] %s" % (mark, entry["name"])
            if entry["detail"] and not entry["passed"]:
                line += "   (%s)" % entry["detail"]
            print(line)
        total = len(results.entries)
        print("")
        print("decoder checks: %d/%d passed" % (total - len(results.failures), total))

    return 1 if results.failures else 0


if __name__ == "__main__":
    sys.exit(main())
