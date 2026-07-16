# Fix Codex Retry Loop

[![Marketplace](https://img.shields.io/badge/Marketplace-Wonderful%20Codex%20Skills-10A37F)](https://github.com/WuChaoli/wonderful-codex-skills)
[![Windows CI](https://github.com/WuChaoli/wonderful-codex-skills/actions/workflows/validate.yml/badge.svg)](https://github.com/WuChaoli/wonderful-codex-skills/actions/workflows/validate.yml)

## 描述 / Description

用于诊断 Windows 上 Codex 持续 `retry`、`reconnecting`、网络错误或请求超时，并在用户明确确认后安全配置本机 HTTP/Mixed 代理。

Diagnose repeated Codex retry or reconnecting failures on Windows and safely configure a local proxy only after explicit user confirmation.

## 适用场景

- Codex 持续显示 retry、reconnecting、network error 或 connection timeout。
- 已运行 Clash、Mihomo 等代理软件，但 Codex 没有经过代理。
- 需要检查 `$CODEX_HOME/.env`、Windows 系统代理和实际监听端口。
- 希望自动备份并更新 `HTTP_PROXY`、`HTTPS_PROXY`、`NO_PROXY`。

它不会把所有重试都归因于代理。认证失败、限流和服务端故障会分别报告，不会擅自修改配置。

## 安全边界

- Detect 阶段只读取配置和监听状态。
- 写入前展示目标路径、代理 URL 和拟应用变更，并要求用户明确确认。
- 已有 `.env` 会先生成带时间戳的备份，其他环境变量保持不变。
- 不默认写入 `ALL_PROXY`。
- 拒绝把含用户名或密码的代理 URL 保存到 `.env`。
- 完成后提供验证结果和回滚方法。

## 兼容性

- Windows 10/11
- PowerShell 7（`pwsh`）
- 支持 Plugin Marketplace 的 Codex CLI 或 Codex desktop app
- 配置代理时需要可用的本机 HTTP/Mixed 代理端口

## 安装

### 1. 添加 Marketplace

在 PowerShell 中运行：

```powershell
codex plugin marketplace add WuChaoli/wonderful-codex-skills
```

Add the public marketplace with the command above.

### 2. 重启并安装 Plugin

1. 完全退出 Codex及后台进程，然后重新启动 Codex。
2. 打开 **Plugins**。
3. 选择 **Wonderful Codex Skills** Marketplace。
4. 安装 **Fix Codex Retry Loop**。
5. 新建一个 Codex 任务，以确保新 Skill 被加载。

## 使用

在 Codex 中输入：

```text
使用 $fix-codex-retry-loop 帮我诊断 Codex 一直 retry 的问题。
```

也可以描述实际症状：

```text
Codex 一直 reconnecting。我在 Windows 上使用 Clash，请检查代理端口；修改配置前先让我确认。
```

Skill 会按以下顺序执行：

1. Detect：定位 Codex Home、现有 `.env`、Windows 系统代理和代理监听端口。
2. Diagnose：区分网络、认证、限流和服务端错误。
3. Confirm：展示精确变更并等待用户明确确认。
4. Apply：确认后备份并更新代理变量。
5. Verify：检查端口和 OpenAI API 网络路径。
6. Restart：提醒用户完全退出并重启 Codex。

## 如何理解验证结果

| 结果 | 含义 | 下一步 |
|---|---|---|
| 端口未监听 | 代理软件未启动或端口错误 | 启动代理或确认其他端口，不写入配置 |
| `401` | 无凭据测试请求已到达 OpenAI | 网络链路可达；不代表账号认证完成 |
| `429` | 请求被限流 | 等待或检查账户限制，通常无需修改代理 |
| `5xx` | 远端服务异常 | 稍后重试并检查服务状态 |
| 多个候选端口 | 无法安全自动选择 | 由用户确认 HTTP/Mixed 端口 |

示例中的 `http://127.0.0.1:7890` 只是常见值；实际端口以本机探测结果和用户确认结果为准。

## 更新

更新 Marketplace 缓存：

```powershell
codex plugin marketplace upgrade wonderful-codex-skills
```

更新后完全重启 Codex。若 Plugins 页面提示 Plugin 有新版本，按页面提示完成更新。

## 卸载

1. 在 Codex 中打开 **Plugins**。
2. 找到 **Fix Codex Retry Loop** 并选择卸载。
3. 完全重启 Codex。

卸载 Plugin 不会自动删除已经写入 `$CODEX_HOME/.env` 的代理变量。

## 回滚代理配置

优先恢复 Skill 返回的 `.env.backup-<timestamp>` 备份；也可以只删除 `.env` 中以下三项：

```dotenv
HTTP_PROXY=...
HTTPS_PROXY=...
NO_PROXY=...
```

保留文件中的其他变量，然后完全重启 Codex。

## 常见问题

### 为什么 HTTPS 请求的代理地址仍是 `http://`？

Clash 的 HTTP/Mixed 端口通常使用 HTTP CONNECT 转发 HTTPS 流量，因此常见配置是 `http://127.0.0.1:<port>`。

### 为什么没有默认设置 `ALL_PROXY`？

Skill 只修改解决 Codex HTTP/HTTPS 请求所需的最小变量，避免无意影响其他协议和工具。

### 仍然持续 retry 怎么办？

保留 Skill 的 Detect 和 Verify 输出，在仓库提交 [Issue](https://github.com/WuChaoli/wonderful-codex-skills/issues)，并删除其中的账号、令牌、代理凭据和其他敏感信息。
