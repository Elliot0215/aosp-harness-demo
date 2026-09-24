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
[[ "$(readlink "$tree/.cursor")" == features/.harness/cursor ]]
bash "$tree/features/install-harness.sh" >/dev/null
[[ "$(readlink "$tree/.cursor")" == features/.harness/cursor ]]

# Physical and logical entry points must select the copied tree without overrides.
for entry in .cursor features/.harness/cursor; do
  env -u HARNESS_ROOT bash "$tree/$entry/bin/cursor-feature" --dry-run >/dev/null
  [[ "$(readlink "$tree/AGENTS.md")" == features/dev-sidebar/AGENTS.md ]]
  env -u HARNESS_ROOT bash "$tree/$entry/bin/check-process-layer" >/dev/null
done
mkdir "$tree/features/dev-next"
printf '# next\n' >"$tree/features/dev-next/AGENTS.md"
state="$FIXTURE/state"
printf '{"session_id":"install-test"}\n' | env -u HARNESS_ROOT \
  CURSOR_HARNESS_STATE_DIR="$state" bash "$tree/.cursor/hooks/session-start.sh"
printf '%s\n' dev-next >"$tree/CURRENT_FEATURE"
output="$(printf '{"session_id":"install-test","hook_event_name":"beforeSubmitPrompt"}\n' | env -u HARNESS_ROOT \
  CURSOR_HARNESS_STATE_DIR="$state" bash "$tree/features/.harness/cursor/hooks/check-branch-drift.sh")"
[[ "$output" == *'"continue": false'* ]]
env -u HARNESS_ROOT bash "$tree/.cursor/bin/cursor-feature" --dry-run >/dev/null
[[ "$(readlink "$tree/AGENTS.md")" == features/dev-next/AGENTS.md ]]

# Collisions must leave existing content untouched.
for collision in cursor-file cursor-dir cursor-link missing-source; do
  target="$FIXTURE/$collision"
  mkdir -p "$target/features/.harness/cursor" "$target/features/.harness/cursor/skills"
  case "$collision" in
    cursor-file) printf keep >"$target/.cursor" ;;
    cursor-dir) mkdir "$target/.cursor" ;;
    cursor-link) ln -s missing "$target/.cursor" ;;
    missing-source)
      rmdir "$target/features/.harness/cursor/skills"
      rmdir "$target/features/.harness/cursor"
      ;;
  esac
  before="$(find "$target" -printf '%P %y %l\n' | LC_ALL=C sort)"
  if HARNESS_ROOT="$target" bash "$ROOT/features/install-harness.sh" >"$FIXTURE/out" 2>&1; then
    echo "FAIL  accepted install collision: $collision" >&2
    exit 1
  fi
  [[ "$(find "$target" -printf '%P %y %l\n' | LC_ALL=C sort)" == "$before" ]]
  case "$collision" in
    cursor-file) [[ "$(cat "$target/.cursor")" == keep ]] ;;
  esac
done
echo 'PASS  Cursor Agent Harness installation and relocated entry points'
