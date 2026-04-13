# Shadow Register Follow-Up Survey (Epic 8 Input)

**Date:** 2026-04-14
**Context:** Epic 7 retrospective identified remaining shadow-register optimisation opportunities. This survey audits every unconverted save/restore site and categorises each by feasibility, savings estimate, and risk to produce a basis for Epic 8 story decomposition.

## Current Baseline

- **Binary size:** 14,105 bytes (post-Epic 7, post-review)
- **EXX users (established):** 13 words across 7.1 (8), 7.2 (1), 7.3 (8) — note 7.1 and 7.3 each count their pre-existing words; there is no overlap
  - 7.1: COLON, CREATE, CONSTANT, CODE, END-CODE, NEXT,, LABEL, MARKER
  - 7.2: ASM_RECOGNIZE (partial — fast-false path does not EXX)
  - 7.3: FILL, MOVE, ROLL, ACCEPT, WORD, >NUMBER, NUMBER?, `(`
- **EX AF,AF' users:** none (AF' register set is entirely pristine and unused)

## Remaining Save/Restore Sites

Grep of `CALL (rpush|rpop)_(de|bc)` across `src/` yields 22 sites outside the Epic 7 converted set. They split into four categories:

### Repo-Wide Inventory

| File | Line | Instruction | Belongs To | Category |
|------|------|-------------|------------|----------|
| inner_interpreter.asm | 101 | CALL rpush_de | DOCOL | D (NOT candidate — hot path) |
| inner_interpreter.asm | 102 | CALL rpush_bc | DOCOL | D (NOT candidate) |
| inner_interpreter.asm | 124 | CALL rpop_de | EXIT | D (NOT candidate — IS the EXIT primitive) |
| compiler.asm | 689 | CALL rpop_de | (DOES>) runtime | D (NOT candidate — functional EXIT) |
| strings.asm | 167 | CALL rpush_de | CHAR entry | A (simple candidate) |
| strings.asm | 252 | CALL rpop_de | CHAR exit | A (simple candidate) |
| formatting.asm | 135 | CALL rpush_de | DOT entry | B (formatting — analysis needed) |
| formatting.asm | 140 | CALL rpop_de | DOT exit | B |
| formatting.asm | 154 | CALL rpush_de | U. entry | B |
| formatting.asm | 157 | CALL rpop_de | U. exit | B |
| formatting.asm | 173 | CALL rpush_de | .R entry | B |
| formatting.asm | 176 | CALL rpush_bc | .R entry (width) | B |
| formatting.asm | 245 | CALL rpop_de | .R exit | B |
| formatting.asm | 267 | CALL rpush_de | .S entry | B |
| formatting.asm | 270 | CALL rpush_bc | .S entry (TOS data) | B |
| formatting.asm | 351 | CALL rpop_bc | .S exit | B |
| formatting.asm | 354 | CALL rpop_de | .S exit | B |
| system.asm | 120 | CALL rpush_de | (ABORT") runtime | A (simple candidate) |
| control_flow.asm | 207 | CALL rpush_bc | (DO) runtime | D (NOT candidate — functional R-push) |
| outer_interpreter.asm | 99 | CALL rpush_de | INTERPRET entry | D (NOT candidate — main thread) |
| outer_interpreter.asm | 100 | CALL rpush_bc | INTERPRET entry | D |
| outer_interpreter.asm | 126 | CALL rpop_bc | INTERPRET exit | D |
| outer_interpreter.asm | 127 | CALL rpop_de | INTERPRET exit | D |

---

## Category A — Simple Mechanical Candidates

Low-risk, same pattern as Epic 7 Group B (PAREN, NUMBER?). Each word saves DE only (or DE for BDOS safety) and can convert to a single EXX entry plus matching exit EXX.

### A.1 — CHAR (`src/strings.asm:160`)

**Current shape:**
```
w_CHAR_cf:
    PUSH  BC                         ; save old TOS (param stack)
    CALL  rpush_de                   ; 3 bytes — save IP
    ; body: parses TIB token, stores first char in .char_result scratch
    ; (scratch needed because A cannot survive the PUSH/POP sequences
    ;  around tib_in updates — but main DE is pinned as IP the whole time)
    ...
    LD    A, (.char_result)
    LD    C, A
    LD    B, 0                       ; BC = new TOS
    CALL  rpop_de                    ; 3 bytes
    NEXT

.char_result: DB 0                   ; 1 byte scratch data
```

**EXX analysis:** After entry EXX, main DE is free scratch. The body's `tib_addr`/`tib_len` loads go into main DE freely, eliminating several of the `PUSH HL / PUSH BC` dances around the `tib_in` writes (which currently exist because there's no free register pair). The `.char_result` scratch may also be eliminable — the first-char byte can ride in main B or C between parse loops since BC is now fully scratch.

**Leaf-level:** No CALLs in the body — entirely inline parse loop and IY-relative loads.

**Conservative savings:**
- CALL rpush_de → EXX: −2 bytes
- CALL rpop_de → EXX: −2 bytes

**Optimistic savings:** additional 2–4 bytes from PUSH/POP elimination around tib_in updates, and potentially 1 byte data from `.char_result` elimination. **Total range: 4–8 bytes.**

**Risk:** Low. Similar structure to Epic 7's WORD conversion.

---

### A.2 — (ABORT") runtime (`src/system.asm:114`)

**Current shape:**
```
.paq_abort:
    ; Non-zero flag path: print string then JP ABORT
    CALL  rpush_de                   ; 3 bytes — save IP for BDOS safety
    LD    A, (DE)                    ; A = count
    INC   DE                         ; DE = string start
    OR    A
    JR    Z, .paq_do_abort
    LD    B, A
    LD    H, D
    LD    L, E
    CALL  bdos_print_str

.paq_do_abort:
    INC   IX                         ; 2 bytes — unwind rpush_de slot
    INC   IX                         ; 2 bytes
    JP    w_ABORT_cf                 ; never returns
```

**EXX analysis:** `bdos_print_str` does not use EXX (verified in Epic 7.3 task 1.2). ABORT resets SP and jumps into QUIT which explicitly reloads DE — shadow-register state is irrelevant after ABORT.

**Proposed shape:**
```
.paq_abort:
    EXX                              ; 1 byte — BC/DE/HL → shadows
    ; main BC/DE/HL now free scratch
    ; but we need the count and string address from DE' (shadow IP)
    EXX                              ; swap back to read (DE) — or restructure
    ...
```

Actually cleaner: keep DE in main set (since we need `LD A, (DE)` and `INC DE`), use EXX to park BC (the TOS for this runtime is garbage — runtime word, consumes flag). Wait — `(ABORT")` entry has already consumed the flag (see `.paq_skip`/`.paq_abort` branch at line 97). BC here holds whatever was under the flag on the param stack. So BC is actually user-data TOS.

**Refined proposal:** Since BDOS clobbers DE, and we need to preserve IP across `bdos_print_str`, and ABORT doesn't need shadow preservation:

```
.paq_abort:
    EXX                              ; 1 byte — DE=IP parked in DE'
    ; main registers free
    EXX                              ; 1 byte — swap back to read string
    ; ... nope, this doesn't work cleanly either
```

The genuinely correct path: extract count/string into registers **before** the EXX, then EXX, then BDOS-print from main HL/B, then JP ABORT. No exit EXX needed because ABORT wipes state.

```
.paq_abort:
    LD    A, (DE)                    ; A = count
    INC   DE                         ; DE = string start
    OR    A
    JR    Z, .paq_do_abort
    LD    B, A                       ; B = count
    LD    H, D
    LD    L, E                       ; HL = string addr
    EXX                              ; 1 byte — park main BC/DE/HL (though we don't need them back)
    ; Wait — EXX swapped HL=string and B=count away. Bug.
```

**Correct approach:** EXX BEFORE reading (DE), then main DE is free scratch, BUT we need to read the original DE=IP (now in DE'). Simplest:

```
.paq_abort:
    ; DE = IP = pointer to count byte
    PUSH  DE                         ; 1 byte — save IP on machine stack
    LD    A, (DE)
    INC   DE
    OR    A
    JR    Z, .paq_do_abort
    LD    B, A
    LD    H, D
    LD    L, E
    CALL  bdos_print_str             ; clobbers DE (but we PUSHed it)
.paq_do_abort:
    POP   DE                         ; 1 byte — restore IP (though ABORT ignores it)
    JP    w_ABORT_cf
```

This doesn't even need EXX — `PUSH DE / POP DE` on the machine stack is 2 bytes total vs current CALL rpush_de (3) + INC IX x2 (4) = 7 bytes. **−5 bytes, no EXX needed.** Actually, since ABORT doesn't care about DE, the POP DE is wasted; we can skip it and just unbalance the stack since ABORT resets SP too. **−6 bytes.**

But: does anything reach `.paq_abort` via fallthrough expecting DE to still point somewhere? No — it's a runtime word that goes straight to ABORT. Safe.

**Savings: ~5–6 bytes (PUSH DE path) or ~5 bytes (EXX path).** Either works; the PUSH DE path is simpler.

**Risk:** Low. ABORT path is cold and consequences of mis-state are caught by ABORT's reset.

---

### A.3 — CHAR + (ABORT") Category A Summary

| Word | Current | Proposed | Savings |
|------|---------|----------|---------|
| CHAR | 6 bytes | EXX pair | 4–8 bytes |
| (ABORT") | 7 bytes | PUSH DE pair (no EXX needed) | 5–6 bytes |
| **Total Category A** | | | **9–14 bytes** |

---

## Category B — Formatting Pipeline

The `.`, `U.`, `.R`, `.S` words and the shared `emit_unsigned`/`u_to_str`/`print_neg_prefix` helpers. Epic 7 declared these out of scope: "BC used for values, DE as scratch throughout the output chain — full restructure required." This survey re-examines that conclusion.

### B.1 — The Contract Problem

`emit_unsigned` expects `BC = value`. It calls `u_to_str` (which consumes BC, clobbers DE via `div_bc_by_e`), then `bdos_print_str` and `bdos_putchar` (clobber DE, AF). If the caller does `EXX` at entry:
- Main BC becomes garbage (what BC' held — irrelevant)
- `emit_unsigned` receives garbage in BC instead of the TOS value

This is the spec's concern. There are two ways out:

**Path 1 — PUSH BC / EXX / POP BC entry (Group A pattern from 7.3 MOVE):**
```
w_DOT_cf:
    CALL  check_underflow
    PUSH  BC                         ; 1 byte — push TOS to machine stack
    EXX                              ; 1 byte — IP parked in DE'
    POP   BC                         ; 1 byte — TOS back in main BC
    CALL  print_neg_prefix
    CALL  emit_unsigned
    EXX                              ; 1 byte — IP restored
    POP   BC                         ; unchanged
    NEXT
```

Current overhead: CALL rpush_de (3) + CALL rpop_de (3) = 6 bytes. Proposed: PUSH BC (1) + EXX (1) + POP BC (1) + EXX (1) = 4 bytes. **−2 bytes per word.**

Applied to DOT and U.: −4 bytes total. Underwhelming.

**Path 2 — Rewrite the helpers to operate in shadow register set:**

Change `u_to_str` / `emit_unsigned` / `print_neg_prefix` to read value from BC' instead of BC. This eliminates the need to preserve main BC in the callers. But it means the helpers can only be called from EXX-context (which is a significant convention shift — every caller must EXX first). And it breaks the leaf-level rule if any callee also uses EXX.

**Path 2 is probably too invasive for marginal gain.** The helpers are called from DOT, U., .R, .S, and potentially elsewhere; forcing all callers into EXX context would require auditing every call site and might not cleanly yield more bytes than Path 1.

### B.2 — Per-Word Analysis (Path 1)

#### DOT (`formatting.asm:132`)
- Current: CALL rpush_de + CALL rpop_de = 6 bytes
- Proposed: PUSH BC / EXX / POP BC + EXX = 4 bytes
- **Savings: 2 bytes**

#### U. (`formatting.asm:151`)
- Identical structure to DOT
- **Savings: 2 bytes**

#### .R (`formatting.asm:169`)
- Current: rpush_de (3) + rpush_bc (3) + INC IX×2 (4) + rpop_de (3) = 13 bytes save/restore
- Plus scratch `.dotr_neg` (1), `.dotr_str` (2), `.dotr_len` (1) = 4 bytes data
- Plus `LD C,(IX+0)/LD B,(IX+1)` (6 bytes) to recover width mid-body
- **Proposed restructure:** EXX at entry; main BC/DE/HL all free scratch; keep width in a register pair throughout (no return-stack stash); n popped directly into a main register pair (DE is free). This potentially eliminates the LDs recovering width from IX (6 bytes) and possibly the `.dotr_str/.dotr_len` memory spills if main HL can hold the string pointer across the pad loop.
- **Savings estimate: 8–14 bytes** (depends on whether scratch variables can be eliminated).

#### .S (`formatting.asm:265`)
- Current: rpush_de (3) + rpush_bc (3) + rpop_bc (3) + rpop_de (3) = 12 bytes save/restore
- **Key insight:** the rpush_bc is NOT save/restore — it deliberately parks TOS on the return stack so `.dots_print_tos` can later read it via `(IX+0)/(IX+1)`. With EXX, BC' holds the original TOS **automatically** — `.dots_print_tos` reads it via `EXX / LD B,B` (nop to verify) / `EXX` or more simply `EXX` before printing, run the print in the EXX'd state, `EXX` back.
- Proposed: EXX entry (1) + per-print-tos path adjustment + EXX exit (1).
- **Savings estimate: 8–12 bytes** (eliminates the IX-based TOS cache plus the rpop_bc).

### B.3 — Category B Summary

| Word | Path | Savings (conservative) | Savings (optimistic) |
|------|------|------------------------|----------------------|
| DOT | Path 1 | 2 | 2 |
| U. | Path 1 | 2 | 2 |
| .R | Path 1 + restructure | 8 | 14 |
| .S | Path 1 + eliminate IX-cache | 8 | 12 |
| **Total Category B** | | **20** | **30** |

**Risk:** DOT/U. are trivial. .R and .S require genuine restructuring of the body and scratch-variable analysis — moderate risk, similar profile to Epic 7.2 recognizer work.

---

## Category C — AF' / EX AF,AF' Opportunities

The `AF'` shadow register set is entirely unused. Survey of `PUSH AF / POP AF` pairs reveals 44 sites across the codebase, split by purpose:

### C.1 — Pair-Balanced Save/Restore (likely breakeven)

`PUSH AF` is 1 byte; `POP AF` is 1 byte; `EX AF,AF'` is 1 byte. Replacing `PUSH AF / (stuff) / POP AF` (2 bytes overhead) with `EX AF,AF' / (stuff) / EX AF,AF'` (2 bytes overhead) is **byte-neutral**. No savings on straight pairs.

Speed differs: PUSH+POP = 21 T-states, EX AF,AF' pair = 8 T-states. Not a size concern but flagged for completeness.

**Implication:** Simple PUSH AF/POP AF brackets are NOT worthwhile targets for size reduction.

### C.2 — A-Spilled-To-Memory Scratch (real opportunity)

Cases where A is stashed to a memory scratch byte because PUSH/POP stack manipulation would be awkward. Examples:

- `formatting.asm:80` — `.uts_count: DB 0` plus multiple `LD A, (.uts_count) / INC A / LD (.uts_count), A` sequences (7+ bytes each)
- `formatting.asm:250` — `.dotr_neg: DB 0` plus `LD A, 1 / LD (.dotr_neg), A` at line 185-186 (5 bytes) and later `LD A, (.dotr_neg) / OR A` test sites (4 bytes each)
- `strings.asm:255` — `.char_result: DB 0` (already flagged in A.1)

Each of these could potentially migrate to AF' (via `EX AF,AF'` park), though A-as-counter patterns don't cleanly translate because the counter needs to survive arbitrary main-set operations and EX AF,AF' only preserves across single instructions unless nothing else needs AF.

**Conservative estimate:** AF' can save bytes where an A-value must survive a subroutine call (alternative to PUSH AF/POP AF around the call) **only if a register-level reorganisation is done**, which is closer to a rewrite than a drop-in replacement.

**Estimate: 0–10 bytes** across the whole codebase, high analysis effort, low yield per byte.

### C.3 — Interaction with EXX

`EX AF,AF'` and `EXX` are independent — they swap different register banks. A word could use both: `EXX` parks BC/DE/HL, `EX AF,AF'` parks AF. Current EXX-using words (Epic 7) already rely on "A survives EXX"; adding AF' to the repertoire would let a word also park the original flags/A across the EXX region. No current word appears to need this.

### C.4 — Category C Recommendation

**Defer AF'/EX AF,AF' optimisation.** The yield is marginal (estimate 0–10 bytes) and the analysis cost is higher than Category A or B. If Epic 8 lands with Categories A and B and the project lead still wants more squeeze, a follow-up story could audit `.uts_count` and `.dotr_neg`-style scratches specifically. Otherwise leave AF' as documented dormant capacity.

---

## Category D — NOT Candidates (Justified Exclusions)

| Site | Reason |
|------|--------|
| DOCOL (inner_interpreter.asm:101-102) | Hot path — already optimised inline; EXX would add 1 byte of permanent overhead per DOCOL invocation |
| EXIT (inner_interpreter.asm:124) | The `CALL rpop_de` IS the EXIT primitive (pops IP from R-stack). EXX cannot replace this — it doesn't pop IX |
| (DOES>) runtime (compiler.asm:689) | Same as EXIT — the final `CALL rpop_de` is a functional EXIT, not save/restore |
| (DO) runtime (control_flow.asm:207) | `CALL rpush_bc` here is a functional PUSH to the return stack (pushes loop index). EXX doesn't modify IX |
| INTERPRET (outer_interpreter.asm:99-127) | The main thread entry. Converting to EXX would make every word in the interpreter loop run in shadow-context, violating the leaf-level rule repo-wide |

---

## Savings Summary

| Category | Stories | Conservative | Optimistic | Risk |
|----------|---------|--------------|------------|------|
| A — CHAR + (ABORT") | 1 story (~2 words) | 9 bytes | 14 bytes | Low |
| B — Formatting pipeline | 1–2 stories (4 words) | 20 bytes | 30 bytes | Medium |
| C — AF' survey | deferred | 0 | ~10 | Low yield, high effort |
| **Total Epic 8 target** | | **~29 bytes** | **~44 bytes** | |

Combined post-Epic 8 projection: 14,105 → ~14,060–14,075 bytes. Combined Epic 6+7+8: ~1,445–1,460 bytes total (~9.4% of original 15,519 baseline).

**Reality check:** Each successive optimisation epic yields diminishing returns — Epic 6 saved 1,034 bytes, Epic 7 saved 208 bytes, Epic 8 projects ~30–45 bytes. This is the natural shape of mining a vein. The question is whether ~35 bytes justifies a focused epic or should be folded into a larger "continued optimisation" epic alongside unrelated work.

---

## Recommended Epic 8 Decomposition

**Option 1 — Tight, focused epic (3 stories):**
- **Story 8.1** — Category A: CHAR + (ABORT") EXX conversion. Mechanical, low risk, ~10 bytes. (Establishes momentum; same conversion pattern as Epic 7.3.)
- **Story 8.2** — Category B trivial: DOT + U. `PUSH BC / EXX / POP BC` conversion. ~4 bytes, low risk.
- **Story 8.3** — Category B restructure: .R + .S rewrite with EXX-enabled register freedom and scratch-variable elimination. ~16–26 bytes, medium risk, highest per-story payoff.

**Option 2 — Minimum viable epic (2 stories):**
- Merge 8.1 and 8.2 into a single "mechanical EXX completion" story (~14 bytes).
- Standalone 8.2: .R + .S restructure (~16–26 bytes).

**Option 3 — Defer:**
- Fold these ~30–45 bytes into a future mixed epic when new feature work is also on the table. Refactor-only epics have diminishing hook for retrospection discipline.

**Recommendation: Option 1.** Three clean stories, each with a clear target. 8.1 is Epic 7 aftermath cleanup. 8.2 is the easy formatting wins. 8.3 is the genuine restructure work. Each story delivers a measurable binary reduction and all follow the established EXX convention. Consistent with Epic 6/7 cadence.

---

## Convention Documentation Gap

Epic 7 established the EXX leaf-level rule, the "A survives EXX" exit-staging idiom, and "shadow BC' as free TOS-preservation slot." These are currently documented only in individual story Dev Notes. Before Epic 8 starts, consider promoting them to a central reference (candidates: `docs/register-conventions.md`, an `EXX` section in an existing doc, or inline in a top-of-file comment block in `inner_interpreter.asm`). This was flagged as Epic 7 retro action item #5.

---

## Files Referenced

- `src/inner_interpreter.asm` — DOCOL, EXIT, rpush/rpop primitives (reference, NOT modified in Epic 8)
- `src/strings.asm` — CHAR (candidate A.1)
- `src/system.asm` — (ABORT") runtime (candidate A.2)
- `src/formatting.asm` — DOT, U., .R, .S, emit_unsigned, u_to_str, print_neg_prefix (Category B targets)
- `src/compiler.asm` — (DOES>) runtime (excluded, Category D)
- `src/control_flow.asm` — (DO) runtime (excluded, Category D)
- `src/outer_interpreter.asm` — INTERPRET main loop (excluded, Category D)
