#!/usr/bin/env python3
"""Static packaging/security audit for CodeSentry-Roblox.

This is a source-tree audit only. It does not parse/execute Luau or emulate Studio.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

REQUIRED_FILES = [
    "README.md",
    "TEST_REPORT.md",
    "LICENSE",
    "default.project.json",
    "src/Shared/Config.lua",
    "src/Shared/Detector.lua",
    "src/Shared/Formatter.lua",
    "src/Shared/History.lua",
    "src/Shared/Processor.lua",
    "src/Shared/Types.lua",
    "src/Client/Main.client.lua",
    "src/Client/UIController.lua",
    "src/Client/ThemeController.lua",
    "src/Client/NotificationController.lua",
    "src/Tests/DetectorTests.lua",
    "src/Tests/HistoryTests.lua",
    "src/Tests/IntegrationTests.lua",
    "src/Tests/TestRunner.lua",
    "docs/Installation.md",
    "docs/Architecture.md",
    "docs/Testing.md",
    "docs/OriginalProjectReview.md",
    "docs/CodeAudit.md",
    ".github/workflows/quality.yml",
    "tools/audit_bundle.py",
]

FORBIDDEN_PATTERNS = {
    "dynamic source execution": re.compile(r"\bloadstring\s*\(", re.IGNORECASE),
    "executor environment access": re.compile(r"\b(getgenv|getrenv|identifyexecutor)\s*\(", re.IGNORECASE),
    "executor filesystem access": re.compile(r"\b(readfile|writefile|appendfile|isfile|isfolder|makefolder)\s*\(", re.IGNORECASE),
    "executor hook API": re.compile(r"\b(hookfunction|getrawmetatable|setreadonly)\s*\(", re.IGNORECASE),
    "remote invocation": re.compile(r"\b(FireServer|InvokeServer)\s*\(", re.IGNORECASE),
    "external code download": re.compile(r"\b(HttpGet|GetObjects)\s*\(", re.IGNORECASE),
    "filesystem I/O": re.compile(r"\b(io\.open|os\.execute|loadfile)\s*\(", re.IGNORECASE),
}

UNFINISHED_MARKERS = re.compile(r"\b(TODO|FIXME|IMPLEMENT ME|PLACEHOLDER IMPLEMENTATION|NOT IMPLEMENTED)\b", re.IGNORECASE)


def main() -> int:
    failures: list[str] = []
    checks = 0

    for relative in REQUIRED_FILES:
        checks += 1
        path = ROOT / relative
        if not path.is_file():
            failures.append(f"Missing required file: {relative}")
        elif path.stat().st_size == 0:
            failures.append(f"Required file is empty: {relative}")

    checks += 1
    project_path = ROOT / "default.project.json"
    try:
        project = json.loads(project_path.read_text(encoding="utf-8"))
        if project.get("name") != "CodeSentry-Roblox":
            failures.append("Rojo project name is not CodeSentry-Roblox")
        tree = project.get("tree", {})
        if tree.get("$className") != "DataModel":
            failures.append("Rojo tree root must be a DataModel")
        for expected_path in ("src/Shared", "src/Tests", "src/Client"):
            if not (ROOT / expected_path).is_dir():
                failures.append(f"Rojo mapped folder does not exist: {expected_path}")
    except (OSError, json.JSONDecodeError) as exc:
        failures.append(f"Invalid default.project.json: {exc}")

    scripts = sorted((ROOT / "src").rglob("*.lua"))
    checks += len(scripts)
    if len(scripts) < 14:
        failures.append(f"Expected at least 14 Luau source/test files, found {len(scripts)}")

    for path in scripts:
        source = path.read_text(encoding="utf-8")
        relative = path.relative_to(ROOT).as_posix()
        for label, pattern in FORBIDDEN_PATTERNS.items():
            if pattern.search(source):
                failures.append(f"Forbidden {label} pattern in {relative}")
        if UNFINISHED_MARKERS.search(source):
            failures.append(f"Unfinished marker found in {relative}")

    test_sources = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted((ROOT / "src/Tests").glob("*.lua"))
    )
    test_count = len(re.findall(r'\btest\s*\(\s*"', test_sources))
    checks += 1
    if test_count < 25:
        failures.append(f"Expected at least 25 named Studio test cases, found {test_count}")

    checks += 1
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    for phrase in ("Roblox Studio", "in memory", "known limitations", "studio test runner"):
        if phrase.lower() not in readme.lower():
            failures.append(f"README missing required explanation: {phrase}")

    if failures:
        print(f"STATIC AUDIT FAILED: {len(failures)} issue(s) across {checks} checks")
        for failure in failures:
            print(f"FAIL: {failure}")
        return 1

    print(f"STATIC AUDIT PASSED: {checks} checks; {len(scripts)} Luau files; {test_count} named Studio tests")
    print("Scope: file/package/security-pattern checks only; Luau compilation and Roblox Studio runtime are not executed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
