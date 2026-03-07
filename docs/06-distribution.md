# 06 - 构建与分发方案

## 为什么不能上 Mac App Store

Owl 需要以下能力，均不允许在 App Store 沙箱中使用：

| 能力 | 原因 |
|------|------|
| 读取系统级统一日志 | `OSLogStore.local()` 和 `log stream` 需要非沙箱 |
| 启动子进程 `/usr/bin/log` | `Foundation.Process` 在沙箱中受限 |
| 读取 Mach host 统计 | `host_statistics()` 在沙箱中可用，但完整功能需要非沙箱 |

因此采用 **Developer ID + Notarization** 方案，在 Apple 官方渠道之外分发，但仍通过 Apple 公证确保用户信任。

---

## Xcode 项目配置

### 基本信息

| 配置项 | 值 |
|--------|-----|
| Product Name | Owl |
| Bundle Identifier | `com.nocoo.owl` |
| Deployment Target | macOS 14.0 (Sonoma) |
| Swift Language Version | 5.9+ |
| Signing | Apple Development (`93WWLTN9XU`) |
| Sandbox | **Disabled** (Hardened Runtime only) |
| App Category | `public.app-category.utilities` |

### Info.plist 关键配置

```xml
<!-- 后台应用，不显示 Dock 图标 -->
<key>LSUIElement</key>
<true/>

<!-- 最低系统版本 -->
<key>LSMinimumSystemVersion</key>
<string>14.0</string>

<!-- 版本号 -->
<key>CFBundleShortVersionString</key>
<string>1.2.0</string>
<key>CFBundleVersion</key>
<string>2</string>
```

### Hardened Runtime

非沙箱应用仍需启用 Hardened Runtime（Notarization 要求）。需要的 entitlement：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <!-- Hardened Runtime 默认值即可，无需额外 entitlement -->
    <!-- 不需要 com.apple.security.app-sandbox -->
    <!-- 不需要 com.apple.security.automation.apple-events -->
</dict>
</plist>
```

Owl 不需要任何特殊 entitlement：
- 不访问通讯录/相机/麦克风
- 不加载第三方动态库
- 不需要 JIT 或内存执行权限
- `Foundation.Process` 在 Hardened Runtime 下可用

---

## 代码签名

### 证书要求

| 证书类型 | 用途 |
|---------|------|
| Apple Development | 本地/开发分发，保持稳定签名与 TCC 权限 |
| Developer ID Application | 正式对外分发（未来接入 notarization 时使用） |

### 签名命令（手动构建时）

```bash
# Xcode 构建时自动签名（推荐）
xcodebuild -scheme Owl -configuration Release \
    CODE_SIGN_IDENTITY="Apple Development" \
    DEVELOPMENT_TEAM="93WWLTN9XU" \
    archive -archivePath build/Owl.xcarchive

# 导出 .app
xcodebuild -exportArchive \
    -archivePath build/Owl.xcarchive \
    -exportPath build/release \
    -exportOptionsPlist ExportOptions.plist
```

`ExportOptions.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

---

## Notarization（公证）

### 流程

```
构建 .app
    │
    ▼
代码签名 (Developer ID)
    │
    ▼
打包 .zip 或 .dmg
    │
    ▼
提交 Apple Notarization
    │  (xcrun notarytool submit)
    ▼
等待审核（通常 < 5 分钟）
    │
    ▼
Staple 公证票据
    │  (xcrun stapler staple)
    ▼
分发给用户
```

### 命令

```bash
# 压缩 .app 为 .zip
ditto -c -k --keepParent build/release/Owl.app build/release/Owl.zip

# 提交公证
xcrun notarytool submit build/release/Owl.zip \
    --apple-id "your@email.com" \
    --team-id "TEAM_ID" \
    --password "@keychain:AC_PASSWORD" \
    --wait

# 贴上公证票据
xcrun stapler staple build/release/Owl.app

# 验证
spctl --assess --type execute --verbose build/release/Owl.app
```

### App-Specific Password

Notarization 需要 App-Specific Password（非 Apple ID 密码）：
1. 在 appleid.apple.com 生成
2. 存入 Keychain: `xcrun notarytool store-credentials`
3. CI 中通过环境变量传入

---

## 分发方式

### v1.0 — GitHub Releases

最简单的分发方式，适合开发者用户群：

1. 在 GitHub repo 创建 Release tag（例如 `v1.2.0`）
2. 上传已公证的 `Owl-v1.2.0.dmg`
3. 用户下载后解压，拖入 /Applications

### 安装方式

推荐 `.dmg` 磁盘映像，包含 app 和 Applications 文件夹的快捷方式：

```
┌───────────────────────────────┐
│                               │
│   [Owl.app]  ──▶  [Applications]  │
│                               │
│   拖拽安装                     │
│                               │
└───────────────────────────────┘
```

创建 DMG:
```bash
# 创建临时目录
mkdir -p build/dmg
cp -R build/release/Owl.app build/dmg/
ln -s /Applications build/dmg/Applications

# 创建 DMG
hdiutil create -volname "Owl" \
    -srcfolder build/dmg \
    -ov -format UDZO \
    build/release/Owl.dmg

# 公证 DMG
xcrun notarytool submit build/release/Owl.dmg ...
xcrun stapler staple build/release/Owl.dmg
```

### 未来考虑 — Homebrew Cask

当用户量增长后，可以提交 Homebrew Cask：

```ruby
cask "owl" do
  version "1.2.0"
  sha256 "..."
  url "https://github.com/nocoo/owl/releases/download/v#{version}/Owl.dmg"
  name "Owl"
  desc "macOS system health monitor in the Menu Bar"
  homepage "https://github.com/nocoo/owl"
  app "Owl.app"
end
```

用户安装: `brew install --cask owl`

---

## 自动更新

### v1.0 — 不实现

首发版本不含自动更新功能。用户手动从 GitHub Releases 下载新版本覆盖安装。

### 未来 — Sparkle

如果需要自动更新，使用 [Sparkle](https://sparkle-project.org/)（macOS 标准自动更新框架）：
- 开源、成熟、被大量非 App Store 应用使用
- 支持 EdDSA 签名验证
- 支持 delta updates
- appcast.xml 托管在 GitHub Pages 或 CDN

这是唯一引入外部依赖的场景，因此推迟到 v2.0。

---

## CI/CD

### v1.0 — 本地构建

首发版本手动在本地构建和公证。

当前可直接使用：

```bash
./scripts/release-gh.sh
```

该脚本会读取 `OwlInfo.version`，构建 `Owl.app`，打出 `Owl-vX.Y.Z.dmg`，并通过 `gh release create` 或 `gh release upload` 上传到 GitHub。

### 未来 — GitHub Actions

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      
      - name: Build
        run: |
          xcodebuild -scheme Owl -configuration Release \
            CODE_SIGN_IDENTITY="Developer ID Application" \
            archive -archivePath build/Owl.xcarchive
      
      - name: Export
        run: |
          xcodebuild -exportArchive \
            -archivePath build/Owl.xcarchive \
            -exportPath build/release \
            -exportOptionsPlist ExportOptions.plist
      
      - name: Notarize
        run: |
          ditto -c -k --keepParent build/release/Owl.app Owl.zip
          xcrun notarytool submit Owl.zip \
            --apple-id "${{ secrets.APPLE_ID }}" \
            --team-id "${{ secrets.TEAM_ID }}" \
            --password "${{ secrets.APP_PASSWORD }}" \
            --wait
          xcrun stapler staple build/release/Owl.app
      
      - name: Create DMG
        run: |
          mkdir -p dmg
          cp -R build/release/Owl.app dmg/
          ln -s /Applications dmg/Applications
          hdiutil create -volname "Owl" -srcfolder dmg -ov -format UDZO Owl.dmg
          xcrun notarytool submit Owl.dmg ... --wait
          xcrun stapler staple Owl.dmg
      
      - name: Release
        uses: softprops/action-gh-release@v2
        with:
          files: Owl.dmg
```

需要的 GitHub Secrets:
- `APPLE_ID` — Apple ID 邮箱
- `TEAM_ID` — Developer Team ID
- `APP_PASSWORD` — App-Specific Password
- `CERT_P12` + `CERT_PASSWORD` — 导出的 Developer ID 证书

---

## 版本策略

### 语义版本号

`MAJOR.MINOR.PATCH`

| 版本 | 变更类型 |
|------|---------|
| 1.0.0 | 首发，14 个检测器 + Menu Bar UI |
| 1.2.0 | SignatureDetector、P05 signature migration、GitHub DMG release script |
| 1.1.0 | 新增检测器或 UI 改进 |
| 1.0.1 | Bug 修复 |
| 2.0.0 | 重大架构变更（如加入自动更新、插件系统等） |

### 最低系统版本

macOS 14 (Sonoma) — 理由：
- SF Symbols 5（包含 `owl` 图标）
- Swift 5.9 标准库特性
- `SMAppService`（登录自启）稳定性改进
- 减少向后兼容负担

---

## 项目目录结构（预览）

```
owl/
├── Owl.xcodeproj/
├── Owl/
│   ├── App/
│   │   ├── OwlApp.swift              // @main 入口
│   │   ├── AppDelegate.swift         // NSStatusItem 创建
│   │   └── StatusItemController.swift // Menu Bar 图标管理
│   ├── Core/
│   │   ├── LogStreamReader.swift     // Process + ndjson 解析
│   │   ├── LogEntry.swift            // 日志条目结构体
│   │   ├── SystemMetricsPoller.swift // CPU/内存采集
│   │   └── DetectorPipeline.swift    // 检测器分发器
│   ├── Detectors/
│   │   ├── PatternDetector.swift     // 协议定义
│   │   ├── ThresholdDetector.swift   // 阈值检测通用实现
│   │   ├── RateDetector.swift        // 速率检测通用实现
│   │   ├── StateDetector.swift       // 状态追踪通用实现
│   │   └── Patterns/
│   │       ├── ThermalPattern.swift
│   │       ├── CrashLoopPattern.swift
│   │       ├── DiskFlushPattern.swift
│   │       └── ... (14 个 pattern 配置)
│   ├── Alerts/
│   │   ├── Alert.swift               // 告警结构体
│   │   ├── Severity.swift            // 严重级别枚举
│   │   └── AlertStateManager.swift   // 告警状态管理
│   ├── UI/
│   │   ├── PopoverContentView.swift
│   │   ├── SystemOverviewBar.swift
│   │   ├── ActiveAlertsSection.swift
│   │   ├── AlertRow.swift
│   │   ├── RecentHistorySection.swift
│   │   └── SettingsView.swift
│   └── Resources/
│       └── Assets.xcassets
├── docs/
│   ├── 01-overview.md
│   ├── 02-architecture.md
│   ├── 03-patterns.md
│   ├── 04-detection-algorithms.md
│   ├── 05-ui-design.md
│   └── 06-distribution.md
├── LICENSE
└── README.md
```

---

## 安全考量

| 风险 | 缓解措施 |
|------|---------|
| Owl 本身被利用 | Hardened Runtime 保护，无网络通信，不接受外部输入 |
| 日志中包含敏感信息 | Owl 仅匹配特定 pattern，不存储原始日志内容 |
| 子进程被劫持 | 使用绝对路径 `/usr/bin/log`，验证路径存在性 |
| 内存中的告警信息 | 仅包含进程名和数值指标，不含用户数据 |

---

## 总结

| 方面 | 决策 |
|------|------|
| 分发渠道 | GitHub Releases（.dmg） |
| 签名 | Developer ID Application + Notarization |
| 沙箱 | 禁用（Hardened Runtime only） |
| 自动更新 | v1 不实现，v2 考虑 Sparkle |
| CI/CD | v1 本地构建，未来 GitHub Actions |
| 最低系统 | macOS 14 Sonoma |
| 外部依赖 | 零（v1） |
