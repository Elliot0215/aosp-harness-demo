#!/usr/bin/env bash
# 检查 repos.tsv 声明的所有涉及仓是否都在 feature 分支。
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT="${HARNESS_ROOT:-$SCRIPT_ROOT}"
FEATURE="${FEATURE_NAME:-dev-sidebar}"
LIST="$ROOT/features/$FEATURE/repos.tsv"
REPOS=()

valid_feature_name() {
  local LC_ALL=C
  [[ ${1-} =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

valid_feature_name "$FEATURE" || {
  echo 'INVALID feature' >&2
  exit 1
}

[[ -f "$LIST" ]] || {
  echo "MISSING $LIST" >&2
  exit 1
}

while read -r path _convention _tags _rest || [[ -n "${path:-}" ]]; do
  case "${path:-}" in
    "" | '#'*) continue ;;
  esac
  REPOS+=("$path")
done <"$LIST"

[[ ${#REPOS[@]} -gt 0 ]] || {
  echo "MISSING repos in $LIST" >&2
  exit 1
}

if [[ "${1:-}" == "--demo" ]]; then
  bad=0
  for repo in "${REPOS[@]}"; do
    branch="$FEATURE"
    [[ "$repo" == "build/make" ]] && branch="main"
    if [[ "$branch" == "$FEATURE" ]]; then
      echo "OK      $repo @ $branch"
    else
      echo "DRIFT   $repo @ $branch (应为 $FEATURE)"
      bad=1
    fi
  done
  exit "$bad"
fi

bad=0
for repo in "${REPOS[@]}"; do
  repo_root="$ROOT/$repo"
  if [[ ! -e "$repo_root/.git" && ! -L "$repo_root/.git" ]]; then
    echo "MISSING $repo"
    bad=1
    continue
  fi
  if ! git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
    echo "MISSING $repo"
    bad=1
    continue
  fi
  if branch="$(git -C "$repo_root" symbolic-ref --quiet --short HEAD 2>/dev/null)"; then
    :
  elif git -C "$repo_root" rev-parse --verify 'HEAD^{object}' >/dev/null 2>&1; then
    branch=DETACHED
  else
    echo "INVALID $repo"
    bad=1
    continue
  fi
  if [[ "$branch" == "$FEATURE" ]]; then
    echo "OK      $repo @ $branch"
  else
    echo "DRIFT   $repo @ $branch (应为 $FEATURE)"
    bad=1
  fi
done

exit "$bad"
