# OneHub App 发版配置教程（正式签名 + GitHub Secrets）

> 2026-09-21 整理。背景：`ZhaoStar/onehubapp` 与 `ZhaoStar/onehubserver` 都是公开仓库，
> 签名文件不能提交进仓库；而缺少签名文件时 `android/app/build.gradle.kts` 会自动回退成
> debug 签名，打出来的包无法覆盖安装手机上已装的正式签名版本，用户只会看到
> 「安装失败 - 已安装了签名冲突的应用」。

## 一、添加 5 个 GitHub Secret（必做）

打开：<https://github.com/ZhaoStar/onehubapp/settings/secrets/actions>
依次点 **New repository secret**，按下表逐条添加（名称必须完全一致、区分大小写）：

| Secret 名称 | 值从哪里来 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | 正式签名库 base64，生成命令见下方 |
| `ANDROID_KEYSTORE_PASSWORD` | `android/key.properties` 里的 `storePassword` |
| `ANDROID_KEY_PASSWORD` | `android/key.properties` 里的 `keyPassword` |
| `ANDROID_KEY_ALIAS` | `upload` |
| `APK_UPLOAD_SECRET` | 服务器 `/root/onehubserver/.env` 里的 `APK_UPLOAD_SECRET`（本机备份：`C:\Users\zhaos\onehub-apk-upload-secret.txt`） |

生成 `ANDROID_KEYSTORE_BASE64`（在项目根目录执行，直接复制到剪贴板）：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\app\upload-keystore.jks")) | Set-Clipboard
```

注意事项：

- 粘贴时不要带引号和多余换行；GitHub 会自动去掉首尾空白。
- 值只放 GitHub Secrets，不要写进任何文件再提交（仓库是公开的）。
- `APK_UPLOAD_SECRET` 已于 2026-09-21 轮换：旧密钥作废，服务端改为从 `.env` 读取
  （`onehubserver/app/api/v1/app_version.py`，未配置时接口返回 503），GitHub Secret 必须与服务器 `.env` 保持一致，否则上传返回 403。
- 本机签名库固定在 `android/app/upload-keystore.jks`（`CN=onehubapp, OU=Mobile, O=OneHub, L=Shenzhen, ST=Guangdong, C=CN`，SHA-256 `82eac4c0…`）。
  换机器时请从安全位置取回同一个 jks，**不要重新生成**，否则老用户必须卸载重装。

## 二、推送代码即自动发版

```powershell
git add .github android lib docs
git commit -m "ci: 使用正式签名打包并校验签名后再发布"
git push origin main
```

推送后 `.github/workflows/build-and-deploy-apk.yml` 依次执行：

1. 安装依赖 → 跑 `flutter test`
2. **还原签名**（从 Secrets 生成 `android/app/upload-keystore.jks` 与 `android/key.properties`），缺少密钥直接失败
3. 打包 `flutter build apk --release --target-platform android-arm64`
4. 定位 APK、算出体积与提交信息
5. **校验签名**：发现 `Android Debug` 直接失败，杜绝 debug 包发出去
6. 上传到 `https://api.onehubai.online/api/v1/app/version/upload`
7. 无论成败都把 APK 存成 workflow artifact（服务器上传失败时也能手动下载安装）

版本号规则：`versionCode = max(GitHub run_number, pubspec.yaml 里的 +N)`，`versionName` 取 `pubspec.yaml` 中 `version:` 的前半段。

## 三、看运行结果

仓库 **Actions → Build and Deploy Android APK → 最新一次运行**：

- 成功时最后一步打印 `Successfully published v1.1.0 (code: N) to OneHub server!`
- 失败时展开红色步骤看日志，对照下表处理

| 日志里的报错 | 原因 | 处理 |
| --- | --- | --- |
| `缺少仓库 Secret ANDROID_KEYSTORE_BASE64` | 没加或名字写错 | 回到第一步 |
| `APK 仍是 debug 签名` | 签名 4 个 Secret 有误 | 检查 base64、密码、别名 |
| `缺少仓库 Secret APK_UPLOAD_SECRET` | 没加上传密钥 | 回到第一步 |
| `413` | 服务端 nginx 请求体上限 | 服务器已把 20M 调到 100M；再超继续调大 |
| `status code: 000 / 520 / 524` | Cloudflare→nginx→后端链路超时 | 重跑一次，或改用第五节的方式发布 |

## 四、验证线上包（强烈建议每次发完都跑一遍）

```powershell
curl.exe -s "https://api.onehubai.online/api/v1/app/version/latest?current_build=1&platform=android"
curl.exe -s -o "$env:TEMP\check.apk" "https://api.onehubai.online/api/v1/app/version/download"
& "$env:LOCALAPPDATA\Android\Sdk\build-tools\37.0.0\apksigner.bat" verify --print-certs "$env:TEMP\check.apk"
```

证书必须是 `CN=onehubapp…`（SHA-256 `82eac4c0…`）；如果显示 `CN=Android Debug`，说明又发成 debug 包了。

## 五、备用发布方式（绕过 Cloudflare，最稳）

```powershell
scp -o BatchMode=yes build\app\outputs\flutter-apk\app-release.apk myserver:/tmp/app.apk
ssh myserver "curl -s -X POST http://172.17.0.1:8000/api/v1/app/version/upload -F 'file=@/tmp/app.apk' -F 'secret=<上传密钥>' -F 'version_name=1.1.0' -F 'version_code=9' -F 'update_log=修复若干问题'; rm -f /tmp/app.apk"
```

说明：该接口只更新 `versionName / versionCode / updateLog / fileSize / publishDate`，
`downloadUrl` 沿用 `version.json` 里的现值（当前是 `https://api.onehubai.online/api/v1/app/version/download`）。

## 六、服务器侧现状（2026-09-21 已处理）

- nginx 跑在 Docker 容器 `onehub-https-proxy`，配置在宿主机 `/root/onehub-proxy/conf.d/onehubai.online.conf`：
  `client_max_body_size` 由 `20M` 改为 `100M`（两处），已 `nginx -t && nginx -s reload`；
  改动前备份为 `onehubai.online.conf.bak-20260921`。
- 已用正式签名包发布 `versionCode 8 / 1.1.0 / 19.2MB`。
- `/static/apk/onehubapp-latest.apk` 会被 Cloudflare 缓存 4 小时，所以 `downloadUrl` 改成了
  动态接口 `/api/v1/app/version/download`（`cf-cache-status: DYNAMIC`，不受缓存影响）。
- 客户端下载地址会追加 `?v=<versionCode>`（见 `AppVersionInfo.freshDownloadUrl`），进一步避免拿到缓存的旧包。
- `APK_UPLOAD_SECRET` 已轮换并迁到 `.env`（服务器 `.env.bak-20260921` 为改动前备份）；上传接口改为
  流式写盘 + 原子替换（先写 `onehubapp-latest.apk.part` 再 `os.replace`），上传中断不会再破坏线上正在分发的包。

## 七、建议的后续加固

1. 官方签名的 jks 与密码只保留在可信位置 + GitHub Secrets，本地 `android/key.properties` 继续由 `.gitignore` 排除。
2. 需要回滚时，用第五节的命令重新上传旧 APK 即可（版本号必须递增，否则手机不会提示更新）。
3. 再要换 `APK_UPLOAD_SECRET` 时：只改服务器 `.env`（`openssl rand -hex 32` 生成）→ 重启后端 → 同步更新 GitHub Secret，不需要动代码。
