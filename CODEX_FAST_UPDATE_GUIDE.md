# ChatGPT Fast 模式重构说明

## 核心目的

通过非官方 API、兼容接口或代理网关接入 ChatGPT/Codex 时，原版客户端通常不能使用 Fast 模式：前端会隐藏 Fast，service-tier gate 会拒绝或降级请求，模型目录也不会暴露 `fast`/`priority`。

本工具因此从 Microsoft Store 的官方 `OpenAI.Codex` 包复制出一份本地客户端，解包 `resources\app.asar`，修改 Fast 相关前端和请求逻辑，再重新打包成独立的 `ChatGPT Fast`。这是客户端重构，不是服务端改造；网关仍必须支持并转发 `service_tier`/`priority`。

## 修改内容

1. `general-settings*.js`：强制 Speed 选项保持可见。
2. `use-service-tier-settings*.js`：绕过 `featureRequirements.fast_mode` 权限 gate。
3. `read-service-tier-for-request*.js`：放开请求前的 Fast gate。
4. service-tier 选项 chunk：尝试提供固定的 `Standard / Fast` 选项。
5. `%USERPROFILE%\.codex\config.toml`：设置 `service_tier = "fast"`。
6. 模型目录 JSON：为支持的模型补充 `additional_speed_tiers` 和 `priority` tier。
7. 重新打包 `app.asar`，保留原始 ASAR、旧构建和 `UserData` 备份。

## 更新命令

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\refresh-chatgpt-fast.ps1 -ForceClose
```

只重建、不启动：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\refresh-chatgpt-fast.ps1 -ForceClose -SkipLaunch
```

自定义路径：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\refresh-chatgpt-fast.ps1 `
  -Destination 'D:\Apps\ChatGPT-Fast' `
  -NodeDir 'C:\Program Files\nodejs' `
  -ForceClose
```

## 验证

启动后进入 **Settings > General > Speed**，确认有 `Standard` 和 `Fast`。选择 Fast 新建任务，并检查非官方 API 网关日志是否接收到并转发 `service_tier`/`priority`。仅看到 UI 选项不能证明服务端已经提速。

如果提示 `pattern changed`，说明 Store 新版压缩 JS 结构变化；脚本会在 staging 目录中止，不会替换当前构建。更新匹配规则后再运行。

