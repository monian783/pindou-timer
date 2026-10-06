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
| `E:\逆向\我勒个豆计时器_v1.1.0.apk` | 打好的安装包 |

打包出来的 APK 每次都会复制一份到 `E:\逆向\` 下，文件名带版本号。

## 每次开新终端先加载环境

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
. 'E:\逆向\_tools\env.ps1'
cd E:\pindou_timer
```

`env.ps1` 里有两个给 Gradle 用的开关：

- `WLGD_MAVEN_MIRROR=1` → 走阿里云镜像（CI 上不设，走官方源）
- `WLGD_NDK=30.0.15729638` → 用本机已装的 NDK（CI 上不设，用 Flutter 默认值）

## 常用命令

```powershell
flutter analyze              # 静态检查
flutter test                 # 交互冒烟测试
flutter run                  # 真机/模拟器热重载调试
flutter build apk --release  # 出安装包 -> build\app\outputs\flutter-apk\
flutter build apk --release --split-per-abi   # 分架构，包更小
dart run flutter_launcher_icons               # 改了 assets/icon 之后重出图标
```

## 云端打包（GitHub Actions）

推代码到 GitHub 后，`.github/workflows/build.yml` 会自动：

- **android**：跑 analyze + test，出 release APK，传成 artifact
- **ios**：在 macOS runner 上出**未签名 ipa**（拿去重签就能装）
- 打 `v*` tag 时，两个产物会一起挂到 Release 上，直接给个下载链接

## 本机踩过的坑（都已在配置里修好）

1. **工程路径必须纯英文**：AGP 会直接报 `project path contains non-ASCII characters` 并中止。
2. **Flutter SDK 路径也必须纯英文**：Java 用 ISO-8859-1 读 `local.properties`，
   中文路径会变成乱码（`E:\éå\...`）导致 Gradle 找不到 SDK。
3. **依赖源走阿里云镜像**：`dl.google.com` / `maven.google.com` 在本机网络下会超时。
   已经做成环境变量开关（见上），改的是工程内两个 gradle 文件；
   另外 `flutter/packages/flutter_tools/gradle/settings.gradle.kts` 也打了一份镜像补丁，
   那是 **SDK 里的文件**，重装 Flutter 之后要重新打。
4. **NDK 版本**：Flutter 默认要 `28.2.13676358`，本机装的是 `30.0.15729638`。
   不指定的话 AGP 会去下载整个 NDK 并卡死在 SDK 仓库上，现在由 `WLGD_NDK` 控制。
5. **中文路径下 `flutter analyze` 会崩**（LSP 通道按字符算长度），
   所以工程放在英文路径；工作区里的 `E:\pindou_timer` junction 已移除。
