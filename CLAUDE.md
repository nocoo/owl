# Owl — Project Notes

## Retrospective

### 2026-03-08: proc_taskinfo CPU time units are Mach absolute ticks, NOT nanoseconds
- `pti_total_user`, `pti_total_system`, `pti_threads_user`, `pti_threads_system` from `proc_pidinfo(PROC_PIDTASKINFO)` are in **Mach absolute time ticks**, not nanoseconds.
- On Apple Silicon (M-series), the Mach timebase is `numer=125, denom=3`, so each tick ≈ 41.67 ns. Treating ticks as nanoseconds causes CPU% to be ~41.67× too low.
- Must convert via `mach_timebase_info`: `nanoseconds = ticks × (numer / denom)`.
- `pti_total_user/system` **already includes** live-thread times. `pti_threads_user/system` is a **subset** of `pti_total_*`, NOT additional time. Summing all four double-counts.
- Three AI agents (Claude, Codex, Gemini) all incorrectly advised summing all four fields. Experimental verification was essential.
- Verified against `ps` (which reports ~99% for a pure CPU spin loop) — our corrected algorithm matches. macOS `top` reports lower (~69%) due to its own sampling methodology.
