# Code Review #001 — Multi-Agent Audit

**Date**: 2026-03-08
**Reviewers**: Claude Code (claude-opus-4.6), Codex (gpt-5.4), Gemini (gemini-2.5-pro)
**Scope**: Full codebase — security, correctness, performance, concurrency
**Resolution**: All 11 items fixed — 485/485 tests passing

## Summary

Three AI agents independently reviewed the Owl codebase. Findings were synthesized
and de-duplicated into 11 actionable items across three priority levels.

## Findings

### P0 — Correctness / Data Loss

| ID | Issue | Files | Status |
|----|-------|-------|--------|
| #5 | Pipe fragmented reads silently drop NDJSON records. `availableData` can return a partial line; `enumerateLines` discards the incomplete tail. Fix: carry-over buffer across reads. | `LogStreamReader.swift` | [x] |
| #6 | Subprocess leak on shutdown. `LogStreamReader` is created as a local variable inside `startEngine()` — no retained reference means `stop()` is never called on app termination. Fix: store `reader` on `AppDelegate`, call `reader.stop()` in `stopEngine()`. | `OwlEngine.swift`, `OwlApp.swift` | [x] |

### P1 — Performance / Correctness

| ID | Issue | Files | Status |
|----|-------|-------|--------|
| #10 | `TopProcessProvider.topProcesses()` iterates ALL system PIDs every 2 seconds, calling `proc_pidinfo` + `proc_name` per PID. Fix: only collect names for top-N candidates after sorting by CPU time. | `TopProcessProvider.swift` | [x] |
| #1 | Fast JSON parser (`extractStringValue`) does not handle `\uXXXX` Unicode escapes. If `eventMessage` contains one, the literal `uXXXX` leaks into the parsed value. Fix: decode `\uXXXX` (and surrogate pairs) in `readJSONStringValue`. | `LogEntry.swift` | [x] |
| #9 | 250 ms batch flush is not time-driven — it only triggers when the next entry arrives. During low-traffic periods, entries can sit in the buffer indefinitely. Fix: add an independent timer that flushes regardless of arrival rate. | `OwlEngine.swift` | [x] |

### P2 — Optimization / Hygiene

| ID | Issue | Files | Status |
|----|-------|-------|--------|
| #8 | `SignatureDetector.GroupState.distinctCount` creates a temporary `Set` via `currentSet.union(previousSet)` on every access. Fix: maintain an incremental union count. | `SignatureDetector.swift` | [x] |
| #2 | LRU eviction in both `RateDetector` and `SignatureDetector` sorts the entire `lastSeen`/`groups` dictionary — O(n log n). Fix: linear scan for the min element instead. | `RateDetector.swift`, `SignatureDetector.swift` | [x] |
| #7 | `AlertStateManager` is a plain `class` but is mutated from the `@MainActor` engine loop AND read from SwiftUI views. No compile-time isolation guarantee. Fix: annotate with `@MainActor`. | `AlertStateManager.swift` | [x] |
| #11 | `SMCTemperatureProvider` opens and closes the IOKit SMC connection on every call (every 2 seconds). Fix: cache the connection for the provider's lifetime. | `SMCTemperatureProvider.swift` | [x] |
| #13 | `AppState` is a single `ObservableObject` with 7 `@Published` properties. Any change triggers re-evaluation of every subscribed view. Fix: migrate to `@Observable` macro (Swift 5.9+) for property-level tracking. | `AppState.swift` | [x] |
