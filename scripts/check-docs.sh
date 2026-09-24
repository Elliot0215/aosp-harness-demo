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
  cursor-agent/README.md \
  zcode/README.md \
  docs/AOSP整机源码Harness工程探索-claude版.md \
  docs/AOSP整机源码Harness工程探索-codex版.md \
  docs/AOSP整机源码Harness工程探索-cursor-agent版.md \
  docs/AOSP整机源码Harness工程探索-zcode版.md; do
  [[ -f $root/$path ]] || fail "missing $path"
done
for executable in claude-code/run-demo.sh codex/run-demo.sh cursor-agent/run-demo.sh zcode/run-demo.sh; do
  [[ -x $root/$executable ]] || fail "not executable: $executable"
done
for phrase in \
  'bash scripts/check.sh --offline' \
  'bash claude-code/run-demo.sh' \
  'bash codex/run-demo.sh' \
  'bash cursor-agent/run-demo.sh' \
  'bash zcode/run-demo.sh' \
  'claude-code/README.md' \
  'codex/README.md' \
  'cursor-agent/README.md' \
  'zcode/README.md' \
  'RESULT PASS'; do
  grep -Fq "$phrase" "$root/README.md" || fail "README missing: $phrase"
done
python3 - "$root" <<'PY' || exit 1
from pathlib import Path
import re
import sys
from urllib.parse import unquote

root = Path(sys.argv[1])
sources = [root / 'README.md', root / 'claude-code/README.md',
           root / 'codex/README.md', root / 'cursor-agent/README.md',
           root / 'zcode/README.md',
           *sorted((root / 'docs').glob('AOSP*.md'))]
for source in sources:
    fenced = False
    for number, line in enumerate(source.read_text(encoding='utf-8').splitlines(), 1):
        if line.startswith('```'):
            fenced = not fenced
            continue
        if fenced:
            continue
        for target in re.findall(r'(?<!!)\[[^\]]+\]\(([^)]+)\)', line):
            target = target.strip()
            if target.startswith('<') and target.endswith('>'):
                target = target[1:-1]
            target = target.split('#', 1)[0]
            if not target or re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', target):
                continue
            if not (source.parent / unquote(target)).exists():
                print(f'DOCS FAIL  {source.relative_to(root)}:{number}: broken link: {target}',
                      file=sys.stderr)
                raise SystemExit(1)
PY
printf 'RESULT PASS  docs readiness\n'
