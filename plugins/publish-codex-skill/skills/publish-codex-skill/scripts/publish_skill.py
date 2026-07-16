#!/usr/bin/env python3
"""Create and enforce a confirmation-bound Git publication plan."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path


TARGET_REPOSITORY = "WuChaoli/wonderful-codex-skills"


def _git(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args], cwd=repo, text=True, capture_output=True, check=False
    )
    if result.returncode:
        raise ValueError(result.stderr.strip() or result.stdout.strip())
    return result.stdout.strip()


def assert_target_remote(repo: Path) -> str:
    remote = _git(repo, "remote", "get-url", "origin")
    normalized = remote.lower().replace("\\", "/")
    valid = (
        "github.com/wuchaoli/wonderful-codex-skills" in normalized
        or "github.com:wuchaoli/wonderful-codex-skills" in normalized
    )
    if not valid:
        raise ValueError(f"origin must target {TARGET_REPOSITORY}; got {remote}")
    return remote


def compute_confirmation_token(repo: Path, paths: list[str], commit_message: str) -> str:
    digest = hashlib.sha256()
    digest.update(TARGET_REPOSITORY.encode())
    digest.update(_git(repo, "branch", "--show-current").encode())
    digest.update(commit_message.encode())
    for relative in sorted(paths):
        candidate = (repo / relative).resolve()
        try:
            candidate.relative_to(repo.resolve())
        except ValueError as exc:
            raise ValueError(f"path escapes repository: {relative}") from exc
        digest.update(relative.replace("\\", "/").encode())
        if candidate.is_file():
            digest.update(candidate.read_bytes())
        elif candidate.is_dir():
            for child in sorted(item for item in candidate.rglob("*") if item.is_file()):
                digest.update(child.relative_to(repo).as_posix().encode())
                digest.update(child.read_bytes())
        else:
            digest.update(b"<deleted-or-missing>")
    return digest.hexdigest()


def create_confirmation_plan(repo: Path, paths: list[str], commit_message: str) -> dict[str, object]:
    repo = Path(repo).resolve()
    remote = assert_target_remote(repo)
    branch = _git(repo, "branch", "--show-current")
    if not branch:
        raise ValueError("publishing from detached HEAD is not allowed")
    token = compute_confirmation_token(repo, paths, commit_message)
    return {
        "repository": TARGET_REPOSITORY,
        "remote": remote,
        "branch": branch,
        "paths": sorted(paths),
        "commit_message": commit_message,
        "token": token,
    }


def verify_apply_gate(repo: Path, plan: dict[str, object], token: str) -> None:
    if not token:
        raise ValueError("explicit confirmation token is required")
    assert_target_remote(repo)
    if plan.get("repository") != TARGET_REPOSITORY:
        raise ValueError("publication plan targets the wrong repository")
    if _git(repo, "branch", "--show-current") != plan.get("branch"):
        raise ValueError("current branch differs from the confirmed branch")
    expected = compute_confirmation_token(repo, list(plan["paths"]), str(plan["commit_message"]))
    if token != plan.get("token") or token != expected:
        raise ValueError("confirmation token is invalid because the publication changed")


def apply_plan(repo: Path, plan: dict[str, object], token: str) -> str:
    verify_apply_gate(repo, plan, token)
    paths = [str(path) for path in plan["paths"]]
    _git(repo, "add", "--", *paths)
    _git(repo, "commit", "-m", str(plan["commit_message"]), "--", *paths)
    _git(repo, "push", "origin", str(plan["branch"]))
    return _git(repo, "rev-parse", "HEAD")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    prepare = subparsers.add_parser("prepare")
    prepare.add_argument("--repo", type=Path, required=True)
    prepare.add_argument("--path", action="append", required=True)
    prepare.add_argument("--message", required=True)
    prepare.add_argument("--plan", type=Path, required=True)
    apply = subparsers.add_parser("apply")
    apply.add_argument("--repo", type=Path, required=True)
    apply.add_argument("--plan", type=Path, required=True)
    apply.add_argument("--confirm", required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "prepare":
            plan = create_confirmation_plan(args.repo, args.path, args.message)
            args.plan.write_text(json.dumps(plan, indent=2, ensure_ascii=False), encoding="utf-8")
            print(json.dumps(plan, indent=2, ensure_ascii=False))
        else:
            plan = json.loads(args.plan.read_text(encoding="utf-8"))
            print(apply_plan(args.repo.resolve(), plan, args.confirm))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
