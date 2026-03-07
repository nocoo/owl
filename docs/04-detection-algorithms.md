# 04 - 检测算法设计

本文档定义三种通用检测算法的内部实现。所有 14 个检测模式都基于这三种算法之一（或组合），不引入任何额外的算法模型。

## 设计约束

| 约束 | 目标 |
|------|------|
| 时间复杂度 | 每条日志处理 O(1) |
| 内存上界 | 全部检测器总计 < 5 MB |
| 无外部依赖 | 纯 Swift 标准库实现 |
| 无持久化 | 所有状态仅在内存中，app 重启后清零 |
| 线程安全 | 所有检测器在同一个后台 Actor 中运行，无需额外锁 |

## 统一协议

```swift
protocol PatternDetector {
    var id: String { get }
    var isEnabled: Bool { get set }
    
    /// 快速判断是否对这条日志感兴趣（O(1) 字符串前缀/包含检查）
    func accepts(_ entry: LogEntry) -> Bool
    
    /// 处理日志条目，O(1) 时间内返回可能的告警
    func process(_ entry: LogEntry) -> Alert?
    
    /// 周期性维护（清理过期状态），每 60 秒由 Pipeline 调用
    func tick()
}
```

`LogEntry` 结构体（从 ndjson 解析）：
```swift
struct LogEntry {
    let timestamp: Date          // 日志时间戳
    let process: String          // 进程名
    let processID: Int           // PID
    let subsystem: String        // 子系统
    let category: String         // 日志分类
    let messageType: String      // Default/Info/Error/Fault
    let eventMessage: String     // 日志正文（检测的核心字段）
}
```

`Alert` 结构体：
```swift
struct Alert {
    let detectorID: String       // 产生此告警的检测器 ID
    let severity: Severity       // info / warning / critical
    let title: String            // 用户可见标题
    let description: String      // 用户可见描述
    let suggestion: String       // 建议操作
    let timestamp: Date          // 告警产生时间
    let ttl: TimeInterval        // 告警存活时间（超时自动消失）
}
```

---

## 算法一：Threshold（阈值检测）

### 适用模式

P01 散热节流、P03 APFS 磁盘刷写延迟、P04 WiFi 信号劣化

### 原理

从日志中提取一个数值，与预设阈值比较。超过阈值持续一定时间（debounce）后触发告警，低于恢复阈值后清除告警。

### 状态机

```
                    value < warning
            ┌─────────────────────────┐
            ▼                         │
        ┌────────┐   value >= warning  ┌──────────┐
        │ Normal │ ──────────────────▶ │ Pending  │
        │        │   (start timer)     │ (debounce)│
        └────────┘                     └──────────┘
            ▲                              │
            │  value < recovery            │ timer expires
            │                              ▼
        ┌────────┐   value >= critical ┌──────────┐
        │        │ ◀────────────────── │ Warning  │
        │Recover │                     │          │
        │        │ ──────────────────▶ └──────────┘
        └────────┘   value < recovery      │
                                           │ value >= critical
                                           ▼
                                      ┌──────────┐
                                      │ Critical │
                                      └──────────┘
```

### 数据结构

```swift
class ThresholdDetector: PatternDetector {
    // 配置（不可变）
    let regex: Regex<...>             // 从 eventMessage 提取数值
    let warningThreshold: Double      // warning 阈值
    let criticalThreshold: Double     // critical 阈值
    let recoveryThreshold: Double     // 恢复阈值
    let debounce: TimeInterval        // 去抖动时间
    let comparison: Comparison        // .lessThan 或 .greaterThan
    
    // 运行时状态
    var state: State = .normal        // 当前状态
    var pendingSince: Date? = nil     // 进入 pending 的时间
    var lastValue: Double = 0         // 最后一次提取的数值
}
```

**内存占用**: 每个 ThresholdDetector 实例 ≈ 200 bytes。3 个实例 = **600 bytes**。

### 处理流程（O(1)）

```
process(entry):
  1. regex.firstMatch(entry.eventMessage)  → 提取 value
  2. switch state:
     - .normal:
         if value 触发 warning → state = .pending, pendingSince = now
     - .pending:
         if value 恢复 → state = .normal, pendingSince = nil
         if now - pendingSince >= debounce → state = .warning, emit Alert
         if value 触发 critical → state = .critical, emit Alert
     - .warning:
         if value 恢复 → state = .normal, emit recovery
         if value 触发 critical → state = .critical, emit Alert
     - .critical:
         if value 恢复 → state = .normal, emit recovery
         if value 回到 warning 区间 → state = .warning
  3. lastValue = value
```

### 特殊处理

- **方向性**: 散热和 WiFi 是"低于阈值为异常"（`comparison = .lessThan`），磁盘刷写是"高于阈值为异常"（`comparison = .greaterThan`）。通过 `Comparison` 枚举统一处理。
- **WiFi 双指标**: P04 同时检测 RSSI 和 txFail 两个值。实现为两个独立的 ThresholdDetector，由 Dispatcher 分别调用，AlertStateManager 聚合结果。

---

## 算法二：Rate（滑动窗口速率计数）

### 适用模式

P02 crash-loop、P05 沙箱违规、P07 崩溃信号、P08 蓝牙断连、P09 TCC 权限、P10 Jetsam（升级部分）、P11 应用卡死、P12 网络失败、P13 USB 异常、P14 DarkWake

### 原理

在固定大小的滑动窗口内，计算某类事件的发生次数。超过阈值则触发告警。支持按 key 分组（如按进程名、设备 ID）。

### 数据结构：Ring Buffer 时间桶

传统滑动窗口用链表存储每个事件的时间戳，内存不可控。我们使用**时间桶（Time Bucket）**方案：

```
窗口 = 60 秒，分为 60 个桶，每桶 1 秒

时间线:  [0s][1s][2s][3s]...[58s][59s]
桶:      [ 3][ 0][ 1][ 5]...[  2][  0]   ← 每桶记录该秒内的事件数
          ▲                          ▲
          oldest                     newest

总计 = sum(所有桶) = 窗口内事件总数
```

使用 Ring Buffer 实现，新桶覆盖最旧的桶：

```swift
struct SlidingWindowCounter {
    let windowSeconds: Int            // 窗口大小（秒）
    let bucketDuration: Int           // 每桶时长（秒），通常 = 1
    
    var buckets: [Int]                // Ring Buffer，大小 = windowSeconds / bucketDuration
    var headIndex: Int = 0            // 当前写入位置
    var headTimestamp: Int = 0        // 当前桶对应的时间戳（秒）
    var total: Int = 0                // 窗口内事件总数（维护增量，避免每次 sum）
}
```

**关键优化 — 增量 total**:
- 每次 `increment()` 时：`total += 1`
- 每次推进桶时：`total -= expiredBucket.count`，然后清零该桶
- 查询时直接返回 `total`，**O(1)** 无需遍历

### 内存占用

单个 SlidingWindowCounter:
- 60 秒窗口 / 1 秒桶 = 60 个 Int = **480 bytes**
- 3600 秒窗口 / 10 秒桶 = 360 个 Int = **2,880 bytes**

分组计数（按进程名/设备 ID）使用 `Dictionary<String, SlidingWindowCounter>`：
- 假设同时追踪 20 个不同的 key
- 60s 窗口: 20 × 480 = **9.6 KB**
- 3600s 窗口: 20 × 2,880 = **57.6 KB**

全部 10 个 Rate 检测器总计: **< 500 KB**

### 处理流程（O(1)）

```
process(entry):
  1. regex.firstMatch(entry.eventMessage)  → 提取 group_key
  2. counter = counters[group_key]  // 或创建新的
  3. counter.advance(to: entry.timestamp)  // 推进到当前时间，清理过期桶
  4. counter.increment()
  5. count = counter.total
  6. if count >= critical_rate AND state != .critical AND !inCooldown:
       state = .critical, emit Alert, startCooldown()
     elif count >= warning_rate AND state != .warning AND !inCooldown:
       state = .warning, emit Alert, startCooldown()
```

`advance()` 的实现：
```
advance(to: currentTimestamp):
  elapsed = currentTimestamp - headTimestamp
  if elapsed <= 0: return  // 同一秒内，无需推进
  if elapsed >= windowSeconds:
      // 整个窗口都过期了，全部清零
      buckets.fill(0); total = 0; headIndex = 0
  else:
      // 逐桶推进，清理过期桶
      for i in 0..<elapsed:
          headIndex = (headIndex + 1) % buckets.count
          total -= buckets[headIndex]
          buckets[headIndex] = 0
  headTimestamp = currentTimestamp
```

### 分组策略

| 模式 | group_by | 说明 |
|------|---------|------|
| P02 | app bundle name | 每个应用独立计数 |
| P05 | 进程名 | 每个进程独立统计 distinct sandbox signatures |
| P07 | 服务名 + 信号名 | 区分不同服务和崩溃原因 |
| P08 | 设备 MAC 地址 | 每个蓝牙设备独立计数 |
| P09 | bundleID | 每个应用独立计数 |
| P11 | PID | 每个卡死进程独立计数 |
| P12 | 无（全局） | 不分组，统计系统级网络状况 |
| P13 | device ID | 每个 USB 设备独立计数 |
| P14 | 无（全局） | 不分组，统计总唤醒频率 |

### 分组上限与淘汰

为防止 Dictionary 无限增长，设置分组上限：

```swift
class RateDetector: PatternDetector {
    let maxGroups: Int = 50           // 最多同时追踪 50 个 key
    var counters: [String: SlidingWindowCounter]
    var lastSeen: [String: Date]      // 每个 key 最后活跃时间
}
```

`tick()` 中执行淘汰:
```
tick():
  for (key, lastDate) in lastSeen:
      if now - lastDate > 2 * window:
          counters.removeValue(forKey: key)
          lastSeen.removeValue(forKey: key)
  if counters.count > maxGroups:
      // 淘汰最久未活跃的 key
      sorted = lastSeen.sorted(by: { $0.value < $1.value })
      removeCount = counters.count - maxGroups
      for (key, _) in sorted.prefix(removeCount):
          counters.removeValue(forKey: key)
          lastSeen.removeValue(forKey: key)
```

### 冷却机制 (Cooldown)

告警触发后进入冷却期，避免同一问题反复告警：

```swift
var cooldownUntil: [String: Date]     // key → 冷却截止时间

func inCooldown(for key: String) -> Bool {
    guard let until = cooldownUntil[key] else { return false }
    return Date() < until
}

func startCooldown(for key: String) {
    cooldownUntil[key] = Date() + cooldownInterval
}
```

---

## 算法三：State（状态追踪 — 配对事件）

### 适用模式

P06 Sleep 断言泄漏

### 原理

追踪配对事件（Created / Released）。当 Created 后长时间未出现对应的 Released，判定为状态泄漏。

### 数据结构

```swift
struct TrackedAssertion {
    let id: String                    // 断言 ID（配对键）
    let source: String                // 来源标识（如 "com.apple.audio..."）
    let type: String                  // 断言类型
    let createdAt: Date               // Created 时间
    var alerted: Severity? = nil      // 已经触发过的最高告警级别
}

class StateDetector: PatternDetector {
    let maxTracked: Int = 100         // 最多追踪 100 个未配对断言
    let warningAge: TimeInterval      // 超过此时间触发 warning
    let criticalAge: TimeInterval     // 超过此时间触发 critical
    
    var pending: [String: TrackedAssertion]  // id → 未配对的 Created 事件
}
```

**内存占用**: 每个 TrackedAssertion ≈ 200 bytes。100 个 = **20 KB**。

### 处理流程（O(1)）

```
process(entry):
  1. regex.firstMatch(entry.eventMessage)  → 提取 action, assertionID, source, type
  2. if action == "Created":
       if pending.count >= maxTracked:
           evictOldest()  // 淘汰最旧的条目
       pending[assertionID] = TrackedAssertion(...)
       return nil  // Created 本身不产生告警
  3. if action == "Released":
       pending.removeValue(forKey: assertionID)
       return nil  // 正常配对，不告警
```

告警逻辑在 `tick()` 中执行（每 60 秒）：

```
tick():
  now = Date()
  for (id, assertion) in pending:
      age = now - assertion.createdAt
      if age >= criticalAge AND assertion.alerted != .critical:
          assertion.alerted = .critical
          emit Alert(critical, ...)
      elif age >= warningAge AND assertion.alerted == nil:
          assertion.alerted = .warning
          emit Alert(warning, ...)
  
  // 清理超时条目（超过 critical 时间的 3 倍，视为已消失）
  for (id, assertion) in pending:
      if now - assertion.createdAt > criticalAge * 3:
          pending.removeValue(forKey: id)
```

### 设计决策

- **告警在 tick() 中产生，而非 process() 中**: 因为泄漏的判断条件是"时间流逝"而非"新事件到来"。如果在 process() 中判断，只有收到新日志时才会触发检查，而泄漏可能在静默期发生。
- **alerted 字段防重复**: 记录已触发的最高级别，避免每次 tick 都重复发出同一告警。
- **淘汰策略**: 超过 maxTracked 时淘汰最旧的条目（FIFO），而非拒绝新条目。因为旧条目如果长期未 Released，很可能已经永远不会 Released 了。

---

## 内存总预算

| 组件 | 内存占用 |
|------|---------|
| 3 × ThresholdDetector | 600 bytes |
| 10 × RateDetector（含分组计数器） | ≈ 500 KB |
| 1 × StateDetector（100 条目上限） | ≈ 20 KB |
| Regex 编译缓存（14 个正则） | ≈ 50 KB |
| Alert State Manager（活跃告警队列） | ≈ 10 KB |
| **总计** | **≈ 580 KB** |

远低于 5 MB 预算上限。即使系统异常导致分组数激增，maxGroups 限制也确保内存不会失控。

---

## 正则性能

每条日志需要对 eventMessage 执行正则匹配。关键优化：

1. **accepts() 先行过滤**: 每个检测器的 `accepts()` 用 O(1) 的字符串包含检查（`contains()` 或前缀匹配）快速排除不相关日志。只有通过 accepts() 的日志才会执行正则。
2. **预编译正则**: 所有正则在 app 启动时编译一次（`try! Regex(...)`），运行时零编译开销。
3. **简单正则**: 所有提取正则都是简单的固定前缀 + 捕获组模式，无回溯风险，无嵌套量词。

预期每条日志的处理时间：
- accepts() 失败（大多数日志）: < 100 ns
- accepts() 成功 + 正则匹配 + 算法处理: < 10 μs

---

## Dispatcher 分发策略

```swift
actor DetectorPipeline {
    let detectors: [PatternDetector]
    
    func dispatch(_ entry: LogEntry) -> [Alert] {
        var alerts: [Alert] = []
        for detector in detectors where detector.isEnabled {
            if detector.accepts(entry) {
                if let alert = detector.process(entry) {
                    alerts.append(alert)
                }
            }
        }
        return alerts
    }
    
    /// 每 60 秒由外部 Timer 调用
    func performTick() -> [Alert] {
        var alerts: [Alert] = []
        for detector in detectors {
            // tick() 可能产生告警（StateDetector 的泄漏检测）
            alerts.append(contentsOf: detector.tick())
        }
        return alerts
    }
}
```

14 个检测器 × accepts() 调用 = 14 次字符串检查。由于 predicate 已在内核侧过滤，到达 app 的日志量有限（预估每秒 < 50 条），总处理开销极低。

---

## Alert State Manager

### 职责

接收检测器产出的 Alert，管理全局告警状态，驱动 UI 更新。

### 告警生命周期

```
Alert 产生
    │
    ▼
┌──────────┐   debounce (5s)   ┌──────────┐
│ Pending  │ ────────────────▶ │  Active  │ ──▶ UI 更新
└──────────┘                   └──────────┘
    │                              │
    │ 在 5s 内恢复                  │ TTL 到期 / 手动消除
    ▼                              ▼
  [丢弃]                       ┌──────────┐
                               │ Expired  │ ──▶ 移入历史
                               └──────────┘
```

### 数据结构

```swift
@MainActor
class AlertStateManager: ObservableObject {
    @Published var activeAlerts: [String: ActiveAlert] = [:]  // detectorID → 活跃告警
    @Published var currentSeverity: Severity = .normal        // 全局最高严重级别
    @Published var alertHistory: [Alert] = []                 // 最近 100 条历史
    
    struct ActiveAlert {
        var alert: Alert
        var pendingSince: Date?       // 去抖动计时
        var isConfirmed: Bool         // 是否已过去抖动期
    }
    
    let historyLimit = 100
    
    func receive(_ alert: Alert) {
        if let existing = activeAlerts[alert.detectorID] {
            // 同一检测器的新告警：更新（可能升级 severity）
            existing.alert = alert
            existing.pendingSince = existing.pendingSince ?? Date()
        } else {
            // 新告警：进入 pending
            activeAlerts[alert.detectorID] = ActiveAlert(
                alert: alert,
                pendingSince: Date(),
                isConfirmed: false
            )
        }
        updateGlobalSeverity()
    }
    
    /// 每秒调用，检查 pending → confirmed 转换和 TTL 过期
    func tick() {
        let now = Date()
        for (id, var active) in activeAlerts {
            // 去抖动：pending 超过 5 秒 → confirmed
            if !active.isConfirmed,
               let since = active.pendingSince,
               now.timeIntervalSince(since) >= 5.0 {
                active.isConfirmed = true
                activeAlerts[id] = active
            }
            // TTL 过期
            if now.timeIntervalSince(active.alert.timestamp) > active.alert.ttl {
                alertHistory.insert(active.alert, at: 0)
                if alertHistory.count > historyLimit {
                    alertHistory.removeLast()
                }
                activeAlerts.removeValue(forKey: id)
            }
        }
        updateGlobalSeverity()
    }
    
    private func updateGlobalSeverity() {
        let confirmed = activeAlerts.values.filter { $0.isConfirmed }
        currentSeverity = confirmed.map(\.alert.severity).max() ?? .normal
    }
}
```

### 聚合规则

| 场景 | 行为 |
|------|------|
| 多个检测器同时告警 | `currentSeverity` = 所有 confirmed 告警中的最高级别 |
| 同一检测器更新告警 | 直接覆盖，severity 可以升级也可以降级 |
| 告警 TTL 到期 | 移入 `alertHistory`，从 `activeAlerts` 移除 |
| 所有告警消失 | `currentSeverity` 回到 `.normal` |

### 默认 TTL

| Severity | 默认 TTL | 说明 |
|---------|---------|------|
| info | 60s | 信息类告警较快消失 |
| warning | 300s (5min) | 足够用户注意到并处理 |
| critical | 600s (10min) | 严重问题保持更久 |

检测器可以在产生 Alert 时覆盖默认 TTL。

---

## tick() 调度时序

```
每 1 秒:
    AlertStateManager.tick()           // 检查 pending→confirmed, TTL 过期

每 60 秒:
    DetectorPipeline.performTick()     // 调用所有检测器的 tick()
    → StateDetector 检查泄漏           // 产生的 Alert 发给 AlertStateManager
    → RateDetector 无操作（可选清理）
    → ThresholdDetector 无操作

每 2 秒:
    SystemMetricsPoller.poll()         // CPU/内存采样（独立于日志检测）
```

---

## 下一步

本文档定义了三种检测算法的完整实现方案。在 `05-ui-design.md` 中，将设计 Menu Bar 图标状态、Popover 弹窗布局、告警列表视图和系统概览面板的详细 UI 规格。
