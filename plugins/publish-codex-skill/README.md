# Publish Codex Skill

## 描述 / Description

面向 `WuChaoli/wonderful-codex-skills` 的跨平台 Skill 发布助手。它检查 Skill 目录、`SKILL.md`、扩展 YAML 字段、语义化版本、Plugin README、manifest 和 Marketplace 索引，并通过一次性确认令牌阻止未经确认的提交与推送。

支持 Windows、macOS 和 Linux，只依赖 Python 3 标准库与 Git。

## 安装 / Install

```text
codex plugin marketplace add WuChaoli/wonderful-codex-skills
```

完全重启 Codex，在 Plugins 页面打开 **Wonderful Codex Skills**，安装 **Publish Codex Skill**。

## 调用 / Invoke

```text
$publish-codex-skill 审查并发布这个 Skill
```

Skill 会先执行只读审查，再准备 Marketplace 变更并展示 diff。只有用户明确确认目标仓库、分支、版本、提交信息和确认令牌后，才能提交并推送。

直接运行审查器：

```text
python scripts/validate_skill.py <skill-folder>
python scripts/validate_skill.py <plugin-folder> --plugin --repository-root <repository-root> --json
```

退出码：`0` 表示通过，`1` 表示规则不通过，`2` 表示参数、文件读取或运行环境错误。

## 更新 / Update

```text
codex plugin marketplace upgrade wonderful-codex-skills
```

更新后完全重启 Codex。

## 卸载 / Uninstall

在 Codex Plugins 页面卸载 **Publish Codex Skill**。卸载不会删除已发布到 GitHub 的 Skill，也不会修改 Git 凭据。

## 安全边界

- 固定目标仓库为 `WuChaoli/wonderful-codex-skills`。
- 不执行 force push，不修改凭据，不暂存发布清单之外的路径。
- prepare 后文件发生变化，确认令牌立即失效。
- Skill 本体不强制包含 README；面向用户的 README 位于 Plugin 根目录。
