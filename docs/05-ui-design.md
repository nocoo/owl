# 05 - Menu Bar UI 设计

## 设计原则

| 原则 | 说明 |
|------|------|
| **信息密度** | 一眼看到系统状态，不需要点击 |
| **最小干扰** | 正常状态下几乎不可见，异常时才突出 |
| **macOS 原生** | 遵循 macOS Human Interface Guidelines，使用 SF Symbols |
| **无模态** | 所有信息通过 Popover 展示，不弹对话框 |

---

## Menu Bar 图标

### 图标选择

使用 SF Symbols `owl` 系列（macOS 14+ 可用）。如不可用，fallback 到 `eye.circle`。

| 状态 | SF Symbol | 渲染模式 | 颜色 | 说明 |
|------|----------|---------|------|------|
| Normal | `owl` | monochrome | 系统默认（自动适配深浅模式） | 一切正常 |
| Info | `owl` | monochrome | `.blue` | 有信息值得关注 |
| Warning | `owl.fill` | hierarchical | `.yellow` | 检测到异常 |
| Critical | `owl.fill` | hierarchical | `.red` + 脉冲动画 | 严重问题 |

### 动画

- **Normal → Warning/Critical**: 图标平滑过渡（0.3s ease-in-out）
- **Critical 脉冲**: 使用 `NSStatusBarButton` 的 `alphaValue` 在 0.4~1.0 之间循环（1.5s 周期），吸引注意力但不刺眼
- **恢复动画**: Warning/Critical → Normal 时，图标短暂闪绿（0.5s）然后恢复默认色，给用户"问题已解决"的正反馈

### 实现方式

```swift
// NSStatusItem 创建
let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

// 图标更新（在 @MainActor 上）
func updateIcon(severity: Severity) {
    let symbolName: String
    let color: NSColor
    
    switch severity {
    case .normal:
        symbolName = "owl"
        color = .secondaryLabelColor
    case .info:
        symbolName = "owl"
        color = .systemBlue
    case .warning:
        symbolName = "owl.fill"
        color = .systemYellow
    case .critical:
        symbolName = "owl.fill"
        color = .systemRed
    }
    
    let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
    let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Owl")?
        .withSymbolConfiguration(config)
    
    statusItem.button?.image = image
    statusItem.button?.contentTintColor = color
}
```

---

## Popover

### 触发方式

- **左键单击** Menu Bar 图标 → 打开/关闭 Popover
- **右键单击** → 快捷菜单（退出 / 设置）

### 尺寸

| 属性 | 值 |
|------|-----|
| 宽度 | 320 pt（固定） |
| 最小高度 | 200 pt |
| 最大高度 | 480 pt（超出后内部滚动） |
| 圆角 | 系统默认（NSPopover 自带） |
| 背景 | `.ultraThinMaterial`（毛玻璃） |

### 布局结构

```
┌──────────────────────────────────┐
│  System Overview Bar             │  ← 固定在顶部，始终可见
│  CPU: 23%  MEM: 45%  TEMP: 72°C │
├──────────────────────────────────┤
│                                  │
│  Active Alerts                   │  ← 活跃告警列表（0~n 条）
│  ┌─ 🔴 CPU 散热节流中            │
│  │  功率预算 3200 mW             │
│  │  检查高 CPU 进程...           │
│  └────────────────────────────── │
│  ┌─ 🟡 进程反复崩溃: node        │
│  │  过去 60 秒崩溃 12 次         │
│  │  尝试强制退出...              │
│  └────────────────────────────── │
│                                  │
├──────────────────────────────────┤
│  Recent History                  │  ← 最近历史（最多 5 条摘要）
│  10:23  WiFi 信号恢复            │
│  10:15  蓝牙 AirPods 断连 ×3    │
│  09:58  APFS 刷写延迟 45ms      │
├──────────────────────────────────┤
│  ⚙ Settings    ⏻ Quit Owl       │  ← 底部操作栏
└──────────────────────────────────┘
```

---

## System Overview Bar

顶部的系统概览条，始终显示，一行展示关键系统指标。

### 布局

```
┌──────────────────────────────────┐
│  CPU  23%  │  MEM  45%  │  72°C  │
│  ████░░░░  │  ████░░░░  │  ███░  │
└──────────────────────────────────┘
```

三栏等宽，每栏包含：
- 标签 + 数值（上行）
- 迷你进度条（下行），颜色随数值变化

### 颜色阈值

| 指标 | 绿色 | 黄色 | 红色 |
|------|------|------|------|
| CPU | < 50% | 50-80% | > 80% |
| Memory | < 70% | 70-90% | > 90% |
| Temperature | < 70°C | 70-90°C | > 90°C |

### 数据来源

- **CPU**: `host_statistics()` 差值计算（System Metrics Poller，每 2 秒）
- **Memory**: `host_statistics64()` 的 `(active + wired + compressed) / total`
- **Temperature**: IOKit `AppleSMC` 读取 CPU proximity 温度（如不可用则隐藏此栏）

---

## Active Alerts 列表

### Alert Row 布局

```
┌──────────────────────────────────┐
│ 🔴  CPU 散热节流中         2 分钟前 │  ← severity 图标 + 标题 + 时间
│     当前功率预算 3200 mW          │  ← 描述
│     检查是否有高 CPU 进程...       │  ← 建议操作（灰色小字）
└──────────────────────────────────┘
```

### Severity 图标

| Severity | 图标 | 颜色 |
|---------|------|------|
| info | `info.circle.fill` | `.blue` |
| warning | `exclamationmark.triangle.fill` | `.yellow` |
| critical | `xmark.octagon.fill` | `.red` |

### 状态

- **空状态**: 无活跃告警时显示：

```
┌──────────────────────────────────┐
│                                  │
│      ✓ 系统运行正常              │
│      未检测到异常                 │
│                                  │
└──────────────────────────────────┘
```

- 告警按 severity 降序排列（critical 在最上面）
- 同 severity 的按时间降序（最新在上）

---

## Recent History

### 布局

最近已消除的告警，最多显示最新 5 条：

```
┌──────────────────────────────────┐
│  最近事件                         │
│  10:23  ✓  WiFi 信号恢复          │  ← 绿色对勾 = 已恢复
│  10:15  ⚠  蓝牙 AirPods 断连 ×3  │  ← 黄色警告 = 过期消失
│  09:58  ⚠  APFS 刷写延迟 45ms    │
│  09:30  ✓  散热节流已恢复          │
│  08:45  ℹ  USB 传输中断 ×5        │
└──────────────────────────────────┘
```

### 时间格式

- 当天: `HH:mm`（如 `10:23`）
- 昨天: `昨天 HH:mm`
- 更早: 不显示（历史只保留 app 运行期间的记录）

---

## 底部操作栏

```
┌──────────────────────────────────┐
│  ⚙ 设置          ⏻ 退出 Owl      │
└──────────────────────────────────┘
```

- **设置**: 打开设置窗口（v1 仅含启用/禁用各检测器的开关）
- **退出**: 退出 app，清理子进程

---

## 设置窗口

首发版本的设置窗口保持极简：

```
┌───────────────────────────────────────┐
│  Owl 设置                              │
├───────────────────────────────────────┤
│                                       │
│  检测器                                │
│  ┌─────────────────────────────┐      │
│  │ [✓] 散热节流检测             │      │
│  │ [✓] 进程 Crash-Loop 检测    │      │
│  │ [✓] APFS 磁盘刷写延迟       │      │
│  │ [✓] WiFi 信号劣化           │      │
│  │ [✓] 沙箱违规风暴            │      │
│  │ [✓] Sleep 断言泄漏          │      │
│  │ [✓] 进程崩溃信号            │      │
│  │ [✓] 蓝牙设备断连            │      │
│  │ [✓] TCC 权限风暴            │      │
│  │ [✓] Jetsam 内存压力         │      │
│  │ [✓] 应用卡死检测            │      │
│  │ [✓] 网络连接失败            │      │
│  │ [✓] USB 设备异常            │      │
│  │ [✓] DarkWake 异常唤醒       │      │
│  └─────────────────────────────┘      │
│                                       │
│  通用                                  │
│  [✓] 登录时自动启动                    │
│                                       │
│  关于                                  │
│  Owl v1.0.0                           │
│                                       │
└───────────────────────────────────────┘
```

### 存储

设置项使用 `UserDefaults` 存储：
- `owl.detector.<id>.enabled` → Bool（每个检测器的启用状态）
- `owl.launchAtLogin` → Bool（登录自启）

登录自启使用 `SMAppService.mainApp` (macOS 13+) 注册 Launch Agent。

---

## 配色方案

Owl 不自定义配色，完全跟随系统外观（Light / Dark Mode）。所有颜色使用语义色：

| 用途 | 颜色 |
|------|------|
| 主文字 | `.labelColor` |
| 次要文字 | `.secondaryLabelColor` |
| 背景 | `.windowBackgroundColor` / `.ultraThinMaterial` |
| 分隔线 | `.separatorColor` |
| 严重级别色 | `.systemRed/Yellow/Blue/Green` |

---

## 交互流程

### 典型场景：散热节流

```
1. 系统开始散热节流
2. kernel 日志: "setDetailedThermalPowerBudget: current power budget: 4500"
3. ThresholdDetector 进入 pending 状态
4. 5 秒后（debounce），确认为 warning
5. AlertStateManager 更新 currentSeverity → .warning
6. Menu Bar 图标: owl → owl.fill (黄色)
7. 用户注意到图标变化，点击打开 Popover
8. 看到 "CPU 散热节流中" 告警和建议操作
9. 用户关闭高 CPU 进程
10. 功率预算恢复到 8000 mW
11. ThresholdDetector 回到 normal
12. Menu Bar 图标: owl.fill (黄色) → owl (闪绿 0.5s) → owl (默认色)
13. 告警移入 Recent History: "✓ 散热节流已恢复"
```

### 典型场景：无异常

```
1. 用户点击 Menu Bar 图标
2. Popover 打开
3. System Overview: CPU 12%, MEM 35%, 52°C（全绿）
4. Active Alerts: "✓ 系统运行正常"
5. Recent History: 空或显示几条早期已恢复的事件
6. 用户满意，关闭 Popover
```

---

## SwiftUI 视图层次

```swift
// 入口
PopoverContentView
├── SystemOverviewBar          // 固定顶部
│   ├── MetricGauge("CPU", value, max: 100)
│   ├── MetricGauge("MEM", value, max: 100)
│   └── MetricGauge("TEMP", value, max: 110)
├── Divider()
├── ScrollView {
│   ├── ActiveAlertsSection    // 活跃告警列表
│   │   ├── AlertRow(alert)
│   │   └── ...
│   ├── Divider()
│   └── RecentHistorySection   // 最近历史
│       ├── HistoryRow(item)
│       └── ...
│   }
├── Divider()
└── BottomBar                  // 设置 + 退出
    ├── Button("设置")
    └── Button("退出")
```

### 数据流

```
AlertStateManager (@MainActor, ObservableObject)
    │
    ├── @Published activeAlerts      ──▶  ActiveAlertsSection
    ├── @Published currentSeverity   ──▶  Menu Bar Icon (NSStatusItem)
    └── @Published alertHistory      ──▶  RecentHistorySection

SystemMetricsPoller (@MainActor, ObservableObject)
    │
    ├── @Published cpuUsage          ──▶  SystemOverviewBar
    ├── @Published memoryUsage       ──▶  SystemOverviewBar
    └── @Published temperature       ──▶  SystemOverviewBar
```

两个 `@ObservableObject` 通过 `@EnvironmentObject` 注入 SwiftUI 视图树。`currentSeverity` 变化时同步更新 `NSStatusItem` 图标（通过 `sink` 或 `onChange`）。

---

## 下一步

本文档定义了完整的 UI 规格。在 `06-distribution.md` 中，将设计 Xcode 项目配置、代码签名、Notarization 流程和版本发布方案。
