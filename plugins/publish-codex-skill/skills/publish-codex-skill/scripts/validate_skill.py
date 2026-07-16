#!/usr/bin/env python3
"""Validate Codex Skill folders without third-party dependencies."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
SEMVER_RE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$")
LINK_RE = re.compile(r"(?<!!)\[[^]]*]\(([^)]+)\)")
SENSITIVE_NAMES = {".env", ".env.local", "id_rsa", "id_ed25519"}


class ValidationReport:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []
        self.passed: list[str] = []

    @property
    def valid(self) -> bool:
        return not self.errors

    def to_json(self) -> str:
        return json.dumps(
            {"valid": self.valid, "errors": self.errors, "warnings": self.warnings, "passed": self.passed},
            ensure_ascii=False,
            indent=2,
        )


def _parse_frontmatter(content: str) -> tuple[dict[str, object], str, list[str]]:
    errors: list[str] = []
    if not content.startswith("---\n"):
        return {}, content, ["SKILL.md must start with YAML frontmatter"]
    end = content.find("\n---", 4)
    if end < 0:
        return {}, content, ["SKILL.md YAML frontmatter is not closed"]
    raw = content[4:end]
    body = content[end + 4 :].strip()
    metadata: dict[str, object] = {}
    current_mapping: dict[str, str] | None = None
    for line in raw.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line.startswith((" ", "\t")):
            if current_mapping is None or ":" not in line:
                errors.append(f"unsupported YAML line: {line.strip()}")
                continue
            key, value = line.strip().split(":", 1)
            current_mapping[key.strip()] = value.strip().strip("\"'")
            continue
        if ":" not in line:
            errors.append(f"invalid YAML field: {line}")
            current_mapping = None
            continue
        key, value = line.split(":", 1)
        key, value = key.strip(), value.strip()
        if value:
            metadata[key] = value.strip("\"'")
            current_mapping = None
        else:
            current_mapping = {}
            metadata[key] = current_mapping
    return metadata, body, errors


def validate_skill(path: Path) -> ValidationReport:
    path = Path(path).resolve()
    report = ValidationReport()
    if not path.is_dir():
        report.errors.append(f"skill folder does not exist: {path}")
        return report
    if not NAME_RE.fullmatch(path.name):
        report.errors.append("skill folder name must use lowercase letters, numbers, and hyphens")
    skill_md = path / "SKILL.md"
    if not skill_md.is_file():
        report.errors.append("SKILL.md is required")
        return report
    content = skill_md.read_text(encoding="utf-8")
    metadata, body, parse_errors = _parse_frontmatter(content)
    report.errors.extend(parse_errors)
    name = metadata.get("name")
    description = metadata.get("description")
    version = metadata.get("version")
    if not isinstance(name, str) or not name:
        report.errors.append("frontmatter name is required")
    elif name != path.name:
        report.errors.append("frontmatter name must match the skill folder name")
    elif len(name) >= 64:
        report.errors.append("skill name must be shorter than 64 characters")
    if not isinstance(description, str) or not description.strip():
        report.errors.append("frontmatter description is required")
    elif len(description) > 1024:
        report.errors.append("frontmatter description must not exceed 1024 characters")
    elif "use when" not in description.lower():
        report.warnings.append("description should state a clear 'Use when' trigger")
    if version is None:
        report.warnings.append("frontmatter version is recommended")
    elif not isinstance(version, str) or not SEMVER_RE.fullmatch(version):
        report.errors.append("frontmatter version must be a strict semantic version")
    if not body:
        report.errors.append("SKILL.md body must not be empty")
    if re.search(r"\b(?:TODO|TBD)\b|\[[A-Z_ -]+\]", body, re.IGNORECASE):
        report.errors.append("SKILL.md contains a template placeholder")
    for target in LINK_RE.findall(body):
        target = target.split("#", 1)[0]
        if not target or re.match(r"^(?:https?://|mailto:|#)", target):
            continue
        if not (path / target).resolve().is_file():
            report.errors.append(f"missing local link target: {target}")
    for candidate in path.rglob("*"):
        lowered = candidate.name.lower()
        if candidate.is_file() and (
            lowered in SENSITIVE_NAMES
            or lowered.endswith((".pem", ".key", ".bak", ".tmp"))
            or "credential" in lowered
        ):
            report.errors.append(f"sensitive or temporary file is not publishable: {candidate.relative_to(path)}")
    if report.valid:
        report.passed.append("skill structure and SKILL.md are valid")
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    try:
        report = validate_skill(args.path)
    except (OSError, UnicodeError) as exc:
        print(json.dumps({"valid": False, "runtime_error": str(exc)}) if args.json else f"ERROR: {exc}")
        return 2
    if args.json:
        print(report.to_json())
    else:
        for message in report.passed:
            print(f"PASS: {message}")
        for message in report.warnings:
            print(f"WARN: {message}")
        for message in report.errors:
            print(f"FAIL: {message}")
    return 0 if report.valid else 1


if __name__ == "__main__":
    sys.exit(main())
