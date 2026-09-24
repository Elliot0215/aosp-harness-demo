---
title: AOSP Harness 使用指南（ZCode）
tags: [zcode, android, aosp, harness, 使用指南]
source: zcode
---

# AOSP Harness 使用指南：从搭建到在 ZCode 中使用

> 本文记录从零搭建一套 aosp-harness（用 `build-aosp-harness` skill）到在 ZCode App 中日常使用的完整操作流程。设计思路见[长文](AOSP整机源码Harness工程探索-zcode版.md)，适配器细节见 [zcode/README](../zcode/README.md)。ZCode 没有官方 CLI，本文全程只使用 App；所有离线步骤不需要 AOSP 源码、Android 设备或客户端认证。

## 全景

Harness 管三层，核心边界一句话：**ZCode 每个会话只加载一次 `AGENTS.md`**，必须先准备上下文再开会话；会话中的 hook 只拦截漂移，不能热换上下文。

| 层 | 职责 | 落点 |
| --- | --- | --- |
| ① 上下文 | 会话开始前选对 feature，会话中漂移就停 | 根 `AGENTS.md` 软链 + `prepare-feature` + hooks |
| ② 流程 | 构建、部署按既定流程走 | `.zcode/skills` 流程 skill |
| ③ 验证 | 只有 `RESULT PASS` 才算完成 | `features/<feature>/verify-*.sh` |

分工总结：**skill 负责"从需求生成 Harness"的一次性工作；`prepare-feature` + App 新建会话是日常入口；hooks 和验证闭环负责过程纪律。**

## 阶段零：准备（一次性）

1. **安装 skill**：把仓库的 `skills/build-aosp-harness/` 复制（或软链）到 ZCode 的用户级 skill 目录 `~/.zcode/skills/` 或 `~/.agents/skills/`；也可放进目标树的 `.zcode/skills/`（工作区级）。注意 user scope 同名 skill 优先于工作区版本，双份时以家目录为准。
2. **（可选）离线演练**：在教学仓库根目录跑 `bash zcode/run-demo.sh`，完整走一遍安装、上下文选择、漂移阻断、流程检查、严格验证和回归测试，不需要任何真实环境。

## 阶段一：用 `build-aosp-harness` 搭建

在 ZCode App 里以目标 AOSP 树根（或其上层目录）为工作区新建会话，提出需求：

```text
使用 build-aosp-harness，为 /path/to/aosp 中的 dev-example 功能搭建 ZCode Harness。
需求：给现有系统服务增加一个可关闭的调试入口，仅 userdebug 可用。
本次搭建 Harness 和离线验证，使用项目已有构建流程。
```

skill 按[六步工作流](../skills/build-aosp-harness/SKILL.md)推进，每步有可检查的产物：

| 步骤 | 做什么 | 落地产物 |
| --- | --- | --- |
| 1 确定契约 | 读目标树已有指引与各仓 `.git`，形成需求/环境/feature/构建/验证/范围记录 | 契约记录（并入 feature 上下文） |
| 2 推导影响面 | `rg` + 源码阅读梳理"用户行为 → 服务 → 依赖 → 验收" | `features/<feature>/repos.tsv`、验收断言 |
| 3 上下文层 | 按适配参考取仓库 `zcode/` 示例作底稿改写 | `features/` 独立 Git 仓 + `.harness/zcode/` + `install-harness.sh` + `features/<feature>/AGENTS.md` |
| 4 流程层 | 只写需求会用到的流程 skill，feature 指令写清路由 | `.zcode/skills/*/SKILL.md` + `check-process-layer` |
| 5 验证闭环 | 断言变成可审计脚本，区分 FAIL / INCOMPLETE | `verify-<feature>.sh` |
| 6 交付 | 分级报告 | 文件清单、离线验证结果、真机缺项 |

skill 会遵守写死在 [适配参考](../skills/build-aosp-harness/references/adapt-examples.md)里的 ZCode 硬约定：

- hooks 配置在 `.zcode/config.json` 的 `hooks.events`，必须显式 `"hooks": {"enabled": true}`（配置文件 hooks 默认禁用）；
- 命令 hook 用**退出码表达结论**：0 通过、2 阻断；stdout 保持为空（非空会被当严格 JSON 解析），阻断原因写 stderr；
- **无 CLI**：唯一入口 `prepare-feature`，之后在 App 新建会话；
- 物理源目录叫 `features/.harness/zcode`，不是 `features/.zcode`（避免嵌套扫描）。

搭建完成的判据是 skill 自己跑的离线验证（安装冲突、漂移、流程工件、验证协议）全部 `RESULT PASS`。

## 阶段二：在 ZCode App 中日常使用

### 每次任务开始

先在终端、树根下跑准备入口（不在 ZCode 会话里跑）：

```bash
./.zcode/bin/prepare-feature
```

它检测 feature（锚点仓 `frameworks/base` 等的分支优先，回退 `CURRENT_FEATURE`）、对存在 `.repo/` 的树 fail-closed 校验涉及仓分支（缺仓/DRIFT/DETACHED/INVALID 任一即止，不动旧链接）、原子切换根 `AGENTS.md`。幂等，可重复运行；不启动任何客户端。

然后在 ZCode App 里以**准备后的树根**为工作区打开项目，**新建**会话（永远新建，不恢复旧的）。会话起来后 hooks 自动生效：

- `SessionStart`（startup）：校验 cwd 是树根、`AGENTS.md` 已按当前 feature 准备好，记录本会话快照（`${TMPDIR:-/tmp}/aosp-zcode-harness-$UID/`）；resume/clear/compact 只校验原快照、从不改写。
- `UserPromptSubmit`：每次提交提示前重查一致性，漂移、快照损坏或未准备就以 exit 2 阻断，提示重新准备并新建会话。

### 会话内的工作纪律

ZCode 读根 `AGENTS.md` 获得全部约束，按三条纪律工作：

1. **改代码前**：按 feature 指令的路由，改 `frameworks/base/services/**` 前必须用 `/build-services-jar` skill，改 `system/sepolicy/**` 前必须用 `/build-sepolicy`；skill 内是完整流程——bash 内 `source build/envsetup.sh` + lunch、后台构建写唯一 `mktemp` 日志、轮询、`wait`、确认 `#### build completed successfully` 和产物存在。
2. **碰设备前**：显式确认后固定 `ANDROID_SERIAL`（每条 adb 都 `adb -s`）；Cuttlefish 先 `cvd fleet` 再固定 `CVD_GROUP`，禁止对未选定组 stop/start。
3. **收工前**：必须跑 `./features/<feature>/verify-<feature>.sh`，只有最终行 `RESULT PASS` 且退出码 0 才是完成证据；`RESULT INCOMPLETE`/`RESULT FAIL` 都不行，`--allow-skip` 只用于探索阶段。

### 漂移与切换 feature

会话中锚点仓分支变了，下一次提交提示就被 hook 拦下。正确动作：终端切好新分支 → 重新 `./.zcode/bin/prepare-feature` → App **新建**会话。旧会话的快照不会被覆盖，恢复旧会话会被校验拦住。

## 阶段三：验收与维护

离线测试证明的是脚本行为；真实 App 会话的事件投递要在目标机上按 [zcode/README](../zcode/README.md) 的四步验收一次：

1. 准备后新建会话，核对 feature 指令和 `/build-services-jar`、`/build-sepolicy` 是否可发现（只核对能力，不跑构建）；
2. 发一个只读请求，确认对应会话的 `.feature` 快照已生成，并在 ZCode 日志核对 hook 执行记录；
3. 恢复会话验证同 feature 可继续；准备另一个 feature 后恢复原会话，确认被阻断；
4. 删除测试会话的快照后恢复，确认阻断且不自动重建基线。

已知限制：`.zcode` 整目录被软链接管后，App 的 plans 文件会落到 `features/.harness/zcode/plans/`（无碰撞，属 features 仓未跟踪内容）；user scope 同名 skill 会遮蔽树内版本；与 Codex 共存时 `.agents/skills` 有双注册风险。

日常维护：新增 feature 就在 `features/<feature>/` 准备四件套（`AGENTS.md`、`repos.tsv`、`check-branch.sh`、`verify-*.sh`）；改验收条件就同步改 verifier；需要新流程时再次调用 `build-aosp-harness` 扩展。

## 命令速查

```bash
bash zcode/run-demo.sh                    # 教学仓库离线演练
bash features/install-harness.sh          # 安装 .zcode 入口（一次性，幂等）
./.zcode/bin/prepare-feature              # 每次任务前：准备上下文，不启动客户端
./.zcode/bin/check-process-layer          # 静态检查流程 skill 工件
./features/<feature>/check-branch.sh      # 手动复查涉及仓分支（--demo 为确定性失败样本）
./features/<feature>/verify-<feature>.sh  # 收工验证；--demo 离线，--allow-skip 仅探索
bash tests/test-zcode-app.sh              # 仓库级离线回归（Desktop 边界契约）
bash scripts/check.sh --offline           # 全量离线门禁
```
