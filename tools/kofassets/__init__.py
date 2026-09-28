"""kofassets -- the small shared parsing library behind the KingOfFate asset tools.

Scope (P5)
----------
This package knows how to *read* the character asset formats IKEMEN GO actually
consumes, and nothing else:

    pngio    minimal PNG encode/decode (zlib only)
    sff      SFF v2 sprite containers (header, palettes, sprites, RLE/LZ5)
    air      .air animation tables, including the engine's collision semantics
    chardef  .def files ([Files] section) and path resolution
    report   ERROR / WARNING / INFO model, exit codes, text + JSON output

It deliberately knows **nothing** about writing SFFs or editing AIRs. P5 is
read-only tooling: see docs/character_asset_tooling.md.

Dependencies: the Python standard library only. No Pillow, no numpy.

The parsing algorithms are ports of the engine's own readers so that "what the
tool says" and "what the engine will do" cannot silently drift apart:

    engine/ikemen-go/src/image.go  (SffHeader.Read, readHeaderV2, readV2,
                                    Rle8Decode, Rle5Decode, Lz5Decode, palettes)
    engine/ikemen-go/src/anim.go   (ReadAnimFrame, ReadAnimation, ReadAction)

The engine is a Git submodule and is never modified by these tools.
"""

__all__ = ["pngio", "sff", "air", "chardef", "report"]

__version__ = "0.1.0"
