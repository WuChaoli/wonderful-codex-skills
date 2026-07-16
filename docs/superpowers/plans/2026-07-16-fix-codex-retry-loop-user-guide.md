# Fix Codex Retry Loop User Guide Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `fix-codex-retry-loop` 发布独立用户说明页，并从 Marketplace 首页提供稳定入口。

**Architecture:** 仓库根 README 只保留 Marketplace 导航和 Plugin 摘要；Plugin README 承担安装、触发、解释、更新、卸载和回滚说明。现有仓库测试增加文档契约，确保链接和关键安全文案不会回退。

**Tech Stack:** Markdown、PowerShell 7、GitHub Actions

## Global Constraints

- 不修改 Skill、脚本、Plugin manifest、版本或 Marketplace 分类。
- 中文为主，关键安装步骤附英文说明。
- 不承诺所有 retry loop 都由代理导致。
- 写入前确认、备份、401 解释和完全重启必须出现。
- 提交信息使用中文 `<动作>：<总结>` 格式。

---

### Task 1: 文档契约测试

**Files:**
- Modify: `tests/validate_repository.ps1`

**Interfaces:**
- 校验 `plugins/fix-codex-retry-loop/README.md` 存在。
- 校验根 README 链接详情页。
- 校验详情页包含安装、触发、确认、备份、重启、状态解释、更新、卸载和回滚关键词。

- [ ] 扩展仓库测试，加入上述断言。
- [ ] 运行 `pwsh -NoProfile -File tests/validate_repository.ps1`。
- [ ] 确认因 Plugin README 缺失而失败。

### Task 2: 用户说明与首页入口

**Files:**
- Create: `plugins/fix-codex-retry-loop/README.md`
- Modify: `README.md`

**Interfaces:**
- 安装命令：`codex plugin marketplace add WuChaoli/wonderful-codex-skills`。
- 更新命令：`codex plugin marketplace upgrade wonderful-codex-skills`。
- 触发示例包含 `$fix-codex-retry-loop`。

- [ ] 编写按用户操作顺序组织的独立说明页。
- [ ] 在根 README 的 Plugin 标题和分类表中添加相对链接。
- [ ] 运行仓库、脚本和 Skill 契约全部测试。
- [ ] 运行 `git diff --check` 和敏感内容扫描。
- [ ] 提交：`文档：新增重试循环技能安装说明`。

### Task 3: 发布与远程验证

**Files:**
- Remote: `WuChaoli/wonderful-codex-skills`

**Interfaces:**
- 推送 `main`，不创建新 Release。
- GitHub Actions 必须通过。

- [ ] 快进合并功能分支到 `main` 并推送。
- [ ] 等待最新 Windows CI 完成。
- [ ] 读取远程 Plugin README 和根 README 链接。
- [ ] 确认本地工作树干净，删除已合并功能分支。
