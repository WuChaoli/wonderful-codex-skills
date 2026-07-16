---
name: publish-codex-skill
description: Use when a Codex Skill needs structural review, Marketplace packaging, README verification, or confirmed publication to WuChaoli/wonderful-codex-skills from Windows, macOS, or Linux.
metadata:
  category: Codex Tools
  version: 0.1.0
---

# Publish Codex Skill

Validate first. Prepare repository changes second. Commit and push only after the user explicitly confirms the exact diff and confirmation token.

## Workflow

1. Locate the source Skill and the `wonderful-codex-skills` repository. Do not modify the source.
2. Run `python scripts/validate_skill.py <skill-folder> --json`. Stop on errors; report warnings.
3. Copy the reviewed Skill into `plugins/<name>/skills/<name>/`. Preserve extra frontmatter fields. Add a strict-semver `version` when absent, after confirming the intended version.
4. Create or update the Plugin manifest, Plugin-root `README.md`, Marketplace entry, and root README index. The Plugin README must cover description, installation, invocation, update, and uninstall.
5. Run Plugin validation:

   ```text
   python scripts/validate_skill.py <plugin-folder> --plugin --repository-root <repository-root>
   ```

6. Run the repository's complete test suite and `git diff --check`.
7. Show the user the target remote, branch, version, commit message, changed paths, and full diff.
8. Create a confirmation plan without committing or pushing:

   ```text
   python scripts/publish_skill.py prepare --repo <repository-root> --path <changed-path> --message <commit-message> --plan <plan-file>
   ```

9. Stop and request explicit confirmation of the displayed token. Never treat validation success as upload authorization.
10. After confirmation, run the same validations again. Apply only when nothing changed:

    ```text
    python scripts/publish_skill.py apply --repo <repository-root> --plan <plan-file> --confirm <token>
    ```

11. Report the commit and GitHub URL. Remind the user to restart Codex after installing or updating the Plugin.

## Guardrails

- Accept additional `SKILL.md` YAML fields; require `name` and `description`; validate `version` when present.
- Publish only to `WuChaoli/wonderful-codex-skills`.
- Never force push, change credentials, stage unrelated paths, or bypass the confirmation token.
- If the working tree changes after prepare, discard the plan and prepare again.
- Keep user documentation at the Plugin root. A README inside the Skill folder is optional and not required.
