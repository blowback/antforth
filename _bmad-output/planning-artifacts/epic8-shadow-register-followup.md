# Epic 8: Shadow Register Follow-Up

## Context

AntForth's binary stands at **14,105 bytes** after Epic 7's shadow register optimisation (208 bytes saved across 3 stories). Epic 7 established the EXX convention across 13 words but explicitly deferred the formatting pipeline and left a handful of non-formatting `CALL rpush_de` / `CALL rpop_de` sites unconverted. The shadow register survey at `docs/shadow-register-followup-survey.md` enumerates every remaining site, categorises each by feasibility, and projects **~30–45 bytes** of additional savings.

This epic completes the EXX conversion for the two remaining simple candidates (CHAR and `(ABORT")`) and tackles the formatting pipeline (., U., .R, .S) that Epic 7 declared out of scope. It also promotes the EXX conventions established across Epic 7 into a central reference document.

**Target: ~30–45 bytes saved** (~0.2–0.3% of binary). Diminishing returns are expected and accepted — this epic closes out the shadow-register vein rather than opening new ground.

**Safety basis:** unchanged from Epic 7 — CP/M 2.2 BDOS does not touch shadow registers, AntForth has no interrupt handlers, `bdos_print_str`/`bdos_putchar`/`BDOS_ENTRY`/`do_number` are all verified EXX-free. The new helpers to audit are `emit_unsigned`, `u_to_str`, `print_neg_prefix`, `div_bc_by_e`, `digit_to_char` — all confirmed EXX-free by code inspection (none contain `EXX` or `EX AF,AF'`).

**Convention:** unchanged from Epic 7 — EXX is a leaf-level technique; a word using EXX must not call any subroutine that also uses EXX. The formatting helpers (`emit_unsigned` et al.) remain non-EXX so they can continue to be called from EXX-using words.

**Build/test:** `make asm` assembles with sjasmplus; `make test && make test-repl` runs all 265 regression tests.

---

## Story 8.1: EXX for CHAR and (ABORT") Runtime

**Savings: ~10–14 bytes | Risk: Low | Effort: Low**

Two remaining non-formatting save/restore sites that Epic 7 didn't cover. Both fit the Epic 7 Group A pattern ("TOS consumed early or irrelevant by exit").

### CHAR (`src/strings.asm:160`)

`CHAR` parses the next space-delimited token from TIB and pushes the first character's ASCII value. It currently uses `PUSH BC / CALL rpush_de` at entry and `CALL rpop_de` at exit, with a 1-byte `.char_result` scratch to carry the parsed character across `PUSH/POP HL/BC` sequences inside the parse loop.

**Conversion pattern:**
- Entry: `PUSH BC / EXX` (preserves old TOS via machine stack for later `POP BC`; EXX parks IP in DE')
- Body: main BC/DE/HL all free scratch — eliminates most PUSH/POP dances around `tib_in` updates
- Exit: `EXX / POP BC` — IP restored from DE', new TOS popped from machine stack

**Second-order savings opportunity:** the `.char_result` scratch byte can potentially be eliminated — with main BC free, the parsed character can ride in a main register through the `.char_scan` advance loop.

### (ABORT") Runtime (`src/system.asm:114`)

`(ABORT")` runtime prints a string then jumps to ABORT. It currently does `CALL rpush_de` (3 bytes) at entry and `INC IX / INC IX` (4 bytes) at exit to undo the rpush — purely for BDOS safety.

**Key insight:** since `JP w_ABORT_cf` resets SP wholesale (via `LD SP, (sp_base)`), the save/restore can be replaced with a bare `PUSH DE` on the machine stack with NO matching POP. The unbalanced stack is irrelevant — ABORT wipes it.

**Conversion:**
- Replace `CALL rpush_de` with `PUSH DE` (1 byte entry)
- Remove `INC IX / INC IX` entirely (0 bytes exit)
- No EXX needed

**Savings: 6 bytes** (7→1) with no EXX involvement.

### Byte Budget

| Word | Current | New | Savings |
|------|---------|-----|---------|
| CHAR entry/exit | 6 | 4 (PUSH BC + EXX + EXX + POP BC — net 2 bytes save/restore) | 2 |
| CHAR `.char_result` elimination | 1 data + load/store overhead | 0 | 2–6 |
| (ABORT") rpush+INC IX | 7 | 1 (PUSH DE) | 6 |
| **Total** | | | **10–14 bytes** |

### Risk

Low. CHAR conversion mirrors Epic 7.3 WORD. (ABORT") requires verifying that nothing else branches into `.paq_abort` expecting the return stack to be pristine — code inspection shows only the single `JR NZ, .paq_abort` fall-through from the flag check, so the stack-unbalance-before-ABORT pattern is safe.

---

## Story 8.2: EXX for DOT and U.

**Savings: ~4 bytes | Risk: Low | Effort: Low**

The two simplest formatting words. Both currently use `CALL rpush_de` / `CALL rpop_de` around a call to `emit_unsigned` (and `print_neg_prefix` for DOT). `emit_unsigned` expects `BC = value`, which means naive `EXX` at entry would clobber the value — the converter must use the Group A pattern from Epic 7.3 MOVE.

### Conversion Pattern

```asm
w_DOT_cf:
    CALL    check_underflow
    PUSH    BC                  ; save TOS to machine stack
    EXX                         ; park IP in DE'
    POP     BC                  ; recover TOS into main BC (for emit_unsigned)
    CALL    print_neg_prefix
    CALL    emit_unsigned
    EXX                         ; restore IP from DE'
    POP     BC                  ; new TOS from param stack
    NEXT
```

Current: `CALL rpush_de` (3) + `CALL rpop_de` (3) = 6 bytes.
New: `PUSH BC / EXX / POP BC / EXX` = 4 bytes.
**Savings: 2 bytes per word × 2 words = 4 bytes.**

### Leaf-Level Audit

The body calls `check_underflow`, `print_neg_prefix`, `emit_unsigned` (which calls `u_to_str`, `bdos_print_str`, `bdos_putchar`). All verified EXX-free:
- `u_to_str`, `div_bc_by_e`, `digit_to_char`, `print_neg_prefix` — inspect source, no `EXX`
- `bdos_print_str`, `bdos_putchar`, `BDOS_ENTRY` — verified in Epic 7.3 Task 1.2
- `check_underflow` — simple SP comparison, no EXX

### Risk

Low. Mechanical substitution. The `PUSH BC / EXX / POP BC` entry pattern is already proven in Epic 7.3 MOVE.

---

## Story 8.3: Restructure .R and .S

**Savings: ~16–26 bytes | Risk: Medium | Effort: Medium**

The largest Epic 8 payoff. Both words currently use multiple rpush/rpop calls plus memory scratch variables to compensate for register pressure. EXX liberates main BC/DE/HL as a full scratch set, enabling significant restructuring.

### .R (`formatting.asm:169`)

**Current overhead:**
- `CALL rpush_de` (3) + `CALL rpush_bc` (3) at entry to save IP and width
- `LD C, (IX+0) / LD B, (IX+1)` (6) mid-body to recover width from return stack
- `INC IX / INC IX` (2) + `CALL rpop_de` (3) at exit to unwind and restore IP
- Memory scratch: `.dotr_neg` (1), `.dotr_str` (2), `.dotr_len` (1) = 4 bytes data

**Proposed structure:**
- Entry: `PUSH BC / EXX / POP BC` (3 bytes) — width in main BC, IP parked in DE'
- `POP DE` for n (main DE is free — no IX stash needed)
- Sign handling in main registers; `.dotr_neg` may be replaceable with a single-register flag
- `u_to_str` called normally (BC = value)
- Width remains live in a main register across the pad loop — no `(IX+0)` recovery needed
- `.dotr_str / .dotr_len` may be eliminable if HL can hold the string pointer across the pad loop (the pad loop currently uses `PUSH BC / LD E, ' ' / CALL bdos_putchar / POP BC / DJNZ` which preserves main BC — HL should survive the same way if saved across the one `CALL bdos_putchar` per iteration)
- Exit: `EXX` (1) + `POP BC` (1)

**Savings estimate:** 8–14 bytes depending on how many of the three scratch variables fall out.

### .S (`formatting.asm:265`)

**Current overhead:**
- `CALL rpush_de` (3) + `CALL rpush_bc` (3) at entry
- `.dots_print_tos` reads original TOS via `LD B, (IX+1) / LD C, (IX+0)` (6 bytes)
- `CALL rpop_bc` (3) + `CALL rpop_de` (3) at exit

**Key insight:** the `rpush_bc` at entry is NOT save/restore — it's a functional cache so `.dots_print_tos` can read the original TOS. With EXX, BC' holds the original TOS automatically. The `.dots_print_tos` label can read it via `EXX / (print BC) / EXX` or by staging through a scratch variable.

**Proposed structure:**
- Entry: `EXX` (1) — BC' = original TOS, DE' = IP
- Body: `.dots_walk` loop prints stack items using main BC (free) and memory `.dots_depth/.dots_addr/.dots_remaining` (unchanged)
- `.dots_print_tos`: to print the original TOS, either `EXX` into the shadow context and call the print pipeline (but print pipeline uses EXX? no — `emit_unsigned` et al. are EXX-free), OR `EXX / LD H,B / LD L,C / EXX / LD B,H / LD C,L` (costs a few bytes but brings TOS into main BC). The cleanest approach is likely a single EXX-swap at the start of `.dots_print_tos` and an EXX back after.
- Exit: `EXX` (1)

**Savings estimate:** 8–12 bytes (entry 5 bytes → 1, exit 6 bytes → 1, plus the IX-based TOS cache read replaced by shadow access).

### Byte Budget

| Change | Conservative | Optimistic |
|--------|--------------|------------|
| .R entry/exit/IX-recovery replacement | 6 | 8 |
| .R scratch-variable elimination | 2 | 6 |
| .S entry/exit replacement | 4 | 6 |
| .S IX-based TOS cache → shadow BC' | 4 | 6 |
| **Total** | **16** | **26** |

### Risk

Medium. The `.S` print-TOS path requires careful thought about which register set the print helpers run in — they are EXX-free, so they work in whichever set is currently "main." The `.R` pad/print loops have several `PUSH BC / CALL bdos_putchar / POP BC` sequences; these must still preserve main BC correctly after the restructure. Full regression suite (`make test-repl`) is the safety net.

---

## Story 8.4: Promote EXX Conventions to Central Reference (Documentation)

**Savings: 0 bytes | Risk: None | Effort: Low**

Epic 7 retro action item #5: promote the shadow-register conventions from scattered story Dev Notes into a single authoritative reference. Currently, the EXX leaf-level rule, "A survives EXX" staging idiom, and "shadow BC' as free TOS-preservation slot" pattern are documented only in individual 7.1/7.2/7.3 story files.

**Deliverable:** a new section or top-of-file block (candidate locations: `docs/register-conventions.md` as a new doc, or an expanded comment header in `src/inner_interpreter.asm` alongside the existing register contract) covering:

1. **Register contract** (BC=TOS, DE=IP, IX=R-stack, IY=user area, HL/AF=scratch) — already documented, restate for completeness
2. **Shadow register convention** — BC'/DE'/HL' available via EXX; AF' available via EX AF,AF' (unused)
3. **Leaf-level rule** — EXX-using words may not call EXX-using subroutines; current EXX-using word list (will be 15–17 by end of Epic 8)
4. **Exit-staging idiom** — stage new TOS through A (survives EXX), rebuild BC after exit EXX
5. **Shadow BC' as TOS-preservation slot** — for `( x -- ... )` words that need original x on one exit path
6. **Group A vs Group B patterns** — TOS consumed early (plain EXX) vs TOS needed throughout (PUSH BC / EXX / POP BC)

**Risk:** None. Pure documentation. No code changes, no tests affected.

---

## Story Ordering and Dependencies

```
8.1 (CHAR + ABORT")     ──> mechanical cleanup, extends Epic 7 pattern
8.2 (DOT + U.)          ──> mechanical, proves Path 1 (PUSH BC / EXX / POP BC) for formatting
8.3 (.R + .S restructure) ──> largest payoff, depends on 8.2 proving Path 1 on formatting helpers
8.4 (convention doc)    ──> can run in parallel with any of 8.1-8.3; recommended last so list of EXX-using words is final
```

Stories 8.1 and 8.2 are independent and either may land first. Story 8.3 should follow 8.2 (shares the Path 1 pattern). Story 8.4 ideally lands last so the convention doc captures the final state.

## Savings Summary

| Story | Savings (conservative) | Savings (optimistic) | Risk | Cumulative (conservative) |
|-------|------------------------|----------------------|------|---------------------------|
| 8.1 CHAR + (ABORT") | 10 | 14 | Low | 10 |
| 8.2 DOT + U. | 4 | 4 | Low | 14 |
| 8.3 .R + .S | 16 | 26 | Medium | 30 |
| 8.4 Convention doc | 0 | 0 | None | 30 |
| **Total** | **30** | **44** | | **~30–44 bytes** |

Combined Epic 6+7+8 projection: 15,519 → ~14,060–14,075 = **~1,445–1,460 bytes total optimisation** (~9.4% of original).

## Verification Strategy

1. **Before epic:** `wc -c build/antforth.com` = 14,105 bytes (baseline)
2. **After each story:** record binary size, verify delta matches estimate
3. **Regression:** `make test && make test-repl` — all 265 tests green after every story
4. **Manual hardware test:** Verify on MicroBeast after each story (EXX correctness on real CP/M)
5. **Code review:** per Epic 6/7 precedent, every story gets an adversarial code review — shadow-register interactions remain a register-contract bug-risk area

## Key Files

- `src/strings.asm` — CHAR (8.1)
- `src/system.asm` — (ABORT") runtime (8.1)
- `src/formatting.asm` — DOT, U., .R, .S, emit_unsigned, u_to_str, print_neg_prefix (8.2, 8.3)
- `src/inner_interpreter.asm` — rpush_de/rpop_de (reference, NOT modified; convention doc candidate host 8.4)
- `docs/shadow-register-followup-survey.md` — authoritative survey behind this epic
- `docs/register-conventions.md` (new, 8.4) or equivalent location

## Out of Scope

- **AF' / EX AF,AF' optimisation** — survey concluded byte-neutral in simple PUSH AF/POP AF pairs; marginal yield from scratch-variable migrations (0–10 bytes for high analysis cost). Deferred pending project-lead judgment call after 8.1–8.3 land.
- **DOCOL, EXIT, (DOES>), (DO), INTERPRET** — category D exclusions documented in the survey (hot paths or functional R-stack manipulation).
- **`.word_delim` scratch elimination in WORD** — 1-byte opportunity noted in Epic 7.3 Task 6.3 as "out-of-scope optimisation"; remains out of scope here (not a shadow-register matter).
