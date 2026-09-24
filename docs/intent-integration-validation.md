# intent 联动历史验证记录（2026-09-21）

本页记录当时版本的实验结果，不代表当前 intent 技能语义或当前仓库的测试结果。intent 在 2026-09-23 精简后，下面提到的 `tests/test_harness_integration.py`、审查报告和“全自动”模式均已不在当前 intent 工作树中；当前使用规则以 [协作规范](../skills/build-aosp-harness/references/intent-cooperation.md) 为准，不能沿用本页的历史通过结论。

本次修改覆盖四端 feature 上下文、八个构建 skill、搭建技能及协作参考、四端 SKIP 结果和相关文档/测试。基于当前工作区修改，保留原有未提交的 Codex App 与 ZCode 等工作；没有修改 wrapper、hooks 或安装器，没有向活动用户目录安装、提交或发布。

## 已执行

- `bash scripts/check.sh --offline`：第一轮独立审查修正后的完整离线回归重跑通过，最终 `RESULT PASS  aosp-harness offline quality gate`。包括四端安装/上下文/分支与验证回归、App/Desktop 离线 fixtures、设备保护、命令失败传播、文档与质量入口测试。
- 四端 `--demo --allow-skip` 存在 SKIP 时仍退出 0，但最终结果改为 `RESULT INCOMPLETE`；默认严格模式返回非零。新增共同故障注入覆盖同时 FAIL/SKIP 时保持 FAIL 非零。
- `bash scripts/check-docs.sh`、`bash tests/test-docs.sh`、`git diff --check` 通过。
- 搭建 skill 和四端共八个构建 skill 原件通过 skill-creator 通用结构校验。
- 本机 ShellCheck 0.9.0 对四个改动验证脚本与共享设备保护测试检查通过。这不是规定版本的完整 CI 结果。
- 相邻 intent 工作区新增 `tests/test_harness_integration.py`，用本仓实际四端安装器、检查器与验证器在临时多仓树运行。3 项集成测试（每项含四端）通过：安装/升级保护项目文件和用户 hooks、非锚点仓漂移失败、分层及 SKIP/FAIL 结果。没有让本仓独立使用依赖 intent 安装。
- intent 的四个隔离原生 subagent 样本观察到：新规划写入 feature 内、已有规划文档原位续用；两仓小需求测试通过但整个 feature 未完成；reviewer 不可用时不报全自动完成；feature 错配或分支漂移时停止修改。样本使用合成 Python 项目，不是 Android。

第一次完整回归因旧精确文档章节预期及隐藏旧 SKIP 断言失败；调整新增说明为现有章节中的小节，并更新真实输出断言后通过。独立审查又发现 ZCode intent 前缀和 Claude paths 当前说明不一致，已修复；随后的完整重跑还发现 Codex README 对旧 paths 句子的精确断言，更新对应断言后，整套离线回归再次通过。第二轮随后发现并修正 Claude README 三层表中的同类 paths 残留；该次只改文档，重跑 check-docs.sh、test-docs.sh 和 diff 检查均通过。

## 未执行与限制

- 完整 `--ci` 未运行：本机 ShellCheck 为 0.9.0，要求 0.11.0；shfmt 3.14.0、gitleaks 8.30.1 不可用。
- 未启动 Codex、Claude Code、Cursor Agent、ZCode 的真实会话，未验证 Codex App/ZCode Desktop 的实际 hooks 事件、信任流程与恢复阻断界面。现有 App/Desktop 测试均为离线 fixtures。
- 未运行 Android 编译、部署、重启、真实设备断言；demo PASS 不代表真机 PASS。
- 未取得行为样本的完整原始工具事件流，控制器仅对产物、分支和本地测试作独立核对，不能据此声称所有工具顺序已验证。

协作约定见 [intent-cooperation.md](../skills/build-aosp-harness/references/intent-cooperation.md)。真实客户端与设备验收需在目标环境分别补充记录。

第二轮由新的独立原生 reviewer 对照双仓修改前快照复查整组最新实现和验证记录，核实上述最后修正后未发现未解决的具体缺陷。其独立重跑 3 项四端联动测试及定向文档检查通过；审查报告保存在 intent 仓 `review/intent-harness-代码-2026-09-21-2.md`，不将审查结论当作真实客户端或设备验收。
