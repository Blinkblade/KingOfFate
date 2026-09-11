# Iteration: Repository Bootstrap

## 基本信息

- 日期：2026-09-11
- Phase：P0 — Repository & Environment
- Branch：`main`
- PR：无（初始工程搭建阶段，直接提交到 `main`）
- 状态：DONE

## 本次目标

为 KingOfFate 建立长期可用的仓库基础：主仓、引擎 Fork、固定的引擎基线，以及把引擎以 Git Submodule
的形式挂进主仓。

这是一次**补写记录**。本文件记录的是仓库初始化阶段已经真实完成的工作，用于补全 `docs/iterations/`
体系。此处不记录任何未实际发生的内容。

## 修改内容

1. 建立 KingOfFate 主仓并完成首次提交。
2. Fork IKEMEN GO 到 `Blinkblade/Ikemen-GO`。
3. 在引擎 Fork 中配置 `origin`（自己的 Fork）与 `upstream`（官方仓库）。
4. 固定引擎基线到官方 release candidate `v1.0.0-rc.5`。
5. 从 `v1.0.0-rc.5` 建立 KingOfFate 专用集成分支 `kingoffate/rc5`。
6. 在主仓中以 Git Submodule 形式引入引擎，路径 `engine/ikemen-go`。
7. 提交 Submodule baseline 指针，并推送 `main` 到远程。

## 主要修改文件

- `README.md`
- `.gitignore`
- `.gitmodules`
- `engine/ikemen-go`（子模块指针）

## 技术实现

### 仓库关系

```text
Blinkblade/KingOfFate        （主仓，本项目全部开发发生在这里）
    │
    └── engine/ikemen-go     （Git Submodule）
            │
            └── Blinkblade/Ikemen-GO
                    ├── origin   = Blinkblade/Ikemen-GO
                    ├── upstream = ikemen-engine/Ikemen-GO
                    └── branch   = kingoffate/rc5
```

主仓只记录引擎所使用的具体 commit，不复制引擎的 Git 历史。

### 引擎基线

```text
Tag:    v1.0.0-rc.5
Commit: ba516193bba83f13f0b63ddce314d8719793931f
Date:   2026-09-05
Msg:    fix: encode AI sync-test inputs correctly
```

`kingoffate/rc5` 从该 tag 建立，后续所有 KingOfFate 引擎级修改都以它为基线。

### Submodule 配置

`.gitmodules`：

```ini
[submodule "engine/ikemen-go"]
	path = engine/ikemen-go
	url = https://github.com/Blinkblade/Ikemen-GO.git
	branch = kingoffate/rc5
```

设计决策：引擎以 Submodule 而非 vendored 源码的形式引入，使"主仓记录版本、Fork 承载引擎历史"这一职责
边界可以被 `git submodule status` 直接验证，避免主仓被引擎历史污染。

### 提交

```text
d5dec1f  Initial commit
ccd5fb9  chore: add IKEMEN GO engine baseline
```

## 测试

执行：

```text
git submodule status
git log -1 --format="%H %d"（在 engine/ikemen-go 内）
git remote -v（在 engine/ikemen-go 与 D:\AI\develop\Ikemen-GO 内）
```

结果：

- PASS — 子模块指针指向 `ba516193bba83f13f0b63ddce314d8719793931f`
- PASS — 子模块处于 `kingoffate/rc5` 分支，工作区 clean
- PASS — 引擎 Fork 的 `origin` / `upstream` 指向正确
- PASS — `git describe --tags` 在基线 commit 上解析为 `v1.0.0-rc.5`

## 已知问题

- 主仓 `.gitignore` 当时仍是通用的 Python 模板，尚未加入本项目需要的 `logs/`、`dist/` 与实际构建产物
  规则。该问题在 `20260911-p0-bootstrap.md` 中处理。
- 此时尚无任何构建脚本、测试、环境记录或目录结构，P0 的 Build / Runtime Gate 尚未验证。

## 后续工作

- 建立项目目录结构与开发文档体系。
- 配置并验证 Windows 构建环境，实际完成引擎 Build 与 Runtime 验证。
- 建立 `build_engine.ps1` / `run_game.ps1` / `test.ps1`。
- 以上工作记录于 `docs/iterations/20260911-p0-bootstrap.md`。
