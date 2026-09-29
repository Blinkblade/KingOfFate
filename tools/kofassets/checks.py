"""Validation rules shared by ``airtool`` and ``character_validate``.

Keeping the rules here means a finding can never be reported by one tool and
missed by the other. Every rule returns :class:`kofassets.report.Finding`
objects; nothing in this module prints, exits or writes.

Rule reference (used by the docs and by the tests):

    AIR_DUPLICATE_ACTION        two [Begin Action N] sections share a number
    AIR_EMPTY_ACTION            an action with no elements
    AIR_BAD_TIME                time outside the legal range
    AIR_BOX_COUNT_MISMATCH      "Clsn1: 3" followed by fewer than 3 box lines
    AIR_ORPHAN_BOX_LINE         a ClsnX[i] line with no declaration in front of it
    AIR_MISSING_SPRITE          an element points at a sprite the SFF does not have
    AIR_ATTACK_NOT_PERSISTENT   attack box on an earlier element, none on the -1 hold
    AIR_ATTACK_PERSISTENT       attack box on an -1 hold, provided by Clsn1Default
    AIR_HURTBOX_GAP             some elements have a hurtbox, others in the same action do not
    AIR_NO_HURTBOX              no element of the action has a hurtbox
    AIR_DEGENERATE_BOX          a collision box with zero area
    AIR_BOX_OUT_OF_RANGE        a collision box far outside the character's size
    SFF_*                       see sffctl
    DEF_*                       see character_validate
"""

from __future__ import annotations

import os
import re

from . import air as air_mod
from . import chardef
from .report import ERROR, WARNING, INFO, Finding

# A character in this project is never wider than a few hundred pixels; a box that
# reaches past this is a typo, not a design decision.
BOX_COORDINATE_LIMIT = 2000
# Elements longer than this are almost always a missing digit, not a real hold.
TIME_SUSPICIOUS_LIMIT = 1000


# ---------------------------------------------------------------------------
# .air structure
# ---------------------------------------------------------------------------


def check_air_structure(air):
    findings = []
    for action in air.actions:
        if not action.elements:
            findings.append(Finding(
                ERROR, "AIR_EMPTY_ACTION",
                "action %d has no animation elements" % action.number,
                file=air.path, action=action.number, line=action.line,
                hint="the engine does not leave such an action empty: it silently copies the "
                     "next action found in the file, so this is almost always a mistake"))

        for element in action.elements:
            if element.time == 0:
                findings.append(Finding(
                    WARNING, "AIR_BAD_TIME",
                    "action %d element %d (sprite %d,%d) has time = 0, so it is never displayed"
                    % (action.number, element.index, element.group, element.image),
                    file=air.path, action=action.number, line=element.line))
            elif element.time < -1:
                findings.append(Finding(
                    ERROR, "AIR_BAD_TIME",
                    "action %d element %d has time = %d; only -1 is a legal negative value"
                    % (action.number, element.index, element.time),
                    file=air.path, action=action.number, line=element.line))
            elif element.time > TIME_SUSPICIOUS_LIMIT:
                findings.append(Finding(
                    WARNING, "AIR_BAD_TIME",
                    "action %d element %d has time = %d, which is unusually long"
                    % (action.number, element.index, element.time),
                    file=air.path, action=action.number, line=element.line))

            if element.time == -1 and element.index != len(action.elements) - 1:
                findings.append(Finding(
                    WARNING, "AIR_BAD_TIME",
                    "action %d element %d holds forever (-1) but %d element(s) follow it; those "
                    "elements are unreachable"
                    % (action.number, element.index,
                       len(action.elements) - 1 - element.index),
                    file=air.path, action=action.number, line=element.line))

            for problem in element.problems:
                findings.append(Finding(
                    ERROR, "AIR_ELEMENT_PROBLEM",
                    "action %d element %d: %s" % (action.number, element.index, problem),
                    file=air.path, action=action.number, line=element.line))

        for entry in action.declared_boxes:
            if entry["declared"] != entry["found"]:
                findings.append(Finding(
                    ERROR, "AIR_BOX_COUNT_MISMATCH",
                    "action %d: %s declares %d box(es) but only %d follow"
                    % (action.number, entry["kind"], entry["declared"], entry["found"]),
                    file=air.path, action=action.number, line=entry["line"],
                    hint="the engine stops reading at the first line that is not a collision "
                         "box, so the remaining boxes are lost"))

        for line_no in action.ignored_box_lines:
            findings.append(Finding(
                WARNING, "AIR_ORPHAN_BOX_LINE",
                "action %d has a collision box line at line %d that follows no declaration; "
                "the engine ignores it" % (action.number, line_no),
                file=air.path, action=action.number, line=line_no))

    for problem in air.problems:
        if problem.code.startswith("AIR_DUPLICATE") or problem.code == "AIR_ACTION_PROBLEM":
            findings.append(problem)
    return findings


# ---------------------------------------------------------------------------
# Sprite references
# ---------------------------------------------------------------------------


def check_sprite_references(air, sff, max_reported=25):
    """Every element must point at a sprite that exists in the character's SFF."""
    findings = []
    reported = 0
    missing_by_action = {}
    for action in air.actions:
        for element in action.elements:
            if sff is None or sff.has_sprite(element.group, element.image):
                continue
            key = (action.number, element.group, element.image)
            if key in missing_by_action:
                continue
            missing_by_action[key] = element.line
            reported += 1
            if reported <= max_reported:
                findings.append(Finding(
                    ERROR, "AIR_MISSING_SPRITE",
                    "action %d element %d references sprite %d,%d which does not exist in %s"
                    % (action.number, element.index, element.group, element.image,
                       os.path.basename(sff.path) if sff else "the SFF"),
                    file=air.path, action=action.number, line=element.line,
                    group=element.group, image=element.image))
    if reported > max_reported:
        findings.append(Finding(
            ERROR, "AIR_MISSING_SPRITE",
            "%d further missing sprite references were not listed" % (reported - max_reported),
            file=air.path))
    return findings


# ---------------------------------------------------------------------------
# Collision semantics
# ---------------------------------------------------------------------------


def check_collision_semantics(air):
    """Static checks that follow from how the engine scopes collision boxes.

    ``Clsn1``/``Clsn2`` apply to the single element that follows them;
    ``Clsn1Default``/``Clsn2Default`` apply to every element of the action
    (see the module docstring of kofassets.air, and P4's Gate 7 evidence).
    """
    findings = []
    for action in air.actions:
        if not action.elements:
            continue

        attack = action.attack_elements()
        infinite = [e for e in action.elements if e.infinite]

        # P4's exact symptom: attack collision declared per-frame, then a hold frame
        # that carries none -- the projectile flies and never connects. An action that
        # explicitly writes "Clsn1: 0" has ended its attack window on purpose (that is
        # how the air normals do it, where the -1 hold is "freeze until landing"), so
        # only actions that never clear the box are reported.
        if attack and infinite and not action.cleared_clsn1:
            for element in infinite:
                if element.clsn1:
                    if element.clsn1_mode == air_mod.MODE_DEFAULT:
                        findings.append(Finding(
                            INFO, "AIR_ATTACK_PERSISTENT",
                            "action %d holds forever (-1) with an attack box inherited from "
                            "Clsn1Default; the box stays active for the whole hold, which is "
                            "what a projectile needs" % action.number,
                            file=air.path, action=action.number, line=element.line))
                    continue
                if element.clsn1_mode != air_mod.MODE_NONE:
                    continue
                first = attack[0]
                findings.append(Finding(
                    WARNING, "AIR_ATTACK_NOT_PERSISTENT",
                    "action %d declares an attack box on element %d (%s) but the element that "
                    "holds forever (-1, element %d) carries none, so the attack is only active "
                    "for %d tick(s)"
                    % (action.number, first.index, first.clsn1_mode, element.index,
                       first.time if first.time > 0 else 0),
                    file=air.path, action=action.number, line=element.line,
                    hint="a per-frame 'Clsn1:' covers one element only. If the attack is meant "
                         "to persist, declare it as 'Clsn1Default:' -- this is the P4 projectile "
                         "finding (docs/P4-summary.md 3.1)"))

        # Hurtbox coverage inside one action: a gap means the character is
        # invulnerable for those ticks, which is rarely intended in an attack.
        if len(action.elements) > 1:
            covered = [e for e in action.elements if e.clsn2]
            if covered and len(covered) != len(action.elements):
                gaps = [e for e in action.elements if not e.clsn2]
                ticks = sum(e.time for e in gaps if e.time > 0)
                findings.append(Finding(
                    WARNING, "AIR_HURTBOX_GAP",
                    "action %d has no hurtbox (Clsn2) on element(s) %s (%d tick(s) total) while "
                    "other elements in the same action do have one"
                    % (action.number, ",".join(str(e.index) for e in gaps), ticks),
                    file=air.path, action=action.number, line=action.line,
                    hint="a per-frame 'Clsn2:' applies to one element only; use 'Clsn2Default:' "
                         "to cover the whole action. No hurtbox means the character cannot be hit "
                         "during those ticks"))
            elif not covered:
                findings.append(Finding(
                    INFO, "AIR_NO_HURTBOX",
                    "action %d has no hurtbox on any element" % action.number,
                    file=air.path, action=action.number, line=action.line))

        # Degenerate or implausible boxes.
        for element in action.elements:
            for group, boxes in (("Clsn1", element.clsn1), ("Clsn2", element.clsn2)):
                for box in boxes:
                    if box.width == 0 or box.height == 0:
                        findings.append(Finding(
                            WARNING, "AIR_DEGENERATE_BOX",
                            "action %d element %d has a zero-area %s box (%d,%d,%d,%d)"
                            % (action.number, element.index, group,
                               box.left, box.top, box.right, box.bottom),
                            file=air.path, action=action.number, line=box.line or element.line))
                    elif (max(abs(box.left), abs(box.right)) > BOX_COORDINATE_LIMIT
                          or max(abs(box.top), abs(box.bottom)) > BOX_COORDINATE_LIMIT):
                        findings.append(Finding(
                            WARNING, "AIR_BOX_OUT_OF_RANGE",
                            "action %d element %d has a %s box far outside the character's size "
                            "(%d,%d,%d,%d)"
                            % (action.number, element.index, group,
                               box.left, box.top, box.right, box.bottom),
                            file=air.path, action=action.number, line=box.line or element.line))
    return findings


# ---------------------------------------------------------------------------
# Character level
# ---------------------------------------------------------------------------


def check_def(parsed, resolved, expected_name=None):
    findings = []

    if not parsed.name:
        findings.append(Finding(
            ERROR, "DEF_MISSING_NAME", "[Info] name is empty; the engine needs it to select "
            "the character", file=parsed.path))
    elif expected_name and parsed.name.lower() != expected_name.lower():
        findings.append(Finding(
            WARNING, "DEF_NAME_MISMATCH",
            "[Info] name is %r but the character directory is %r"
            % (parsed.name, expected_name), file=parsed.path))
    if not parsed.display_name:
        findings.append(Finding(
            WARNING, "DEF_MISSING_DISPLAYNAME",
            "[Info] displayname is empty, so the select screen shows nothing",
            file=parsed.path))

    if not parsed.files():
        findings.append(Finding(
            ERROR, "DEF_NO_FILES", "the .def has no [Files] section, so nothing can be loaded",
            file=parsed.path))
        return findings

    for key, value in sorted(parsed.files().items()):
        required = chardef.FILE_KEYS.get(key)
        entry = resolved.get(key)
        if not value:
            if required:
                findings.append(Finding(
                    ERROR, "DEF_MISSING_FILE_ENTRY",
                    "[Files] %s is required but empty" % key, file=parsed.path, hint=key))
            continue
        if entry is None or not entry.exists:
            severity = ERROR if required or key in ("anim", "sprite") else WARNING
            findings.append(Finding(
                severity, "DEF_UNRESOLVED_FILE",
                "[Files] %s = %s cannot be found (looked in the character directory%s)"
                % (key, value,
                   " and the engine tree" if chardef.find_engine_root(parsed.directory) else ""),
                file=parsed.path, hint=key))
            continue
        if key in ("sprite", "anim", "cmd", "cns", "st", "sound") and entry.location != "character":
            findings.append(Finding(
                ERROR, "DEF_FILE_OUTSIDE_CHARACTER",
                "[Files] %s = %s resolves to %s, outside the character directory"
                % (key, value, entry.path), file=parsed.path, hint=key))

    for section, key in parsed.duplicate_keys:
        findings.append(Finding(
            WARNING, "DEF_DUPLICATE_KEY",
            "[%s] %s is defined more than once; the last value wins"
            % (section.title(), key), file=parsed.path))

    for key in parsed.files():
        if key not in chardef.FILE_KEYS:
            findings.append(Finding(
                INFO, "DEF_UNKNOWN_FILE_KEY",
                "[Files] %s is not a key the engine reads" % key, file=parsed.path))
    return findings


# ---------------------------------------------------------------------------
# Animation coverage
# ---------------------------------------------------------------------------
#
# What the character's *own* scripts ask for must exist. That is the rule below,
# and it is unambiguous: the character cannot work without it.
#
# An earlier version of this file also carried a hard-coded list of "animations a
# character should have", including the animation numbers the engine's common
# states request. It was removed: measured against data/common1.cns.zss, most of
# those requests are guarded by `selfAnimExist(...)` (175, 190, 5030, 5050, 5500)
# or sit in states the engine marks "Deprecated in DosMugen" (110, 115). Reporting
# them would have produced nine warnings per character that no one can act on, and
# a validator that cries wolf gets ignored. Deciding which engine requests are
# unconditional would mean parsing the engine's own ZSS semantics, which is out of
# scope (see docs/character_asset_tooling.md "Known limits").
#
# What replaced it is the rule that actually protects P6: the character's scripts
# are scanned for *literal* animation references and each one must exist.

_ZSS_ANIM_DECL_RE = re.compile(r"\banim\s*:\s*([0-9]+)")
_CHANGE_ANIM_RE = re.compile(
    r"changeanim[0-9]*\s*\{[^}]*?\bvalue\s*:\s*([0-9]+)", re.IGNORECASE)


def scan_zss_animation_references(path):
    """Return [(line_number, action_number)] for *literal* animation references.

    Deliberately narrow: only ``anim: N`` and ``changeAnim{value: N}`` with a
    literal number. Anything computed (``value: $anim``, ``140 + ...``) is
    skipped rather than guessed at -- see docs/character_asset_tooling.md for why
    P5 does not parse ZSS semantics.
    """
    with open(path, "rb") as handle:
        text = handle.read().decode("utf-8-sig", errors="replace")
    references = []
    for index, line in enumerate(text.splitlines(), start=1):
        line = line.split("#", 1)[0]
        if not line:
            continue
        for match in _ZSS_ANIM_DECL_RE.finditer(line):
            references.append((index, int(match.group(1))))
        for match in _CHANGE_ANIM_RE.finditer(line):
            references.append((index, int(match.group(1))))
    return references


def check_zss_animation_references(air, script_paths):
    """Every literal animation the character's scripts use must exist in the AIR."""
    findings = []
    seen = set()
    for path in script_paths:
        if not path or not os.path.exists(path):
            continue
        for line_no, number in scan_zss_animation_references(path):
            if (path, number) in seen:
                continue
            seen.add((path, number))
            if air.action(number) is None:
                findings.append(Finding(
                    ERROR, "ZSS_MISSING_ACTION",
                    "%s asks for animation %d, which the animation table does not define"
                    % (os.path.basename(path), number),
                    file=path, line=line_no, action=number,
                    hint="the engine cannot show this animation; add [Begin Action %d] to the "
                         ".air or fix the reference" % number))
    return findings

