import json
import subprocess
import tempfile
import unittest
from pathlib import Path


class CodexPerformanceCliTests(unittest.TestCase):
    repo = Path(__file__).parents[1]
    cli = repo / "plugins/diagnose-codex-desktop-lag/skills/diagnose-codex-desktop-lag/scripts/codex-performance.mjs"

    def run_cli(self, *args: str) -> dict:
        result = subprocess.run(
            ["node", self.cli, *args], text=True, capture_output=True, check=True
        )
        return json.loads(result.stdout)

    def test_thread_summary_reports_json_for_missing_database(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_cli("diagnose", "thread-state-summary", "--codex-home", directory)
        self.assertEqual(result["check"], "thread-state-summary")
        self.assertEqual(result["status"], "skipped")

    def test_remediation_preview_does_not_create_backup(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            result = self.run_cli("remediate", "backup-codex-state", "--codex-home", directory, "--what-if")
            self.assertFalse(result["applied"])
            self.assertFalse((home / "performance-backups").exists())
