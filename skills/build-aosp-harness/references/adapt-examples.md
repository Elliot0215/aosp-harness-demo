# 从本仓库示例适配

仅在能访问 `aosp-harness` 示例仓且准备复用时读取。它是可选素材，不是 skill 运行的外部硬依赖。

## 定位与读取

先解析本 `SKILL.md` 所在目录的物理路径。本 skill 位于示例仓 `skills/build-aosp-harness/` 时，该目录的上两级是候选仓根；检查根 `README.md` 和下面的源文件确认身份，不硬编码作者机器路径。若 skill 被单独复制走，检查用户提供的示例仓路径；仍无素材时依据主文档协议在目标树实现，不从未知地址下载模板，也不要声称已运行本仓库测试。

只读取所选客户端的素材：

| 用途 | Codex | Claude Code | Cursor Agent | ZCode |
| --- | --- | --- | --- | --- |
| 使用说明 | `codex/README.md` | `claude-code/README.md` | `cursor-agent/README.md` | `zcode/README.md` |
| 安装器 | `codex/features/install-harness.sh` | `claude-code/features/install-harness.sh` | `cursor-agent/features/install-harness.sh` | `zcode/features/install-harness.sh` |
| wrapper | `codex/features/.harness/codex/bin/codex-feature` | `claude-code/features/.harness/bin/claude-feature` | `cursor-agent/features/.harness/cursor/bin/cursor-feature` | `zcode/features/.harness/zcode/bin/prepare-feature`（无 CLI，仅准备入口） |
| App 准备入口 | `codex/features/.harness/codex/bin/prepare-feature` | 不适用 | `cursor-agent/features/.harness/cursor/bin/prepare-feature` | 参阅 ZCode 使用说明 |
| hooks 与配置 | `codex/features/.harness/codex/` | `claude-code/features/.harness/{hooks,settings.json}` | `cursor-agent/features/.harness/cursor/{hooks.json,hooks}` | `zcode/features/.harness/zcode/{config.json,hooks}` |
| 流程 skills | `codex/features/.harness/skills/` | `claude-code/features/.harness/skills/` | `cursor-agent/features/.harness/cursor/skills/` | `zcode/features/.harness/zcode/skills/` |
| 流程静态检查器 | `codex/features/.harness/codex/bin/check-process-layer` | `claude-code/features/.harness/bin/check-process-layer` | `cursor-agent/features/.harness/cursor/bin/check-process-layer` | `zcode/features/.harness/zcode/bin/check-process-layer` |
| feature 素材 | `codex/features/dev-sidebar/` | `claude-code/features/dev-sidebar/` | `cursor-agent/features/dev-sidebar/` | `zcode/features/dev-sidebar/` |
| 回归 | `codex/tests/` | `claude-code/features/.harness/tests/` | `cursor-agent/tests/` | `zcode/tests/` |

跨客户端的命令块和 hook 配置运行测试位于 `tests/test-runtime-contracts.sh`，按 [validation.md](validation.md) 检查其覆盖与目标场景的差异。

Codex App 还需读取 [codex-app.md](codex-app.md)，参考 `tests/test-codex-app.sh` 的配置命令离线测试；该测试不是实际 App 事件投递证据。

以上是仓库实现位置，不代表任意客户端版本都支持其配置。优先检查当前安装版本；无法确认的 hook 能力保留为兼容性缺项。

## 四套布局分别保留

本仓库 Codex 示例：

```text
.codex         -> features/.harness/codex
.agents/skills -> ../features/.harness/skills
AGENTS.md      -> features/<feature>/AGENTS.md
```

本仓库 Claude Code 示例：

```text
.claude       -> features/.harness
CLAUDE.md     -> features/<feature>/CLAUDE.md
```

本仓库 Cursor Agent 示例：

```text
.cursor   -> features/.harness/cursor
AGENTS.md -> features/<feature>/AGENTS.md
```

本仓库 ZCode 示例：

```text
.zcode    -> features/.harness/zcode
AGENTS.md -> features/<feature>/AGENTS.md
```

物理源目录必须叫 `cursor` 而不是 `.cursor`：Cursor 会递归发现仓库内任意 `.cursor/skills/`，嵌套 skill 还会被限定到该子树。ZCode 的 hooks 配置位于 `.zcode/config.json` 的 `hooks.events`，配置文件 hooks 默认禁用，必须显式 `"hooks": {"enabled": true}`；命令 hook 用退出码表达结论（0 通过、2 阻断），stdout 走严格 JSON schema，因此阻断原因写 stderr，不能复用 Codex 的 `continue/stopReason` JSON。`.zcode` 整目录由软链接接管后，用户自有的工作区级配置需并入 harness 管理的 `config.json`。不要把 `.codex` 改名为 `.cursor` 或 `.zcode`，也不要把 Claude `settings.json` 事件名改成其他客户端的就声称完成。

不要把四套 `.harness/` 整目录直接合并；用户要求同时支持多个客户端时，设计独立适配器，共享 feature 事实和验证脚本，分别检查安装和启动。同树同时装 Codex 与 Cursor 时，`.agents/skills` 会被 Cursor 再扫一遍，可能双注册；ZCode 也扫描 `.agents/skills`，与 Codex 共存时同样要审计双注册。保留已安装的入口链接，修改它们对应的物理源文件。

## 复制前明确适配差异

- `frameworks/base/`、`frameworks/native/` 是占位源码，不复制到真实树；`dev-sidebar` 仅是示例需求。只取所需 Harness 文件，保留隐藏目录及可执行权限，不递归覆盖整个目标 `features/`。
- `CURRENT_FEATURE` 用于离线选择。示例依次尝试 `frameworks/base`、`frameworks/native`、`frameworks/av`、`system/core`，取首个非 detached 分支；名称非法则拒绝，不继续找下一仓。没有候选分支时才回退该文件。真实树明确锚点仓或显式选择策略；不要保留“任意候选仓有分支就选它”的偶然行为，不因锚点失效而静默回退到 Demo。示例的真实分支检查由 `.repo` 目录触发，适配到独立 project/worktree 时应显式判定模式。
- `check-branch.sh` 默认值、feature 上下文、wrapper、流程 skill 和验证入口中的 `dev-sidebar` 必须协调替换；`repos.tsv` 根据需求重新生成。四套 `check-process-layer` 都是 Demo 专用静态检查，不执行构建：Codex、Cursor 与 ZCode 固定 skill 名、精确 frontmatter、lunch、模块、产物和命令，Cursor 与 ZCode 额外要求 `/skill-name` 显式选择且禁止 `paths`；Claude 只匹配少量命令、产物及验证入口文本。复用时同步适配检查器和测试，不把它们当作通用 skill 格式规范或命令能运行的证据。
- 示例只支持单组件 feature 名；含 `/` 的真实分支需要显式映射和测试，不能只放宽正则后拼路径。
- 清单解析能力不同：Codex、Cursor 与 ZCode 校验三列非空 Tab 字段、feature 一致性及 NUL；Claude 只按空白读取第一列，以 `FEATURE_NAME` 比较所有仓分支。四者均未完整实现重复仓、规范化路径越界与 project 顶层校验。适配时补齐 [feature-contract.md](feature-contract.md) 的目标约束，不能以 Demo 已通过为理由降低清单校验。
- 四套示例的 wrapper 在检测到 `.repo` 时校验涉及仓。Codex 与 Cursor 的准备步骤已经拆到 `prepare-feature`，CLI wrapper 共用它；App 先准备再新建任务。Cursor 桌面 IDE 打开的是工作区文件夹，没有 `--workspace`：先运行 `prepare-feature`，信任工作区，再新建 Agent 对话。切换 feature 后不要恢复旧对话。Codex 的 `session-lifecycle.sh` 在 SessionStart 与 UserPromptSubmit 校验 cwd、上下文链接，并在 `.repo` 模式复查涉及仓；feature 漂移、缺失/非法快照等返回阻断 JSON。其他客户端不要据此推定拥有同样的涉及仓持续检查；Claude Code 仅在快照内容和当前 feature 均非空且不同时告警；Cursor 在 `beforeSubmitPrompt` 返回 `continue: false`，并在 `preToolUse` 返回 `permission: deny`；ZCode 的统一 lifecycle hook 校验 cwd、准备状态与快照后以 exit 2 + stderr 阻断。Codex 与 Claude 都没有写工具前的持续保护；Cursor Demo 用 `preToolUse` 补了这一层，但 CLI 是否实际派发该事件仍记为缺项。真实适配需按本机客户端核对事件覆盖，未验证的事件不能写成“已拦截”。
- Codex 快照按 `session_id` 隔离，默认目录按 UID 共用，未加入树根标识；`SessionStart` 匹配 `startup/resume/clear/compact`，仅无快照的 startup 建立基线，恢复及重复 startup 保留原快照进行校验，缺失恢复状态阻断。不要绕过统一 lifecycle 入口直接调用底层 `session-start.sh` 来恢复任务。Cursor 快照按 `session_id` 或 `conversation_id` 隔离，默认目录 `${TMPDIR:-/tmp}/aosp-cursor-harness-$UID`。ZCode 的 `SessionStart` matcher 覆盖 `startup/resume/clear/compact`，只有全新 startup 建立基线，resume/clear/compact 只校验从不改写，快照按 `session_id` 隔离，默认目录 `${TMPDIR:-/tmp}/aosp-zcode-harness-$UID`。Claude Code 使用固定临时快照，并在 `SessionEnd` 清理（ZCode 无 SessionEnd，快照不自动清理）。四者不能一概称为已有跨树/多会话隔离。按目标需求加入树根与会话标识、恢复会话有效性检查，不以重新记录快照掩盖旧会话上下文。
- Codex 示例使用 `hooks.json`，Claude Code 示例使用 `settings.json`，Cursor 示例使用 `.cursor/hooks.json`（schema `version: 1`），ZCode 示例使用 `.zcode/config.json` 的 `hooks.events`（配置文件 hooks 默认禁用，必须显式 `enabled: true`；命令经 `${ZCODE_PROJECT_DIR}` 定位）；事件、输入字段、返回协议、信任流程分别验证。Cursor 的 `sessionStart` 是 fire-and-forget，不能阻断启动。项目 hook 需要用户在客户端进行的信任操作应如实交代，不自动修改全局信任或权限策略来绕过；Cursor 日常入口不要自动加 `--trust`。
- 当前 Codex 流程 skill 使用 `name` / `description`，支持说明中的显式 `$skill-name`、AGENTS 路由和 description 匹配；Cursor 与 ZCode 使用 `name` / `description` 和显式 `/skill-name`，不把 `paths` 写成自动触发；Claude 示例同样使用显式 `/skill-name` 和真实本地路径，已移除 `paths` 字段。不要把该字段复制成 Codex、Cursor 或 ZCode 的路径触发机制，或用路径路由文字证明客户端自动加载。使用 feature 指令中的显式路由，离线文件检查与真实客户端加载分别验证。ZCode 还存在 user scope（`~/.zcode/skills`、`~/.agents/skills`）同名 skill 遮蔽工作区版本的排查项。
- 安装器的标准入口冲突保护与 wrapper 的上下文同步分开检查。四套安装器均拒绝冲突；Claude wrapper 遇到普通根 `CLAUDE.md` 会备份后原子替换，Codex、Cursor 与 ZCode wrapper 拒绝普通 `AGENTS.md`。Cursor 的 `prepare-feature` 不启动客户端；CLI wrapper 共用该步骤后拒绝 `--worktree`/`-w`，优先解析 `cursor-agent`，只有 `agent --help` 含 `Start the Cursor Agent` 才回退，并在未指定时传入 `--workspace`。日常入口不要自动加 `--trust`。ZCode 没有官方 CLI，不做 CLI 启动：唯一入口是 `prepare-feature`，随后在 App 中以树根新建会话。四者 `--dry-run` 均执行上下文同步，Claude 还可能生成备份。先合并保留已有指令，仅留下备份不代表旧约束仍被加载。
- Claude 的 `SessionStart` 会尝试补同步链接并告警，但客户端可能已读入旧上下文；这不替代 wrapper 的启动前同步，也不保证首次加载或热重载正确。Cursor 的 `sessionStart` 同样不能热换本次运行已加载的 `AGENTS.md`。
- 替换 `SidebarService`、`sidebar`、包名和验证查询，尤其是 Demo 环境变量及尚未实现的 SKIP。不要全局文本替换后就认定满足新需求。
- 四套验证器的 `--allow-skip` 都仅允许与 `--demo` 联用，存在 SKIP 时始终输出 `RESULT INCOMPLETE`，探索模式可退出 0；严格模式仍非零。严格验收要求最终行精确为 `RESULT PASS`、退出 0 且无必需 SKIP，不能只匹配 PASS 前缀。
- `aosp_cf_x86_64_phone-trunk_staging-userdebug`、`vsoc_x86_64`、`services.jar`、`system.img` 是具体示例参数。核实目标分支的构建入口、产品和产物；SELinux 等变更的部署分区由实际项目确定。
- Claude 构建片段虽在同一 Bash 初始化，但未包含 Codex 的唯一日志、后台等待、成功标记与产物检查，services 部署也没有独立 `get-state`。其 SELinux 说明仍用简写 `cvd stop/start`，规则示例与 Codex 的 `system_server_service` 属性方案不同。按主文流程契约补齐实际需要的构建证据、设备连接和组选择，并依目标源码核实策略，不能原样复制后声称已满足契约。
- 保留安装冲突检查与回滚，再补目标场景需要的路径约束、多会话隔离和分支检查。示例已有测试通过不代表新场景已覆盖。

## 验证命令的边界

两端 services 部署块仅演示固定序列号和逐步失败停止；没有不可变备份、原子替换、整组回滚或新启动周期验证。真实设备部署按 [deployment-transactions.md](deployment-transactions.md) 单独实现和测试；尤其不能把直接 push 示例用于覆盖正在 mmap 的 ELF。Cursor 示例的部署块与 Codex 同级，同样不是生产入口。

在示例仓根可运行：

```bash
bash scripts/check.sh --offline
```

它验证原始示例和仓库协议。新 Harness 还需在隔离目标中运行自己的安装、wrapper 和断言测试；不得用原始 Demo 的结果替代目标交付验证。`run-demo.sh` 包含故意的失败展示，评估时读取场景预期和最终回归结果。

源仓若只是提供模板，不需要把 `run-demo.sh`、占位源码、原 feature 或整套历史设计文档放进目标 AOSP。

## intent 协作

四套 feature 示例均约定新规划放在 `features/dev-sidebar/.intent/`，已有资料原位续用；主 agent 维护规划和审查 Markdown，源码范围仍由 `repos.tsv` 限定。按 [intent-cooperation.md](intent-cooperation.md) 接入，保留 wrapper、hooks、安装布局和各端清单格式；不自动安装或执行 intent 阶段。
