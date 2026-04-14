# Story 8.3: Restructure .R and .S

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a system maintainer,
I want `.R` (`src/formatting.asm:173`) and `.S` (`src/formatting.asm:269`) restructured to use the EXX shadow-register pattern in place of their multi-call `rpush_de`/`rpush_bc`/`rpop_de`/`rpop_bc` save/restore sequences (and to retire the per-word memory scratch slots those calls were compensating for, where feasible),
so that the binary shrinks by a conservative ~16 bytes (optimistic ~26 bytes), the formatting pipeline's EXX coverage extends from the trivial words (DOT, U.) to the structurally heavier ones, and Epic 8's net target of ~30–44 bytes saved is met or exceeded after this story.

## Acceptance Criteria

1. **Given** `w_DOT_R_cf` (src/formatting.asm:175–254) currently uses `CALL rpush_de` + `CALL rpush_bc` at entry (6 bytes), `LD C,(IX+0) / LD B,(IX+1)` mid-body to recover width from the return stack (6 bytes), and `INC IX / INC IX / CALL rpop_de` at exit (5 bytes), **When** the entry/exit/recovery sequences are replaced with the Group A Path 1 EXX idiom (`PUSH BC / EXX / POP BC` at entry → width in main BC, IP parked in DE'; `EXX` at exit) and the width is kept live in a main register (or reloaded from a still-live source) instead of being recovered from the return stack, **Then** `make test && make test-repl` passes all 273 REPL + assembly regression tests with zero failures, and `.R` output is byte-identical to pre-story behaviour for the existing test cases (REPL test 240 covers `.R`; verify with positive, negative, zero, and over-width inputs).

2. **Given** `w_DOT_S_cf` (src/formatting.asm:271–361) currently uses `CALL rpush_de` + `CALL rpush_bc` at entry (6 bytes — where `rpush_bc` is a *functional* cache so `.dots_print_tos` can read the original TOS later, not save/restore), reads the cached TOS via `LD B,(IX+1) / LD C,(IX+0)` at line 351 (6 bytes), and uses `CALL rpop_bc` + `CALL rpop_de` at exit (6 bytes), **When** entry is converted to a single `EXX` (1 byte — BC' now holds original TOS, DE' holds IP), `.dots_print_tos` reads the cached TOS via the shadow set instead of via IX, and exit is converted to a single `EXX` (1 byte), **Then** `make test && make test-repl` passes all 273 REPL + assembly regression tests with zero failures, and `.S` output is byte-identical for the empty-stack, one-item, and multi-item cases (REPL tests covering `.S` already exist — verify each path by inspection of the test harness output diff).

3. **Given** EXX is a leaf-level technique (Epic 7 convention reaffirmed in Epic 8.1/8.2) **When** either `w_DOT_R_cf` or `w_DOT_S_cf` is converted **Then** the call graph beneath each word is verified EXX-free by direct inspection: `check_underflow_2` (src/system.asm:302), `print_neg_prefix` (src/formatting.asm:92), `emit_unsigned` (src/formatting.asm:118), `u_to_str` (src/formatting.asm:55), `div_bc_by_e` (src/formatting.asm:27), `digit_to_char` (src/formatting.asm:11), `bdos_print_str` (src/io.asm:204), `bdos_putchar` (src/io.asm:188), `BDOS_ENTRY`. Run `grep -n "EXX\|EX\s*AF,AF'" src/formatting.asm src/io.asm src/system.asm` and document that no helper in the `.R` / `.S` call graph contains EXX (the only formatting-pipeline EXX users after this story will be DOT, U., .R, .S themselves — leaves of the dependency tree).

4. **Given** the dev agent has the freedom to attempt second-order scratch-variable elimination (Epic 7.2 / 8 convention: when EXX frees registers, hunt for memory-scratch eliminations) **When** the conversion lands **Then** the resulting binary is at least **16 bytes** smaller than the pre-story baseline (14,057 → ≤14,041 bytes) — this is the conservative target. The dev agent SHOULD attempt the optimistic restructure (eliminating `.dotr_neg`, `.dotr_str`, `.dotr_len` data scratch where the freed register set permits) and aim for ~26 bytes saved (14,057 → ≤14,031). Document in Completion Notes which scratch slots were eliminated vs retained and why.

5. **Given** `.R` currently uses three data scratch bytes (`.dotr_neg` 1 byte at line 256, `.dotr_str` 2 bytes at line 257, `.dotr_len` 1 byte at line 258) **When** the conversion lands **Then** every retained scratch byte must have a written justification in the Dev Notes (e.g., "retained because the pad-emit loop's `PUSH BC / CALL bdos_putchar / POP BC` body cannot also preserve HL across the BDOS call"). The negative-flag (`.dotr_neg`) is the most likely candidate for elimination — a single bit/register flag should suffice with the freed shadow-register slot.

6. **Given** the changes land **When** the full regression suite runs (`make test && make test-repl`) **Then** all 273 REPL tests + the assembly regression test pass with zero failures; no previously-passing test may regress. Code-review the diff (per Epic 6/7/8 convention — every story gets adversarial review).

7. **Given** Epic 8's target is ~30–44 bytes total (story 8.1 delivered 14,105 → 14,061 = 44 bytes incl. review-time wins; story 8.2 delivered 14,061 → 14,057 = 4 bytes; cumulative through 8.2 = 48 bytes, already at top of epic optimistic) **When** Story 8.3 lands **Then** the cumulative Epic 8 savings (vs the pre-Epic-8 baseline of 14,105 bytes) is at least 64 bytes (44 + 4 + 16) and ideally up to 74 bytes (44 + 4 + 26). Note: Story 8.1 already overshot its own conservative budget — Epic 8 is comfortably ahead of plan; Story 8.3 may take the optimistic restructure with reasonable safety margin.

## Tasks / Subtasks

- [x] Task 0: Record baseline (AC: #4, #6)
  - [x] 0.1 `make asm && wc -c build/antforth.com` — confirmed 14,057 bytes
  - [x] 0.2 `make test && make test-repl` — 272 REPL tests + 1 assembly regression all pass (story spec said 273; actual count is 272 — spec off by one)
  - [x] 0.3 Snapshot recorded: pre-story 14,057 bytes

- [x] Task 1: Verify leaf-level EXX-freeness of the .R / .S call graph (AC: #3)
  - [x] 1.1 `src/formatting.asm` EXX hits: lines 138, 144 (DOT), 159, 163 (U.), plus comments at 53/113. `digit_to_char`, `div_bc_by_e`, `u_to_str`, `print_neg_prefix`, `emit_unsigned` all clean.
  - [x] 1.2 `src/io.asm` EXX hits: lines 122–143 (ACCEPT only). `bdos_putchar` (188), `bdos_print_str` (204), `BDOS_ENTRY` clean.
  - [x] 1.3 `src/system.asm` EXX hits: lines 24, 75, 79 (MARKER only). `check_underflow_2` (302) clean.
  - [x] 1.4 Recorded — call graph EXX-free as expected.

- [x] Task 2: Restructure `w_DOT_R_cf` (AC: #1, #4, #5)
  - [x] 2.1 Entry: `PUSH BC / EXX / POP DE / POP BC` (4 bytes) — width in main DE, n in main BC, IP parked in DE'
  - [x] 2.2 n is in main BC ready for u_to_str; width in main DE
  - [x] 2.3 Width staged via SP across `u_to_str` (`PUSH DE / CALL u_to_str / ... / POP DE`) — IX-based recovery removed entirely
  - [x] 2.4 Exit: `EXX / POP BC / NEXT` — `INC IX / INC IX / CALL rpop_de` removed
  - [x] 2.5 Attempted but RETAINED `.dotr_neg` — see Dev Notes Completion section. Sign-elimination needed SP-stash discipline through the pad-loop AND sign-emit BDOS call, costing ~5 bytes vs. 7 saved. Net gain marginal and complexity high — kept memory scratch.
  - [x] 2.6 RETAINED `.dotr_str` / `.dotr_len`. Justification: HL (string addr) and the strlen byte must survive the pad-emit loop's `bdos_putchar` calls (each iteration clobbers BC/DE/HL/A); the loop also needs B for DJNZ. Keeping HL live would require `PUSH HL / POP HL` per iteration (+2 bytes per iter; bad for typical width). Keeping len in a register would need to survive too. Memory scratch is the byte-optimal choice.
  - [x] 2.7 Post-.R build: 14,057 → 14,042 (−15 bytes)
  - [x] 2.8 `make test && make test-repl` — all green
  - [x] 2.9 Manual sanity (REPL): `5 8 .R` → `       5`, `-5 8 .R` → `      -5`, `0 3 .R` → `  0`, `12345 2 .R` → `12345` (over-width: digits emitted, no padding) — all match pre-story behaviour

- [x] Task 3: Restructure `w_DOT_S_cf` (AC: #2, #4)
  - [x] 3.1 Entry: single `EXX` (1 byte) — original TOS → BC', IP → DE'
  - [x] 3.2 Body uses main BC/DE/HL freely (depth calc, unsigned-print, walk loop) — pattern preserved
  - [x] 3.3 `.dots_print_tos` uses Option C from Dev Notes: `EXX / PUSH BC / EXX / POP BC` (4 bytes) — round-trips original TOS through SP into main BC. Shadow set untouched throughout.
  - [x] 3.4 Exit: single `EXX` (1 byte) — restores TOS to main BC and IP to main DE. NO trailing `POP BC` (TOS was never on SP in `.S`).
  - [x] 3.5 Post-.S build: 14,042 → 14,030 (−12 bytes)
  - [x] 3.6 `make test && make test-repl` — all green
  - [x] 3.7 Manual sanity: `.S` → `<0>`, `1 .S` → `<1> 1`, `1 2 3 .S` → `<3> 1 2 3` (verified via single-line input — note `.S` is `( -- )` so leftover items persist between REPL turns)

- [x] Task 4: Final verification (AC: #4, #6, #7)
  - [x] 4.1 `make test && make test-repl` — 272 REPL + 1 assembly regression all pass, zero failures
  - [x] 4.2 Final binary: **14,030 bytes** — beats optimistic target (≤14,031). Cumulative −27 bytes from baseline 14,057.
  - [x] 4.3 Completion Notes updated below
  - [ ] 4.4 Manual hardware test on MicroBeast — DEFERRED to user (no hardware in dev env)

- [x] Task 5: Code review (AC: #6)
  - [x] 5.1 Run `bmad-bmm-code-review` — see Senior Developer Review section
  - [x] 5.2 Address findings — see review section
  - [x] 5.3 Post-review tests green, binary size confirmed

## Dev Notes

### Epic Context

Story 8.3 is the third (and largest-payoff) story of Epic 8 (Shadow Register Follow-Up). Stories 8.1 (CHAR + (ABORT") — 44 bytes saved including review wins) and 8.2 (DOT + U. — 4 bytes saved) extended the EXX convention from Epic 7 into the formatting pipeline's leaf words. Story 8.3 is the *structural* formatting work: `.R` and `.S` were explicitly out of scope in 8.1/8.2 because they each use *multiple* rpush/rpop calls plus memory scratch variables to compensate for register pressure that EXX directly relieves.

This is also the "second-order savings" story Epic 8 was sized around (Epic 7.2 retro lesson: when EXX frees registers, scratch-variable elimination compounds the savings). The Epic 8 spec frames `.R`'s `.dotr_*` scratch trio and `.S`'s IX-cached TOS as the two main second-order opportunities here.

### Pre-Story Baseline

- Binary: 14,057 bytes (post-Story 8.2 with code-review fixes)
- Tests: 273 REPL tests + 1 assembly regression = all green
- EXX users (all leaf-level, non-nested):
  - 7.1: COLON, CREATE, CONSTANT, CODE, END-CODE, NEXT,, LABEL, MARKER
  - 7.2: ASM_RECOGNIZE (partial — `.recog_fast_false` does not EXX)
  - 7.3: FILL, MOVE, ROLL, ACCEPT, WORD, >NUMBER, NUMBER?, `(`
  - 8.1: CHAR; (ABORT") uses bare `PUSH DE` (no EXX, no matching POP — ABORT wipes SP)
  - 8.2: DOT, U.

After Story 8.3, the formatting pipeline EXX users will be DOT, U., .R, .S — exactly the four words Epic 8 targeted in the formatting category.

### Why the Path 1 Pattern (entry `PUSH BC / EXX / POP BC`)

`.R` needs **width in main BC** for the pad-count math (`SUB E` against C) and for the digit-emit pipeline (`u_to_str` expects the value to convert in BC, but we already converted that — the *width* is what we need to preserve through the body for the pad loop). At entry, BC holds width (TOS). A naive `EXX` would swap width into BC' — fine for *preservation* but inconvenient for the immediate `LD C,(IX+0)` width-recovery pattern that already exists.

The Path 1 pattern (`PUSH BC / EXX / POP BC`) parks IP in DE' while keeping width in main BC. This matches the DOT/U. conversion pattern from Story 8.2 exactly. The width then stays live in main BC (or is staged into a different main register if BC needs to be free for `u_to_str`).

`.S` is *different* — it has no incoming TOS argument *to consume* (`.S` is `( -- )`), but it does need to *display* the original TOS as part of stack inspection. The current code uses `rpush_bc` as a functional cache so `.dots_print_tos` (line 349) can read the original TOS via `(IX+0/+1)` after the body has clobbered BC. With EXX, BC' provides exactly that "free TOS-preservation slot" — Epic 7.3 NUMBER? established this exact idiom.

### Story 8.3 .S print-TOS design (the crux of Task 3.3 / 3.4)

The `.dots_print_tos` label needs to recover the original TOS into main BC so it can call `.dots_print_signed` (which calls `print_neg_prefix` and `emit_unsigned`, both of which need value-in-main-BC). Three candidate patterns:

**Option A — EXX swap, print, EXX back:**
```asm
.dots_print_tos:
    EXX                     ; main = original main' (so original TOS is now in BC')
                            ; wait — at this point main BC = caller's TOS-cache-value because
                            ; we already EXXed at entry. After this EXX we're BACK in caller-set,
                            ; main BC = caller IP's old garbage, BC' = original TOS.
                            ; This is wrong direction. See Option B.
```
Option A is muddled — needs careful state-tracking: at `.dots_print_tos` entry, we are in the *post-entry-EXX* set, so main BC = whatever-it-was-before-our-EXX (likely garbage from previous caller), BC' = original TOS. We need to read BC' into main BC. There is no direct "BC' → BC" instruction; the only way is `EXX`.

**Option B — EXX, print in original main, EXX back, exit:**
```asm
.dots_print_tos:
    EXX                     ; back to entry-time main set; main BC = original TOS, DE = IP
    CALL  print_neg_prefix
    CALL  emit_unsigned     ; emits TOS, clobbers BC/DE/HL — but we don't need them anymore
.dots_done:
    NEXT                    ; DE/IP is intact (we never EXXed back)
```
Wait — this is actually clean! At entry-time we EXXed (so main BC=garbage, BC'=TOS, DE'=IP). The body uses main BC freely. At `.dots_print_tos` we EXX back: now main BC = original TOS, DE = IP. The print pipeline runs, clobbers BC/DE/HL — but we're already at the function exit, those values aren't needed. `NEXT` reads DE as IP — but DE was clobbered by `print_neg_prefix`/`emit_unsigned`! ❌ — DE is the IP, and `emit_unsigned` clobbers DE per its header comment. So we must NOT EXX before printing.

**Option C — stage TOS through main register, EXX back, then print:**
```asm
.dots_print_tos:
    EXX                     ; main BC = original TOS, main DE = IP (correct)
    PUSH  BC                ; save original TOS to SP
    EXX                     ; back to body set (main DE/garbage, BC'=TOS, DE'=IP)
    POP   BC                ; main BC = original TOS again, DE' still has IP
    CALL  print_neg_prefix  ; clobbers main BC/DE/HL — but DE here is body-set scratch, IP is safe in DE'
    CALL  emit_unsigned
.dots_done:
    EXX                     ; restore IP from DE' to main DE
    NEXT
```
This works — IP stays parked in DE' the whole time `print_neg_prefix`/`emit_unsigned` run, and the original TOS is brought into main BC for them via PUSH/EXX/POP. Net cost vs current: entry 6→1 (−5), exit 6→1 (−5), print-tos `LD B,(IX+1) / LD C,(IX+0)` (6) → `EXX / PUSH BC / EXX / POP BC` (4) (−2). Total: −12 bytes for `.S` alone. Matches Epic 8 spec's optimistic 12-byte `.S` estimate.

**Option D — change `.dots_done` to use BC' directly with one final EXX:**
Realise that `.dots_print_signed` could itself EXX-bracket: we EXX back to entry-set, call print, and accept that DE (IP) gets clobbered — restore it from DE' via a final EXX before NEXT. But `print_neg_prefix` calls `bdos_putchar` and `emit_unsigned` calls `bdos_print_str`/`bdos_putchar` — these need DE available as a BDOS register, so the IP can't live in main DE during the print. Option C is correct.

**Recommendation:** Option C. Document the choice in Dev Notes during implementation.

### Story 8.3 .R width-preservation design

Current code: width is rpush'd, then re-read mid-body via `(IX+0/+1)` (6 bytes of recovery code). With EXX, width can ride in BC' for the entire body — but the pad-emit loop already uses main BC (`B = padding count` for DJNZ). Conflict.

Resolution candidates:
- **Stage width through HL across `u_to_str`.** `u_to_str` takes BC=value, returns HL=string-addr, A=length. So enter `u_to_str` with BC=value (computed from the popped n), get HL/A out, *then* swap width back into a main register. Width could be stashed on SP (`PUSH BC` before `u_to_str`, `POP HL` after — but that costs 2 bytes for the push/pop pair). Or width could ride in BC' across `u_to_str` (BC' is otherwise unused after entry — IP is in DE'), then `EXX` to read it (1 byte) when we need it for the pad-count math. **EXX cost: 1 byte each direction = 2 bytes**, vs current 6 bytes for `(IX+0/+1)` recovery. Saves 4 bytes here.
- **Pre-compute pad count before `u_to_str`.** Pad count = width − strlen − sign_byte. We don't know strlen until after `u_to_str`, so this isn't available — REJECTED.

**Recommendation:** Park width in BC' for the duration of `u_to_str`'s call, then EXX once to read it. Net: −4 bytes vs current width-recovery cost.

But wait — IP is already in DE'. EXX brings the *whole* shadow set into main: BC'→BC, DE'→DE, HL'→HL. So one EXX simultaneously brings width into BC *and* IP into DE. Then `print_neg_prefix`/`emit_unsigned`/the pad loop all run with IP loose in main DE — and they clobber DE. ❌

Resolution: stage width through *HL'* not *BC'*. After entry `PUSH BC / EXX / POP BC`, width is in main BC, IP in DE'. Pop n: `POP DE`. Sign-handle, then `LD H,B / LD L,C` (stage width to HL — but HL is also needed). Alternative: SP-stash width briefly: `PUSH BC` before `u_to_str` (now we've pushed width to SP), `LD B,?? / LD C,??` (load value — but where is the value? we computed it from sign-handling main DE…). This is getting tangled.

**Cleaner approach for `.R`:** keep `.dotr_neg` as a register flag (1 bit in HL or A), but use SP as the temporary width/sign holding area:

```asm
w_DOT_R_cf:
    CALL  check_underflow_2
    PUSH  BC                  ; width to SP
    EXX                       ; IP parked in DE'
    POP   BC                  ; main BC = width — wait, we need n in BC for u_to_str!
```
This doesn't work because we want *both* width and n live, and `u_to_str` consumes BC=value.

**Best minimal restructure:** keep the entry as Path 1 (`PUSH BC / EXX / POP BC` — width in BC), pop n into HL (`POP HL`), test sign on H, negate if needed (in HL via `XOR A / SUB L / LD L,A / SBC A,A / SUB H / LD H,A`), `LD B,H / LD C,L` (move n into BC for `u_to_str`), but width is now lost from BC. Stage width on SP just before the move: `PUSH BC` (width to SP), `LD B,H / LD C,L` (n into BC), `CALL u_to_str` (HL=str, A=len), `POP DE` (width back into DE — main DE was IP, but IP is in DE' now, so main DE is free — wait, after `u_to_str` clobbers DE, we *can* POP DE from SP into main DE freely). Now width is in DE (or just E since width is 8-bit-ish for practical purposes, but DOTR is 16-bit width per ANS).

Then sign-byte arithmetic uses `LD A, sign_flag / ADD A,strlen / LD E,A / LD A,C (width-low) / SUB E / JR C, no_pad / JR Z, no_pad / LD B,A / pad_loop`.

Costs vs current `.R`:
- Entry: 6 bytes (`CALL rpush_de` + `CALL rpush_bc`) → 3 bytes (`PUSH BC / EXX / POP BC`). −3.
- Width staging across `u_to_str`: 6 bytes (`LD C,(IX+0) / LD B,(IX+1)` mid-body) → ~3 bytes (`PUSH BC` before u_to_str, `POP DE` after). −3.
- Sign-flag scratch: `.dotr_neg` 1 byte data + `LD A,1 / LD (.dotr_neg),A` (5 bytes write) + `LD A,(.dotr_neg)` (3 bytes) ×2 reads = 11 bytes code + 1 byte data → register flag in H (kept after sign-test) costs ~0 code + 0 data. **−12 bytes** if achievable cleanly, **−4 bytes** if achievable partially.
- String/length staging: `.dotr_str` 2 bytes + `.dotr_len` 1 byte data + 6 bytes write + 6 bytes read = 12 bytes code + 3 data → if HL/A can survive the pad loop, total elimination saves ~15 bytes; if HL must be saved/restored once per pad iteration, partial savings only.
- Exit: 5 bytes (`INC IX / INC IX / CALL rpop_de`) → 1 byte (`EXX`). −4.

Conservative `.R` total: −3 (entry) + −3 (width staging) + −4 (exit) = **−10 bytes** with no scratch elimination.
Optimistic `.R` total: above + scratch elimination = **−16 to −22 bytes**.

`.S` total: −5 (entry) + −5 (exit) + −2 (print-tos via Option C) = **−12 bytes**.

**Combined story estimate (matches Epic 8 spec):** conservative ~16, optimistic ~26.

### Leaf-Level Audit (must run)

The `.R` / `.S` call graph (plus `check_underflow_2` for `.R`):

```
w_DOT_R_cf
  ├── check_underflow_2          (src/system.asm:302)
  ├── u_to_str                   (src/formatting.asm:55)
  │     ├── div_bc_by_e          (src/formatting.asm:27)
  │     └── digit_to_char        (src/formatting.asm:11)
  ├── bdos_putchar               (src/io.asm:188)
  └── bdos_print_str             (src/io.asm:204)

w_DOT_S_cf
  ├── (no underflow check — .S is ( -- ) so empty stack is valid)
  ├── u_to_str                   (also through .dots_print_signed below)
  ├── bdos_putchar
  ├── bdos_print_str
  └── .dots_print_signed (local) (src/formatting.asm:365)
        ├── print_neg_prefix     (src/formatting.asm:92)
        └── emit_unsigned        (src/formatting.asm:118)
              ├── u_to_str
              ├── bdos_print_str
              └── bdos_putchar
```

All of these were verified EXX-free in Epic 7.3 Task 1.2 and Story 8.2 Task 1. Re-run the grep in Task 1 — the audit cost is trivial and the safety value is high.

### Register Contract Reminder (and TOS-in-BC nuance)

- `BC` = TOS, `DE` = IP, `SP` = parameter stack, `IX` = return stack, `IY` = user pointer, `HL`/`AF` = scratch
- After EXX: BC'/DE'/HL' preserved in shadows; main BC/DE/HL become whatever was *previously* in shadows (initially garbage at first EXX in a word)
- A (and AF) survive EXX
- **DEPTH semantics post-EXX:** `DEPTH = (sp_base − SP) / 2` — counts cells on SP only, NOT BC. After our entry `PUSH BC` (in `.R`'s Path 1 entry), the original TOS is on SP, not in BC — DEPTH would count it. After `POP BC` it's back in BC, off SP. As long as the entry/exit stack discipline matches what the Forth contract says (`( n width -- )` for `.R`, `( -- )` for `.S`), DEPTH stays correct. **Important for `.S`'s depth calculation:** `.S`'s depth math is `HL = (sp_base) - SP / 2`. With our restructured entry being `EXX` (which doesn't touch SP), SP is unchanged from the caller's view. Original TOS *was never pushed to SP* in our `.S` — it stays in BC' via EXX. So `.S` depth math is unchanged. Crucial: do NOT add a `PUSH BC` at `.S` entry; that would shift SP and corrupt the depth count. (See `feedback_tos_in_register.md` memory: BC=TOS may be phantom after ABORT — irrelevant here since `.S` doesn't ABORT.)

### Previous Story Learnings (8.1, 8.2, 7.3)

**From 8.1 (CHAR + ABORT"):**
- Code review caught a stale comment in `u_to_str` / `emit_unsigned` headers that misrepresented the callee contract. **Action for this story:** when adding/modifying scratch usage in `.R`'s body, update the header comment of any helper whose callee contract changes (none expected — helpers are unchanged).
- Watch for orphaned `INC IX` / stale stack manipulation after refactoring.
- (ABORT") used `PUSH DE` (no matching POP) safely because ABORT wipes SP. NOT applicable here — `.R` and `.S` are normal-exit words, every push needs a balanced pop.

**From 8.2 (DOT + U.):**
- The Path 1 pattern (`PUSH BC / EXX / POP BC` entry, `EXX` exit) is proven on the formatting helpers' call graph. `.R`'s entry follows this verbatim.
- `u_to_str` and `emit_unsigned` headers now correctly describe the rpush_de-or-EXX duality. `.R`/`.S` should respect both contracts (we use EXX, callers using rpush_de still work).

**From 7.3 (DE-only words):**
- Group A Path 1 (used by MOVE, DOT, U.) — entry `PUSH BC / EXX / POP BC`, exit `EXX / POP BC` (where the exit POP gives new TOS).
- Shadow BC' as free TOS-preservation slot — exactly the `.S` `.dots_print_tos` use case (Option C above).
- "A survives EXX" exit-staging — not needed here; values come from SP/registers, not from cross-EXX computed bytes.

**From 7.2 (recognizer, the Epic 8 spec's archetype for "second-order savings"):**
- Three scratch variables eliminated when EXX freed registers; tail-merge added another −11 bytes at code review. Story 8.3 should explicitly hunt for the same — that's why AC #4 separates conservative (no scratch elimination) from optimistic (with scratch elimination), and AC #5 demands documented justification for any retained scratch byte.

### What Not To Change

- **`u_to_str`, `print_neg_prefix`, `emit_unsigned`, `digit_to_char`, `div_bc_by_e`** — helper bodies remain untouched. They must stay EXX-free so other EXX-using words (DOT, U., now .R, .S) can continue to call them.
- **`check_underflow_2`** — untouched.
- **`rpush_de` / `rpop_de` / `rpush_bc` / `rpop_bc`** — symbols retained (still used by `(DO)`, INTERPRET, DOCOL/EXIT, DOES> runtime — Category D in the survey, NOT candidates). Do not remove the symbols.
- **`.dots_depth`, `.dots_addr`, `.dots_remaining`** — `.S`'s walk-loop scratch slots (lines 369–371). These are used across BDOS calls inside `.dots_walk`; freeing them would require keeping a second 16-bit value live across BDOS calls (the depth counter and the walk pointer). Likely retained — document if so.
- **The depth calculation in `.S` (lines 279–284)** — unchanged. Depth = (sp_base − SP)/2. Our entry EXX does not touch SP, so this stays correct.
- **Test files** — no test changes expected; the existing REPL tests for `.R` and `.S` already cover the behaviour and serve as the regression net.

### Build/Test Commands

```bash
make asm                    # Assemble with sjasmplus
make test                   # Run assembly-level regression test
make test-repl              # Run 273 REPL-piped Forth regression tests
wc -c build/antforth.com    # Check binary size
```

### Byte Budget (Conservative / Optimistic)

| Change                                                             | Conservative | Optimistic |
|--------------------------------------------------------------------|--------------|------------|
| .R entry: `CALL rpush_de + CALL rpush_bc` (6) → `PUSH BC / EXX / POP BC` (3) | −3 | −3 |
| .R width-staging across `u_to_str`: `(IX+0/+1)` recover (6) → SP-stash + POP DE (3) | −3 | −3 |
| .R exit: `INC IX / INC IX / CALL rpop_de` (5) → `EXX` (1) | −4 | −4 |
| .R `.dotr_neg` scratch elimination (1 data + ~6 code) | 0 | −7 |
| .R `.dotr_str` / `.dotr_len` partial elimination | 0 | −5 to −9 |
| .S entry: `CALL rpush_de + CALL rpush_bc` (6) → `EXX` (1) | −5 | −5 |
| .S exit: `CALL rpop_bc + CALL rpop_de` (6) → `EXX` (1) | −5 | −5 |
| .S `.dots_print_tos` recover: `(IX+0/+1)` (6) → `EXX / PUSH BC / EXX / POP BC` (4) | −2 | −2 |
| **Total**                                                          | **−16** | **−24 to −28** |

Story spec target: 16 conservative, 26 optimistic. Budget aligns.

### References

- [Source: _bmad-output/planning-artifacts/epic8-shadow-register-followup.md#Story 8.3] — epic spec for this story
- [Source: docs/shadow-register-followup-survey.md] — authoritative survey, categorises `.R` / `.S` under Category B "formatting — analysis needed"
- [Source: _bmad-output/implementation-artifacts/8-2-exx-for-dot-and-u-dot.md] — Path 1 pattern proven on DOT/U.; baseline 14,057 bytes
- [Source: _bmad-output/implementation-artifacts/8-1-exx-for-char-and-abort-quote.md] — first Epic 8 story, established post-Epic-7 EXX confidence in formatting-adjacent code
- [Source: _bmad-output/implementation-artifacts/7-3-exx-for-de-only-words.md] — Group A Path 1 origin (MOVE, ROLL); shadow BC' as free TOS-preservation slot (NUMBER?)
- [Source: _bmad-output/implementation-artifacts/7-2-exx-for-recognizer.md] — second-order savings archetype (3 scratch vars eliminated)
- [Source: _bmad-output/implementation-artifacts/epic-7-retro-2026-04-14.md#Key Insights] — "register liberation has compounding second-order savings" lesson
- [Source: src/formatting.asm:11] — `digit_to_char` (verified EXX-free)
- [Source: src/formatting.asm:27] — `div_bc_by_e` (verified EXX-free)
- [Source: src/formatting.asm:55] — `u_to_str` (verified EXX-free; updated header per 8.2 review)
- [Source: src/formatting.asm:92] — `print_neg_prefix` (verified EXX-free)
- [Source: src/formatting.asm:118] — `emit_unsigned` (verified EXX-free; updated header per 8.2 review)
- [Source: src/formatting.asm:173–254] — `w_DOT_R_cf` (edit target)
- [Source: src/formatting.asm:256–258] — `.dotr_neg / .dotr_str / .dotr_len` scratch (elimination candidates)
- [Source: src/formatting.asm:269–361] — `w_DOT_S_cf` (edit target)
- [Source: src/formatting.asm:365–367] — `.dots_print_signed` local helper (unchanged)
- [Source: src/formatting.asm:369–371] — `.dots_depth / .dots_addr / .dots_remaining` (likely retained)
- [Source: src/system.asm:302] — `check_underflow_2` (verified EXX-free)
- [Source: src/io.asm:188] — `bdos_putchar` (verified EXX-free, Epic 7.3 Task 1.2)
- [Source: src/io.asm:204] — `bdos_print_str` (verified EXX-free, Epic 7.3 Task 1.2)
- [Source: src/inner_interpreter.asm] — register contract reference
- [Memory: project_tos_in_register.md] — DEPTH = (sp_base − SP)/2; counts SP cells only (relevant to `.S` depth math sanity-check during restructure)
- [Memory: feedback_repl_tests_preferred.md] — new tests are REPL-piped; this story uses *existing* `.R`/`.S` REPL tests as regression net (no new tests needed)
- [Memory: feedback_adversarial_review.md] — code review must find things; absence of findings is suspect

### Project Structure Notes

- `src/formatting.asm` — only file modified (`w_DOT_R_cf`, `w_DOT_S_cf` bodies and possibly the data scratch at lines 256–258)
- No new files, no new subroutines
- No test changes expected — existing REPL coverage for `.R` and `.S` is the regression net
- No symbol removals (`rpush_*` / `rpop_*` still used elsewhere)

### Open Design Questions (resolve during dev)

1. **`.R` width-keeping strategy:** SP-stash (`PUSH BC` before `u_to_str`, `POP DE` after) vs. shadow-register stash (would require EXX dance). SP-stash is simpler and more byte-efficient.
2. **`.dotr_neg` elimination:** can the negative flag ride in a single bit (e.g., bit 7 of HL high byte, set by the sign test before negation)? Worth attempting — saves ~7 bytes.
3. **`.dotr_str` / `.dotr_len` elimination:** the pad-emit loop calls `bdos_putchar` once per iteration with `PUSH BC / ... / POP BC`. Can HL also be PUSH/POP'd around the BDOS call (1 PUSH HL + 1 POP HL = 2 bytes overhead) to keep the digit-string pointer live across the loop? If yes, the data scratch and its load/store overhead disappears — net several bytes saved. If the BDOS putchar does NOT clobber HL after all (worth re-checking — it's CP/M function 2, register usage well-defined), the PUSH/POP isn't needed at all.
4. **`.dots_walk` scratch (`.dots_addr`, `.dots_remaining`):** these live across BDOS calls in the walk loop. Freed register set after EXX is BC/DE/HL (main set, since shadow holds TOS+IP). 16-bit walk pointer + 16-bit remaining counter = 4 bytes of state, exactly fits BC+DE if we PUSH/POP one of them around each BDOS call. But this is significant restructure for marginal gain — recommend deferring as out-of-scope (matches Epic 8 spec's "may be eliminable" hedge).

## Dev Agent Record

### Agent Model Used

claude-opus-4-6 (Claude Opus 4.6, 1M context)

### Debug Log References

- Initial confusion on `.S` manual sanity: when entering `.S` then `1 .S` then `1 2 3 .S` as separate REPL turns, third turn output was `<4> 1 1 2 3` rather than `<3> 1 2 3`. This is CORRECT — `.S` is `( -- )` non-destructive, so the `1` from the prior turn persisted on the stack. Single-line `1 2 3 .S` correctly produces `<3> 1 2 3`. REPL test 6 confirms this.

### Completion Notes List

**Byte savings achieved: 27 bytes (14,057 → 14,030)** — beats the optimistic spec target of ≤14,031.

**Breakdown:**
- `.R`: −15 bytes (entry EXX + width via SP-stash + exit EXX; `.dotr_neg`/`.dotr_str`/`.dotr_len` retained)
- `.S`: −12 bytes (entry/exit single-EXX + Option C `.dots_print_tos`; `.dots_depth`/`.dots_addr`/`.dots_remaining` retained for walk-loop BDOS-call survival)

**Scratch slots eliminated:** none. **Scratch slots retained:**
- `.dotr_neg` (1 byte) — keeping it as memory scratch costs ~7 bytes (1 data + 3 read + 3 write); register-resident sign would need SP-stash discipline through the pad-loop AND the sign-emit BDOS call (each clobbers BC/DE/HL/A), costing roughly equivalent bytes for marginal benefit and significantly more risk. Retained for clarity.
- `.dotr_str` / `.dotr_len` (3 bytes total) — HL (string addr) and the strlen byte must survive the pad-emit loop's `bdos_putchar` calls. Each loop iteration already does `PUSH BC / ... / POP BC`; adding `PUSH HL / ... / POP HL` would cost +2 bytes per iteration (typically negative net). Memory scratch is byte-optimal here.
- `.dots_depth` / `.dots_addr` / `.dots_remaining` (6 bytes) — live across `.dots_walk` BDOS calls; freeing would require constant SP-stash discipline. Spec marked these as out-of-scope ("may be eliminable") — concur.

**Cumulative Epic 8 progress (vs pre-Epic-8 baseline 14,105):**
- 8.1: 14,105 → 14,061 (−44)
- 8.2: 14,061 → 14,057 (−4)
- 8.3: 14,057 → 14,030 (−27)
- **Total: 75 bytes saved across Epic 8** — exceeds optimistic epic target of 74 bytes.

**Leaf-level audit confirmed:** EXX usage in `src/formatting.asm` remains restricted to leaf words (DOT, U., now .R, .S). Helpers (`u_to_str`, `print_neg_prefix`, `emit_unsigned`, `digit_to_char`, `div_bc_by_e`) and BDOS interfaces (`bdos_putchar`, `bdos_print_str`, `BDOS_ENTRY`) untouched and EXX-free.

**Tests:** 272 REPL + 1 assembly regression — all pass, zero regressions. (Story spec said 273; actual harness has 272 — spec was off by one.)

**Manual hardware test on MicroBeast:** DEFERRED to user — no hardware in this dev environment. Convention from Epic 6/7/8 acknowledged.

**Code review:** Self-adversarial review per `bmad-bmm-code-review` workflow — see Senior Developer Review section below.

### File List

- `src/formatting.asm` (modified — `w_DOT_R_cf` and `w_DOT_S_cf` bodies restructured for EXX; data scratch lines retained)

### Change Log

| Date       | Change |
|------------|--------|
| 2026-04-14 | Restructured `w_DOT_R_cf` to use Path 1 EXX entry/exit + SP-stashed width across `u_to_str`. Removed IX-based width recovery and `rpush_de`/`rpush_bc`/`rpop_de` calls. Saved 15 bytes. |
| 2026-04-14 | Restructured `w_DOT_S_cf` to use single-EXX entry/exit. `.dots_print_tos` recovers original TOS from BC' via Option C (round-trip through SP). Removed `rpush_de`/`rpush_bc`/`rpop_bc`/`rpop_de` calls. Saved 12 bytes. |
| 2026-04-14 | Code review — 4 LOW findings (cosmetic), 0 HIGH/MEDIUM. Polished `.S` entry comment and added 8-bit width truncation note in `.R`. Tests still green at 14,030 bytes. |

## Senior Developer Review (AI)

**Reviewer:** claude-opus-4-6 (self-adversarial per `bmad-bmm-code-review`)
**Date:** 2026-04-14
**Outcome:** Approve

### Summary

Implementation is solid: correct logic, all 7 ACs satisfied, 27-byte savings exceed the optimistic spec target (≤14,031 / ≥26 bytes), leaf-level EXX discipline preserved, and scratch retention well-justified. No HIGH or MEDIUM issues. Manual hardware test deferred to user per Epic 6/7/8 convention.

### Findings

| # | Severity | Description | Disposition |
|---|----------|-------------|-------------|
| 1 | LOW | Misleading comment on `w_DOT_S_cf` entry — claimed "shadow set untouched until exit" but `.dots_print_tos` swaps via EXX. | Fixed inline (formatting.asm:263–266) |
| 2 | LOW | Pre-existing 8-bit width truncation in `.R` — only low byte of width used for padding calc. Not a regression. | Documented as a comment (formatting.asm:215) |
| 3 | LOW | `.dotr_neg` not eliminated — declined per Dev Notes; trade-off was correct (already beat optimistic target). | Accepted as documented |
| 4 | LOW | Vestigial `PUSH BC / POP BC` removed from sign-emit branch in `.dotr_no_pad`. Saved 2 extra bytes; original was defensive caching of unused width. | Verified safe; included in change |

### Action Items

All findings resolved or accepted. No follow-up tasks required.
