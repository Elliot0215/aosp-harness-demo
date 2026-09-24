# AOSP Harness：Codex App 使用指南

本文说明如何从搭建 Harness 开始，在 Codex App 中接入项目、开发功能并验证交付。适用于本仓库的 Codex 适配方案，Windows 场景使用已配置的 WSL/Linux 执行环境。

完整流程：**明确需求与源码树 → 调用 skill 搭建 → 离线验证与准备 → App 新建任务验收 → 开发 → 验证交付**。

本仓库只有教学占位源码。离线演示通过不代表 Android 编译、真机验收或当前 App 的 hooks 已经验证通过。实际开发应在自己的完整 AOSP 源码树中进行。

## 1. 准备需求和目标环境

至少提供：

- AOSP 源码根目录的绝对路径。
- 要实现的功能、允许修改的范围和可观察的验收条件。
- 使用 Codex App，以及本次是否包含编译、部署和设备验收。

已有产品配置、构建入口、涉及仓与分支信息可以一起提供。不确定的参数让搭建代理检查源码或列为待配置，不直接套用 Demo 的 lunch、模块或设备参数。

同一源码树已有 Harness 时优先扩展；已有 `AGENTS.md`、项目配置和 skills 应保留有效约束。

## 2. 调用 skill 搭建 Harness

先确认当前任务能发现 `$build-aosp-harness`。本仓库提供的技能源文件位于 [skills/build-aosp-harness](../skills/build-aosp-harness/SKILL.md)，使用前应安装到客户端可发现的 skill 目录。

发送下面的需求，将路径和功能内容替换为实际值：

```text
$build-aosp-harness

目标源码树：/实际/AOSP/根目录
客户端：Codex App
功能：……
验收条件：……

先搭建开发框架并验证 App 接入。
本阶段不编译、不部署、不操作设备。
```

代理会检查现有工作区、推导涉及仓和流程，并生成或补齐以下内容：

| 内容 | 用途 |
| --- | --- |
| feature 的 `AGENTS.md` | 目标、修改范围、约束和流程路由 |
| `repos.tsv` 与分支检查器 | 涉及仓及预期分支的检查 |
| 构建流程 skills | 对应改动的构建、部署和验证步骤 |
| 安装器与 `prepare-feature` | 暴露标准入口，准备当前 feature 上下文 |
| 生命周期 hooks | 校验任务目录、上下文、恢复快照及分支漂移 |
| feature 验证脚本 | 给出 PASS、FAIL 或 INCOMPLETE |
| 使用说明与验收记录 | 进入 App 的准确步骤和验证证据 |

常见布局如下；已有工作区可保留自己的组织方式：

```text
<AOSP_ROOT>/
├── features/
│   ├── install-harness.sh
│   ├── .harness/               # 通用脚本、配置与 skills 的实际源文件
│   └── <feature>/
│       ├── AGENTS.md
│       ├── repos.tsv
│       ├── check-branch.sh
│       └── verify-<feature>.sh
├── .codex/                    # 标准配置入口
├── .agents/skills/            # 项目 skills 入口
└── AGENTS.md                  # 当前 feature 上下文入口
```

安装遇到普通文件、目录或错误链接冲突时，先检查并合并已有配置，不强制覆盖。

## 3. 离线验证并准备上下文

搭建代理应在隔离目录中验证安装幂等性、冲突保护、错误 cwd、缺仓、分支漂移、恢复快照、跨源码树状态隔离等行为。测试对象应是生成的目标 Harness，不能仅使用原 Demo 的结果。

检查通过后，在实际源码根执行交付说明中的命令。采用本仓库布局时通常是：

```bash
cd /实际/AOSP/根目录
bash features/install-harness.sh
./.codex/bin/prepare-feature
```

`prepare-feature` 负责选择 feature、检查分支和准备根上下文，不启动 Codex CLI，也不建立 App 任务快照。已有普通 `AGENTS.md` 不会被直接覆盖。

**必须先准备，再创建 App 任务。** 在已运行的任务中修改根上下文链接，不能据此认为当前任务已重新加载指令。CLI 的 `codex-feature --dry-run` 也可能修改上下文链接，不能当作纯只读命令。

## 4. 在 Codex App 中新建任务并验收

### 选择正确目录

在 App 中添加或选择目标项目，以完整 AOSP 源码根为任务工作目录。Windows 使用本套 Bash 适配时，选择能访问该树的 WSL/Linux 执行环境；确认代理与 hooks 使用相同的源码路径、用户和状态目录。

体验教学示例时，项目目录应为本仓库的 `codex/`，不是外层 `aosp-harness/`。初次接入直接使用准备好的目录；普通单仓 Git worktree 不会自动提供完整的 AOSP 多仓源码、独立 features 仓和编译环境。

### 发送首条验收提示

搭建代理应提供已填好 feature 和 skill 名的提示。也可以使用下面的通用版本：

```text
请只读验收本项目的 Codex App Harness，不构建、不部署、不访问设备：

1. 报告工作目录、当前 feature、本任务已加载的项目指令及关键约束。
   区分启动时加载的指令与之后手动读取的文件。
2. 确认任务可用技能列表中有项目的流程 skills，报告名称与来源。
   仅调用以读取流程，不执行构建和部署，检查同名全局 skill 是否遮蔽项目版本。
3. 检查本任务自动触发 hooks 的记录和对应快照。
   不要手动投递 payload、创建快照或修复状态来制造通过证据。
4. 无法确认的项目标为未验证，给出下一步。
```

### 确认实际接入，而不只检查文件存在

项目配置和 hook 定义需要按当前客户端支持的方式审查、信任；修改定义后重新确认。CLI 的 `/hooks` 审查能力不能证明 App 有相同界面或共享信任记录。未确认时让代理排查并记录具体缺项，不关闭信任检查来通过验收。

App 接入验收至少包括：

| 项目 | 应有的实际证据 |
| --- | --- |
| 上下文 | 新任务从正确目录加载预期 feature 指令 |
| skills | 任务发现项目技能，调用后读取正确版本 |
| hooks | 对应任务自动执行 hook，产生可关联的运行记录和初始快照 |
| 正常恢复 | 同 feature 恢复可继续，保留原基线 |
| 漂移阻断 | feature 或非锚点涉及仓漂移后，自动检查阻止代理继续工作 |
| 缺失状态 | 快照缺失后恢复被阻断，不自动补建基线 |

分支切换、删除快照等故障注入在可丢弃的验收副本中进行，不扰动活动工作区。副本的阻断测试不能替代实际目标的指令、skills 和配置加载确认。

**必需项目全部有实际 App 证据，才能报告“Codex App 接入完成”。** 手动执行检查器、手动读取文件或投递 hook payload 不能代替自动加载和阻断证据。未完成时应同时保留离线结果、App 缺项和具体接续步骤。

## 5. 开始功能开发

接入验收通过后，在该 feature 的任务中直接下达需求。例如：

```text
实现 SidebarService 的状态查询接口。
先确认当前 feature 和涉及仓分支，按项目指令读取对应流程 skill。
完成实现与离线测试，先不要部署设备。
```

开发流程通常是：

```text
检查分支 → 分析源码 → 读取对应 skill → 修改代码
→ 授权范围内的构建与测试 → feature 验证 → 报告证据
```

读取构建 skill 不代表立即执行其中全部命令。构建所需产品参数、部署范围及设备目标应明确后再执行。真实 ADB 操作显式设置 `ANDROID_SERIAL`，Cuttlefish 操作明确目标组。

提示提交时的 hook 检查不能覆盖同一轮任务中后续发生的分支变化。遵循目标 Harness 声明的事件覆盖范围，未覆盖的写操作前重新检查分支，不把这类检查当作始终有效的全程锁定。

## 6. 继续开发与切换 feature

| 情况 | 操作 |
| --- | --- |
| 同一 feature 继续开发 | 恢复原任务，由生命周期检查校验原快照 |
| 切换 feature | 准备新 feature 资料和相关仓分支，运行 `prepare-feature`，再新建 App 任务 |
| 快照缺失或损坏 | 排查状态目录与环境；按恢复提示准备并新建任务，不伪造旧快照 |
| 多个 feature 并行 | 使用分别准备的完整工作区；各树的会话状态隔离 |

不要仅修改 `CURRENT_FEATURE` 就认为真实 AOSP 各仓分支已切换。该文件在教学示例中用于离线选择；真实树按搭建时确认的锚点或显式选择策略处理。

不要在旧任务中切换 feature 后继续开发。同一源码树共享的根上下文链接、`out/`、设备和 CVD 组都可能相互影响；相关操作按项目约定串行。

## 7. 如何判断完成

把以下结论分别记录，不能互相替代：

| 层次 | 完成依据 |
| --- | --- |
| Harness 离线检查 | 目标脚本及配置的离线测试通过 |
| Codex App 接入 | 上下文、skills、恢复和自动阻断的实际验收通过 |
| Android 构建 | 本次构建退出码、成功标记及产物符合要求 |
| 功能与设备验收 | 所有必需断言通过，严格验证最终输出 `RESULT PASS` 且退出 0 |

`RESULT FAIL` 表示存在失败；`RESULT INCOMPLETE` 表示尚有必需检查未完成。探索模式允许跳过并返回 0，仍不能作为交付通过证据。

## 先体验教学演示

只想理解流程时，从本仓库根执行：

```bash
bash codex/run-demo.sh
bash tests/test-codex-app.sh
```

这两项是离线演示和协议测试，不启动真实 App 验收，也不构建 Android 或访问设备。演示包含故意的失败场景，应结合预期与最终回归结果判断。

## 相关说明

- [Codex 示例安装与实现说明](../codex/README.md)
- [build-aosp-harness skill](../skills/build-aosp-harness/SKILL.md)
- [App 搭建和验收契约](../skills/build-aosp-harness/references/codex-app.md)
- [Codex Harness 设计长文](AOSP整机源码Harness工程探索-codex版.md)
