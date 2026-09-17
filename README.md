# AOSP Harness Demo

本仓库保留两个独立的 AOSP Harness 教学示例，分别演示 Claude Code 和 Codex 的上下文选择、流程 skills 与验证闭环。

| 示例 | 内容 | 说明 |
| --- | --- | --- |
| [claude-code/](claude-code/) | Claude Code wrapper、hooks、skills 与 feature 示例 | [使用说明](claude-code/README.md) |
| [codex/](codex/) | Codex instructions、wrapper、hooks、skills 与 feature 示例 | [使用说明](codex/README.md) |

两个示例均可单独复制和运行。离线演示需要 Bash、Git、Python 3.8+、ripgrep 和常见 Unix 工具，无需 AOSP 源码、Android 设备或客户端 CLI。

## 运行示例

从仓库根目录运行：

```bash
bash claude-code/run-demo.sh
bash codex/run-demo.sh
```

演示包含刻意制造的分支漂移与验证失败，用于展示拦截行为；各入口最后执行自身回归测试。

## 离线检查

```bash
bash scripts/check.sh --offline
```

该入口检查 shell 语法、两个示例的回归、设备目标保护和文档。CI 使用 `bash scripts/check.sh --ci`，另外运行 ShellCheck、shfmt 与 gitleaks。

真实构建与设备部署请按各示例内的 build skills 配置 AOSP 环境，并显式设置 `ANDROID_SERIAL`。只有严格验证返回 `RESULT PASS` 且退出码为 0 才能作为通过证据；离线 Demo 不代表真机验证完成。

真实源码树搭建中发现的部署、回滚及跨客户端审查问题见 [实战反馈](docs/AOSP-Harness实战反馈.md)。两端直接 push 示例不具备生产部署事务能力；适配真机工具前阅读 [部署事务与故障注入](skills/build-aosp-harness/references/deployment-transactions.md)。

## 搭建新 Harness 的 Skill

[`build-aosp-harness`](skills/build-aosp-harness/SKILL.md) 指导 agent 根据开发需求搭建或扩展 Harness：推导涉及仓与验收条件，配置 Codex / Claude Code 入口，补齐构建流程，并运行离线验证。可复用本仓库示例，也可独立指导目标源码树的搭建。

将 `skills/build-aosp-harness/` 安装到客户端的 skill 目录后，可这样提出需求：

```text
使用 $build-aosp-harness，为 /path/to/aosp 中的 dev-example 功能搭建 Codex Harness。
需求：给现有系统服务增加一个可关闭的调试入口，仅 userdebug 可用。
本次搭建 Harness 和离线验证，使用项目已有构建流程。
```

## 设计文档

- [Claude Code 版](docs/AOSP整机源码Harness工程探索-claude版.md)
- [Codex 版](docs/AOSP整机源码Harness工程探索-codex版.md)
