# Phase Reports

A Phase Report is the **complete, self-contained account of one phase of the project**.

It answers: *what was this phase for, what came out of it, what actually happened, and what is
left behind?* It is written once, when the phase reaches its exit gate, and then it is left alone.

## Phase Report vs Iteration Record

They are not the same thing and both are required.

| | Iteration Record (`docs/iterations/`) | Phase Report (`docs/phase_reports/`) |
| --- | --- | --- |
| Scope | one PR / one piece of work | one whole phase (P0…P12) |
| Written | per PR, as the work happens | once, at the end of the phase |
| Answers | "what did this PR change and how was it verified?" | "what is the state of this phase?" |
| Audience | whoever reviews the PR | whoever starts the next phase, or picks the project up cold |
| Lifecycle | append/update as the work continues | final once the phase is closed |

A phase usually produces several Iteration Records and exactly one Phase Report.

## Naming

```text
P<phase>-<short-topic>.md
```

Examples: `P0-repository-and-environment.md`, `P1-ikemen-character-architecture.md`.

## Required content

1. **结论** — the phase status and what it actually unblocked
2. **Exit gate 结果** — every gate with PASS / FAIL / BLOCKED and the evidence for it
3. **交付物清单** — documents, scripts, tests, directories produced
4. **环境基线** — the versions and machine facts the phase was verified against
5. **构建 / 运行 / 测试 结果** — the real commands and the real output
6. **关键决策** — decisions taken, and why
7. **遇到的问题与解决过程** — including hypotheses that were tested and ruled out
8. **已知限制与遗留事项** — what is carried forward, and its impact
9. **对下一阶段的输入** — what the next phase can assume

Rules:

- Report numbers as measured. Never round a failure into a pass.
- Every claim should point at something in the repository (a file, a log, a command output).
- Unfinished work is written as `BLOCKED`, never as `PASS`.
- Carry-over items must state their impact, not just exist as a list.
