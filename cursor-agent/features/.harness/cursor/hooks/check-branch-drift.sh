#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd -P)"
source "$SCRIPT_DIR/feature-common.sh"

ROOT="${HARNESS_ROOT:-$DEFAULT_ROOT}"
STATE_DIR="${CURSOR_HARNESS_STATE_DIR:-${TMPDIR:-/tmp}/aosp-cursor-harness-$UID}"
SYSTEM_MESSAGE='Run ./.cursor/bin/prepare-feature in the tree root, then start a NEW Agent chat in the Cursor IDE. For CLI, restart with ./.cursor/bin/cursor-feature. Do not resume the old chat after switching features.'

parse_hook_input() {
  python3 -c '
import json
import re
import sys

try:
    data = json.load(sys.stdin)
except (json.JSONDecodeError, TypeError):
    raise SystemExit(1)
session_id = data.get("session_id") or data.get("conversation_id")
if session_id is None:
    raise SystemExit(1)

if not isinstance(session_id, str):
    raise SystemExit(1)
if not 1 <= len(session_id) <= 128:
    raise SystemExit(1)
if session_id in (".", ".."):
    raise SystemExit(1)
if re.fullmatch(r"[A-Za-z0-9._-]+", session_id) is None:
    raise SystemExit(1)
event = data.get("hook_event_name") or ""
if not isinstance(event, str):
    raise SystemExit(1)
if event and re.fullmatch(r"[A-Za-z0-9._-]+", event) is None:
    raise SystemExit(1)
sys.stdout.buffer.write(session_id.encode("ascii") + b"\n" + event.encode("ascii"))
'
}

prepare_state_dir() {
  python3 - "$1" <<'PY'
import os
import stat
import sys

raw_path = sys.argv[1]
if not raw_path or any(ord(character) < 32 or ord(character) == 127 for character in raw_path):
    raise SystemExit(1)
raw_components = raw_path.split(os.sep)
if any(component in (".", "..") for component in raw_components):
    raise SystemExit(1)

components = [component for component in raw_components if component]
if not components:
    raise SystemExit(1)

absolute = os.path.isabs(raw_path)
normalized = os.path.join(*components)
if absolute:
    normalized = os.sep + normalized

open_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
if hasattr(os, "O_CLOEXEC"):
    open_flags |= os.O_CLOEXEC

directory_fd = os.open(os.sep if absolute else ".", open_flags)
try:
    for component in components:
        created = False
        try:
            component_stat = os.lstat(component, dir_fd=directory_fd)
        except FileNotFoundError:
            try:
                os.mkdir(component, mode=0o700, dir_fd=directory_fd)
                created = True
            except FileExistsError:
                pass
            component_stat = os.lstat(component, dir_fd=directory_fd)

        if stat.S_ISLNK(component_stat.st_mode):
            raise SystemExit(1)
        if not stat.S_ISDIR(component_stat.st_mode):
            raise SystemExit(1)

        next_fd = os.open(component, open_flags, dir_fd=directory_fd)
        os.close(directory_fd)
        directory_fd = next_fd
        if created:
            os.fchmod(directory_fd, 0o700)
            created_stat = os.fstat(directory_fd)
            if created_stat.st_uid != os.getuid():
                raise SystemExit(1)
            if stat.S_IMODE(created_stat.st_mode) != 0o700:
                raise SystemExit(1)

    final_stat = os.fstat(directory_fd)
    if final_stat.st_uid != os.getuid():
        raise SystemExit(1)
    os.fchmod(directory_fd, 0o700)
    final_stat = os.fstat(directory_fd)
    if not stat.S_ISDIR(final_stat.st_mode):
        raise SystemExit(1)
    if stat.S_IMODE(final_stat.st_mode) != 0o700:
        raise SystemExit(1)
finally:
    os.close(directory_fd)

sys.stdout.buffer.write(os.fsencode(normalized))
PY
}

emit_stop() {
  local stop_reason="$1"
  local system_message="$2"
  local event="${HOOK_EVENT_NAME:-}"

  python3 - "$stop_reason" "$system_message" "$event" <<'PY'
import json
import sys

stop_reason, system_message, event = sys.argv[1:]
deny_events = {
    "preToolUse",
    "beforeReadFile",
    "beforeShellExecution",
    "beforeMCPExecution",
}
if event in deny_events:
    payload = {
        "permission": "deny",
        "user_message": system_message,
        "agent_message": stop_reason + " " + system_message,
    }
else:
    payload = {
        "continue": False,
        "user_message": stop_reason + " " + system_message,
    }
sys.stdout.buffer.write((json.dumps(payload) + "\n").encode("utf-8"))
PY
}

HOOK_EVENT_NAME=''
if ! parsed="$(parse_hook_input 2>/dev/null)"; then
  emit_stop \
    'AOSP feature guard: invalid hook input; session consistency cannot be verified.' \
    "$SYSTEM_MESSAGE"
  exit 0
fi
session_id="${parsed%%$'\n'*}"
HOOK_EVENT_NAME="${parsed#*$'\n'}"
if [[ "$session_id" == "$parsed" ]]; then
  HOOK_EVENT_NAME=''
fi

if ! feature="$(detect_feature "$ROOT")"; then
  emit_stop \
    'AOSP feature guard: current feature context is unavailable.' \
    "$SYSTEM_MESSAGE"
  exit 0
fi
if ! feature_context_path "$ROOT" "$feature" >/dev/null; then
  emit_stop \
    'AOSP feature guard: current feature context is unavailable.' \
    "$SYSTEM_MESSAGE"
  exit 0
fi

umask 077
if ! STATE_DIR="$(prepare_state_dir "$STATE_DIR" 2>/dev/null)"; then
  emit_stop \
    'AOSP feature guard: session state is unavailable or unsafe.' \
    "$SYSTEM_MESSAGE"
  exit 0
fi

snapshot="$STATE_DIR/$session_id.feature"
if [[ ! -e "$snapshot" && ! -L "$snapshot" ]]; then
  emit_stop \
    "AOSP feature snapshot is missing for session '$session_id'. Restart the Cursor Agent session before continuing." \
    "$SYSTEM_MESSAGE"
  exit 0
fi
if [[ -L "$snapshot" || ! -f "$snapshot" || ! -O "$snapshot" || ! -r "$snapshot" ]]; then
  emit_stop \
    'AOSP feature guard: session feature snapshot is unsafe, unreadable, or invalid.' \
    "$SYSTEM_MESSAGE"
  exit 0
fi

if ! snapshot_feature="$(
  python3 - "$snapshot" 2>/dev/null <<'PY'
import re
import sys

try:
    data = open(sys.argv[1], "rb").read()
except OSError:
    raise SystemExit(1)
match = re.fullmatch(rb"([A-Za-z0-9][A-Za-z0-9._-]*)(?:\n)?", data)
if match is None:
    raise SystemExit(1)
sys.stdout.buffer.write(match.group(1))
PY
)"; then
  emit_stop \
    'AOSP feature guard: session feature snapshot is unsafe, unreadable, or invalid.' \
    "$SYSTEM_MESSAGE"
  exit 0
fi

if [[ "$snapshot_feature" == "$feature" ]]; then
  exit 0
fi

emit_stop \
  "AOSP feature drift: session started on '$snapshot_feature', current feature is '$feature'." \
  "$SYSTEM_MESSAGE"
