# AOSP 整机源码 Cursor Agent Harness 可运行 Demo

这是一份 **Cursor Agent 原生适配，不是把 Codex/Claude 配置改名** 的 AOSP Harness 教学示例。它用 Cursor 已文档化的 `AGENTS.md`、`.cursor/skills`、`.cursor/hooks.json` 和 `cursor-agent` CLI，演示“上下文 / 流程 / 验证闭环”三层怎样协作。Demo 不启动真实 Cursor Agent，不运行 AOSP 构建，也不访问 ADB 或 CVD。

## 快速开始

从仓库根目录运行主入口：

```bash
./cursor-agent/run-demo.sh
```

或先进入 Cursor Agent demo 目录：

```bash
cd cursor-agent
./run-demo.sh
```

`run-demo.sh` 先运行幂等安装器，再依次演示上下文选择、会话分支漂移、涉及仓分支一致性、流程 skills、严格验证和回归测试。它只调用 wrapper 的 `--dry-run` 模式和确定性 demo 入口。

## 本机 CLI 核对（2026.09.15）

在适配机上确认：

- 二进制是 `cursor-agent`（本机版本 `2026.09.15-d2fe57e`）。`cursor-agent --help` 写的是 `Usage: agent`，但安装入口仍是 `cursor-agent`。
- PATH 上的 `agent` **不一定是 Cursor**。本机 `agent` 是 Grok CLI；wrapper 只在 `cursor-agent` 不存在且 `agent --help` 含 `Start the Cursor Agent` 时才回退到 `agent`。
- `--workspace` 可用，用于把非 Git 的 AOSP 树根钉成工作区。
- `--worktree` / `-w` 会按 Git 仓复制 checkout。wrapper **拒绝** 该参数，也不给整机树加 worktree。
- `--trust` 只适合 headless；日常入口不自动信任项目 hook。
- 项目 hooks 位于 `.cursor/hooks.json`。官方文档覆盖 IDE / Cloud 的事件面；**本 Demo 没有用真实 `cursor-agent` 跑通 hook 触发列表**。`sessionStart`、`beforeSubmitPrompt`、`preToolUse` 的脚本协议有离线 stdin 测试。CLI 是否实际派发这些事件记为兼容性缺项，不能把离线 JSON 当成“已拦截”。

## Cursor 与 Codex / Claude Code 版的关键差异

以下对照只描述本仓库示例，不把某一 demo 的实现细节外推为产品通用契约。

| 维度 | Cursor Agent 版 | Codex 版 | 本仓库 Claude Code demo |
|---|---|---|---|
| 根 / feature 指引 | 树根 `AGENTS.md` 软链；CLI 还会读 `CLAUDE.md` 和 `.cursor/rules`，本 demo 不用后两者当 feature 入口 | 根与 feature 的 `AGENTS.md` | 根与 feature 的 `CLAUDE.md` |
| 仓库 skills | `.cursor/skills`（经 `.cursor` 软链暴露）；可用 `/skill-name` 显式选择，也可按 `description` 隐式选择；可选 `paths`，本 demo **不使用** `paths` | `.agents/skills`；`$skill-name` 与 description | `.claude/skills` 与 feature 指令显式路由；不设置 `paths` metadata |
| Hooks | `.cursor/hooks.json`，schema `version: 1`；`sessionStart` 不能阻断启动；`beforeSubmitPrompt` 返回 `continue: false`；`preToolUse` 返回 `permission: deny` | `.codex/hooks.json` 的 Codex hook schema | `.claude/settings.json` |
| 启动边界 | Wrapper 必须先选定 `AGENTS.md` 再 `cursor-agent --workspace <树根>` | Wrapper `cd` 后 `exec codex` | Wrapper 同步 `CLAUDE.md` 后 `exec claude` |
| 嵌套发现 | 仓库内任意 `.cursor/skills/` 会被扫到，且嵌套 skill 会限定到该子树；物理源因此命名为 `features/.harness/cursor`，避免双注册和错误 scope | 无此 Cursor 发现规则 | 物理源命名 `.harness` 避免与 `.claude` 双注册 |

因此，Cursor 版不是把 `.codex` 改名为 `.cursor`：指引发现、skill 路径、hook schema、CLI 二进制解析和 `--workspace` 都按 Cursor 契约重新落地。

## 目录与三层

```text
cursor-agent/
├── CURRENT_FEATURE
├── AGENTS.md -> features/dev-sidebar/AGENTS.md
├── run-demo.sh
├── .cursor -> features/.harness/cursor
├── features/                          # 真实 AOSP 中可独立成 Git 仓
│   ├── install-harness.sh
│   ├── .harness/cursor/               # Cursor 自己的通用 Harness；不要叫 .cursor
│   │   ├── bin/{prepare-feature,cursor-feature,check-process-layer}
│   │   ├── hooks.json
│   │   ├── hooks/{feature-common,session-start,check-branch-drift}.sh
│   │   └── skills/{build-services-jar,build-sepolicy}/SKILL.md
│   └── dev-sidebar/
│       ├── AGENTS.md
│       ├── repos.tsv
│       ├── check-branch.sh
│       └── verify-sidebar.sh
└── tests/{test-harness,test-install-harness}.sh
```

| 层 | 职责 | Demo 落点 |
|---|---|---|
| ① 上下文层 | 在一次 Cursor 会话前选定 feature，并防止会话中分支漂移 | `CURRENT_FEATURE` + 树根 `AGENTS.md` 软链 + `prepare-feature` + hooks |
| ② 流程层 | 将构建、部署、安全检查和验证顺序封装为可复用流程 | `.cursor/skills/*/SKILL.md` + `check-process-layer` |
| ③ 验证闭环层 | 用脚本产出可审计的 PASS / FAIL / INCOMPLETE 结论 | `features/dev-sidebar/verify-sidebar.sh` |

导航不单独算一层：本方案使用 **`rg` + 源码阅读**，先按仓和路径缩小范围，再搜 JNI 注册名或全限定 `Class::method`。不需要预先建立索引，也不把搜索命中误写成完整引用关系。

## 安装与切换 feature

在 `cursor-agent/` 或真实 AOSP 树根运行：

```bash
bash features/install-harness.sh
./.cursor/bin/prepare-feature
./.cursor/bin/cursor-feature --dry-run
./.cursor/bin/cursor-feature
```

安装器创建相对软链 `.cursor -> features/.harness/cursor`，可重复执行；已有普通文件、目录或其他目标的软链会使安装失败，原内容保留。`prepare-feature` 只检测 feature、校验涉及仓并更新根 `AGENTS.md`，不启动客户端。CLI 的 `cursor-feature` 先调用它，再启动 `cursor-agent`。`--dry-run` 停在同一步准备。会话中检测到漂移会阻断继续使用旧上下文。

## Cursor 桌面 IDE（App）接入

桌面 IDE 的 Agent Chat 会读取项目根 `AGENTS.md`、`.cursor/skills` 和已信任工作区里的 `.cursor/hooks.json`。它不会经过 `cursor-feature`，也没有 `--workspace`。必须先准备上下文，再新建对话：

```bash
bash features/install-harness.sh
./.cursor/bin/prepare-feature
```

然后用桌面 IDE 打开该目录并新建 Agent 对话。教学仓库应选择 **`aosp-harness/cursor-agent/`**，不要打开外层 `aosp-harness/`。真实 AOSP 应选择完整源码树根。需要并行 feature 时分别准备完整工作区，避免多个对话竞争同一根 `AGENTS.md` 链接。

- 项目 hooks 只有在信任工作区之后才会加载。日常入口不要自动加 `--trust`。
- `sessionStart` 只在快照不存在时建立基线，重复触发不会改写已有快照，也不能阻断会话创建。
- 切换 feature 后不要恢复旧对话。先重新运行 `prepare-feature`，再新建 Agent 对话。CLI 仍用 `./.cursor/bin/cursor-feature`。
- 漂移时 `beforeSubmitPrompt` 返回 `continue: false`，`preToolUse` 返回 `permission: deny`。提示提交只比较 feature token，不重跑 `repos.tsv`。

仓库根目录运行 `bash tests/test-cursor-app.sh` 可离线验证准备命令不会启动客户端，以及快照、恢复和阻断协议。它不打开桌面 IDE，也不构建 Android。

**状态：接入代码与离线测试已提供；真实 IDE 的事件投递、信任工作区后的阻断效果和 skills 发现仍需在新对话里验收。** 离线 JSON 不等于客户端已加载 hooks。Hooks 未信任或未加载时，只能手动运行 `./features/dev-sidebar/check-branch.sh`，不能宣称具备自动漂移拦截。Cloud Agent 不跑 `sessionStart`，不能靠这份基线。

`.harness/cursor` 是版本管理布局；Cursor 仍通过树根 `.cursor` 发现 hooks 与 skills。不要在 `features/` 下再放一个名为 `.cursor` 的目录，否则嵌套 skill 可能被限定到 `features/` 子树，改 `frameworks/base` 时看不到。

同树若已安装 Codex 的 `.agents/skills`，Cursor 也会扫描它，可能与 `.cursor/skills` 双注册。两套适配器分入口检查，不要把 Codex 技能目录当作 Cursor 的正式入口。

## ① 上下文层

### Wrapper

```bash
# 桌面 IDE：只准备上下文，不启动客户端
./.cursor/bin/prepare-feature

# CLI 干跑与 prepare-feature 同一准备步骤
./.cursor/bin/cursor-feature --dry-run

# CLI 工作入口：准备完成后启动 cursor-agent --workspace <树根>
./.cursor/bin/cursor-feature
```

Wrapper 的正确性边界很重要：**根 `AGENTS.md` 在一次运行开始时加载**，会话中改软链不等于当前运行已重载指令。必须先由 `prepare-feature` 选定链接，再开始新的 IDE 对话或 CLI 运行；漂移 hook 的职责是停止继续工作并提示重新准备，不是在同一运行里热换上下文。`sessionStart` 是 fire-and-forget，不能阻断启动。

AOSP 树根常常不是 Git 仓。Cursor CLI 默认使用当前工作目录，也可用 `--workspace`。本 demo 的 wrapper 会 `cd` 到树根，并在调用方未指定时传入 `--workspace`。不要从某个 Git project 子目录直接启动并指望树根 Harness 生效。

### Hooks 演示

```bash
session_payload='{"session_id":"manual-demo","cwd":".","hook_event_name":"sessionStart"}'
prompt_payload='{"session_id":"manual-demo","cwd":".","hook_event_name":"beforeSubmitPrompt"}'
printf '%s\n' "$session_payload" | ./.cursor/hooks/session-start.sh
printf '%s\n' "$prompt_payload" | ./.cursor/hooks/check-branch-drift.sh
```

这是手工测试脚本的示意，不验证客户端事件是否触发。`beforeSubmitPrompt` 漂移时返回 `"continue": false`；`preToolUse` 漂移时返回 `"permission": "deny"`。CLI 是否实际派发这些事件记为兼容性缺项。桌面 IDE 的事件投递同样不能用这段手工 JSON 代替。

`repos.tsv` 是 feature 涉及仓的单一事实源：

```bash
./features/dev-sidebar/check-branch.sh --demo
```

`--demo` 故意返回一个分支漂移失败，便于检查调用方是否正确处理非零退出。

## ② 流程层

```bash
./.cursor/bin/check-process-layer
```

Skills 位于 `.cursor/skills`。Cursor 对 skills 使用渐进式披露：初始上下文放名称、`description` 和路径，选中后再读取完整 `SKILL.md`。

- 显式选择：在提示中写 `/build-services-jar` 或通过 `/` 菜单选择。
- 隐式选择：任务与 skill 的 `description` 匹配时，Cursor 可选择它。
- 本 demo **没有** 使用 `paths` 字段；不要把“修改某路径”宣称为必然选中某个 skill。feature `AGENTS.md` 显式路由必须使用的 skill。

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
2. 在 AOSP 树根运行 `bash features/install-harness.sh`，通过 `.cursor/` 暴露 Harness；随后运行 `./.cursor/bin/prepare-feature` 选择树根 `AGENTS.md` 软链。桌面 IDE 以该树根新建 Agent 对话；CLI 再用 `cursor-feature` 启动。
3. 审计各 Git project 已有的嵌套 `AGENTS.md`：Cursor 会把它们与根文件合并，更具体的子目录指令优先。
4. 保留 `repos.tsv` 和涉及仓 checker，在开始任务前 fail closed 检查缺仓、分支漂移、detached HEAD 和非法仓库。
5. 真实设备操作前必须显式固定 `ANDROID_SERIAL`，先校验 `adb -s "$ANDROID_SERIAL" get-state`；操作 Cuttlefish 前先用 `cvd fleet` 确认目标，再固定 `CVD_GROUP`。
6. Cursor 只读审查可能写入私有 chats/sandbox 状态目录；把这些目录放到可写隔离位置，不要靠放宽 AOSP 源码写权限绕过。
7. 把 `verify-sidebar.sh` 的 demo 数据源换成真实设备查询，保留查询失败即 FAIL、crash 时间基线、严格 SKIP 和整个 feature 只有严格 `RESULT PASS` 且退出 0 才能交付的语义。

## 继续阅读

- 长文：[AOSP 整机源码 Cursor Agent Harness 工程探索](../docs/AOSP整机源码Harness工程探索-cursor-agent版.md)
- [Using Agent in CLI](https://cursor.com/docs/cli/using)
- [CLI parameters](https://cursor.com/docs/cli/reference/parameters)
- [Agent Skills](https://cursor.com/docs/context/skills)
- [Rules / AGENTS.md](https://cursor.com/docs/context/rules)
- [Hooks](https://cursor.com/docs/hooks)

## 与 intent 协作

当前 feature 指令中包含完整协作规则。新规划默认放在 `features/dev-sidebar/.intent/`（`roadmap.md`、固定编号的需求 Markdown、实际审查的逐轮 `review/` 记录）；用户指定和已有文档位置优先，原位续用。主 agent 可更新这些规划资料，业务源码仍受 `repos.tsv` 限定。修改源码前读取实际流程 skill，并按 hook 覆盖范围重新检查分支；不自动切换 feature 或分支。

小需求满足事先明确的自身验收与必要回归即可交付；独立审查仅在用户要求或项目规则要求时成为完成条件。整个 feature 须全部需求和 `verify-sidebar.sh` 严格通过：最终 `RESULT PASS` 且退出 0。`RESULT INCOMPLETE` 在探索模式返回 0 仍是未完成；规划、Harness 离线检查、编译和设备验收分别报告。读取 skill 不代表运行其中所有命令，设备操作遵循已有授权；同一 out/、设备或 CVD 组串行使用。

先独立安装 intent 并确认当前客户端可见，再显式调用 `/intent-roadmap 为 dev-sidebar 规划路线图`、`/intent-plan features/dev-sidebar/.intent/001-需求名称.md` 或 `/intent-implement features/dev-sidebar/.intent/001-需求名称.md`；需要审查时调用 `/intent-review`。技能不会自动进入下一阶段。已有需求也可交给 build-aosp-harness 引用后接入。详见 [完整协作方法](../skills/build-aosp-harness/references/intent-cooperation.md)。
