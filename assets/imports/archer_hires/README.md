# High-resolution Archer source (P6 art upgrade)

## Why this folder exists

P6 v1 shipped with **kuri's 2005 MUGEN Archer** (`assets/imports/archer/`).
Its sprites are 54×120 for the body — small, and its animation numbering does
not follow a modern four-button layout (which is why our first mapping put a
"raised swords" pose on the heavy kick).

The owner's decision (2026-09-30): use the **finest source available now**,
because the art will be re-drawn by AI later — a sharper input makes that
re-draw better. So we are switching the art source, not the architecture.

## What was ruled out

**Fate/Unlimited Codes (2008, TYPE-MOON / CAPCOM / Cavia / 8ing) sprite rips.**
Checked and rejected: the game is **3D-model based**, so there are no 2D sprite
sheets to cut. The Spriters Resource lists it with **0 assets** (verified
2026-09-30, `spriters-resource.com/arcade/fateunlimitedcodes/` redirects to the
PS2 entry). Extracting its models and rendering frames would be a multi-day
job with high risk, and would need a whole new capture pipeline.

## What to download

**`Archer / EMIYA (Custom Sprited High Res)` by aka65535 / Sho** — custom-drawn
high-resolution 2D sprites (Guilty Gear-ish 5-button playstyle), published
2017, latest revision 8/6/2017.

- Collection page (MFFA, same source we used for kuri):
  <https://mugenfreeforall.com/topic/48291-fate-series/> →
  expand the SERVANTS section → **Archer / EMIYA (Custom Sprited High Res)**
- Author's own thread with the announcement and a NicoNico preview:
  <https://mugenfreeforall.com/topic/32804-archeremiya-by-aka65535-updated-8617>

**Put the archive here** as `assets/imports/archer_hires/<whatever>.zip|rar|7z`
(do not unpack it; the tools read archives are not needed — unpacking is a
one-liner with bsdtar).

### Why it is worth it

- Sprites are several times larger than kuri's, which is what the AI re-draw
  needs most.
- It is a **MUGEN character pack**, i.e. an SFF container — so the pipeline we
  already have (v1/v2 reader, `sffpack transcode`, `asset_map.csv`) applies
  **unchanged**. No sprite-sheet cutter has to be written. That was the entire
  cost of the FUC route, and it disappears with this choice.

### Also on the shortlist (if the first one disappoints)

| Variant | Note |
| --- | --- |
| `EMIYA (Fate Sword Dance Sprite Edit)` — No Name / Himegami / Org | same base as kuri, edited |
| `EMIYA (Jump Ultimate Stars Sprite Edit)` — Mugen n5 / DYT59 / Vezz | JUS-style, cleaner limbs |
| `EMIYA (Jump Ultimate Stars Sprite Edit 2)` — InSeph | modern edit |
| Emiya (Academy Style) — InSeph, on Patreon | newest / highest quality, but gated |

## What happens after the file lands

1. `sffctl inspect` + `airtool inspect` — version, sprite count, sprite sizes,
   action coverage (compare against the 88 actions our skeleton needs).
2. Decide the mix: if the new pack is missing whole ranges (e.g. no UBW
   activation, no hit/knockdown set), we can **mix sources per group** — the
   asset_map already picks each sprite individually.
3. Rewrite `design/characters/archer/asset_map.csv` against the new source,
   transcode, validate, test in-engine, and screenshot for the owner.

## Licence

Fan work derived from TYPE-MOON's Archer, same situation as kuri's pack:
non-commercial fan game only. Register the new source in
`assets/LICENSE_MANIFEST.csv` with the author name (aka65535 / Sho), the
download date and the source URL as soon as the archive lands.
