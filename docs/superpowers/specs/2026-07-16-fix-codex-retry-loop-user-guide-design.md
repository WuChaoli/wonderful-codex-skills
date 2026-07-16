# fix-codex-retry-loop 用户说明设计

## 目标

为 `fix-codex-retry-loop` 增加面向安装者的独立说明页，并从 Marketplace 根 README 链接进入。说明页帮助用户判断是否适用、完成安装、正确触发 Skill，并理解确认、验证、重启、卸载和回滚流程。

## 文件范围

- 新增 `plugins/fix-codex-retry-loop/README.md`。
- 修改根 `README.md` 中的 Plugin 条目，增加详情链接和最短安装入口。
- 扩展 `tests/validate_repository.ps1`，验证说明页与必要内容。
- 不修改 Skill 工作流、PowerShell 实现、Plugin 版本或 Marketplace 分类。

## 内容结构

独立说明页按用户实际操作顺序组织：

1. 名称、简短描述和状态徽标。
2. 适用症状与不适用场景。
3. 功能、安全边界和 Windows/PowerShell 兼容性。
4. 添加 Marketplace 的命令。
5. 重启 Codex、打开 Plugins 页面并安装 Plugin。
6. 使用 `$fix-codex-retry-loop` 的触发示例。
7. Detect、用户确认、Apply、Verify 和再次重启的行为说明。
8. `401`、端口失败、`429` 与 `5xx` 的结果解释。
9. Marketplace 更新、Plugin 卸载和 `.env` 回滚。
10. 常见问题及仓库 Issue 入口。

## 文案原则

- 中文为主，安装命令和关键操作附简短英文说明。
- 先给结论和安装命令，再解释内部机制。
- 不让用户手工复制 Skill 脚本或编辑仓库文件。
- 不承诺所有 retry loop 都由代理引起。
- 明确写入前必须由用户确认，且已有 `.env` 会先备份。
- 明确 `401` 仅代表无凭据测试请求到达服务端。
- 示例使用通用 `127.0.0.1:7890`，说明实际端口以探测和确认结果为准。

## 安装与使用接口

添加 Marketplace：

```powershell
codex plugin marketplace add WuChaoli/wonderful-codex-skills
```

触发示例：

```text
使用 $fix-codex-retry-loop 帮我诊断 Codex 一直 retry 的问题。
```

更新 Marketplace：

```powershell
codex plugin marketplace upgrade wonderful-codex-skills
```

卸载操作优先引导用户在 Codex Plugins 页面完成，避免假设当前 CLI 的 Plugin 删除命令。

## 测试契约

仓库测试必须确认：

- Plugin README 存在。
- 根 README 链接到 Plugin README。
- 说明页包含安装命令、Skill 触发名、Windows、明确确认、备份、完全重启、401、更新、卸载和回滚。
- 文档不包含展开后的用户目录、密钥或代理凭据。
- 所有既有脚本、Skill 和 Plugin 测试继续通过。

## 成功标准

- 新用户只阅读 Plugin README 即可完成安装和触发。
- 用户能明确区分网络可达、认证失败、限流和服务端错误。
- 用户知道 Skill 不会在未确认时写入代理配置。
- 用户知道如何更新 Marketplace、卸载 Plugin 和恢复代理配置。
- 公开 CI 通过，根 README 与独立说明页链接可从 GitHub 正常访问。
