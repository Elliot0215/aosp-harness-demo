#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P)"
python3 - "$root" <<'PY'
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

root = Path(sys.argv[1])


def skill_path(client, skill):
    if client == 'cursor-agent':
        return root / client / 'features/.harness/cursor/skills' / skill / 'SKILL.md'
    if client == 'zcode':
        return root / client / 'features/.harness/zcode/skills' / skill / 'SKILL.md'
    return root / client / 'features/.harness/skills' / skill / 'SKILL.md'


def blocks(client, skill):
    return re.findall(r'```bash\n(.*?)```', skill_path(client, skill).read_text(), re.S)


with tempfile.TemporaryDirectory(prefix='harness-runtime-') as temporary:
    fixture = Path(temporary)
    binary = fixture / 'bin'
    binary.mkdir()
    log = fixture / 'calls.jsonl'
    driver = '''import json, os, pathlib, signal, sys, time
signal.signal(signal.SIGPIPE, signal.SIG_DFL)
tool = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
if tool == 'sleep':
    time.sleep(0.001)
    raise SystemExit(0)
with open(os.environ['HARNESS_TEST_CALLS'], 'a') as output:
    output.write(json.dumps([tool, *args]) + '\\n')
if tool == 'build':
    if os.environ.get('HARNESS_TEST_ARTIFACT_MODE') != 'missing':
        artifact = pathlib.Path(os.environ['HARNESS_TEST_ARTIFACT'])
        artifact.parent.mkdir(parents=True, exist_ok=True)
        artifact.touch()
    print(os.environ.get('HARNESS_TEST_MARKER', '#### build completed successfully (1 seconds) ####'))
    raise SystemExit(int(os.environ.get('HARNESS_TEST_BUILD_RC', '0')))
if tool == 'cvd':
    assert args == ['fleet'] or args in [
        ['--group_name=fake-group', 'stop'], ['--group_name=fake-group', 'start']
    ], args
    raise SystemExit(73 if args[-1] == os.environ.get('HARNESS_TEST_FAIL') else 0)
assert tool == 'adb' and args[:2] == ['-s', 'fake-device'], args
args = args[2:]
if args[0] == os.environ.get('HARNESS_TEST_FAIL'):
    raise SystemExit(73)
if args in [['get-state'], ['root'], ['remount'], ['reboot']] or args[0] == 'push':
    raise SystemExit(0)
if args == ['shell', 'getprop', 'sys.boot_completed']:
    print('1')
elif args == ['shell', 'pidof', 'system_server']:
    print('123')
elif args == ['shell', 'cat', '/proc/stat']:
    print('btime 100')
elif args[0] == 'logcat':
    pass
elif args in [['shell', 'service', 'list'], ['shell', 'pm', 'list', 'packages']]:
    package = args[1] == 'pm'
    mode = os.environ.get('HARNESS_TEST_PACKAGE' if package else 'HARNESS_TEST_SERVICE', 'valid')
    good = 'package:com.android.sidebar' if package else '42 sidebar: [android.os.ISidebar]'
    if mode == 'lookalike':
        print('package:com.android.sidebar.fake' if package else '42 other_sidebar: [android.os.ISidebar]')
    elif mode == 'dots':
        print('package:comXandroidYsidebar')
    elif mode != 'missing':
        print(good + '\\r')
    if mode == 'large':
        for i in range(10000):
            print(f'package:com.example.app{i}' if package else f'{i} other{i}: [android.os.IOther]')
    if mode == 'error':
        raise SystemExit(73)
else:
    raise AssertionError(args)
'''
    for tool in ('adb', 'cvd', 'build', 'sleep'):
        executable = binary / tool
        executable.write_text(f'#!{sys.executable}\n' + driver)
        executable.chmod(0o755)
    (fixture / 'build').mkdir()
    (fixture / 'build/envsetup.sh').write_text(
        'lunch() { return "${HARNESS_TEST_LUNCH_RC:-0}"; }\n'
        'm() { "$HARNESS_TEST_BIN/build" "$@"; }\n'
        'return "${HARNESS_TEST_ENVSETUP_RC:-0}"\n')
    environment = dict(os.environ, PATH=str(binary) + ':' + os.environ['PATH'],
                       TMPDIR=temporary, ANDROID_SERIAL='fake-device', CVD_GROUP='fake-group',
                       HARNESS_TEST_BIN=str(binary), HARNESS_TEST_CALLS=str(log))

    def run(command, **overrides):
        log.write_text('')
        result = subprocess.run(command, cwd=fixture, env=dict(environment, **overrides),
                                text=True, capture_output=True, timeout=20)
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        return result, calls

    # Run the actual Markdown blocks in a default Bash shell, without inherited errexit.
    for client in ('claude-code', 'codex', 'cursor-agent', 'zcode'):
        deploy = next(block for block in blocks(client, 'build-services-jar')
                      if 'adb -s' in block and ' push ' in block)
        expected = ['get-state', 'root', 'remount', 'push', 'reboot']
        if client == 'claude-code':
            expected.remove('get-state')
        for serial in ('', ' ', '-s', 'device name', 'device;reboot', 'device\nother'):
            result, calls = run(['bash', '-c', deploy], ANDROID_SERIAL=serial)
            assert result.returncode == 2, (client, serial, result)
            assert calls == [], (client, serial, calls)
        for fail in ['', *expected]:
            result, calls = run(['bash', '-c', deploy], HARNESS_TEST_FAIL=fail)
            assert result.returncode == (73 if fail else 0), (client, fail, result)
            actual = [call[3] for call in calls]
            assert all(call[:3] == ['adb', '-s', 'fake-device'] for call in calls), calls
            assert actual == (expected[:expected.index(fail) + 1] if fail else expected), calls
    print('PASS  invalid serials make zero ADB calls; deployment stops at each failed ADB command')

    # Build status, actual AOSP log formats, and artifacts are independent evidence.
    artifacts = {'build-services-jar': 'system/framework/services.jar',
                 'build-sepolicy': 'system/etc/selinux/plat_sepolicy.cil'}
    for client in ('codex', 'cursor-agent', 'zcode'):
        for skill, relative in artifacts.items():
            for full in (False, True):
                build = next(block for block in blocks(client, skill)
                             if ('full_build_pid=$!' if full else '\nbuild_pid=$!') in block)
                artifact = fixture / 'out/target/product/vsoc_x86_64' / ('system.img' if full else relative)
                cases = [
                    ({}, 0),
                    ({'HARNESS_TEST_MARKER': '#### build completed successfully (01:23 (mm:ss)) ####'}, 0),
                    ({'HARNESS_TEST_MARKER': '\033[32m#### build completed successfully  ####\033[0m'}, 0),
                    ({'HARNESS_TEST_BUILD_RC': '73'}, 73),
                    ({'HARNESS_TEST_ENVSETUP_RC': '73'}, 73),
                    ({'HARNESS_TEST_LUNCH_RC': '73'}, 73),
                    ({'HARNESS_TEST_MARKER': '#### failed to build some targets ####'}, 1),
                    ({'HARNESS_TEST_ARTIFACT_MODE': 'missing'}, 1),
                ]
                if full:
                    cases += [({'HARNESS_TEST_FAIL': step}, 73) for step in ('fleet', 'stop', 'start')]
                for overrides, expected_rc in cases:
                    if artifact.exists():
                        artifact.unlink()
                    result, calls = run(['bash', '-c', build], HARNESS_TEST_ARTIFACT=str(artifact), **overrides)
                    assert result.returncode == expected_rc, (client, skill, full, overrides, result)
                    cvd = [call[-1] for call in calls if call[0] == 'cvd']
                    expected = ['fleet', 'stop', 'start'] if full else []
                    if overrides.get('HARNESS_TEST_FAIL'):
                        expected = expected[:expected.index(overrides['HARNESS_TEST_FAIL']) + 1]
                    elif expected_rc:
                        expected = []
                    assert cvd == expected, (client, skill, overrides, calls)
    print('PASS  build evidence and CVD failure propagation')

    # Exercise the real verifier with lookalikes and output exceeding a pipe buffer.
    for client in ('claude-code', 'codex', 'cursor-agent', 'zcode'):
        command = ['bash', str(root / client / 'features/dev-sidebar/verify-sidebar.sh')]
        cases = [({}, 'RESULT PASS')]
        for variable in ('HARNESS_TEST_PACKAGE', 'HARNESS_TEST_SERVICE'):
            cases += [({variable: 'large'}, 'RESULT PASS'), ({variable: 'error'}, 'RESULT FAIL')]
            for mode in ('missing', 'lookalike'):
                cases.append(({variable: mode}, 'RESULT INCOMPLETE' if 'PACKAGE' in variable else 'RESULT FAIL'))
        cases.append(({'HARNESS_TEST_PACKAGE': 'dots'}, 'RESULT INCOMPLETE'))
        for overrides, expected in cases:
            result, _ = run(command, **overrides)
            assert result.stdout.splitlines()[-1] == expected, (client, overrides, result)
            assert result.returncode == (0 if expected == 'RESULT PASS' else 1), result
    print('PASS  exact service/package matching, large output, and query failures')

    # Execute commands taken from settings.json, including every hook's actual effect.
    project = fixture / 'tree with spaces'
    shutil.copytree(root / 'claude-code/features/.harness/hooks', project / '.claude/hooks')
    for feature in ('dev-a', 'dev-b'):
        context = project / 'features' / feature / 'CLAUDE.md'
        context.parent.mkdir(parents=True)
        context.write_text(f'# {feature}\n')
    current = project / 'CURRENT_FEATURE'
    current.write_text('dev-a\n')
    settings = json.loads((root / 'claude-code/features/.harness/settings.json').read_text())
    snapshot = fixture / '.aosp-harness-demo.feature-snapshot'

    def hook(event):
        command = settings['hooks'][event][0]['hooks'][0]['command']
        result = subprocess.run(['bash', '-c', command], cwd=project,
                                env=dict(environment, CLAUDE_PROJECT_DIR=str(project)),
                                input=json.dumps({'session_id': 'test-session', 'hook_event_name': event,
                                                  'reason': 'other'}),
                                text=True, capture_output=True, timeout=20)
        assert result.returncode == 0, result
        return result.stdout

    hook('SessionStart')
    assert snapshot.read_text() == 'dev-a'
    assert (project / 'CLAUDE.md').resolve() == project / 'features/dev-a/CLAUDE.md'
    assert hook('UserPromptSubmit') == ''
    current.write_text('dev-b\n')
    assert '分支漂移' in hook('UserPromptSubmit')
    hook('SessionEnd')
    assert not snapshot.exists()
    print('PASS  configured hooks support paths with spaces and clean up state')

    # Execute Cursor hooks.json commands, including drift deny/continue payloads.
    cursor_project = fixture / 'cursor tree with spaces'
    shutil.copytree(root / 'cursor-agent/features/.harness/cursor/hooks',
                    cursor_project / '.cursor/hooks')
    for feature in ('dev-a', 'dev-b'):
        context = cursor_project / 'features' / feature / 'AGENTS.md'
        context.parent.mkdir(parents=True)
        context.write_text(f'# {feature}\n')
    cursor_current = cursor_project / 'CURRENT_FEATURE'
    cursor_current.write_text('dev-a\n')
    cursor_hooks = json.loads(
        (root / 'cursor-agent/features/.harness/cursor/hooks.json').read_text())
    cursor_state = fixture / 'cursor-state'

    def cursor_hook(event):
        command = cursor_project / cursor_hooks['hooks'][event][0]['command']
        result = subprocess.run(['bash', str(command)], cwd=cursor_project,
                                env=dict(environment, HARNESS_ROOT=str(cursor_project),
                                         CURSOR_HARNESS_STATE_DIR=str(cursor_state)),
                                input=json.dumps({'session_id': 'test-session',
                                                  'hook_event_name': event}),
                                text=True, capture_output=True, timeout=20)
        assert result.returncode == 0, result
        return result.stdout

    assert cursor_hook('sessionStart') == ''
    assert (cursor_state / 'test-session.feature').read_text() == 'dev-a\n'
    assert cursor_hook('beforeSubmitPrompt') == ''
    cursor_current.write_text('dev-b\n')
    prompt_stop = json.loads(cursor_hook('beforeSubmitPrompt'))
    assert prompt_stop['continue'] is False
    assert 'dev-a' in prompt_stop['user_message'] and 'dev-b' in prompt_stop['user_message']
    tool_stop = json.loads(cursor_hook('preToolUse'))
    assert tool_stop['permission'] == 'deny'
    assert 'dev-a' in tool_stop['agent_message'] and 'dev-b' in tool_stop['agent_message']
    print('PASS  Cursor hooks.json commands support paths with spaces')

    # Execute ZCode config.json hook commands, including the exit-2 drift block.
    zcode_project = fixture / 'zcode tree with spaces'
    shutil.copytree(root / 'zcode/features/.harness/zcode/hooks',
                    zcode_project / '.zcode/hooks')
    for feature in ('dev-a', 'dev-b'):
        context = zcode_project / 'features' / feature / 'AGENTS.md'
        context.parent.mkdir(parents=True)
        context.write_text(f'# {feature}\n')
    zcode_current = zcode_project / 'CURRENT_FEATURE'
    zcode_current.write_text('dev-a\n')
    (zcode_project / 'AGENTS.md').symlink_to('features/dev-a/AGENTS.md')
    zcode_config = json.loads(
        (root / 'zcode/features/.harness/zcode/config.json').read_text())
    zcode_state = fixture / 'zcode-state'

    def zcode_hook(source):
        event = 'UserPromptSubmit' if source == 'prompt' else 'SessionStart'
        groups = zcode_config['hooks']['events'][event]
        command = [h['command'] for group in groups
                   if event != 'SessionStart' or re.search(group.get('matcher', ''), source)
                   for h in group['hooks']][0]
        return subprocess.run(['bash', '-c', command], cwd=zcode_project,
                              env=dict(environment, ZCODE_PROJECT_DIR=str(zcode_project),
                                       HARNESS_ROOT=str(zcode_project),
                                       ZCODE_HARNESS_STATE_DIR=str(zcode_state)),
                              input=json.dumps({'session_id': 'test-session',
                                                'cwd': str(zcode_project),
                                                'hook_event_name': event, 'source': source}),
                              text=True, capture_output=True, timeout=20)

    started = zcode_hook('startup')
    assert started.returncode == 0, started
    assert (zcode_state / 'test-session.feature').read_text() == 'dev-a\n'
    assert zcode_hook('prompt').returncode == 0
    zcode_current.write_text('dev-b\n')
    stopped = zcode_hook('prompt')
    assert stopped.returncode == 2, stopped
    assert stopped.stdout == '', stopped.stdout
    assert 'AGENTS.md was not prepared for the active feature' in stopped.stderr, stopped.stderr
    assert 'NEW ZCode session' in stopped.stderr, stopped.stderr
    print('PASS  ZCode config.json hook commands support paths with spaces')

print('RESULT PASS  runtime contracts')
PY
