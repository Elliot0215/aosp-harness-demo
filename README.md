# AOSP Harness Demo

本仓库保留四套独立的 AOSP Harness 教学示例，分别演示 Claude Code、Codex、Cursor Agent 和 ZCode 的上下文选择、流程 skills 与验证闭环。Cursor 与 ZCode 示例是独立适配器，不是把 Codex 或 Claude 配置改名。

| 示例 | 内容 | 说明 |
| --- | --- | --- |
| [claude-code/](claude-code/) | Claude Code wrapper、hooks、skills 与 feature 示例 | [使用说明](claude-code/README.md) |
| [codex/](codex/) | Codex instructions、wrapper、hooks、skills 与 feature 示例 | [使用说明](codex/README.md) |
| [cursor-agent/](cursor-agent/) | Cursor Agent wrapper、hooks、skills 与 feature 示例 | [使用说明](cursor-agent/README.md) |
| [zcode/](zcode/) | ZCode prepare 入口、config.json hooks、skills 与 feature 示例 | [使用说明](zcode/README.md) |

四套示例均可单独复制和运行。离线演示需要 Bash、Git、Python 3.8+、ripgrep 和常见 Unix 工具，无需 AOSP 源码、Android 设备或客户端 CLI。

## 运行示例

从仓库根目录运行：

```bash
bash claude-code/run-demo.sh
bash codex/run-demo.sh
bash cursor-agent/run-demo.sh
bash zcode/run-demo.sh
```

演示包含刻意制造的分支漂移与验证失败，用于展示拦截行为；各入口最后执行自身回归测试。

## 离线检查

```bash
bash scripts/check.sh --offline
```

该入口检查 shell 语法、四套示例的回归、设备目标保护和文档。CI 使用 `bash scripts/check.sh --ci`，另外运行 ShellCheck、shfmt 与 gitleaks。

真实构建与设备部署请按各示例内的 build skills 配置 AOSP 环境，并显式设置 `ANDROID_SERIAL`。只有严格验证返回 `RESULT PASS` 且退出码为 0 才能作为通过证据；离线 Demo 不代表真机验证完成。

真实源码树搭建中发现的部署、回滚及跨客户端审查问题见 [实战反馈](docs/AOSP-Harness实战反馈.md)。直接 push 示例不具备生产部署事务能力；适配真机工具前阅读 [部署事务与故障注入](skills/build-aosp-harness/references/deployment-transactions.md)。

从搭建到 App 开发的完整操作流程见 [Codex App 使用指南](docs/AOSP-Codex-App使用指南.md)。

## 搭建新 Harness 的 Skill

[`build-aosp-harness`](skills/build-aosp-harness/SKILL.md) 指导 agent 根据开发需求搭建或扩展 Harness：推导涉及仓与验收条件，配置 Codex / Claude Code / Cursor Agent / ZCode 入口，补齐构建流程，并运行离线验证。可复用本仓库示例，也可独立指导目标源码树的搭建。

将 `skills/build-aosp-harness/` 安装到客户端的 skill 目录后，可这样提出需求：

```text
使用 $build-aosp-harness，为 /path/to/aosp 中的 dev-example 功能搭建 Cursor Agent Harness。
需求：给现有系统服务增加一个可关闭的调试入口，仅 userdebug 可用。
本次搭建 Harness 和离线验证，使用项目已有构建流程。
```

## 与 intent 配合

四端 feature 指令已声明协作约定：intent 维护规划与小需求，Harness 提供 feature 选择、多仓范围、分支检查、构建和整体验证入口。新规划使用 `features/<feature>/.intent/roadmap.md`、固定编号的需求 Markdown、实际审查的逐轮 `review/` 记录；用户指定和已有位置优先，不自动搬迁。

已有 Harness 先准备 feature 并从源码树根新建会话，再显式调用已安装的 intent skill；新树可先明确需求，再显式调用 `build-aosp-harness` 引用原文档搭建。Codex 和 ZCode 使用 `$intent-roadmap` / `$intent-plan` / `$intent-implement` / `$intent-review`，Claude Code、Cursor Agent 使用对应的 `/` 前缀。不会自动安装 intent 或进入其他阶段。

小需求按自身验收和必要回归完成；独立审查仅在用户要求或项目规则要求时成为完成条件。整个 feature 要求全部小需求及严格整体验证通过。规划不启动构建，构建成功不代替设备验收；共享 `out/`、设备和 CVD 组串行操作。`--demo --allow-skip` 有跳过时输出 `RESULT INCOMPLETE`、退出 0，不能作为验收通过。详见 [协作规范](skills/build-aosp-harness/references/intent-cooperation.md)。

## 设计文档

- [Claude Code 版](docs/AOSP整机源码Harness工程探索-claude版.md)
- [Codex 版](docs/AOSP整机源码Harness工程探索-codex版.md)
- [Cursor Agent 版](docs/AOSP整机源码Harness工程探索-cursor-agent版.md)
- [ZCode 版](docs/AOSP整机源码Harness工程探索-zcode版.md)
- [ZCode 使用指南：从搭建到日常使用](docs/AOSP-Harness使用指南-zcode.md)

Codex App（GUI）接入与验收步骤见 [Codex 示例说明](codex/README.md#codex-appgui接入)。先执行 `prepare-feature`，再以准备后的源码树根新建 App 任务。ZCode App 接入同理由 [ZCode 示例说明](zcode/README.md#zcode-desktopapp接入)的 `prepare-feature` 准备流程开始。Cursor 桌面 IDE 先运行 [Cursor 示例](cursor-agent/README.md#cursor-桌面-ideapp接入) 的 `prepare-feature`，信任工作区后再新建 Agent 对话。

2026-09-21 的命令结果、独立审查修正及未实测范围见 [历史联动验证记录](docs/intent-integration-validation.md)；其中依赖的 intent 集成测试在后续精简中已移除。
