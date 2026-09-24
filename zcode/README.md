# AOSP 整机源码 ZCode Harness 可运行 Demo

这是一份 **ZCode 原生重写，不是名称替换** 的 AOSP Harness 教学示例。它用 ZCode 已文档化的工作区 `AGENTS.md`、`.zcode/config.json` hooks、`.zcode/skills` 和 Desktop（App）接入入口，演示“上下文 / 流程 / 验证闭环”三层怎样协作。Demo 不启动 ZCode，不运行 AOSP 构建，也不访问 ADB 或 CVD。

## 快速开始

从仓库根目录运行主入口：

```bash
./zcode/run-demo.sh
```

或先进入 ZCode demo 目录：

```bash
cd zcode
./run-demo.sh
```

`run-demo.sh` 先运行幂等安装器，再依次演示上下文选择、会话分支漂移、涉及仓分支一致性、流程 skills、严格验证和回归测试。它只调用 `prepare-feature` 准备入口和确定性 demo 入口，不启动任何客户端。

## ZCode 与 Claude Code 版的关键差异

以下 Claude Code 一栏只描述本仓库的 `claude-code/` demo，不把该 demo 的实现细节外推为 Claude Code 的通用产品契约。ZCode 的扩展面依据为客户端内置 `zcode-guide` 插件文档（Settings → Plugin Management 可见），本 demo 不引用任何未经证实的外部链接。

| 维度 | ZCode 版 | 本仓库 Claude Code demo |
|---|---|---|
| 根 / feature 指引 | 使用根与 feature 的 `AGENTS.md`；ZCode 从当前目录向上搜索到项目根 | 使用根与 feature 的 `CLAUDE.md`，由该 demo 的 wrapper 在启动前同步根软链 |
| 仓库 skills | ZCode 仓库 skills 位于 `.zcode/skills`（也扫描 `.agents/skills`，`.zcode` 优先）；可显式 `/skill-name` 选择，也可在任务匹配 `description` 时隐式选择；没有已文档化的 `paths` 路径触发契约 | 本仓库 Claude demo 使用 `.claude/skills` 与 feature 指令显式路由，不设置 `paths` metadata |
| Hooks | ZCode demo 用 `.zcode/config.json` 的 `hooks.events`；**配置文件 hooks 默认禁用，必须显式 `"hooks": {"enabled": true}`**；事件共七个，无 SessionEnd；命令 hook 用退出码表达结论：0 通过、2 阻断，stdout 走严格 JSON schema（多余 key 判失败） | 本仓库 Claude demo 用 `.claude/settings.json`，命令通过 `${CLAUDE_PROJECT_DIR}` 定位；它不与 ZCode 的配置 schema 等同 |
| 启动边界 | ZCode 没有官方 CLI，本示例**不做 CLI 支持**：会话前必须先 `prepare-feature` 选定 `AGENTS.md`，再在 App 中新建会话；会话中漂移由 hook 以 exit 2 阻断并提示重启 | 该 demo 也在启动前同步 `CLAUDE.md`，并把 SessionStart hook 定位为 fallback；这是本仓库的工程选择 |

因此，ZCode 版不是把 `CLAUDE.md` 改名为 `AGENTS.md`，也不是把 Codex 的 `.codex/hooks.json` 改个存放位置：指引发现、skill 选择、hook 配置形态与阻断协议、启动时正确性边界都按 ZCode 契约重新落地。

## 目录与三层

```text
zcode/
├── CURRENT_FEATURE
├── AGENTS.md -> features/dev-sidebar/AGENTS.md
├── run-demo.sh
├── .zcode -> features/.harness/zcode
├── features/                          # 真实 AOSP 中可独立成 Git 仓
│   ├── install-harness.sh
│   ├── .harness/                      # ZCode 自己的通用 Harness
│   │   └── zcode/
│   │       ├── bin/{prepare-feature,check-process-layer}
│   │       ├── config.json
│   │       ├── hooks/{feature-common,session-lifecycle,session-start,check-branch-drift}.sh
│   │       └── skills/
│   │           ├── build-services-jar/SKILL.md
│   │           └── build-sepolicy/SKILL.md
│   └── dev-sidebar/
│       ├── AGENTS.md
│       ├── repos.tsv
│       ├── check-branch.sh
│       └── verify-sidebar.sh
└── tests/{test-harness,test-install-harness}.sh
```

| 层 | 职责 | Demo 落点 |
|---|---|---|
| ① 上下文层 | 在一次 ZCode 会话前选定 feature，并防止会话中分支漂移 | `CURRENT_FEATURE` + 树根 `AGENTS.md` 软链 + `prepare-feature` + hooks |
| ② 流程层 | 将构建、部署、安全检查和验证顺序封装为可复用流程 | `.zcode/skills/*/SKILL.md` + `check-process-layer` |
| ③ 验证闭环层 | 用脚本产出可审计的 PASS / FAIL / INCOMPLETE 结论 | `features/dev-sidebar/verify-sidebar.sh` |

导航不单独算一层：本方案使用 **`rg` + 源码阅读**，先按仓和路径缩小范围，再搜 JNI 注册名或全限定 `Class::method`。不需要预先建立索引，也不把搜索命中误写成完整引用关系。

## 安装与切换 feature

在 `zcode/` 或真实 AOSP 树根运行：

```bash
bash features/install-harness.sh
./.zcode/bin/prepare-feature
```

安装器创建一个相对软链 `.zcode -> features/.harness/zcode`，可重复执行；已有普通文件、目录或其他目标的软链会使安装失败，原内容保留。物理源命名为 `features/.harness/zcode` 而不是 `features/.zcode`，避免 ZCode 把子树内的 skills 目录扫描成嵌套注册。

`prepare-feature` 是唯一的 harness 入口：检测 feature、校验涉及仓分支、切换根 `AGENTS.md` 软链，**不启动任何客户端**，因此不需要 `--dry-run` 变体。新增 feature 时，在 `features/<feature>/` 准备 `AGENTS.md`、`repos.tsv`、分支检查和验证脚本。真实树切换锚点仓及涉及仓分支后重新运行它，再在 App 中新建会话；Demo 用 `CURRENT_FEATURE` 模拟分支选择。通用 hooks 和 skills 无需随 feature 切换。会话中检测到漂移会阻断继续使用旧上下文。

`.zcode` 整目录由软链接管后，工作区级其他 ZCode 配置（如 MCP servers）需要写入 harness 管理的 `features/.harness/zcode/config.json`；安装器对已存在的 `.zcode` 拒绝覆盖，因此不会静默吞掉用户已有配置。实测 ZCode Desktop 会在工作区 `.zcode/plans/` 写入计划文件；接管后这些文件会经软链落到 `features/.harness/zcode/plans/`，与 `config.json` 无碰撞，但会成为 features 仓里的未跟踪内容。脚本从物理位置定位树根，也支持直接调用 `features/.harness/zcode/bin/prepare-feature`。

## ZCode Desktop（App）接入

ZCode 官方形态是桌面 App（ADE），没有公开 CLI；本示例只保证 App 接入，不做 CLI 支持。App 新建会话不会经过任何启动封装，因此必须先准备上下文，再新建会话：

```bash
# 在本示例的 zcode/ 目录，或安装了 features/ 的真实 AOSP 树根执行
bash features/install-harness.sh
./.zcode/bin/prepare-feature
```

`prepare-feature` 会检测 feature、在真实 `.repo/` 树中检查涉及仓分支，并安全更新根 `AGENTS.md` 软链；不会启动任何客户端。普通 `AGENTS.md` 文件仍受保护，安装器也不会覆盖既有配置。

然后在 Desktop 中以该目录为工作区打开项目并新建会话。此教学仓库应选择 **`aosp-harness/zcode/`**，而不是外层 `aosp-harness/`。真实 AOSP 应选择完整源码树根；单个 Git 仓的 worktree 无法复制 `.repo/` 管理的多个仓、独立 features 仓及编译输出。需要并行 feature 时，分别准备完整工作区，避免多个会话竞争同一根 `AGENTS.md` 链接。

### 生命周期与配置

配置入口是 `.zcode/config.json` 的 `hooks.events`。**配置文件 hooks 默认禁用**；本 demo 的 config.json 已带 `"hooks": {"enabled": true}`。`SessionStart`（matcher 匹配 `startup/resume/clear/compact`）和 `UserPromptSubmit` 统一进入 `session-lifecycle.sh`，命令通过文档化模板变量 `${ZCODE_PROJECT_DIR}` 定位脚本：

- 检查会话 cwd 是否为源码树根、当前 feature 是否存在、根链接是否已准备好；真实树还会重新检查涉及仓分支。
- 新会话 `startup` 建立初始快照；重复 startup 保留已有快照。
- 恢复、清理或压缩上下文时仅校验原快照，不用当前 feature 覆盖它。快照丢失、损坏或 feature 改变时以 exit 2 阻断并输出 stderr 说明。
- 阻断提示执行 `prepare-feature` 后新建会话。切换 feature 后不要恢复旧会话；hook 不会在同一运行中重新加载新的 `AGENTS.md`。

ZCode 命令 hook 的输出契约是“退出码优先”：0 通过，2 阻断；stdout 若非空会被当作严格 JSON schema 解析，多余 key 直接判失败。因此本 demo 的 hook 一律保持 stdout 为空，把阻断原因写到 stderr。

### 验证边界与 Desktop 验收

仓库根目录运行 `bash tests/test-zcode-app.sh` 可离线验证实际 config.json 中配置的命令，覆盖带空格路径、准备幂等性、保护普通文件、分支异常、恢复旧会话、快照丢失及非法输入。它已接入 `bash scripts/check.sh --offline`，不启动 Desktop、不构建 Android、不访问设备。

实际 Desktop 验收应使用独立 demo 副本，避免影响正在使用的工作区：

1. 执行准备命令，以准备后的目录新建会话，核对 feature 指令和 `/build-services-jar`、`/build-sepolicy` 是否可发现；只核对能力，不运行构建或设备操作。
2. 发送一个只读请求，确认对应会话的 `.feature` 快照已生成；默认位于 `${TMPDIR:-/tmp}/aosp-zcode-harness-$UID/`，hook 执行记录（触发、超时、阻断）可在 ZCode 日志中核对。记录 Desktop 版本、执行环境和 hook 运行证据。
3. 恢复会话并发送只读请求，确认同 feature 可以继续；准备另一个有效 feature 后恢复原会话，确认在代理工作前阻断。
4. 在新 feature 下新建会话，确认可以继续；删除测试会话的快照后恢复该会话，确认阻断且不会自动重建基线。

**状态：接入代码与离线测试已提供；真实 ZCode 会话的事件投递、stdin payload 字段名及界面阻断效果仍需上述验收。** 离线脚本行为不等于客户端已加载 hooks；hooks 未启用或未加载时，只能依靠显式检查流程，不能宣称具备自动漂移拦截。

## ① 上下文层

### 准备入口（prepare-feature）

```bash
# 选择 feature、校验分支并同步 AGENTS.md；不启动任何客户端
./.zcode/bin/prepare-feature
```

准备入口的正确性边界很重要：**AGENTS.md 每次会话只加载一次**，所以会话中改软链不等于当前会话已重载指令链。必须先运行 `prepare-feature` 选定链接，再在 App 中新建会话；漂移 hook 的职责是停止继续工作并提示重新准备，不是在同一会话里热换上下文。

ZCode 从当前工作目录向上搜索 `AGENTS.md` 直到项目根。因此对 **非 Git 的 AOSP 树根**，要把准备后的树根作为工作区打开；hook 命令也通过 `${ZCODE_PROJECT_DIR}` 取得项目根，不依赖调用者 cwd。

### Hooks 演示

```bash
session_payload='{"session_id":"manual-demo","cwd":".","hook_event_name":"SessionStart"}'
prompt_payload='{"session_id":"manual-demo","cwd":".","hook_event_name":"UserPromptSubmit"}'
printf '%s\n' "$session_payload" | ./.zcode/hooks/session-start.sh
printf '%s\n' "$prompt_payload" | ./.zcode/hooks/check-branch-drift.sh
```

`session-start.sh` 只记录快照；一致性校验统一走 `session-lifecycle.sh`。上面两个脚本支持 `HARNESS_ROOT` 与 `ZCODE_HARNESS_STATE_DIR` 覆盖，便于离线验证。`repos.tsv` 是 feature 涉及仓的单一事实源：

```bash
./features/dev-sidebar/check-branch.sh --demo
```

`--demo` 故意返回一个分支漂移失败，便于检查调用方是否正确处理非零退出。

## ② 流程层

```bash
./.zcode/bin/check-process-layer
```

Skills 位于 `.zcode/skills`（物理源在 `features/.harness/zcode/skills`）。

- 显式选择：在提示中写 `/build-services-jar` 或直接使用 skill 名称。
- 隐式选择：任务与 skill 的 `description` 匹配时，ZCode 可选择它。
- 当前公开契约中 **没有已文档化的 `paths` 路径触发契约**；不要把“修改某路径”宣称为必然选中某个 skill。这个 demo 由 feature `AGENTS.md` 显式路由必须使用的 skill。

注意 user scope 遮蔽：`~/.zcode/skills` 与 `~/.agents/skills` 中的同名 skill 优先于工作区版本。真实树上如果开发者家目录已有同名 skill，会遮蔽树内 Harness 版本；接入审计时应检查这一层。

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
2. 在 AOSP 树根运行 `bash features/install-harness.sh`，通过 `.zcode/` 下的标准入口暴露 Harness；每次任务前运行 `./.zcode/bin/prepare-feature` 选定树根 `AGENTS.md` 软链，再在 App 中以树根为工作区新建会话（无 CLI 入口）。
3. 保留 `repos.tsv` 和涉及仓 checker，在开始任务前 fail closed 检查缺仓、分支漂移、detached HEAD 和非法仓库。
4. 真实设备操作前必须显式固定 `ANDROID_SERIAL`，先校验 `adb -s "$ANDROID_SERIAL" get-state`；操作 Cuttlefish 前先用 `cvd fleet` 确认目标，再固定 `CVD_GROUP`，禁止对未选定组执行 stop/start。
5. 把 `verify-sidebar.sh` 的 demo 数据源换成真实设备查询，保留查询失败即 FAIL、crash 时间基线、严格 SKIP 和整个 feature 只有严格 `RESULT PASS` 且退出 0 才能交付的语义。

## 继续阅读

- 使用指南：[AOSP Harness 使用指南：从搭建到日常使用](../docs/AOSP-Harness使用指南-zcode.md)
- 长文：[AOSP 整机源码 ZCode Harness 工程探索](../docs/AOSP整机源码Harness工程探索-zcode版.md)
- ZCode 扩展面（指令文件、skills、hooks、插件）的权威说明见客户端内置 `zcode-guide` 插件：Settings → Plugin Management → zcode-guide。

## 与 intent 协作

当前 feature 指令中包含完整协作规则。新规划默认放在 `features/dev-sidebar/.intent/`（`roadmap.md`、固定编号的需求 Markdown、实际审查的逐轮 `review/` 记录）；用户指定和已有文档位置优先，原位续用。主 agent 可更新这些规划资料，业务源码仍受 `repos.tsv` 限定。修改源码前读取实际流程 skill，并按 hook 覆盖范围重新检查分支；不自动切换 feature 或分支。

小需求满足事先明确的自身验收与必要回归即可交付；独立审查仅在用户要求或项目规则要求时成为完成条件。整个 feature 须全部需求和 `verify-sidebar.sh` 严格通过：最终 `RESULT PASS` 且退出 0。`RESULT INCOMPLETE` 在探索模式返回 0 仍是未完成；规划、Harness 离线检查、编译和设备验收分别报告。读取 skill 不代表运行其中所有命令，设备操作遵循已有授权；同一 out/、设备或 CVD 组串行使用。

先独立安装 intent 并确认当前客户端可见，再显式调用 `$intent-roadmap 为 dev-sidebar 规划路线图`、`$intent-plan features/dev-sidebar/.intent/001-需求名称.md` 或 `$intent-implement features/dev-sidebar/.intent/001-需求名称.md`；需要审查时调用 `$intent-review`。技能不会自动进入下一阶段。已有需求也可交给 build-aosp-harness 引用后接入。详见 [完整协作方法](../skills/build-aosp-harness/references/intent-cooperation.md)。
