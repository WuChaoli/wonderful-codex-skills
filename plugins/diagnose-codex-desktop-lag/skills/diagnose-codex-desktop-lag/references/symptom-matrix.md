# 症状与证据矩阵

下列阈值是排查启发式，不是 Codex 官方规格。GitHub Issue 是用户复现证据，未关闭的 Issue 不等于已确认根因。

| 现象 | 支持证据 | 排除证据 | 候选方案 |
|---|---|---|---|
| renderer 持续占用单核 | renderer 高 CPU，后端/I/O 低 | CPU 随真实子任务结束而下降 | 重启、空任务 A/B、版本对比 |
| 会话历史负载 | 活跃任务多、元数据大、少数 rollout 巨大 | 新旧任务同样卡且历史较小 | 逐个归档或隔离已确认候选 |
| TRACE 日志压力 | WAL 持续增长、写入率高、TRACE 字节占比高 | WAL 稳定或 I/O 接近零 | 备份后阻断插入 |
| Git/WSL churn | 多个短命 `git.exe`/`wsl.exe` 与卡顿同步 | 仅偶发且 CPU 很低 | 修正环境或项目触发条件 |
| GPU/窗口问题 | 最大化透明/冻结，恢复窗口正常 | 窗口状态无差异 | 近全屏、驱动/渲染 A/B |
| 系统资源不足 | 可用内存低、系统盘接近满 | 资源余量充足 | 先处理系统资源 |

## 参考证据

- 大历史与侧栏负载：[openai/codex#18693](https://github.com/openai/codex/issues/18693)、[#24510](https://github.com/openai/codex/issues/24510)
- renderer 空转高 CPU：[#20435](https://github.com/openai/codex/issues/20435)
- Windows WSL 环境变量冻结：[#22376](https://github.com/openai/codex/issues/22376)
- SQLite TRACE/WAL 写入：[#17320](https://github.com/openai/codex/issues/17320)
- Windows 最大化窗口渲染冻结：[#25513](https://github.com/openai/codex/issues/25513)
- Git 子进程 churn：[#22085](https://github.com/openai/codex/issues/22085)
- 直接修改 archived 后被协调恢复：[#23851](https://github.com/openai/codex/issues/23851)

## 建议判断线

- CPU：持续采样，不用单个瞬时值；`50%` 单逻辑核以上只标记为候选。
- WAL：必须看字节/秒；仅文件很大不能证明当前正在写。
- rollout：默认从 `8 MB` 开始列候选，不自动认定为根因。
- 任务：活跃数超过 `500` 或存在 `100M+` token 任务时提高关注度，不自动批量归档。
- 临时文件：陈旧文件超过 `1000` 或 `500 MB` 时提高关注度，不自动清理。
