---
name: build-sepolicy
description: Build and verify AOSP SELinux policy after changes under system/sepolicy, especially new system services requiring service_contexts, service types, allow rules, denial checks, and full feature verification.
---

# Build SELinux policy

Select this repository skill explicitly as `/build-sepolicy` when an `AGENTS.md` route requires it. ZCode may also select it implicitly when the frontmatter description matches the task. File paths alone do not select skills.

## Define a system service

Map the service name in `system/sepolicy/private/service_contexts` or the appropriate product or vendor file:

```text
sidebar    u:object_r:sidebar_service:s0
```

Tag a service registered by SystemServer with the canonical attributes, and grant a concrete client only lookup access:

```te
type sidebar_service, system_server_service, service_manager_type;
allow sidebar_app sidebar_service:service_manager find;
```

The system_server_service attribute is consumed by add_service(system_server, system_server_service). AOSP's `add_service` macro grants SystemServer `{ add find }` and adds a neverallow guarding registration from other domains, so do not add a raw per-service SystemServer allow.

## Build in one retained session

Submit this entire block as one shell invocation. ZCode must keep polling the same exec session until it exits; starting the build in one session and waiting in another loses the child status.

```bash
bash -c '
set -u
build_log="$(mktemp "${TMPDIR:-/tmp}/build-sepolicy.XXXXXX.log")"
artifact="out/target/product/vsoc_x86_64/system/etc/selinux/plat_sepolicy.cil"
printf "build log: %s\n" "$build_log"
(
  source build/envsetup.sh >/dev/null 2>&1 &&
  lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 &&
  m selinux_policy
) >"$build_log" 2>&1 &
build_pid=$!
while kill -0 "$build_pid" 2>/dev/null; do
  tail -n 20 "$build_log"
  sleep 10
done
wait "$build_pid"
build_rc=$?
if [[ "$build_rc" -ne 0 ]]; then
  tail -n 200 "$build_log" >&2
  exit "$build_rc"
fi
grep -Fq "#### build completed successfully" "$build_log" || exit 1
[[ -f "$artifact" ]] || exit 1
printf "artifact: %s\n" "$artifact"
'
```

## Deploy the policy image

Policy requires a full image, not a services.jar push. Build it from its own initialized shell, inspect the fleet, and explicitly confirm the group before changing its state:

```bash
bash -c '
set -u
full_build_log="$(mktemp "${TMPDIR:-/tmp}/build-full-sepolicy.XXXXXX.log")"
image_artifact="out/target/product/vsoc_x86_64/system.img"
printf "full build log: %s\n" "$full_build_log"
(
  source build/envsetup.sh >/dev/null 2>&1 &&
  lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 &&
  m
) >"$full_build_log" 2>&1 &
full_build_pid=$!
while kill -0 "$full_build_pid" 2>/dev/null; do
  tail -n 20 "$full_build_log"
  sleep 10
done
wait "$full_build_pid"
full_build_rc=$?
if [[ "$full_build_rc" -ne 0 ]]; then
  tail -n 200 "$full_build_log" >&2
  exit "$full_build_rc"
fi
grep -Fq "#### build completed successfully" "$full_build_log" || exit 1
[[ -f "$image_artifact" ]] || exit 1
' || exit $?
cvd fleet || exit $?
cvd_group="${CVD_GROUP:?Set CVD_GROUP to the explicitly confirmed group from cvd fleet}"
cvd --group_name="$cvd_group" stop || exit $?
cvd --group_name="$cvd_group" start || exit $?
```

The group selector placement above is the local Cuttlefish `cvd [selectors] command` form.

## Verify enforcement and behavior

Set `ANDROID_SERIAL` only after explicitly confirming the target. Pin both the denial query and service registration query to it:

```bash
device_serial="${ANDROID_SERIAL:?Set ANDROID_SERIAL to the explicitly confirmed target serial}"
adb -s "$device_serial" get-state
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

After boot, inspect denials and service registration. Investigate every new relevant denial rather than assuming an empty or filtered query proves correctness. For whole-feature delivery, run the applicable `features/<feature>/verify-*.sh` scripts and require exact `RESULT PASS` with exit 0; apply the requirement-level acceptance below to individual tasks.

## Execution scope and acceptance

Read this skill before the routed source change; reading it does not execute every command. Requirement clarification and planning do not start builds. Select build commands, deployment actions and acceptance checks separately according to the current authorized task. Calling intent-implement does not by itself authorize device deployment, restart or data cleanup. Use the confirmed device/CVD group and retain the existing device protections.

Read the active feature instructions and run its branch checker before source writes; repeat before later writes not covered by hooks. Record the affected repository subset, build target, artifacts, applicable checks and environment dependencies in the current requirement document. Serialize builds sharing one `out/`, and operations sharing a device or CVD group; the main agent owns shared planning documents.

Complete a requirement against its agreed acceptance and necessary regressions; independent review is required only when requested by the user or project rules. Keep other unfinished requirements visible without blocking an already accepted requirement. Whole-feature delivery requires all requirements plus the full `features/<feature>/verify-*.sh` acceptance: exact `RESULT PASS`, exit 0, no required SKIP. An exploration result `RESULT INCOMPLETE` with exit 0 is incomplete. Report planning, offline Harness checks, compilation, requirement delivery and device acceptance separately; investigate relevant failures instead of retroactively excluding checks. If required environment or review is unavailable, report partial results and the next concrete operation.
