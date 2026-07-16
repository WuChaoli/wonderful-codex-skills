# Publish Wonderful Codex Skills Marketplace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 发布公开的 `WuChaoli/wonderful-codex-skills` Codex Plugin Marketplace，并交付首个 `Codex Tools` 类 Plugin `fix-codex-retry-loop`。

**Architecture:** 使用官方 repo marketplace 布局：`.agents/plugins/marketplace.json` 索引平铺的 `plugins/<name>`。Plugin 用 `.codex-plugin/plugin.json` 包装一个 Skill；仓库根测试验证脚本行为、Skill 契约、JSON 路径、安全边界和公开内容。

**Tech Stack:** Git、GitHub CLI、Codex Plugin、Agent Skills、PowerShell 7、GitHub Actions

## Global Constraints

- 公开仓库名固定为 `WuChaoli/wonderful-codex-skills`，默认分支 `main`。
- Marketplace 分类固定为 `Codex Tools`、`Development`、`Design`、`Productivity`、`Other`。
- Plugin 路径固定为 `plugins/fix-codex-retry-loop`，版本 `0.1.0`，许可证 MIT。
- 不发布 `.env`、备份、代理凭据、API 密钥或 `C:\Users\wuchaoli` 等机器专属路径。
- 写入代理配置前必须取得用户明确确认；真实网络调用不进入 CI。
- Git 提交使用中文 `<动作>：<总结>` 格式。

---

### Task 1: Marketplace 和 Plugin 结构

**Files:**
- Create: `.agents/plugins/marketplace.json`
- Create: `plugins/fix-codex-retry-loop/.codex-plugin/plugin.json`
- Create: `tests/validate_repository.ps1`

**Interfaces:**
- Marketplace 条目 `source.path` 为 `./plugins/fix-codex-retry-loop`，分类为 `Codex Tools`。
- Manifest `skills` 为 `./skills/`，版本为 `0.1.0`。

- [ ] 先创建 `tests/validate_repository.ps1`，断言上述文件存在、JSON 可解析、名称/路径/分类/版本正确，并拒绝绝对用户路径与 `.env` 文件。
- [ ] 运行测试，确认因 marketplace 缺失而失败。
- [ ] 使用 `plugin-creator/scripts/create_basic_plugin.py` 生成 repo marketplace 和带 skills 的 Plugin。
- [ ] 按设计补齐 manifest 作者、仓库、许可证、关键词和 UI 元数据。
- [ ] 运行仓库测试与 `plugin-creator/scripts/validate_plugin.py`，确认通过。
- [ ] 提交：`开发：建立可分类的 Codex Marketplace`。

### Task 2: 迁移并验证 Skill

**Files:**
- Create: `plugins/fix-codex-retry-loop/skills/fix-codex-retry-loop/SKILL.md`
- Create: `plugins/fix-codex-retry-loop/skills/fix-codex-retry-loop/agents/openai.yaml`
- Create: `plugins/fix-codex-retry-loop/skills/fix-codex-retry-loop/scripts/fix_codex_proxy.ps1`
- Create: `tests/fix_codex_proxy.Tests.ps1`
- Create: `tests/skill_contract.Tests.ps1`

**Interfaces:**
- 保持已验证的 `Detect|Apply|Verify` 和 `-ConfirmWrite` 接口。
- 测试从仓库根定位目标脚本和 Skill，不依赖用户目录。

- [ ] 先复制测试并改为仓库相对路径，运行后确认因 Skill 文件缺失而失败。
- [ ] 复制已验证的 Skill、UI 元数据与 PowerShell 脚本，不复制本机 `.env` 或备份。
- [ ] 运行 5 项脚本测试、9 项契约检查、PowerShell AST 解析和 Agent Skill 校验。
- [ ] 运行真实本地 Detect/Verify 作为非 CI 验收，确认 7890 和无凭据 401 可达。
- [ ] 提交：`开发：发布 Codex 重试循环修复技能`。

### Task 3: 公共文档、CI 和许可证

**Files:**
- Create: `README.md`
- Create: `CONTRIBUTING.md`
- Create: `LICENSE`
- Create: `.github/workflows/validate.yml`

**Interfaces:**
- README 首屏提供 `codex plugin marketplace add WuChaoli/wonderful-codex-skills`。
- CI 在 `windows-latest` 运行仓库校验、脚本测试、契约测试和 PowerShell AST 检查。

- [ ] 扩充仓库测试，断言 README 包含安装命令和五个分类，CI 调用全部本地测试。
- [ ] 运行测试并确认因文档/CI 缺失而失败。
- [ ] 创建中英双语 README、贡献指南、MIT LICENSE 和 Windows workflow。
- [ ] 运行全量测试、安全扫描和 `git diff --check`。
- [ ] 提交：`文档：完善 Marketplace 发布与贡献指南`。

### Task 4: GitHub 发布和远程验收

**Files:**
- Remote: `https://github.com/WuChaoli/wonderful-codex-skills`

**Interfaces:**
- 远程仓库公开，默认分支 `main`，origin 指向该 URL。
- Marketplace 可由仓库简写添加。

- [ ] 最终运行全部本地验证并确认工作树干净。
- [ ] 用 `gh repo create WuChaoli/wonderful-codex-skills --public --source . --remote origin --push` 创建并推送。
- [ ] 用 GitHub API读回 visibility、defaultBranchRef 和关键文件。
- [ ] 检查 GitHub Actions 状态；失败则读取日志、修复、复验并推送。
- [ ] 用临时 Codex Home 或 CLI discovery 验证 marketplace URL，不修改现有用户 marketplace。
- [ ] CI 通过后创建 `v0.1.0` tag 和 GitHub Release，并读回 tag、URL 与发布状态。
