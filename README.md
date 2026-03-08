<p align="center"><img src="owl.png" width="128" height="128" /></p>

<h1 align="center">Owl</h1>

<p align="center"><strong>macOS 菜单栏系统健康监控器</strong><br>实时日志分析 · 异常模式检测 · 零依赖原生应用</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS_14+-000000?logo=apple&logoColor=white" />
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" />
  <img src="https://img.shields.io/badge/tests-485-brightgreen" />
  <img src="https://img.shields.io/github/license/nocoo/owl" />
</p>

<p align="center">
  <img src="https://s.zhe.to/dcd0e6e42358/20260307/bd240b86-6874-4f0c-a147-9000629cc37c.jpg" width="720" />
</p>

---

## 这是什么

Owl 监听 macOS 统一日志流（Unified Log），通过 14 个模式检测器实时识别系统异常，并在菜单栏以颜色变化呈现告警。

macOS 已经在日志中记录了所有重要的系统事件——热节流、进程崩溃、内存压力杀死、蓝牙断连——只是没人看。Owl 替你看。

```
┌─────────────┐     ┌───────────────┐     ┌──────────────┐     ┌────────────┐
│  log stream  │────▶│  14 Patterns  │────▶│  4 Detector  │────▶│  Menu Bar  │
│  (ndjson)    │     │  (filter)     │     │  Engines     │     │  (alerts)  │
└─────────────┘     └───────────────┘     └──────────────┘     └────────────┘
```

**性能**：内存 ~12 MB，零外部依赖，100% 原生 Swift。

## 功能

- **热节流检测** — 内核功率预算低于阈值时发出警告
- **进程崩溃循环** — 追踪 launchd 服务反复崩溃重启
- **磁盘刷写延迟** — APFS tx_flush 超过阈值时告警
- **WiFi 信号衰退** — RSSI 值持续低于安全范围
- **沙盒违规风暴** — 统计进程被 Sandbox/SystemPolicy 拒绝的签名多样性
- **睡眠断言泄漏** — 追踪 powerd Created/Released 配对，检测未释放断言
- **进程崩溃信号** — 检测 QUIT/SIGABRT/SIGSEGV 等异常退出
- **蓝牙断连** — 按 MAC 地址分组追踪设备断连频率
- **TCC 权限风暴** — 检测应用被系统反复拒绝权限请求
- **Jetsam 内存杀** — 单次杀死即时告警，频繁杀死升级为严重
- **应用挂起** — 追踪 WindowServer 报告的 App Not Responding
- **网络连接失败** — 全局统计 ping 失败和网络异常
- **USB 设备错误** — 按设备 ID 分组追踪 abortGated 错误
- **DarkWake 异常唤醒** — 检测系统频繁异常唤醒

## 安装

从 [Releases](https://github.com/nocoo/owl/releases) 下载最新 `Owl.dmg`，打开后将 `Owl.app` 拖入 `/Applications`。

Owl 以菜单栏应用运行（无 Dock 图标）。点击猫头鹰图标查看系统状态、活跃告警和历史记录。右键点击可进入设置或退出。

## 可检测模式

| # | 模式 | 算法 | 说明 |
|---|------|------|------|
| 1 | Thermal Throttling | Threshold | 内核功率预算阈值检测 |
| 2 | Crash Loop | Rate | launchd 服务崩溃频率 |
| 3 | Disk Flush Delay | Threshold | APFS tx_flush 延迟 |
| 4 | WiFi Degradation | Threshold | RSSI 信号强度 |
| 5 | Sandbox Violation | Signature | 沙盒拒绝签名多样性 |
| 6 | Sleep Assertion Leak | State | 睡眠断言配对追踪 |
| 7 | Crash Signals | Rate | 进程异常退出信号 |
| 8 | Bluetooth Disconnect | Rate | 蓝牙设备断连频率 |
| 9 | TCC Permission Storm | Rate | 权限请求拒绝频率 |
| 10 | Jetsam Memory Kill | Threshold + Rate | 内存压力杀死（混合检测） |
| 11 | App Hang | Rate | 应用无响应事件 |
| 12 | Network Failure | Rate | 网络连接失败 |
| 13 | USB Device Error | Rate | USB 设备错误 |
| 14 | DarkWake | Rate | 系统异常唤醒 |

## 项目结构

```
owl/
├── Sources/
│   ├── Owl/                    # 应用入口 (AppDelegate, Menu Bar)
│   └── OwlCore/                # 核心库 (全部可测试逻辑)
│       ├── Detectors/          # Threshold / Rate / Signature / State 四种引擎
│       ├── Models/             # LogEntry, Alert, Severity
│       ├── Patterns/           # 14 个模式配置 + PatternCatalog
│       ├── Pipeline/           # DetectorPipeline, AlertStateManager
│       ├── Services/           # LogStreamReader, SystemMetricsPoller
│       ├── Settings/           # AppSettings, DetectorCatalog
│       └── UI/                 # SwiftUI views, AppState, StatusItemMapper
├── Tests/OwlCoreTests/         # 485 tests / 42 suites
├── scripts/                    # build, notarize, DMG 打包
└── docs/                       # 设计文档
```

## 技术栈

| 层 | 技术 |
|----|------|
| 语言 | [Swift 6](https://www.swift.org/) + swift-tools-version 5.9 |
| UI 框架 | [SwiftUI](https://developer.apple.com/xcode/swiftui/) (MenuBarExtra) |
| 日志采集 | `/usr/bin/log stream --style ndjson`（内核侧谓词过滤） |
| 并发模型 | [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html) (Actor, AsyncSequence) |
| 系统接口 | [IOKit](https://developer.apple.com/documentation/iokit) (CPU/内存/磁盘指标) |
| 构建 | [Swift Package Manager](https://www.swift.org/documentation/package-manager/) |
| 测试 | [Swift Testing](https://developer.apple.com/xcode/swift-testing/) |

## 开发

**环境要求**：macOS 14 Sonoma 或更高版本，Xcode 16+

**快速开始**：

```bash
git clone https://github.com/nocoo/owl.git
cd owl
swift build -c release --product Owl
nohup .build/release/Owl > /dev/null 2>&1 &
```

**常用命令**：

| 命令 | 说明 |
|------|------|
| `swift build` | Debug 构建 |
| `swift build -c release --product Owl` | Release 构建 |
| `swift test` | 运行全部 485 个测试 |
| `swift test --filter Integration` | 仅运行集成测试 |
| `./scripts/build.sh` | 构建 .app bundle |
| `./scripts/package-dmg.sh` | 打包 DMG |
| `./scripts/release-gh.sh` | 打包并发布到 GitHub Releases |
| `./scripts/notarize.sh` | 公证 .app |
| `./scripts/notarize.sh --dmg` | 公证 .dmg |

## 测试

| 层 | 内容 | 触发时机 |
|----|------|----------|
| L1 | 485 个单元 + 集成测试 (Swift Testing) | `swift test` / pre-commit |
| L2 | SwiftLint strict mode（零违规） | pre-commit |
| L3 | 11 个端到端集成测试（日志流 → Pipeline → 告警） | `swift test --filter Integration` |

## 文档

| 文档 | 内容 |
|------|------|
| [01-overview.md](docs/01-overview.md) | 项目概述 |
| [02-architecture.md](docs/02-architecture.md) | 技术架构 |
| [03-patterns.md](docs/03-patterns.md) | 可检测模式目录 |
| [04-detection-algorithms.md](docs/04-detection-algorithms.md) | 检测算法设计 |
| [05-ui-design.md](docs/05-ui-design.md) | 菜单栏 UI 设计 |
| [06-distribution.md](docs/06-distribution.md) | 构建与分发 |
| [07-development-plan.md](docs/07-development-plan.md) | 开发计划 |

## License

[MIT](LICENSE) © 2026
