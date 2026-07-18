# 跨平台 Codex Desktop 修复手册

## 两次确认

完整报告后先确认要处理的单项。随后用 `--what-if` 预览该命令，展示预览，再确认是否用 `--apply` 应用。每次应用后只复测关联指标。

## 脚本化修复

| 修复 | 前置证据 | 脚本 | 复测 |
|---|---|---|---|
| 任一修复 | 对应诊断已确认 | `node scripts/codex-performance.mjs remediate <action> --what-if` | 预览后才允许 `--apply` |

先预览：

```powershell
node "$skillRoot/scripts/codex-performance.mjs" remediate block-log-inserts --what-if
```

用户再次确认后，将 `--what-if` 改为 `--apply`。不要同时运行第二个修复命令。

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
