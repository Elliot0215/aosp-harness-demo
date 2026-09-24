<!-- DEMO · 启动前同步 + 单文件 —— 这是《AOSP 整机源码 Harness 工程探索》的 feature 上下文示例。
     真实环境里 <AOSP_ROOT>/.claude 指向 features/.harness，<AOSP_ROOT>/CLAUDE.md 指向本文件；
     .claude/bin/claude-feature 在 Claude 启动前选定 feature 上下文。
     整个 feature 的上下文都在这一个文件里：树级 bootstrap/硬约束 + feature 总览 + 各仓约定。
     SessionStart 只做幂等检查和恢复告警，不承担首次加载顺序保证。 -->

# 树根 CLAUDE.md（① 上下文层 · 启动前同步）

本文件 = 树级固定内容 + 当前 feature 上下文。换 feature 后使用 `.claude/bin/claude-feature` 启动，让 wrapper 在 Claude 读取项目 memory 前把根软链切到 `features/<分支>/CLAUDE.md`。

## 编译（agent 默认会做错的地方）

- envsetup 必须用 **bash**（工具默认 shell 可能是 zsh），且 **source 后不能接 pipe**（函数会进子 shell）：

```bash
bash -c 'source build/envsetup.sh >/dev/null 2>&1 \
  && lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 \
  && m services' > /tmp/build.log 2>&1 &   # 后台 + 日志轮询，看到 build completed successfully 才算完
```

- **一切编译必须后台跑 + 轮询日志**：前台命令有超时上限，单编模块十几分钟起步。
- lunch 目标是三段式 `product-release-variant`，release 段如 `trunk_staging`（可从 `out/soong.log` 的 `TARGET_RELEASE=` 反查）。

## 硬约束（主代理和会修改代码的代理必须遵守）

| 硬约束 | 防的是什么 |
|---|---|
| 不向任何 gerrit project 提交 harness/上下文文件（CLAUDE.md/.claude/features/ 等） | 知识污染上游 |
| 不配任何 LSP（clangd/jdtls/Eclipse/aidegen）、禁生成 Eclipse 工程文件、禁建 compdb | 吃内存 + 写坏树（Eclipse 残留的 .aconfig 被 soong glob 到会构建失败）；索引在整机树规模下建不完，会给出不完整却不自知的引用结果 |
| 改 public/System API 后必须 `m update-api` | 否则 checkapi 挂构建 |
| 新增系统服务必须同步 `system/sepolicy`（service_contexts + .te） | 否则服务起不来（avc denied） |
| push framework.jar/services.jar 后注意 ART 缓存 | dexpreopt/boot image 校验不一致拖慢甚至起不来，诡异时清 `/data/dalvik-cache/` |
| 不手改 `out/` 下任何生成物 | 破坏增量构建 |

## 代码导航

- 全语言统一：`rg` + 源码阅读定位模块、符号和调用链，不准备任何索引（见硬约束：本树不配 LSP）。
- 整机树同名符号成海（`onTransact` 之流全树数百命中）。习惯：**先用路径收窄范围，再用高信息量锚点代替泛词**——跨 Java↔JNI↔native 用 JNI 注册名（如 `android_view_*`），C++ 用 `Class::method` 全限定名，二者在全树近乎唯一。
- 判断"改这个会影响谁"时，宁可要 `rg` 吵闹但完整的结果，也不要一个看起来干净、实则漏掉大半的答案。

## 子代理派发

只读 Explore/Plan 不注入整份 feature 上下文。派发时只给一张局部任务卡：

- 目标：要回答的具体问题；
- 范围：允许搜索的仓和目录；
- 关键事实：会改变结论的版本、ABI/JNI 或生成代码事实；
- 约束：只读、禁止目录或禁止动作；
- 输出：源码路径、关键函数、证据和未确认项。

只有承担代码修改、构建或部署的代理才需要相关硬约束。内建 Explore/Plan 会跳过 CLAUDE.md，因此关键范围必须写进派发 prompt。

---

# feature: dev-sidebar

**目标**：在 AOSP 17 上新增一个系统服务 + 一个常驻边栏应用。

**涉及仓**（本 feature 只动这些，清单外默认不动）：`frameworks/base`、`frameworks/native`、`packages/apps/SidebarApp`、`build/make`、`system/sepolicy`。机器可读单一事实源是本目录 `repos.tsv`（分支一致性检查读取它）。各仓 feature 约定见下方 `## 涉及仓约定`。

**一致性检查**：`./features/dev-sidebar/check-branch.sh`（涉及仓是否都在 dev-sidebar 分支）。
**验证入口**：`./features/dev-sidebar/verify-sidebar.sh`。crash 检查默认从设备启动时间（`/proc/stat` 的 `btime`）开始；部署前已有历史 crash 时，用 `--since <epoch-seconds>` 显式指定本次部署基线。crash buffer 查询失败直接判 FAIL，不能当成空结果。默认只要有 SKIP 就返回 `RESULT INCOMPLETE`；探索期必须显式加 `--allow-skip`。`--demo` 为无设备演示。

## 涉及仓约定

### frameworks/base

本 feature 在此仓：新增 `services/core/java/com/android/server/sidebar/SidebarService.java`（系统服务，暴露 `ISidebar` AIDL 接口）；`SystemServer.java` 里注册（`ServiceManager.addService("sidebar", ...)`）；新增 `core/java/android/sidebar/ISidebar.aidl`（public/System API 面）。

- **改了 public/System API**（新增 `android.sidebar` 包 + AIDL）→ 必须 `m update-api`，否则 checkapi 挂构建。
- **新增系统服务** → 必须同步 `system/sepolicy`（修改前显式读取 `.claude/skills/build-sepolicy/SKILL.md`，或使用 `/build-sepolicy`）。
- 编译/push/验证通用流程见 skill **`build-services-jar`**（修改前显式读取 `.claude/skills/build-services-jar/SKILL.md`，或使用 `/build-services-jar`）：单编 `m services`、产物 `services.jar`、push 清单、ART 缓存坑。

### frameworks/native

本 feature 在此仓：新增 `services/sidebarflinger/SidebarFlinger.cpp`（native 合成侧，把边栏窗口的缩放态合成到屏幕）；注册进 SurfaceFlinger 的服务启动链。

- 纯 native（C++）：导航用 `rg`；`SidebarFlinger` 这类新符号是独特锚点，直接搜即可。
- 窗口缩放态下的 touch 事件映射若要动，属 input 链路，谨慎评估再改。
- 本示例没有 native 构建 skill。修改前从目标源码的模块和现有构建入口确定构建、产物与验收方法，记录在小需求中；不能调用不存在的 native skill。

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

- 恢复入口：`.claude/bin/claude-feature`。
- intent 已独立安装且用户明确选择后，可显式调用 `/intent-roadmap 为 dev-sidebar 规划路线图`；单项规划用 `/intent-plan features/dev-sidebar/.intent/001-需求名称.md`，实现用 `/intent-implement features/dev-sidebar/.intent/001-需求名称.md`，需要审查时用 `/intent-review features/dev-sidebar/.intent/001-需求名称.md`。当前没有实际规划文档时，不把这些示例路径报告为已创建。
