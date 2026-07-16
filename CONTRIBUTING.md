# Contributing

感谢为 Wonderful Codex Skills 添加或改进 Plugin。

## Plugin 布局

每个 Plugin 使用官方平铺结构：

```text
plugins/<plugin-name>/.codex-plugin/plugin.json
plugins/<plugin-name>/skills/<skill-name>/SKILL.md
```

不要创建 `plugins/development/` 或 `plugins/design/` 等分类目录。分类写入 `.agents/plugins/marketplace.json` 的 `category`，并同步更新 README 索引。

## 分类

选择 `Codex Tools`、`Development`、`Design`、`Productivity` 或 `Other`。只有已有分类无法合理覆盖多个稳定 Plugin 时，才提出新分类。

## 必需检查

- Plugin manifest 使用严格语义化版本。
- Skill 名称与目录一致，说明包含清晰触发条件。
- 写操作必须有明确授权门槛、备份或回滚方案。
- 测试不能依赖个人目录、代理端口、令牌或实时外部服务。
- 不提交 `.env`、备份、凭据或机器专属绝对路径。

在 Windows PowerShell 7 中运行：

```powershell
pwsh -NoProfile -File tests/validate_repository.ps1
pwsh -NoProfile -File tests/fix_codex_proxy.Tests.ps1
pwsh -NoProfile -File tests/skill_contract.Tests.ps1
```

跨平台 Skill 与 Plugin 结构审查在 Windows、macOS 和 Linux 上运行：

```text
python -m unittest discover -s tests -p "test_*.py" -v
python plugins/publish-codex-skill/skills/publish-codex-skill/scripts/validate_skill.py plugins/<plugin-name> --plugin --repository-root .
```

`SKILL.md` frontmatter 必须包含 `name` 和 `description`，审查器允许扩展字段。为兼容 Codex 官方 validator，发布文件推荐在 `metadata.version` 提供严格语义化版本，并与 Plugin manifest 版本一致。面向用户的安装与使用文档放在 Plugin 根目录 `README.md`。

提交信息使用中文 `<动作>：<总结>` 格式。
