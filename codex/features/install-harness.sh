#!/usr/bin/env bash
# Expose the versioned Codex Harness through its standard project paths.
set -euo pipefail

FEATURES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="${HARNESS_ROOT:-$(cd "$FEATURES_DIR/.." && pwd -P)}"

python3 - "$ROOT" <<'PY'
import os
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve(strict=True)
agents = root / '.agents'
links = (
    (root / '.codex', 'features/.harness/codex'),
    (agents / 'skills', '../features/.harness/skills'),
)
created = []
created_agents = False
try:
    # Validate both destinations before creating either link. An existing .agents
    # directory can contain unrelated user files; never traverse a symlink here.
    if agents.is_symlink() or (agents.exists() and not agents.is_dir()):
        raise ValueError(f'{agents} must be an ordinary directory; refusing overwrite')
    for link, target in links:
        source = root / 'features/.harness' / ('codex' if link.name == '.codex' else 'skills')
        if not source.is_dir():
            raise ValueError(f'missing Harness source: {source}')
        if os.path.lexists(link):
            if not link.is_symlink() or os.readlink(link) != target:
                raise ValueError(f'{link} already exists; refusing overwrite')
    if not agents.exists():
        agents.mkdir()
        created_agents = True
    for link, target in links:
        if link.is_symlink() and os.readlink(link) == target:
            continue
        # symlink fails if a destination appeared after the preflight.
        link.symlink_to(target, target_is_directory=True)
        created.append((link, target))
except (OSError, ValueError) as error:
    for link, target in reversed(created):
        if link.is_symlink() and os.readlink(link) == target:
            link.unlink()
    if created_agents:
        try:
            agents.rmdir()
        except OSError:
            pass
    print(f'error: {error}', file=sys.stderr)
    sys.exit(1)
for link, target in links:
    print(f'[install-harness] {link.relative_to(root)} -> {target}')
PY
