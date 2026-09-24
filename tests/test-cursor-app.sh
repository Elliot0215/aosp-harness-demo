#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
python3 - "$ROOT" <<'PY'
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

repo = Path(sys.argv[1])
with tempfile.TemporaryDirectory(prefix='cursor app ') as temporary:
    root = Path(temporary) / 'aosp tree'
    root.mkdir()
    shutil.copytree(repo / 'cursor-agent/features/.harness', root / 'features/.harness')
    shutil.copy(repo / 'cursor-agent/features/install-harness.sh', root / 'features/install-harness.sh')
    for feature in ('dev-one', 'dev-two'):
        directory = root / 'features' / feature
        directory.mkdir()
        (directory / 'AGENTS.md').write_text('# ' + feature + '\n')
    (root / 'CURRENT_FEATURE').write_text('dev-one\n')
    env = dict(os.environ, HARNESS_ROOT=str(root),
               CURSOR_HARNESS_STATE_DIR=str(Path(temporary) / 'state'))
    # Preparation must never launch a CLI, including when called outside root.
    fake = Path(temporary) / 'bin'
    fake.mkdir()
    for name in ('cursor-agent', 'agent'):
        binary = fake / name
        binary.write_text('#!/usr/bin/env bash\ntouch "$APP_TEST_CLI_MARKER"\nexit 99\n')
        binary.chmod(0o755)
    env['APP_TEST_CLI_MARKER'] = str(root / 'cli-launched')
    env['PATH'] = str(fake) + os.pathsep + env['PATH']

    def run(*args):
        return subprocess.run(args, cwd=temporary, env=env, text=True, capture_output=True)

    installed = run('bash', str(root / 'features/install-harness.sh'))
    assert installed.returncode == 0, installed.stderr
    prepare = root / '.cursor/bin/prepare-feature'
    for _ in range(2):
        result = run(str(prepare))
        assert result.returncode == 0, result.stderr
    assert not (root / 'cli-launched').exists()
    assert os.readlink(root / 'AGENTS.md') == 'features/dev-one/AGENTS.md'
    assert run(str(prepare), '--unknown').returncode == 2
    assert os.readlink(root / 'AGENTS.md') == 'features/dev-one/AGENTS.md'
    # The IDE does not inherit the CLI wrapper's environment variables.
    env.pop('HARNESS_ROOT')
    assert run(str(prepare)).returncode == 0
    assert run(str(root / '.cursor/bin/cursor-feature'), '--dry-run').returncode == 0
    assert not (root / 'cli-launched').exists()

    config = json.loads((root / '.cursor/hooks.json').read_text())
    assert config['version'] == 1
    for event in ('beforeSubmitPrompt', 'preToolUse'):
        assert config['hooks'][event][0]['failClosed'] is True

    def hook(event, session='app-one', *, stopped=False, malformed=False):
        payload = dict(session_id=session, cwd=str(root), hook_event_name=event)
        commands = [item['command'] for item in config['hooks'][event]]
        assert len(commands) == 1, (event, commands)
        result = subprocess.run(['bash', str(root / commands[0])], cwd=root, env=env,
                                input='{' if malformed else json.dumps(payload),
                                text=True, capture_output=True)
        if event == 'sessionStart' and (stopped or malformed):
            assert result.returncode != 0, (result.returncode, result.stdout, result.stderr)
            return result
        assert result.returncode == 0, (result.returncode, result.stdout, result.stderr)
        if stopped:
            data = json.loads(result.stdout)
            if event == 'preToolUse':
                assert data['permission'] == 'deny', data
            else:
                assert data['continue'] is False, data
            assert './.cursor/bin/prepare-feature' in data['user_message'], data
            assert 'NEW Agent chat' in data['user_message'], data
            assert './.cursor/bin/cursor-feature' in data['user_message'], data
        else:
            assert result.stdout == '', result.stdout
        return result

    hook('sessionStart')
    snapshot = Path(env['CURSOR_HARNESS_STATE_DIR']) / 'app-one.feature'
    assert snapshot.read_text() == 'dev-one\n'
    hook('sessionStart')
    assert snapshot.read_text() == 'dev-one\n'
    hook('beforeSubmitPrompt')
    hook('preToolUse')
    hook('beforeSubmitPrompt', '../escape', stopped=True)
    assert not snapshot.with_name('..escape.feature').exists()
    hook('beforeSubmitPrompt', malformed=True, stopped=True)
    hook('sessionStart', '../escape', stopped=True)
    assert not list(Path(env['CURSOR_HARNESS_STATE_DIR']).glob('*escape*'))

    (root / 'CURRENT_FEATURE').write_text('dev-two\n')
    assert run(str(prepare)).returncode == 0
    assert os.readlink(root / 'AGENTS.md') == 'features/dev-two/AGENTS.md'
    # Replaying sessionStart must not bless the old chat with the new feature.
    hook('sessionStart')
    assert snapshot.read_text() == 'dev-one\n'
    for event in ('beforeSubmitPrompt', 'preToolUse'):
        hook(event, stopped=True)
        assert snapshot.read_text() == 'dev-one\n'
    hook('sessionStart', 'app-two')
    assert snapshot.with_name('app-two.feature').read_text() == 'dev-two\n'
    snapshot.with_name('app-two.feature').unlink()
    hook('beforeSubmitPrompt', 'app-two', stopped=True)
    assert not snapshot.with_name('app-two.feature').exists()
    snapshot.with_name('app-two.feature').write_text('invalid\nsnapshot\n')
    hook('sessionStart', 'app-two')
    hook('beforeSubmitPrompt', 'app-two', stopped=True)
    assert snapshot.with_name('app-two.feature').read_text() == 'invalid\nsnapshot\n'

    # Existing user instructions survive preparation failure.
    (root / 'AGENTS.md').unlink()
    (root / 'AGENTS.md').write_text('user-owned\n')
    assert run(str(prepare)).returncode != 0
    assert (root / 'AGENTS.md').read_text() == 'user-owned\n'
    (root / 'AGENTS.md').unlink()
    assert run(str(prepare)).returncode == 0
    assert os.readlink(root / 'AGENTS.md') == 'features/dev-two/AGENTS.md'

    # Illegal feature names fail closed and leave the previous link alone.
    (root / 'CURRENT_FEATURE').write_text('not a feature\n')
    assert run(str(prepare)).returncode != 0
    assert os.readlink(root / 'AGENTS.md') == 'features/dev-two/AGENTS.md'
    (root / 'CURRENT_FEATURE').write_text('dev-two\n')

    # Multi-repo validation runs on preparation and does not retarget on failure.
    (root / '.repo').mkdir()
    feature_dir = root / 'features/dev-two'
    checker = feature_dir / 'check-branch.sh'
    shutil.copy(repo / 'cursor-agent/features/dev-sidebar/check-branch.sh', checker)
    checker.chmod(0o755)
    (feature_dir / 'repos.tsv').write_text('repos/one\tdev-two\tfixture\n')
    assert run(str(prepare)).returncode != 0
    assert os.readlink(root / 'AGENTS.md') == 'features/dev-two/AGENTS.md'
    child = root / 'repos/one'
    child.mkdir(parents=True)
    assert run('git', '-C', str(child), 'init', '-q', '-b', 'dev-two').returncode == 0
    assert run('git', '-C', str(child), '-c', 'user.name=test', '-c', 'user.email=test@example.com',
               'commit', '--allow-empty', '-qm', 'fixture').returncode == 0
    assert run(str(prepare)).returncode == 0
    assert run('git', '-C', str(child), 'checkout', '-qb', 'wrong-feature').returncode == 0
    assert run(str(prepare)).returncode != 0
    assert os.readlink(root / 'AGENTS.md') == 'features/dev-two/AGENTS.md'
    assert run('git', '-C', str(child), 'checkout', '-q', 'dev-two').returncode == 0

    launched = run(str(root / '.cursor/bin/cursor-feature'))
    assert launched.returncode == 99, (launched.returncode, launched.stdout, launched.stderr)
    assert (root / 'cli-launched').exists()
    (root / 'cli-launched').unlink()
    assert run(str(prepare)).returncode == 0
    assert not (root / 'cli-launched').exists()
print('RESULT PASS  Cursor IDE preparation and lifecycle contracts (offline fixtures)')
PY
