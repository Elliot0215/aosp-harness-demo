#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf -- "$FIXTURE"' EXIT

# Only features/ is needed to install into a fresh tree, including spaces.
tree="$FIXTURE/AOSP tree"
mkdir -p "$tree"
cp -a "$ROOT/features" "$tree/features"
printf '%s\n' dev-sidebar >"$tree/CURRENT_FEATURE"
bash "$tree/features/install-harness.sh" >/dev/null
[[ "$(readlink "$tree/.zcode")" == features/.harness/zcode ]]
bash "$tree/features/install-harness.sh" >/dev/null

# Physical and logical entry points must select the copied tree without overrides.
for entry in .zcode features/.harness/zcode; do
  env -u HARNESS_ROOT bash "$tree/$entry/bin/prepare-feature" >/dev/null
  [[ "$(readlink "$tree/AGENTS.md")" == features/dev-sidebar/AGENTS.md ]]
  env -u HARNESS_ROOT bash "$tree/$entry/bin/check-process-layer" >/dev/null
done
mkdir "$tree/features/dev-next"
printf '# next\n' >"$tree/features/dev-next/AGENTS.md"
state="$FIXTURE/state"
printf '{"session_id":"install-test"}\n' | env -u HARNESS_ROOT \
  ZCODE_HARNESS_STATE_DIR="$state" bash "$tree/.zcode/hooks/session-start.sh"
printf '%s\n' dev-next >"$tree/CURRENT_FEATURE"
set +e
output="$(printf '{"session_id":"install-test"}\n' | env -u HARNESS_ROOT \
  ZCODE_HARNESS_STATE_DIR="$state" \
  bash "$tree/features/.harness/zcode/hooks/check-branch-drift.sh" 2>&1)"
rc=$?
set -e
[[ "$rc" -eq 2 ]]
[[ "$output" == *"current feature is 'dev-next'"* ]]
env -u HARNESS_ROOT bash "$tree/.zcode/bin/prepare-feature" >/dev/null
[[ "$(readlink "$tree/AGENTS.md")" == features/dev-next/AGENTS.md ]]

# Collisions must leave existing content untouched.
for collision in zcode-file zcode-dir zcode-link missing-source; do
  target="$FIXTURE/$collision"
  mkdir -p "$target/features/.harness/zcode"
  case "$collision" in
    zcode-file) printf keep >"$target/.zcode" ;;
    zcode-dir) mkdir "$target/.zcode" ;;
    zcode-link) ln -s missing "$target/.zcode" ;;
    missing-source) rmdir "$target/features/.harness/zcode" ;;
  esac
  before="$(find "$target" -printf '%P %y %l\n' | LC_ALL=C sort)"
  if HARNESS_ROOT="$target" bash "$ROOT/features/install-harness.sh" >"$FIXTURE/out" 2>&1; then
    echo "FAIL  accepted install collision: $collision" >&2
    exit 1
  fi
  [[ "$(find "$target" -printf '%P %y %l\n' | LC_ALL=C sort)" == "$before" ]]
  case "$collision" in
    zcode-file) [[ "$(cat "$target/.zcode")" == keep ]] ;;
  esac
done
echo 'PASS  ZCode Harness installation and relocated entry points'
