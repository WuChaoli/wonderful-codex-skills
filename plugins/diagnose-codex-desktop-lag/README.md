# Diagnose Codex Desktop Lag

[![Marketplace](https://img.shields.io/badge/Marketplace-Wonderful%20Codex%20Skills-10A37F)](https://github.com/WuChaoli/wonderful-codex-skills)
[![Windows CI](https://github.com/WuChaoli/wonderful-codex-skills/actions/workflows/validate.yml/badge.svg)](https://github.com/WuChaoli/wonderful-codex-skills/actions/workflows/validate.yml)

## 描述 / Description

用于诊断 Windows Codex Desktop 的卡顿、冻结、输入延迟、高 CPU/GPU/内存/I/O、SQLite WAL 增长、Git/WSL 子进程频繁启动、会话历史膨胀和窗口渲染异常。

Diagnose Windows Codex Desktop freezes, stutter, high resource usage, SQLite logging pressure, child-process churn, large local history, and rendering problems.

Skill 先逐项运行 18 个独立只读诊断脚本并生成完整报告。修复阶段每次只处理一个已确认问题：先用 `-WhatIf` 预览，再次确认后应用，并立即复测。

## 安全边界

- 诊断阶段不修改配置、数据库、会话、环境变量或项目文件。
- 不提供“一键运行全部诊断”或“一键修复全部问题”。
- 修复前要求用户明确确认，涉及状态时先备份。
- 默认隔离或保留恢复副本，不永久删除历史。
- 不通过单独修改 `threads.archived` 批量归档任务。
- 不删除真实项目目录，包括名为 `codespace` 的目录。
- 保留用户指定的 `show-context-window-usage` 设置。
- 只在当前 AI 任务内工作，不派发子智能体。

## 兼容性

- Windows 10/11
- PowerShell 7 (`pwsh`)
- Python 3.11 或更高版本
- 支持 Plugin Marketplace 的 Codex CLI 或 Codex desktop app

## 安装 / Install

```powershell
codex plugin marketplace add WuChaoli/wonderful-codex-skills
```

完全退出并重启 Codex，在 Plugins 页面打开 **Wonderful Codex Skills**，安装 **Diagnose Codex Desktop Lag**。

## 调用 / Invoke

```text
使用 $diagnose-codex-desktop-lag 帮我完整诊断 Codex Desktop 卡顿，修复前先让我确认。
```

只做 dry-run：

```text
使用 $diagnose-codex-desktop-lag 做一次只读 dry-run，不执行修复。
```

## 诊断范围

- Codex 和 Windows 版本、系统内存与磁盘余量。
- Codex CPU、内存、I/O、GPU 与子进程采样。
- WSL 环境标志、GPU 和虚拟显示驱动。
- `state_5.sqlite`、`logs_2.sqlite` 完整性和 WAL 增长率。
- 活跃任务、token、元数据和大 rollout 文件。
- `.tmp`、保存的工作区入口和安全配置摘要。
- 空任务、重启、窗口模式、插件或 MCP 的人工对照步骤。

## 修复方式

修复脚本均支持 PowerShell `-WhatIf`。可选方案包括：

- 在线备份 Codex SQLite 数据库。
- 备份配置和全局状态。
- 一致归档一个已确认的任务。
- 隔离单个 rollout 或陈旧临时文件。
- 移除一个保存的工作区入口，但不删除物理目录。
- 移除导致 Windows 误调用 WSL 的环境标志。
- 在证据充分时阻断或恢复日志插入。
- 从时间戳备份恢复。

## 更新 / Update

```powershell
codex plugin marketplace upgrade wonderful-codex-skills
```

更新后完全退出并重启 Codex。

## 卸载 / Uninstall

在 Codex Plugins 页面卸载 **Diagnose Codex Desktop Lag**，然后完全重启 Codex。卸载不会删除诊断前生成的备份或隔离目录。

## 回滚

优先使用修复脚本输出的时间戳备份目录。涉及数据库或会话归档时，完全退出 Codex 后再运行 `restore-codex-backup.ps1`，并重新执行数据库完整性和任务状态诊断。
