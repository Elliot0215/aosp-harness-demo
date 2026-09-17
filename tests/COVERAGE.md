| Test | Specs/requirements | Protected behavior | Offline boundary | Status |
|---|---|---|---|---|
| `tests/test-device-safety.sh` | Independent examples | Device targeting and legacy regressions | Fake ADB and both example test suites | active |
| `tests/test-docs.sh` | Example documentation | README commands, local links, and rejection of stale article paths | Local files and temporary fixture only | active |
| `tests/test-runtime-contracts.sh` | Build/deploy and verification contracts | Invalid serials rejected before any ADB call in both services skills; AOSP success log formats, artifact/status checks, ADB/CVD failure propagation, exact service/package checks with large output, and configured hooks in paths with spaces | Actual skill blocks and hooks with fake tools in temporary fixtures | active |
| `tests/test-quality-gate.sh` | Quality gate | Offline/CI checks and tool failure handling | Fixture and fake tools only | active |
