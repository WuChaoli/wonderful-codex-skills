# wonderful-codex-skills Marketplace 设计说明

## 目标

创建公开 GitHub 仓库 `WuChaoli/wonderful-codex-skills`，作为可长期扩展的 Codex Plugin Marketplace。首个 Plugin 为 `fix-codex-retry-loop`，归入 `Codex Tools` 分类。

## 设计原则

- 遵循 Codex 官方 Plugin 和 Marketplace 目录约定。
- Plugin 在 `plugins/` 下平铺，避免分类目录破坏脚手架、安装路径和自动校验。
- 分类由 marketplace `category`、Plugin `keywords` 和 README 索引共同表达。
- 每个 Plugin 独立版本化、校验和测试；仓库可持续加入不同类别。
- 公开仓库不包含用户代理配置、API 密钥、备份文件或机器专属路径。

## 仓库结构

```text
wonderful-codex-skills/
├── .agents/plugins/marketplace.json
├── plugins/
│   └── fix-codex-retry-loop/
│       ├── .codex-plugin/plugin.json
│       └── skills/fix-codex-retry-loop/
│           ├── SKILL.md
│           ├── agents/openai.yaml
│           └── scripts/fix_codex_proxy.ps1
├── tests/
├── .github/workflows/validate.yml
├── docs/superpowers/specs/
├── README.md
├── CONTRIBUTING.md
└── LICENSE
```

Skill 的开发测试放在仓库根 `tests/`，不进入最终 Skill 包目录。设计与实现计划保留在 `docs/superpowers/`，作为维护依据。

## 分类体系

| 分类 | 范围 | 当前内容 |
|---|---|---|
| Codex Tools | Codex 配置、网络、环境、诊断和维护 | fix-codex-retry-loop |
| Development | 编码、测试、调试和 CI/CD | 暂无 |
| Design | UI、视觉、交互和设计工作流 | 暂无 |
| Productivity | 文档、信息整理和个人效率 | 暂无 |
| Other | 尚未形成稳定类别的 Plugin | 暂无 |

新增 Plugin 时必须选择一个现有分类；只有出现无法合理归类的稳定主题时才新增分类。

## 首个 Plugin

`fix-codex-retry-loop` 使用版本 `0.1.0` 和 MIT 许可证。Plugin manifest 指向 `./skills/`，并提供作者、仓库、主页、关键词及安装界面元数据。

该 Skill Windows 优先，功能边界保持不变：

1. 只读探测 Codex Home、现有代理、Windows 系统代理和代理监听端口。
2. 区分网络、认证和服务端错误。
3. 展示目标路径、代理 URL 和拟应用变更。
4. 仅在用户明确确认后备份并更新 `.env`。
5. 验证本地端口和 OpenAI API 网络路径。
6. 提醒用户完全退出 Codex及后台进程后重新启动。

## Marketplace

`.agents/plugins/marketplace.json` 使用稳定名称 `wonderful-codex-skills`，展示名称为 `Wonderful Codex Skills`。每个条目包含：

- `source.path`：相对 marketplace 根的 `./plugins/<plugin-name>`。
- `policy.installation`：`AVAILABLE`。
- `policy.authentication`：`ON_INSTALL`。
- `category`：使用本设计的分类值。

用户安装入口：

```powershell
codex plugin marketplace add WuChaoli/wonderful-codex-skills
```

## 文档与许可证

- 根 README 使用中英双语，先给安装命令，再列分类和 Plugin 状态。
- CONTRIBUTING 说明新增 Plugin 的目录、分类、测试和安全要求。
- 仓库与首个 Plugin 使用 MIT 许可证。
- README 不承诺代理能解决全部重试问题，明确 `401` 仅表示无凭据请求已到达服务端。

## 自动验证

Windows GitHub Actions 执行：

1. PowerShell AST 语法检查。
2. `fix_codex_proxy.Tests.ps1` 行为测试。
3. `skill_contract.Tests.ps1` Skill 契约检查。
4. Plugin manifest 与 marketplace JSON 结构检查。
5. 占位符、绝对用户路径和常见密钥模式扫描。

网络调用不进入 CI 的强制测试，避免依赖 OpenAI 或代理可用性；真实代理 Verify 保留为本地验收。

## 发布流程

1. 本地生成 Plugin 与 marketplace。
2. 复制已验证 Skill，移除机器专属内容。
3. 运行测试和官方校验器。
4. 创建公开 GitHub 仓库，提交并推送 `main`。
5. 读取远程仓库可见性、默认分支和文件结构。
6. 通过 GitHub marketplace 地址做安装发现检查。
7. 创建 `v0.1.0` Release 仅在远程 CI 通过后进行。

## 成功标准

- 远程仓库公开且默认分支为 `main`。
- Marketplace 和 Plugin 均通过本地校验。
- Windows CI 通过。
- 用户可使用仓库简写添加 marketplace，并看到 `fix-codex-retry-loop`。
- 公开内容不存在本机用户名路径、密钥、代理凭据或 `.env` 文件。
- README 清晰展示未来 Development、Design、Productivity 和 Other 分类扩展位置。
