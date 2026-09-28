"""Findings, exit codes and output formatting shared by the P5 tools.

Exit code contract (documented in docs/character_asset_tooling.md):

    0   OK                     nothing above INFO was found
    1   FINDINGS               at least one ERROR (or, for the validators, a WARNING
                               when --strict was passed)
    2   USAGE                  bad command line
    3   IO                     an input file is missing or unreadable
    4   UNSUPPORTED            the input is a format the tool deliberately refuses
    5   CORRUPT                the input is the right format but its data is broken

WARNING-only runs exit 0 on purpose: the tools must be usable in a pipeline where
"unusual but legal" data should not stop the build.
"""

from __future__ import annotations

import json
import sys

ERROR = "ERROR"
WARNING = "WARNING"
INFO = "INFO"

_SEVERITY_ORDER = {ERROR: 0, WARNING: 1, INFO: 2}

EXIT_OK = 0
EXIT_FINDINGS = 1
EXIT_USAGE = 2
EXIT_IO = 3
EXIT_UNSUPPORTED = 4
EXIT_CORRUPT = 5


class Finding:
    """One thing worth telling the user about.

    ``code`` is a stable, machine-friendly identifier (``AIR_MISSING_SPRITE``,
    ``SFF_HEADER_TRUNCATED``, ...) so tests and scripts can match on it instead
    of on prose.
    """

    __slots__ = ("severity", "code", "message", "file", "line", "action",
                 "group", "image", "hint")

    def __init__(self, severity, code, message, file=None, line=None, action=None,
                 group=None, image=None, hint=None):
        self.severity = severity
        self.code = code
        self.message = message
        self.file = file
        self.line = line
        self.action = action
        self.group = group
        self.image = image
        self.hint = hint

    @property
    def location(self):
        bits = []
        if self.file:
            bits.append(self.file)
        if self.line is not None:
            bits.append("line %d" % self.line)
        if self.action is not None:
            bits.append("action %d" % self.action)
        if self.group is not None and self.image is not None:
            bits.append("sprite %d,%d" % (self.group, self.image))
        return " ".join(bits)

    def to_dict(self):
        out = {"severity": self.severity, "code": self.code, "message": self.message}
        if self.file:
            out["file"] = self.file
        if self.line is not None:
            out["line"] = self.line
        if self.action is not None:
            out["action"] = self.action
        if self.group is not None and self.image is not None:
            out["sprite"] = {"group": self.group, "image": self.image}
        if self.hint:
            out["hint"] = self.hint
        return out

    def format(self):
        head = "%-7s %s" % (self.severity, self.code)
        loc = self.location
        text = "  %s  %s" % (head, self.message)
        if loc:
            text += "\n           at %s" % loc
        if self.hint:
            text += "\n           hint: %s" % self.hint
        return text


class Report:
    """Collects findings and decides the process exit code."""

    def __init__(self, title=None):
        self.title = title
        self.findings = []

    def add(self, severity, code, message, **kw):
        finding = Finding(severity, code, message, **kw)
        self.findings.append(finding)
        return finding

    def error(self, code, message, **kw):
        return self.add(ERROR, code, message, **kw)

    def warn(self, code, message, **kw):
        return self.add(WARNING, code, message, **kw)

    def info(self, code, message, **kw):
        return self.add(INFO, code, message, **kw)

    def extend(self, findings):
        self.findings.extend(findings)
        return self

    @property
    def errors(self):
        return [f for f in self.findings if f.severity == ERROR]

    @property
    def warnings(self):
        return [f for f in self.findings if f.severity == WARNING]

    @property
    def infos(self):
        return [f for f in self.findings if f.severity == INFO]

    def summary(self):
        return {"errors": len(self.errors), "warnings": len(self.warnings),
                "infos": len(self.infos)}

    def exit_code(self, strict=False):
        if self.errors:
            return EXIT_FINDINGS
        if strict and self.warnings:
            return EXIT_FINDINGS
        return EXIT_OK

    def sorted_findings(self):
        return sorted(self.findings, key=lambda f: (_SEVERITY_ORDER[f.severity], f.code))


def print_findings(report, stream=None):
    stream = stream or sys.stdout
    if report.title:
        print(report.title, file=stream)
    for finding in report.sorted_findings():
        print(finding.format(), file=stream)
    counts = report.summary()
    print("", file=stream)
    print("errors: %d   warnings: %d   info: %d"
          % (counts["errors"], counts["warnings"], counts["infos"]), file=stream)


def emit_json(payload, stream=None):
    stream = stream or sys.stdout
    json.dump(payload, stream, indent=2, sort_keys=False, ensure_ascii=False)
    stream.write("\n")
