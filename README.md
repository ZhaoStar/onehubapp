# onehubapp — Flutter 项目文件结构说明

> 🎯 本文档面向新手，逐项解释项目里每个文件和文件夹是干什么用的。


## 📂 项目根目录文件

| 文件 | 作用 |
|------|------|
| `pubspec.yaml` | ⭐ **项目配置文件**。定义项目名称、版本、依赖包、字体、图片资源等，相当于项目的"身份证"。 |
| `pubspec.lock` | **依赖锁定文件**。自动生成，记录了每个依赖包的确切版本号，保证团队所有人安装的包版本一致。**不要手动修改**。 |
| `analysis_options.yaml` | **代码检查规则**。配置 Dart 静态分析器，帮你检查代码中的错误、警告和不规范写法。 |
| `.gitignore` | **Git 忽略列表**。告诉 Git 哪些文件/文件夹不需要上传（如临时文件、编译产物），保持仓库干净。 |
| `.metadata` | **Flutter 项目元数据**。Flutter 自动生成，记录项目类型等信息。**不要手动修改**。 |
| `README.md` | **项目说明文档**。就是你正在看的这个文件 😄 |


## 📂 lib/ — 你的代码主战场 🔥

| 文件 | 作用 |
|------|------|
| `lib/main.dart` | ⭐ **应用入口文件**。整个 App 从这里启动，`main()` 函数是程序的起点。你写的几乎所有代码都在 `lib/` 目录下。 |

> 💡 后续开发时，你会在这里创建 `screens/`、`widgets/`、`models/`、`services/` 等子文件夹来组织代码。


## 📂 test/ — 测试代码

| 文件 | 作用 |
|------|------|
| `test/widget_test.dart` | **Widget 测试文件**。用来写自动化测试，验证界面是否正常渲染。可以运行 `flutter test` 来执行。 |


## 📂 android/ — Android 平台相关

| 文件/文件夹 | 作用 |
|-------------|------|
| `build.gradle.kts` | 项目级 Gradle 构建脚本（使用 Kotlin DSL），配置 Android 编译设置。 |
| `app/build.gradle.kts` | 应用级构建脚本，配置 App 的包名、版本号、最低 SDK 版本等。 |
| `app/src/` | Android 原生代码目录，包含 `AndroidManifest.xml`、Java/Kotlin 代码等。 |
| `settings.gradle.kts` | Gradle 设置，声明项目包含哪些模块。 |
| `gradle.properties` | Gradle 属性配置（如 JVM 参数）。 |
| `gradlew` / `gradlew.bat` | Gradle Wrapper 脚本，自动下载匹配的 Gradle 版本（macOS/Linux 用 `gradlew`，Windows 用 `gradlew.bat`）。 |
| `gradle/wrapper/` | Gradle Wrapper 的配置和 jar 包。 |
| `local.properties` | 本地配置（如 Android SDK 路径），**每个开发者不同，不要上传到 Git**。 |

> 💡 如果你不需要修改 Android 原生代码（如调用原生相机），这个目录基本不用动。


## 📂 ios/ — iOS 平台相关

| 文件/文件夹 | 作用 |
|-------------|------|
| `Runner/` | iOS 应用主体，包含 `AppDelegate.swift`（应用入口）、`Info.plist`（应用配置）、图标资源等。 |
| `Runner.xcodeproj/` | Xcode 工程文件，双击可用 Xcode 打开 iOS 项目。 |
| `Runner.xcworkspace/` | Xcode 工作空间文件，通常用这个打开而非 `.xcodeproj`。 |
| `Flutter/` | Flutter 引擎相关配置，自动生成，**不要手动修改**。 |
| `RunnerTests/` | iOS 原生测试代码。 |

> 💡 和 Android 一样，不改原生功能就不用管。只有在 Mac 上才能编译 iOS 版本。


## 📂 web/ — Web 平台

| 文件 | 作用 |
|------|------|
| `index.html` | Web 应用入口 HTML 页面，Flutter Web 应用就挂载在这个页面上。 |
| `manifest.json` | PWA（渐进式 Web 应用）清单文件，定义应用名称、图标、主题色等。 |
| `favicon.png` | 浏览器标签页上的小图标。 |
| `icons/` | PWA 应用的图标资源。 |


## 📂 windows/ — Windows 桌面平台

| 文件/文件夹 | 作用 |
|-------------|------|
| `CMakeLists.txt` | CMake 构建配置文件。 |
| `runner/` | Windows 应用主体，包含 C++ 入口代码（`main.cpp`）、窗口管理（`win32_window.cpp`）等。 |
| `flutter/` | Flutter 与 Windows 的桥接代码，自动生成。 |


## 📂 linux/ — Linux 桌面平台

| 文件/文件夹 | 作用 |
|-------------|------|
| `CMakeLists.txt` | CMake 构建配置文件。 |
| `runner/` | Linux 应用主体，包含 C++ 入口代码。 |
| `flutter/` | Flutter 与 Linux 的桥接代码，自动生成。 |


## 📂 macos/ — macOS 桌面平台

| 文件/文件夹 | 作用 |
|-------------|------|
| `Runner/` | macOS 应用主体，包含 `AppDelegate.swift`、`MainFlutterWindow.swift` 等。 |
| `Runner.xcodeproj/` | Xcode 工程文件。 |
| `Flutter/` | Flutter 引擎配置，自动生成。 |

> 💡 只能在 Mac 上编译 macOS 版本。


## 📂 build/ — 编译产物

编译后自动生成的文件夹（如打包的 APK、IPA、Web 文件等）。**已加入 `.gitignore`，不会上传**。可以随时删除，下次编译会自动重建。


## 📂 其他隐藏文件夹

| 文件夹 | 作用 |
|--------|------|
| `.dart_tool/` | Dart 工具缓存，存放包信息等。自动生成，**不要手动修改**。 |
| `.idea/` | JetBrains IDE（Android Studio / IntelliJ）的项目配置。用 VS Code 的话可以忽略。 |
| `.git/` | Git 版本控制的本地仓库，存放所有提交历史。**千万不要删除**。 |
| `.vscode/` | VS Code 的项目配置（如果有），存放启动配置、推荐插件等。可选提交到 Git。 |


## 🚀 常用命令速查

```bash
# 获取依赖包
flutter pub get

# 运行应用（连接设备或模拟器后）
flutter run

# 查看可用的设备列表
flutter devices

# 运行测试
flutter test

# 代码检查
flutter analyze

# 打包 APK（Android）
flutter build apk

# 打包 IPA（iOS，需 Mac）
flutter build ios

# 打包 Web
flutter build web
```


## 📚 学习资源

- [Flutter 官方文档](https://flutter.dev/docs)
- [Dart 语言中文网](https://dart.cn/)
- [Flutter 中文网](https://flutter.cn/)
- [pub.dev](https://pub.dev/) — 查找 Flutter/Dart 第三方包
