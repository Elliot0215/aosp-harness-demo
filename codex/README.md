# AOSP 整机源码 Codex Harness 可运行 Demo

这是一份 **Codex 原生重写，不是名称替换** 的 AOSP Harness 教学示例。它用 Codex 已文档化的 `AGENTS.md`、skills、project hooks 和 CLI / App 接入入口，演示“上下文 / 流程 / 验证闭环”三层怎样协作。Demo 不启动 Codex，不运行 AOSP 构建，也不访问 ADB 或 CVD。

## 快速开始

从仓库根目录运行主入口：

```bash
./codex/run-demo.sh
```

或先进入 Codex demo 目录：

```bash
cd codex
./run-demo.sh
```

`run-demo.sh` 先运行幂等安装器，再依次演示上下文选择、会话分支漂移、涉及仓分支一致性、流程 skills、严格验证和回归测试。它只调用 wrapper 的 `--dry-run` 模式和确定性 demo 入口。

## Codex 与 Claude Code 版的关键差异

以下 Claude Code 一栏只描述本仓库的 `claude-code/` demo，不把该 demo 的实现细节外推为 Claude Code 的通用产品契约。

| 维度 | Codex 版 | 本仓库 Claude Code demo |
|---|---|---|
| 根 / feature 指引 | 使用根与 feature 的 `AGENTS.md`；Codex 在启动时每次运行建立一次指令链 | 使用根与 feature 的 `CLAUDE.md`，由该 demo 的 wrapper 在启动前同步根软链 |
| 仓库 skills | Codex 仓库 skills 位于 `.agents/skills`；可显式 `$skill-name` 选择，也可在任务匹配 `description` 时隐式选择；没有已文档化的 `paths` 路径触发契约 | 本仓库 Claude demo 使用 `.claude/skills` 与 feature 指令显式路由，不设置 `paths` metadata |
| Hooks | Codex demo 用 `.codex/hooks.json`；Codex 也支持 `.codex/config.toml` 中的 inline `[hooks]` tables，两者使用同一 Codex hook schema：事件 → matcher group → command hook；项目 hook 信任必须通过 `/hooks` 审查 | 本仓库 Claude demo 用 `.claude/settings.json`，命令通过 `${CLAUDE_PROJECT_DIR}` 定位；它不与 Codex 的配置 schema 或信任流程等同 |
| 启动边界 | Wrapper 必须先选定 `AGENTS.md` 再启动新运行；会话中漂移由 hook 阻断并提示重启 | 该 demo 也在启动前同步 `CLAUDE.md`，并把 SessionStart hook 定位为 fallback；这是本仓库的工程选择 |

因此，Codex 版不是把 `CLAUDE.md` 改名为 `AGENTS.md`：指引发现、skill 选择、hook 配置与信任、启动时正确性边界都按 Codex 契约重新落地。

## 目录与三层

```text
codex/
├── CURRENT_FEATURE
├── AGENTS.md -> features/dev-sidebar/AGENTS.md
├── run-demo.sh
├── .codex -> features/.harness/codex
├── .agents/
│   └── skills -> ../features/.harness/skills
├── features/                          # 真实 AOSP 中可独立成 Git 仓
│   ├── install-harness.sh
│   ├── .harness/                      # Codex 自己的通用 Harness
│   │   ├── codex/
│   │   │   ├── bin/{prepare-feature,codex-feature,check-process-layer}
│   │   │   ├── hooks.json
│   │   │   └── hooks/{feature-common,session-lifecycle,session-start,check-branch-drift}.sh
│   │   └── skills/
│   │       ├── build-services-jar/SKILL.md
│   │       └── build-sepolicy/SKILL.md
│   └── dev-sidebar/
│       ├── AGENTS.md
│       ├── repos.tsv
│       ├── check-branch.sh
│       └── verify-sidebar.sh
└── tests/{test-harness,test-install-harness}.sh
```

| 层 | 职责 | Demo 落点 |
|---|---|---|
| ① 上下文层 | 在一次 Codex 运行前选定 feature，并防止会话中分支漂移 | `CURRENT_FEATURE` + 树根 `AGENTS.md` 软链 + wrapper + hooks |
| ② 流程层 | 将构建、部署、安全检查和验证顺序封装为可复用流程 | `.agents/skills/*/SKILL.md` + `check-process-layer` |
| ③ 验证闭环层 | 用脚本产出可审计的 PASS / FAIL / INCOMPLETE 结论 | `features/dev-sidebar/verify-sidebar.sh` |

导航不单独算一层：本方案使用 **`rg` + 源码阅读**，先按仓和路径缩小范围，再搜 JNI 注册名或全限定 `Class::method`。不需要预先建立索引，也不把搜索命中误写成完整引用关系。

## 安装与切换 feature

在 `codex/` 或真实 AOSP 树根运行：

```bash
bash features/install-harness.sh
./.codex/bin/codex-feature --dry-run
./.codex/bin/codex-feature
```

安装器创建两个相对软链，可重复执行；已有普通文件、目录或其他目标的软链会使安装失败，原内容保留。已有 `.agents/` 目录中的其他文件会保留。旧布局迁移时，先备份并将原 `.codex/` 与 `.agents/skills/` 内容合并到 `features/.harness/` 对应目录，再移走旧入口并运行安装器。

新增 feature 时，在 `features/<feature>/` 准备 `AGENTS.md`、`repos.tsv`、分支检查和验证脚本。真实树切换锚点仓及涉及仓分支后，通过 wrapper 启动新会话；Demo 用 `CURRENT_FEATURE` 模拟分支选择。通用 hooks 和 skills 无需随 feature 切换。会话中检测到漂移会阻断继续使用旧上下文。

`.harness/` 是本 Demo 的版本管理布局；Codex 仍通过 `.codex` 和 `.agents/skills` 使用配置与 skills。[官方 skills 文档](https://learn.chatgpt.com/docs/build-skills)说明了 `.agents/skills` 的发现规则及 skill 目录软链支持。脚本从物理位置定位树根，也支持直接调用 `features/.harness/codex/bin/codex-feature`。

## Codex App（GUI）接入

App 与 CLI 共用 `features/.harness/` 中的 skills、检查器和验证脚本。GUI 新建任务不会经过 `codex-feature`，因此必须先准备上下文，再新建任务：

```bash
# 在本示例的 codex/ 目录，或安装了 features/ 的真实 AOSP 树根执行
bash features/install-harness.sh
./.codex/bin/prepare-feature
```

`prepare-feature` 会检测 feature、在真实 `.repo/` 树中检查涉及仓分支，并安全更新根 `AGENTS.md` 软链；不会启动 Codex CLI。旧入口 `codex-feature --dry-run` 保留并调用同一准备步骤。普通 `AGENTS.md` 文件仍受保护，安装器也不会覆盖既有配置。

然后在 App 中添加该目录为项目，以该目录为任务工作目录新建任务。此教学仓库应选择 **`aosp-harness/codex/`**，而不是外层 `aosp-harness/`。真实 AOSP 应选择完整源码树根；单个 Git 仓的 worktree 无法自动复制 `.repo/` 管理的多个仓、独立 features 仓及编译输出。需要并行 feature 时，分别准备完整工作区，避免多个任务竞争同一根 `AGENTS.md` 链接。

Windows App 使用本套 Bash 脚本时，任务执行环境应为能访问源码的 WSL/Linux，且 hooks 与代理命令必须使用同一环境、用户和状态目录。原生 PowerShell 执行环境尚未适配。

### 生命周期与信任

配置入口仍是 `.codex/hooks.json`。`SessionStart`（`startup/resume/clear/compact`）和 `UserPromptSubmit` 统一进入 `session-lifecycle.sh`：

- 检查任务 cwd 是否为源码树根、当前 feature 是否存在、根链接是否已准备好；真实树还会重新检查涉及仓分支。
- 新任务 `startup` 建立初始快照；重复 startup 保留已有快照。
- 恢复、清理或压缩上下文时仅校验原快照，不用当前 feature 覆盖它。快照丢失、损坏或 feature 改变时返回结构化阻断信息。
- 提示执行 `prepare-feature` 后新建 App 任务。切换 feature 后不要恢复旧任务；hook 不会在同一运行中重新加载新的 `AGENTS.md`。

项目及 hook 定义必须受信任；修改 hooks 后需要重新审查。官方文档明确了 CLI 的 `/hooks` 审查入口，但本仓库没有验证当前 App 的信任界面及其与 CLI 的信任记录共享方式。不要将手动执行脚本成功等同于 App 已加载 hooks，也不要通过关闭信任检查来完成接入。参见 [官方 hooks 文档](https://learn.chatgpt.com/docs/hooks)。

### 验证边界与 App 验收

仓库根目录运行 `bash tests/test-codex-app.sh` 可离线验证实际 hooks 配置中的命令，覆盖带空格路径、准备幂等性、保护普通文件、分支异常、恢复旧任务、快照丢失及非法输入。它已接入 `bash scripts/check.sh --offline`，不启动 App、不构建 Android、不访问设备。

实际 App 验收应使用独立 demo 副本，避免影响正在使用的工作区：

1. 执行准备命令，以准备后的目录新建任务，核对 feature 指令和 `$build-services-jar`、`$build-sepolicy` 是否可发现；只核对能力，不运行构建或设备操作。
2. 审查并信任 hooks，发送一个只读请求，确认对应 session 的 `.feature` 快照已生成；默认位于 `${TMPDIR:-/tmp}/aosp-codex-harness-$UID/`。记录 App 版本、执行环境和 hook 运行证据。
3. 恢复任务并发送只读请求，确认同 feature 可以继续；准备另一个有效 feature 后恢复原任务，确认在代理工作前阻断。
4. 在新 feature 下新建任务，确认可以继续；删除测试任务的快照后恢复该任务，确认阻断且不会自动重建基线。

**状态：接入代码与离线测试已提供；App 实际事件投递、信任流程及界面阻断效果仍需上述验收。** 当前任务没有重新创建在 demo 根目录，不能作为完整 App 验收证据。未启用或未加载 hooks 时，只能依靠显式检查流程，不能宣称具备自动漂移拦截。

## ① 上下文层

### Wrapper

```bash
# 只选择 feature、校验分支并同步 AGENTS.md，不启动 Codex
./.codex/bin/codex-feature --dry-run

# 真实工作入口：同步完成后启动 Codex
./.codex/bin/codex-feature
```

Wrapper 的正确性边界很重要：**AGENTS.md 每次运行只加载一次**，所以会话中改软链不等于当前运行已重载指令链。必须先由 wrapper 选定链接，再开始新运行；漂移 hook 的职责是停止继续工作并提示重启，不是在同一运行里热换上下文。

Codex 默认把 Git 根当作 project root；找不到 project root 时只检查当前目录。因此对 **非 Git 的 AOSP 树根**，要从树根开始运行。本 demo 的 wrapper 会 `cd` 到树根，也为 project hook 的相对命令提供稳定起点。

### Hooks 演示与信任

```bash
session_payload='{"session_id":"manual-demo","cwd":".","hook_event_name":"SessionStart"}'
prompt_payload='{"session_id":"manual-demo","cwd":".","hook_event_name":"UserPromptSubmit"}'
printf '%s\n' "$session_payload" | ./.codex/hooks/session-start.sh
printf '%s\n' "$prompt_payload" | ./.codex/hooks/check-branch-drift.sh
```

项目级 hooks 只在 **受信任项目** 中加载。在 CLI 中使用 `/hooks` 查看来源、审查并信任精确的 hook 定义；定义改变后应重新审查。这些 hook 的相对命令依赖 wrapper 固定的工作目录。本方案不假设 hook 一定先于 `AGENTS.md` 发现执行。

`repos.tsv` 是 feature 涉及仓的单一事实源：

```bash
./features/dev-sidebar/check-branch.sh --demo
```

`--demo` 故意返回一个分支漂移失败，便于检查调用方是否正确处理非零退出。

## ② 流程层

```bash
./.codex/bin/check-process-layer
```

Skills 位于 `.agents/skills`。Codex 对 skills 使用 **渐进式披露**：初始上下文只放名称、`description` 和文件路径，选中后再读取完整 `SKILL.md`。

- 显式选择：在提示中写 `$build-services-jar` 或通过 `/skills` 选择。
- 隐式选择：任务与 skill 的 `description` 匹配时，Codex 可选择它。
- 当前公开契约中 **没有已文档化的 `paths` 路径触发契约**；不要把“修改某路径”宣称为必然选中某个 skill。这个 demo 由 feature `AGENTS.md` 显式路由必须使用的 skill。

## ③ 验证闭环层

```bash
# 离线确定性验证
./features/dev-sidebar/verify-sidebar.sh --demo

# 只有探索阶段才显式容忍 SKIP
./features/dev-sidebar/verify-sidebar.sh --demo --allow-skip
```

最终状态语义是：

- `RESULT PASS`：所有严格断言通过，退出 0。
- `RESULT FAIL`：至少一项失败，非零退出。
- `RESULT INCOMPLETE`：无 FAIL 但存在 SKIP，默认仍非零退出。
- `--demo --allow-skip` **仅用于探索**；有跳过仍输出 `RESULT INCOMPLETE`，即使退出 0 也不得作为验收通过。

## 适配到真实 AOSP

1. 把完整 `features/`（含隐藏的 `.harness/`）建成 **manifest 之外的独立 Git 仓**，统一管理通用 Harness、feature 上下文、涉及仓清单和验证脚本，不污染 AOSP manifest、Gerrit 或 Soong 输入。
2. 在 AOSP 树根运行 `bash features/install-harness.sh`，通过 `.codex/` 与 `.agents/` 下的标准入口暴露 Harness；随后由 wrapper 选择树根 `AGENTS.md` 软链，CLI 日常工作经过 wrapper；App 按上面的准备后新建任务流程接入。
3. 保留 `repos.tsv` 和涉及仓 checker，在开始任务前 fail closed 检查缺仓、分支漂移、detached HEAD 和非法仓库。
4. 真实设备操作前必须显式固定 `ANDROID_SERIAL`，先校验 `adb -s "$ANDROID_SERIAL" get-state`；操作 Cuttlefish 前先用 `cvd fleet` 确认目标，再固定 `CVD_GROUP`，禁止对未选定组执行 stop/start。
5. 把 `verify-sidebar.sh` 的 demo 数据源换成真实设备查询，保留查询失败即 FAIL、crash 时间基线、严格 SKIP 和整个 feature 只有严格 `RESULT PASS` 且退出 0 才能交付的语义。

## 继续阅读

- 操作指南：[从搭建 Harness 到 Codex App 开发](../docs/AOSP-Codex-App使用指南.md)

- 长文：[AOSP 整机源码 Codex Harness 工程探索](../docs/AOSP整机源码Harness工程探索-codex版.md)
- [`AGENTS.md` 自定义指令](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [Build skills](https://learn.chatgpt.com/docs/build-skills)
- [Hooks](https://learn.chatgpt.com/docs/hooks)
- [Advanced configuration](https://learn.chatgpt.com/docs/config-file/config-advanced)
- [Subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)
- [Developer commands](https://learn.chatgpt.com/docs/developer-commands)

## 与 intent 协作

当前 feature 指令中包含完整协作规则。新规划默认放在 `features/dev-sidebar/.intent/`（`roadmap.md`、固定编号的需求 Markdown、实际审查的逐轮 `review/` 记录）；用户指定和已有文档位置优先，原位续用。主 agent 可更新这些规划资料，业务源码仍受 `repos.tsv` 限定。修改源码前读取实际流程 skill，并按 hook 覆盖范围重新检查分支；不自动切换 feature 或分支。

小需求满足事先明确的自身验收与必要回归即可交付；独立审查仅在用户要求或项目规则要求时成为完成条件。整个 feature 须全部需求和 `verify-sidebar.sh` 严格通过：最终 `RESULT PASS` 且退出 0。`RESULT INCOMPLETE` 在探索模式返回 0 仍是未完成；规划、Harness 离线检查、编译和设备验收分别报告。读取 skill 不代表运行其中所有命令，设备操作遵循已有授权；同一 out/、设备或 CVD 组串行使用。

先独立安装 intent 并确认当前客户端可见，再显式调用 `$intent-roadmap 为 dev-sidebar 规划路线图`、`$intent-plan features/dev-sidebar/.intent/001-需求名称.md` 或 `$intent-implement features/dev-sidebar/.intent/001-需求名称.md`；需要审查时调用 `$intent-review`。技能不会自动进入下一阶段。已有需求也可交给 build-aosp-harness 引用后接入。详见 [完整协作方法](../skills/build-aosp-harness/references/intent-cooperation.md)。
