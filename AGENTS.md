# Repository Guidelines

## 项目结构与模块组织

本仓库包含四套独立的 AOSP Harness 教学示例，源码目录仅提供占位文件：

- `claude-code/`、`codex/`、`cursor-agent/` 和 `zcode/`：各客户端的启动封装、hooks、skills 和可运行示例。修改各自 `features/.harness/` 下的实际源文件，保留安装生成的符号链接。Cursor 与 ZCode 示例是独立适配器，不要把 `.codex` 改名为 `.cursor`，也不要复用 Codex 的 `hooks.json` 结构充当 ZCode 的 `.zcode/config.json`。
- 各示例的 `features/dev-sidebar/`：功能说明、`repos.tsv`、分支检查和验证脚本；`CURRENT_FEATURE` 指定当前功能。
- 各示例的 `frameworks/base/` 和 `frameworks/native/`：占位源码。
- `tests/`：仓库级回归测试；客户端回归测试位于 `codex/tests/`、`cursor-agent/tests/`、`zcode/tests/` 和 `claude-code/features/.harness/tests/`。
- `scripts/`：质量检查入口；`docs/`：设计文档。

## 构建、测试与开发命令

以下命令均从仓库根目录运行。离线开发需要 Bash、Git、Python 3.8+、ripgrep 和常见 Unix 工具。

- `bash claude-code/run-demo.sh`：演示 Claude Code 上下文选择与验证流程，并运行回归测试。
- `bash codex/run-demo.sh`：安装 Codex 入口、演示工作流并运行回归测试。
- `bash cursor-agent/run-demo.sh`：安装 Cursor Agent 入口、演示工作流并运行回归测试。
- `bash zcode/run-demo.sh`：安装 ZCode 入口、演示工作流并运行回归测试。
- `bash scripts/check.sh --offline`：检查 shell 语法、回归测试、设备保护和文档。
- `bash scripts/check.sh --ci`：额外运行固定版本的 ShellCheck 0.11.0、shfmt 3.14.0 和 gitleaks 8.30.1。
- `bash scripts/check-docs.sh`：检查文档入口。

真实 Android 构建需要单独配置 AOSP 环境，并遵循对应构建 skill 的说明。

## 编码风格与命名约定

使用 Bash 编写执行流程，使用 Python 编写结构化断言。遵循相邻代码风格；新增 shell 代码采用两空格缩进，以 `shfmt -i 2 -ci -bn` 格式化，以 `shellcheck -x --severity=warning` 检查。路径变量展开时加引号，保留脚本可执行权限。脚本使用含义明确、以连字符分隔的名称，回归脚本命名为 `test-*.sh`。功能目录名应与 `repos.tsv` 中的预期分支一致。

## 测试要求

测试使用 shell 测试脚本、Python 断言、临时测试目录和模拟工具。覆盖成功、失败与清理行为，避免依赖设备或客户端认证。仓库级测试覆盖范围变化时更新 `tests/COVERAGE.md`；目前未设置覆盖率百分比门槛。明确报告失败检查。演示中的失败可能是预设场景；严格验证必须输出 `RESULT PASS`，且退出码为 0。

## 提交与 Pull Request 规范

历史提交使用动词开头的简短标题，部分带有 `docs:`、`refactor:` 等前缀；沿用这一风格，每次提交聚焦一个主题。PR 描述应说明行为变化、受影响的示例、验证命令及结果，以及已知限制；存在相关问题单时附上链接。

## 安全与配置

不要提交凭据和生成产物。操作真实设备时显式设置 `ANDROID_SERIAL`。保留安装器拒绝覆盖已有文件的保护逻辑，并区分离线测试证据与真机验证结果。
