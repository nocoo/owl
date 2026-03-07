# 03 - 可检测模式目录

本文档定义 Owl 首发版本的 14 个检测模式。每个模式包含完整的技术规格，足以直接编码实现。

## 模式规格模板

每个模式按以下结构描述：

| 字段 | 含义 |
|------|------|
| **ID** | 唯一标识符，用于代码和配置 |
| **名称** | 用户可见的中文名 |
| **分类** | 所属类别（硬件 / 进程 / 存储 / 网络 / 安全 / 系统） |
| **日志来源** | process 或 subsystem 名称 |
| **Predicate** | 传给 `log stream --predicate` 的过滤条件片段 |
| **原始日志样本** | 真实系统中抓到的日志 eventMessage |
| **提取正则** | 从 eventMessage 中提取关键数值的正则表达式 |
| **算法类型** | Threshold / Rate / State 三选一 |
| **检测参数** | 阈值、窗口、计数等具体数值 |
| **Severity** | 默认告警级别（info / warning / critical） |
| **告警文案** | 用户在 Popover 中看到的标题和描述 |
| **建议操作** | 给用户的可执行建议 |

---

## 分类总览

| 分类 | 模式数量 | 包含模式 |
|------|---------|---------|
| 硬件 | 3 | 散热节流、蓝牙断连、USB 设备异常 |
| 进程 | 3 | 进程 crash-loop、进程卡死、Jetsam 内存杀 |
| 存储 | 1 | APFS 磁盘刷写延迟 |
| 网络 | 2 | WiFi 信号劣化、网络连接失败 |
| 安全 | 2 | 沙箱违规风暴、TCC 权限风暴 |
| 系统 | 3 | Sleep 断言泄漏、进程崩溃信号、DarkWake 异常唤醒 |

---

## P01 — 散热节流 (Thermal Throttling)

| 字段 | 值 |
|------|-----|
| **ID** | `thermal_throttling` |
| **名称** | 散热节流 |
| **分类** | 硬件 |
| **日志来源** | process: `kernel` |
| **Predicate** | `process == 'kernel' AND eventMessage CONTAINS 'setDetailedThermalPowerBudget'` |

**原始日志样本**:
```
setDetailedThermalPowerBudget: current power budget: 4500 (mW), thermal_budget_normal: 8000
```

**提取正则**:
```
current power budget:\s*(\d+)
```
捕获组 1 = 当前功率预算（mW）。

**算法类型**: Threshold

**检测参数**:
| 参数 | 值 | 说明 |
|------|-----|------|
| warning_threshold | 6000 mW | 低于此值触发 warning |
| critical_threshold | 3000 mW | 低于此值触发 critical |
| recovery_threshold | 7000 mW | 高于此值恢复 normal |
| debounce | 5s | 持续低于阈值 5 秒才触发 |

**Severity**: warning（默认），可升级为 critical

**告警文案**:
- **标题**: `CPU 散热节流中`
- **描述**: `当前功率预算 {value} mW，系统正在降频散热`
- **critical 描述**: `功率预算降至 {value} mW，性能严重受限`

**建议操作**: `检查是否有高 CPU 进程（Activity Monitor），确保通风口畅通`

---

## P02 — 进程 Crash-Loop

| 字段 | 值 |
|------|-----|
| **ID** | `process_crash_loop` |
| **名称** | 进程 Crash-Loop |
| **分类** | 进程 |
| **日志来源** | process: `launchservicesd` |
| **Predicate** | `process == 'launchservicesd'` |

**原始日志样本**:
```
CHECKIN: pid = 85412 matches portless application ...
QUIT: pid = 85412, name = "com.example.app", ...
```

**提取正则**:
```
CHECKIN:.*pid\s*=\s*(\d+).*application\s+(.+?)[\s,]
QUIT:.*pid\s*=\s*(\d+).*name\s*=\s*"([^"]+)"
```
CHECKIN 捕获 PID 和应用标识；QUIT 捕获 PID 和 bundle name。

**算法类型**: Rate（滑动窗口速率计数）

**检测参数**:
| 参数 | 值 | 说明 |
|------|-----|------|
| window | 60s | 滑动窗口大小 |
| warning_rate | 5 次/窗口 | 同一应用标识在窗口内 QUIT 次数 |
| critical_rate | 20 次/窗口 | 高频 crash-loop |
| group_by | app bundle name | 按应用分组计数 |
| cooldown | 120s | 告警后冷却时间，避免重复告警 |

**Severity**: warning（默认），可升级为 critical

**告警文案**:
- **标题**: `进程反复崩溃: {app_name}`
- **描述**: `{app_name} 在过去 60 秒内崩溃了 {count} 次`
- **critical 描述**: `{app_name} 正在高速 crash-loop（{count} 次/分钟），可能拖慢系统`

**建议操作**: `尝试在 Activity Monitor 中强制退出该进程，或检查其配置是否有误`

---

## P03 — APFS 磁盘刷写延迟

| 字段 | 值 |
|------|-----|
| **ID** | `apfs_flush_delay` |
| **名称** | APFS 磁盘刷写延迟 |
| **分类** | 存储 |
| **日志来源** | process: `kernel`，subsystem: `com.apple.apfs` |
| **Predicate** | `process == 'kernel' AND eventMessage CONTAINS 'tx_flush:'` |

**原始日志样本**:
```
tx_flush: 523 tx in 45.123ms
```

**提取正则**:
```
tx_flush:\s*\d+\s+tx\s+in\s+([\d.]+)ms
```
捕获组 1 = 刷写耗时（毫秒）。

**算法类型**: Threshold

**检测参数**:
| 参数 | 值 | 说明 |
|------|-----|------|
| warning_threshold | 10 ms | 超过此值触发 warning |
| critical_threshold | 100 ms | 超过此值触发 critical |
| recovery_threshold | 5 ms | 低于此值恢复 normal |
| debounce | 3s | 持续超过阈值 3 秒才触发 |

**Severity**: info（默认），可升级为 warning / critical

**告警文案**:
- **标题**: `磁盘 I/O 延迟升高`
- **描述**: `APFS 刷写耗时 {value} ms（正常 < 10 ms）`
- **critical 描述**: `APFS 刷写耗时 {value} ms，磁盘可能存在硬件问题`

**建议操作**: `检查磁盘健康状态（Disk Utility → First Aid），确认没有大量写入操作`

---

## P04 — WiFi 信号劣化

| 字段 | 值 |
|------|-----|
| **ID** | `wifi_degradation` |
| **名称** | WiFi 信号劣化 |
| **分类** | 网络 |
| **日志来源** | process: `airportd`，subsystem: `com.apple.wifi` 或 `corewifi` |
| **Predicate** | `process == 'airportd' AND eventMessage CONTAINS 'LQM:'` |

**原始日志样本**:
```
LQM: rssi=-75, snr=22, cca=45, txFail=12, txRetry=8
```

**提取正则**:
```
LQM:.*rssi=([-\d]+).*txFail=(\d+)
```
捕获组 1 = RSSI（dBm，负数），捕获组 2 = 传输失败次数。

**算法类型**: Threshold

**检测参数**:
| 参数 | 值 | 说明 |
|------|-----|------|
| rssi_warning | -70 dBm | 信号弱 |
| rssi_critical | -80 dBm | 信号极弱 |
| rssi_recovery | -65 dBm | 恢复正常 |
| txfail_warning | 10 | 单条日志 txFail 超过此值 |
| debounce | 10s | WiFi 信号波动频繁，用更长去抖 |

**Severity**: info（默认），可升级为 warning / critical

**告警文案**:
- **标题**: `WiFi 信号较弱`
- **描述**: `当前信号强度 {rssi} dBm，传输失败 {txfail} 次`
- **critical 描述**: `WiFi 信号极弱（{rssi} dBm），网络可能不稳定`

**建议操作**: `尝试靠近路由器，或切换到 5GHz 频段`

---

## P05 — 沙箱违规风暴

| 字段 | 值 |
|------|-----|
| **ID** | `sandbox_violation_storm` |
| **名称** | 沙箱违规风暴 |
| **分类** | 安全 |
| **日志来源** | process: `kernel`，category: `Sandbox` |
| **Predicate** | `process == 'kernel' AND eventMessage CONTAINS 'deny(1)'` |

**原始日志样本**:
```
Sandbox: Google Chrome(85321) deny(1) file-read-data /private/var/folders/...
```

**提取正则**:
```
(?:Sandbox|System Policy):\s+(.+?)\(\d+\)\s+deny\(1\)\s+(\S+)\s+(.+)$
```
捕获组 1 = 进程名，2 = 被拒绝的操作类型，3 = 被拒绝目标。

**算法类型**: Signature（滑动窗口去重签名计数）

**签名构造**:
- key = 进程名
- signature = `operation + normalized(target)`
- `target` 会做路径规范化：UUID -> `<UUID>`、数字段 -> `<N>`、`/private/var/folders/...` 随机目录 -> 稳定占位符

**检测参数**:
| 参数 | 值 | 说明 |
|------|-----|------|
| window | 60s | 滑动窗口大小 |
| warning_distinct | 10 个/窗口 | 同一进程在窗口内的不同 deny 签名数 |
| critical_distinct | 50 个/窗口 | 大规模多样化违规 |
| group_by | 进程名 | 按进程分组统计 signature diversity |
| cooldown | 300s | 沙箱违规通常持续存在，冷却时间长 |

**Severity**: info（默认），可升级为 warning / critical

**告警文案**:
- **标题**: `沙箱违规风暴`
- **描述**: `{process_name} 在过去 60 秒出现 {count} 个不同的沙箱拒绝签名`
- **critical 描述**: `{process_name} 出现大规模多样化沙箱违规，可能存在路径爆炸或权限异常`

**建议操作**: `通常为应用兼容性问题，如频繁发生可尝试重装该应用或检查权限设置`

---

## P06 — Sleep 断言泄漏

| 字段 | 值 |
|------|-----|
| **ID** | `sleep_assertion_leak` |
| **名称** | Sleep 断言泄漏 |
| **分类** | 系统 |
| **日志来源** | process: `powerd` |
| **Predicate** | `process == 'powerd' AND (eventMessage CONTAINS 'Created' OR eventMessage CONTAINS 'Released')` |

**原始日志样本**:
```
Created InternalPreventSleep "com.apple.audio.AppleHDAEngineOutput" 00000001 age:0 id:0x0000000100000482
Released InternalPreventSleep "com.apple.audio.AppleHDAEngineOutput" 00000001 id:0x0000000100000482
```

**提取正则**:
```
(Created|Released)\s+(\S+)\s+"([^"]+)".*?id:(0x[0-9a-fA-F]+)
```
捕获组 1 = 动作（Created/Released），2 = 断言类型，3 = 来源标识，4 = 断言 ID（用于配对）。

**算法类型**: State（状态追踪 — 配对事件）

**检测参数**:
| 参数 | 值 | 说明 |
|------|-----|------|
| pair_key | assertion ID (id:0x...) | 用断言 ID 配对 Created 和 Released |
| warning_age | 1800s (30min) | Created 后 30 分钟未 Released |
| critical_age | 7200s (2hr) | Created 后 2 小时未 Released |
| max_tracked | 100 | 最多同时追踪 100 个未配对断言 |
| cleanup_interval | 300s | 每 5 分钟清理已过期条目 |

**Severity**: warning（默认），可升级为 critical

**告警文案**:
- **标题**: `Sleep 断言未释放`
- **描述**: `"{source}" 阻止系统休眠已超过 {age} 分钟`
- **critical 描述**: `"{source}" 已阻止休眠 {age} 小时，疑似断言泄漏`

**建议操作**: `运行 pmset -g assertions 查看当前 sleep 断言，或重启相关进程`

---

## P07 — 进程崩溃信号

| 字段 | 值 |
|------|-----|
| **ID** | `process_crash_signal` |
| **名称** | 进程崩溃信号 |
| **分类** | 系统 |
| **日志来源** | process: `launchd` |
| **Predicate** | `process == 'launchd' AND eventMessage CONTAINS 'exited due to'` |

**原始日志样本**:
```
Service exited due to SIGKILL | sent by mach_vm_map_kernel[0]: ...
Service exited due to SIGSEGV | sent by exc handler[0]: ...
Service exited due to SIGABRT | sent by abort()[85412]: ...
```

**提取正则**:
```
Service\s+(.+?)\s+exited due to\s+(SIG\w+)
```
捕获组 1 = 服务名，2 = 信号名（SIGKILL/SIGSEGV/SIGABRT 等）。

> **注意**: 如果 eventMessage 格式中服务名不在此位置，可能需要结合 `processImagePath` 或其他字段辅助提取。实际开发时需用真实日志校准正则。

**算法类型**: Rate（滑动窗口速率计数）

**检测参数**:
| 参数 | 值 | 说明 |
|------|-----|------|
| window | 3600s (1hr) | 滑动窗口大小 |
| warning_rate | 3 次/窗口 | 同一服务在 1 小时内崩溃 3 次 |
| critical_rate | 10 次/窗口 | 频繁崩溃 |
| group_by | 服务名 + 信号名 | 按服务和信号类型分组 |
| cooldown | 600s | 冷却时间 10 分钟 |

**Severity**: warning（默认），可升级为 critical

**告警文案**:
- **标题**: `进程频繁崩溃: {service_name}`
- **描述**: `{service_name} 在过去 1 小时因 {signal} 退出了 {count} 次`

**建议操作**: `查看 ~/Library/Logs/DiagnosticReports/ 中对应的 crash 报告`

---

## P08 — 蓝牙设备断连

| 字段 | 值 |
|------|-----|
| **ID** | `bluetooth_disconnect` |
| **名称** | 蓝牙设备断连 |
| **分类** | 硬件 |
| **日志来源** | process: `bluetoothd` |
| **Predicate** | `process == 'bluetoothd' AND eventMessage CONTAINS 'Device disconnected'` |

**原始日志样本**:
```
Device disconnected - "AirPods Pro" (XX:XX:XX:XX:XX:XX), reason: 0x13
```

**提取正则**:
```
Device disconnected.*?"(.+?)"\s+\(([0-9A-Fa-f:]+)\).*?reason:\s*(0x[0-9a-fA-F]+)
```
捕获组 1 = 设备名，2 = MAC 地址，3 = 断连原因码。

**算法类型**: Rate（滑动窗口速率计数）

**检测参数**:
| 参数 | 值 | 说明 |
|------|-----|------|
| window | 3600s (1hr) | 滑动窗口大小 |
| warning_rate | 3 次/窗口 | 同一设备在 1 小时内断连 3 次 |
| critical_rate | 8 次/窗口 | 频繁断连 |
| group_by | 设备 MAC 地址 | 按设备分组计数 |
| cooldown | 300s | 冷却时间 5 分钟 |

**Severity**: info（默认），可升级为 warning / critical

**告警文案**:
- **标题**: `蓝牙设备反复断连: {device_name}`
- **描述**: `{device_name} 在过去 1 小时断连了 {count} 次`

**建议操作**: `尝试重新配对设备，或检查设备电量是否不足`

---

## P09 — TCC 权限风暴

| 字段 | 值 |
|------|-----|
| **ID** | `tcc_permission_storm` |
| **名称** | TCC 权限风暴 |
| **分类** | 安全 |
| **日志来源** | process: `tccd` |
| **Predicate** | `process == 'tccd' AND (eventMessage CONTAINS 'REQUEST:' OR eventMessage CONTAINS 'AUTHREQ_RESULT:')` |

**原始日志样本**:
```
REQUEST: service=kTCCServiceAppleEvents, bundleID=com.example.app, ...
AUTHREQ_RESULT: DENIED, service=kTCCServiceAppleEvents, bundleID=com.example.app
```

**提取正则**:
```
REQUEST:.*service=(\S+?),.* bundleID=(\S+?)[\s,]
AUTHREQ_RESULT:\s*(\w+),.*service=(\S+?),.* bundleID=(\S+?)[\s,]
```
REQUEST: 捕获服务名和 bundleID；AUTHREQ_RESULT: 捕获结果、服务名和 bundleID。

**算法类型**: Rate（滑动窗口速率计数）

**检测参数**:
| 参数 | 值 | 说明 |
|------|-----|------|
| window | 60s | 滑动窗口大小 |
| warning_rate | 10 次/窗口 | 同一应用被 DENIED 的次数 |
| critical_rate | 30 次/窗口 | 大规模权限拒绝 |
| group_by | bundleID | 按应用分组计数 |
| filter | 仅计数 DENIED 结果 | 忽略 ALLOWED |
| cooldown | 300s | 冷却时间 5 分钟 |

**Severity**: info（默认），可升级为 warning

**告警文案**:
- **标题**: `权限请求被大量拒绝: {app_name}`
- **描述**: `{app_name} 在过去 60 秒请求 {service} 权限被拒绝 {count} 次`

**建议操作**: `在系统设置 → 隐私与安全中检查该应用的权限配置`

---

## P10 — Jetsam 内存压力杀进程

| 字段 | 值 |
|------|-----|
| **ID** | `jetsam_kill` |
| **名称** | Jetsam 内存压力杀进程 |
| **分类** | 进程 |
| **日志来源** | process: `kernel`，category: `memorystatus` |
| **Predicate** | `process == 'kernel' AND eventMessage CONTAINS 'memorystatus_kill_top_process'` |

**原始日志样本**:
```
memorystatus_kill_top_process: killing pid 85412 [SomeApp] (memorystatus_available_pages: 1024) ...
```

**提取正则**:
```
memorystatus_kill_top_process:.*pid\s+(\d+)\s+\[(.+?)\].*memorystatus_available_pages:\s*(\d+)
```
捕获组 1 = PID，2 = 进程名，3 = 可用页数。

**算法类型**: Threshold（任何一次出现即触发）

**检测参数**:
| 参数 | 值 | 说明 |
|------|-----|------|
| trigger | 任意匹配 | 每次出现都触发（Jetsam kill 本身就是严重事件） |
| escalate_rate | 3 次/5min | 短时间多次 Jetsam 升级为 critical |
| cooldown | 60s | 同一进程的冷却 |

**Severity**: warning（单次），critical（5 分钟内多次）

**告警文案**:
- **标题**: `系统内存不足 — {process_name} 被强制终止`
- **描述**: `macOS 因内存压力终止了 {process_name}（PID {pid}）`
- **critical 描述**: `5 分钟内 {count} 个进程被 Jetsam 终止，系统内存严重不足`

**建议操作**: `关闭不必要的应用以释放内存，或考虑重启系统`

---

## P11 — 应用卡死 (App Hang)

| 字段 | 值 |
|------|-----|
| **ID** | `app_hang` |
| **名称** | 应用卡死 |
| **分类** | 进程 |
| **日志来源** | process: `WindowServer` |
| **Predicate** | `process == 'WindowServer' AND eventMessage CONTAINS 'failed to act on a ping'` |

**原始日志样本**:
```
[pid=85412] failed to act on a ping. Removing
```

**提取正则**:
```
\[pid=(\d+)\]\s+failed to act on a ping
```
捕获组 1 = 卡死进程的 PID。

**算法类型**: Rate（滑动窗口速率计数）

**检测参数**:
| 参数 | 值 | 说明 |
|------|-----|------|
| window | 60s | 滑动窗口大小 |
| warning_rate | 2 次/窗口 | 同一 PID 在 60 秒内被 ping 失败 2 次 |
| group_by | PID | 按 PID 分组 |
| pid_resolve | 是 | 尝试通过 PID 反查进程名（`ProcessInfo`） |
| cooldown | 120s | 冷却时间 |

> **PID 反查**: 收到告警时用 `kill(pid, 0)` 检查进程是否还存在，再通过 `/proc` 或 `sysctl` 获取进程名。如果进程已被 WindowServer 移除则使用 "PID {pid}" 作为标识。

**Severity**: warning

**告警文案**:
- **标题**: `应用无响应: {process_name}`
- **描述**: `{process_name}（PID {pid}）未响应 WindowServer 的心跳检测`

**建议操作**: `在 Activity Monitor 中查看该进程是否正常，可尝试强制退出`

---

## P12 — 网络连接失败

| 字段 | 值 |
|------|-----|
| **ID** | `network_failure` |
| **名称** | 网络连接失败 |
| **分类** | 网络 |
| **日志来源** | subsystem: `com.apple.network` |
| **Predicate** | `subsystem == 'com.apple.network' AND eventMessage CONTAINS 'reporting state failed error'` |

**原始日志样本**:
```
nw_connection_report_state_with_handler [C123] reporting state failed error Path:Unsatisfied ...
```

**提取正则**:
```
nw_connection.*?\[C\d+\].*?reporting state failed error\s+(.+)
```
捕获组 1 = 错误描述（Path:Unsatisfied 等）。

**算法类型**: Rate（滑动窗口速率计数 — 聚合模式）

**检测参数**:
| 参数 | 值 | 说明 |
|------|-----|------|
| window | 60s | 滑动窗口大小 |
| warning_rate | 10 次/窗口 | **跨进程**总失败次数（系统级网络问题） |
| critical_rate | 30 次/窗口 | 大规模网络失败 |
| group_by | 无（全局聚合） | 不按进程分组，检测系统级网络问题 |
| cooldown | 120s | 冷却时间 |

> **关键设计**: 与其他 Rate 检测器不同，此检测器**不按进程分组**，而是全局聚合。因为网络故障通常是系统级的（DNS 不通、VPN 断开等），多个进程同时报错才有意义。单个进程偶尔的连接失败不值得告警。

**Severity**: warning（默认），可升级为 critical

**告警文案**:
- **标题**: `系统网络连接异常`
- **描述**: `过去 60 秒有 {count} 次网络连接失败`
- **critical 描述**: `大规模网络连接失败（{count} 次/分钟），网络可能已断开`

**建议操作**: `检查 WiFi 连接状态和 VPN 是否正常，尝试打开浏览器测试网络`

---

## P13 — USB 设备异常

| 字段 | 值 |
|------|-----|
| **ID** | `usb_device_error` |
| **名称** | USB 设备异常 |
| **分类** | 硬件 |
| **日志来源** | process: `kernel`，subsystem: `com.apple.iokit` |
| **Predicate** | `process == 'kernel' AND eventMessage CONTAINS 'IOUSBHostPipe::abortGated'` |

**原始日志样本**:
```
AppleUSBHostController@01000000: IOUSBHostPipe::abortGated: device 0x12345678, endpoint 0x81
```

**提取正则**:
```
IOUSBHostPipe::abortGated:.*device\s+(0x[0-9a-fA-F]+)
```
捕获组 1 = 设备标识。

**算法类型**: Rate（滑动窗口速率计数）

**检测参数**:
| 参数 | 值 | 说明 |
|------|-----|------|
| window | 3600s (1hr) | 滑动窗口大小 |
| warning_rate | 5 次/窗口 | 同一设备在 1 小时内中断 5 次 |
| critical_rate | 20 次/窗口 | 设备可能损坏 |
| group_by | device ID | 按设备标识分组 |
| cooldown | 600s | 冷却时间 10 分钟 |

**Severity**: info（默认），可升级为 warning / critical

**告警文案**:
- **标题**: `USB 设备通信异常`
- **描述**: `设备 {device_id} 在过去 1 小时发生 {count} 次传输中断`

**建议操作**: `尝试重新插拔该 USB 设备，或更换 USB 线缆/端口`

---

## P14 — DarkWake 异常唤醒

| 字段 | 值 |
|------|-----|
| **ID** | `darkwake_abnormal` |
| **名称** | DarkWake 异常唤醒 |
| **分类** | 系统 |
| **日志来源** | process: `kernel` + `powerd` |
| **Predicate** | `(process == 'kernel' OR process == 'powerd') AND eventMessage CONTAINS 'DarkWake'` |

**原始日志样本**:
```
DarkWake from Normal Sleep [CDNPB] due to EC.LidOpen/Lid Open: Using AC
DarkWake: sleepASAP - notass
```

**提取正则**:
```
DarkWake\s+from\s+\w+\s+Sleep.*due to\s+(.+?):\s
```
捕获组 1 = 唤醒原因。

**算法类型**: Rate（滑动窗口速率计数）

**检测参数**:
| 参数 | 值 | 说明 |
|------|-----|------|
| window | 3600s (1hr) | 滑动窗口大小 |
| warning_rate | 10 次/窗口 | 1 小时内 DarkWake 超过 10 次 |
| critical_rate | 30 次/窗口 | 异常频繁唤醒 |
| group_by | 无（全局计数） | 不区分原因，关注总频率 |
| cooldown | 600s | 冷却时间 10 分钟 |

**Severity**: info（默认），可升级为 warning / critical

**告警文案**:
- **标题**: `系统被频繁唤醒`
- **描述**: `过去 1 小时发生 {count} 次 DarkWake（最近原因: {reason}）`
- **critical 描述**: `过去 1 小时 {count} 次 DarkWake，电池将快速消耗`

**建议操作**: `运行 pmset -g log | grep DarkWake 查看详细唤醒记录，检查是否有外设持续唤醒系统`

---

## Predicate 汇总

以下是所有模式的 predicate 合并后的完整过滤条件，作为传给 `log stream --predicate` 的参数：

```
process == 'kernel'
  OR process == 'launchservicesd'
  OR process == 'launchd'
  OR process == 'powerd'
  OR process == 'airportd'
  OR process == 'bluetoothd'
  OR process == 'tccd'
  OR process == 'WindowServer'
  OR subsystem == 'com.apple.network'
```

> **设计说明**: 我们在 predicate 层做粗过滤（按 process/subsystem），在 app 层做细过滤（每个检测器的 `accepts()` 方法检查 eventMessage 内容）。这样 predicate 保持简洁，内核侧过滤效率最高。

## 算法类型分布

| 算法类型 | 数量 | 使用模式 |
|---------|------|---------|
| **Threshold** | 3 | P01 散热、P03 磁盘、P04 WiFi |
| **Rate** | 9 | P02 crash-loop、P05 沙箱、P07 崩溃信号、P08 蓝牙、P09 TCC、P10 Jetsam（混合）、P11 卡死、P12 网络、P13 USB、P14 DarkWake |
| **State** | 1 | P06 sleep 断言 |

> Jetsam（P10）是混合模式：单次出现 = Threshold 触发 warning，短时间多次 = Rate 升级为 critical。

## 下一步

本文档为每个模式提供了完整的检测规格。在 `04-detection-algorithms.md` 中，将详细设计三种算法类型的通用实现（数据结构、内存占用、时间复杂度），使所有检测器可以复用统一的算法引擎。
