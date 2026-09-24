#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
python3 - "$ROOT" <<'PY'
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

repo = Path(sys.argv[1])
with tempfile.TemporaryDirectory(prefix='zcode app ') as temporary:
    root = Path(temporary) / 'aosp tree'
    root.mkdir()
    shutil.copytree(repo / 'zcode/features/.harness', root / 'features/.harness')
    shutil.copy(repo / 'zcode/features/install-harness.sh', root / 'features/install-harness.sh')
    for feature in ('dev-one', 'dev-two'):
        directory = root / 'features' / feature
        directory.mkdir()
        (directory / 'AGENTS.md').write_text('# ' + feature + '\n')
    (root / 'CURRENT_FEATURE').write_text('dev-one\n')
    env = dict(os.environ, HARNESS_ROOT=str(root), ZCODE_HARNESS_STATE_DIR=str(Path(temporary) / 'state'))
    # Preparation must never launch a CLI, including when called outside root.
    fake = Path(temporary) / 'bin'
    fake.mkdir()
    (fake / 'zcode').write_text('#!/usr/bin/env bash\ntouch "$APP_TEST_CLI_MARKER"\nexit 99\n')
    (fake / 'zcode').chmod(0o755)
    env['APP_TEST_CLI_MARKER'] = str(root / 'cli-launched')
    env['PATH'] = str(fake) + os.pathsep + env['PATH']

    def run(*args):
        return subprocess.run(args, cwd=temporary, env=env, text=True, capture_output=True)

    installed = run('bash', str(root / 'features/install-harness.sh'))
    assert installed.returncode == 0, installed.stderr
    prepare = root / '.zcode/bin/prepare-feature'
    for _ in range(2):
        result = run(str(prepare))
        assert result.returncode == 0, result.stderr
    assert not (root / 'cli-launched').exists()
    assert os.readlink(root / 'AGENTS.md') == 'features/dev-one/AGENTS.md'
    assert run(str(prepare), '--unknown').returncode == 2
    # Desktop does not inherit the CLI wrapper's environment variables.
    env.pop('HARNESS_ROOT')
    assert run(str(prepare)).returncode == 0

    config = json.loads((root / '.zcode/config.json').read_text())
    events = config['hooks']['events']
    assert config['hooks']['enabled'] is True

    def hook(source, session='app-one', *, cwd=None, stopped=False, malformed=False):
        event = 'UserPromptSubmit' if source == 'prompt' else 'SessionStart'
        payload = dict(session_id=session, cwd=str(cwd or root), hook_event_name=event, source=source)
        commands = [h['command'] for group in events[event]
                    if event != 'SessionStart' or re.search(group.get('matcher', ''), source)
                    for h in group['hooks']]
        assert len(commands) == 1, (source, commands)
        result = subprocess.run(['bash', '-c', commands[0]], cwd=root,
                                env=dict(env, ZCODE_PROJECT_DIR=str(root)),
                                input='{' if malformed else json.dumps(payload), text=True, capture_output=True)
        if stopped:
            # ZCode command hooks block via exit code 2 with an empty stdout.
            assert result.returncode == 2, (result.returncode, result.stdout, result.stderr)
            assert result.stdout == '', result.stdout
            assert result.stderr, result.stderr
            assert 'NEW ZCode session' in result.stderr, result.stderr
        else:
            assert result.returncode == 0, (result.returncode, result.stdout, result.stderr)
            assert result.stdout == '', result.stdout

    hook('startup')
    snapshot = Path(env['ZCODE_HARNESS_STATE_DIR']) / 'app-one.feature'
    assert snapshot.read_text() == 'dev-one\n'
    for source in ('prompt', 'resume', 'compact', 'clear', 'startup'):
        hook(source)
    hook('resume', 'unknown-session', stopped=True)
    assert not snapshot.with_name('unknown-session.feature').exists()
    hook('startup', '../escape', stopped=True)
    hook('startup', malformed=True, stopped=True)
    hook('startup', cwd=temporary, stopped=True)

    # Bypassing preparation cannot silently attach the wrong instructions.
    (root / 'CURRENT_FEATURE').write_text('dev-two\n')
    hook('startup', 'unprepared', stopped=True)
    assert not snapshot.with_name('unprepared.feature').exists()
    assert run(str(prepare)).returncode == 0
    # Preparing another feature must not bless an old session, even on startup replay.
    for source in ('resume', 'prompt', 'compact', 'clear', 'startup'):
        hook(source, stopped=True)
        assert snapshot.read_text() == 'dev-one\n'
    hook('startup', 'app-two')
    hook('prompt', 'app-two')
    snapshot.with_name('app-two.feature').unlink()
    hook('resume', 'app-two', stopped=True)
    snapshot.with_name('app-two.feature').write_text('invalid\nsnapshot\n')
    hook('resume', 'app-two', stopped=True)
    assert snapshot.with_name('app-two.feature').read_text() == 'invalid\nsnapshot\n'

    # Existing user instructions survive preparation failure.
    (root / 'AGENTS.md').unlink()
    (root / 'AGENTS.md').write_text('user-owned\n')
    assert run(str(prepare)).returncode != 0
    assert (root / 'AGENTS.md').read_text() == 'user-owned\n'
    hook('startup', 'protected', stopped=True)
    (root / 'AGENTS.md').unlink()
    assert run(str(prepare)).returncode == 0

    # Multi-repo validation runs on preparation and on subsequent prompts.
    (root / '.repo').mkdir()
    feature_dir = root / 'features/dev-two'
    shutil.copy(repo / 'zcode/features/dev-sidebar/check-branch.sh', feature_dir / 'check-branch.sh')
    (feature_dir / 'repos.tsv').write_text('repos/one\tdev-two\tfixture\n')
    assert run(str(prepare)).returncode != 0
    hook('startup', 'missing-repo', stopped=True)
    child = root / 'repos/one'
    child.mkdir(parents=True)
    assert run('git', '-C', str(child), 'init', '-q', '-b', 'dev-two').returncode == 0
    assert run('git', '-C', str(child), '-c', 'user.name=test', '-c', 'user.email=test@example.com',
               'commit', '--allow-empty', '-qm', 'fixture').returncode == 0
    assert run(str(prepare)).returncode == 0
    hook('startup', 'multi-repo')
    assert run('git', '-C', str(child), 'checkout', '-qb', 'wrong-feature').returncode == 0
    hook('prompt', 'multi-repo', stopped=True)
    assert os.readlink(root / 'AGENTS.md') == 'features/dev-two/AGENTS.md'
    assert not (root / 'cli-launched').exists()
print('RESULT PASS  ZCode Desktop preparation and lifecycle contracts (offline fixtures)')
PY
