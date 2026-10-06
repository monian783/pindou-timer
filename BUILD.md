# 我勒个豆计时器 — 本地构建说明

拼豆店座位计时收银 App（Flutter，安卓 + 后续 iOS）。

## 目录

| 位置 | 说明 |
| --- | --- |
| `E:\pindou_timer` | **工程本体**（必须是纯英文路径，AGP 拒绝非 ASCII 路径） |
| `E:\pindou-tools\flutter` | Flutter SDK 3.47.6 |
| `E:\pindou-tools\pub-cache` | Dart 依赖缓存 |
| `E:\pindou-tools\gradle-home` | Gradle 缓存 / GRADLE_USER_HOME |
| `E:\pindou-tools\appdata`、`localappdata` | 重定向的 Flutter 状态目录 |
| `E:\逆向\_tools\env.ps1` | 构建环境变量脚本 |
| `E:\逆向\我勒个豆计时器_v1.0.0.apk` | 打好的安装包 |

## 每次开新终端先加载环境

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
. 'E:\逆向\_tools\env.ps1'
cd E:\pindou_timer
```

## 常用命令

```powershell
flutter analyze              # 静态检查
flutter test                 # 交互冒烟测试
flutter run                  # 真机/模拟器热重载调试
flutter build apk --release  # 出安装包 -> build\app\outputs\flutter-apk\
flutter build apk --release --split-per-abi   # 分架构，包更小
```

## 本机踩过的坑（都已在配置里修好）

1. **工程路径必须纯英文**：AGP 会直接报 `project path contains non-ASCII characters` 并中止。
2. **Flutter SDK 路径也必须纯英文**：Java 用 ISO-8859-1 读 `local.properties`，
   中文路径会变成乱码（`E:\éå\...`）导致 Gradle 找不到 SDK。
3. **依赖源走阿里云镜像**：`dl.google.com` / `maven.google.com` 在本机网络下会超时。
   镜像已写入 `android/settings.gradle.kts`、`android/build.gradle.kts`，
   以及 `flutter/packages/flutter_tools/gradle/settings.gradle.kts`（后者改的是 SDK，
   重装 Flutter 后需要重新打）。
4. **NDK 版本**：Flutter 默认要 `28.2.13676358`，本机装的是 `30.0.15729638`。
   不指定的话 AGP 会去下载整个 NDK 并卡死在 SDK 仓库上，
   已在 `android/app/build.gradle.kts` 里写死为本机版本。
5. **中文路径下 `flutter analyze` 会崩**（LSP 通道按字符算长度），
   所以工程放在英文路径；工作区里的 `E:\pindou_timer` junction 已移除。
