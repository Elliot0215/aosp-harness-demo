---
name: build-sepolicy
description: 新增/修改系统服务的 SELinux 策略 —— 改 system/sepolicy 时用（service_contexts + .te 三件套）
---

<!-- DEMO —— ② 流程层示例 skill。物理源位于 features/.harness/skills/，
     经树根 .claude 软链暴露，由 feature 指令显式选择并读取。 -->

# build-sepolicy（② 流程：修改 sepolicy 前显式读取）

新增系统服务后**必须**同步 SELinux 策略，否则服务注册/被访问时 `avc: denied`，服务起不来。这是 CLAUDE.md 六条硬约束之一。

## 三件套

1. **声明服务类型**（`system/sepolicy/private/service_contexts` 或 vendor 对应文件）：

   ```text
   sidebar    u:object_r:sidebar_service:s0
   ```

2. **定义 type + 允许规则**（`.te`，如 `private/sidebar.te`）：

   ```text
   type sidebar_service, service_manager_type;
   allow system_server sidebar_service:service_manager { add find };
   ```

3. **允许客户端 find**（谁要用这个服务就给谁 `find` 权限）。

## 编译与验证

```bash
bash -c 'source build/envsetup.sh >/dev/null 2>&1 \
  && lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 \
  && m selinux_policy'
```

- 策略随整机镜像生效，改动一般走稳环（`m` 整机 → `cvd stop/start` 换新镜像）更稳。
- 起机后执行以下验证：`dmesg` 不应出现本服务相关的 denial，服务列表应包含 `sidebar`；收口到 `features/<分支>/verify-*.sh`。

```bash
device_serial="${ANDROID_SERIAL-}"
if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then
  echo 'error: set ANDROID_SERIAL to a safe, explicit target serial' >&2
  exit 2
fi
device_output="$(mktemp "${TMPDIR:-/tmp}/sidebar-device-check.XXXXXX")" || exit 1
trap 'unlink "$device_output"' EXIT
adb -s "$device_serial" shell dmesg >"$device_output" || exit $?
if grep -Fq 'avc: denied' "$device_output"; then
  echo 'error: SELinux denial detected' >&2
  exit 1
fi
adb -s "$device_serial" shell service list >"$device_output" || exit $?
grep -Fq sidebar "$device_output" || {
  echo 'error: sidebar service missing' >&2
  exit 1
}
trap - EXIT
unlink "$device_output"
```

## Execution scope and acceptance

Read this skill before the routed source change; reading it does not execute every command. Requirement clarification and planning do not start builds. Select build commands, deployment actions and acceptance checks separately according to the current authorized task. Calling intent-implement does not by itself authorize device deployment, restart or data cleanup. Use the confirmed device/CVD group and retain the existing device protections.

Read the active feature instructions and run its branch checker before source writes; repeat before later writes not covered by hooks. Record the affected repository subset, build target, artifacts, applicable checks and environment dependencies in the current requirement document. Serialize builds sharing one `out/`, and operations sharing a device or CVD group; the main agent owns shared planning documents.

Complete a requirement against its agreed acceptance and necessary regressions; independent review is required only when requested by the user or project rules. Keep other unfinished requirements visible without blocking an already accepted requirement. Whole-feature delivery requires all requirements plus the full `features/<feature>/verify-*.sh` acceptance: exact `RESULT PASS`, exit 0, no required SKIP. An exploration result `RESULT INCOMPLETE` with exit 0 is incomplete. Report planning, offline Harness checks, compilation, requirement delivery and device acceptance separately; investigate relevant failures instead of retroactively excluding checks. If required environment or review is unavailable, report partial results and the next concrete operation.
