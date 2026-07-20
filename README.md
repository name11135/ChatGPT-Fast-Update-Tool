# ChatGPT Fast Mode Rebuilder

**为非官方 API 接入重构本地 ChatGPT/Codex 客户端，使 Fast 模式可以显示并发出 Fast service tier 请求 / Rebuild the local ChatGPT/Codex client so non-official API integrations can expose and request Fast mode**

[中文说明](#中文) · [English](#english)

## 中文

### 1. 核心目的：为什么要重构 ChatGPT

当 ChatGPT/Codex 通过非官方 API、兼容接口、代理网关或自建 API 转发接入时，官方客户端的 Fast 模式通常不可用：

- 前端会根据账号/服务端返回的 `featureRequirements.fast_mode` 隐藏 Fast 选项。
- 请求前的 service-tier gate 会把 Fast 请求降级或拒绝。
- 模型目录通常不会给非官方接入显示 `fast`/`priority` tier。
- 即使手工修改配置，原版客户端也可能仍然只发送 Standard 请求。

因此，本项目不是单纯的“更新脚本”，而是**从 Microsoft Store 官方 `OpenAI.Codex` 安装包重建一个本地 ChatGPT Fast 版本**：复制官方客户端、解包 `app.asar`、修改 Fast 相关前端和请求逻辑，再重新打包到独立目录。

> 这只修改本地客户端行为，不会给非官方 API 服务端凭空增加 Fast 能力。后端网关必须识别并转发 `service_tier`/`priority`；如果后端完全不支持该字段，客户端仍可显示 Fast，但实际速度不会改变。

### 2. 具体修改了什么

脚本 `refresh-chatgpt-fast.ps1` 会在每次 Store 更新后重新应用以下修改：

| 文件/区域 | 修改内容 | 作用 |
|---|---|---|
| `webview/assets/general-settings*.js` | 强制 Speed 选项可见（将隐藏条件改为永不返回空） | 在 Settings > General > Speed 显示 Fast |
| `webview/assets/use-service-tier-settings*.js` | 绕过 `featureRequirements.fast_mode` 权限 gate | 不再因为非官方 API 的能力标记隐藏 Fast |
| `webview/assets/read-service-tier-for-request*.js` | 放开请求前的 Fast service-tier gate | 允许请求继续携带 Fast tier |
| service-tier 选项 chunk | 尝试固定生成 `Standard / Fast` 选项 | 即使模型目录不完整也能显示选项 |
| `%USERPROFILE%\.codex\config.toml` | 设置 `service_tier = "fast"` | 让 Codex 默认偏向 Fast 请求 |
| 模型目录 JSON | 为支持的模型补充 `additional_speed_tiers: ["fast"]` 和 `priority` tier | 让模型目录暴露 Fast/priority 能力 |
| `resources\app.asar` | 重新打包所有补丁后的 Electron 前端 | 生成可启动的 ChatGPT Fast 客户端 |

每次运行都会先备份原始 ASAR、被修改的 JS/配置和旧构建；原有 `UserData` 会迁移到新构建，避免登录态和本地数据丢失。

### 3. 项目不做什么

- 不修改 OpenAI 服务端，不创建 Fast 账号权限。
- 不把非官方 API 变成官方 API。
- 不包含账号、Cookie、Token、API Key 或 `UserData`。
- 不保证任何第三方网关一定实现 Fast；实际效果取决于网关是否接受并转发 tier 字段。

### 4. 目录结构

```text
ChatGPT-Fast-Update-Tool/
├─ refresh-chatgpt-fast.ps1       # 复制、解包、补丁、重打包和启动
├─ run-update.cmd                  # 双击执行的包装器
├─ CODEX_FAST_UPDATE_GUIDE.md     # 中文操作说明
├─ PROMPT_FOR_CODEX.txt           # 可直接交给 Codex 的任务提示词
├─ VERSION                         # 当前版本
└─ README.md                       # 本文档
```

### 5. 环境要求

1. Windows 10/11。
2. Microsoft Store 已安装 `OpenAI.Codex`；脚本通过 `Get-AppxPackage OpenAI.Codex` 找到官方安装目录。
3. PowerShell 5.1 或 PowerShell 7+。
4. Node.js，并且 `npx.cmd` 位于 `-NodeDir` 指定目录中。首次运行会通过 `npx` 获取 `@electron/asar`。
5. 对输出目录、Store 包和 `%USERPROFILE%\.codex\config.toml` 有读写权限。

### 6. 快速开始

在解压后的目录打开 PowerShell：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\refresh-chatgpt-fast.ps1 -ForceClose
```

只重建、不自动启动：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\refresh-chatgpt-fast.ps1 -ForceClose -SkipLaunch
```

自定义输出目录和 Node.js：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\refresh-chatgpt-fast.ps1 `
  -Destination 'D:\Apps\ChatGPT-Fast' `
  -NodeDir 'C:\Program Files\nodejs' `
  -ForceClose
```

也可以双击 `run-update.cmd`。

### 7. 参数

```text
-Destination <path>   输出目录，默认 E:\Users\Administrator\Apps\ChatGPT-Fast
-NodeDir <path>       Node.js 目录，默认 F:\Nodejs
-ForceClose            强制关闭输出目录下的旧 ChatGPT Fast 进程
-SkipLaunch            完成重建后不启动 ChatGPT.exe
```

### 8. 执行流程

1. 选择当前最新的 Store `OpenAI.Codex` 版本。
2. 将官方 `app` 复制到带时间戳的 staging 目录。
3. 解包 `resources\app.asar` 到 `resources\app`。
4. 定位 `general-settings`、`use-service-tier-settings`、`read-service-tier-for-request` 等压缩 JS。
5. 应用 Speed/Fast 可见性、权限 gate、请求 gate 和模型目录补丁。
6. 设置 `service_tier = "fast"`，备份原始配置。
7. 备份原始 ASAR，使用 `@electron/asar` 重新打包。
8. 迁移旧 `UserData`，备份旧构建，创建桌面/开始菜单快捷方式。
9. 按参数启动或跳过启动。

### 9. 验证 Fast 是否真的生效

1. 启动 `ChatGPT Fast`。
2. 打开 **Settings > General > Speed**，确认出现 `Standard` 和 `Fast`。
3. 选择 Fast，新建一次任务。
4. 检查实际请求或网关日志，确认 `service_tier`/`priority` 被接收并转发。

只看到 UI 选项并不等于服务端已经提速；非官方 API 网关必须支持对应字段。

### 10. 备份、回滚和数据位置

- 旧构建：`<parent>\ChatGPT-Fast.backup-YYYYMMDD-HHMMSS`。
- 原始 ASAR：`resources\app.asar.fastmode.bak`。
- 被修改文件：同目录的 `.bak-fast-<timestamp>`。
- 用户数据：`<Destination>\UserData`，更新时会搬移到新构建。

回滚前退出 ChatGPT Fast，再将当前目录改名并恢复最近的 `.backup-*` 目录；也可以把 `app.asar.fastmode.bak` 改回 `app.asar`。

### 11. 常见问题

**`OpenAI.Codex Microsoft Store package is not installed`**

```powershell
Get-AppxPackage OpenAI.Codex | Sort-Object Version -Descending
```

**`npx was not found`**

```powershell
Test-Path 'C:\Program Files\nodejs\npx.cmd'
```

然后把实际目录传给 `-NodeDir`。

**`pattern changed`**

说明 Store 新版本的压缩 JS 结构发生变化。脚本会停在 staging，不替换现有构建；检查对应的 `webview\assets` 文件，更新匹配规则后再运行。`Patch-FixedFastOptions` 是可选补丁，找不到新版模式时会跳过。

**Fast 显示了但没有提速**

检查非官方 API 网关是否识别 `service_tier`、`fast` 或 `priority`，以及是否把字段转发给上游；客户端补丁不能替代服务端实现。

**启动停在 OpenAI 标志页**

检查 `https://ab.chatgpt.com` 是否能通过当前代理访问；Statsig 超时可能使启动等待变长。

### 12. Release 包

```text
ChatGPT-Fast-Update-Tool-v1.0.0.zip
```

压缩包只包含脚本和文档，不包含 Store 应用本体、Node.js、账号数据或 `UserData`。

### 13. 许可

MIT License。`@electron/asar`、Electron 和 Microsoft Store 应用仍受各自许可证约束。

## English

### 1. Why this project exists

When ChatGPT/Codex is connected through a non-official API, compatibility endpoint, proxy gateway, or self-hosted relay, Fast mode is usually unavailable or ineffective:

- the frontend hides Fast when `featureRequirements.fast_mode` is not granted;
- the request-side service-tier gate can reject or downgrade Fast;
- the model catalog does not expose `fast` or `priority` tiers for the non-official route;
- changing a config file alone may still leave the original client sending Standard requests.

This project therefore **rebuilds a local ChatGPT Fast client from the official Microsoft Store `OpenAI.Codex` package**. It copies the official app, extracts `app.asar`, patches the local frontend/request gates, and repacks an isolated portable build.

The patch is client-side. It does not add Fast capability to a server. The non-official gateway must accept and forward `service_tier`/`priority`; if the gateway ignores those fields, the UI can show Fast but the backend will not become faster.

### 2. Exact changes

| File or area | Change | Result |
|---|---|---|
| `webview/assets/general-settings*.js` | Force the Speed options component to remain visible | Fast appears under Settings > General > Speed |
| `webview/assets/use-service-tier-settings*.js` | Bypass the `featureRequirements.fast_mode` permission gate | Fast is not hidden by non-official capability metadata |
| `webview/assets/read-service-tier-for-request*.js` | Open the request-side Fast tier gate | Fast tier requests can continue to the API route |
| service-tier option chunk | Try to provide fixed `Standard / Fast` options | The selector remains usable when the catalog is incomplete |
| `%USERPROFILE%\.codex\config.toml` | Set `service_tier = "fast"` | Codex defaults to the Fast tier when supported |
| model catalog JSON | Add `additional_speed_tiers: ["fast"]` and a `priority` tier to eligible models | The client exposes Fast/priority capability |
| `resources\app.asar` | Repack the patched Electron frontend | Produces the standalone ChatGPT Fast build |

The script backs up the original ASAR and edited files, preserves `UserData`, and keeps the previous portable build for rollback.

### 3. Scope and limitations

- This is a local client rebuild, not a server-side Fast implementation.
- It does not convert a non-official API into the official API.
- It ships no account, cookie, token, API key, or `UserData`.
- Actual acceleration depends on the non-official gateway accepting and forwarding the tier fields.

### 4. Requirements

- Windows 10/11.
- Microsoft Store package `OpenAI.Codex` installed for the current user.
- PowerShell 5.1+.
- Node.js with `npx.cmd` in the directory passed through `-NodeDir`; the first run downloads `@electron/asar`.
- Read/write access to the destination and `%USERPROFILE%\.codex\config.toml` when present.

### 5. Quick start

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\refresh-chatgpt-fast.ps1 -ForceClose
```

Build without launching:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\refresh-chatgpt-fast.ps1 -ForceClose -SkipLaunch
```

Portable location and Node.js override:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\refresh-chatgpt-fast.ps1 `
  -Destination 'D:\Apps\ChatGPT-Fast' `
  -NodeDir 'C:\Program Files\nodejs' `
  -ForceClose
```

`run-update.cmd` is a double-click wrapper for the same command.

### 6. Parameters and flow

`-Destination` selects the portable output, `-NodeDir` selects the directory containing `npx.cmd`, `-ForceClose` stops the old portable process, and `-SkipLaunch` avoids starting the rebuilt executable. The script selects the newest Store package, stages it, extracts `app.asar`, applies the Fast patches listed above, updates the local config/model catalog, repacks the ASAR, migrates `UserData`, creates shortcuts, and optionally launches the result.

### 7. Validation

Open **Settings > General > Speed** and confirm `Standard` and `Fast`. Select Fast and create a new task. Then inspect the actual request or gateway log to verify that `service_tier`/`priority` was accepted and forwarded. A visible selector alone does not prove that the backend supports Fast.

### 8. Backups and troubleshooting

The old build is renamed to `<name>.backup-<timestamp>`, the original ASAR becomes `resources\app.asar.fastmode.bak`, and edited files receive `.bak-fast-<timestamp>` backups. A `pattern changed` error means the Store frontend changed; the script stops before replacing the existing build. If Fast is visible but ineffective, inspect the non-official gateway's tier handling. If `npx` is missing, pass the directory containing `npx.cmd` through `-NodeDir`.

### 9. Release and license

The release asset is `ChatGPT-Fast-Update-Tool-v1.0.0.zip`. It contains scripts and documentation only, not the Store app, Node.js, credentials, or `UserData`. The repository is MIT licensed; `@electron/asar`, Electron, and the Microsoft Store app remain subject to their own licenses.

