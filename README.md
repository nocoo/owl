<p align="center">
  <img src="assets/brand/icon-rounded.png" width="128" height="128" alt="Owl logo" />
</p>
<h1 align="center">Owl</h1>
<p align="center">在 macOS 菜单栏查看系统指标、进程和异常告警。</p>
<p align="center">
  <a href="docs/README.en.md">English</a>
</p>

## 这是什么

Owl 是 macOS 14 及以上版本的菜单栏应用。它读取统一日志流并采样系统指标，将反复崩溃、资源压力、设备连接异常等信号整理为告警，方便排查 Mac 变慢、发热或睡眠异常的原因。

采集与分析在本机完成，无需账号或外部服务。检测范围取决于 macOS 提供的日志和硬件指标；温度等读数在部分设备上可能不可用。偏好设置保存在 UserDefaults，近期告警保存在当前进程内存中，重启应用后不会恢复。

## 功能

- **系统概览**：CPU 与各核心使用率、负载、内存和交换空间、磁盘、网络收发、电池及可用温度传感器。
- **异常告警**：按阈值、事件频率、拒绝签名和状态配对分析日志，同时检测持续高 CPU、系统热状态、内存压力、交换空间和磁盘占用。
- **菜单栏反馈**：通过图标颜色和状态文字查看严重程度，打开面板查看活跃告警、近期记录，并复制详情。
- **进程查看**：查看当前资源占用较高的进程，以及累计 CPU 时间、内存和运行实例统计。
- **按需设置**：逐项启停检测器，切换中英文和外观，配置登录启动及系统通知。
- **分级采样**：面板打开时采集完整指标；关闭后降低采样频率，保留异常检测需要的数据。

日志检测覆盖以下信号：

| 类别 | 信号 |
| --- | --- |
| 进程与权限 | 崩溃重启循环、异常退出信号、应用无响应、沙盒和 TCC 权限拒绝 |
| 资源压力 | 热节流、APFS 刷写延迟、Jetsam 内存终止 |
| 网络与设备 | Wi-Fi 信号衰退、连接失败、蓝牙断连、USB 设备错误 |
| 睡眠 | 未释放的睡眠断言、频繁 DarkWake 唤醒 |

## 使用

从 [GitHub Releases](https://github.com/nocoo/owl/releases) 下载发布页提供的 `Owl-*.dmg`，打开后将 `Owl.app` 放入 `/Applications`。发布包对应各自的版本，最新源码见 main 分支。

启动后点击菜单栏图标打开面板，右键点击进入设置或退出。系统通知需要在 macOS 中允许通知，并在 Owl 设置中启用；关闭通知不影响菜单栏告警。

## 开发

需要 macOS 14+、支持 Swift 6 的 Xcode 工具链（Xcode 16+）。项目使用 Swift Package Manager，没有第三方 Swift 包依赖。

```bash
git clone https://github.com/nocoo/owl.git
cd owl
swift build
swift run Owl
```

直接运行 SPM 可执行文件可检查界面和采集逻辑，但它没有完整 app bundle，系统通知会被禁用。

构建 app bundle：

```bash
bash scripts/build.sh --sign "Apple Development: Your Name (TEAMID)"
```

输出为 `build/release/Owl.app`。脚本默认选择 `Apple Development` 签名身份；请指定本机实际可用的身份。DMG 打包与公证入口分别见 [package-dmg.sh](scripts/package-dmg.sh) 和 [notarize.sh](scripts/notarize.sh)。

主要代码位于：

| 路径 | 内容 |
| --- | --- |
| [Sources/Owl](Sources/Owl) | AppKit 菜单栏、应用生命周期与通知 |
| [Sources/OwlCore](Sources/OwlCore) | 指标采集、检测器、告警状态及 SwiftUI 界面 |
| [Sources/HIDThermalBridge](Sources/HIDThermalBridge) | Apple Silicon 温度传感器的 Objective-C 桥接 |
| [Tests/OwlCoreTests](Tests/OwlCoreTests) | 单元测试与检测管道集成测试 |

## 测试

在配置好 Xcode 工具链的 macOS 上运行：

```bash
swift test
swift test --filter EndToEnd
```

第一条运行全部测试；第二条只运行日志条目到检测管道、告警状态的集成测试。集成测试使用构造的日志数据；部分系统指标和传感器测试会读取当前 Mac。菜单栏交互和系统通知需在 app bundle 中手动检查。

## 技术栈

| 技术 | 用途 |
| --- | --- |
| Swift / Swift Concurrency | 应用逻辑、异步日志流与指标采样 |
| SwiftUI / AppKit | 面板、设置窗口与菜单栏 |
| macOS Unified Logging | 通过 `log stream` 读取系统事件 |
| IOKit / Mach / libproc | 硬件、内存、CPU 与进程指标 |
| Objective-C / IOHID | Apple Silicon 温度读取 |
| UserDefaults | 本地偏好设置 |
| Swift Package Manager / Swift Testing | 构建与自动化测试 |

## 文档

- [架构设计](docs/02-architecture.md)
- [日志模式设计](docs/03-patterns.md)
- [检测算法](docs/04-detection-algorithms.md)
- [品牌资源](assets/brand/README.md)

## 许可证

[MIT](LICENSE)
