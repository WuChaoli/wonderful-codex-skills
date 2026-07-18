# Codex Desktop Lag JS Implementation Plan

**Goal:** Publish a Node.js-only, cross-platform diagnostic and remediation CLI.

1. Add failing tests for JSON diagnostics and non-mutating remediation previews.
2. Implement the Node.js CLI with platform path resolution, read-only diagnostics, and guarded remediations.
3. Replace PowerShell contracts with Node.js contracts and update the Skill, README, metadata, and CI.
4. Run tests, validate the Plugin, prepare the confirmation-bound publication plan, and publish only after confirmation.
