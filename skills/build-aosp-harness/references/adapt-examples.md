# 从本仓库示例适配

仅在能访问 `aosp-harness` 示例仓且准备复用时读取。它是可选素材，不是 skill 运行的外部硬依赖。

## 定位与读取

先解析本 `SKILL.md` 所在目录的物理路径。本 skill 位于示例仓 `skills/build-aosp-harness/` 时，该目录的上两级是候选仓根；检查根 `README.md` 和下面的源文件确认身份，不硬编码作者机器路径。若 skill 被单独复制走，检查用户提供的示例仓路径；仍无素材时依据主文档协议在目标树实现，不从未知地址下载模板，也不要声称已运行本仓库测试。

只读取所选客户端的素材：

| 用途 | Codex 源文件 | Claude Code 源文件 |
| --- | --- | --- |
| 使用说明 | `codex/README.md` | `claude-code/README.md` |
| 安装器 | `codex/features/install-harness.sh` | `claude-code/features/install-harness.sh` |
| wrapper | `codex/features/.harness/codex/bin/codex-feature` | `claude-code/features/.harness/bin/claude-feature` |
| hooks 与配置 | `codex/features/.harness/codex/` | `claude-code/features/.harness/{hooks,settings.json}` |
| 流程 skills | `codex/features/.harness/skills/` | `claude-code/features/.harness/skills/` |
| 流程静态检查器 | `codex/features/.harness/codex/bin/check-process-layer` | `claude-code/features/.harness/bin/check-process-layer` |
| feature 素材 | `codex/features/dev-sidebar/` | `claude-code/features/dev-sidebar/` |
| 回归 | `codex/tests/` | `claude-code/features/.harness/tests/` |

跨客户端的命令块和 hook 配置运行测试位于 `tests/test-runtime-contracts.sh`，按 [validation.md](validation.md) 检查其覆盖与目标场景的差异。

以上是仓库实现位置，不代表任意客户端版本都支持其配置。优先检查当前安装版本；无法确认的 hook 能力保留为兼容性缺项。

## 两套布局分别保留

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

不要把两套 `.harness/` 整目录直接合并；用户要求同时支持两个客户端时，设计独立适配器，共享 feature 事实和验证脚本，分别检查安装和启动。保留已安装的入口链接，修改它们对应的物理源文件。

## 复制前明确适配差异

- `frameworks/base/`、`frameworks/native/` 是占位源码，不复制到真实树；`dev-sidebar` 仅是示例需求。只取所需 Harness 文件，保留隐藏目录及可执行权限，不递归覆盖整个目标 `features/`。
- `CURRENT_FEATURE` 用于离线选择。示例依次尝试 `frameworks/base`、`frameworks/native`、`frameworks/av`、`system/core`，取首个非 detached 分支；名称非法则拒绝，不继续找下一仓。没有候选分支时才回退该文件。真实树明确锚点仓或显式选择策略；不要保留“任意候选仓有分支就选它”的偶然行为，不因锚点失效而静默回退到 Demo。示例的真实分支检查由 `.repo` 目录触发，适配到独立 project/worktree 时应显式判定模式。
- `check-branch.sh` 默认值、feature 上下文、wrapper、流程 skill 和验证入口中的 `dev-sidebar` 必须协调替换；`repos.tsv` 根据需求重新生成。两端的 `check-process-layer` 都是 Demo 专用静态检查，不执行构建：Codex 固定 skill 名、精确 frontmatter、lunch、模块、产物和命令；Claude 只匹配少量命令、产物及验证入口文本。复用时同步适配检查器和测试，不把它们当作通用 skill 格式规范或命令能运行的证据。
- 示例只支持单组件 feature 名；含 `/` 的真实分支需要显式映射和测试，不能只放宽正则后拼路径。
- 清单解析能力不同：Codex 校验三列非空 Tab 字段、feature 一致性及 NUL；Claude 只按空白读取第一列，以 `FEATURE_NAME` 比较所有仓分支。两者均未完整实现重复仓、规范化路径越界与 project 顶层校验。适配时补齐 [feature-contract.md](feature-contract.md) 的目标约束，不能以 Demo 已通过为理由降低清单校验。
- 两套示例都只在 wrapper 检测到 `.repo` 时校验所有涉及仓；提示提交 hook 只比较 feature，不重读 `repos.tsv` 或复查其他涉及仓。Codex 对 feature 漂移、缺失/非法快照等返回阻断 JSON，Claude Code 仅在快照内容和当前 feature 均非空且不同时告警。二者均没有写工具前的持续保护，真实适配需补检查或在写入前重新运行分支检查。
- Codex 快照按 `session_id` 隔离，默认目录按 UID 共用，未加入树根标识；`SessionStart` 仅匹配 `startup`，没有专门的 resume 初始化。Claude Code 使用固定临时快照，并在 `SessionEnd` 清理；两者不能一概称为已有跨树/多会话隔离。按目标需求加入树根与会话标识、恢复会话有效性检查，不以重新记录快照掩盖旧会话上下文。
- Codex 示例使用 `hooks.json`，Claude Code 示例使用 `settings.json`；事件、输入字段、返回协议、信任流程分别验证。项目 hook 需要用户在客户端进行的信任操作应如实交代，不自动修改全局信任或权限策略来绕过。
- 当前 Codex 流程 skill 使用 `name` / `description`，支持说明中的显式 `$skill-name`、AGENTS 路由和 description 匹配；Claude 示例保留 `paths` 字段。不要把该字段复制成 Codex 的路径触发机制，或用路径路由文字证明客户端自动加载。使用 feature 指令中的显式路由，离线文件检查与真实客户端加载分别验证。
- 安装器的标准入口冲突保护与 wrapper 的上下文同步分开检查。两套安装器均拒绝冲突；Claude wrapper 遇到普通根 `CLAUDE.md` 会备份后原子替换，Codex wrapper 拒绝普通 `AGENTS.md`。两者 `--dry-run` 均执行上下文同步，Claude 还可能生成备份。先合并保留已有指令，仅留下备份不代表旧约束仍被加载。
- Claude 的 `SessionStart` 会尝试补同步链接并告警，但客户端可能已读入旧上下文；这不替代 wrapper 的启动前同步，也不保证首次加载或热重载正确。
- 替换 `SidebarService`、`sidebar`、包名和验证查询，尤其是 Demo 环境变量及尚未实现的 SKIP。不要全局文本替换后就认定满足新需求。
- 两套验证器的 `--allow-skip` 都仅允许与 `--demo` 联用，允许跳过时均可能输出 `RESULT PASS (SKIP allowed)`，不符合新 Harness 保留 `INCOMPLETE` 的目标协议。复用时统一结果协议，严格验收要求最终行精确为 `RESULT PASS`、退出 0 且无必需 SKIP，不能只匹配 PASS 前缀。
- `aosp_cf_x86_64_phone-trunk_staging-userdebug`、`vsoc_x86_64`、`services.jar`、`system.img` 是具体示例参数。核实目标分支的构建入口、产品和产物；SELinux 等变更的部署分区由实际项目确定。
- Claude 构建片段虽在同一 Bash 初始化，但未包含 Codex 的唯一日志、后台等待、成功标记与产物检查，services 部署也没有独立 `get-state`。其 SELinux 说明仍用简写 `cvd stop/start`，规则示例与 Codex 的 `system_server_service` 属性方案不同。按主文流程契约补齐实际需要的构建证据、设备连接和组选择，并依目标源码核实策略，不能原样复制后声称已满足契约。
- 保留安装冲突检查与回滚，再补目标场景需要的路径约束、多会话隔离和分支检查。示例已有测试通过不代表新场景已覆盖。

## 验证命令的边界

两端 services 部署块仅演示固定序列号和逐步失败停止；没有不可变备份、原子替换、整组回滚或新启动周期验证。真实设备部署按 [deployment-transactions.md](deployment-transactions.md) 单独实现和测试；尤其不能把直接 push 示例用于覆盖正在 mmap 的 ELF。

在示例仓根可运行：

```bash
bash scripts/check.sh --offline
```

它验证原始示例和仓库协议。新 Harness 还需在隔离目标中运行自己的安装、wrapper 和断言测试；不得用原始 Demo 的结果替代目标交付验证。`run-demo.sh` 包含故意的失败展示，评估时读取场景预期和最终回归结果。

源仓若只是提供模板，不需要把 `run-demo.sh`、占位源码、原 feature 或整套历史设计文档放进目标 AOSP。
