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
[[ "$(readlink "$tree/.codex")" == features/.harness/codex ]]
[[ "$(readlink "$tree/.agents/skills")" == ../features/.harness/skills ]]
printf 'keep\n' >"$tree/.agents/user-file"
bash "$tree/features/install-harness.sh" >/dev/null
[[ "$(cat "$tree/.agents/user-file")" == keep ]]

# Physical and logical entry points must select the copied tree without overrides.
for entry in .codex features/.harness/codex; do
  env -u HARNESS_ROOT bash "$tree/$entry/bin/codex-feature" --dry-run >/dev/null
  [[ "$(readlink "$tree/AGENTS.md")" == features/dev-sidebar/AGENTS.md ]]
  env -u HARNESS_ROOT bash "$tree/$entry/bin/check-process-layer" >/dev/null
done
mkdir "$tree/features/dev-next"
printf '# next\n' >"$tree/features/dev-next/AGENTS.md"
state="$FIXTURE/state"
printf '{"session_id":"install-test"}\n' | env -u HARNESS_ROOT \
  CODEX_HARNESS_STATE_DIR="$state" bash "$tree/.codex/hooks/session-start.sh"
printf '%s\n' dev-next >"$tree/CURRENT_FEATURE"
output="$(printf '{"session_id":"install-test"}\n' | env -u HARNESS_ROOT \
  CODEX_HARNESS_STATE_DIR="$state" bash "$tree/features/.harness/codex/hooks/check-branch-drift.sh")"
[[ "$output" == *'"continue": false'* ]]
env -u HARNESS_ROOT bash "$tree/.codex/bin/codex-feature" --dry-run >/dev/null
[[ "$(readlink "$tree/AGENTS.md")" == features/dev-next/AGENTS.md ]]

# Collisions must leave both existing content and the other entry untouched.
for collision in codex-file codex-dir codex-link skills-file skills-dir skills-link agents-file agents-link missing-source; do
  target="$FIXTURE/$collision"
  mkdir -p "$target/features/.harness/codex" "$target/features/.harness/skills"
  case "$collision" in
    codex-file) printf keep >"$target/.codex" ;;
    codex-dir) mkdir "$target/.codex" ;;
    codex-link) ln -s missing "$target/.codex" ;;
    skills-file)
      mkdir "$target/.agents"
      printf keep >"$target/.agents/skills"
      ;;
    skills-dir) mkdir -p "$target/.agents/skills" ;;
    skills-link)
      mkdir "$target/.agents"
      ln -s missing "$target/.agents/skills"
      ;;
    agents-file) printf keep >"$target/.agents" ;;
    agents-link) ln -s "$tree/.agents" "$target/.agents" ;;
    missing-source) rmdir "$target/features/.harness/skills" ;;
  esac
  before="$(find "$target" -printf '%P %y %l\n' | LC_ALL=C sort)"
  if HARNESS_ROOT="$target" bash "$ROOT/features/install-harness.sh" >"$FIXTURE/out" 2>&1; then
    echo "FAIL  accepted install collision: $collision" >&2
    exit 1
  fi
  [[ "$(find "$target" -printf '%P %y %l\n' | LC_ALL=C sort)" == "$before" ]]
  case "$collision" in
    codex-file) [[ "$(cat "$target/.codex")" == keep ]] ;;
    skills-file) [[ "$(cat "$target/.agents/skills")" == keep ]] ;;
    agents-file) [[ "$(cat "$target/.agents")" == keep ]] ;;
  esac
done
echo 'PASS  Codex Harness installation and relocated entry points'
