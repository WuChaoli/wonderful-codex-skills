# Publish Codex Skill 设计

## 目标

新增 `publish-codex-skill` Plugin，指导并门禁化地将本地 Codex Skill 发布到固定仓库 `WuChaoli/wonderful-codex-skills`。运行环境不限定 Windows，审查脚本和测试必须支持 Windows、macOS 与 Linux。

## 范围

首版负责：

- 审查输入 Skill 的目录结构与 `SKILL.md`。
- 审查 Marketplace Plugin 包装、用户 README 和元数据。
- 在固定仓库中准备发布变更并执行完整门禁。
- 展示目标分支、版本、提交信息与 diff。
- 仅在用户明确确认后提交并推送。

首版不负责发布到任意仓库、不自动创建 GitHub Release，也不绕过分支保护或 CI。

## 目录结构

```text
plugins/publish-codex-skill/
├── .codex-plugin/plugin.json
├── README.md
└── skills/publish-codex-skill/
    ├── SKILL.md
    ├── agents/openai.yaml
    └── scripts/
        ├── validate_skill.py
        └── publish_skill.py
```

Python 只使用标准库，避免要求 PowerShell、Bash 或额外包。`validate_skill.py` 提供确定性审查；`publish_skill.py` 负责准备文件、更新 Marketplace 元数据和执行门禁。GitHub 认证沿用本机已有 Git 凭据或 GitHub CLI，不读取或保存令牌。

## 审查规则

### Skill 文件夹

- 目录名仅允许小写字母、数字和连字符，且与 frontmatter 中的 `name` 一致。
- 必须存在非空 `SKILL.md`。
- 允许 `agents`、`scripts`、`references`、`assets` 等资源目录。
- 拒绝 `.env`、私钥、凭据、备份、缓存、临时文件和机器专属产物。
- 检查 Markdown 中引用的本地相对文件是否存在。

### SKILL.md

- YAML frontmatter 必须完整闭合且可由受限解析器验证。
- `name` 和 `description` 为必需字段；允许保留其他扩展字段。
- 推荐提供 `version`，存在时必须使用严格语义化版本；发布器生成的新 Skill 默认写入 `version`。
- `description` 必须非空、长度不超过 1024 个字符，并说明明确的使用触发场景。
- 正文必须非空，不能包含 `TODO`、`TBD` 或模板占位符。
- Skill 名称必须少于 64 个字符。

### Plugin 包装

- Skill 本体不要求 `README.md`；用户文档位于 Plugin 根目录。
- Plugin 根目录必须有 `README.md`，并包含描述、安装、调用、更新和卸载说明。
- 必须存在 `.codex-plugin/plugin.json` 与 `agents/openai.yaml`。
- Plugin manifest 的名称、版本、skills 路径、仓库地址和分类必须合法；其版本必须与 Skill frontmatter 的 `version` 一致。
- `.agents/plugins/marketplace.json` 中的名称、路径和分类必须与 Plugin 一致。
- 根 `README.md` 必须在分类表和 Plugins 段落中索引新 Plugin。

审查结果使用稳定退出码：无错误返回 `0`，规则错误返回 `1`，参数或运行环境错误返回 `2`。输出同时支持人类可读文本和 `--json`，便于 CI 使用。

## 发布流程与确认门禁

1. 接收本地 Skill 路径、目标版本和分类；仓库固定为 `WuChaoli/wonderful-codex-skills`。
2. 对源 Skill 执行只读审查；任何错误都会停止流程。
3. 在仓库中生成或更新 Plugin 包装、Marketplace 清单和根 README。
4. 运行 Plugin 审查、仓库契约测试及 `git diff --check`。
5. 展示变更摘要、完整 diff、目标 remote、目标分支、版本和中文 `<动作>：<总结>` 提交信息。
6. 停止并要求用户明确确认。准备阶段不得 commit 或 push。
7. 确认后重新执行审查，确保用户确认后的内容没有漂移。
8. 仅提交本次发布产生的文件并 push 当前目标分支。
9. 返回 commit、分支和 GitHub URL；推送失败时保留本地提交并报告恢复方式。

`publish_skill.py` 默认运行在 `--prepare` 模式。真正上传必须显式使用 `--apply`，同时传入由 prepare 阶段生成、与当前 diff 绑定的一次性确认令牌。令牌不匹配、工作树发生变化或 remote 不指向指定仓库时，门禁拒绝提交和推送。

## 安全边界

- 不自动覆盖无关的未提交修改。
- 不执行 force push，不修改 Git 凭据，不切换远端仓库。
- remote 必须解析为 `WuChaoli/wonderful-codex-skills`。
- 默认目标分支为当前分支；发布前明确展示，不静默切换。
- 只暂存发布清单中的路径，避免把用户其他改动带入提交。
- 审查通过不等于自动授权上传；确认门禁始终独立存在。

## 测试与验收

测试采用 Python `unittest`，并接入现有 GitHub Actions：

- 合法最小 Skill 通过。
- 缺少 `SKILL.md`、非法目录名、frontmatter 错误、名称不一致均失败。
- `TODO`、缺失相对引用、敏感文件均失败。
- 缺少 Plugin README 或 README 必要章节时失败。
- Marketplace 路径、分类或 manifest 不一致时失败。
- 未提供有效确认令牌时，`--apply` 不得执行 commit 或 push。
- prepare 后文件变化时，确认令牌失效。
- Windows、macOS、Linux CI 均执行审查器测试；现有 PowerShell 专项测试继续只在 Windows 执行。

完成标准：新 Plugin 可从 Marketplace 安装；审查器的文本与 JSON 模式均通过测试；仓库全量门禁通过；模拟 Git 仓库证明未确认不会上传、确认后只提交允许路径。
