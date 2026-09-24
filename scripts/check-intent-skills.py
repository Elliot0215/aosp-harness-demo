#!/usr/bin/env python3
"""Check active Harness references against the current intent skill interface."""

import argparse
import re
import sys
from pathlib import Path


CURRENT_SKILLS = {
    "intent",
    "intent-roadmap",
    "intent-plan",
    "intent-bugfix",
    "intent-explain",
    "intent-implement",
    "intent-review",
    "intent-retrospect",
}
HANDOFF_SKILLS = {
    "intent-roadmap",
    "intent-plan",
    "intent-implement",
    "intent-review",
}
CLIENTS = {
    "claude-code": ("features/dev-sidebar/CLAUDE.md", "/"),
    "codex": ("features/dev-sidebar/AGENTS.md", "$"),
    "cursor-agent": ("features/dev-sidebar/AGENTS.md", "/"),
    "zcode": ("features/dev-sidebar/AGENTS.md", "$"),
}
ACTIVE_PATHS = [
    "README.md",
    "skills/build-aosp-harness/SKILL.md",
    "skills/build-aosp-harness/references/intent-cooperation.md",
    "skills/build-aosp-harness/references/feature-contract.md",
    "skills/build-aosp-harness/references/validation.md",
]
for client, (feature, _) in CLIENTS.items():
    ACTIVE_PATHS.extend(
        (f"{client}/README.md", f"{client}/{feature}",
         f"docs/AOSP整机源码Harness工程探索-{client if client != 'claude-code' else 'claude'}版.md")
    )
    adapter = {
        "claude-code": "skills",
        "codex": "skills",
        "cursor-agent": "cursor/skills",
        "zcode": "zcode/skills",
    }[client]
    for skill in ("build-services-jar", "build-sepolicy"):
        ACTIVE_PATHS.append(f"{client}/features/.harness/{adapter}/{skill}/SKILL.md")

CALL = re.compile(r"`([$/])(intent(?:-[a-z][a-z0-9-]*))(?=[\s`])")
OLD_INTERFACE = re.compile(
    r"intent-requirement|全自动 intent|intent 全自动|逐步或全自动|全自动模式|"
    r"[Ff]ully automatic intent"
)
NAME = re.compile(r"^name:\s*([a-z][a-z0-9-]*)\s*$", re.MULTILINE)


def installed_names(intent_root):
    skill_root = intent_root / "skills"
    if not skill_root.is_dir():
        raise ValueError(f"missing intent skills directory: {skill_root}")
    names = set()
    for skill_file in sorted(skill_root.glob("intent*/SKILL.md")):
        match = NAME.search(skill_file.read_text(encoding="utf-8"))
        if not match:
            raise ValueError(f"missing skill name: {skill_file}")
        names.add(match.group(1))
    if not names:
        raise ValueError(f"no intent skills found: {skill_root}")
    return names


def check(root, intent_root=None):
    errors = []
    references = {}
    for relative in ACTIVE_PATHS:
        path = root / relative
        if not path.is_file():
            errors.append(f"missing active document: {relative}")
            continue
        content = path.read_text(encoding="utf-8")
        old = OLD_INTERFACE.search(content)
        if old:
            line = content.count("\n", 0, old.start()) + 1
            errors.append(f"{relative}:{line}: obsolete intent interface: {old.group()}")
        calls = []
        for match in CALL.finditer(content):
            line = content.count("\n", 0, match.start()) + 1
            calls.append((match.group(1), match.group(2), line))
            if match.group(2) not in CURRENT_SKILLS:
                errors.append(f"{relative}:{line}: unknown intent skill: {match.group(2)}")
        references[relative] = calls

    canonical = "skills/build-aosp-harness/references/intent-cooperation.md"
    for skill in sorted(HANDOFF_SKILLS - {name for _, name, _ in references.get(canonical, [])}):
        errors.append(f"{canonical}: missing handoff skill: {skill}")
    for client, (feature, prefix) in CLIENTS.items():
        relative = f"{client}/{feature}"
        calls = {(marker, name) for marker, name, _ in references.get(relative, [])}
        for skill in sorted(HANDOFF_SKILLS):
            if (prefix, skill) not in calls:
                errors.append(f"{relative}: missing {prefix}{skill} invocation")

    if intent_root is not None:
        try:
            actual = installed_names(intent_root)
        except ValueError as error:
            errors.append(str(error))
        else:
            for relative, calls in references.items():
                for _, name, line in calls:
                    if name not in actual:
                        errors.append(f"{relative}:{line}: skill absent from intent source: {name}")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--intent-root", type=Path, help="optional adjacent intent checkout")
    args = parser.parse_args()
    errors = check(args.root, args.intent_root)
    if errors:
        for error in errors:
            print(f"INTENT FAIL  {error}", file=sys.stderr)
        return 1
    print("RESULT PASS  intent skill references")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
