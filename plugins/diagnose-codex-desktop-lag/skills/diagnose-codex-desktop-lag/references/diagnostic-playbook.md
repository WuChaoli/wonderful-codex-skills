# Windows Codex Desktop 诊断手册

## 执行规则

要求 PowerShell 7 和 Python 3.11 或更高版本。从 skill 根目录运行，只使用当前 AI，不派发子智能体。每次只运行一个脚本并保存输出；不要并行采样 CPU、I/O、WAL，避免相互干扰。某项失败时记录错误，不伪造结果。

## 诊断清单

| 顺序 | 问题 | 脚本 |
|---|---|---|
| 1 | Codex 与 Windows 版本 | `scripts/diagnostics/get-codex-version.ps1` |
| 2 | 系统内存、磁盘余量 | `measure-system-resources.ps1` |
| 3 | 各 Codex 进程 CPU、内存 | `measure-codex-processes.ps1` |
| 4 | Codex 进程 I/O 增量 | `measure-codex-io.ps1` |
| 5 | Codex GPU engine | `measure-codex-gpu.ps1` |
| 6 | Codex 子进程 | `inspect-codex-child-processes.ps1` |
| 7 | WSL 环境标志 | `inspect-wsl-environment.ps1` |
| 8 | GPU、虚拟显示驱动 | `inspect-display-drivers.ps1` |
| 9 | `state_5.sqlite` 完整性 | `test-state-database.ps1` |
| 10 | `logs_2.sqlite` 完整性和 trigger | `test-log-database.ps1` |
| 11 | WAL 实际增长率 | `measure-log-wal-growth.ps1` |
| 12 | 日志等级、target 和估算字节 | `summarize-log-levels.ps1` |
| 13 | 活跃任务、token、元数据 | `summarize-thread-state.ps1` |
| 14 | 数据库索引到的超大 rollout | `find-large-rollout-files.ps1` |
| 15 | 超大标题、首条消息和 preview | `find-abnormal-thread-metadata.ps1` |
| 16 | `.tmp`、`tmp` 状态 | `inspect-temporary-files.ps1` |
| 17 | 保存的工作区入口 | `inspect-workspace-state.ps1` |
| 18 | 安全配置摘要 | `inspect-codex-configuration.ps1` |

调用示例：

```powershell
& "$skillRoot\scripts\diagnostics\measure-codex-processes.ps1" -SampleSeconds 15
```

## 人工对照

脚本完成后逐项操作并记录现象：

1. 新建空任务，对比问题长任务的输入、滚动和切换延迟。
2. 重启 Codex 后保持空闲两分钟，再重复 CPU、I/O、WAL 采样。
3. 对比最大化窗口与略小于全屏的恢复窗口。
4. 若侧栏闪烁或透明，临时使用软件渲染启动方式做对照；不要把它当永久修复。
5. 若存在多个 MCP、插件或 hooks，一次停用一个并复测；不要批量关闭。

## 完整诊断报告

```markdown
# Codex Desktop 性能诊断报告
## 环境信息
## 资源采样
## 数据库与日志
## 任务与历史
## 配置、临时文件和工作区
## 人工对照
## 已确认问题（证据、影响、置信度）
## 已排除问题（排除依据）
## 尚未确认（原因、补充方法）
## 修复建议（每项风险、收益、前置条件、回滚）
## 下一步（等待用户只选择一项）
```
