# Windows Codex Desktop 修复手册

## 两次确认

完整报告后先确认要处理的单项。随后用 `-WhatIf` 预览该脚本，展示预览，再确认是否应用。每次应用后只复测关联指标。

## 脚本化修复

| 修复 | 前置证据 | 脚本 | 复测 |
|---|---|---|---|
| 在线备份 SQLite | 任意数据库修复前 | `backup-codex-databases.ps1` | 对备份运行完整性检查 |
| 备份配置和状态 | 状态修复前 | `backup-codex-state.ps1` | 比较文件数量、大小 |
| 隔离单个 rollout | 已确认单文件导致退化 | `quarantine-rollout-file.ps1` | 空任务/问题任务 A/B |
| 一致归档单任务 | 活跃任务或巨型 rollout 已确认 | `archive-thread-consistently.ps1` | 任务统计、rollout、重启复验 |
| 隔离陈旧临时文件 | 陈旧文件数量或体积异常 | `quarantine-stale-temp-files.ps1` | 临时文件统计、启动时间 |
| 移除一个保存的工作区入口 | 精确入口异常或过宽 | `remove-stale-workspace-state.ps1` | 工作区状态、重启侧栏 |
| 移除 Windows 的 WSL 标志 | 检出变量且观察到 `wsl.exe` | `remove-wsl-environment-marker.ps1` | 重启 Windows 后检查子进程 |
| 阻断日志插入 | DB 完整、WAL 持续增长、TRACE 主导 | `block-log-inserts.ps1` | WAL、CPU、I/O |
| 恢复日志插入 | trigger 无效或需要恢复 | `restore-log-inserts.ps1` | trigger 列表、日志增长 |
| 恢复备份 | 修复无效或副作用 | `restore-codex-backup.ps1` | DB 完整性、配置、任务可见性 |

先预览：

```powershell
& "$skillRoot\scripts\remediation\block-log-inserts.ps1" -WhatIf
```

用户再次确认后，去掉 `-WhatIf`。不要同时运行第二个修复脚本。

## 可执行参考命令

应用修复前确认 Codex 已退出：

```powershell
Get-Process Codex,codex -ErrorAction SilentlyContinue
```

手工查看数据库结构，禁止先假设表名：

```powershell
sqlite3 "$env:USERPROFILE\.codex\logs_2.sqlite" ".schema"
sqlite3 "$env:USERPROFILE\.codex\logs_2.sqlite" "PRAGMA integrity_check;"
```

参考 trigger SQL；优先调用脚本，因为脚本会备份和验证 schema：

```sql
CREATE TRIGGER block_log_inserts
BEFORE INSERT ON logs
BEGIN
  SELECT RAISE(IGNORE);
END;
```

恢复命令：

```sql
DROP TRIGGER IF EXISTS block_log_inserts;
```

## 无法可靠脚本化的修复

- renderer 重启后暂时恢复：更新到已知稳定版，或在明确版本回归证据下回退；保留前后版本和采样。
- 最大化窗口冻结：使用近全屏恢复窗口，等待上游修复。
- GPU 视觉异常：一次只测试一个渲染参数或虚拟显示驱动，记录可逆步骤。
- 插件、MCP、hooks：一次停用一个，复测后决定是否保持关闭。
- 长任务 UI 恢复昂贵：新建接续任务并保留原任务；不要直接删除历史。
