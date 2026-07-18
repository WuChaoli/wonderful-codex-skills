---
name: diagnose-codex-desktop-lag
description: Use when Codex Desktop on Windows, macOS, or Linux freezes, stutters, renders slowly, consumes high CPU, GPU, memory, or disk I/O, grows logs_2.sqlite WAL files, spawns repeated child processes, or becomes slow with large thread history.
version: 0.2.0
metadata:
  category: Codex Tools
---

# Diagnose Codex Desktop Lag

## 核心原则

先完成证据采集，再提出修复；用户确认后一次只执行一项修复，随后复测。只在当前 AI 任务内工作，不派发子智能体。诊断脚本必须逐个手动运行，禁止创建或运行“全部诊断”总控脚本。

## 工作协议

1. 阅读 [diagnostic-playbook.md](references/diagnostic-playbook.md) 和 [symptom-matrix.md](references/symptom-matrix.md)。记录用户要求保留的配置和目录。
2. 按清单逐个运行所有适用命令：`node <skill-dir>/scripts/codex-performance.mjs diagnose <check>`。每项记录 `ok`、`warning`、`error` 或 `skipped`；跳过时写明原因。诊断阶段不修改文件、配置、环境变量或数据库。
3. 完成全部适用诊断和人工对照后，按模板给出完整诊断报告。区分“已确认”“已排除”“尚未确认”，并为每条修复建议提供证据、风险、收益和回滚方式。
4. 停止并等待用户确认一项建议。不要把多个修复合并到一个确认中。
5. 用户确认后，阅读 [remediation-playbook.md](references/remediation-playbook.md)，只对该项运行 `remediate <action> --what-if`。展示预览并再次等待 `--apply` 确认。
6. 应用确认后只执行这一项。立即重跑关联诊断，比较修复前后数据，然后停止并询问是否处理下一项。

## 硬性边界

- 完整诊断前不清缓存、不隔离会话、不改 SQLite、不重建 `state_5.sqlite`。
- 修复脚本运行前退出 Codex；涉及状态时先备份。默认不删除，只隔离或保留可恢复副本。
- 不递归扫描整个 `~/.codex`，只读取清单中的明确文件和目录。
- 不通过单独设置 `threads.archived=1` 归档；会话 JSONL 留在 `sessions` 时可能被重新激活。
- 只有数据库完整、WAL 持续增长且 TRACE 占主要新增量时，才建议阻断日志插入。
- 真实项目目录（包括名为 `codespace` 的目录）不在修复范围内。只可在用户确认后移除 Codex 保存的工作区入口。
- 保留用户指定的 `show-context-window-usage`；除非用户明确要求修改该配置。

## 停止信号

发现以下想法时停止：立即清所有缓存、顺便修其他问题、用户很急所以跳过诊断、数据库完整所以可以直接重建、会话多所以全部归档。它们都不能替代证据和逐项确认。

停止信号只停止修改，不停止工作。用户要求跳过诊断或一次修完时，继续执行安全、只读的完整诊断；不要把拒绝批量修复变成等待用户重新授权诊断。

| 常见借口 | 事实 |
|---|---|
| “先清理再看” | 修改会破坏基线，先测量。 |
| “一次确认等于全部授权” | 每项修复的风险和回滚不同。 |
| “WAL 很大就是正在高速写” | 文件大小不是增长率。 |
| “归档只改数据库即可” | 会话协调可能恢复活跃状态。 |
