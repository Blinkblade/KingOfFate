# Test fixtures (P5)

Everything under `assets/` is **generated**. Nothing here is a third-party asset, so
there are no licence obligations and the whole directory is safe to commit.

## What it is for

The P5 asset tools can read the real character containers, but those cannot prove the
reader is *correct*: the containers are placeholder art borrowed from IKEMEN's KFM, and
nobody ever wrote down what pixel should be where. A test against them can only say
"the output did not change".

These fixtures fix that. `make_fixtures.py` writes tiny SFF files from a known index
pattern and a known palette, so the expected RGBA is known exactly and can be asserted
byte for byte -- including the LZ5 path, which the real files depend on for 280 of
their 282 sprites.

## Contents

```text
make_fixtures.py        generate (or --check) everything below
verify_decoders.py      assert the decode, and golden-hash the real containers
expected/
  decoder_goldens.json  sha256 of the decoded RGBA of three real sprites
assets/
  minimal_v2.sff        3 sprites: raw 8-bit, LZ5, non-square raw
  ok.sff                same container under the name airtool auto-detects next to ok.air
  unsupported_v1.sff    a valid SFF v1 file, to check that v1 is refused clearly
  truncated.sff         header promises more data than the file holds
  bad_signature.sff     not an SFF at all
  linked_sprite.sff     a sprite with no data of its own (engine shareCopy path)
  blank_sprite.sff      a sprite the engine leaves blank (data size 0, link out of range)
  ok.air                a clean animation table
  dup_action.air        the same action number twice
  empty_action.air      an action with no elements
  bad_box_count.air     "Clsn1: 3" followed by two boxes
  orphan_box.air        a ClsnX[i] line with no declaration in front of it
  missing_sprite.air    references sprite 99,99
  bad_time.air          time = -2
  p4_per_frame_hold.air P4 negative case: per-frame Clsn1 in front of a -1 hold
  p4_default_hold.air   P4 positive case: Clsn1Default in front of a -1 hold
  char_ok/              a consistent, complete character directory
  char_missing_files/   .def pointing at files that do not exist
  char_zss_missing_anim/ script asks for an animation the AIR does not define
  char_v1_sprite/       .def whose SFF is a version the tooling refuses
```

## Regenerating

```powershell
python tests\fixtures\make_fixtures.py            # rewrite the assets
python tests\fixtures\make_fixtures.py --check    # fail if they differ from the generator
python tests\fixtures\verify_decoders.py --update # rewrite the golden hashes
```

`make_fixtures.py` is the only place in this repository that *writes* an SFF file. That
is deliberate and it is test-only: the product tools are read-only by design
(`docs/character_asset_tooling.md`, "What P5 deliberately does not do"). Do not grow it
into an SFF writer for production use.

## Note on the goldens

The hashes in `expected/decoder_goldens.json` prove the decode **has not changed**, not
that it is right. Correctness rests on the byte-exact assertions above, and on a
one-off comparison of every decoded sprite against the engine's own `Lz5Decode`
(1128 sprites, 0 mismatches; method and result in
`docs/evidence/p5/engine_decoder_crosscheck.txt`). The helper Go program used for that
comparison is deliberately **not** committed, so re-running it means recreating it from
the instructions in that file -- about five minutes of work.

The montage (`python tools\sffctl\sffctl.py montage <sff> --out <png>`) is still the
fastest way to spot something that looks wrong, but it is no longer carrying the
burden of proving the decoder.
