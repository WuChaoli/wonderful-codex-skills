---
name: fix-codex-retry-loop
description: Use when Codex on Windows is stuck in retry, reconnecting, network error, connection timeout, or repeated request failures, especially with Clash, Mihomo, a local proxy port, or CODEX_HOME/.env proxy configuration.
---

# Fix Codex Retry Loop

## 核心原则

先用证据区分网络、认证和服务端故障。只读探测后展示精确变更；只有用户明确确认，才写入 Codex 代理配置。

## 工作流

1. 确认平台为 Windows，定位本 Skill 目录。
2. 运行只读探测：

   ```powershell
   pwsh -NoProfile -File <skill-dir>\scripts\fix_codex_proxy.ps1 -Action Detect
   ```

3. 根据证据分类：
   - 代理端口未监听或请求无法到达远端：网络/代理问题。
   - OpenAI API 返回 `401`：网络已到达，属于未携带凭据的预期响应。
   - 返回 `429`、`5xx` 或明确认证错误：报告对应问题，不擅自改代理。
4. 若找到多个监听端口，让用户选择。不要猜端口。
5. 向用户展示以下确认单：
   - 目标路径：显式 `CODEX_HOME/.env`；未设置时为 `%USERPROFILE%\.codex\.env`。
   - 将更新的键：`HTTP_PROXY`、`HTTPS_PROXY`、`NO_PROXY`。
   - 完整代理 URL 和拟应用的差异；代理 URL 如含凭据必须停止。
   - 已有 `.env` 将先创建时间戳备份，其他变量保持不变。
6. 询问用户是否明确确认写入。没有肯定答复时停止，保持只读。
7. 获得明确确认后才运行：

   ```powershell
   pwsh -NoProfile -File <skill-dir>\scripts\fix_codex_proxy.ps1 -Action Apply -ProxyUrl http://127.0.0.1:7890 -ConfirmWrite
   ```

8. 使用相同 URL 验证：

   ```powershell
   pwsh -NoProfile -File <skill-dir>\scripts\fix_codex_proxy.ps1 -Action Verify -ProxyUrl http://127.0.0.1:7890
   ```

9. 汇报目标文件、备份路径、端口与远端验证结果。最后明确提醒：完全退出 Codex及后台进程，然后重新启动。

## 快速判断

| 结果 | 结论 | 操作 |
|---|---|---|
| 端口未监听 | 代理软件或端口错误 | 不写入，要求启动代理或重新选择 |
| 端口可达，远端 `401` | 代理网络链路正常 | 配置有效，提醒重启 Codex |
| 多个候选端口 | 选择不明确 | 让用户确认 |
| 用户拒绝或未明确同意 | 未授权写入 | 保持只读 |

## 常见错误

- 写成 `%USERPROFILE%\.codex\.codex\.env`：应解析 `CODEX_HOME`，默认路径只有一层 `.codex`。
- 把 HTTPS 目标的代理写成 `https://127.0.0.1:7890`：Clash HTTP/Mixed 端口通常仍使用 `http://`，由 CONNECT 建立隧道。
- 默认设置 `ALL_PROXY`：保持最小修改，只写 HTTP/HTTPS 和本地直连规则。
- 覆盖整个 `.env`：必须保留无关变量并先备份。
- 写完即宣称生效：必须验证并提醒完全重启。

## 回滚

恢复 Apply 返回的备份文件，或只删除 `.env` 中的 `HTTP_PROXY`、`HTTPS_PROXY`、`NO_PROXY`，随后完全重启 Codex。

