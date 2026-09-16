# OneHub 移动端一键本地打包并发布到服务器脚本
param (
    [string]$ServerHost = "api.onehubai.online",
    [string]$ServerUser = "root",
    [int]$ServerPort = 22,
    [string]$UpdateLog = "日常更新与体验优化",
    [int]$VersionCode = 0
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  OneHub App 本地一键打包与发布工具" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. 确定版本构建号
$pubspecPath = "pubspec.yaml"
$pubspecContent = Get-Content $pubspecPath -Raw
if ($pubspecContent -match 'version:\s*(\d+\.\d+\.\d+)\+(\d+)') {
    $baseVer = $matches[1]
    $currentCode = [int]$matches[2]
} else {
    $baseVer = "1.0.0"
    $currentCode = 1
}

if ($VersionCode -gt 0) {
    $newCode = $VersionCode
} else {
    $newCode = $currentCode + 1
}

$newVerName = "$baseVer"
$newVersionString = "$newVerName+$newCode"

Write-Host "[1/4] 更新版本号为: $newVersionString" -ForegroundColor Yellow
$newPubspec = $pubspecContent -replace 'version:\s*\d+\.\d+\.\d+\+\d+', "version: $newVersionString"
Set-Content -Path $pubspecPath -Value $newPubspec -NoNewline

# 2. 编译 Release APK
Write-Host "[2/4] 开始编译 Release APK (flutter build apk --release)..." -ForegroundColor Yellow
flutter build apk --release --build-name=$newVerName --build-number=$newCode
if ($LASTEXITCODE -ne 0) {
    Write-Host "编译失败，请检查错误日志！" -ForegroundColor Red
    exit 1
}

$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $apkPath)) {
    Write-Host "未找到生成的 APK 文件: $apkPath" -ForegroundColor Red
    exit 1
}

$fileItem = Get-Item $apkPath
$sizeMb = [math]::Round($fileItem.Length / 1MB, 1)
$fileSizeStr = "$sizeMb" + "MB"
$publishDate = Get-Date -Format "yyyy-MM-dd HH:mm"

Write-Host "[3/4] 编译成功！APK 大小: $fileSizeStr" -ForegroundColor Green

# 3. 生成 version.json
$versionJsonObj = @{
    versionCode = $newCode
    versionName = $newVerName
    minVersionCode = 1
    downloadUrl = "https://$ServerHost/static/apk/onehubapp-latest.apk"
    fileSize = $fileSizeStr
    updateLog = $UpdateLog
    publishDate = $publishDate
    forceUpdate = $false
}
$versionJsonStr = $versionJsonObj | ConvertTo-Json -Depth 4
$localDistDir = "build\dist"
if (-not (Test-Path $localDistDir)) {
    New-Item -ItemType Directory -Path $localDistDir | Out-Null
}
$versionJsonPath = "$localDistDir\version.json"
Set-Content -Path $versionJsonPath -Value $versionJsonStr -Encoding UTF8

Copy-Item -Path $apkPath -Destination "$localDistDir\onehubapp-latest.apk" -Force

Write-Host "[4/4] 准备上传至服务器 $ServerUser@$ServerHost..." -ForegroundColor Yellow
Write-Host "目标目录: /root/onehubserver/static/apk/" -ForegroundColor DarkGray
Write-Host "如需通过 SSH 上传，请确保本地已配置好 SSH Key。" -ForegroundColor DarkGray

try {
    ssh -p $ServerPort -o StrictHostKeyChecking=no "$ServerUser@$ServerHost" "mkdir -p /root/onehubserver/static/apk/"
    scp -P $ServerPort -o StrictHostKeyChecking=no "$localDistDir\onehubapp-latest.apk" "$ServerUser@$ServerHost:/root/onehubserver/static/apk/onehubapp-latest.apk"
    scp -P $ServerPort -o StrictHostKeyChecking=no "$versionJsonPath" "$ServerUser@$ServerHost:/root/onehubserver/static/apk/version.json"
    Write-Host "`n==========================================" -ForegroundColor Green
    Write-Host "  发布成功！手机端 App 打开即可检测到更新！" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
} catch {
    Write-Host "直接 SSH 上传遇到提示，您也可以将代码 git push 到 GitHub，由 GitHub Actions 自动打包发布。" -ForegroundColor Yellow
}
