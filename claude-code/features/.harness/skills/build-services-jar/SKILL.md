---
name: build-services-jar
description: 编译 / 部署 services.jar —— 改 frameworks/base/services 下代码（含 SystemServer 注册系统服务）时用
paths:
  - "frameworks/base/services/**"
---

<!-- DEMO —— ② 流程层示例 skill。物理源位于 features/.harness/skills/，
     经树根 .claude 软链暴露，避免 features/.claude 造成重复 skill 注册。 -->

# build-services-jar（② 流程：改 services 代码时激活）

承载**不随 feature 变**的通用流程；feature 特有内容写在 `features/<分支>/CLAUDE.md` 的对应仓小节，那里一句话指回本 skill（单一事实源，避免两处漂移）。

## 单编目标与产物

```bash
bash -c 'source build/envsetup.sh >/dev/null 2>&1 \
  && lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 \
  && m services'
```

- 产物：`out/target/product/vsoc_x86_64/system/framework/services.jar`

## push 清单（快环）

此教学片段没有不可变备份、原子替换、整组回滚或新启动周期验证。适配真实设备时实现并测试事务部署入口，不能将直接 push 用于正在 mmap 的 ELF；参见本仓的 [部署事务参考](../../../../../skills/build-aosp-harness/references/deployment-transactions.md)。

```bash
device_serial="${ANDROID_SERIAL-}"
if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then
  echo 'error: set ANDROID_SERIAL to a safe, explicit target serial' >&2
  exit 2
fi
adb -s "$device_serial" root || exit $?
adb -s "$device_serial" remount || exit $?
adb -s "$device_serial" push out/target/product/vsoc_x86_64/system/framework/services.jar /system/framework/services.jar || exit $?
adb -s "$device_serial" reboot || exit $?
```

## 已知坑

- **ART 缓存**：push services.jar 后 dexpreopt/boot image 与新 jar 校验不一致会拖慢启动甚至起不来。诡异时清 `/data/dalvik-cache/`，或走稳环（`m` 整机 → `cvd stop` → `cvd start` 换新镜像）。
- **新增系统服务**：必须同步 `system/sepolicy`（service_contexts + .te），否则 avc denied 起不来——见 `build-sepolicy` skill。
- **改 public/System API**：必须 `m update-api`，否则 checkapi 挂构建。

## 编过 ≠ 改对

build 成功只是第一步。收工前必须跑 `features/<分支>/verify-*.sh` 且全部 PASS 才允许宣布完成。
