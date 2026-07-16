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
ALLOWED_CATEGORIES = {"Codex Tools", "Development", "Design", "Productivity", "Other"}


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
    nested_metadata = metadata.get("metadata")
    version = metadata.get("version")
    if version is None and isinstance(nested_metadata, dict):
        version = nested_metadata.get("version")
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


def validate_plugin(path: Path, repository_root: Path | None = None) -> ValidationReport:
    path = Path(path).resolve()
    report = ValidationReport()
    readme_path = path / "README.md"
    manifest_path = path / ".codex-plugin" / "plugin.json"
    skills_root = path / "skills"
    if not readme_path.is_file():
        report.errors.append("Plugin README.md is required")
    else:
        readme = readme_path.read_text(encoding="utf-8")
        required_sections = {
            "description": r"(?im)^##+\s+(?:description|描述)",
            "install": r"(?im)^##+\s+(?:install|安装)",
            "invoke": r"(?im)^##+\s+(?:invoke|usage|调用|使用)",
            "update": r"(?im)^##+\s+(?:update|更新)",
            "uninstall": r"(?im)^##+\s+(?:uninstall|卸载)",
        }
        for label, pattern in required_sections.items():
            if not re.search(pattern, readme):
                report.errors.append(f"Plugin README.md is missing the {label} section")
    manifest: dict[str, object] = {}
    if not manifest_path.is_file():
        report.errors.append(".codex-plugin/plugin.json is required")
    else:
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            report.errors.append(f"plugin.json is invalid JSON: {exc}")
    plugin_name = manifest.get("name")
    if plugin_name and plugin_name != path.name:
        report.errors.append("plugin manifest name must match the Plugin folder")
    if manifest and manifest.get("skills") != "./skills/":
        report.errors.append("plugin manifest skills must be ./skills/")
    skill_dirs = sorted(item for item in skills_root.iterdir() if item.is_dir()) if skills_root.is_dir() else []
    if not skill_dirs:
        report.errors.append("Plugin must contain at least one Skill folder")
    for skill_dir in skill_dirs:
        child_report = validate_skill(skill_dir)
        report.errors.extend(f"{skill_dir.name}: {message}" for message in child_report.errors)
        report.warnings.extend(f"{skill_dir.name}: {message}" for message in child_report.warnings)
        skill_md = skill_dir / "SKILL.md"
        if skill_md.is_file():
            metadata, _, _ = _parse_frontmatter(skill_md.read_text(encoding="utf-8"))
            nested_metadata = metadata.get("metadata")
            skill_version = metadata.get("version")
            if skill_version is None and isinstance(nested_metadata, dict):
                skill_version = nested_metadata.get("version")
            if skill_version is not None and manifest.get("version") != skill_version:
                report.errors.append("plugin manifest version must match the Skill frontmatter version")
        if not (skill_dir / "agents" / "openai.yaml").is_file():
            report.errors.append(f"{skill_dir.name}: agents/openai.yaml is required")
    if repository_root is not None:
        root = Path(repository_root).resolve()
        marketplace_path = root / ".agents" / "plugins" / "marketplace.json"
        try:
            marketplace = json.loads(marketplace_path.read_text(encoding="utf-8"))
            entry = next((item for item in marketplace.get("plugins", []) if item.get("name") == path.name), None)
        except (OSError, json.JSONDecodeError):
            entry = None
        if entry is None:
            report.errors.append("Marketplace entry is required")
        else:
            if entry.get("source", {}).get("path") != f"./plugins/{path.name}":
                report.errors.append("Marketplace source path must match the Plugin folder")
            if entry.get("category") not in ALLOWED_CATEGORIES:
                report.errors.append("Marketplace category is invalid")
        root_readme = root / "README.md"
        expected_link = f"plugins/{path.name}/README.md"
        if not root_readme.is_file() or expected_link not in root_readme.read_text(encoding="utf-8"):
            report.errors.append("root README.md must index the Plugin README")
    if report.valid:
        report.passed.append("Plugin, Skills, README, manifest, and Marketplace metadata are valid")
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--plugin", action="store_true")
    parser.add_argument("--repository-root", type=Path)
    args = parser.parse_args(argv)
    try:
        report = validate_plugin(args.path, args.repository_root) if args.plugin else validate_skill(args.path)
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
