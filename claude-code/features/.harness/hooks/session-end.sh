#!/usr/bin/env bash
# ① 上下文层 · SessionEnd：校验事件名/session ID/reason 后清理 Demo 快照。
set -euo pipefail

prc=0
python3 -c '
import json, re, sys
try:
    d = json.load(sys.stdin)
    ev, sid, reason = d["hook_event_name"], d["session_id"], d["reason"]
except Exception:
    sys.exit(3)
if (ev != "SessionEnd" or not isinstance(sid, str)
        or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", sid)
        or reason not in ("clear", "resume", "logout", "prompt_input_exit", "other")):
    sys.exit(3)
' || prc=$?

if [[ $prc != 0 ]]; then
  cat >/dev/null 2>&1 || true
  exit 0
fi

rm -f -- "${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot" 2>/dev/null || true
