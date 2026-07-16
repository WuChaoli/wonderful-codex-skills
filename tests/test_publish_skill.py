import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = (
    Path(__file__).parents[1]
    / "plugins/publish-codex-skill/skills/publish-codex-skill/scripts/publish_skill.py"
)


def load_module():
    spec = importlib.util.spec_from_file_location("publish_skill", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class PublishGateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.repo = Path(self.temp.name)
        subprocess.run(["git", "init", "-b", "main"], cwd=self.repo, check=True, capture_output=True)
        subprocess.run(
            ["git", "remote", "add", "origin", "https://github.com/WuChaoli/wonderful-codex-skills.git"],
            cwd=self.repo,
            check=True,
        )
        (self.repo / "seed.txt").write_text("seed\n", encoding="utf-8")
        subprocess.run(["git", "add", "seed.txt"], cwd=self.repo, check=True)
        subprocess.run(
            ["git", "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-m", "seed"],
            cwd=self.repo,
            check=True,
            capture_output=True,
        )

    def tearDown(self):
        self.temp.cleanup()

    def test_prepare_token_changes_when_worktree_changes(self):
        module = load_module()
        plan = module.create_confirmation_plan(self.repo, ["seed.txt"], "开发：发布测试 Skill")
        original = plan["token"]
        (self.repo / "seed.txt").write_text("changed\n", encoding="utf-8")
        changed = module.compute_confirmation_token(self.repo, ["seed.txt"], "开发：发布测试 Skill")
        self.assertNotEqual(original, changed)

    def test_apply_rejects_missing_token_before_git_mutation(self):
        module = load_module()
        plan = module.create_confirmation_plan(self.repo, ["seed.txt"], "开发：发布测试 Skill")
        with self.assertRaisesRegex(ValueError, "confirmation token"):
            module.verify_apply_gate(self.repo, plan, "")
        status = subprocess.run(["git", "status", "--short"], cwd=self.repo, text=True, capture_output=True, check=True)
        self.assertEqual("", status.stdout)

    def test_remote_must_be_fixed_repository(self):
        module = load_module()
        subprocess.run(["git", "remote", "set-url", "origin", "https://github.com/example/other.git"], cwd=self.repo, check=True)
        with self.assertRaisesRegex(ValueError, "WuChaoli/wonderful-codex-skills"):
            module.assert_target_remote(self.repo)


if __name__ == "__main__":
    unittest.main()
