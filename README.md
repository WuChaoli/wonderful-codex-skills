# Wonderful Codex Skills

一个按用途分类、可持续扩展的 Codex Plugin Marketplace。

An extensible, categorized marketplace for reusable Codex plugins and skills.

## 安装 / Install

```powershell
codex plugin marketplace add WuChaoli/wonderful-codex-skills
```

添加后完全重启 Codex，在 Plugins 页面选择 **Wonderful Codex Skills** 并安装需要的 Plugin。

After adding the marketplace, restart Codex completely. Open Plugins, select **Wonderful Codex Skills**, and install the plugin you need.

## 分类 / Categories

| Category | Scope | Plugins |
|---|---|---|
| Codex Tools | Codex 配置、网络、环境、诊断与维护 | [`fix-codex-retry-loop`](plugins/fix-codex-retry-loop/README.md) |
| Development | 编码、测试、调试与 CI/CD | — |
| Design | UI、视觉、交互与设计工作流 | — |
| Productivity | 文档、信息整理与个人效率 | — |
| Other | 尚未形成稳定类别的 Plugin | — |

## Plugins

### [fix-codex-retry-loop](plugins/fix-codex-retry-loop/README.md)

Windows 优先的 Codex 网络诊断与代理配置 Skill：

- 检测 Clash、Mihomo 等代理进程和监听端口。
- 区分网络故障、认证响应与服务端错误。
- 仅在用户明确确认后备份并更新 `$CODEX_HOME/.env`。
- 验证代理端口和 OpenAI API 网络路径，并提醒完全重启 Codex。

`401` 只表示未携带凭据的测试请求已到达 OpenAI 服务端，不代表账号认证已经完成。

[查看完整描述、安装、使用、更新、卸载与回滚说明。](plugins/fix-codex-retry-loop/README.md)

## Compatibility

- Codex CLI or Codex desktop app with Plugin Marketplace support
- Windows 10/11
- PowerShell 7 (`pwsh`)
- A local HTTP/Mixed proxy when proxy configuration is required

## Contributing

新增 Plugin 前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

## License

MIT
