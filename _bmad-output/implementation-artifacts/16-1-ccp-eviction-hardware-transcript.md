# Story 16.1 — CCP eviction hardware-verification transcript

**Verdict:** **PASS — CCP prompt clean after warm-boot via both `BYE` and `^C` exit paths; CP/M 2.2 BIOS reloads CCP from disk as assumed; F3 closes; +2 KB Page-3 headroom ($D400–$DBFF) safe to consume in Epic 17+.**

## Run metadata

- **Date / time of hardware run:** 2026-05-13 11:06:40 (transcript filename timestamp).
- **Hardware:** MicroBeast (project-lead's primary unit; same physical unit used for Story 15.5 / Story 11.5.1.2 transcripts).
- **MicroBeast firmware revision:** post-2026-04-28 firmware fix per memory `project_hardware_crash_audit.md` (PROBE.COM all-P; antforth runs flawlessly; no BDOS register-preservation crash class). This is the load-bearing anchor for "hardware is clean for the AC1 run" per AC1's pre-conditions; no further firmware revision identifier captured by the project lead at run-time (gap acknowledged — same pattern as Story 15.5 / Story 11.5.1.2 transcripts; consider capturing an explicit firmware-version banner in future hardware-typed stories).
- **CP/M 2.2 source:** stock CP/M 2.2 BIOS on MicroBeast B: ramdisk (the boot path used for every Phase-3 hardware run; cf. Story 15.5 transcripts `beastty-20260509-{123943,125414,134543}.bin`).
- **antforth binary:** `build/antforth.com` patched with the Story 16.1 Task 2.1 transient CCP-zero patch (`LD HL,$D400 / LD DE,$D401 / LD BC,$07FF / LD (HL),0 / LDIR` inserted in `src/antforth.asm` cold_start, immediately after FORTH-WORDLIST init and before "; 10. Enter execution"). Patched size: **25,008 bytes** (= baseline 24,995 + 13 B patch).
- **Transcript binary:** `~/Downloads/beastty-20260513-110640.bin` (1,453 bytes; CR/LF-terminated console capture).

## Transcript-verbatim excerpts

### Pre-state baseline (CCP healthy pre-run)

```
B>
B>B:SLIDE r
…(SLIDE LED test ran; LED activity escape sequences elided)…
B>dir
B: SLIDE    COM : RESET    COM : BBCBASIC COM : MBASIC   COM
B: LEDS     BAS : FONTS    BAS : STRINGS  BAS : SCROLTXT BAS
B: EFFECTS  BAS : LEDS     COM : FONTS    COM : STRINGS  COM
B: SCROLTXT COM : EFFECTS  COM : BATNBALL FTH : ANTFORTH COM
B: BDOS_PRO COM : PROBE    COM : AFFS     COM : OLDSLIDE COM
B: TESTFILE COM : TESTFIL~ COM : VIBE     COM
```

CCP responsive; `B>` prompt healthy; `dir` lists B: ramdisk contents cleanly (incl. patched `ANTFORTH COM`).

### Run 1 — antforth then `BYE` (clean-exit warm-boot)

```
B>antforth
AntForth v2.0.0 (C) ant.org 2026
MicroBeast - 30550 bytes free
Type BYE to exit
1 2 + .
3  ok
bye

B>dir
B: SLIDE    COM : RESET    COM : BBCBASIC COM : MBASIC   COM
…(full DIR listing, same as pre-state)…
B: TESTFILE COM : TESTFIL~ COM : VIBE     COM
```

Banner prints; REPL sanity probe `1 2 + .` returns `3  ok`; `bye` exits antforth and BIOS warm-boots; **`B>` CCP prompt returns clean; subsequent `dir` works**. CCP code at $D400–$DBFF was zeroed at antforth startup, so the post-exit `B>` prompt + working `dir` together prove BIOS reloaded the CCP from disk on warm-boot.

### Run 2 — antforth then `^C` (warm-boot via CTRL-C)

```
B>antforth
AntForth v2.0.0 (C) ant.org 2026
MicroBeast - 30550 bytes free
Type BYE to exit
1 2 + .
3  ok
^C
B>
B>dir
B: SLIDE    COM : RESET    COM : BBCBASIC COM : MBASIC   COM
…(full DIR listing, same as pre-state)…
B: TESTFILE COM : TESTFIL~ COM : VIBE     COM
```

Second invocation; same banner + sanity probe; `^C` from antforth REPL triggers warm-boot; **`B>` CCP prompt returns clean; subsequent `dir` works**. Independent confirmation via the `^C` path (which on CP/M 2.2 also routes through BIOS warm-boot).

## Observations + verdict logic

- **Both exit paths verified.** F3 was framed against the `^C`-from-CCP warm-boot specifically (CP/M 2.2 convention); the transcript exercises both `BYE` (kernel-controlled exit) and `^C` (REPL-controlled warm-boot). Both produce a healthy CCP prompt post-return — independent corroboration that CP/M 2.2 BIOS warm-boot semantics handle CCP reload from disk regardless of which side originates the warm-boot.
- **No stranded state.** After both exits the `B>` prompt accepts a `dir` and renders the full B: ramdisk contents (23 entries visible in the transcript excerpt — `SLIDE COM` through `VIBE COM`). No corruption, no hang, no garbled output.
- **antforth banner shows `30550 bytes free`** — vs. iz-cpm's reported `37712 bytes free` for the same binary. The delta is BDOS-address-dependent (real MicroBeast BDOS lives at a different address than iz-cpm's BDOS-substitute), so the absolute number isn't load-bearing; what matters is the kernel computed it cleanly with $D400–$DBFF zeroed.
- **REPL sanity probe `1 2 + .` returns `3  ok` on both runs** — the kernel runs end-to-end with the CCP region zeroed; no surprise side-effect of the zero-fill on antforth's own behaviour. The CCP region is entirely outside antforth's working set (kernel body ends ~$6303, stacks live near BDOS at ~$DC00; $D400–$DBFF is genuinely unused by antforth at runtime).

## F3 disposition

**F3 closes with verdict PASS.** Architecture `:862..868` (Finding F3 "CCP-reload assumption — BIOS warm-boot reloads CCP from disk on real CP/M 2.2 / MicroBeast") is updated to append:

> **Closed by Story 16.1, 2026-05-13, verdict PASS — CCP reloaded from disk by BIOS on warm-boot per CP/M 2.2 spec; both `BYE` and `^C` exit paths verified clean on real MicroBeast hardware (transcript `~/Downloads/beastty-20260513-110640.bin`); +2 KB Page-3 headroom ($D400–$DBFF) safe to consume in Epic 17+ for the descriptor-stub allocator + `bank-table[]`.**

No follow-up Story 16.1.1 spawned — AC2 FAIL path does not fire.

## Forward consumption

Story 17.1 may now safely move `kernel_end:` (currently `src/antforth.asm:290`) up by 2 KB into the $D400–$DBFF region for the Phase-4 descriptor-stub allocator + `bank-table[]` shell, per AC5's future-edit reference. Story 17.1 / 18.1 / §9.5 own the layout decision within the reclaimed 2 KB.
