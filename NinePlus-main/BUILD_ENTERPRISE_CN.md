# 企业证书云端构建

不需要 Mac。把本仓库提交到 GitHub 后，使用 `Build NinePlus Enterprise IPA` 工作流生成已签名的企业 IPA。

## GitHub Secrets

在仓库 `Settings > Secrets and variables > Actions` 添加：

- `ENTERPRISE_P12_BASE64`：企业证书 `.p12` 的 Base64。
- `ENTERPRISE_P12_PASSWORD`：`.p12` 导出密码。
- `APP_PROFILE_BASE64`：App 描述文件的 Base64。
- `WIDGET_PROFILE_BASE64`：Widget 描述文件的 Base64。

描述文件必须是企业内部分发类型，并且包含 App Group 权限。

Windows 生成 Base64：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\certificate.p12")) | Set-Clipboard
```

不要通过聊天或提交到 Git 的方式发送证书、密码、描述文件和 APNs 私钥。

## 运行工作流

打开 `Actions > Build NinePlus Enterprise IPA > Run workflow`，填写：

- App Bundle ID
- Widget Bundle ID
- App Group ID

构建完成后下载 `NinePlus-Enterprise-IPA`。

## 企业安装

企业签名 IPA 可以通过企业分发页面、MDM 或支持企业证书的安装工具安装。安装前确认设备信任对应的企业开发者证书。

## APNs

企业证书不能代替 APNs 推送密钥。秒级通知还需要配置：

- `APNS_TEAM_ID`
- `APNS_KEY_ID`
- `APNS_BUNDLE_ID`
- `APNS_AUTH_KEY_PATH` 或 `APNS_AUTH_KEY`
- `APNS_ENVIRONMENT=production`

服务端检测状态变化后才能发送推送，因此最终延迟仍受九号官方接口轮询频率和苹果推送调度影响。
