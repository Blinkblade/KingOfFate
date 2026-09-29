"""AIR (animation table) reader with the engine's *effective* collision semantics.

Ported from ``engine/ikemen-go/src/anim.go`` (``ReadAnimFrame``, ``ReadAnimation``,
``ReadAction``, ``AnimationTable.readAction``).

The one part that really matters for P5 is collision scope, so it is spelled out
here because the two declarations behave differently and confusing them was the
most expensive bug of P4:

    Clsn1: 1 / Clsn1[0] = ...        per-frame: applies to the *next element only*
    Clsn1Default: 1 / Clsn1[0] = ... applies to *every* element of the action

That asymmetry is not folklore, it falls out of the parser: the ``def1`` flag is
set to false by a declaration and reset to true after every element line, so an
element whose predecessor declared a plain ``Clsn1`` is the only one that keeps
it -- unless the box came from ``Clsn1Default``, which every element re-inherits
(``ReadAnimation``, anim.go:311-324 and 335-364).

This module therefore reports, for every element, both the boxes and *where they
came from* -- ``default``, ``per-frame``, ``cleared`` or ``none``. A projectile
animation that declares ``Clsn1`` (not ``Clsn1Default``) before its ``-1`` hold
frame shows up as ``per-frame`` on one element and ``none`` on the hold frame;
that is exactly the P4 symptom, and it is visible in the tool output instead of
having to be remembered.
"""

from __future__ import annotations

from .report import ERROR, WARNING, INFO, Finding

MODE_DEFAULT = "default"
MODE_PER_FRAME = "per-frame"
MODE_CLEARED = "cleared"
MODE_NONE = "none"


class AirError(Exception):
    """Raised when a file cannot be read at all."""


class Box:
    __slots__ = ("left", "top", "right", "bottom", "line")

    def __init__(self, left, top, right, bottom, line=None):
        # ReadAnimation normalises the rectangle so that left<=right, top<=bottom.
        if left > right:
            left, right = right, left
        if top > bottom:
            top, bottom = bottom, top
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
        self.line = line

    @property
    def width(self):
        return self.right - self.left

    @property
    def height(self):
        return self.bottom - self.top

    def to_list(self):
        return [self.left, self.top, self.right, self.bottom]

    def to_dict(self):
        return {"left": self.left, "top": self.top, "right": self.right,
                "bottom": self.bottom, "width": self.width, "height": self.height}

    def __repr__(self):
        return "Box(%d,%d,%d,%d)" % (self.left, self.top, self.right, self.bottom)


class Element:
    """One animation element: a sprite reference plus how long it is shown."""

    __slots__ = ("index", "line", "raw", "group", "image", "x", "y", "time",
                 "flip", "blend", "xscale", "yscale", "angle",
                 "clsn1", "clsn2", "clsn1_mode", "clsn2_mode", "problems")

    def __init__(self, index, line, raw):
        self.index = index
        self.line = line
        self.raw = raw
        self.group = 0
        self.image = 0
        self.x = 0
        self.y = 0
        self.time = 0
        self.flip = ""
        self.blend = ""
        self.xscale = None
        self.yscale = None
        self.angle = None
        self.clsn1 = []
        self.clsn2 = []
        self.clsn1_mode = MODE_NONE
        self.clsn2_mode = MODE_NONE
        self.problems = []

    @property
    def infinite(self):
        return self.time == -1

    @property
    def sprite(self):
        return (self.group, self.image)

    def to_dict(self):
        out = {
            "index": self.index,
            "line": self.line,
            "sprite": {"group": self.group, "image": self.image},
            "x": self.x,
            "y": self.y,
            "time": self.time,
            "infinite": self.infinite,
            "flip": self.flip,
            "clsn1": {"mode": self.clsn1_mode, "count": len(self.clsn1),
                      "boxes": [b.to_list() for b in self.clsn1]},
            "clsn2": {"mode": self.clsn2_mode, "count": len(self.clsn2),
                      "boxes": [b.to_list() for b in self.clsn2]},
        }
        if self.blend:
            out["blend"] = self.blend
        if self.xscale is not None:
            out["xscale"] = self.xscale
        if self.yscale is not None:
            out["yscale"] = self.yscale
        if self.angle is not None:
            out["angle"] = self.angle
        return out


class Action:
    __slots__ = ("number", "line", "elements", "loopstart", "copy_action",
                 "interpolate", "declared_boxes", "ignored_box_lines", "cleared_clsn1",
                 "problems")

    def __init__(self, number, line):
        self.number = number
        self.line = line
        self.elements = []
        self.loopstart = None
        self.copy_action = None
        self.interpolate = []
        self.declared_boxes = []      # (kind, declared_count, found_count, line, is_default)
        self.ignored_box_lines = []   # box lines with no matching declaration
        # True when the author wrote an explicit "Clsn1: 0": they deliberately
        # ended the attack window, so an -1 hold with no attack box is intended.
        self.cleared_clsn1 = False
        self.problems = []

    @property
    def element_count(self):
        return len(self.elements)

    @property
    def has_infinite_frame(self):
        return any(e.infinite for e in self.elements)

    @property
    def last_element_infinite(self):
        return bool(self.elements) and self.elements[-1].infinite

    @property
    def finite_ticks(self):
        """Sum of the element durations, excluding any -1 hold."""
        return sum(e.time for e in self.elements if e.time > 0)

    @property
    def total_ticks(self):
        """Finite tick count, or None when the action holds forever."""
        if self.has_infinite_frame:
            return None
        return self.finite_ticks

    def attack_elements(self):
        return [e for e in self.elements if e.clsn1]

    def to_dict(self, include_elements=False):
        out = {
            "action": self.number,
            "line": self.line,
            "elements": self.element_count,
            "has_infinite_frame": self.has_infinite_frame,
            "finite_ticks": self.finite_ticks,
            "duration": self.total_ticks if self.total_ticks is not None else "infinite",
            "loopstart": self.loopstart,
        }
        if self.copy_action is not None:
            out["copy_action"] = self.copy_action
        if self.interpolate:
            out["interpolate"] = sorted(set(self.interpolate))
        modes = {e.clsn1_mode for e in self.elements}
        out["clsn1_modes"] = sorted(modes) if modes else []
        out["clsn1_elements"] = [e.index for e in self.attack_elements()]
        if include_elements:
            out["element_data"] = [e.to_dict() for e in self.elements]
        return out


def _atoi(text):
    """MUGEN's atoi: leading-number parse, 0 when there is no number at all."""
    s = text.strip()
    if not s:
        return 0
    i = 0
    if s[0] in "+-":
        i = 1
    j = i
    while j < len(s) and s[j].isdigit():
        j += 1
    if j == i:
        return 0
    try:
        return int(s[:j])
    except ValueError:
        return 0


def _is_numeric(text):
    text = text.strip()
    if not text:
        return False
    try:
        float(text)
        return True
    except ValueError:
        return False


def parse_element(line, line_no, raw, problems):
    """Parse one element line. Returns an Element, or None if it is not one."""
    if not raw or not (raw[0].isdigit() or raw[0] == "-"):
        return None

    fields = [p.strip() for p in raw.split(",", 9)]
    if len(fields) < 5:
        problems.append(Finding(
            ERROR, "AIR_ELEMENT_TOO_FEW_FIELDS",
            "animation element has %d comma-separated fields, at least 5 are required "
            "(group, image, x, y, time)" % len(fields),
            line=line_no, hint=raw))
        return None

    element = Element(-1, line_no, raw)
    element.group = _atoi(fields[0])
    element.image = _atoi(fields[1])
    element.x = _atoi(fields[2])
    element.y = _atoi(fields[3])
    element.time = _atoi(fields[4])

    if len(fields) >= 6 and fields[5]:
        element.flip = fields[5]
        for ch in fields[5]:
            if ch in "Hh":
                element.x = -element.x
            elif ch in "Vv":
                element.y = -element.y
            else:
                element.problems.append(
                    "invalid flip flag %r (only H and V are accepted)" % ch)
    if len(fields) >= 7 and fields[6]:
        element.blend = fields[6]
    if len(fields) >= 8 and fields[7]:
        if _is_numeric(fields[7]):
            element.xscale = float(fields[7])
        else:
            element.problems.append("invalid x-scale %r" % fields[7])
    if len(fields) >= 9 and fields[8]:
        if _is_numeric(fields[8]):
            element.yscale = float(fields[8])
        else:
            element.problems.append("invalid y-scale %r" % fields[8])
    if len(fields) >= 10 and fields[9]:
        if _is_numeric(fields[9]):
            element.angle = float(fields[9])
        else:
            element.problems.append("invalid angle %r" % fields[9])
    return element


def parse_boxes(lines, i, count, kind, line_no_of_decl):
    """Read ``count`` box lines starting at index i (already past the declaration).

    Mirrors the inner loop of ``ReadAnimation``: it stops early when a line is not
    a ``clsn`` line, so a declaration promising more boxes than follow is a real
    defect and is reported as such.
    """
    boxes = []
    n = 0
    while n < count and i < len(lines):
        stripped = lines[i].split(";", 1)[0].strip()
        if not stripped:
            i += 1
            continue
        if stripped[:4].lower() != "clsn":
            break
        eq = stripped.find("=")
        if eq < 0:
            break
        parts = [p.strip() for p in stripped[eq + 1:].split(",")]
        if len(parts) < 4:
            break
        boxes.append(Box(_atoi(parts[0]), _atoi(parts[1]), _atoi(parts[2]), _atoi(parts[3]),
                         line=i + 1))
        n += 1
        i += 1
    return boxes, i, n


_INTERPOLATE_KEYWORDS = ("interpolate offset", "interpolate scale",
                         "interpolate angle", "interpolate blend")


def _interpolate_keyword(lowered):
    for keyword in _INTERPOLATE_KEYWORDS:
        if lowered.startswith(keyword):
            return keyword.split()[1]
    return None


def parse_action(lines, start):
    """Parse one ``[Begin Action N]`` section starting at line index ``start``."""
    header = lines[start].strip()
    inner = header[1:header.find("]")] if "]" in header else header[1:]
    after = inner[len("begin"):].strip() if inner.lower().startswith("begin") else inner
    if not after.lower().startswith("action"):
        return None, start + 1, None
    number_text = after[len("action"):].strip()
    problem = None
    try:
        number = int(number_text)
    except ValueError:
        number = 0
        problem = "action number %r is not an integer (the engine reads it as 0)" % number_text

    action = Action(number, start + 1)
    if problem:
        action.problems.append(problem)

    i = start + 1
    # Collision state machine, copied from ReadAnimation.
    clsn1, clsn2 = [], []
    clsn1_default, clsn2_default = [], []
    use_default1, use_default2 = True, True
    last_kind1, last_kind2 = MODE_NONE, MODE_NONE

    while i < len(lines):
        stripped = lines[i].split(";", 1)[0].strip()
        if stripped.startswith("["):
            break

        lowered = stripped.lower()
        if not lowered:
            i += 1
            continue

        if lowered.startswith("copy action"):
            value = stripped[len("copy action"):].strip()
            try:
                action.copy_action = int(value)
            except ValueError:
                action.copy_action = -1
                action.problems.append("copy action target %r is not an integer" % value)
            i += 1
            break

        if lowered.startswith("loopstart"):
            action.loopstart = len(action.elements)
            i += 1
            continue

        interpolate = _interpolate_keyword(lowered)
        if interpolate is not None:
            action.interpolate.append(interpolate)
            i += 1
            continue

        if lowered[:4] == "clsn":
            colon = stripped.find(":")
            if colon < 0:
                # A box line that lost its declaration, or a malformed declaration.
                if stripped[:5].lower().startswith("clsn") and "[" in stripped:
                    action.ignored_box_lines.append(i + 1)
                    i += 1
                    continue
                action.problems.append("malformed collision declaration: %r" % stripped)
                i += 1
                continue

            which = lowered[4:5]
            if which not in ("1", "2"):
                action.problems.append("unknown collision group in %r" % stripped)
                i += 1
                continue
            is_default = lowered[5:12] == "default"
            count_text = stripped[colon + 1:].strip()
            declared = _atoi(count_text)
            if declared < 0:
                action.problems.append(
                    "collision declaration %r has a negative box count" % stripped)
                i += 1
                continue

            boxes, i, found = parse_boxes(lines, i + 1, declared, which, i + 1)
            if declared == 0:
                boxes = []
            if found != declared:
                action.problems.append(
                    "Clsn%s%s declares %d box(es) at line %d but only %d follow"
                    % (which, "Default" if is_default else "", declared, i + 1, found))
            if which == "1":
                clsn1 = boxes
                if is_default:
                    clsn1_default = boxes
                else:
                    action.cleared_clsn1 = action.cleared_clsn1 or not boxes
                last_kind1 = MODE_DEFAULT if is_default else (
                    MODE_PER_FRAME if boxes else MODE_CLEARED)
                use_default1 = False
            else:
                clsn2 = boxes
                if is_default:
                    clsn2_default = boxes
                last_kind2 = MODE_DEFAULT if is_default else (
                    MODE_PER_FRAME if boxes else MODE_CLEARED)
                use_default2 = False
            action.declared_boxes.append({
                "kind": "Clsn%s%s" % (which, "Default" if is_default else ""),
                "declared": declared, "found": found, "line": i,
            })
            continue

        element = parse_element(stripped, i + 1, stripped, action.problems)
        if element is None:
            i += 1
            continue

        if use_default1:
            element.clsn1 = clsn1_default
            element.clsn1_mode = MODE_DEFAULT if clsn1_default else MODE_NONE
        else:
            element.clsn1 = clsn1
            element.clsn1_mode = last_kind1
        if use_default2:
            element.clsn2 = clsn2_default
            element.clsn2_mode = MODE_DEFAULT if clsn2_default else MODE_NONE
        else:
            element.clsn2 = clsn2
            element.clsn2_mode = last_kind2

        element.index = len(action.elements)
        action.elements.append(element)
        use_default1, use_default2 = True, True
        i += 1

    return action, i, problem


class Air:
    """A parsed .air file."""

    def __init__(self, path):
        self.path = path
        self.actions = []
        self.by_number = {}
        self.duplicates = []
        self.problems = []       # list[Finding]
        self.line_count = 0
        self.encoding = "utf-8"

    @classmethod
    def load(cls, path):
        air = cls(path)
        try:
            with open(path, "rb") as f:
                raw = f.read()
        except OSError as exc:
            raise AirError("cannot read %s: %s" % (path, exc)) from exc
        try:
            text = raw.decode("utf-8-sig")
        except UnicodeDecodeError:
            text = raw.decode("latin-1")
            air.encoding = "latin-1"
            air.problems.append(Finding(
                WARNING, "AIR_ENCODING", "file is not valid UTF-8; read as latin-1", file=path))
        air.parse(text)
        return air

    def parse(self, text):
        lines = text.splitlines()
        self.line_count = len(lines)
        i = 0
        while i < len(lines):
            stripped = lines[i].split(";", 1)[0].strip()
            if stripped.startswith("["):
                action, i, problem = parse_action(lines, i)
                if action is None:
                    self.problems.append(Finding(
                        ERROR, "AIR_BAD_SECTION",
                        "line looks like a section but is not '[Begin Action N]': %r" % stripped,
                        file=self.path, line=i))
                    i += 1
                    continue
                for msg in action.problems:
                    self.problems.append(Finding(
                        ERROR, "AIR_ACTION_PROBLEM", msg, file=self.path,
                        action=action.number))
                self.actions.append(action)
                if action.number in self.by_number:
                    self.duplicates.append(action.number)
                    self.problems.append(Finding(
                        ERROR, "AIR_DUPLICATE_ACTION",
                        "action %d is defined more than once; the engine keeps the first "
                        "definition and silently discards the rest" % action.number,
                        file=self.path, action=action.number, line=action.line))
                else:
                    self.by_number[action.number] = action
                continue
            i += 1

    def action(self, number):
        return self.by_number.get(number)

    def group_actions(self):
        """All actions, duplicates included, sorted by number."""
        return sorted(self.actions, key=lambda a: a.number)

    def sprite_references(self):
        """Every (group, image) an element points at, with the actions using it."""
        refs = {}
        for action in self.actions:
            for element in action.elements:
                refs.setdefault(element.sprite, set()).add(action.number)
        return refs
