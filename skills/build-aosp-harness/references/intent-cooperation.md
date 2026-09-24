# intent 与 AOSP Harness 协作规范

本文件是 AOSP Harness 对 intent 的唯一适配规范。intent 保持通用技能与文档规则；Harness 负责 feature 选择、源码仓范围、分支检查、构建入口和整体验收。搭建时将适用约束写入当前 feature 指令；业务项目不需要额外的交换文件、状态机、hook 或调度运行时。

## 启动与调用

先独立安装所用客户端的 intent skills，并确认技能可见。已有 Harness 先通过 CLI wrapper，或 GUI/Desktop 的 `prepare-feature`，准备目标 feature；随后从 AOSP 源码树根新建会话。尚无 Harness 时，可先用 intent 澄清需求，再显式调用 `build-aosp-harness` 引用原文档搭建。技能调用不自动安装另一套技能，也不自动进入下一阶段。

intent 阶段由用户显式选择：多项交付用 `intent-roadmap`，单项需求规划用 `intent-plan`，实现用 `intent-implement`，需要审查时用 `intent-review`。Codex 与 ZCode 分别调用 `$intent-roadmap`、`$intent-plan`、`$intent-implement`、`$intent-review`；Claude Code 与 Cursor Agent 使用对应的 `/intent-roadmap`、`/intent-plan`、`/intent-implement`、`/intent-review`。调用前确认当前客户端已安装相应技能；可用具体需求 Markdown 路径明确本次目标。

feature 与已加载上下文不符，或涉及仓分支漂移时，停止依赖旧上下文修改源码。通过该客户端现有 wrapper 或 `prepare-feature` 重新准备，并从树根新建会话；不自行切分支，也不在旧会话内热换指令。hook 未覆盖同轮后续写操作时，写入前重新运行分支检查。

## 文档交接与修改范围

文档位置依次服从用户明确指定、已有位置、项目指令和 intent 默认位置。本 Harness 的新项目约定为 `features/<feature>/.intent/`：多需求目标使用 `roadmap.md`，展开的需求使用固定编号的 `001-需求名称.md` 等普通 Markdown，实际审查按轮次写入 `review/001-需求名称-1.md` 等文件。已有资料原位续用，不搬迁、不预建空文件；feature 指令只保留目标摘要和文档入口，进展与证据更新到需求主文档及已有路线图。

每个需求记录目标与验收、当前 feature、涉及的仓与路径及理由、适用的构建和验证入口、环境依赖与共享资源，以及执行后的实际证据和剩余事项。规划文件可由主 agent 在当前 feature 的约定位置更新；这不扩大业务源码的可修改范围。`repos.tsv` 及其分支检查器仍是源码仓范围和预期分支的事实来源，小需求只列本次涉及的子集。AOSP 树根可能不是 Git 仓，逐一识别各 Git project 根与规划目录。

## 实施与验收

修改源码前运行当前 feature 的分支检查，并读取实际存在且对应改动的构建 skill；读取 skill 不等于执行其中全部命令。澄清和规划不启动构建；构建、部署、重启、数据清理和验收依当前任务授权及环境分别执行。独立审查仅在用户要求或项目规则要求时成为完成条件；若要求独立审查，由非作者审查相关仓中的已提交、未提交及未跟踪实现，并说明基线和未覆盖范围。

如派发局部源码任务，任务卡给出源码根、feature、允许仓与路径、约束、验证和共享资源；主 agent 维护共享规划文档。独立源码任务可以并行，同一 `out/` 构建及同一设备或 CVD 组操作串行。

单个需求满足事先约定的自身验收与必要回归即可交付，其他需求未完成时保留整个 feature 的未完成状态。feature 交付还要求全部需求完成，严格运行整体验证，最终行精确为 `RESULT PASS` 且退出码为 0。失败检查须调查，不能事后改成不适用；`--demo --allow-skip` 输出的 `RESULT INCOMPLETE` 即使退出码为 0 也未完成。

分别报告规划、离线 Harness 检查、编译、单项需求交付和 feature 真机验收。环境、设备证据或已要求的审查缺失时，说明已完成部分及下一步，不把离线或编译结果当作真机验收。
