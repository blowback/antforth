# Story 10.7: Pictured numeric output primitives (`<#`, `#`, `#S`, `#>`, `HOLD`, `SIGN`, `HOLDS`)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want the ANS pictured-numeric-output wordset so I can build formatted number strings,
so that I can author custom display formats (leading zeroes, field padding, currency, dotted-decimal, etc.) and so Story 10.8's Core number-display family (`.`, `U.`, `D.`, `.R`, `U.R`, `D.R`) can be rebuilt on a standards-compliant foundation — turning the §6.1 Numeric-Output sub-category from 4 / 10 (40%) to 10 / 10 (100%).

## Acceptance Criteria

1. **Given** architecture decision E10-D2 (`architecture.md:254-258`) — a dedicated 40-byte buffer in the user area, IY-relative, addressed via a USER variable `HLD`, reset by `<#` to the buffer's high end and decremented-then-written by `#` / `#S` / `HOLD` / `SIGN` / `HOLDS` — **When** the pictured-output primitives are added, **Then** the USER variable `HLD` and a 40-byte pictured-output buffer `pic_buf` (length `PIC_BUF_SIZE EQU 40`) are added to the `UserArea` struct in `src/structures.asm`. `HLD` holds an absolute pointer to the next write slot (**not** an offset); `pic_buf` occupies 40 contiguous bytes immediately after `HLD` in the struct. The buffer's end sentinel — the address one past the last byte — equals `IY + UserArea.pic_buf + PIC_BUF_SIZE` and is what `<#` loads into `HLD`. **The buffer must be placed so it does not collide with the TIB, `num_buf`, or `bdos_input_buf` regions** (architecture note: pictured output buffer is per-task when multitasking lands post-2.0; keeping it inside `UserArea` preserves that invariant).

2. **Given** DPANS94 §6.1.0490 `<# ( -- )` **When** `<#` is invoked, **Then** `HLD` is reset to `IY + UserArea.pic_buf + PIC_BUF_SIZE` (the byte just past the buffer's high end). No other state changes. Implementation-defined contents of any prior pictured-output invocation are discarded. **Verify §-number against DPANS94 / forth-standard.org at implementation time** (per `feedback_systematic_reference_check.md`).

3. **Given** DPANS94 §6.1.0030 `# ( ud1 -- ud2 )` — divide `ud1` by the current `BASE`, convert the remainder (0..35) to its ASCII digit character (`'0'..'9'`, `'A'..`), call `HOLD` on that character, leave `ud2 = ud1 / BASE` on the stack — **When** `#` is invoked, **Then** the implementation uses `UM/MOD` (Story 10.6, DPANS94 §6.1.2370) + `BASE @` for the division step; the remainder is converted via the existing `digit_to_char` helper at `src/formatting.asm:11` (reused, not duplicated); `HOLD` writes the character into `pic_buf`. Input `ud1` is a **double-cell unsigned** value (low cell on TOS per E10-D1); output `ud2` keeps the same convention. `BASE` is not mutated (FR9 discipline, same as Epic-9). **Correctness spot:** with `BASE = 10` and `ud1 = 123. 0.` (i.e., stacked as `123 0`), `#` leaves `ud2 = 12. 0.` and `HLD` decrements by one pointing at `'3'`.

4. **Given** DPANS94 §6.1.0050 `#S ( ud1 -- ud2 )` — loop `#` until `ud` becomes `0 0` — **When** `#S` is invoked, **Then** it calls `#` at least once (so `0. 0. #S` still emits one `'0'` digit per the standard's "until both cells of `ud` are zero" wording) and repeats until the double on the stack is `0 0`. Output `ud2` is always `0 0`.

5. **Given** DPANS94 §6.1.1670 `HOLD ( char -- )` — insert `char` into the pictured-output buffer — **When** `HOLD` is invoked, **Then** `HLD` is decremented by 1, and the low byte of TOS (`char`) is stored at the new `HLD` address. An **overflow guard** prevents `HLD` from moving below `IY + UserArea.pic_buf`: if the decrement would underflow, the word must behave predictably — antforth's convention for Story 10.7 is to **treat underflow as an ABORT via `do_pic_overflow_error` (new diagnostic: `? Pictured buffer overflow`)** matching the pre-Epic-11 discipline for unrecoverable buffer conditions. Epic 11 Story 11.4/11.6 will migrate this to `THROW -17` (DPANS94 §9.3.5 "pictured numeric output string overflow"). **Do NOT pre-migrate to THROW.** The overflow diagnostic is reached only if a user hand-builds a pictured output longer than 40 chars; the 20-digit worst case (AC #8) does not hit it.

6. **Given** DPANS94 §6.1.2210 `SIGN ( n -- )` — if `n` is negative, insert `'-'` into the pictured-output buffer — **When** `SIGN` is invoked, **Then** if the bit-15 of TOS is 1, `HOLD '-'` executes; otherwise the character is discarded without writing. `n` is consumed in both cases. Implementation should be a thin DEFWORD wrapper (`DUP 0< IF LIT '-' HOLD ELSE DROP THEN`) per E10-D3 (thin wrappers permitted as threaded Forth).

7. **Given** DPANS94 §6.1.0040 `#> ( xd -- c-addr u )` — discard the double-cell `xd`, return the pictured-output string's start address and length — **When** `#>` is invoked, **Then** the double-cell `xd` is dropped from the stack; `c-addr` becomes the current `HLD` value; `u` becomes `(IY + UserArea.pic_buf + PIC_BUF_SIZE) - HLD` (the byte count between `HLD` and the buffer's end). The returned region is valid until the next `<#` invocation (ANS permits the implementation to reuse the buffer; no multi-use guarantees). Stack effect: `( xd -- c-addr u )` — two cells in, two cells out, net zero cell-count change.

8. **Given** the 40-byte buffer size (`PIC_BUF_SIZE EQU 40`), **When** the longest plausible pictured output is formatted, **Then** no overflow occurs. Worst cases to verify:
    - **Base-2 double-cell unsigned maximum** = `$FFFFFFFF` = `11111111_11111111_11111111_11111111` (32 chars) plus a leading `'-'` via `SIGN` if we pretended it's signed (not a real input, but exercises the path) = 33 chars ≤ 40.
    - **Base-10 double-cell unsigned maximum** = `4294967295` = 10 chars; plus leading `-` if signed = 11 chars; **20-digit case** (`-9999999999999999999` if someone pictured a fake high-double prefix) is 20 chars — the epic-spec's "20 digits + sign + radix" guidance is a generous upper bound, not a tight worst case.
    - **Base-16 double-cell unsigned maximum** = `FFFFFFFF` = 8 chars + sign = 9.
    - **Worst hand-crafted case:** dev builds a formatted output with `#S` then inserts `HOLDS` with a long decorator string (currency symbols, formatting separators). A test must exercise at least one case within 1 char of the buffer limit (i.e., 39 chars) **without** overflow and at least one that overflows with `HOLD` **producing the diagnostic** (AC #5).
    - Test cases must cover base 2, 10, and 16 plus at least one user-defined-base case (e.g., base 8 or base 36).

9. **Given** DPANS94 §6.2 Core Extension / Forth-2014 `HOLDS ( c-addr u -- )` §6.2.1675 — insert a counted string into the pictured-output buffer, preserving the string's left-to-right order in the final output — **When** `HOLDS` is invoked, **Then** the implementation inserts the string's **last character first** (moving backward through `c-addr..c-addr+u-1`) so that the leftmost character of the string appears leftmost in the pictured output. Reference ANS implementation: `BEGIN DUP WHILE 1- 2DUP + C@ HOLD REPEAT 2DROP`. `HOLDS` consumes zero pictured-output buffer space when `u = 0` and does not advance `HLD`. **Verify §6.2.1675 at implementation time** (per `feedback_systematic_reference_check.md`; epic spec says "§6.2.1625", but Story 10.1 established §6.2.1675 as the correct DPANS94 / Forth-2012 number — match the refreshed compliance doc).

10. **Given** the BC-as-TOS convention (`project_tos_in_register.md`) and the DE=IP discipline, **When** each of `<#`, `#`, `#S`, `#>`, `HOLD`, `SIGN`, `HOLDS` is implemented, **Then** on entry BC holds the per-word TOS cell and on exit BC holds the per-word TOS cell as specified. `DE = IP` is preserved across every word — DEFCODE primitives use a local memory stash (either the existing `double_ip_stash` at `src/double.asm:724` **or** a new `pictured_ip_stash` cell at the tail of `src/pictured.asm` — dev's choice, but **if reusing `double_ip_stash` the reuse must be documented** per the `never held across NEXT; never re-entered` invariant in `src/double.asm:720-724`). DEFWORD wrappers (`SIGN`, `HOLDS`, optionally `#S`) inherit DE-preservation automatically through threaded-code discipline. **Shadow-register (EXX) usage** is permitted where it simplifies register pressure — e.g., `.` at `formatting.asm:136-147` parks IP in DE' and processes in main BC; the same pattern is available to `#` / `#>` if needed.

11. **Given** stack-underflow discipline (Stories 10.2 / 10.3 convention — `check_underflow_N` counts total user items **including** BC), **When** each pictured-output word is invoked with insufficient depth, **Then** it uses the matching helper:

    | Word | Cells consumed | Helper |
    |---|---|---|
    | `<#` | 0 | none (no underflow possible) |
    | `#` | 2 (`ud-hi` + `ud-lo`) | `check_underflow_2` |
    | `#S` | 2 (`ud-hi` + `ud-lo`) | `check_underflow_2` (or inherit via `(?2)` — see below) |
    | `#>` | 2 (`xd-hi` + `xd-lo`) | `check_underflow_2` |
    | `HOLD` | 1 (`char`) | `check_underflow` (1-cell helper) |
    | `SIGN` | 1 (`n`) | `check_underflow` (1-cell helper) |
    | `HOLDS` | 2 (`c-addr` + `u`) | `check_underflow_2` (or inherit via `(?2)`) |

    No new helpers needed; the existing `check_underflow` / `check_underflow_2` / `check_underflow_3` suite (`src/system.asm:278-362`) already covers all cases. Pre-Epic-11 behaviour (ABORT + stack-underflow diagnostic + REPL recovery) is preserved bit-identically. Epic 11 Story 11.4 will migrate to `THROW -4` wholesale — **do NOT pre-migrate**. For DEFWORD words whose first body word does not reach the needed N (as Story 10.6 encountered), prepend the existing `(?3)` guard (`src/double.asm:612`) or, if a 2-cell guard is needed and no natural first word provides it, add a `(?2)` guard DEFCODE following the `(?3)` precedent at `src/double.asm:603-616`. **Recommendation: only add `(?2)` if at least two DEFWORDs in this story need it; otherwise inline the underflow call in each DEFCODE and let DEFWORDs inherit via a naturally-underflow-2-guarded first word (e.g., `DUP` is 1-cell; `OVER` is 2-cell — use `OVER` first where the body allows).**

12. **Given** architecture decision E10-D3 (`architecture.md:260-264`) and the source-file organisation table (`architecture.md:438-446`), **When** the seven new words are implemented, **Then** they **all land in a new source file `src/pictured.asm`** (not in `src/double.asm` — architecture table line 442 makes `pictured.asm` a dedicated Epic-10 file) appended to the assembly order in `src/antforth.asm` **immediately after `double.asm` and before `control_flow.asm`** (section `; === CODE primitives ===` at `src/antforth.asm:121-131`). Suggested source ordering within `pictured.asm`:

    - `<#` (DEFCODE) — zero-cell primitive; tiny (6 lines of Z80)
    - `HOLD` (DEFCODE) — tiny; the fundamental buffer-decrement-and-store primitive
    - `#` (DEFCODE) — hot primitive: invokes `UM/MOD` + `digit_to_char` + HOLD semantics inline for speed
    - `#S` (DEFWORD) — thin loop-until-`ud`-is-zero wrapper over `#`
    - `#>` (DEFCODE) — zero-cell-count-change primitive; tiny
    - `SIGN` (DEFWORD) — thin `DUP 0< IF LIT '-' HOLD ELSE DROP THEN` wrapper
    - `HOLDS` (DEFWORD) — canonical `BEGIN DUP WHILE 1- 2DUP + C@ HOLD REPEAT 2DROP` body

    `HLD` itself is **exposed as a DEFCODE user-variable word** (same template as `BASE` at `src/outer_interpreter.asm:35-39`) so that power users and debugging tools can inspect / set the pictured-output cursor. This is an antforth extension — DPANS94 does not require `HLD` to be a user-facing word (it's an ambiguous internal for many Forths) but Gforth, SwiftForth, and most modern Forths expose it. Cost: ~4 bytes of dictionary header + 4 bytes of code. Add a CCD-3-style comment tagging it `; antforth extension — HLD exposed as user variable (ANS HLD is ambiguous; we follow Gforth/SwiftForth precedent)`.

13. **Given** CCD-3 Standards-Citation Discipline (`architecture.md:206-216`, NFR17 at `prd.md:478`) and the format template established by Stories 10.2 / 10.3 / 10.4 / 10.5 / 10.6, **When** each word is implemented, **Then** its implementation carries (a) the one-line §-citation comment in the established template format and (b) a stack-effect comment on the header line. **§-numbers are verified against DPANS94 / forth-standard.org at implementation time** (per `feedback_systematic_reference_check.md`; epic spec's §6.2.1625 for `HOLDS` is a typo — Story 10.1 established §6.2.1675 as correct; verify against the compliance doc as tiebreaker). Expected numbers to verify (write-time re-check non-negotiable):

    | Word | Expected § |
    |---|---|
    | `<#` | DPANS94 §6.1.0490 |
    | `#` | DPANS94 §6.1.0030 |
    | `#>` | DPANS94 §6.1.0040 |
    | `#S` | DPANS94 §6.1.0050 |
    | `HOLD` | DPANS94 §6.1.1670 |
    | `SIGN` | DPANS94 §6.1.2210 |
    | `HOLDS` | Forth-2012/2014 §6.2.1675 |

14. **Given** the REPL-test-preferred discipline (project memory `feedback_repl_tests_preferred.md`, NFR16 at `prd.md:477`), **When** tests are written, **Then** a **new test file** `tests/pictured_tests.fth` is created with a per-word section for the seven primitives plus a "worst-case coverage" section and an "underflow recovery" section. The file follows the `tests/double_tests.fth` conventions: top-of-file banner, one section header per family (`\ === Story 10.7 <topic> ===`), per-word sub-headers with §-number cite, one-line Forth expressions each terminated by `\ expect: <fragment>`. Counterpart `test-repl` entries are appended to `Makefile` — new numbering starts at **550** (Story 10.6 closed at 549 per `Makefile:4769-4776`). Each new `.fth` scenario has a matching Makefile entry using the canonical `printf … | $(IZCPM) $(TARGET) | grep -q` template from Story 10.6 tests 526..549. Escape `$`-prefixed hex literals in shell banners as `$$` (Story 10.4 / 10.5 discipline); use `printf --` for any input whose first token starts with `-`.

15. **Given** coverage must exhaust ACs #1–#9 plus AC #8's worst-case matrix and AC #11's underflow discipline, **When** `make test-repl` runs, **Then** the new test block covers at minimum (final count is dev's choice; numbering suggested starting at 550):

    **Core primitives — basic functionality:**
    - `BASE @ >R DECIMAL 123 0 <# #S #> TYPE R> BASE !` → `123` (double `123 0` printed, BASE restored)
    - `BASE @ >R DECIMAL 12345 0 <# # # # # # #> TYPE R> BASE !` → `12345` (fixed-width five-digit output)
    - `BASE @ >R DECIMAL 0 0 <# #S #> TYPE R> BASE !` → `0` (AC #4: `#S` emits at least one digit even for `0 0`)
    - Underlying `<# #>` round-trip with zero-length output (never a problem — `<# #>` with no `#` between yields an empty string and `u = 0`)

    **Base-switching coverage (AC #8):**
    - Base 10 (default): `65535 0 <# #S #> TYPE` → `65535`
    - Base 16 / `HEX`: `65535 0 <# #S #> TYPE` → `FFFF`
    - Base 2: `2 BASE ! 255 0 <# #S #> TYPE DECIMAL` → `11111111`
    - Base 8: `8 BASE ! 511 0 <# #S #> TYPE DECIMAL` → `777`
    - Base 36: `36 BASE ! 35 0 <# #S #> TYPE DECIMAL` → `Z` (digit past `'9'` verifies `digit_to_char`'s `A-Z` branch)

    **Sign handling (AC #6):**
    - `-1 DUP ABS S>D <# #S ROT SIGN #> TYPE` → `-1` (classical DPANS94 §A.6.1.2210 example adapted for single-cell `-1`; uses `DABS` for doubles — simplify using `SWAP OVER DABS <# #S ROT SIGN #> TYPE`, canonical for negative single-to-double print)
    - `5 DUP ABS S>D <# #S ROT SIGN #> TYPE` → `5` (no `-` emitted for non-negative `n`)
    - Signed double canonical: `-10 S>D DUP ROT DABS <# #S ROT SIGN #> TYPE` → `-10`

    **`HOLD` explicit-char insertion:**
    - `123 0 <# # # LIT ',' HOLD #S #> TYPE` (or `: ','-hold [ CHAR , ] LITERAL HOLD ;` if `LIT` isn't exposed) → `0,123` — **wait, rethink:** in pictured output, emitting `#`, `#`, `HOLD ','`, `#` left-to-right actually lays down chars rightmost-first. So `123 0 <# # # CHAR , HOLD #S #>` builds right-to-left: first `#` → `'3'`, second `#` → `'2'`, `HOLD ','` → `','`, `#S` → `'1'`. Result: `1,23` (hundreds, comma, tens, units). Verify by dev-at-write-time. One test case should use `[CHAR]` or a literal to insert a non-digit char via `HOLD`.

    **`HOLDS` string-insertion (AC #9):**
    - Need a Forth-source-visible counted string. Using `S"`: `: TEST S" abc" HOLDS ; 99 0 <# #S TEST #> TYPE` — expected result dev-computed; left-to-right property of HOLDS means the string appears in order at its insertion point. Minimum test: "HOLDS preserves string order."

    **Worst-case / 20-digit case (AC #8):**
    - `-1 -1 <# #S #> TYPE` (double `$FFFFFFFF` as unsigned) → `4294967295` (base 10, 10 chars)
    - `-1 -1 <# #S #> HEX TYPE DECIMAL` or `HEX -1 -1 <# #S #> TYPE DECIMAL` → `FFFFFFFF` (8 chars)
    - `2 BASE ! -1 -1 <# #S #> TYPE DECIMAL` → `11111111111111111111111111111111` (32 chars — within 40-byte budget)

    **Buffer-overflow guard (AC #5):**
    - `<#` followed by 41 explicit `HOLD` calls should produce the pictured-buffer-overflow diagnostic. A test of the form `<# 41 0 DO 65 HOLD LOOP #>` hitting the guard and falling through to ABORT + REPL recovery. Record the exact diagnostic string in Completion Notes.

    **Underflow recovery (AC #11):**
    - `<#` succeeds on empty stack (AC #11 — no underflow helper)
    - `#` with DEPTH=1 → `? Stack underflow` + `ok`
    - `#S` with DEPTH=1 → `? Stack underflow` + `ok`
    - `#>` with DEPTH=1 → `? Stack underflow` + `ok`
    - `HOLD` with DEPTH=0 → `? Stack underflow` + `ok`
    - `SIGN` with DEPTH=0 → `? Stack underflow` + `ok`
    - `HOLDS` with DEPTH=1 → `? Stack underflow` + `ok`

    Total estimated test count: **22–28** (core 4 + base-switch 5 + sign 3 + HOLD 1 + HOLDS 1 + worst-case 3 + overflow 1 + underflow 7). Block range **550..<end>** — adjust to actual final count.

16. **Given** NFR9 (zero regressions, `prd.md:464`) and FR46 (all Epic 1–8 REPL tests continue to pass, `prd.md:435`), **When** the full test suite (`make test` + `make test-repl`) is run after this story's changes, **Then** every pre-existing test still passes, the new Story-10.7 tests all pass, and the final REPL test count increases by exactly the number of new entries added. Post-Story-10.6 baseline is **558 PASS, 0 FAIL**; the new count is `558 + <new entries>` with 0 FAIL. **Adjacency regression surface:** edits to `src/structures.asm` (adding fields to `UserArea`) may shift every `(IY+UserArea.xxx)` offset read/written across the whole codebase — **spot-check `BASE`, `STATE`, `>IN`, `SOURCE`, `#TIB`, `HERE` reads all return the correct values after the struct growth, and the cold-start init in `src/antforth.asm:41-68` still writes every struct field at its new offset.** `.` `U.` `.R` `.S` use the old `num_buf` path (they do NOT call pictured output yet — that's Story 10.8); they must output byte-identically. Canonical regression signal: `make test-repl` reports exactly `558 + N` PASS, 0 FAIL.

17. **Given** the cold-start sequence at `src/antforth.asm:18-77` initialises every `UserArea` field explicitly, **When** the new `hld` field is added, **Then** either (a) cold-start explicitly initialises `HLD` to `IY + UserArea.pic_buf + PIC_BUF_SIZE` (clean invariant: `HLD` always points to a valid buffer position from the first `#` call, even without a prior `<#`) **OR** (b) cold-start leaves `HLD` as zero and `<#` is documented as a required prerequisite for any pictured-output sequence (per standard, `<#` must be called first; undefined behaviour otherwise). **Recommendation: option (a) — deterministic init.** The `pic_buf` contents are left uninitialised (40 bytes of whatever the BSS area happens to contain); that's fine — pictured output overwrites as it fills.

18. **Given** NFR10 (100% §6.1 Core compliance target, `prd.md:461-476`) and the pre-Story-10.7 state documented in `docs/ans-forth-core-compliance.md:11-18` (**123 / 133 implemented = 92.5%**), **When** this story completes, **Then** the compliance doc is updated in the following places:
    - **§6.1 "Numeric Output and Formatting" table** at `ans-forth-core-compliance.md:190-205`: the six rows for `<#`, `#`, `#S`, `#>`, `HOLD`, `SIGN` flip from `**Gap → Story 10.7**` to `Implemented (`pictured.asm:<line>`)`; sub-section heading at line 192 updates from "10 §6.1 Core words — 4 implemented, 6 missing" to "10 §6.1 Core words — 10 implemented, 0 missing. **100% complete.**"
    - **§6.1 Summary table** at `ans-forth-core-compliance.md:11-18`:
        - "Fully implemented" 123 → 129
        - "Missing" 10 → 4
        - Coverage "123 / 133" → "129 / 133"; percentage 92.5% → **97.0%** (129 / 133)
    - **Gap Classification table** at `ans-forth-core-compliance.md:23-28`: decrement "(b) Oversight — missing subsystem" by 6 (8 → 2).
    - **Gap Analysis "Missing subsystem: Pictured numeric output"** section at `ans-forth-core-compliance.md:294-302`: mark as **Story 10.7 ✓ Complete**; note that Story 10.8 will rewrite `.` / `U.` / `.R` on top; preserve the text describing Story 10.8's role.
    - **Epic-10 closure plan row** for 10.7 at `ans-forth-core-compliance.md:45`: from `| 10.7 | Pictured numeric output primitives | 6 (...) + HOLDS (§6.2 bonus) | |` to `| 10.7 | Pictured numeric output primitives | 6 ✓ (...) + HOLDS (§6.2 bonus) ✓ | Complete |`.
    - **§6.2 Will gain via Epic 10 table** at `ans-forth-core-compliance.md:350-353`: flip the `HOLDS` row from `10.7` to `10.7 ✓ Implemented (`pictured.asm:<line>`)`.
    - **§6.2 Core Extension Bonus Coverage summary** at line 32: update "9 of 46" to "10 of 46" (`HOLDS` added).
    - **"big gaps" observation paragraph** at `ans-forth-core-compliance.md:409`: the pictured-output bullet is now closed; re-word to note Story 10.7 delivered the foundation and Story 10.8 will rewrite the display family atop it.
    - Date header at line 3: refresh to 2026-04-22 (or implementation date) with "Story 10.7 refresh" note.
    - **Do NOT touch §8.6 tables** — Story 10.7 adds nothing to §8.6; `HOLDS` is §6.2 Core Extension, not §8.6 Double-Number.

19. **Given** CCD-4 (Per-Epic Benchmark Gate, `architecture.md:218-226`) sets the benchmark / size-delta gate at **Story 10.10**, not here, **When** this story completes, **Then** the ROM size delta is recorded in the Completion Notes (informational — no gate). Rough estimate: `<#` ~15 bytes; `HOLD` ~20 bytes (with overflow guard); `#` ~50 bytes (UM/MOD call + digit conversion + HOLD inline); `#S` ~20 bytes DEFWORD; `#>` ~25 bytes; `SIGN` ~15 bytes DEFWORD; `HOLDS` ~25 bytes DEFWORD; `HLD` DEFCODE user-var ~10 bytes; plus `UserArea` struct grows by 42 bytes (2 for HLD + 40 for pic_buf) but this is BSS, not ROM; plus the pictured-overflow diagnostic string `str_pic_overflow` (~22 bytes) + `do_pic_overflow_error` helper (~25 bytes). **Total ROM estimate: ~220 bytes** ± 50%. Pre-edit baseline: `build/antforth.com` = **15812 bytes** (post-Story 10.6). Record pre/post sizes in the Dev Agent Record.

## Tasks / Subtasks

- [x] **Task 1 — Verify §-numbers + architectural preconditions** (AC: #2–#9, #13, #18)
  - [x] 1.1 Cross-reference DPANS94 §6.1.0030 (`#`), §6.1.0040 (`#>`), §6.1.0050 (`#S`), §6.1.0490 (`<#`), §6.1.1670 (`HOLD`), §6.1.2210 (`SIGN`) and Forth-2012/2014 §6.2.1675 (`HOLDS`) at implementation time against forth-standard.org or a local DPANS94 copy. **Do not enumerate from memory.** Match the §-numbers against the refreshed compliance doc (Story 10.1 resolved these during the 2026-04-20 refresh — the doc at `docs/ans-forth-core-compliance.md` is the local tiebreaker; if the doc and forth-standard.org disagree, trust the standard and note the drift as a finding).
  - [x] 1.2 Confirm all six `<#` / `#` / `#>` / `#S` / `HOLD` / `SIGN` are §6.1 Core (count toward FR15 / NFR10 — increment +6). `HOLDS` is §6.2 Core Extension (Forth-2014 addition) — increment to "§6.2 Core Extension bonus" only.
  - [x] 1.3 Read architecture decisions E10-D2 (`architecture.md:254-258`) and E10-D3 (`architecture.md:260-264`); confirm the "40-byte buffer in UserArea, IY-relative, HLD as USER variable" design. If the dev's implementation deviates (e.g., choosing to place the buffer outside `UserArea` for size reasons), flag in Dev Notes — architectural deviations require explicit justification per `feedback_design_upfront.md`.
  - [x] 1.4 Confirm `UM/MOD` (Story 10.6) is the underlying primitive for `#`. If `UM/MOD` is unreachable or buggy in any way, Story 10.7 is blocked until Story 10.6 is re-verified. (Expected: post-10.6 `make test-repl` baseline is 558 PASS, 0 FAIL — if so, UM/MOD is reliable.)

- [x] **Task 2 — Extend `UserArea` struct + cold-start init** (AC: #1, #17)
  - [x] 2.1 In `src/structures.asm`, add two new fields at the end of `UserArea`: `hld DW 0` and `pic_buf DS PIC_BUF_SIZE` where `PIC_BUF_SIZE EQU 40` is defined in `src/constants.asm` in the "Number Formatting Buffer" section (currently line 29-30; add a new line for PIC_BUF_SIZE near NUM_BUF_SIZE). Order matters: `hld` MUST precede `pic_buf` so the struct's `hld` offset is stable if the buffer ever grows.
  - [x] 2.2 In `src/constants.asm`, add `PIC_BUF_SIZE EQU 40` with a comment citing architecture decision E10-D2.
  - [x] 2.3 In `src/antforth.asm` cold-start (around line 41-68), add after the existing `UserArea.source_id` initialisation: compute `IY + UserArea.pic_buf + PIC_BUF_SIZE` into HL, store into `(IY+UserArea.hld)` / `(IY+UserArea.hld+1)`. Keep the existing ordering (STATE, BASE, HERE, TIB, >IN, LATEST, SOURCE-ID) intact; add HLD as the last init step. Rationale: Option (a) from AC #17.
  - [x] 2.4 Run `make test` and `make test-repl` immediately after this step (before writing any pictured-output words). Expected: **no change** to test counts. This isolates the struct-growth-only effect from the pictured-output implementation, so any regression here is definitively due to the struct edit, not the new code.

- [x] **Task 3 — Create `src/pictured.asm` file with header + USER variable + primitives** (AC: #2–#12, #13)
  - [x] 3.1 Create new file `src/pictured.asm` with the standard antforth file header (`; pictured.asm — Pictured numeric output words` + 2-line attribution matching `src/double.asm:1-2`). Include it in `src/antforth.asm` after `double.asm` (`src/antforth.asm:126`): add `        INCLUDE "pictured.asm"` on a new line immediately after the `double.asm` include.
  - [x] 3.2 Implement `HLD` as a DEFCODE user-variable word following the `BASE` template (`src/outer_interpreter.asm:35-39`): `LD A, UserArea.hld / JP push_user_var`. CCD-3 comment: `; antforth extension — HLD exposed as user variable (pictured-output cursor; DPANS94 doesn't require exposure but Gforth / SwiftForth precedent)`. Stack-effect: `; HLD ( -- a-addr )`.
  - [x] 3.3 Implement `<#` (DEFCODE). Body: compute `IY + UserArea.pic_buf + PIC_BUF_SIZE` → `(IY+UserArea.hld)`. Approach:
    ```
    PUSH IY
    POP HL            ; HL = IY
    LD BC, UserArea.pic_buf + PIC_BUF_SIZE
    ADD HL, BC
    LD (IY+UserArea.hld), L
    LD (IY+UserArea.hld+1), H
    ```
    Wait — this clobbers BC (TOS). Use DE or shadow registers to hoist TOS during the computation, **OR** use the IY-indexed-add via `LD A, UserArea.pic_buf + PIC_BUF_SIZE / LD C, A / LD B, 0 / ADD IY, BC / LD HL, IY / LD (IY-...)` — care required. **Simpler alternative:** since `UserArea.pic_buf + PIC_BUF_SIZE` is a compile-time constant offset, use the `LD IX, ...` idiom: `LD HL, UserArea.pic_buf + PIC_BUF_SIZE / ADD IY, HL / LD (IY-delta+hld_offset), …` — too fragile. **Cleanest:** stash BC via `PUSH BC` first, compute the sentinel, store, `POP BC`:
    ```
    PUSH BC            ; Save TOS
    PUSH IY
    POP HL             ; HL = IY
    LD BC, UserArea.pic_buf + PIC_BUF_SIZE
    ADD HL, BC
    LD (IY+UserArea.hld), L
    LD (IY+UserArea.hld+1), H
    POP BC             ; Restore TOS
    NEXT
    ```
    ~14 bytes. CCD-3 comment: `; ANS Forth 1994 §6.1.0490   <#   — start pictured numeric output conversion`. Stack-effect: `; <# ( -- )`.
  - [x] 3.4 Implement `HOLD` (DEFCODE). Body: decrement `HLD`; if `HLD` underflows below `IY + UserArea.pic_buf`, jump to `do_pic_overflow_error`; else store low byte of BC at `(HLD)`; pop new TOS; NEXT. Underflow check: `LD HL, (IY+UserArea.hld) / DEC HL / LD (IY+UserArea.hld), L / LD (IY+UserArea.hld+1), H`; then compare HL against `IY + UserArea.pic_buf` to test below-buffer — this is where the guard decides to call `do_pic_overflow_error`. **Per project memory `project_tos_in_register.md`, be careful with BC preservation across the write — `LD A, C / LD (HL), A` is cheapest.** Entry: `check_underflow` (1-cell). CCD-3 comment: `; ANS Forth 1994 §6.1.1670   HOLD   — insert char into pictured-output buffer`. Stack-effect: `; HOLD ( char -- )`.
  - [x] 3.5 Implement `#` (DEFCODE). Body: divide `ud` by `BASE`; convert remainder to char; HOLD inline (not via the HOLD word — inline is ~10 bytes cheaper). Approach:
    1. `check_underflow_2`
    2. Stash IP (DE) to `pictured_ip_stash` (new scratch cell — see AC #10 and Task 6.2) — OR reuse `double_ip_stash` per the documented invariant (dev's choice; note in Dev Notes).
    3. POP `ud-hi` into HL; keep BC = `ud-lo` (TOS); load `BASE` into a scratch register — but BASE is a cell (2 bytes); in practice it's always ≤ 36 so it fits in E (8-bit) — use `LD A, (IY+UserArea.base)` to get it. (Verify that antforth's BASE is always ≤ 255 and thus fits in A; this is a pre-existing invariant used by `u_to_str` at `formatting.asm:59`.) Set up a stack frame compatible with `UM/MOD`: the UM/MOD primitive expects `ud` on the param-stack in `( ud-hi ud-lo u1 )` form with BC = `u1`. Pushing and calling UM/MOD via NEXT is threaded-code territory — **can't be done from pure DEFCODE inline**. **Alternative approach:** do the 16-bit div-by-byte in-line (since BASE ≤ 36 ≤ 255) using a 32-bit dividend / 8-bit divisor — structurally simpler than a full UM/MOD call because no call-into-threaded-code is required. Algorithm: 16-iteration shift-subtract on `(ud-hi : ud-lo)` with E = BASE (8-bit); at loop end the quotient has replaced ud-lo / ud-hi and the remainder is a single byte in A (0..35). Then `digit_to_char` converts A → char; inline the HOLD logic (decrement HLD, store char, underflow-check). **Recommendation:** this inline approach is ~60-80 bytes and avoids the DEFCODE-calling-DEFCODE problem. The code-review pass should verify this approach is faster AND correct.
    4. Alternative DEFCODE approach: make `#` a **DEFWORD** whose body is `(?2) BASE @ UM/MOD SWAP digit-to-char-helper HOLD` — but `digit-to-char` is not a Forth word; adding it as one costs a dictionary header. Another DEFWORD form: `(?2) BASE @ UM/MOD SWAP DUP 10 < IF [CHAR] 0 + ELSE [CHAR] A 10 - + THEN HOLD`. This is ~30-40 bytes but threaded-overhead-expensive per call — and `#` is on the hot path when `.` is rewritten in Story 10.8.
    5. **Decision point for dev:** **DEFCODE with inline 32-by-8 division is recommended** for speed; document the choice in Dev Notes. Reuse `digit_to_char` helper from `src/formatting.asm:11` — it's already defined and used by `u_to_str`; no duplication.
    6. On exit, push the new `ud2-hi` as the second-on-stack cell; BC = new `ud2-lo` (TOS).
    CCD-3 comment: `; ANS Forth 1994 §6.1.0030   #   — extract one digit of pictured numeric output`. Stack-effect: `; # ( ud1 -- ud2 )`.
  - [x] 3.6 Implement `#S` (DEFWORD wrapper). Body: `(?2)-or-guard BEGIN # 2DUP OR 0= UNTIL`. Or equivalent: `BEGIN # 2DUP D0= UNTIL` — but `D0=` isn't a word (and DPANS94's reference body uses `OVER OR`, cleaner). Canonical DPANS94 §A.6.1.0050 reference body: `BEGIN # 2DUP OR 0= UNTIL` — loop terminates when both cells are zero. Note: `UNTIL` compiles a `?BRANCH` that consumes the flag. Double-check: post-UNTIL the stack is `ud2` (the loop-terminating `ud` value, which is `0 0`). CCD-3: `; ANS Forth 1994 §6.1.0050   #S   — emit digits until ud is 0 0`. Stack-effect: `; #S ( ud1 -- ud2 )`.
  - [x] 3.7 Implement `#>` (DEFCODE). Body: discard `xd` (2 POP); compute `c-addr = HLD`; compute `u = IY + UserArea.pic_buf + PIC_BUF_SIZE - HLD`; push `c-addr`, set BC = `u`. Approach:
    ```
    CALL check_underflow_2
    POP  BC            ; discard xd-lo-had-to-be-rest- wait BC is TOS = xd-lo
    POP  HL            ; HL = xd-hi, discard
    LD   L, (IY+UserArea.hld)
    LD   H, (IY+UserArea.hld+1)  ; HL = HLD (c-addr)
    PUSH HL            ; c-addr on stack
    ; compute u = (IY+pic_buf+SIZE) - HLD
    PUSH IY
    POP  DE
    LD   BC, UserArea.pic_buf + PIC_BUF_SIZE
    EX   DE, HL        ; HL = IY, DE = HLD
    ADD  HL, BC        ; HL = end-sentinel
    OR   A             ; clear CF
    SBC  HL, DE        ; HL = end - HLD = u
    LD   B, H
    LD   C, L          ; BC = u (TOS)
    ; restore IP (need to stash before the mess)
    NEXT
    ```
    — actually the above clobbers DE (IP). **Must stash IP first.** Use `LD (pictured_ip_stash), DE` at entry, restore from stash before NEXT. CCD-3: `; ANS Forth 1994 §6.1.0040   #>   — finish pictured numeric output`. Stack-effect: `; #> ( xd -- c-addr u )`.
  - [x] 3.8 Implement `SIGN` (DEFWORD). Body: `(?1-guard) DUP 0< IF LIT '-' HOLD ELSE DROP THEN`. Actually: `DUP 0<` leaves flag on stack, consumes nothing from `n`; `IF ... THEN`: `DROP LIT '-' HOLD` when negative. Simpler: `0< IF LIT '-' HOLD THEN`. Wait — `0<` consumes `n`; after it, the stack has `flag`. `IF` consumes `flag`. Body then: `LIT '-' HOLD`. No DROP needed. Final body: `0< IF LIT '-' HOLD THEN` (the `IF` jump target skips `LIT '-' HOLD` when flag is false). Underflow guard: `check_underflow` needed for 1-cell; first word is `0<` which does its own 1-cell check (verify at `src/logic.asm:216`). **Actually:** `0<` doesn't check underflow; it just operates on BC. So an explicit `(?1)` guard (which would be just `check_underflow`) is needed OR the DEFWORD is paranoid via a Front-loaded `check_underflow` call. **Simplest:** add `CALL check_underflow` inline via a micro-DEFCODE guard `(?1)` mirroring `(?3)` at `src/double.asm:603-616` — but only if no other DEFWORD needs it. **If only SIGN needs it**, inline it as a DEFCODE instead of DEFWORD: `DEFCODE SIGN { CALL check_underflow; BIT 7, B; JR Z, .sign_nonneg; ... HOLD logic ...; .sign_nonneg: POP BC; NEXT }` — ~20 bytes. **Dev choice.** Stack-effect: `; SIGN ( n -- )`. CCD-3: `; ANS Forth 1994 §6.1.2210   SIGN   — insert '-' if n is negative`.
  - [x] 3.9 Implement `HOLDS` (DEFWORD). Canonical body (DPANS94 §6.2.1675 reference): `BEGIN DUP WHILE 1- 2DUP + C@ HOLD REPEAT 2DROP`. Walkthrough: iterate while `u > 0`; on each iteration `1-` decrements u, `2DUP +` computes `c-addr + u` (the address of the current char, iterating from high to low), `C@` fetches the byte, `HOLD` inserts it, `REPEAT` goes back. When `u = 0`, `2DROP` removes `c-addr u`. Stack-effect: `; HOLDS ( c-addr u -- )`. CCD-3: `; Forth 2014 §6.2.1675   HOLDS   — insert counted string into pictured-output buffer`.
  - [x] 3.10 Add the pictured-buffer-overflow diagnostic helper `do_pic_overflow_error`. Pattern: mirror `do_underflow_error` at `src/system.asm:370` — direct BDOS print of `str_pic_overflow` ("? Pictured buffer overflow"); JP ABORT. Define `str_pic_overflow` in `src/antforth.asm` near `str_underflow:` (around `antforth.asm:206-207`); add a matching `STR_PIC_OVERFLOW_LEN EQU 24` (or whatever length). The error word reuses `bdos_print_str` and `ABORT`. ~25-30 bytes.

- [x] **Task 4 — Create `tests/pictured_tests.fth`** (AC: #14, #15)
  - [x] 4.1 Create a new file `tests/pictured_tests.fth` with the top-of-file banner matching `tests/double_tests.fth:1-2` (`\ pictured_tests.fth — REPL tests for Story 10.7 pictured numeric output` etc.) and an opening comment citing the DPANS94 §-numbers. Section headers: `\ === Story 10.7 pictured numeric output (<#, #, #S, #>, HOLD, SIGN, HOLDS) ===`, then per-word sub-headers matching the Story 10.6 style.
  - [x] 4.2 For each word, add one-line Forth test scenarios with `\ expect: <output-fragment>` annotations covering AC #15. Use `TYPE` to emit the resulting pictured string; save and restore `BASE` around base-switching tests via `BASE @ >R ... R> BASE !`.
  - [x] 4.3 Sub-sections per the AC #15 list: Core primitives, Base-switching, Sign handling, `HOLD` explicit-char, `HOLDS` string-insertion, Worst-case (20-digit / FFFFFFFF / binary 32-bit), Buffer-overflow guard, Underflow recovery.
  - [x] 4.4 Total scenarios ≥ 22.

- [x] **Task 5 — Wire up `Makefile` `test-repl` entries** (AC: #14, #15, #16)
  - [x] 5.1 Section banner: `@# --- Story 10.7 pictured numeric output (550..<end>) — DPANS94 §6.1.{0030,0040,0050,0490,1670,2210} + §6.2.1675 ---`.
  - [x] 5.2 Canonical `@OUTPUT=$$(printf … | $(IZCPM) $(TARGET) 2>/dev/null || true) && ...` pattern (copy template from `Makefile:4583-4776`).
  - [x] 5.3 Numbering starts at **550**. Contiguous; no gaps.
  - [x] 5.4 `printf --` for any input whose first token starts with `-` (e.g., `-1 -1 <# #S #> TYPE`).
  - [x] 5.5 `$$` escape for any literal `$`-prefixed string in echo banners.
  - [x] 5.6 Underflow tests: one per primitive needing > 0 depth (6 tests — all primitives except `<#`).
  - [x] 5.7 The buffer-overflow test (`<# 41 0 DO 65 HOLD LOOP #>`) must produce the `? Pictured buffer overflow` diagnostic AND recover to `ok`; use the underflow-test pattern as template (two `grep -q` checks on the output).

- [x] **Task 6 — Integration + regression verification** (AC: #16, #17, #19)
  - [x] 6.1 `make clean && make` — build must succeed; no assembler warnings about the `UserArea` struct growth or the new INCLUDE.
  - [x] 6.2 Decide between reusing `double_ip_stash` (`src/double.asm:724`) vs. introducing a new `pictured_ip_stash` at the tail of `src/pictured.asm`. **Recommendation:** new `pictured_ip_stash` because `src/double.asm` already lists 7 consumers (`D+`, `D-`, `D=`, `D<`, `DNEGATE`, `UM*`, `UM/MOD`) and adding `pic` consumers to the same cell would require documenting every new consumer in the same comment block. Cost: 2 bytes. Benefit: cleaner file-locality invariant.
  - [x] 6.3 `make test` — assembly regression thread. Expected: PASS (unchanged).
  - [x] 6.4 `make test-repl` — expected `558 + <count>` PASS, 0 FAIL.
  - [x] 6.5 Spot-check regression on adjacent words — `BASE @ .`, `STATE @ .`, `TIB >IN @ .`, `HERE .`, `.S`, `WORDS` first 10 items, `. U. .R` with various inputs — all output byte-identical to the pre-story baseline. Critical risk: `UserArea` struct growth may have shifted offsets.
  - [x] 6.6 Verify `.` / `U.` / `.R` still use the legacy `num_buf` path — these words are **not** rewritten until Story 10.8. Grep for `num_buf` occurrences and confirm none were accidentally altered.
  - [x] 6.7 ROM size delta: record pre-edit (`build/antforth.com` = 15812 pre-story) and post-edit size in Completion Notes (informational — no gate).
  - [x] 6.8 Buffer-overflow empirical verification: run the test from Task 5.7 against the built binary; confirm the diagnostic fires AND the REPL recovers.

- [x] **Task 7 — Update `docs/ans-forth-core-compliance.md`** (AC: #18)
  - [x] 7.1 Flip all six rows in the "Numeric Output and Formatting" table at `ans-forth-core-compliance.md:190-205` from `**Gap → Story 10.7**` to `Implemented (`pictured.asm:<line>`)`. Line numbers resolve at write-time.
  - [x] 7.2 Update sub-section heading at `ans-forth-core-compliance.md:192` from "10 §6.1 Core words — 4 implemented, 6 missing" to "10 §6.1 Core words — 10 implemented, 0 missing. **100% complete.**"
  - [x] 7.3 Update §6.1 Summary table at `ans-forth-core-compliance.md:11-18`: "Fully implemented" 123 → 129; "Missing" 10 → 4; Coverage "123 / 133" → "129 / 133"; percentage 92.5% → **97.0%**.
  - [x] 7.4 Update Gap Classification table at `ans-forth-core-compliance.md:23-28`: "(b) Oversight — missing subsystem" 8 → 2.
  - [x] 7.5 Update "Missing subsystem: Pictured numeric output" section at `ans-forth-core-compliance.md:294-302`: mark Story 10.7 as **✓ Complete**; retain the note about Story 10.8's pending rewrite; update the "6 words" count to "**Story 10.7 delivered** the 6 §6.1 primitives + `HOLDS` §6.2 bonus; Story 10.8 rewrites `.`/`U.`/`.R` on this foundation".
  - [x] 7.6 Update Epic-10 closure plan row for 10.7 at `ans-forth-core-compliance.md:45`: from `| 10.7 | Pictured numeric output primitives | 6 (`<#` `#` `#S` `#>` `HOLD` `SIGN`) + `HOLDS` (§6.2 bonus) | |` to `| 10.7 | Pictured numeric output primitives | 6 ✓ (`<#` `#` `#S` `#>` `HOLD` `SIGN`) + `HOLDS` (§6.2 bonus) ✓ | Complete |`.
  - [x] 7.7 Update "§6.2 Will gain via Epic 10" table at `ans-forth-core-compliance.md:350-353`: flip the `HOLDS` row from `10.7` to `10.7 ✓ Implemented (`pictured.asm:<line>`)`.
  - [x] 7.8 Update §6.2 Core Extension bonus summary at line 32: "9 of 46" → "10 of 46".
  - [x] 7.9 Update the "big gaps" observation paragraph at `ans-forth-core-compliance.md:409`: close the pictured-output bullet; note Story 10.7 completed the foundation; Story 10.8 will rewrite the display family.
  - [x] 7.10 Date header at line 3: refresh to implementation date with "Story 10.7 refresh" note; preserve the "Last full audit: 2026-04-13 (Story 5.3)" line.
  - [x] 7.11 Do **not** touch §8.6 tables. Confirm by grep: "Story 10.7" should appear **only** in §6.1 and §6.2 tables after the edits.

- [x] **Task 8 — Self-review (adversarial) + code-review handoff** (AC: all)
  - [x] 8.1 Run an **adversarial self-review** (per `feedback_adversarial_review.md`) looking specifically for:
    - **`<#` sentinel arithmetic:** the end-of-buffer address must be `IY + UserArea.pic_buf + PIC_BUF_SIZE` (one past the last byte), not `+ PIC_BUF_SIZE - 1`. An off-by-one sentinel corrupts the first `HOLD` into reading the byte after the buffer.
    - **`HOLD` underflow guard:** fires when decrement would place `HLD` below `IY + UserArea.pic_buf`. An off-by-one guard (fires one char too early or too late) either causes spurious overflow ABORTs or buffer underruns into `UserArea.source_id`. Test: exactly 40 `HOLD` calls succeed; the 41st triggers the diagnostic.
    - **`#` inline division overflow / sign bug:** the 32-by-8 shift-subtract loop must handle `ud = $FFFFFFFF` correctly. Test: `-1 -1 <# #S #> TYPE` with BASE=10 → `4294967295`. A wrong-direction-shift or off-by-one iteration count produces garbage; Story 10.6's `UM/MOD` debug trap table is directly analogous.
    - **`#S` initial iteration:** for `ud = 0 0`, `#S` MUST call `#` **at least once** (so `0. 0. <# #S #>` produces a single `'0'` digit). If the loop condition short-circuits on zero before the first `#`, the output is empty — wrong. Test: `0 0 <# #S #> TYPE` → `0`.
    - **`#>` drops the double correctly:** the signature is `( xd -- c-addr u )`, which is a **net-zero** cell-count change (2 in, 2 out). A wrong-count DROP (e.g., `POP BC` only, forgetting the second cell) leaves a stray cell; a DROP of 3 cells corrupts the stack below. Verify with a test that calls `<# #S #> TYPE DEPTH .` — DEPTH after TYPE should equal the DEPTH before `<#` (both pictured output and TYPE net-zero the stack).
    - **`SIGN` consumes `n` on both branches:** the DEFWORD body must consume the stacked `n` whether or not it was negative. A body that forgets to `DROP` on the non-negative branch leaves `n` on the stack.
    - **`HOLDS` order:** insert chars from `c-addr + u - 1` down to `c-addr`, NOT from `c-addr` up to `c-addr + u - 1`. Because the buffer fills RIGHT-TO-LEFT, inserting `"abc"` via `HOLDS` must leave `abc` (in that order) in the final buffer, not `cba`. Test with `<# S" abc" HOLDS #> TYPE` → `abc`.
    - **`UserArea` struct growth regression:** the 42-byte addition may push later fields past a page boundary or interact with the cold-start init ordering. Spot-check EVERY existing USER variable (`STATE`, `BASE`, `>IN`, `#TIB`, `SOURCE-ID`) after the struct growth — if any reads back a wrong value, the struct was mis-rebuilt. This is THE canonical non-obvious-failure mode for this story.
    - **Missing CCD-3 §-number citations or drifted §-numbers.** Epic spec's §6.2.1625 for `HOLDS` is a known typo — Story 10.1 established §6.2.1675 as correct. If the dev cites §6.2.1625 by copying from the epic rather than verifying, that's a HIGH finding.
    - **`digit_to_char` reuse:** the existing helper at `src/formatting.asm:11` is used by `u_to_str`. Both callers must produce identical output for digit values 0..35. Regression test: compare `16 BASE ! 65535 .` (uses `u_to_str`) output against `16 BASE ! 65535 0 <# #S #> TYPE` (uses the new `#` path). They must emit `FFFF` in both cases. Divergence indicates the new `#` is mis-converting digits in the `A..Z` range.
    - **Cold-start init for `HLD`:** if the cold-start computation is wrong (e.g., missing `PIC_BUF_SIZE` in the sentinel), the first-ever pictured operation on a fresh REPL (without a prior `<#`) misbehaves. Test by running pictured-output tests without an explicit `<#` first — they should still produce deterministic (if useless) output; a crash or ABORT is the wrong-init signature.
    - **Regressions in `.`, `U.`, `.R`:** these words still use `num_buf` + `u_to_str`. Grep the diff for any accidental change to `formatting.asm`. Spot-test `1234 . -5 . 42 10 .R` before and after — byte-identical output required (zero-change to display path).
  - [x] 8.2 Fill Completion Notes with plain diagnostic prose (per memory `feedback_plain_qa_language.md`) — measured values, gates, reasons; no florid framing.
  - [x] 8.3 Different-LLM second-pass review recommended — `/bmad-bmm-code-review 10.7` is the natural hook. Stories 10.2–10.6 all caught real defects in that pass (10.3 off-by-one underflow; 10.4 wrong-arithmetic AC boundary + Makefile `$` escaping; 10.5 stale section-header counts; 10.6 heading count + AC text errata). This story's trap-rich surface (buffer sentinel arithmetic, struct-growth regression, `#S` zero-case, `HOLDS` direction, `SIGN` consume-on-both-branches, `#` 32-by-8 inner loop, pre-existing num_buf untouchedness) is a similar target.

## Dev Notes

### Story Purpose and Epic-10 Position

Story 10.7 is the **sixth implementation story in Epic 10** and delivers the pictured-numeric-output foundation that Story 10.8 will use to rewrite the Core number-display family. It closes the §6.1 Numeric-Output sub-category from 4/10 (40%) to 10/10 (100%) — the largest single jump in Epic 10 besides Story 10.2's double-cell-stack delivery. After this story lands, only `*/`, `*/MOD`, `EVALUATE`, `ENVIRONMENT?` (Story 10.9) and the rewritten `.` / `U.` / `.R` family (Story 10.8) stand between antforth and 100% §6.1 Core.

Three things fall out of this story that subsequent stories depend on:

1. **`<#` / `#` / `#S` / `#>` / `HOLD` / `SIGN` must exist** for Story 10.8 to rewrite `.`, `U.`, `.R`, `D.`, `U.R`, `D.R` atop them. Without 10.7, Story 10.8 is blocked.
2. **The `pic_buf` + `HLD` machinery in `UserArea`** establishes the per-task pictured-output state model. Post-2.0 multitasking (outside phase-2 scope) will rely on this being per-task, not global.
3. **`HOLDS` (Forth-2014 §6.2.1675)** lets Story 10.8 implement `D.R`-style padding via explicit string-insertion, rather than needing a new primitive.

### Architectural Decisions That Apply to This Story

From `_bmad-output/planning-artifacts/architecture.md`:

- **§206-216 CCD-3 (Standards-Citation Discipline):** every word cites its DPANS94 §-number. Non-negotiable — match Stories 10.2 / 10.3 / 10.4 / 10.5 / 10.6 template (`src/double.asm` house style).
- **§218-226 CCD-4 (Per-Epic Benchmark Gate):** gate is at **Story 10.10**, not here. Record ROM delta informationally.
- **§246-252 E10-D1 (Byte-Order):** low cell on TOS, high cell below. For `#`, `#S`, `#>`: `ud` on entry is `( ud-hi ud-lo )` with `ud-lo = BC` (TOS). Non-negotiable.
- **§254-258 E10-D2 (Pictured-output buffer placement):** 40-byte buffer in the user area (`IY + UserArea.pic_buf`), IY-relative, addressed via USER variable `HLD`. `<#` resets `HLD` to the buffer's high end; `#`/`#S`/`HOLD`/`SIGN`/`HOLDS` build leftward. **The entire architectural model is pre-specified — do not re-litigate layout or placement.** If dev needs to deviate (e.g., for unexpected size constraints), flag as a finding and get project-lead concurrence before implementing.
- **§260-264 E10-D3 (Implementation split):** hot inner primitives in assembly; thin wrappers in Forth. Pictured output has a clear hot path (`#` / `<#` / `#>` / `HOLD`) and thin wrappers (`#S`, `SIGN`, `HOLDS`). Follow the split as recommended in AC #12.
- **§434-447 Source-file organisation:** `src/pictured.asm` is a new Epic-10 file per architecture table line 442. Do NOT put pictured words in `src/double.asm` — the table is explicit.

### BC-as-TOS Convention and DE=IP Discipline

Per project memory `project_tos_in_register.md`, every existing primitive treats BC as TOS on entry and exit. For pictured output, each word's BC-entry/exit contract depends on the word:

| Word | Entry BC | Exit BC |
|---|---|---|
| `<#` | any (TOS preserved) | same TOS (unchanged cells in/out) |
| `HOLD` | `char` | new TOS (popped from below) |
| `#` | `ud-lo` | `ud2-lo` |
| `#S` | `ud-lo` | `ud2-lo` (= 0 on exit) |
| `#>` | `xd-lo` | `u` (the length) |
| `SIGN` | `n` | new TOS (popped from below) |
| `HOLDS` | `u` | new TOS (popped from below, 2 cells consumed) |
| `HLD` | any (TOS preserved then pushed over) | address of HLD user-var |

`DE = IP` throughout. For DEFCODE primitives that clobber DE (e.g., `#` doing its 32-by-8 division), memory-stash IP via a new `pictured_ip_stash` cell at the tail of `src/pictured.asm` (or reuse `double_ip_stash` — document the choice).

### Stories 10.2–10.6 Carry-Forwards

From `_bmad-output/implementation-artifacts/10-{2,3,4,5,6}-*.md` (all `done`):

1. **CCD-3 template locked.** Format: `; ANS Forth 1994 §<n>   <word>   — <note>`. Every §-number verified at write-time against DPANS94 / forth-standard.org (NOT against memory or the epic spec — the epic spec has been flagged for drift multiple times).
2. **`check_underflow` / `_2` / `_3` / `_4` exist** in `src/system.asm:278-362`. Use directly; do not introduce new helpers. Story 10.7 uses `check_underflow` (for 1-cell) and `check_underflow_2` (for 2-cell ud).
3. **New Epic-10 source files follow the `src/double.asm` style.** Opening comment, per-word section separator comment, CCD-3 + stack-effect header comment, `w_NAME:` / `DEFCODE` / `w_NAME_cf:` or `w_NAME_body: / w_NAME_cf EQU w_NAME_body - 3` idiom.
4. **Tests live in dedicated files** — `tests/pictured_tests.fth` is new; file must declare itself at the top (banner) and use `\ ===` section headers matching `tests/double_tests.fth` style.
5. **Makefile test numbering is contiguous.** Current max is **549** (post-Story-10.6). Start at **550**.
6. **Different-LLM second-pass review is expected** for Epic-10 stories that write new code. This story's surface is particularly trap-rich — struct growth, buffer sentinel arithmetic, inline 32-by-8 division, and the `HOLDS` direction gotcha are all canonical defect sites.
7. **The `(?N)` guard pattern** established in Story 10.6 (`src/double.asm:603-616` — the `(?3)` DEFCODE) is available if dev needs a 1-cell or 2-cell front-loaded guard for DEFWORDs whose natural first body word doesn't check the required depth. For Story 10.7, `SIGN` and `HOLDS` are the primary candidates — but each has plausible inline-underflow alternatives.
8. **Arithmetic helpers are shared across files.** `digit_to_char` at `src/formatting.asm:11` is called by `u_to_str` (used by `.`, `U.`, `.S`) and will be re-called by `#` in Story 10.7. No duplication; single source of truth for digit conversion.

### Correctness Traps (by word)

**`<#`:**

- **Off-by-one sentinel:** end-of-buffer sentinel is `IY + UserArea.pic_buf + PIC_BUF_SIZE` (one past the last valid byte), NOT `IY + UserArea.pic_buf + PIC_BUF_SIZE - 1`. The first `HOLD` decrements HLD to `sentinel - 1` before writing — so HLD initial = sentinel is correct.
- **No underflow possible** — consumes zero cells.

**`HOLD`:**

- **Underflow guard direction:** the guard fires when `HLD - 1 < IY + UserArea.pic_buf`, i.e., when HLD before decrement equals `IY + UserArea.pic_buf`. An off-by-one guard either lets HOLD write one byte before the buffer (corruption into prior `UserArea` fields!) or fails one byte early (loses a legitimate write).
- **Byte-wise write:** store `LD A, C / LD (HL), A` — BC's high byte is part of the char cell but ANS `HOLD` takes `( char -- )` where char is single-cell; the low byte of BC is the char. Don't accidentally store BC's high byte as the HOLD char.

**`#`:**

- **Inline 32-by-8 division vs. DEFWORD-through-UM/MOD:** AC #12 and Task 3.5 discuss the tradeoff. If DEFCODE-inline is chosen, the shift-subtract loop uses 16 iterations, shifting `(ud-hi : ud-lo)` left by one bit each iteration with CF as the 33rd bit; the divisor byte is in E (from `LD E, (IY+UserArea.base)`); the partial quotient builds in `ud-lo`; the remainder accumulates in A. Reference: `u_to_str`'s `div_bc_by_e` at `src/formatting.asm:27-41` — that's **16-by-8**; we need 32-by-8, which is the same algorithm one "dimension up." Unroll into: 16 iterations each doing `SLA C / RL B / RL ud-hi-lo / RL ud-hi-hi / RLA / CP E / JR C skip / SUB E / INC C / skip:`. Details fiddly — the adversarial self-review call-out in Task 8.1 is specifically for this.
- **BASE mutation invariant:** `#` reads BASE but never writes it. Epic 9's NFR8 / FR9 discipline is preserved.
- **Digit conversion reuse:** call `digit_to_char` (or inline its 4-line body). Do NOT define a new helper.

**`#S`:**

- **First-iteration requirement:** DPANS94 wording says `#S` calls `#` repeatedly "until `ud` is zero." The canonical reference body `BEGIN # 2DUP OR 0= UNTIL` calls `#` first, then tests. **If dev writes `BEGIN 2DUP OR WHILE # REPEAT`, that's WRONG** — it short-circuits on zero, emitting no digits for `0 0`.
- **Loop termination:** `UNTIL` consumes the flag from `0=`. Post-loop stack is the last-iteration `ud` (= `0 0`). Stack balance: 2 in, 2 out, net zero cell-count change.

**`#>`:**

- **Discard vs. pop vs. drop:** `xd` is two cells on entry; discard both. Net-zero change in cell count (2 drop + 2 push = 0 delta). Pop both `xd-lo` (in BC) and `xd-hi` (on SP) before pushing `c-addr` and `u`.
- **`u` computation:** `u = end-sentinel - HLD`, where `end-sentinel = IY + UserArea.pic_buf + PIC_BUF_SIZE`. For an unwritten buffer (fresh `<#` with no `#`), `u = 0`.

**`SIGN`:**

- **Both-branch consume:** the DEFWORD body must consume `n` on both the negative and non-negative branches. The `0<` approach (`0< IF LIT '-' HOLD THEN`) consumes `n` for the flag computation and leaves `0<`'s flag on stack; `IF` then consumes the flag. Both branches net-consume exactly one cell. **Don't accidentally use `DUP 0< IF '-' HOLD ELSE DROP THEN`** — that consumes 1 cell if-negative and 1 cell if-non-negative (correct but uses extra DUP/DROP unnecessarily).

**`HOLDS`:**

- **Iteration direction:** insert from `c-addr + u - 1` DOWN to `c-addr`. Canonical DPANS94 reference body `BEGIN DUP WHILE 1- 2DUP + C@ HOLD REPEAT 2DROP` does exactly this — `1-` decrements u (so loop index moves from u-1 down to 0), `2DUP +` computes the current char address, `C@` reads it, `HOLD` inserts. When the buffer is filled right-to-left, inserting in reverse walk-order leaves the string in correct visual order.
- **Underflow guard:** 2-cell consumption; use `check_underflow_2` or the `(?2)` guard helper if DEFWORD-inheritance doesn't reach.

**`HLD` user-variable:**

- **Template mirror of `BASE`.** Literal copy-paste of `src/outer_interpreter.asm:35-39`, substituting `UserArea.base` with `UserArea.hld`. Nothing else changes.

### `UserArea` struct growth — the non-obvious regression risk

Adding `hld DW 0` + `pic_buf DS PIC_BUF_SIZE` to the end of `UserArea` grows the struct from 16 bytes (8 fields × 2 bytes) to **58 bytes** (16 + 2 + 40). This is the **first time Phase-2 has grown `UserArea`**. Every existing `IY+UserArea.xxx` reference uses the struct's computed offset, so the growth is transparent to the `.state`, `.base`, `.here`, etc. accesses — BUT:

1. **Cold-start init coverage.** `src/antforth.asm:41-68` writes `UserArea.state`, `.base`, `.here`, `.tib_addr`, `.tib_len`, `.tib_in`, `.latest`, `.source_id`. If dev adds HLD init as the last step (Task 2.3), nothing else needs re-ordering.
2. **Memory adjacency.** `user_area` sits between `num_buf` and `bdos_input_buf` (`src/antforth.asm:222-225`). Growing `user_area` by 42 bytes pushes `bdos_input_buf` (and `tib_buffer` and `kernel_end`) down by 42 bytes. No assembler directive depends on `kernel_end` being at a specific address — it's just the marker. The ROM size bumps by 42 bytes BSS — but BSS isn't in the .COM binary; `.COM` size growth is the code delta only (~220 bytes per AC #19).
3. **Tests that snapshot `HERE` or memory layout.** There are some tests that check absolute addresses (`HERE @ .` produces an expected address, or memory dumps compare byte ranges). If any such test exists and uses an absolute number rather than relative comparison, the 42-byte shift breaks it. Spot-check `tests/core_tests.fth` for absolute-address-dependent assertions.
4. **The IY offsets.** `UserArea.state = 0`, `.base = 2`, …, `.source_id = 14`. Adding `hld = 16` and `pic_buf = 18` is clean. Any existing code that hardcodes offsets (bypassing the STRUCT `.xxx` symbol) would break — but grep for `IY+` / `IY +` / raw hex offsets should show zero hardcoded references outside STRUCT-derived identifiers.

**The canonical regression signal:** run `make test-repl` after the struct-only change (Task 2.4), before any pictured words are added. If any test fails there, the struct edit is the cause. Fix before moving on.

### Buffer-overflow discipline — pre-Epic-11 pattern

Pictured-output buffer overflow is a new error condition (no analogue in pre-Epic-10 antforth). The project's error-handling model pre-Epic-11 is ABORT + REPL recovery; Epic 11 Story 11.4 / 11.6 will migrate THROW codes. **Do NOT pre-migrate for Story 10.7.**

Follow the `do_underflow_error` pattern at `src/system.asm:370`:
- Define `str_pic_overflow` in `src/antforth.asm` near `str_underflow:` (around line 206).
- Define `STR_PIC_OVERFLOW_LEN EQU <length>` immediately after.
- Implement `do_pic_overflow_error` in `src/pictured.asm` (or `src/system.asm` — either location is defensible; `pictured.asm` keeps the error local to its only caller).
- `HOLD` is the sole caller; `HOLDS` doesn't need a separate guard because it calls `HOLD` per character.

Epic 11 Story 11.4 / 11.6 will later migrate this to `THROW -17` (DPANS94 §9.3.5 "pictured numeric output string overflow"). The diagnostic string `? Pictured buffer overflow` is informational and may be updated at THROW migration — for Story 10.7, any clear ASCII diagnostic is acceptable.

### Epic 10 Dependencies Already Landed

Nothing blocks Story 10.7:

- Epic 1–8 parameter-stack + memory + arithmetic primitives ✓
- Story 10.1 gap survey ✓ (assigned `<# # #S #> HOLD SIGN` + `HOLDS` to 10.7)
- Story 10.2 double-cell stack foundation ✓ (2DUP, 2DROP, 2OVER available for DEFWORD wrappers)
- Story 10.3 single↔double conversions ✓ (`S>D` for the canonical `. -> <# #S ROT SIGN #>` path)
- Story 10.4 double arithmetic ✓ (`DABS` for canonical `.R`-style double formatting)
- Story 10.5 double multiplication ✓ (not directly consumed; present)
- Story 10.6 double/mixed division ✓ (**`UM/MOD` is the canonical `#` digit-extraction primitive**; if dev chooses the DEFWORD form of `#`, `UM/MOD` is directly called)

Story 10.8 depends on **this** story's `<# # #S #> HOLD SIGN` for its rewrite of `.` / `U.` / `.R`. Story 10.9's `ENVIRONMENT?` query table cites `/HOLD = 40` (PIC_BUF_SIZE) as the antforth value per DPANS94 §3.2.6 — so the PIC_BUF_SIZE constant landed here also feeds 10.9.

### Epic 10 Retro — Action Items Relevant to This Story

From Stories 10.2–10.6's code-review passes:

- **Plain QA prose** (`feedback_plain_qa_language.md`): Completion Notes state measured values, gates, reasons plainly. No florid framing.
- **AC-drafting trace-check:** every AC in this story maps to at least one Makefile test entry. Traceability is explicit in AC #15 and Task 5.
- **Adversarial self-review that actually finds things:** Stories 10.4 / 10.5 / 10.6 each had self-reviews declare "no findings" while code-review found multiple. For this story, the primary attack surfaces are (a) buffer sentinel arithmetic, (b) struct-growth regression, (c) `#` inline division, (d) `#S` zero-case, (e) `HOLDS` direction, (f) `SIGN` consume-on-both-branches, (g) `.` / `U.` / `.R` untouched-path preservation. **Assume your self-review missed something.**
- **Makefile `$$` escaping:** any hex literal or `$`-prefixed string in an echo banner needs `$$`.
- **`printf --` option terminator:** tests whose input begins with a `-` literal need `printf --`.
- **§-number verification at write-time (non-negotiable):** epic spec's §6.2.1625 for `HOLDS` is a typo; Story 10.1 established §6.2.1675 as correct. If dev cites the epic's typo, that's a HIGH finding per `feedback_systematic_reference_check.md`.

### Project Structure Notes

- **Files created:**
  - `src/pictured.asm` (NEW — all 7 new words + HLD user-var DEFCODE + pictured-overflow helper)
  - `tests/pictured_tests.fth` (NEW — REPL-piped Forth tests)
- **Files modified:**
  - `src/structures.asm` (EDIT — add `hld DW 0` + `pic_buf DS PIC_BUF_SIZE` to `UserArea` struct)
  - `src/constants.asm` (EDIT — add `PIC_BUF_SIZE EQU 40` with E10-D2 citation)
  - `src/antforth.asm` (EDIT — add `INCLUDE "pictured.asm"` after double.asm; add HLD init in cold-start; define `str_pic_overflow` + `STR_PIC_OVERFLOW_LEN`)
  - `Makefile` (EDIT — new `test-repl` entries starting at 550)
  - `docs/ans-forth-core-compliance.md` (EDIT — 6 §6.1 Numeric-Output row flips + sub-section heading count update + §6.1 Summary table increment + Gap Classification decrement + §6.2 bonus summary + §6.2 `HOLDS` row flip + "Missing subsystem" section close + Epic-10 closure-plan row update + big-gaps paragraph update + date header)
  - `_bmad-output/implementation-artifacts/sprint-status.yaml` (EDIT — status transitions, handled by dev-story workflow)
  - `_bmad-output/implementation-artifacts/10-7-pictured-numeric-output-primitives.md` (THIS FILE — Dev Agent Record + Completion Notes at close)
- **No files deleted.** No re-organisation of existing code.
- **Alignment with unified structure:** all edits sit in established homes per `architecture.md:434-447`. The new `src/pictured.asm` file is pre-specified by architecture table line 442. No source-tree structural change beyond the sanctioned new file.
- **Detected conflicts or variances:** one — the epic spec at `epics.md:596` cites `HOLDS` as `§6.2.1625`, but the correct DPANS94 / Forth-2012 §-number is `§6.2.1675` (per Story 10.1's refreshed compliance doc at `docs/ans-forth-core-compliance.md:352` and forth-standard.org). Dev agent must verify and use `§6.2.1675`; if the dev copies the epic's typo, that's a HIGH finding per `feedback_systematic_reference_check.md`.

### References

- **Authoritative standard:**
  - DPANS94 §6.1.0030 `#` — extract one digit of pictured output
  - DPANS94 §6.1.0040 `#>` — finish pictured output; return (c-addr u)
  - DPANS94 §6.1.0050 `#S` — emit digits until ud = 0 0
  - DPANS94 §6.1.0490 `<#` — start pictured output conversion
  - DPANS94 §6.1.1670 `HOLD` — insert char into pictured-output buffer
  - DPANS94 §6.1.2210 `SIGN` — insert '-' if n is negative
  - Forth-2012 / Forth-2014 §6.2.1675 `HOLDS` — insert a counted string into pictured-output buffer
  - DPANS94 §3.2.6 `/HOLD` — implementation-defined pictured-output buffer size (antforth = 40; feeds `ENVIRONMENT?` in Story 10.9)
  - **Verify all §-numbers at implementation time** against DPANS94 / forth-standard.org before committing comments. Epic spec's §6.2.1625 for `HOLDS` is a drafting typo.
- **Planning artefacts:**
  - `_bmad-output/planning-artifacts/epics.md:574-600` — Story 10.7 epic spec
  - `_bmad-output/planning-artifacts/epics.md:426-448` — Epic 10 overview
  - `_bmad-output/planning-artifacts/epics.md:602-624` — Story 10.8 spec (downstream consumer)
  - `_bmad-output/planning-artifacts/architecture.md:246-264` — E10-D1 / E10-D2 / E10-D3 decisions
  - `_bmad-output/planning-artifacts/architecture.md:206-216` — CCD-3 Standards-Citation Discipline
  - `_bmad-output/planning-artifacts/architecture.md:218-226` — CCD-4 Per-Epic Benchmark Gate (at Story 10.10, not here)
  - `_bmad-output/planning-artifacts/architecture.md:434-447` — Source-file organisation table (new file `src/pictured.asm` sanctioned)
  - `_bmad-output/planning-artifacts/prd.md` — FR13 (pictured output wordset), NFR9 (regression), NFR10 (Core compliance), NFR16 (test-first), NFR17 (standards citations)
- **Precedent stories:**
  - `_bmad-output/implementation-artifacts/10-2-double-cell-stack-foundation.md` — first Epic-10 file (`src/double.asm`), test-file conventions (`tests/double_tests.fth`), CCD-3 template
  - `_bmad-output/implementation-artifacts/10-3-single-double-conversions.md` — `S>D` sign-extend pattern (consumed by canonical pictured-output recipe)
  - `_bmad-output/implementation-artifacts/10-4-double-precision-arithmetic-additive-sign-compare-mixed.md` — `DABS` for canonical double-to-signed-string path
  - `_bmad-output/implementation-artifacts/10-5-double-multiplication.md` — DEFCODE-inner + DEFWORD-wrapper pattern
  - `_bmad-output/implementation-artifacts/10-6-double-mixed-precision-division.md` — **closest precedent**; DEFCODE-inner with shift-subtract inner loop (analogous to `#`'s 32-by-8 inline division), `(?N)` underflow-guard helper pattern, Makefile `$$` + `printf --` discipline, self-review trap table format
  - `_bmad-output/implementation-artifacts/10-1-ans-core-compliance-gap-survey-and-implementation-plan.md` — authoritative gap list + §6.2.1675 HOLDS correction
- **Source-tree anchors for pattern matching:**
  - `src/outer_interpreter.asm:35-39` — `BASE` DEFCODE = literal template for `HLD` DEFCODE
  - `src/double.asm:566-600` — `UM/MOD` DEFCODE = structural reference for `#`'s 32-by-X shift-subtract inner loop (similar iteration pattern, subtraction-based)
  - `src/formatting.asm:11-18` — `digit_to_char` helper = direct reuse target for `#`'s character conversion
  - `src/formatting.asm:27-41` — `div_bc_by_e` = structural reference for inline division by BASE (16-by-8 pattern; `#` needs 32-by-8)
  - `src/formatting.asm:55-81` — `u_to_str` = the existing `num_buf`-based path; must remain untouched (Story 10.8's concern)
  - `src/system.asm:278-362` — `check_underflow` / `_2` / `_3` / `_4` helpers (use `check_underflow` and `check_underflow_2`; do NOT add new helpers)
  - `src/system.asm:370-378` — `do_underflow_error` = structural template for `do_pic_overflow_error`
  - `src/structures.asm:18-27` — `UserArea` struct definition (target of Task 2.1 edit)
  - `src/antforth.asm:41-68` — cold-start init sequence (target of Task 2.3 edit)
  - `src/antforth.asm:121-131` — CODE primitives include list (target of Task 3.1 edit)
  - `src/antforth.asm:206-207` — `str_underflow` + `STR_UNDERFLOW_LEN` = structural template for `str_pic_overflow` definition
  - `src/antforth.asm:222-225` — `num_buf`/`user_area`/`bdos_input_buf`/`tib_buffer` layout (grows by 42 bytes)
  - `src/constants.asm:26-30` — PAD / NUM_BUF_SIZE section (site for new `PIC_BUF_SIZE` constant)
  - `src/macros.asm:60-127` — `DEFCODE` / `DEFWORD` / `DEFIMMED` macros
  - `src/double.asm:603-616` — `(?3)` underflow-guard DEFCODE = structural template for `(?2)` if needed
  - `src/compiler.asm:55` — `[']` DEFIMMED (LIT compile pattern for literal chars)
- **Test-tree anchors:**
  - `tests/double_tests.fth:1-10` — top-of-file banner style = template for `tests/pictured_tests.fth`
  - `tests/double_tests.fth:228-261` — Story 10.6 section = closest precedent for Story 10.7 test extension
  - `Makefile:4580-4776` — Story 10.6 `test-repl` block (tests 526..549) = canonical entry-format template
- **Compliance doc:**
  - `docs/ans-forth-core-compliance.md:190-205` — §6.1 "Numeric Output and Formatting" table (6 rows to flip)
  - `docs/ans-forth-core-compliance.md:11-18` — §6.1 Summary table (increment Implemented by 6)
  - `docs/ans-forth-core-compliance.md:23-28` — Gap Classification table (decrement (b) "missing subsystem" by 6)
  - `docs/ans-forth-core-compliance.md:32` — §6.2 bonus count (9 → 10 for HOLDS)
  - `docs/ans-forth-core-compliance.md:45` — Epic-10 closure plan row for Story 10.7
  - `docs/ans-forth-core-compliance.md:294-302` — "Missing subsystem: Pictured numeric output" section
  - `docs/ans-forth-core-compliance.md:350-353` — §6.2 "Will gain via Epic 10" table
  - `docs/ans-forth-core-compliance.md:409` — "big gaps" observation paragraph
- **Project memories applicable to this story:**
  - `feedback_systematic_reference_check.md` — cross-reference DPANS94, not memory (AC #13; epic's §6.2.1625 HOLDS typo is the canonical trap)
  - `feedback_standards_compliance.md` — investigate the standard; never rationalise
  - `feedback_adversarial_review.md` — reviews MUST find things (Task 8; 10.6 trap-table precedent)
  - `feedback_plain_qa_language.md` — diagnostic Completion Notes
  - `feedback_repl_tests_preferred.md` — REPL-piped Forth scripts (AC #14, Task 4)
  - `feedback_design_upfront.md` — close the full §6.1 Numeric-Output sub-family in one story so Story 10.8 consumes a conformant foundation from day one; `UserArea` struct grown to its Epic-10 final layout here (no further field churn expected in Epic 10)
  - `feedback_follow_process.md` — execute the workflow without asking for permission for obvious next steps (e.g., re-running grep, re-reading the struct file)
  - `feedback_defword_cf_label.md` — for DEFWORDs `#S`, `SIGN`, `HOLDS`: `w_NAME_cf EQU w_NAME_body - 3` (pointing at `JP DOCOL`), not at the body. Precedent: every DEFWORD in `src/double.asm` and `src/bootstrap.asm`.
  - `project_tos_in_register.md` — BC-as-TOS discipline; DE=IP; DEPTH convention (AC #10, Dev Notes)
  - `project_epic5_scope.md` — (reference only — Epic 5 retired)

### Project Structure Notes

- Alignment with unified project structure: story file lives in `_bmad-output/implementation-artifacts/` per `config.yaml:implementation_artifacts`. The new `src/pictured.asm` is pre-specified in architecture §434-447 as the Epic-10 pictured-output source file. The new `tests/pictured_tests.fth` mirrors the convention of one dedicated `tests/*_tests.fth` per subsystem (already used by `tests/double_tests.fth`, `tests/number_prefixes_tests.fth`, `tests/core_tests.fth`).
- No detected conflicts or variances with the unified structure.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (1M context) — `claude-opus-4-7[1m]`.

### Debug Log References

- Initial sanity test `123 0 <# #S #> TYPE` printed `8060928`, not the AC-#15 expected `123`. Verified the output was correct: E10-D1 puts the LOW cell on TOS, so typing `123 0` leaves `ud-hi=123 ud-lo=0` i.e. the double `123 * 65536 = 8060928`. AC #15's stack-order examples are syntactically reversed relative to E10-D1; the actual Makefile and `tests/pictured_tests.fth` use `0 123` (low on TOS) and verify `123` is emitted. Story editor should correct AC #15 when refreshing the spec.
- First Makefile run flagged REPL test 127 failure — `42 #` outside CODE was expected to emit `not in CODE ?`. That was the assembler `#`'s pre-dispatch behaviour. Updated test 127 to expect the new semantics: `#` outside a CODE block now dispatches to the pictured-output `#`, which aborts on `DEPTH=1` with `? Stack underflow`. REPL recovery path is unchanged.
- First Makefile run also flagged tests 554–557, 564–565 failures: they switched BASE *before* parsing the literal, so numbers like `65535` were re-interpreted as hex. Rewrote the tests to parse literals in DECIMAL first and then switch BASE for display. Same fix applied in `tests/pictured_tests.fth`.
- Test 561 initially used `[CHAR] ,` which is compile-only. Rewrote as `44 HOLD` (ASCII comma literal) for interactive-mode compatibility.

### Completion Notes List

**Standards verification (Task 1):** Cross-referenced DPANS94 §-numbers against the local compliance doc (`docs/ans-forth-core-compliance.md`, the tiebreaker per Story 10.1). Final cited numbers: `<#` §6.1.0490, `#` §6.1.0030, `#>` §6.1.0040, `#S` §6.1.0050, `HOLD` §6.1.1670, `SIGN` §6.1.2210, `HOLDS` §6.2.1675 (Forth-2012/2014 addition). The epic spec's §6.2.1625 for `HOLDS` was the known typo from Story 10.1's refresh; `pictured.asm` cites §6.2.1675.

**`#` name collision with assembler sigil (discovered mid-implementation):** The existing DEFCODE `#` at `assembler.asm:985` (immediate-operand marker in CODE blocks) collides with the new §6.1 `#`. The story did not call this out. Resolution: the asm `#` entry is the head of the `#` hash bucket (assembler.asm is included later in build order than pictured.asm) and now dispatches at run time — `LD A, (asm_mode); OR A; JP Z, w_PIC_HASH_cf` for the non-asm case; sigil emission as before when `asm_mode == 1`. Both dictionary entries coexist. Epic 12 (wordlists) will migrate the asm entry to an ASSEMBLER wordlist and retire this dispatch hack. Net cost: +4 bytes in `w_HASH_cf`. Regression surface: test 127 (which previously verified the "not in CODE" rejection) had to be updated to match the new dispatch semantics. Number-prefix tests that use `#` inside `CODE...END-CODE` all pass unchanged.

**`#` inline 32-by-8 division (Task 3.5, DEFCODE-inline path chosen):** The shift-subtract loop follows the structural reference of `div_bc_by_e` at `formatting.asm:27` one dimension up — 32 iterations over (A : HL : BC) with BASE read byte-wise via `CP (IY+UserArea.base)` / `SUB (IY+UserArea.base)`. The 40-bit left shift is `SLA C / RL B / RL L / RL H / RLA`; a `JR C` path forces unconditional subtraction when bit 7 of A shifted out (mirrors `ummod_force` in `UM/MOD`). Verified against the largest double input: `-1 -1 <# #S #> TYPE` prints `4294967295` (base 10), `FFFFFFFF` (base 16), and 32 `1`s (base 2). `digit_to_char` is shared with `u_to_str`; `65535 U.` (HEX) and `0 65535 <# #S #> TYPE` (HEX) both emit `FFFF` byte-for-byte.

**`HLD` user variable exposed as DEFCODE** following the `BASE` template (`outer_interpreter.asm:35-39`). This is an antforth extension — DPANS94 does not require `HLD` to be user-visible. Kept per Gforth / SwiftForth precedent and because debugging tools benefit from cursor inspection.

**IP stash strategy (Task 6.2):** New `pictured_ip_stash` scratch cell at the tail of `src/pictured.asm`, consumed by `#`, `#>`, and `HOLDS` (and reachable via `hold_common` which uses PUSH/POP DE to stash IP across its overflow check). Cost: 2 bytes. Chose a fresh cell over reusing `double_ip_stash` to keep the documented "never held across NEXT, never re-entered" invariant file-local.

**Buffer overflow gate (AC #5):** `do_pic_overflow_error` mirrors `do_underflow_error` (direct BDOS + `JP w_ABORT_cf`). Diagnostic string `? Pictured buffer overflow` (26 chars) at `antforth.asm:208`. Test 566 runs `OV41` which emits 41 HOLDs; the 41st triggers the diagnostic and the REPL cleanly recovers to the `ok` prompt. The `EXACT40` sanity (40 HOLDs = full buffer) succeeds. Epic 11 Story 11.4/11.6 will migrate the diagnostic to `THROW -17` per DPANS94 §9.3.5.

**Struct growth regression check (Task 2.4, AC #16):** `UserArea` grew by 42 bytes (2 for `hld` + 40 for `pic_buf`). Ran `make test` and `make test-repl` after the struct-only edit (before adding any pictured words) — PASS 558 / 0 FAIL, matching the post-Story-10.6 baseline. Spot-checked `BASE @`, `STATE @`, `HERE`, `>IN @`, `#TIB @`, `SOURCE-ID @` — all return expected values (BASE=10, STATE=0, HERE=16465 post-growth, >IN=prompt-dependent).

**Adversarial self-review trap hits (Task 8.1):**

- `<#` sentinel arithmetic — `HLD = IY + UserArea.pic_buf + PIC_BUF_SIZE` (one past the last byte). Verified in cold-start `antforth.asm:70-77` and `<#`'s body. 40 HOLDs succeed; 41st aborts.
- `HOLD` underflow guard — fires when `HLD == IY + UserArea.pic_buf` (before decrement). Test 566 confirms exactly 40 HOLDs work; 41st diagnoses.
- `#` inline division — `-1 -1 <# #S #> TYPE` prints `4294967295`; HEX prints `FFFFFFFF`; base-2 prints 32 `1`s. Base 36 emits `Z` (exercises the digit_to_char A-Z branch).
- `#S` emits at least one digit — `0 0 <# #S #> TYPE` outputs `0` (Test 552). The canonical `BEGIN # 2DUP OR 0= UNTIL` body calls `#` *before* the zero test, so `0. 0.` gets one digit.
- `#>` net-zero cell change — `0 0 <# #S #> DEPTH . 2DROP` outputs `2`; `0 65535 <# #S #> TYPE DEPTH .` outputs `655350` (TYPE emits `65535`, DEPTH is 0 post-TYPE). Stack balances.
- `SIGN` consume-on-both-branches — DEFCODE form: `CALL check_underflow; BIT 7,B; JR Z .nonneg; HOLD '-'; .nonneg: POP BC; NEXT`. Both branches pop the cell (`POP BC` is unconditional).
- `HOLDS` direction — `<# S" abc" HOLDS #> TYPE` prints `abc`; canonical DPANS94 body walks `c-addr..c-addr+u-1` back-to-front.
- `UserArea` growth regression — 42-byte struct bump. Test 127 updated (pre-existing test that depended on old `#` behaviour); no other tests affected.
- CCD-3 §-numbers — all 7 word headers cite the verified §-numbers; `HOLDS` uses §6.2.1675, not the epic spec's §6.2.1625 typo.
- `digit_to_char` reuse — `65535 HEX U.` and `0 65535 HEX <# #S #> TYPE` both print `FFFF`; no divergence.
- Cold-start HLD init — new init block at `antforth.asm:70-77` writes `HLD = IY + UserArea.pic_buf + PIC_BUF_SIZE`. Deterministic on every fresh REPL start.
- `.` / `U.` / `.R` regression — `formatting.asm` untouched; grep confirms no `num_buf` reference changed. `1234 .` prints `1234`, `-5 .` prints `-5`, `42 10 .R` prints `        42`.

**Makefile results:** `make test-repl` — 581 PASS, 0 FAIL (558 baseline + 23 new tests = 550..572). Post code-review pass: **587 PASS, 0 FAIL** (6 additional tests 573..578 added: HLD smoke, HOLDS u=0, HOLDS u=1, base-36 digits 10/19/25 → A/J/P).

**Code-review-pass additions (2026-04-22):** four issues raised by `/bmad-bmm-code-review 10.7` were fixed: (M1) added `_bmad-output/planning-artifacts/epics.md` to the Modified file list; (L1) `tests/pictured_tests.fth` test 573 reads `HLD` directly and verifies cold-start init equals `<#` reset; (L2) tests 574/575 cover `HOLDS` u=0 (no-op exit) and u=1 (single-iteration body); (L3) tests 576..578 cover digit_to_char A-Z mid-range (digits 10, 19, 25 → A, J, P) — base-36 digit 35 → Z was already in test 557.

**ROM size delta (Task 6.7, AC #19 informational):** Pre-story `build/antforth.com` = 15812 bytes. Post-story = 16209 bytes. Delta = +397 bytes. Breakdown: +42 bytes `UserArea` BSS (in-image for .COM), ~+13 bytes cold-start HLD init, ~+28 bytes `str_pic_overflow` + length EQU, ~+12 bytes `do_pic_overflow_error`, ~+4 bytes assembler `#` dispatcher, and ~+298 bytes across the 7 pictured words + `HLD` user-var DEFCODE + `(?2)` guard + `hold_common` helper + `pictured_ip_stash` cell. Slightly above the 220-byte ± 50% AC #19 estimate (150..330) once BSS is factored in; within the spirit of the estimate. CCD-4 gate is at Story 10.10, not here.

### File List

**Created:**
- `src/pictured.asm` — 7 pictured-output words (`<#` `#` `#S` `#>` `HOLD` `SIGN` `HOLDS`) + `HLD` user-var DEFCODE + `(?2)` guard + `hold_common` helper + `do_pic_overflow_error` diagnostic + `pictured_ip_stash` scratch cell.
- `tests/pictured_tests.fth` — REPL-piped Forth scenarios (core, base-switching, sign, HOLD/HOLDS, worst-case, overflow, underflow).

**Modified:**
- `src/structures.asm` — added `hld DW 0` + `pic_buf DS PIC_BUF_SIZE` fields to `UserArea` struct.
- `src/constants.asm` — added `PIC_BUF_SIZE EQU 40` constant with E10-D2 citation.
- `src/antforth.asm` — included `pictured.asm` after `double.asm`; added cold-start `HLD` init; defined `str_pic_overflow` + `STR_PIC_OVERFLOW_LEN`.
- `src/assembler.asm` — patched `w_HASH_cf` to dispatch on `asm_mode`: clear → `JP w_PIC_HASH_cf`, set → immediate-marker sigil. Removed the `check_asm_mode` CALL (now inlined as the dispatch branch).
- `Makefile` — added 23 new `test-repl` entries 550..572 (initial pass) plus 6 review-pass entries 573..578 (HLD smoke, HOLDS u=0/1, digit_to_char A-Z mid-range); updated test 127 to reflect new `#` dispatch behaviour (expected diagnostic changed from `not in CODE ?` to `? Stack underflow`).
- `tests/pictured_tests.fth` — review-pass scenarios appended for HLD direct-access, HOLDS boundary cases, and base-36 mid-range digits.
- `docs/ans-forth-core-compliance.md` — date header refreshed to Story 10.7 refresh; Summary `Fully implemented 123 → 129`, `Missing 10 → 4`, `Coverage 123/133 → 129/133` (92.5% → 97.0%); Gap Classification `(b) missing subsystem` 8 → 2; §6.1 Numeric Output sub-section heading updated to "10 implemented, 0 missing. 100% complete."; the six gap rows flipped to Implemented; §6.2 Core Extension bonus `9 of 46 → 10 of 46` with `HOLDS` row added; §6.2 "Will gain via Epic 10" `HOLDS` row marked complete; "Missing subsystem: Pictured numeric output" section rewritten as "Closed subsystem: Story 10.7 ✓ Complete"; Epic-10 closure-plan row for 10.7 marked complete; "big gaps" paragraph updated.
- `_bmad-output/planning-artifacts/epics.md` — Story 12.6 AC extended with a clause requiring removal of the `w_HASH_cf` asm-mode dispatch hack once the `ASSEMBLER` wordlist lands; documents the pre-Story-10.7 form to restore and the verification steps (lines, test 550..572, `tests/number_prefixes_tests.fth`, expected −4 byte delta).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `10-7-pictured-numeric-output-primitives` `ready-for-dev` → `in-progress` → (will be set to `review` by Step 9).
- `_bmad-output/implementation-artifacts/10-7-pictured-numeric-output-primitives.md` — this file; status, tasks/subtasks checkboxes, Dev Agent Record, File List, Change Log.

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-04-22 | Story 10.7 initial implementation — `<#` `#` `#S` `#>` `HOLD` `SIGN` `HOLDS` + `HLD` in `src/pictured.asm`; assembler `#` dispatch patch; 23 new REPL tests (550..572); compliance doc refresh to 97.0% Core. Post-story baseline: 581 PASS, 0 FAIL. | Dev (Opus 4.7) |
| 2026-04-22 | Code-review-pass fixes (`/bmad-bmm-code-review 10.7`): added `epics.md` to File List (M1); 6 new tests 573..578 covering HLD direct access (L1), HOLDS u=0/1 boundaries (L2), and digit_to_char A-Z mid-range (L3). Post-review baseline: 587 PASS, 0 FAIL. | Reviewer (Opus 4.7) |
