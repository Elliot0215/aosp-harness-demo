#!/usr/bin/env bash
set -u
root=$(CDPATH='' cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P) || exit 1
fail() {
  printf 'DOCS FAIL  %s\n' "$1" >&2
  exit 1
}
for path in \
  claude-code/README.md \
  codex/README.md \
  docs/AOSP整机源码Harness工程探索-claude版.md \
  docs/AOSP整机源码Harness工程探索-codex版.md; do
  [[ -f $root/$path ]] || fail "missing $path"
done
for executable in claude-code/run-demo.sh codex/run-demo.sh; do
  [[ -x $root/$executable ]] || fail "not executable: $executable"
done
for phrase in \
  'bash scripts/check.sh --offline' \
  'bash claude-code/run-demo.sh' \
  'bash codex/run-demo.sh' \
  'claude-code/README.md' \
  'codex/README.md' \
  'RESULT PASS'; do
  grep -Fq "$phrase" "$root/README.md" || fail "README missing: $phrase"
done
printf 'RESULT PASS  docs readiness\n'
