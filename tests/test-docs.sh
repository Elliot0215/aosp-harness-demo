#!/usr/bin/env bash
set -u
root=$(CDPATH='' cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P)
out=$(bash "$root/scripts/check-docs.sh") || exit 1
[[ $out == 'RESULT PASS  docs readiness' ]] || exit 1
python3 - "$root" <<'PY' || exit 1
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(sys.argv[1])
with tempfile.TemporaryDirectory(prefix='harness-docs-') as temporary:
    fixture = Path(temporary)
    for directory in ('scripts', 'docs', 'claude-code', 'codex'):
        (fixture / directory).mkdir()
    shutil.copy2(root / 'scripts/check-docs.sh', fixture / 'scripts/check-docs.sh')
    (fixture / 'README.md').write_text(
        'bash scripts/check.sh --offline\nbash claude-code/run-demo.sh\n'
        'bash codex/run-demo.sh\nclaude-code/README.md\ncodex/README.md\nRESULT PASS\n')
    for client in ('claude', 'codex'):
        directory = 'claude-code' if client == 'claude' else client
        (fixture / directory / 'README.md').write_text(
            f'[article](../docs/AOSP整机源码Harness工程探索-{client}版.md)\n')
        (fixture / 'docs' / f'AOSP整机源码Harness工程探索-{client}版.md').touch()
        entry = fixture / directory / 'run-demo.sh'
        entry.touch()
        entry.chmod(0o755)
    command = ['bash', str(fixture / 'scripts/check-docs.sh')]
    result = subprocess.run(command, text=True, capture_output=True)
    assert result.returncode == 0, result.stderr
    (fixture / 'codex/README.md').write_text('[article](AOSP整机源码Codex-Harness工程探索.md)\n')
    result = subprocess.run(command, text=True, capture_output=True)
    assert result.returncode != 0 and 'broken link' in result.stderr, result
    assert 'RESULT PASS' not in result.stdout, result.stdout
PY
printf 'RESULT PASS  docs\n'
