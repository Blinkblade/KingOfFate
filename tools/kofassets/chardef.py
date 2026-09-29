"""Character ``.def`` reader.

Only what a validator needs: the ``[Info]`` block, the ``[Files]`` mapping and the
palette keymap, plus resolution of every referenced file against the search path
the engine itself uses (``engine/ikemen-go/src/char.go``: the character's own
directory first, then ``""``, then ``"data/"``).

Nothing here writes or edits a .def.
"""

from __future__ import annotations

import os

# Keys the engine reads out of [Files]. ``required`` marks the ones a character
# cannot load without (see docs/ikemen_character_architecture.md and the engine's
# char.go, which errors out when sprite/anim/cmd/constants are missing).
FILE_KEYS = {
    "cmd": True,
    "cns": False,       # IKEMEN: "cns" is the constants file, "st" the states
    "st": True,
    "st2": False, "st3": False, "st4": False, "st5": False, "st6": False,
    "st7": False, "st8": False, "st9": False,
    "stcommon": False,
    "sprite": True,
    "anim": True,
    "sound": False,
    "ai": False,
    "movelist": False,
    "intro": False,
    "ending": False,
}
for _i in range(1, 13):
    FILE_KEYS["pal%d" % _i] = False

# Files the engine looks up outside the character directory.
ENGINE_SEARCH_PREFIXES = ("data/", "")


class DefError(Exception):
    """The .def file itself cannot be read."""


class ParsedDef:
    def __init__(self, path):
        self.path = path
        self.directory = os.path.dirname(os.path.abspath(path))
        self.sections = {}          # name -> {key: value}
        self.order = []             # section names in file order
        self.duplicate_keys = []    # (section, key)

    # -- convenience -------------------------------------------------------

    @property
    def name(self):
        return self.sections.get("info", {}).get("name", "")

    @property
    def display_name(self):
        return self.sections.get("info", {}).get("displayname", "")

    def files(self):
        return self.sections.get("files", {})

    def palettes(self):
        return self.sections.get("palette keymap", {})

    def raw(self, section, key, default=""):
        return self.sections.get(section, {}).get(key, default)

    def to_dict(self):
        return {"path": self.path, "directory": self.directory,
                "name": self.name, "display_name": self.display_name,
                "sections": {k: dict(v) for k, v in self.sections.items()}}


def _strip_value(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        value = value[1:-1]
    return value.strip()


def parse(path):
    try:
        with open(path, "rb") as f:
            raw = f.read()
    except OSError as exc:
        raise DefError("cannot read %s: %s" % (path, exc)) from exc

    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        text = raw.decode("latin-1")

    parsed = ParsedDef(path)
    section = None
    for line in text.splitlines():
        # Comments run to end of line and are the dominant syntax in these files.
        line = line.split(";", 1)[0].strip()
        if not line:
            continue
        if line.startswith("[") and "]" in line:
            section = line[1:line.find("]")].strip().lower()
            if section not in parsed.sections:
                parsed.sections[section] = {}
                parsed.order.append(section)
            continue
        if section is None or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip().lower()
        if key in parsed.sections[section]:
            parsed.duplicate_keys.append((section, key))
        parsed.sections[section][key] = _strip_value(value)
    return parsed


def find_engine_root(start=None):
    """Locate ``engine/ikemen-go`` by walking up from ``start`` (or this file)."""
    here = os.path.abspath(start or os.path.dirname(__file__))
    for _ in range(8):
        candidate = os.path.join(here, "engine", "ikemen-go", "data")
        if os.path.isdir(candidate):
            return os.path.join(here, "engine", "ikemen-go")
        parent = os.path.dirname(here)
        if parent == here:
            break
        here = parent
    return None


class ResolvedFile:
    __slots__ = ("key", "declared", "path", "location")

    def __init__(self, key, declared, path=None, location=None):
        self.key = key
        self.declared = declared
        self.path = path
        self.location = location or "missing"

    @property
    def exists(self):
        return self.path is not None and os.path.exists(self.path)

    def to_dict(self):
        return {"key": self.key, "declared": self.declared,
                "resolved": self.path, "location": self.location}


def resolve_files(parsed, engine_root=None):
    """Resolve every [Files] entry.

    ``location`` is one of ``character``, ``engine`` or ``missing`` -- an asset
    that only resolves inside the engine tree is a real finding for P6, because
    the character would not be portable.
    """
    results = {}
    for key, declared in sorted(parsed.files().items()):
        if not declared:
            results[key] = ResolvedFile(key, declared)
            continue
        value = declared.replace("\\", "/")
        candidates = [
            (os.path.join(parsed.directory, *value.split("/")), "character"),
        ]
        if engine_root:
            for prefix in ENGINE_SEARCH_PREFIXES:
                candidates.append((os.path.join(engine_root, prefix, *value.split("/")),
                                   "engine"))
        chosen = None
        for path, location in candidates:
            if os.path.exists(path):
                chosen = ResolvedFile(key, declared, os.path.normpath(path), location)
                break
        if chosen is None:
            chosen = ResolvedFile(key, declared)
        results[key] = chosen
    return results
