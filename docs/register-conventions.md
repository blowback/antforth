# AntForth Register & Shadow-Register Conventions

**Scope:** This document is the authoritative, operational reference for the register contract and the shadow-register (EXX) usage conventions followed by every CODE word in AntForth. It consolidates rules that were previously scattered across the Dev Notes of Stories 7.1, 7.2, 7.3, 8.1, 8.2, and 8.3.

---

## Hard Rules (read these first)

An implementing agent or human developer must not violate any of the following four rules without explicit architectural justification documented in the touching story:

1. **BC = TOS, DE = IP is inviolable.** Every CODE word must exit with BC holding the parameter-stack top and DE holding the interpreter pointer. A single violation corrupts threading immediately and usually fails silently for several instructions before the next word mis-decodes.
2. **EXX is leaf-level only.** An EXX-using CODE word must NOT `CALL` any subroutine that itself issues `EXX`. The Z80 has no push/pop for the shadow set — a nested `EXX` unconditionally swaps the two sets *back*, silently losing the caller's saved IP/TOS. Enforcement is by human/AI review: `grep -nE '^\s*EXX\b' src/*.asm` before you add a CALL inside an EXX word.
3. **Only A (and flags) survive EXX.** Main BC/DE/HL are all shadowed. To cross an exit EXX with a computed value, stage it through A (`LD A, <value>` → exit `EXX` → `LD C, A / LD B, 0`). This is the "A survives EXX" idiom and is the pattern used by `CHAR` and `FILL`.
4. **The return stack is IX-indexed, two-byte cells, grows downward.** Never mix SP-relative and IX-relative cell counting inside one word. A push is `DEC IX / DEC IX / LD (IX+0),E / LD (IX+1),D`; a pop is the reverse. Misaligned push/pop counts per call path silently corrupt the return stack (Epic 7.1 code review found a pre-existing `INC IX` bug in `w_QUERY_cf` via this failure mode).

---

## 1. Register Contract

The following assignments are immutable across every CODE word. They are the canonical interpretation of Forth stack/thread state in this implementation.

| Register | Role | CODE-word rules |
|----------|------|-----------------|
| `BC`  | Top-of-stack (TOS) cell | Must hold current TOS on entry and exit. Body may clobber freely if it restores before `NEXT`. |
| `DE`  | Interpreter pointer (IP) | Points to the next thread-word address. Must not be clobbered across a `CALL` unless the callee is documented IP-preserving (e.g., a helper that `PUSH DE`/`POP DE` around its body), or IP is parked in the shadow set via `EXX`. |
| `HL`  | Word pointer (W) / scratch | DOCOL/DOVAR/DOCON use HL as the word pointer on entry. Otherwise free scratch. |
| `IX`  | Return-stack pointer | Two-byte cells, grows downward. Only modified via explicit push/pop sequences or the `rpush_*`/`rpop_*` helpers. |
| `IY`  | User-area base | Points to the `UserArea` structure. Never reassigned after cold start. |
| `SP`  | Parameter stack pointer | Hardware stack; holds all param-stack cells below TOS. |
| `A` / `AF` | Scratch | Only A (and flags) survive `EXX`. AF' is currently unused across the codebase. |

See also `_bmad-output/planning-artifacts/architecture.md` §Register Usage Discipline for the original architectural statement of this contract.

---

## 2. The Shadow Register Set

The Z80 provides a second register bank addressed via two instructions:

- `EXX` — exchanges `BC`/`DE`/`HL` with `BC'`/`DE'`/`HL'` (one byte, 4 T-states).
- `EX AF, AF'` — exchanges `AF` with `AF'` (one byte, 4 T-states).

There are **no other ways** to access shadow registers. In particular, there is no `LD BC, BC'` or `PUSH BC'` — values cross the set boundary only via a full `EXX`, or by going through memory (including the parameter stack via `PUSH`/`POP`), or by riding on A/flags.

**Current usage across AntForth (as of end of Epic 8):**

- `EXX` is used to park and recover IP/TOS across body code that would otherwise need explicit `rpush_de` / `rpush_bc` save/restore calls. See §4 for the two standard entry patterns.
- `EX AF, AF'` / AF' is **unused**. Scratch across EXX uses A directly (see §5); preservation across calls uses SP or main register staging. AF' remains a dormant resource flagged in Epic 7's retrospective.

---

## 3. The Leaf-Level Rule

**Rule:** an EXX-using CODE word may not `CALL` (directly or transitively) any subroutine that also issues `EXX`.

**Why:** `EXX` is unconditional — it cannot be skipped based on whether a "swap has already happened." Two EXXes in a row (one by caller at entry, one by callee at its own entry) exchange the sets back to caller-set, so the callee sees *caller's* body state, not its own saved caller state. On the return path, the callee's exit `EXX` swaps them again — leaving everything in a state where the caller's body state (likely garbage for TOS/IP) is now in main, and the caller's *saved* TOS/IP are permanently lost in the shadows.

**Enforcement:** there is no automatic guard. Before adding a `CALL` inside an EXX window, grep the callee's call graph for `EXX`:

```sh
grep -nE '^\s*EXX\b' src/*.asm
```

Every entry in §7 of this document is a convention-bound EXX site. Treat any word in that table as poisoned for CALL from within another EXX window.

**A short list of known-safe helpers** (verified EXX-free; may be called from inside an EXX window):

- `bdos_putchar`, `bdos_print_str`, `BDOS_ENTRY` (`src/io.asm`, `src/macros.asm`) — all clobber BC/DE/HL/A, but are EXX-free
- `check_underflow`, `check_underflow_2` (`src/system.asm`)
- `digit_to_char`, `div_bc_by_e`, `u_to_str`, `print_neg_prefix`, `emit_unsigned` (`src/formatting.asm`)
- `rpush_de`, `rpop_de`, `rpush_bc`, `rpop_bc` (`src/inner_interpreter.asm`) — the return-stack helpers themselves are EXX-free. **Note:** while safe to call from inside an EXX window, doing so is semantically wrong: inside an EXX window, IP lives in `DE'` (shadow), not `DE` (main), so `CALL rpush_de` would save the shadow's garbage-DE instead of the IP. The whole point of EXX is to *replace* these calls — don't nest them inside an EXX window.

If you add a new CODE word that uses EXX, audit its call graph against §7 and confirm no transitive EXX.

---

## 4. Group A vs Group B Entry Patterns

There are two standard entry idioms. Choose based on whether the body needs the incoming TOS live in main BC.

### Group A — TOS not needed in main BC during body

Use when the body consumes TOS early into a stable main register (or into A), or when the body operates on param-stack cells below TOS exclusively. The body gets all three main scratch registers (BC/DE/HL) free.

```asm
; FILL ( addr u char -- )    src/memory.asm:224
w_FILL_cf:
        LD      A, C            ; A = fill byte (char) — must precede EXX
        EXX                     ; Save TOS/IP/W to shadows; main BC/DE/HL = scratch
        POP     HL              ; HL = u (count)
        POP     DE              ; DE = addr
        ; ... body uses main BC/DE/HL/A freely ...
        EXX                     ; Restore IP to main DE (BC shadowed but overwritten below)
        POP     BC              ; New TOS from param stack
        NEXT
```

Cost: entry `EXX` (1 byte), exit `EXX` (1 byte) = 2 bytes total.

Other Group A examples: `MARKER` (`src/system.asm:21`), `WORD` (`src/strings.asm:10`), `ROLL` (`src/stack_ops.asm:111`), `>NUMBER` (`src/strings.asm:336`), `COLON` (`src/compiler.asm:358`), `CREATE` (`src/compiler.asm:548`), `CODE` (`src/assembler.asm:1165`).

### Group B — TOS needed live in main BC throughout body

Use when the body calls helpers (e.g., `emit_unsigned`) that expect value-in-BC. Park IP in DE' via EXX while keeping TOS in main BC. Known as Path 1 in Story 8.2.

```asm
; DOT ( n -- )    src/formatting.asm:132
w_DOT_cf:
        CALL    check_underflow
        PUSH    BC              ; stash TOS on param stack
        EXX                     ; DE' = IP (saved); BC' = caller's TOS (not exploited here — DOT doesn't use §6)
        POP     BC              ; main BC = TOS (recovered from SP)
        CALL    print_neg_prefix
        CALL    emit_unsigned
        EXX                     ; main DE = IP (from DE'); main BC = garbage
        POP     BC              ; new TOS from param stack
        NEXT
```

Cost: entry `PUSH BC / EXX / POP BC` (3 bytes), exit `EXX` (1 byte) = 4 bytes total.

Other Group B examples: `U.` (`src/formatting.asm:153`), `.R` variant (see note below).

**.R variant — two live values at entry:** `.R ( n width -- )` needs both values from SP/BC in main registers. The entry is `PUSH BC / EXX / POP DE / POP BC` (4 bytes): width (TOS) → main DE via stack-bounce; value (NOS) → main BC via POP of underlying param cell. See `src/formatting.asm:180` and Story 8.3 Dev Notes for full context.

---

## 5. The "A Survives EXX" Exit-Staging Idiom

When a word computes its **new TOS** in the body (rather than preserving the incoming TOS), A is the only main-set register whose value crosses the exit `EXX` intact. The idiom:

```asm
; CHAR ( -- char )    src/strings.asm:160
w_CHAR_cf:
        PUSH    BC              ; save old TOS on param stack
        EXX                     ; park IP in DE'; main BC/DE/HL free
        ; ... body computes char byte into A ...
        LD      A, D            ; A = computed char value (before EXX)
        ; ... tib_in update, still in body set ...
        EXX                     ; restore IP to main DE
        LD      C, A            ; A survived EXX — build new TOS
        LD      B, 0
        NEXT
```

See `src/strings.asm:200–234` for the full sequence. This idiom is the reason the FILL example in §4 also does `LD A, C` *before* its entry EXX — `LD A, C` before the swap would not have worked.

---

## 6. Shadow BC' as a Free TOS-Preservation Slot

For words with stack effect `( x -- ... )` that need the original `x` on one exit path (typically a failure/reject branch), a plain entry `EXX` leaves the original TOS sitting in `BC'` for free. No explicit `PUSH BC / POP BC` bracket is needed.

### Canonical example — `NUMBER?`

```asm
; NUMBER? ( c-addr -- n true | c-addr false )    src/strings.asm:369
w_NUMBER_Q_cf:
        PUSH    BC              ; save c-addr on param stack
        EXX                     ; save TOS/IP/W; shadow BC' = c-addr_orig
        POP     HL              ; HL = c-addr (main, for parsing)
        ; ... conversion body ...
.numq_fail:
        ; Shadow BC' still holds original c-addr
        EXX                     ; Restore IP; main BC = c-addr_orig (for free)
        PUSH    BC              ; Push c-addr as NOS
        LD      BC, 0           ; FALSE (new TOS)
        NEXT
```

On the fail path, the body has not disturbed the shadow set, so `EXX` at exit both restores IP to main DE *and* brings the original c-addr back into main BC — no explicit save/restore pair needed for the rollback.

### Advanced pattern — `.S` (`src/formatting.asm:341`)

`.S` is `( -- )` but needs to *display* the original TOS as part of stack inspection. The TOS is parked in BC' by the entry EXX. To recover it into main BC for `emit_unsigned` (which expects value-in-main-BC) *without disturbing the shadow set*, use a double-EXX / SP bounce:

```asm
.dots_print_tos:
        EXX                     ; main = entry set: BC=TOS, DE=IP
        PUSH    BC              ; original TOS to SP
        EXX                     ; back to body set; BC'/DE' still hold TOS/IP
        POP     BC              ; main BC = original TOS
        CALL    .dots_print_signed
```

**Flag:** this is an *advanced* pattern (4 bytes for the round-trip). Use only when a plain swap is insufficient (e.g., when the body is mid-loop and cannot afford to leave the shadow set). For a simple rollback at a reject branch, the `NUMBER?` pattern (single EXX, no bounce) is strictly preferred.

---

## 7. Complete List of EXX-Using Words and Routines

This list is authoritative for end-of-Epic-8. Regenerate with:

```sh
grep -nE '^\s*EXX\b' src/*.asm
```

Per-file breakdown of every convention-bound EXX site. In each table, the **Lines** column lists the word's label line first, followed by its EXX-instruction lines (entry + exit(s) + any internal swaps).

### `src/compiler.asm`

| Lines (label / EXX) | Word | Role |
|------|------|------|
| 358 / 361 / 393 / 397 | `w_COLON` / `:` | Group A — entry `EXX`, two exit `EXX`s (one per exit path) |
| 548 / 551 / 572 / 576 | `w_CREATE` | Group A — entry/exit EXX |
| 584 / 587 / 601 / 603 / 606 / 608 / 617 / 622 | `w_CONSTANT` | Group A with internal EXX swaps to re-access saved value from BC' during body (see §6 advanced pattern) |

### `src/strings.asm`

| Lines (label / EXX) | Word | Role |
|------|------|------|
| 10 / 16 / 74 / 148 | `w_WORD` | Group A — entry EXX, two exit EXXes (success/empty paths) |
| 160 / 165 / 231 | `w_CHAR` | Group A — entry EXX, exit EXX, "A survives EXX" staging (§5) |
| 336 / 342 / 359 | `w_TO_NUMBER` / `>NUMBER` | Group A — entry/exit EXX |
| 369 / 376 / 425 / 431 | `w_NUMBER_Q` / `NUMBER?` | Group A + shadow BC' preservation slot (§6 canonical) |
| 820 / 826 / 867 / 877 | `w_PAREN` / `(` | Group A — entry EXX, two exit EXXes |

### `src/memory.asm`

| Lines (label / EXX) | Word | Role |
|------|------|------|
| 224 / 230 / 254 | `w_FILL` | Group A — `LD A, C` before entry EXX to stage char through A |
| 263 / 269 / 301 | `w_MOVE` | Group A — entry/exit EXX (wraps LDIR which clobbers BC/DE/HL) |

### `src/stack_ops.asm`

| Lines (label / EXX) | Word | Role |
|------|------|------|
| 111 / 126 / 168 | `w_ROLL` | Group A — entry/exit EXX |

### `src/io.asm`

| Lines (label / EXX) | Word | Role |
|------|------|------|
| 116 / 124 / 143 | `w_ACCEPT` | Group A — entry EXX, exit EXX after BDOS read line |

### `src/system.asm`

| Lines (label / EXX) | Word | Role |
|------|------|------|
| 21 / 24 / 75 / 79 | `w_MARKER` | Group A — entry EXX, two exit EXXes |

### `src/assembler.asm`

| Lines (label / EXX) | Word / Routine | Role |
|------|----------------|------|
| 886 / 898 / 931 / 956 | `w_ASM_RECOGNIZE_cf` | Group A — entry EXX after fast-fail, two exit EXXes (match / no-match) |
| 1165 / 1180 / 1209 / 1213 | `w_CODE` | Group A — entry/exit EXX |
| 1221 / 1229 / 1260 | `w_END_CODE` | Group A — entry/exit EXX |
| 2142 / 2148 / 2156 | `w_NEXT_COMMA` / `NEXT,` | Group A — entry/exit EXX |
| 2194 / 2198 / 2275 / 2289 | `w_LABEL` | Group A — entry EXX, two exit EXXes |

### `src/formatting.asm`

| Lines (label / EXX) | Word | Role |
|------|------|------|
| 132 / 138 / 144 | `w_DOT` / `.` | Group B (Path 1) — canonical example |
| 153 / 159 / 163 | `w_U_DOT` / `U.` | Group B |
| 173 / 180 / 244 | `w_DOT_R` / `.R` | Group B two-value variant |
| 262 / 268 / 344 / 346 / 352 | `w_DOT_S` / `.S` | Group A + shadow BC' preservation slot (§6 advanced pattern — `.dots_print_tos` double-EXX/SP-bounce) |

### Notable exceptions (NOT convention-bound EXX sites)

- **`(ABORT")` runtime — `.paq_abort` inside `w_ABORT_QUOTE_cf`** (`src/system.asm:114`, where `w_ABORT_QUOTE:` is at line 138 / `_cf` at 140). Uses **no IP save at all** — no EXX, no `PUSH DE`, no `rpush_de`. Story 8.1 deleted the former `CALL rpush_de` + `INC IX / INC IX` unwind outright as dead code: `w_ABORT_cf` (at `src/system.asm:258`) resets SP via `LD SP, (sp_base)` and `JP w_QUIT_cf` resets IX and reloads DE, so any leftover IP/return-stack state is garbage-collected before anyone could read it. A future maintainer may be tempted to *add back* an IP save here for "safety" — do not. The inline comments at `src/system.asm:116–118` state the rationale in the source.

**Total: ~22 convention-bound EXX-using words across 8 source files.**

---

## 8. Out-of-Scope / Deferred EXX Candidates

The following `rpush_de`/`rpush_bc` call sites remain unconverted by explicit Epic 7/8 decision. They are documented here to prevent rediscovery as "missed opportunities":

- **`src/compiler.asm:689`** — `(;CODE)` / DOES> runtime exit. Category D exclusion (hot path, functional R-stack manipulation).
- **`src/control_flow.asm:207`** — `(DO)` runtime. Category D (functional R-stack use — loop params pushed for `LOOP`/`+LOOP` to consume).
- **`src/outer_interpreter.asm:99–127`** — the INTERPRET loop itself. Category D (*is* the main thread; any EXX here reframes the whole interpreter state model).
- **`src/system.asm:114`** (`.paq_abort` inside `w_ABORT_QUOTE_cf` @ line 140) — the `(ABORT")` runtime. See §7 exception note.

### Dormant resources

- **AF' / `EX AF, AF'`** is entirely unused. No word currently needs to preserve A/flags across a subroutine boundary where EXX-style reasoning does not already suffice. Flagged in Epic 7 retrospective as a dormant resource.

### Non-EXX micro-optimisations flagged in prior retros

- **`.word_delim` scratch byte elimination in WORD** (1 byte) — out of scope for shadow-register work; noted in Epic 7.3 Task 6.3.

See `docs/shadow-register-followup-survey.md` for the full survey behind these exclusions.

---

## References

Source-of-truth documents consulted or referenced by this convention doc:

- `docs/shadow-register-survey.md` — Epic 7 survey establishing the EXX convention
- `docs/shadow-register-followup-survey.md` — Epic 8 follow-up survey (classified candidate words into Path 1 / Path 2 / Category D)
- `_bmad-output/planning-artifacts/architecture.md` §Register Usage Discipline — original register contract statement
- `_bmad-output/planning-artifacts/epic7-shadow-register-optimization.md` — Epic 7 scope and story split
- `_bmad-output/planning-artifacts/epic8-shadow-register-followup.md` — Epic 8 scope; Story 8.4 (this doc) specification on lines 160–175

Per-story Dev Notes establishing individual conventions:

- `_bmad-output/implementation-artifacts/7-1-exx-for-build-header-words.md` — COLON/CREATE/CONSTANT/CODE/END-CODE/NEXT,/LABEL/MARKER conversions; leaf-level rule
- `_bmad-output/implementation-artifacts/7-2-exx-for-recognizer.md` — ASM_RECOGNIZE; scratch-variable elimination lesson
- `_bmad-output/implementation-artifacts/7-3-exx-for-de-only-words.md` — FILL/MOVE/ROLL/ACCEPT/WORD/>NUMBER/NUMBER?/`(` conversions; shadow-BC'-as-preservation-slot idiom (NUMBER?)
- `_bmad-output/implementation-artifacts/epic-7-retro-2026-04-14.md` — Epic 7 retrospective; action item #5 is the direct parent of this doc
- `_bmad-output/implementation-artifacts/8-1-exx-for-char-and-abort-quote.md` — CHAR; "A survives EXX" idiom; `(ABORT")` bare-PUSH-DE exception
- `_bmad-output/implementation-artifacts/8-2-exx-for-dot-and-u-dot.md` — DOT/U.; Group B (Path 1) pattern on the formatting pipeline
- `_bmad-output/implementation-artifacts/8-3-restructure-dot-r-and-dot-s.md` — .R/.S restructure; `.R` two-value entry variant; `.S` `.dots_print_tos` advanced double-EXX pattern; limits of shadow relief across BDOS calls
