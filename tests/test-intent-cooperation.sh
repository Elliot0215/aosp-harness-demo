#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P)"
python3 - "$repo_root" <<'PY'
import importlib.util
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(sys.argv[1])
checker = root / "scripts/check-intent-skills.py"
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("intent_checker", checker)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def run(*args):
    return subprocess.run(
        [sys.executable, str(checker), *map(str, args)],
        text=True, capture_output=True, check=False,
    )


assert run().returncode == 0
with tempfile.TemporaryDirectory(prefix="harness-intent-") as temporary:
    fixture = Path(temporary) / "harness"
    for relative in module.ACTIVE_PATHS:
        target = fixture / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / relative, target)

    assert run("--root", fixture).returncode == 0
    feature = fixture / "codex/features/dev-sidebar/AGENTS.md"
    original = feature.read_text(encoding="utf-8")
    assert "$intent-plan" in original
    feature.write_text(original.replace("$intent-plan", "$intent-missing", 1), encoding="utf-8")
    result = run("--root", fixture)
    assert result.returncode == 1 and "unknown intent skill: intent-missing" in result.stderr, result
    feature.write_text(original, encoding="utf-8")

    intent = Path(temporary) / "intent"
    for name in module.CURRENT_SKILLS - {"intent-plan"}:
        skill = intent / "skills" / name / "SKILL.md"
        skill.parent.mkdir(parents=True, exist_ok=True)
        skill.write_text(f"---\nname: {name}\n---\n", encoding="utf-8")
    result = run("--root", fixture, "--intent-root", intent)
    assert result.returncode == 1 and "skill absent from intent source: intent-plan" in result.stderr, result
    skill = intent / "skills/intent-plan/SKILL.md"
    skill.parent.mkdir(parents=True, exist_ok=True)
    skill.write_text("---\nname: intent-plan\n---\n", encoding="utf-8")
    assert run("--root", fixture, "--intent-root", intent).returncode == 0

print("RESULT PASS  intent cooperation contract")
PY
