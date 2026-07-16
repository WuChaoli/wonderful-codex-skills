import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = (
    Path(__file__).parents[1]
    / "plugins/publish-codex-skill/skills/publish-codex-skill/scripts/validate_skill.py"
)


def load_module():
    spec = importlib.util.spec_from_file_location("validate_skill", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ValidateSkillTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def write_skill(self, name="sample-skill", frontmatter="", body="# Workflow\n\nRun safely.\n"):
        skill = self.root / name
        skill.mkdir()
        metadata = frontmatter or (
            f"name: {name}\n"
            "description: Use when publishing a tested Codex Skill.\n"
            "version: 1.2.3\n"
            "metadata:\n"
            "  owner: example\n"
        )
        (skill / "SKILL.md").write_text(f"---\n{metadata}---\n\n{body}", encoding="utf-8")
        return skill

    def test_accepts_extra_fields_and_semver_version(self):
        module = load_module()
        report = module.validate_skill(self.write_skill())
        self.assertEqual([], report.errors)

    def test_rejects_missing_skill_markdown(self):
        module = load_module()
        skill = self.root / "missing-skill"
        skill.mkdir()
        self.assertIn("SKILL.md", "\n".join(module.validate_skill(skill).errors))

    def test_rejects_invalid_name_and_mismatch(self):
        module = load_module()
        skill = self.write_skill("Bad_Name", "name: other-name\ndescription: Use when testing.\n")
        errors = "\n".join(module.validate_skill(skill).errors)
        self.assertIn("folder name", errors)
        self.assertIn("must match", errors)

    def test_rejects_invalid_version_placeholder_link_and_secret(self):
        module = load_module()
        skill = self.write_skill(
            frontmatter=(
                "name: sample-skill\n"
                "description: Use when publishing.\n"
                "version: v1\n"
            ),
            body="# TODO\n\nSee [missing](references/missing.md).\n",
        )
        (skill / ".env").write_text("TOKEN=secret", encoding="utf-8")
        errors = "\n".join(module.validate_skill(skill).errors)
        self.assertIn("semantic version", errors)
        self.assertIn("placeholder", errors)
        self.assertIn("missing local link", errors)
        self.assertIn("sensitive", errors)

    def test_json_report_is_machine_readable(self):
        module = load_module()
        payload = json.loads(module.validate_skill(self.write_skill()).to_json())
        self.assertTrue(payload["valid"])
        self.assertEqual([], payload["errors"])

    def create_plugin(self):
        plugin = self.root / "plugins" / "sample-skill"
        skill = plugin / "skills" / "sample-skill"
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text(
            "---\nname: sample-skill\ndescription: Use when publishing.\nversion: 1.2.3\n---\n\n# Workflow\n",
            encoding="utf-8",
        )
        (skill / "agents").mkdir()
        (skill / "agents" / "openai.yaml").write_text("interface:\n  display_name: Sample\n", encoding="utf-8")
        (plugin / ".codex-plugin").mkdir()
        (plugin / ".codex-plugin" / "plugin.json").write_text(
            json.dumps({"name": "sample-skill", "version": "1.2.3", "skills": "./skills/"}),
            encoding="utf-8",
        )
        (plugin / "README.md").write_text(
            "# Sample\n\n## Description\nText\n## Install\nText\n## Invoke\nText\n## Update\nText\n## Uninstall\nText\n",
            encoding="utf-8",
        )
        marketplace = self.root / ".agents" / "plugins"
        marketplace.mkdir(parents=True)
        (marketplace / "marketplace.json").write_text(
            json.dumps({"plugins": [{"name": "sample-skill", "source": {"path": "./plugins/sample-skill"}, "category": "Codex Tools"}]}),
            encoding="utf-8",
        )
        (self.root / "README.md").write_text("[sample-skill](plugins/sample-skill/README.md)", encoding="utf-8")
        return plugin

    def test_validates_plugin_readme_manifest_and_marketplace(self):
        module = load_module()
        report = module.validate_plugin(self.create_plugin(), self.root)
        self.assertEqual([], report.errors)

    def test_rejects_missing_readme_section_and_version_mismatch(self):
        module = load_module()
        plugin = self.create_plugin()
        (plugin / "README.md").write_text("# Sample\n\n## Install\n", encoding="utf-8")
        manifest = plugin / ".codex-plugin" / "plugin.json"
        data = json.loads(manifest.read_text(encoding="utf-8"))
        data["version"] = "2.0.0"
        manifest.write_text(json.dumps(data), encoding="utf-8")
        errors = "\n".join(module.validate_plugin(plugin, self.root).errors)
        self.assertIn("README", errors)
        self.assertIn("version", errors)


if __name__ == "__main__":
    unittest.main()
