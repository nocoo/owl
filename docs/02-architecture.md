# 02 - 技术架构设计

## 整体架构

```
┌─────────────────────────────────────────────────────┐
│                    Owl.app (非沙箱)                   │
│                                                     │
│  ┌───────────┐    ┌──────────────┐    ┌───────────┐ │
│  │ Log Stream │───▶│   Pattern    │───▶│  Menu Bar │ │
│  │  Reader    │    │  Detector    │    │    UI     │ │
│  │            │    │  Pipeline    │    │           │ │
│  └───────────┘    └──────────────┘    └───────────┘ │
│        │                │                    │       │
│        ▼                ▼                    ▼       │
│  ┌───────────┐    ┌──────────────┐    ┌───────────┐ │
│  │  System    │    │    Alert     │    │  Popover  │ │
│  │  Metrics   │    │    State     │    │  Detail   │ │
│  │  Poller    │    │   Manager    │    │   View    │ │
│  └───────────┘    └──────────────┘    └───────────┘ │
└─────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────┐
│  /usr/bin/log     │  (子进程，内核侧 predicate 过滤)
│  stream --style   │
│  ndjson           │
└──────────────────┘
```

## 模块划分

### 1. Log Stream Reader

**职责**: 管理 `/usr/bin/log stream` 子进程的生命周期，逐行读取 ndjson 输出并解析。

**技术方案**:
- 使用 `Foundation.Process` 启动 `/usr/bin/log stream`
- 参数: `["stream", "--style", "ndjson", "--predicate", "<组合predicate>"]`
- 通过 `Pipe` 捕获 stdout
- 使用 `FileHandle.bytes.lines`（Swift Concurrency async 序列）逐行读取
- 每行用 `JSONSerialization` 或 `JSONDecoder` 解析为结构体

**ndjson 输出格式**（每行一个 JSON 对象）:
```json
{
  "traceID": 123456,
  "eventMessage": "setDetailedThermalPowerBudget: ...",
  "processID": 0,
  "processImagePath": "/kernel",
  "subsystem": "com.apple.kernel",
  "category": "default",
  "timestamp": "2026-03-06 08:30:44.123456+0800",
  "messageType": "Default"
}
```

**生命周期管理**:
- app 启动时创建子进程
- 子进程异常退出时自动重启（指数退避，最大间隔 30s）
- app 退出时 `terminate()` 子进程
- 使用 `Process.terminationHandler` 监听退出

**Predicate 组合策略**:
```
subsystem == 'com.apple.kernel'
  OR subsystem == 'com.apple.launchservices'
  OR process == 'launchd'
  OR process == 'powerd'
  OR process == 'airportd'
  OR process == 'bluetoothd'
  OR process == 'tccd'
  OR process == 'WindowServer'
  OR subsystem == 'com.apple.network'
```

这个 predicate 在内核侧过滤，只有匹配的日志才会通过 pipe 传给 app。

### 2. System Metrics Poller

**职责**: 定期采集 CPU、内存等系统指标（不依赖日志）。

**技术方案**:
- **CPU**: `host_statistics()` + `HOST_CPU_LOAD_INFO`，每 2 秒采样一次，取两次差值算百分比
- **内存**: `host_statistics64()` + `HOST_VM_INFO64`，读取 free/active/inactive/wired/compressed
- **散热**（备选）: IOKit `AppleSMC` 读取 CPU 温度和风扇转速

**采样频率**: 2 秒一次，使用 `DispatchSourceTimer`

这些 Mach API 是公开稳定的，调用开销极低（微秒级）。

### 3. Pattern Detector Pipeline

**职责**: 接收解析后的日志条目，分发给各个检测器模块。

**设计**:
```
LogEntry ──▶ Dispatcher ──┬──▶ ThermalDetector
                          ├──▶ CrashLoopDetector
                          ├──▶ DiskFlushDetector
                          ├──▶ WiFiDetector
                          ├──▶ BluetoothDetector
                          ├──▶ JetsamDetector
                          ├──▶ AppHangDetector
                          ├──▶ ...
                          └──▶ (更多检测器)
```

每个检测器遵循统一协议:
```swift
protocol PatternDetector {
    var id: String { get }
    var isEnabled: Bool { get set }
    
    // 是否对这条日志感兴趣（快速判断，避免不必要的处理）
    func accepts(_ entry: LogEntry) -> Bool
    
    // 处理日志条目，返回可能的告警
    func process(_ entry: LogEntry) -> Alert?
    
    // 周期性清理过期状态（每 60 秒调用一次）
    func tick()
}
```

Dispatcher 的分发逻辑:
1. 遍历所有已启用的检测器
2. 调用 `accepts()` 快速判断（通常是字符串前缀匹配或 process 名比较）
3. 匹配的检测器才调用 `process()`
4. 返回的 Alert 发送给 Alert State Manager

### 4. Alert State Manager

**职责**: 管理所有检测器产出的告警状态，决定 Menu Bar 图标的显示。

**状态模型**:
```
enum Severity {
    case normal    // 绿色/无色 — 一切正常
    case info      // 蓝色 — 有信息值得关注
    case warning   // 黄色 — 检测到异常，但不严重
    case critical  // 红色 — 严重问题，需要立即关注
}
```

**聚合规则**:
- 多个检测器同时产出告警时，取最高 severity
- 告警有 TTL（存活时间），超时自动降级/消失
- 同一检测器的告警可以升级（如散热从 warning 升为 critical）

**去抖动**:
- 告警产生后有 5 秒确认窗口，持续超过 5 秒才真正展示
- 避免瞬时波动导致图标频繁闪烁

### 5. Menu Bar UI

**职责**: 展示健康状态图标和详情弹窗。

**技术方案**:
- `NSStatusItem` + `NSStatusBar.system` 创建 Menu Bar 图标
- 图标使用 SF Symbols（支持动态着色）
- 点击图标弹出 `NSPopover`，内容用 SwiftUI `NSHostingView` 渲染
- 弹窗展示当前活跃告警列表 + 系统指标摘要

**图标状态**:
| 状态 | 图标 | 含义 |
|------|------|------|
| Normal | `owl` (灰色) | 一切正常 |
| Info | `owl` (蓝色) | 有信息 |
| Warning | `owl.fill` (黄色) | 检测到异常 |
| Critical | `owl.fill` (红色) + 脉冲动画 | 严重问题 |

### 6. Popover Detail View

**职责**: 展示详细的告警信息和系统概览。

**SwiftUI 视图结构**:
```
PopoverView
├── SystemOverview (CPU / 内存 / 散热 一行摘要)
├── ActiveAlerts (当前活跃告警列表)
│   ├── AlertRow (图标 + 标题 + 描述 + 建议操作)
│   └── ...
├── RecentHistory (最近 1 小时的告警时间线)
└── Footer (设置 / 退出)
```

## 线程模型

```
Main Thread (UI)
    │
    ├── NSStatusItem 更新
    └── SwiftUI Popover 渲染

Background Thread (log stream reader)
    │
    ├── Process stdout 读取
    ├── JSON 解析
    └── Detector Pipeline 执行
         │
         └──▶ Alert State Manager (thread-safe, @MainActor 更新 UI)

Timer Thread (metrics poller)
    │
    └── host_statistics() 调用，每 2 秒
```

日志读取和检测在后台线程执行，通过 `@MainActor` 将 UI 更新切回主线程。使用 Swift Concurrency（async/await + Actor）保证线程安全。

## 关键技术决策

| 决策 | 选择 | 替代方案 | 理由 |
|------|------|---------|------|
| 日志读取 | `Process()` + `/usr/bin/log stream` | OSLogStore 轮询 / 私有 SPI | 唯一可靠的公开实时方案 |
| 输出格式 | `--style ndjson` | `--style compact` / default | 机器可解析，每行独立 JSON |
| UI 框架 | NSStatusItem + SwiftUI Popover | 纯 SwiftUI MenuBarExtra | NSStatusItem 控制力更强，MenuBarExtra 不支持自定义图标动画 |
| 并发模型 | Swift Concurrency (Actor) | GCD / pthread | 现代，安全，可读性好 |
| 沙箱 | 禁用 | 启用 | 读系统日志和 spawn 子进程都需要非沙箱 |
| 分发 | Developer ID + Notarization | Mac App Store | 非沙箱不允许上 App Store |

## 依赖

**零外部依赖** — 全部使用 Apple 原生框架:
- `Foundation` — Process, JSONSerialization, Timer
- `AppKit` — NSStatusItem, NSPopover, NSStatusBar
- `SwiftUI` — Popover 内容视图
- `OSLog`（可选）— app 自身的日志输出
- `Darwin` / `mach` — host_statistics CPU/内存指标
