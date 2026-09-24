#!/usr/bin/env bash
# Expose the versioned Cursor Agent Harness through its standard project path.
set -euo pipefail

FEATURES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="${HARNESS_ROOT:-$(cd "$FEATURES_DIR/.." && pwd -P)}"

python3 - "$ROOT" <<'PY'
import os
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve(strict=True)
link = root / '.cursor'
target = 'features/.harness/cursor'
source = root / 'features/.harness/cursor'

if not source.is_dir():
    print(f'error: missing Harness source: {source}', file=sys.stderr)
    sys.exit(1)

if os.path.lexists(link):
    if link.is_symlink() and os.readlink(link) == target:
        print(f'[install-harness] {link.relative_to(root)} -> {target}')
        sys.exit(0)
    print(f'error: {link} already exists; refusing overwrite', file=sys.stderr)
    sys.exit(1)

try:
    link.symlink_to(target, target_is_directory=True)
except OSError as error:
    print(f'error: {error}', file=sys.stderr)
    sys.exit(1)

print(f'[install-harness] {link.relative_to(root)} -> {target}')
PY
