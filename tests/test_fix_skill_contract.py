from pathlib import Path
import unittest


class FixSkillContractTests(unittest.TestCase):
    def test_retry_skill_supports_macos_env_writes(self) -> None:
        skill = (
            Path(__file__).parents[1]
            / "plugins/fix-codex-retry-loop/skills/fix-codex-retry-loop/SKILL.md"
        ).read_text(encoding="utf-8")

        self.assertIn("macOS", skill)
        self.assertIn("写入 `$CODEX_HOME/.env`", skill)
