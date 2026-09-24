#!/usr/bin/env bash
# Shared CLI/App boundary: never select or reload context from a hook.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="${HARNESS_ROOT:-$(cd "$SCRIPT_DIR/../../../.." && pwd -P)}"
STATE_DIR="${CODEX_HARNESS_STATE_DIR:-${TMPDIR:-/tmp}/aosp-codex-harness-$UID}"
source "$SCRIPT_DIR/feature-common.sh"

stop() {
  python3 - "$1" <<'PY'
import json
import sys
print(json.dumps({
    "continue": False,
    "stopReason": sys.argv[1],
    "systemMessage": "Run ./.codex/bin/prepare-feature in the AOSP root, then create a NEW App task in that directory; for CLI use ./.codex/bin/codex-feature. Do not resume the old task after switching features.",
}))
PY
  exit 0
}

payload="$(cat)"
if ! parsed="$(python3 -c '
import json, pathlib, re, sys
try:
    data = json.load(sys.stdin)
    session = data["session_id"]
    if not isinstance(session, str) or re.fullmatch(r"[A-Za-z0-9._-]{1,128}", session) is None or session in (".", ".."):
        raise ValueError("invalid session")
    if pathlib.Path(data["cwd"]).resolve(strict=True) != pathlib.Path(sys.argv[1]).resolve(strict=True):
        raise ValueError("wrong cwd")
    event = data["hook_event_name"]
    if event not in ("SessionStart", "UserPromptSubmit"):
        raise ValueError("invalid event")
    source = data.get("source", "") if event == "SessionStart" else "prompt"
    if event == "SessionStart" and source not in ("startup", "resume", "clear", "compact"):
        raise ValueError("invalid source")
    print(session + " " + source)
except (KeyError, TypeError, ValueError, OSError, RuntimeError):
    sys.exit(1)
' "$ROOT" <<<"$payload" 2>/dev/null)"; then
  stop 'AOSP context guard: invalid hook input or task cwd is not the prepared tree root.'
fi
session_id="${parsed% *}"
source_name="${parsed##* }"

if ! feature="$(detect_feature "$ROOT")" || ! target="$(feature_context_path "$ROOT" "$feature")"; then
  stop 'AOSP context guard: active feature is unavailable.'
fi
if [[ ! -L "$ROOT/AGENTS.md" || "$(readlink "$ROOT/AGENTS.md")" != "$target" ]]; then
  stop 'AOSP context guard: AGENTS.md was not prepared for the active feature.'
fi
if [[ -d "$ROOT/.repo" ]]; then
  checker="$ROOT/features/$feature/check-branch.sh"
  if [[ ! -x "$checker" ]] || ! HARNESS_ROOT="$ROOT" FEATURE_NAME="$feature" "$checker" >&2; then
    stop 'AOSP context guard: involved repository branch validation failed.'
  fi
fi

# Resume/compact/clear must check the original snapshot, never establish a new
# baseline. A repeated startup for the same id must not overwrite it either.
snapshot="$STATE_DIR/$session_id.feature"
if [[ "$source_name" == startup && ! -e "$snapshot" && ! -L "$snapshot" ]]; then
  if ! "$SCRIPT_DIR/session-start.sh" <<<"$payload"; then
    stop 'AOSP context guard: unable to record the initial feature snapshot.'
  fi
fi
if ! result="$("$SCRIPT_DIR/check-branch-drift.sh" <<<"$payload")"; then
  stop 'AOSP context guard: session consistency check failed.'
fi
if [[ -n "$result" ]]; then
  if ! reason="$(python3 -c 'import json, sys; print(json.load(sys.stdin)["stopReason"])' <<<"$result" 2>/dev/null)"; then
    stop 'AOSP context guard: invalid consistency check response.'
  fi
  stop "$reason"
fi
