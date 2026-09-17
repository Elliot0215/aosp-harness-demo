# AOSP Harness 实战反馈（2026-09-09）

来源：tOS16.3 X6891 真实源码树的 Harness 搭建与跨客户端审查。复现与修复验证使用离线 fake ADB，未编译 Android、未部署或操作手机；不包含游戏触控收益结论。

## 已确认的问题与反馈落点

| 实战问题 | 本仓优化 |
| --- | --- |
| TSV 空列移位、远端查询错误被当成不存在 | 部署参考要求精确解析、完整预检与三态查询 |
| 半写入备份被信任、回滚误用新权限 | 部署参考规定 staging 校验、不可变备份及原元数据恢复 |
| restorecon 失败被忽略、清缓存失败提前提交 | 部署参考补提交边界及 rollback-failed 语义 |
| reboot 返回失败仍等待、旧 boot_completed 误报、ADB 卡住越过超时 | 部署参考要求新 boot_id、命令返回码与共享截止时间 |
| 独立入口漏参数检查 | 要求校验器共用；本仓 Codex services 示例补非法序列号预检，两端实际命令块新增零 ADB 调用断言 |
| Cursor 在只读审查时无法写私有状态目录 | 验证参考补跨客户端最小读任务、私有状态隔离与分层诊断 |
| mock 在整个 shell 命令前失败，未复现声称的失败阶段 | 验证参考要求在真实命令边界注入，并核验最终文件状态 |

Cursor 问题的实现修复属于独立的 any-subagent 项目：项目 trust 参数及私有 chats/sandbox-policies 目录处理，不应通过放宽 AOSP 源码写权限来解决。本仓仅记录可复用诊断方法，不绑定客户端内部目录的长期实现。

## 使用与证据边界

- 新建真实部署工具时读取 [部署事务参考](../skills/build-aosp-harness/references/deployment-transactions.md)，按故障矩阵实现自己的工具与测试。
- [适配说明](../skills/build-aosp-harness/references/adapt-examples.md) 明确两端直接 push 示例不具备事务能力，不能照搬成生产入口。
- [验证说明](../skills/build-aosp-harness/references/validation.md) 区分 mock、真实客户端集成与设备证据。
- 来源树修复后离线回归为 8/8 组，其中设备工具 107 项断言通过；这些不是本仓测试数量。本仓回归运行 `bash scripts/check.sh --offline`，新增实际行为覆盖见 [测试清单](../tests/COVERAGE.md)。

本次没有复制产品专用部署脚本、设备参数、旧 lunch 或实验结论；参考仓的教学布局保持不变。
