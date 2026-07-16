# Publish Codex Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a cross-platform `publish-codex-skill` Plugin that validates Skill packages and only publishes approved changes to `WuChaoli/wonderful-codex-skills` after an explicit confirmation gate.

**Architecture:** Use Python standard-library modules for portable validation and publishing. Keep validation pure and reusable, while the publisher prepares repository changes, hashes the exact staged intent, and requires that hash during apply before invoking Git.

**Tech Stack:** Python 3 standard library, `unittest`, Git, Codex Plugin Marketplace JSON/YAML-compatible metadata, GitHub Actions.

## Global Constraints

- Target repository is fixed to `WuChaoli/wonderful-codex-skills`.
- Runtime must support Windows, macOS, and Linux.
- `SKILL.md` requires `name` and `description`, permits extra YAML fields, and recommends a strict-semver `version` field.
- No commit or push may occur before explicit user confirmation.
- No force push, credential mutation, unrelated staging, or third-party Python dependencies.

---

### Task 1: Cross-platform Skill validator

**Files:**
- Create: `tests/test_validate_skill.py`
- Create: `plugins/publish-codex-skill/skills/publish-codex-skill/scripts/validate_skill.py`

**Interfaces:**
- Produces: `validate_skill(path: Path) -> ValidationReport`, `validate_plugin(path: Path, repository_root: Path | None = None) -> ValidationReport`, and CLI `validate_skill.py PATH [--plugin] [--repository-root PATH] [--json]`.

- [ ] Write failing `unittest` cases for a valid Skill, missing `SKILL.md`, invalid folder name, mismatched name, extra frontmatter fields, strict-semver version, placeholders, missing relative links, and sensitive files.
- [ ] Run `python -m unittest tests.test_validate_skill -v`; verify failure because the validator module does not exist.
- [ ] Implement a standard-library parser, structured findings, stable exit codes `0`, `1`, and `2`, plus text and JSON renderers.
- [ ] Run the validator tests and verify all cases pass.
- [ ] Commit with `开发：新增跨平台 Skill 结构审查器`.

### Task 2: Plugin and Marketplace contract validation

**Files:**
- Modify: `tests/test_validate_skill.py`
- Modify: `plugins/publish-codex-skill/skills/publish-codex-skill/scripts/validate_skill.py`

**Interfaces:**
- Consumes: `ValidationReport` from Task 1.
- Produces: validation for Plugin README sections, `.codex-plugin/plugin.json`, `agents/openai.yaml`, marketplace entry, root README index, category, and version consistency.

- [ ] Add failing fixture-based tests for missing README sections, missing manifest, invalid category, mismatched version, missing marketplace entry, and missing root README index.
- [ ] Run the focused tests and verify they fail for missing Plugin validation.
- [ ] Implement only the required Plugin and repository checks.
- [ ] Run `python -m unittest tests.test_validate_skill -v` and verify all cases pass.
- [ ] Commit with `开发：增加 Marketplace 发布结构门禁`.

### Task 3: Confirmation-bound publisher

**Files:**
- Create: `tests/test_publish_skill.py`
- Create: `plugins/publish-codex-skill/skills/publish-codex-skill/scripts/publish_skill.py`

**Interfaces:**
- Consumes: source Skill path, repository root, version, category, commit message, and validator module.
- Produces: `prepare_publish(...) -> PublishPlan`, `apply_publish(plan_path: Path, token: str) -> PublishResult`, CLI subcommands `prepare` and `apply`.

- [ ] Write failing tests using temporary Git repositories for fixed-remote enforcement, generated Plugin wrapper, marketplace update, root README index, token creation, missing-token refusal, drift refusal, and allowlisted staging.
- [ ] Run `python -m unittest tests.test_publish_skill -v`; verify failure because the publisher module does not exist.
- [ ] Implement prepare without commit or push; serialize an allowlist and SHA-256 confirmation token derived from repository state and diff.
- [ ] Implement apply to revalidate remote, branch, working-tree hash, allowlist, and token before `git add`, `git commit`, and `git push`.
- [ ] Run publisher tests and verify all cases pass without contacting GitHub.
- [ ] Commit with `开发：实现确认后发布 Skill 的门禁流程`.

### Task 4: Publish Plugin content and user documentation

**Files:**
- Create: `plugins/publish-codex-skill/.codex-plugin/plugin.json`
- Create: `plugins/publish-codex-skill/README.md`
- Create: `plugins/publish-codex-skill/skills/publish-codex-skill/SKILL.md`
- Create: `plugins/publish-codex-skill/skills/publish-codex-skill/agents/openai.yaml`
- Modify: `.agents/plugins/marketplace.json`
- Modify: `README.md`
- Modify: `tests/validate_repository.ps1`

**Interfaces:**
- Documents invocation `$publish-codex-skill`, installation, prepare/apply workflow, update, uninstall, exit codes, and confirmation boundary.

- [ ] Add failing repository contract checks for the new Plugin, README sections, Marketplace category, metadata, and Skill trigger contract.
- [ ] Run repository validation and verify the new checks fail.
- [ ] Generate the Skill scaffold with the official `init_skill.py`, then replace placeholders with concise workflow instructions and metadata including `version: 0.1.0`.
- [ ] Add the Plugin manifest, user README, Marketplace entry, and root README index.
- [ ] Run Python and PowerShell contract tests and verify they pass.
- [ ] Commit with `开发：发布 Codex Skill 发布指导插件`.

### Task 5: Cross-platform CI and final verification

**Files:**
- Modify: `.github/workflows/validate.yml`
- Modify: `CONTRIBUTING.md`

**Interfaces:**
- Produces: Python validation jobs on `ubuntu-latest`, `macos-latest`, and `windows-latest`; retains Windows-only proxy tests.

- [ ] Add a failing repository assertion that CI contains the three-OS matrix and Python test commands.
- [ ] Run repository validation and verify the assertion fails against the old workflow.
- [ ] Add the cross-platform matrix job and document the local validation command.
- [ ] Run `python -m unittest discover -s tests -p "test_*.py" -v`, all PowerShell tests, `git diff --check`, and the validator against both published Plugins.
- [ ] Inspect `git status` and confirm only intended files changed; commit with `优化：增加 Skill 发布器跨平台验证`.
- [ ] Push `main`, inspect the GitHub Actions run, and report the commit and repository URLs.
