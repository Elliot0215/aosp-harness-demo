<!-- 本文件是 dev-sidebar 的完整 feature 上下文。树根 AGENTS.md 由
     .codex/bin/codex-feature 在 Codex 启动前切换为指向本文件的相对软链。 -->

# AOSP 树与 dev-sidebar feature 上下文

## 树级构建约束

- `envsetup.sh` 必须在 bash 中 `source`，不要依赖调用者的默认 shell；`source` 后不要直接接管道，避免函数落入子 shell。
- 长时间构建必须在后台执行并把输出写入日志；轮询日志，只有出现 `build completed successfully` 成功标记才算构建完成。
- 不得手工编辑 `out/` 下的生成物，所有产物都必须由构建系统生成。
- 修改 public/System API 后必须运行 `m update-api`，否则 checkapi 会阻断构建。
- 新增系统服务必须同时补齐 `system/sepolicy` 中的 service context、类型和 allow 规则。
- push `framework.jar` 或 `services.jar` 后要评估 ART 缓存风险；校验不一致时，旧 dexpreopt/boot image 或 `/data/dalvik-cache/` 可能导致启动缓慢或失败。

## 源码导航

- 使用 `rg` 配合源码阅读定位模块、符号和调用链。
- 先按仓库和路径缩小范围，再搜索 JNI 注册名、全限定 `Class::method` 等高信息量锚点，避免用 `onTransact` 一类泛词扫全树。
- 这里没有建立完整索引，也不得把搜索结果描述成索引结论；影响面判断必须给出源码路径、关键符号和仍未确认的边界。

## 子代理任务卡

派发子代理时只提供完成局部任务所需的任务卡，不广播整份 feature 上下文。任务卡必须包含：

- 目标：要交付或回答的具体问题；
- 路径：允许读取或修改的仓库和目录；
- 事实：会改变结论的版本、ABI、JNI 或生成代码信息；
- 约束：禁止目录、只读要求、构建和部署限制；
- 证据：期望返回的源码位置、命令结果、验证结论和未确认项。

## feature: dev-sidebar

目标是在 AOSP 17 中新增系统服务、native 合成侧和常驻边栏应用。

允许修改的仓库只有：`frameworks/base`、`frameworks/native`、`packages/apps/SidebarApp`、`build/make`、`system/sepolicy`。机器可读清单位于 `features/dev-sidebar/repos.tsv`；开始工作前用 `./features/dev-sidebar/check-branch.sh` 检查所有涉及仓是否位于 `dev-sidebar` 分支。

### 必须遵循的流程路由

- 修改 `frameworks/base/services/**` 前必须显式读取并按当前任务使用 `$build-services-jar`。
- 修改 `system/sepolicy/**` 前必须显式读取并按当前任务使用 `$build-sepolicy`。
- 整个 feature 交付前运行 `./features/dev-sidebar/verify-sidebar.sh`；完成条件按下方两层验收判定。

### frameworks/base

新增 `SidebarService` 和 `ISidebar.aidl`，并在 `SystemServer` 注册 `sidebar` 服务。AIDL 进入 public/System API 时必须运行 `m update-api`；服务实现和 `SystemServer` 变更遵循 `$build-services-jar`。

### frameworks/native

新增 SidebarFlinger native 合成实现并接入合成服务启动链。使用唯一类名、全限定 C++ 方法和注册点导航；若触及缩放态触摸坐标映射，先明确 input 链路影响面。

### packages/apps/SidebarApp

常驻边栏应用通过 `ISidebar` 与系统服务通信。修改前确认平台签名、privapp 权限、产品安装位置及应用进程存活策略。

### build/make

仅接入 dev-sidebar 所需模块和产品配置。不要直接修改 `out/` 里的产品文件来模拟构建结果。

### system/sepolicy

为 `sidebar` 服务补齐 `service_contexts`、service type、域访问与必要 allow 规则。策略修改遵循 `$build-sepolicy`，验证时检查新的 AVC denial。

### 与 intent 协作及完成条件

- 从源码树根工作，分别识别各 Git project 根和规划目录；不要用树根的一次 `git status` 代表所有涉及仓。`repos.tsv` 与现有检查器是源码仓范围及分支的事实来源，小需求只记录本次涉及的子集和理由。
- intent 文档位置依次采用：用户明确指定 → 已有文档位置 → 本 feature 的 `features/dev-sidebar/.intent/` → intent 默认位置。新路线图为 `features/dev-sidebar/.intent/roadmap.md`，展开需求使用固定编号的 `001-需求名称.md` 等 Markdown，实际审查按轮次写入 `features/dev-sidebar/.intent/review/001-需求名称-1.md` 等文件；已有资料原位续用，不搬迁或预建空文件。
- 每份小需求记录当前 feature、目标与验收、涉及仓子集和路径及理由、构建与验证入口、环境依赖、实际证据和剩余事项；不另建状态文件。主 agent 可更新当前 feature 的上述规划和审查资料，包括明确指定或已有的规划位置；这不扩大业务源码可修改范围。上下文只维护目标摘要、执行约束与文档入口，详细任务和进展维护在原文档中。
- 每次修改相关源码前读取对应流程 skill，并运行 `./features/dev-sidebar/check-branch.sh`；同轮后续写操作未被 hook 覆盖时重新检查。若需求文档的 feature 与已加载上下文不同，停止依赖旧上下文的写入，按下述启动入口重新准备并新建会话，不自行切换分支或热换上下文。
- worker 任务卡包含源码根、feature、允许修改的仓及路径、相关约束、验收命令和共享资源。由主 agent 维护共享需求文档；同一 `out/` 的构建、同一设备或 CVD 组的操作串行执行。审查逐仓确定基线，包含相关已提交、未提交及未跟踪实现；基线不可靠时检查明确模块并披露限制。
- 小需求按事先明确的自身验收和必要回归判断交付；独立审查仅在用户要求或项目规则要求时成为完成条件。缺少已要求的审查、构建环境或必要设备证据时如实报告部分完成。
- 整个 feature 交付须全部需求完成，并运行 `./features/dev-sidebar/verify-sidebar.sh`，最终精确输出 `RESULT PASS` 且退出 0。其他小需求尚未实现不能阻止已满足自身验收的前项交付，但必须保留 feature 未完成状态。不能事后把失败检查改为“不适用”；相关失败须调查。
- 规划完成、离线 Harness 可用、编译通过、小需求交付和 feature 真机验收分别报告。`RESULT INCOMPLETE` 即使在 `--demo --allow-skip` 下退出 0，也不是验收通过。
- 需求澄清、设计和任务规划不触发构建；读取流程只提供当前任务的方法，构建、部署及验收按已授权范围分别执行。调用 `intent-implement` 不扩大设备操作授权，也不自动启动另一 intent 阶段或安装 skills。

- 恢复入口：`.codex/bin/codex-feature`；GUI 用 `.codex/bin/prepare-feature` 后从源码树根新建任务。
- intent 已独立安装且用户明确选择后，可显式调用 `$intent-roadmap 为 dev-sidebar 规划路线图`；单项规划用 `$intent-plan features/dev-sidebar/.intent/001-需求名称.md`，实现用 `$intent-implement features/dev-sidebar/.intent/001-需求名称.md`，需要审查时用 `$intent-review features/dev-sidebar/.intent/001-需求名称.md`。当前没有实际规划文档时，不把这些示例路径报告为已创建。
