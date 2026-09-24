| Test | Specs/requirements | Protected behavior | Offline boundary | Status |
|---|---|---|---|---|
| `tests/test-device-safety.sh` | Independent examples | Device targeting, strict/allow-skip INCOMPLETE result semantics and FAIL precedence over SKIP, and legacy regressions | Fake ADB and the Claude, Codex, Cursor Agent, and ZCode example test suites | active |
| `tests/test-docs.sh` | Example documentation | README commands, local links, and rejection of stale article paths | Local files and temporary fixture only | active |
| `tests/test-intent-cooperation.sh` | intent skill interface | Active four-client calls resolve to current skill names; missing names and missing adjacent skills fail | Temporary document and skill fixtures; adjacent intent checkout is optional | active |
| `tests/test-runtime-contracts.sh` | Build/deploy and verification contracts | Invalid serials rejected before any ADB call in Claude, Codex, Cursor Agent, and ZCode services skills; AOSP success log formats, artifact/status checks, ADB/CVD failure propagation, exact service/package checks with large output, and configured hooks in paths with spaces | Actual skill blocks and hooks with fake tools in temporary fixtures | active |
| `tests/test-quality-gate.sh` | Quality gate | Offline/CI checks and tool failure handling | Fixture and fake tools only | active |
| `tests/test-codex-app.sh` | Codex App adapter | Shared preparation, protected instructions, configured lifecycle commands, root cwd, branch validation, immutable resume baseline and missing-state rejection | Temporary multi-repo fixtures and fake CLI; no App runtime or device validation | active |
| `tests/test-zcode-app.sh` | ZCode Desktop adapter | Shared preparation, protected instructions, configured config.json lifecycle commands with exit-2 blocking, root cwd, branch validation, immutable resume baseline and missing-state rejection | Temporary multi-repo fixtures and fake CLI; no Desktop runtime or device validation | active |
| `tests/test-cursor-app.sh` | Cursor desktop IDE adapter | Shared preparation that never launches a client, protected instructions, configured hooks.json commands, immutable session baseline, and drift or missing-snapshot blocking | Temporary multi-repo fixtures and a fake CLI; no IDE runtime, trust prompt, or device validation | active |

## intent 联动补充验证

2026-09-21 的 [联动验证记录](../docs/intent-integration-validation.md) 提到相邻 intent 仓的 `tests/test_harness_integration.py`；该测试在 intent 后续精简后已不在当前工作树中，不能作为本次回归证据。当前 Harness 的离线门禁独立运行，不依赖相邻仓；可选的技能引用核对读取实际 intent `SKILL.md` 名称。
