# ChatGPT Fast Update Tool

**Microsoft Store 安装包更新、补丁和便携化工具 / Microsoft Store updater, patcher and portable builder**

[中文说明](#中文) · [English](#english)

> 本项目不是 OpenAI 官方产品。它只处理当前 Windows 用户本机已经安装的 `OpenAI.Codex` Microsoft Store 包，不包含账号、Cookie、Token 或其他登录凭据。

## 中文

### 1. 这是什么

`ChatGPT-Fast-Update-Tool` 用一个可重复执行的 PowerShell 脚本，把 Microsoft Store 中最新的 `OpenAI.Codex` 安装内容复制到一个独立目录，然后解包和重新打包 `resources\app.asar`，应用 ChatGPT/Codex Fast 模式相关补丁。

它解决的问题是：Store 更新后，之前生成的 `ChatGPT Fast` 目录不会自动继承新版本文件；重新运行本工具即可从当前 Store 版本重建，而不需要手工解包、修改或打包 ASAR。

### 2. 主要功能

- 自动选择已安装的最新 `OpenAI.Codex` Store 版本。
- 复制官方 `app` 目录到独立的便携目录。
- 使用 `npx @electron/asar` 解包和重新打包 `app.asar`。
- 修改 Speed 可见性、Fast service-tier 权限和请求 gate。
- 尝试补充内置 `Standard / Fast` 选项；新版前端模式变化时会跳过可选补丁而继续使用模型目录。
- 为修改过的 JS、`config.toml`、模型目录和原始 `app.asar` 保留备份。
- 保留旧构建中的 `UserData`，避免登录态和本地数据因更新丢失。
- 创建桌面和开始菜单中的 `ChatGPT Fast` 快捷方式。
- 可选择更新后自动启动新构建。

### 3. 目录结构

```text
ChatGPT-Fast-Update-Tool/
├─ refresh-chatgpt-fast.ps1       # 主更新脚本
├─ run-update.cmd                  # 双击执行的包装器
├─ CODEX_FAST_UPDATE_GUIDE.md     # 原始中文操作说明
├─ PROMPT_FOR_CODEX.txt           # 可直接交给 Codex 的任务提示词
└─ README.md                       # 本文档
```

### 4. 环境要求

1. Windows 10/11。
2. Microsoft Store 已安装 `OpenAI.Codex`（脚本通过 `Get-AppxPackage OpenAI.Codex` 查找）。
3. PowerShell 5.1 或 PowerShell 7+。
4. Node.js，并且 `npx.cmd` 位于 `-NodeDir` 指定目录中。`npx` 会在线获取 `@electron/asar`，第一次运行需要网络。
5. 对目标目录、Store 包和 `%USERPROFILE%\.codex\config.toml` 有读写权限。

### 5. 快速开始

在本目录打开 PowerShell：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\refresh-chatgpt-fast.ps1 -ForceClose
```

`-ForceClose` 会关闭当前 `ChatGPT Fast` 进程；如果不希望脚本关闭正在运行的程序，请先手工退出并省略该参数。

只生成新目录、不自动启动：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\refresh-chatgpt-fast.ps1 -ForceClose -SkipLaunch
```

也可以直接双击 `run-update.cmd`。命令行方式更适合保存日志和排查问题。

### 6. 常用参数

```text
-Destination <path>   输出目录，默认 E:\Users\Administrator\Apps\ChatGPT-Fast
-NodeDir <path>       Node.js 目录，默认 F:\Nodejs
-ForceClose            强制关闭输出目录下仍在运行的进程
-SkipLaunch            完成重建后不启动 ChatGPT.exe
```

例如，将程序放到 D 盘并使用标准 Node.js 安装目录：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\refresh-chatgpt-fast.ps1 `
  -Destination 'D:\Apps\ChatGPT-Fast' `
  -NodeDir 'C:\Program Files\nodejs' `
  -ForceClose
```

### 7. 脚本执行流程

1. 查询当前最新的 `OpenAI.Codex` Store 包。
2. 将官方 `app` 复制到带时间戳的 staging 目录。
3. 解包 `resources\app.asar` 到 `resources\app`。
4. 在 `webview\assets` 中定位并修改 Speed/Fast 相关代码。
5. 如果存在 `%USERPROFILE%\.codex\config.toml`，备份后设置顶层 `service_tier = "fast"`，并按模型目录内容补充 Fast tier。
6. 将原始 `app.asar` 改名为 `app.asar.fastmode.bak`，重新生成补丁后的 `app.asar`。
7. 从旧输出目录移动 `UserData` 到新构建，旧构建改名为带时间戳的备份。
8. 创建快捷方式并按参数启动或跳过启动。

### 8. 备份、回滚和数据位置

脚本不会直接覆盖旧目录：

- 旧构建：`<parent>\ChatGPT-Fast.backup-YYYYMMDD-HHMMSS`。
- 原始 ASAR：新构建 `resources\app.asar.fastmode.bak`。
- 被修改文件：同目录的 `.bak-fast-<timestamp>` 文件。
- 用户数据：`<Destination>\UserData`，更新时会搬移到新构建。

回滚时先退出 `ChatGPT Fast`，再把当前目录改名，将最近的 `.backup-*` 目录恢复为 `ChatGPT-Fast`。如果只需要恢复 ASAR，可在 `resources` 中删除补丁后的 `app.asar` 并将 `app.asar.fastmode.bak` 改回 `app.asar`。

### 9. 验证更新是否成功

脚本成功结束后应看到类似输出：

```text
[ok] backed up original app.asar
[ok] rebuilt patched app.asar
[ok] preserved UserData
[ok] launched ChatGPT Fast
```

然后在应用中打开 **Settings > General > Speed**，应能看到 `Standard` 和 `Fast`。切换 Fast 后新建任务进行实际验证；旧任务可能保留原来的 service tier。

### 10. 常见问题

**`OpenAI.Codex Microsoft Store package is not installed`**

确认 Store 应用已经安装，并在 PowerShell 执行：

```powershell
Get-AppxPackage OpenAI.Codex | Sort-Object Version -Descending
```

**`npx was not found`**

将 `-NodeDir` 改为实际包含 `npx.cmd` 的目录：

```powershell
Test-Path 'C:\Program Files\nodejs\npx.cmd'
```

**`Speed visibility pattern changed` 或其他 pattern changed**

这表示 Store 更新后的压缩 JS 结构发生变化。脚本会在 staging 目录中止，不会替换现有构建。保留 staging 目录和日志，检查对应的 `webview\assets\general-settings*.js`、`use-service-tier-settings*.js` 或 `read-service-tier-for-request*.js`，更新匹配规则后再运行。`Patch-FixedFastOptions` 是可选补丁，找不到新版模式时会明确跳过。

**应用启动停在 OpenAI 标志页**

检查 `https://ab.chatgpt.com` 是否能通过当前代理访问。Statsig 初始化超时可能使启动等待变长，但本地默认配置通常仍会继续加载。

**不想改变 Codex 全局配置**

脚本发现 `%USERPROFILE%\.codex\config.toml` 后会先备份并设置 `service_tier = "fast"`。如需保留原配置，请先复制该文件；也可以在脚本运行前暂时移走它，完成后自行恢复。

### 11. 发布包

Release 页面提供以下压缩包：

```text
ChatGPT-Fast-Update-Tool-v1.0.0.zip
```

下载后解压，进入包含 `refresh-chatgpt-fast.ps1` 的目录，再按上面的快速开始命令运行。压缩包不包含 Store 应用本体、Node.js、账号数据或 `UserData`。

### 12. 许可

本仓库使用 MIT License。第三方 `@electron/asar`、Electron 和 Microsoft Store 应用仍受其各自许可证约束。

## English

### 1. Overview

`ChatGPT-Fast-Update-Tool` is a repeatable PowerShell builder for the Microsoft Store `OpenAI.Codex` package. It copies the newest Store `app` directory into an isolated destination, extracts and repacks `resources\app.asar`, and applies the local Speed/Fast service-tier patches used by the portable **ChatGPT Fast** build.

The Store application can update without updating an older portable copy. Running this tool rebuilds the portable copy from the current Store version instead of requiring manual ASAR extraction and editing.

### 2. Features

- Selects the newest installed `OpenAI.Codex` package.
- Copies the official application into a separate portable directory.
- Uses `npx @electron/asar` to extract and rebuild `app.asar`.
- Patches Speed visibility, Fast service-tier permission, and the request gate.
- Tries to provide built-in `Standard / Fast` options; an incompatible optional pattern is skipped without failing the build.
- Creates timestamped backups for JavaScript, `config.toml`, the model catalog, and the original ASAR.
- Preserves `UserData` across updates.
- Creates Desktop and Start Menu shortcuts.
- Can launch the rebuilt application automatically.

### 3. Requirements

- Windows 10 or Windows 11.
- Microsoft Store package `OpenAI.Codex` installed for the current user.
- PowerShell 5.1+.
- Node.js with `npx.cmd` available in the directory passed through `-NodeDir`; the first run downloads `@electron/asar` through `npx`.
- Read/write access to the destination and to `%USERPROFILE%\.codex\config.toml` when that file exists.

### 4. Quick start

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\refresh-chatgpt-fast.ps1 -ForceClose
```

Build without launching:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\refresh-chatgpt-fast.ps1 -ForceClose -SkipLaunch
```

For a portable location and a conventional Node.js installation:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\refresh-chatgpt-fast.ps1 `
  -Destination 'D:\Apps\ChatGPT-Fast' `
  -NodeDir 'C:\Program Files\nodejs' `
  -ForceClose
```

`run-update.cmd` is a double-click wrapper around the same command.

### 5. Parameters

| Parameter | Meaning |
|---|---|
| `-Destination <path>` | Output directory. Default: `E:\Users\Administrator\Apps\ChatGPT-Fast`. |
| `-NodeDir <path>` | Directory containing `npx.cmd`. Default: `F:\Nodejs`. |
| `-ForceClose` | Stop processes launched from the destination before rebuilding. |
| `-SkipLaunch` | Build the new copy but do not start `ChatGPT.exe`. |

### 6. Backups and rollback

The existing destination is renamed to `<name>.backup-<timestamp>`, the original ASAR becomes `resources\app.asar.fastmode.bak`, and edited files receive `.bak-fast-<timestamp>` backups. The old `UserData` directory is moved into the new build. Close the application before restoring a backup directory.

### 7. Validation and troubleshooting

After a successful run, verify the `[ok]` messages, start the application, and check **Settings > General > Speed** for `Standard` and `Fast`. A `pattern changed` error means the Store frontend changed; the script stops before replacing the existing build, so inspect the preserved staging directory and update the matching rule before retrying. The optional fixed-option patch can be skipped when the model catalog already provides the tiers.

If the application waits at the OpenAI logo, check access to `https://ab.chatgpt.com` through the active proxy. If `npx` cannot be found, pass the directory that contains `npx.cmd` through `-NodeDir`.

### 8. Release package

The release asset is:

```text
ChatGPT-Fast-Update-Tool-v1.0.0.zip
```

The archive contains the scripts and documentation only. It does not contain the Store application, Node.js, account credentials, or `UserData`.

### 9. License

MIT License. `@electron/asar`, Electron, and the Microsoft Store application remain subject to their own licenses.

