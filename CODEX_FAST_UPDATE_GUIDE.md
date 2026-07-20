# ChatGPT / Codex Fast 更新说明

## 结论

Microsoft Store 中的官方 ChatGPT/Codex 更新后，`ChatGPT-Fast` 不会自动继承新版文件，需要重新复制官方包并应用补丁。

不需要手工重新压缩或打包。运行一键脚本即可：

```powershell
powershell -ExecutionPolicy Bypass -File "E:\GPT5.6-5.5--main\refresh-chatgpt-fast.ps1" -ForceClose
```

如果只想生成新版本，不立即启动：

```powershell
powershell -ExecutionPolicy Bypass -File "E:\GPT5.6-5.5--main\refresh-chatgpt-fast.ps1" -ForceClose -SkipLaunch
```

脚本会自动完成：

1. 读取最新的 Microsoft Store `OpenAI.Codex` 安装目录。
2. 复制官方 `app` 到临时目录。
3. 解包 `resources/app.asar` 到 `resources/app`。
4. 修改 Speed 设置可见性和 Fast service tier 权限。
5. 强制提供 Standard / Fast 选项。
6. 给支持 Fast 的模型补充 `service_tiers`，包括 `gpt-5.5`。
7. 设置 `config.toml` 的顶层 `service_tier = "fast"`。
8. 备份原始 `app.asar`，并自动重打包含补丁的新 `app.asar`。
9. 保留旧版程序和 `UserData` 登录数据。
10. 更新桌面及开始菜单的 `ChatGPT Fast` 快捷方式。

脚本对 JavaScript、TOML 和模型目录统一使用 UTF-8 无 BOM 读写，避免 Windows PowerShell 5 将压缩脚本中的 Unicode 字符改成乱码。

## 给 Codex 的任务描述

可以将下面内容直接交给 Codex：

```text
请更新本机 ChatGPT Fast 补丁版。先检查 Microsoft Store 的 OpenAI.Codex 当前版本，
然后运行 E:\GPT5.6-5.5--main\refresh-chatgpt-fast.ps1 -ForceClose。
确认脚本成功复制官方 app、解包并重新打包 app.asar、修改 Speed/Fast gate、保留 UserData，
并验证 E:\Users\Administrator\Apps\ChatGPT-Fast\ChatGPT.exe 已启动。
如果脚本提示 minified JS pattern changed，请读取新版 webview/assets，按以下行为重新定位：
- general-settings*.js 中 Speed 组件的 isServiceTierAllowed / availableOptions 隐藏条件；
- use-service-tier-settings*.js 中 featureRequirements.fast_mode 权限条件；
- read-service-tier-for-request*.js 中 chatgpt auth gate；
- serviceTiers 选项生成函数及内置 Standard/Fast 数组。
修改脚本适配新版后重新执行，并保留原文件备份。
```

## 验证

启动桌面的 `ChatGPT Fast`，进入 `Settings > General > Speed`，应看到 `Standard` 和 `Fast`。

选择 `Fast` 后新建任务测试。旧任务可能保留原 service tier。

如果启动时长时间停留在 OpenAI 标志页，检查 `https://ab.chatgpt.com` 是否能通过当前代理访问。该 Statsig 初始化地址连接超时会让启动页额外等待；连接恢复或超时结束后，应用会继续使用本地默认配置加载。
