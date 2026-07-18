# Cross-Platform Codex Desktop Lag Design

## Goal

Replace the Windows-only PowerShell implementation with a Node.js CLI that provides the same named diagnostics and reversible, confirmed remediations on Windows, macOS, and Linux.

## Architecture

`scripts/codex-performance.mjs` exposes independent `diagnose <check>` and `remediate <action>` commands. Each command emits one JSON object. The CLI selects paths from `CODEX_HOME` or the platform default, uses Node standard-library APIs, and uses `node:sqlite` for SQLite work. Unsupported platform-specific checks return `skipped`.

## Safety

Diagnostics are read-only. Remediations require `--what-if` for preview and `--apply` for mutation, reject both flags together, verify Codex is not running, operate only below `CODEX_HOME`, create timestamped backups before changing state, and handle one action per invocation.

## Scope

The CLI supports the existing 18 diagnostic check names and 10 remediation action names. Windows-specific WSL cleanup and display-driver checks return `skipped` on macOS/Linux. Documentation and tests are updated for Node.js 22.13+; no PowerShell runtime is required.
