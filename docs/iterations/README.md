# Iteration Records

This directory is KingOfFate's **engineering log**.

- `docs/development_status.md` answers *where the project is now*.
- `docs/iterations/` answers *how the project became what it is*.

Both are kept. Neither replaces the other.

---

## Purpose

Every development iteration must be recorded here. An "iteration" is any of:

```text
a feature
a bug fix
a tool change
a batch of character animations
an engine change
a substantial configuration change
a standalone PR
```

Rule of thumb: **one PR corresponds to at least one iteration record.** If a PR clearly bundles several
independent tasks, it may contain several records. The record is a required engineering artifact, not optional
documentation, and it ships in the same branch and PR as the code it describes.

---

## File naming

```text
YYYYMMDD-<topic>.md
```

Examples:

```text
docs/iterations/
├── 20260911-repository-bootstrap.md
├── 20260911-p0-bootstrap.md
├── 20260913-kfm-study.md
├── 20260915-base-fighter-template.md
└── 20260918-fighter-a-normal-attacks.md
```

If the same topic is iterated on more than once in a single day, suffix the copies:

```text
20260918-fighter-a-normal-attacks-01.md
20260918-fighter-a-normal-attacks-02.md
```

---

## Rules

1. This directory is the engineering log of KingOfFate — keep it complete.
2. Every functional PR must add at least one record.
3. Old records are never deleted and never rewritten.
4. A new record only ever describes what was actually implemented and verified in the current version.
5. Never write `PASS` for something unfinished. Write `BLOCKED` and the exact reason.
6. A record must let a future reader understand **why** something changed, **what** changed, and **how it was
   verified** — "modified some character logic" is not acceptable.

---

## Fixed template

```markdown
# Iteration: <title>

## 基本信息

- 日期：
- Phase：
- Branch：
- PR：
- 状态：

## 本次目标

...

## 修改内容

...

## 主要修改文件

...

## 技术实现

...

## 测试

...

## 已知问题

...

## 后续工作

...
```
