# Story 8.1: EXX for CHAR and (ABORT") Runtime

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a system maintainer,
I want the two remaining non-formatting `CALL rpush_de` / `CALL rpop_de` save/restore sites cleaned up — `CHAR` via the Group A EXX pattern and `(ABORT")` by deleting genuinely dead stack management — so that the binary shrinks by ~10–14 bytes and the Epic 7 shadow-register conversion is mechanically complete.

## Acceptance Criteria

1. **Given** `w_CHAR_cf` (src/strings.asm:162) currently uses `PUSH BC` (save old TOS to parameter stack) + `CALL rpush_de` (save IP to return stack) at entry and `CALL rpop_de` at exit **When** entry is converted to `PUSH BC / EXX` and exit to `EXX / POP BC` (identical to the Epic 7.3 MOVE pattern) **Then** `make test && make test-repl` passes all 265 regression tests with zero failures.

2. **Given** `w_CHAR_cf` currently uses a 1-byte `.char_result` scratch (src/strings.asm:255) to stash the parsed first character across the post-find `.char_scan` advance loop (because PUSH/POP dances around `tib_in` updates make register preservation awkward) **When** the body is restructured to use main BC/DE/HL as free scratch after EXX **Then** either (a) `.char_result` is eliminated entirely and the character rides in a main register, or (b) Dev Notes records why elimination would cost more bytes than it saves. Either outcome is acceptable.

3. **Given** `(ABORT")` runtime path `.paq_abort` (src/system.asm:114–137) currently uses `CALL rpush_de` at entry (3 bytes) and `INC IX / INC IX` at `.paq_do_abort` (4 bytes) before `JP w_ABORT_cf` — and the saved DE value is **never read back** (the code between rpush and unwind does not `CALL rpop_de` or `LD DE, (IX+...)` to restore IP) **When** both the `CALL rpush_de` and the `INC IX / INC IX` unwind are deleted outright **Then** all 265 regression tests pass; CP/M BDOS preserves IX in AntForth's environment (established by every existing BDOS-calling word that uses IX as return stack), and `w_ABORT_cf` resets SP wholesale before any code would read a stale IX — so the stack management genuinely accomplishes nothing.

4. **Given** EXX is a leaf-level technique **When** converting `w_CHAR_cf` **Then** the body contains no CALLs to any EXX-using subroutine (the parse loop is entirely inline; IY-relative loads for `tib_addr`/`tib_len`/`tib_in` are instructions, not subroutines). For `(ABORT")`, `bdos_print_str` is verified EXX-free from Epic 7.3 Task 1.2 — though moot since this story's `(ABORT")` path uses no EXX.

5. **Given** the conversions land **When** `wc -c build/antforth.com` is measured **Then** the binary is at least 8 bytes smaller than the pre-story baseline (14,105 bytes). Conservative target. Expected combined savings: 10–14 bytes (4–8 from CHAR, 7 from (ABORT")).

6. **Given** the changes land **When** the full regression suite runs (`make test && make test-repl`) **Then** all 265 tests pass with zero failures; no previously-passing test may regress.

## Tasks / Subtasks

- [x] Task 0: Record baseline (AC: #5)
  - [x] 0.1 `make asm && wc -c build/antforth.com` — confirm 14,105 bytes
  - [x] 0.2 `make test && make test-repl` — confirm all 265 tests pass

- [x] Task 1: Convert w_CHAR_cf to EXX (AC: #1, #2, #4)
  - [x] 1.1 Replace `CALL rpush_de` (src/strings.asm:167, 3 bytes) with `EXX` (1 byte) — note the preceding `PUSH BC` stays (it's preserving old TOS on the parameter stack, not a save/restore thing)
  - [x] 1.2 Replace `CALL rpop_de` at the exit (src/strings.asm:252, 3 bytes) with `EXX` (1 byte)
  - [x] 1.3 Eliminated the PUSH/POP dance around tib_in updates entirely — rather than tracking tib_in during the loops, compute new tib_in = parse_ptr - tib_addr once at exit (HL holds final parse_ptr; DE loaded with tib_addr via IY, SBC HL,DE gives new tib_in).
  - [x] 1.4 Eliminated `.char_result` scratch byte: char value stashed in main D between `.char_found` and `.char_finish`; then moved to A (which survives the final EXX) and built into BC after the exit EXX.
  - [x] 1.5 `make asm && make test && make test-repl` — all tests pass
  - [x] 1.6 Byte delta after CHAR conversion: 14,105 → 14,072 = **−33 bytes**

- [x] Task 2: Delete dead stack management in (ABORT") runtime (AC: #3, #4)
  - [x] 2.1 Verified: between `.paq_abort` and `JP w_ABORT_cf` no instruction reads the return-stack slot created by rpush_de. `LD A,(DE)` and `INC DE` use live main DE, not a restored copy.
  - [x] 2.2 Verified `bdos_print_str` (src/io.asm:204) uses only HL/BC/DE/A — never touches IX. IX-preservation is established by every `rpush_de` → BDOS → `rpop_de` sequence in the codebase.
  - [x] 2.3 Verified `w_ABORT_cf` (src/system.asm:266-270) resets SP via `LD SP, (sp_base)` and tail-calls `w_QUIT_cf` which resets IX.
  - [x] 2.4 Deleted `CALL rpush_de` at src/system.asm:120
  - [x] 2.5 Deleted `INC IX / INC IX` at src/system.asm:135–136
  - [x] 2.6 Updated comments to explain that no save is needed because ABORT resets stacks wholesale and bdos_print_str preserves IX.
  - [x] 2.7 `make asm && make test && make test-repl` — all tests pass
  - [x] 2.8 Byte delta after (ABORT") change: 14,072 → 14,065 = **−7 bytes** (matches predicted exactly)

- [x] Task 3: Final verification (AC: #5, #6)
  - [x] 3.1 `make test && make test-repl` — assembly test passes + 272 REPL tests pass (story cited 265 baseline; current count is 272 — all green, zero failures)
  - [x] 3.2 Final binary size: 14,065 bytes; delta from 14,105 baseline = **−40 bytes**
  - [x] 3.3 Savings 40 ≥ 8 bytes ✓
  - [x] 3.4 CHAR behaviour covered by REPL tests 251 (`CHAR A .` → 65), 252 (`CHAR Z .` → 90), and 254 (`[CHAR] A` → 65) — all pass. Hardware spot-check deferred to code-review phase.
  - [x] 3.5 ABORT" behaviour covered by REPL tests 257 (zero flag → no abort) and 258 (non-zero flag → prints message and aborts) — all pass. Hardware spot-check deferred to code-review phase.

## Dev Notes

### Epic Context

Story 8.1 is the first story of Epic 8 (Shadow Register Follow-Up). It completes the mechanical part of the EXX conversion that Epic 7 left on the table: two non-formatting sites that share the `CALL rpush_de` / `CALL rpop_de` pattern but fell outside the Epic 7 candidate lists. Story 8.2 (DOT + U.) and 8.3 (.R + .S restructure) will tackle the formatting pipeline that Epic 7 declared out of scope.

### Pre-Story Baseline

- Binary: 14,105 bytes (post-Epic 7 + code review fixes)
- Tests: 265/265 pass (assembly + REPL)
- EXX users (all leaf-level, non-nested):
  - 7.1: COLON, CREATE, CONSTANT, CODE, END-CODE, NEXT,, LABEL, MARKER
  - 7.2: ASM_RECOGNIZE (partial — `.recog_fast_false` path does not EXX)
  - 7.3: FILL, MOVE, ROLL, ACCEPT, WORD, >NUMBER, NUMBER?, `(`

### The Two Conversions Are Structurally Different

**CHAR** is a standard Epic 7.3 Group A-style conversion: the entry EXX parks DE=IP in DE' while `PUSH BC` preserves old TOS on the parameter stack, the body runs in the freed main register set, and the exit EXX + `POP BC` restores IP and new TOS. Savings come from two 2-byte reductions (CALL→EXX at entry and exit) plus potentially eliminating the `.char_result` scratch byte.

**(ABORT")** is **NOT an EXX conversion** — it's dead-code removal. The story title frames it as part of the EXX cleanup because it came out of the same survey, but the transformation is simply deleting 7 bytes of stack management that does nothing useful. No EXX or replacement save mechanism is needed.

### CHAR Conversion Pattern

Current (src/strings.asm:160–253):
```asm
w_CHAR_cf:
    PUSH    BC              ; save old TOS to parameter stack (grows stack by 1)
    CALL    rpush_de        ; save IP to return stack — 3 bytes
    ; body: parse next token from TIB, store first char in .char_result
    ; many PUSH HL/PUSH BC pairs around tib_in updates because DE=IP is pinned
    ...
    LD      A, (.char_result)
    LD      C, A
    LD      B, 0            ; BC = new TOS (char value)
    CALL    rpop_de         ; restore IP — 3 bytes
    NEXT

.char_result:   DB 0        ; 1-byte scratch data
```

After (target):
```asm
w_CHAR_cf:
    PUSH    BC              ; unchanged — save old TOS
    EXX                     ; 1 byte — IP parked in DE', BC' = garbage (irrelevant)
    ; body: main BC/DE/HL all free scratch
    ; tib_in updates can use main DE persistently → most PUSH/POP pairs go away
    ...
    ; Compute BC = char value (either from freed main register or from .char_result memory)
    LD      C, A            ; or similar, depending on where char ends up
    LD      B, 0
    EXX                     ; 1 byte — IP restored from DE', main BC/DE/HL swapped away
    POP     BC              ; restore new TOS? — wait, need to be careful
```

**Subtle point:** After the exit EXX, main BC holds whatever was in BC' — which is garbage from the initial swap. So `POP BC` from the parameter stack is still needed to get the new TOS (the old TOS was saved with `PUSH BC` at entry, and the old TOS has now been consumed — CHAR's stack effect is `( -- char )`, it pushes a new value without consuming one).

Actually, re-reading CHAR's stack effect: `( "<spaces>name" -- char )`. It pushes a char without consuming anything. So the `PUSH BC` at entry is growing the stack (saving the old TOS one level down so the new char-TOS can go in BC).

**Corrected exit:**
```asm
    ; Build new TOS (char value) before exit EXX.
    ; But new TOS must end up in main BC after the exit EXX.
    ; EXX swaps main BC with BC' (which was seeded as garbage at entry).
    ; Use "A survives EXX" idiom: stage char value in A across exit EXX.

    LD      A, <char-value>  ; char parsed, held in A (preserved across EXX)
    EXX                      ; IP restored to main DE, BC = garbage
    LD      C, A             ; build new TOS
    LD      B, 0
    NEXT
```

No `POP BC` needed at exit because the `PUSH BC` at entry is compensated by the stack-growth semantics of `( -- char )` — the old TOS now lives below the new TOS on the parameter stack.

**Double-check against current code:** current exit is `CALL rpop_de / NEXT` — no POP BC. The `PUSH BC` at entry was NOT balanced by a POP; it was deliberately growing the stack for the new-char push. So the Group A pattern here is specifically:
- Entry: `PUSH BC` (stack-grow) + `EXX` (park IP) — 2 bytes total
- Exit: `EXX` (restore IP) + build new TOS in BC via A-staging

**Entry savings:** CALL rpush_de (3) → EXX (1) = −2 bytes.
**Exit savings:** CALL rpop_de (3) → EXX (1) = −2 bytes.
**Base savings: 4 bytes.**
**Plus** potential `.char_result` elimination (1 byte data + multi-byte load/store overhead) = additional 2–4 bytes if feasible.

### (ABORT") Dead-Code Analysis

Current (src/system.asm:114–137):
```asm
.paq_abort:
    ; Non-zero flag path: print string then JP ABORT
    CALL    rpush_de        ; save IP to return stack — 3 bytes
    LD      A, (DE)         ; A = count
    INC     DE              ; DE = string start
    OR      A
    JR      Z, .paq_do_abort ; empty string — skip print
    LD      B, A            ; B = count
    LD      H, D
    LD      L, E            ; HL = string address
    CALL    bdos_print_str  ; clobbers DE (doesn't matter — we never read DE again)

.paq_do_abort:
    INC     IX              ; 2 bytes — unwind rpush_de slot
    INC     IX              ; 2 bytes
    JP      w_ABORT_cf      ; never returns; ABORT resets SP, IX, reloads DE
```

**Claim:** The `CALL rpush_de` and the `INC IX / INC IX` unwind are both dead code. Proof by case analysis:

1. **The saved DE is never consumed.** Between `CALL rpush_de` (line 120) and `JP w_ABORT_cf` (line 137), no instruction reads the return-stack slot that rpush_de created. `LD A, (DE) / INC DE` at lines 122–123 uses the live main DE (pointing to the inline string count byte), not the saved copy.

2. **ABORT erases all stack state.** `w_ABORT_cf` (src/system.asm:266) executes `LD SP, (sp_base)` and `JP w_QUIT_cf`. `w_QUIT_cf` resets IX (return stack) and DE (IP) from known values. Anything on IX at the moment of `JP w_ABORT_cf` is garbage-collected.

3. **BDOS preserves IX in AntForth's environment.** Every existing `CALL rpush_de` → BDOS helper → `CALL rpop_de` sequence in the codebase (DOT, ACCEPT, WORD, etc.) relies on IX surviving BDOS calls. If BDOS trashed IX, those words would all be broken — but 265 tests pass. So IX-preservation is an established invariant, and the `INC IX / INC IX` "unwind" is exactly balanced by the `CALL rpush_de` that preceded it, making both together a no-op.

**Conclusion:** Delete both. Total savings: 3 + 4 = **7 bytes**. No replacement needed.

### Leaf-Level Audit

**CHAR body:** No CALLs (parse loop is entirely inline; IY-relative loads are single instructions). Leaf-level rule trivially satisfied.

**(ABORT") body:** Calls `bdos_print_str` only. `bdos_print_str` is verified EXX-free (Epic 7.3 Task 1.2). Leaf-level rule satisfied — though the story doesn't actually introduce EXX here, so this audit is defensive only.

### Register Contract Reminder

- `BC` = TOS, `DE` = IP, `SP` = parameter stack, `IX` = return stack, `IY` = user pointer, `HL`/`AF` = scratch
- After EXX: BC'/DE'/HL' preserved, main BC/DE/HL = free scratch
- A (and AF) survive EXX — canonical idiom for exit-staging a computed byte value

### Previous Story Learnings (7.1, 7.2, 7.3)

**From 7.1 (build-header words):**
- EXX is safe in AntForth (BDOS doesn't touch shadows, no ISRs)
- Code review caught a vestigial `INC IX` in `w_QUERY_cf` left over from rpop_bc refactoring — always audit for leftover stack-management instructions after refactoring (DIRECTLY RELEVANT to Task 2.5)

**From 7.2 (recognizer):**
- When EXX frees registers, hunt for scratch-variable eliminations (`.recog_save_ip`, `.recog_len`, `.recog_name` all removed → 5 bytes of data eliminated)
- Code review found additional savings beyond initial conversion (tail-merge fall-through, −11 bytes)

**From 7.3 (DE-only words):**
- The Group A pattern (`PUSH BC / EXX / POP BC` entry, `EXX` exit) is proven in MOVE — but CHAR is slightly different because its `PUSH BC` is stack-grow semantics, not TOS-preservation, so there's no matching `POP BC` at exit
- "A survives EXX" idiom: stage new TOS through A across the exit EXX, rebuild BC from A after — this is the pattern for CHAR exit
- Shadow BC' as free TOS-preservation slot — not applicable to CHAR (which pushes, not transforms) but worth noting

### What Not To Change

- **The `PUSH BC` at w_CHAR_cf entry** stays — it's stack-grow for the `( -- char )` effect, unrelated to IP save/restore
- **`.char_skip` and `.char_scan` loop logic** — only the save/restore is changing; the parse logic is correct
- **Any other `(ABORT")` code path** — only `.paq_abort` has dead stack management; the flag-zero fast path (src/system.asm:97–112) is fine

### Build/Test Commands

```bash
make asm                    # Assemble with sjasmplus
make test                   # Run assembly-level regression tests
make test-repl              # Run REPL-piped Forth regression tests
wc -c build/antforth.com    # Check binary size
```

### Byte Budget

| Change | Old (bytes) | New (bytes) | Savings |
|--------|-------------|-------------|---------|
| CHAR entry CALL rpush_de → EXX | 3 | 1 | 2 |
| CHAR exit CALL rpop_de → EXX | 3 | 1 | 2 |
| CHAR `.char_result` elimination (if feasible) | 1 data + ~4 overhead | 0 | 0–5 |
| (ABORT") CALL rpush_de deletion | 3 | 0 | 3 |
| (ABORT") INC IX / INC IX deletion | 4 | 0 | 4 |
| **Conservative total** | | | **11 bytes** |
| **Optimistic total** | | | **16 bytes** |

AC target: ≥ 8 bytes (conservative floor, allows for `.char_result` deferral under AC #2(b)).

### References

- [Source: docs/shadow-register-followup-survey.md] — Epic 8 survey, categorises this story as "Category A — Simple Mechanical Candidates" (sections A.1 CHAR, A.2 (ABORT"))
- [Source: _bmad-output/planning-artifacts/epic8-shadow-register-followup.md#Story 8.1] — Epic spec
- [Source: _bmad-output/implementation-artifacts/7-3-exx-for-de-only-words.md] — Group A pattern (FILL, MOVE, ROLL, ACCEPT) and A-staging idiom
- [Source: src/strings.asm:156–255] — w_CHAR_cf + `.char_result` scratch
- [Source: src/system.asm:82–137] — w_PAREN_ABORT_QUOTE_cf + `.paq_abort` / `.paq_do_abort`
- [Source: src/system.asm:266] — w_ABORT_cf (for verifying ABORT reset semantics)
- [Source: src/inner_interpreter.asm] — rpush_de/rpop_de reference (NOT modified)

### Project Structure Notes

- `src/strings.asm` — CHAR conversion (Task 1)
- `src/system.asm` — (ABORT") dead-code removal (Task 2)
- `src/inner_interpreter.asm` — reference only (rpush_de/rpop_de bodies, NOT modified)
- No new files, no new subroutines

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context) — claude-opus-4-6[1m]

### Debug Log References

None — no debugging required; all changes landed cleanly on first build.

### Completion Notes List

- **CHAR saved 33 bytes** (more than the 4-byte base target + 2-4 byte `.char_result` bonus). The extra savings came from realising that `tib_in` does not need to be tracked incrementally during the skip/scan loops — since `parse_ptr = tib_addr + tib_in` is invariant, the new `tib_in` can simply be computed as `parse_ptr - tib_addr` once at exit via a single `SBC HL, DE`. This eliminated **two** copies of the 17-byte `PUSH HL / PUSH BC / LD L,(IY+tib_in) / LD H,(IY+tib_in+1) / INC HL / LD (IY+tib_in),L / LD (IY+tib_in+1),H / POP BC / POP HL` dance inside the inner loops. The freed register pressure also allowed `.char_result` (1 byte data + 2 × `LD (.char_result),A` + `LD A,(.char_result)` = ~7 bytes of overhead) to be removed — char rides in main D between `.char_found` and `.char_finish`, then is moved to A (preserved across the exit EXX) to build the new TOS. Entry computation also slightly tightened by using direct `LD B,(IY+...)` / `LD C,(IY+...)` instead of `LD A,(IY+...) / LD B,A` pairs now that BC is free post-PUSH.
- **(ABORT") saved 7 bytes** exactly as predicted — `CALL rpush_de` (3) and `INC IX / INC IX` (4) both deleted. Verified all three prerequisites: (a) saved DE never read back, (b) `bdos_print_str` (src/io.asm:204-214) touches only HL/BC/DE/A, (c) `w_ABORT_cf` resets SP and tail-calls `w_QUIT_cf` which resets IX.
- **Total: 14,105 → 14,065 bytes (−40 bytes)**, well above the AC #5 floor of 8 bytes.
- **Test count note:** story AC cited 265 tests; current count is 272 REPL tests + 1 assembly regression. All pass; no regressions.
- AC #2 satisfied via option (a) — `.char_result` eliminated entirely.
- Leaf-level audit (AC #4): new CHAR body makes no CALLs (parse loop fully inline); `.paq_abort` introduces no new EXX so `bdos_print_str` EXX-freeness is defensive-only.
- **Code review (2026-04-14):** M1 (tib_in double-load), L1 (misleading DE comment), L3 (invariant note at `.char_empty`) all fixed. Additional 4 bytes saved. L2 (no regression test covering CHAR at exhausted TIB) left as a pre-existing coverage gap — behaviour is unchanged from pre-story code.

### File List

- Modified: src/strings.asm (w_CHAR_cf rewritten: EXX pattern + tib_in at-exit computation + `.char_result` elimination)
- Modified: src/system.asm (w_PAREN_ABORT_QUOTE_cf `.paq_abort` path — removed dead rpush_de + INC IX/INC IX unwind, updated comments)

### Change Log

- 2026-04-14: Converted `w_CHAR_cf` to Group A EXX pattern (PUSH BC / EXX entry, EXX + A-staged TOS build at exit). Eliminated incremental tib_in tracking inside skip/scan loops (compute at exit as parse_ptr - tib_addr). Eliminated `.char_result` scratch byte. Saved 33 bytes.
- 2026-04-14: Removed dead `CALL rpush_de` and `INC IX / INC IX` stack-management pair from `.paq_abort` — the saved IP was never consumed and `w_ABORT_cf` resets SP/IX/IP wholesale. Saved 7 bytes.
- 2026-04-14: Code-review fixes applied to `w_CHAR_cf` — (M1) reordered prologue to copy tib_in into BC directly instead of loading it from IY a second time for the remaining calc (saves 4 bytes by dropping two IY-relative loads in exchange for two register-to-register copies); (L1) corrected misleading post-subtract comment that claimed DE held tib_len when it actually holds remaining; (L3) added invariant note at `.char_empty` that HL must remain live for the tib_in writeback. Final binary: 14,065 → 14,061 bytes (−4). Cumulative story delta: 14,105 → 14,061 = **−44 bytes**. All 272 REPL + assembly regression tests pass.
