# THROW Code Allocation & ABORT-Site Migration Inventory

**Date:** 2026-04-25 (Story 11.1)
**System:** antforth (Z80 Forth for CP/M)
**Scope:** Single source of truth for THROW codes and the Epic 11 ABORT-site
migration plan.
**References:**
- DPANS94 / ANS Forth 1994 §9.3.5 (THROW code table)
- `_bmad-output/planning-artifacts/architecture.md:193-216` (CCD-2, CCD-3)
- `_bmad-output/planning-artifacts/architecture.md:302-306` (E11-D3 migration strategy)
- `_bmad-output/planning-artifacts/architecture.md:471-479` (THROW EQU naming pattern)

---

## (a) Allocation Policy

Per CCD-2 (`architecture.md:193-204`), THROW codes occupy three disjoint ranges:

| Range | Use | Source of citation |
|---|---|---|
| `-1` to `-58` | ANS standard codes (1994 wordset) | `ANS Forth 1994 §9.3.5` |
| `-59` to `-255` | Reserved for post-1994 ANS extensions (e.g., `-69` File-Access) | `ANS Forth 1994 §9.3.5` (Forth 2014 retains) |
| `-256` to `-32767` | antforth-specific extension codes | `antforth extension — see docs/throw-codes.md` |
| `+n` | User-defined per ANS | (never issued by the kernel) |

**Citation discipline (CCD-3, `architecture.md:206-216`):** every EQU in
`src/constants.asm` carries a one-line citation comment using the exact form
above. Standard codes cite `ANS Forth 1994 §9.3.5`; extension codes cite
`antforth extension — see docs/throw-codes.md`.

**Citation-form reconciliation:** the architecture's THROW EQU example at
`architecture.md:476-478` uses `; ANS Forth 2014 §9.3.5`. This story uses
`; ANS Forth 1994 §9.3.5` for §9.3.5 codes because (a) CCD-3's own example
(`architecture.md:208-214`) uses `ANS Forth 1994` for §6 codes, (b) the
existing codebase (`src/double.asm`, `src/system.asm`, etc.) uses
`ANS Forth 1994 §<sec>` for §6 / §8 cites, and (c) §9.3.5 was first
standardised in ANS Forth 1994 — the EXCEPTION wordset predates Forth 2014.
The architecture spec's `2014` example diverges from its own CCD-3 rule;
project convention is `1994`. A future architecture-spec edit should
align lines 476-478 with this convention.

**Standard range is pristine.** No antforth code is allocated in `-1..-255`.
If an ABORT site has no fitting ANS code, the search must cover all 58
standard codes (and the post-1994 reserved extensions like `-69`) before
allocating an extension. Two judgment calls in this inventory exercise
that rule (see §c, allocations for `(` and pictured overflow — both
resolve to ANS codes, no extension needed).

**Reservations inside the antforth-extension range.** Per
`architecture.md:478,606`, code `-257` is reserved for
`THROW_ASM_LOAD_FAIL` (Epic 13 lazy-load assembler). The Epic 11
assembler-error contiguous block therefore starts at `-258`, not `-256`,
leaving `-256` as a one-code gap (reserved for future use) and `-257` as
the architecture-mandated reservation. The block extends through `-272`
post-Story-11.5.6 (Story 11.5 allocated `-258..-269`; Story 11.6 added
`-270` / `-271` for the asm_die residual; Story 11.5.6 split the
generic `-271 range` into `-271 disp range` / `-272 bit range`).

**Naming pattern (architecture.md:471-479):** `THROW_<UPPER_SNAKE_NAME>`
matching the human-readable name from the standard table (or, for
extensions, the assembler-error string).

---

## (b) ANS Standard THROW Codes (DPANS94 / ANS Forth 1994 §9.3.5)

All 58 standard codes, transcribed verbatim. The "Used this epic?" column
flags which codes Epic 11 will reference; the "Migrating from" column points
back to the per-file inventory in §d.

| Code | Name (verbatim) | Used this epic? | Migrating from |
|---:|---|---|---|
| -1  | ABORT | done — Story 11.7 | `system.asm:286` (`w_ABORT_cf` entry; **done — 11.7**) |
| -2  | ABORT" | done — Story 11.7 | `system.asm:139` (`(ABORT")` `.paq_do_abort`; **done — 11.7**) |
| -3  | stack overflow | done — Story 11.5.2 | `system.asm` (`do_overflow_error`; defensive guard at LIT/DOCON/DOVAR/DODOES/push_user_var/NUMBER?-family) |
| -4  | stack underflow | done — Story 11.4 | `system.asm:591` (`do_underflow_error`; migrated) |
| -5  | return stack overflow | no | — |
| -6  | return stack underflow | no | — |
| -7  | do-loops nested too deeply during execution | no | — |
| -8  | dictionary overflow | no | — |
| -9  | invalid memory address | no | — |
| -10 | division by zero | done — Story 11.4 | `arithmetic.asm:126` (`udivmod` guard — covers `/`, `MOD`, `/MOD`); `double.asm:569` (`UM/MOD` guard — covers `SM/REM`, `FM/MOD`, `*/`, `*/MOD`, bare `UM/MOD`) |
| -11 | result out of range | no | — |
| -12 | argument type mismatch | no | — |
| -13 | undefined word | done — Story 11.5 | `compiler.asm:48` (`'`), `compiler.asm:451` (`COMP-ERROR`), `outer_interpreter.asm:226` (`INTERPRET`) |
| -14 | interpreting a compile-only word | done — Story 11.5 | `compiler.asm:469` (`;`), `compiler.asm:641` (`DOES>`), `control_flow.asm:20` (`?COMP`) |
| -15 | invalid FORGET | no | — |
| -16 | attempt to use zero-length string as a name | done — Story 11.5 | `system.asm:80` (`MARKER`), `compiler.asm:398` (`:`), `compiler.asm:577` (`CREATE`), `compiler.asm:624` (`CONSTANT`) |
| -17 | pictured numeric output string overflow | done — Story 11.6 | `pictured.asm:251` (`do_pic_overflow_error`; migrated) |
| -18 | parsed string overflow | no | — |
| -19 | definition name too long | no | — |
| -20 | write to a read-only location | no | — |
| -21 | unsupported operation (e.g., AT-XY on a too-dumb terminal) | no | — |
| -22 | control structure mismatch | no | — |
| -23 | address alignment exception | no | — |
| -24 | invalid numeric argument | no | — |
| -25 | return stack imbalance | no | — |
| -26 | loop parameters unavailable | no | — |
| -27 | invalid recursion | no | — |
| -28 | user interrupt | no | — |
| -29 | compiler nesting | no | — |
| -30 | obsolescent feature | no | — |
| -31 | >BODY used on non-CREATEd definition | no | — |
| -32 | invalid name argument (e.g., TO xxx) | no | — |
| -33 | block read exception | no | — |
| -34 | block write exception | no | — |
| -35 | invalid block number | no | — |
| -36 | invalid file position | no | — |
| -37 | file I/O exception | no | — |
| -38 | non-existent file | no | — |
| -39 | unexpected end of file | no | — |
| -40 | invalid BASE for floating point conversion | no | — |
| -41 | loss of precision | no | — |
| -42 | floating-point divide by zero | no | — |
| -43 | floating-point result out of range | no | — |
| -44 | floating-point stack overflow | no | — |
| -45 | floating-point stack underflow | no | — |
| -46 | floating-point invalid argument | no | — |
| -47 | compilation word list deleted | no | — |
| -48 | invalid POSTPONE | no | — |
| -49 | search-order overflow | done — Story 12.3 | `wordlists.asm:do_search_order_overflow` (SET-ORDER bounds check; **done — 12.3**) |
| -50 | search-order underflow | no | — |
| -51 | compilation word list changed | no | — |
| -52 | control-flow stack overflow | no | — |
| -53 | exception stack overflow | no | — |
| -54 | floating-point underflow | no | — |
| -55 | floating-point unidentified fault | no | — |
| -56 | QUIT | no | — |
| -57 | exception in sending or receiving a character | no | — |
| -58 | unexpected end of input (e.g., during `(` parsing) | done — Story 11.6 | `strings.asm:953` (`(` `.paren_missing`; migrated) |

**Codes referenced by Epic 11 migrations:** 9 standard codes
(`-1`, `-2`, `-4`, `-10`, `-13`, `-14`, `-16`, `-17`, `-58`).

**Architecture-spec-named EQUs:** `architecture.md:432` shows
`THROW_STACK_UNDERFLOW EQU -4` as a constant-naming example, and
`architecture.md:476-478` shows three THROW EQUs by name:
`THROW_UNDEFINED_WORD EQU -13`, `THROW_FCB_EXHAUSTED EQU -69`,
`THROW_ASM_LOAD_FAIL EQU -257`.

**Upfront declarations beyond Epic 11's referenced set.** Per the
`feedback_design_upfront.md` rule, every code that the architecture spec
names as a canonical example is declared in this story even when no
Epic 11 migration references it. That covers:

- `-22 THROW_CONTROL_MISMATCH` — not in `architecture.md` directly, but
  part of the `THROW` design's natural complement (mismatched
  `BEGIN`/`UNTIL`, unmatched `IF`/`THEN`, etc.) and one of the
  most-cited §9.3.5 entries; lands at first compile-flow validation
  story (post-Epic 11). Declared upfront so that future stories don't
  grow the encoding organically.
- `-69 THROW_FCB_EXHAUSTED` — architecture-mandated by
  `architecture.md:477`; first used in Epic 13 (File-Access).
- `-257 THROW_ASM_LOAD_FAIL` — architecture-mandated by
  `architecture.md:478,606`; first used in Epic 13 (lazy-load
  assembler).

**Two judgment-call resolutions (Task 3.2, 3.3):**

- **Pictured-buffer overflow → `-17`, no extension.** DPANS94 §9.3.5
  defines `-17` "pictured numeric output string overflow" — exact semantic
  match to `do_pic_overflow_error` (called from `HOLD`, `#`). No antforth
  extension allocated.
- **`(` reaches end-of-input without `)` → `-58`, no extension.** DPANS94
  §9.3.5 defines `-58` "unexpected end of input". The standard's intent
  covers any parser running past the end of the current input — `(`
  swallowing source until `)` matches that pattern. `-13` (undefined word)
  was rejected — the parser is not looking up a word. No extension
  allocated.

---

## (b.1) Post-1994 ANS Reserved Codes Used by antforth

DPANS94 §9.3.5 reserves `-59..-79` for post-1994 extensions; Forth 2014
populates this block (notably `-69` File-Access, `-70` FREE,
`-71` RESIZE, `-72` ALLOCATE). antforth uses two slots from this
reserved block:

| Code | Forth 2014 semantic | antforth usage | EQU | First-use story |
|---:|---|---|---|---|
| -69 | File-Access wordset (FCB pool exhaustion in Forth 2014's intent — kernel-resident pool) | FCB pool exhausted (`pool_acquire` failure when all 8 slots in-use) | `THROW_FCB_EXHAUSTED EQU -69` (`constants.asm:92`) | Story 13.1 (raise sites in `pool_acquire`) |
| -70 | FREE (memory deallocator) | **Re-purposed**: invalid file-access fileid (closed FID / out-of-range pool ptr / use-after-free) — antforth has no separate FREE wordset, so the slot is re-allocated to a closer-in-spirit "use-after-free" diagnostic | `THROW_FILE_INVALID_FID EQU -70` (`constants.asm:101`) | Story 13.2 (raise site in `fid_validate`) |

**Rationale for the `-70` re-purpose** (Story 13.2 AC #8): the standard
allocates `-70` to FREE (memory-deallocator deallocate-failed), but
antforth currently has no MEMORY wordset (`ALLOCATE` / `FREE` /
`RESIZE`) and no near-term plan to add one. The FID-validation
discipline introduced by Story 13.2 — closed/stale FID detection at
every File-Access entry — is conceptually a "use-after-free" of an FCB
slot, which is structurally analogous to FREE's memory-deallocator
context. Re-using `-70` for this related-by-mechanism condition keeps
the ANS-reserved block dense and avoids burning an antforth-extension
code in the `-256..-32767` block. If antforth later acquires a MEMORY
wordset, the FREE / FID-invalid pair must be split (likely by moving
FID-invalid to a fresh antforth-extension code and reclaiming `-70`
for FREE).

The dev-pass alternative discussed in Story 13.2 AC #8 — picking a
fresh antforth-extension code (e.g., `-273 THROW_FILE_INVALID_FID`) —
was considered and rejected: the `-70` re-purpose is the project
lead's stated default and the rationale above (related-by-mechanism)
is stronger than the "fresh code is cleaner" counter-argument.

---

## (c) antforth Extension Codes (Range -256 to -32767)

All extensions allocated by Epic 11 sit in a contiguous block
`-258..-272` for grep-ability (Epic 11.5 / Story 11.5.6 added one
code by splitting -271). Every extension comes from the assembler
(`src/assembler.asm`) — the kernel's ABORT sites otherwise resolve to ANS
codes. `-256` is unallocated (reserved gap). `-257` is reserved by
`architecture.md:478,606` for `THROW_ASM_LOAD_FAIL` (Epic 13 lazy-load
assembler) and is declared upfront in `src/constants.asm` even though no
Epic 11 site references it.

**Drafting reconciliation:** the Story 11.1 inventory said the `asm_die`
fan-in was "8 shorthand `asm_err_*` entry points". Re-reading the source
shows **9 entry points** route through `asm_die`: the 8 `asm_err_*` plus
`asm_bad_operand` (which is named without the `asm_err_` prefix but is
structurally identical — `LD HL, str / LD B, len / JP asm_die`). Story
11.5 migrated those 9 plus 3 additional non-fan-in callers
(`asm_err_bare_int`, `asm_err_unresolved`, `asm_err_already`) for 12
contiguous codes (`-258..-269`). Story 11.5's adversarial review
discovered a second-tier `asm_die` residual: two non-fan-in callers
(`check_asm_mode` and `asm_range_err`) had also been missed by Story
11.1's grep-of-`JP\sw_ABORT_cf` inventory because they routed through
`asm_die` rather than ABORT directly. Story 11.6 retires those two with
`-270 THROW_ASM_NOT_IN_CODE` and `-271 THROW_ASM_RANGE` (the latter
later split by Story 11.5.6 — see Note below), extending the
contiguous block to `-258..-272`. The two-tier reconciliation is
recorded here per the "no drafting-spec errors slip into the deliverable"
discipline.

| Code | Name | Trigger | ABORT site | Migration story |
|---:|---|---|---|---|
| -257 | THROW_ASM_LOAD_FAIL         | (reserved by `architecture.md:478,606`; first used Epic 13 lazy-load assembler) | (reserved — not a current ABORT site) | (Epic 13) |
| -258 | THROW_ASM_BAD_OPERAND       | bad operand to asm op                                 | `assembler.asm:281` (`asm_die` ← `asm_bad_operand`)         | **done — 11.5** |
| -259 | THROW_ASM_NESTED            | nested `CODE` block                                   | `assembler.asm:281` (`asm_die` ← `asm_err_nested`)          | **done — 11.5** |
| -260 | THROW_ASM_NONAME            | `CODE` parsed empty name                              | `assembler.asm:281` (`asm_die` ← `asm_err_noname`)          | **done — 11.5** |
| -261 | THROW_ASM_ORPHAN_LABEL      | orphan label (declared, never resolved this CODE)     | `assembler.asm:281` (`asm_die` ← `asm_err_orphan`)          | **done — 11.5** |
| -262 | THROW_ASM_LABEL_AFTER_END   | label declared after `END-CODE`                       | `assembler.asm:281` (`asm_die` ← `asm_err_label_after`)     | **done — 11.5** |
| -263 | THROW_ASM_JR_RANGE          | `JR` displacement out of range                        | `assembler.asm:281` (`asm_die` ← `asm_err_jr_range`)        | **done — 11.5** |
| -264 | THROW_ASM_TOO_LABELS        | local-label table exhausted                           | `assembler.asm:281` (`asm_die` ← `asm_err_too_labels`)      | **done — 11.5** |
| -265 | THROW_ASM_TOO_FIXUPS        | fixup table exhausted                                 | `assembler.asm:281` (`asm_die` ← `asm_err_too_fixups`)      | **done — 11.5** |
| -266 | THROW_ASM_EQU_IN_CODE       | `EQU` used outside `CODE` block (or vice versa)       | `assembler.asm:281` (`asm_die` ← `asm_err_equ_in_code`)     | **done — 11.5** |
| -267 | THROW_ASM_BARE_INT          | tagged operand expected, bare integer received        | `assembler.asm:337` (`asm_err_bare_int` own JP)             | **done — 11.5** |
| -268 | THROW_ASM_UNRESOLVED        | unresolved label NAME at `END-CODE`                   | `assembler.asm:381` (`asm_print_error_with_name` ← `asm_err_unresolved`) | **done — 11.5** |
| -269 | THROW_ASM_ALREADY_FIXED     | already-fixed label NAME (double `FIX`)               | `assembler.asm:381` (`asm_print_error_with_name` ← `asm_err_already`)    | **done — 11.5** |
| -270 | THROW_ASM_NOT_IN_CODE       | inline-assembler word used outside `CODE` block       | `assembler.asm:472` (`check_asm_mode` direct raise)                      | **done — 11.6** |
| -271 | THROW_ASM_DISP_RANGE        | `+D` 8-bit displacement out of range                  | `assembler.asm:1204` (`asm_disp_range_err` direct raise)                 | **done — 11.5.6** |
| -272 | THROW_ASM_BIT_RANGE         | `BIT,`/`RES,`/`SET,` bit number not in 0..7           | `assembler.asm:1210` (`asm_bit_range_err` direct raise)                  | **done — 11.5.6** |

**Note on -271 / -272 split (Story 11.5.6 closure).** The original
Story 11.6 allocation collapsed two structurally-different conditions
onto a single `-271 THROW_ASM_RANGE`: `+D`'s 8-bit-signed displacement
check (`assembler.asm:1143/:1146/:1151`) and the `BIT,/RES,/SET,`
bit-number 0..7 check (`assembler.asm:3095/:3132/:3164`). The user
diagnostic `error -271: range` was generic and carried no locality hint.
Story 11.5.6 split this — see Story 11.5.6 file at
`_bmad-output/implementation-artifacts/11.5-6-throw-271-semantic-split.md`.
Post-split, `-271 THROW_ASM_DISP_RANGE` raises `error -271: disp range`
and `-272 THROW_ASM_BIT_RANGE` raises `error -272: bit range`.

**Subgroup justification:** Story 11.5 migrated 12 extensions (`-258..-269`)
covering the `asm_die` fan-in plus the three non-fan-in callers that did
their own raise (`asm_err_bare_int`, `asm_err_unresolved`, `asm_err_already`).
Story 11.6 added `-270` / `-271` for the two non-fan-in `asm_die` callers
that were missed by Story 11.1's enumerated inventory (Story 11.5 D1
deviation forward-pointer). Story 11.5.6 then split the generic `-271`
into `-271 disp range` / `-272 bit range` for diagnostic locality. All
15 assembler-error codes form one contiguous grep-able block. Rationale:
assembler errors are structurally compiler-state errors — they fire
while the assembler is parsing source and building an in-progress CODE
definition. Story 11.5 (compiler/dictionary) covered the bulk; Story 11.6
(strings/I-O + asm-die residual) covered the two latecomers plus the
standard-code migrations for `(` missing-`)` / pictured overflow; Story
11.5.6 split `-271` per the F4 LOW-deferred closure.

---

## (d) Per-File ABORT-Site Inventory

Survey method: `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm` plus
the entry point of `w_ABORT_cf` itself (line 286 of `system.asm` post-
Story-11.7 — was 260 at Story 11.1 dev-pass; line numbers drift across
intervening migrations, see Story 11.7 Completion Notes). Re-run during
dev pass on 2026-04-25 — 17 grep hits, all matching the pre-canned story
inventory. The 18th row (the entry point) is added explicitly.

Cross-checks:
- `grep -nE 'CALL\s+check_underflow' src/*.asm` returns 50 hits, of
  which 1 is a comment, leaving **49 actual `CALL` sites**. Every
  one converges on `do_underflow_error`. Migration to `-4 THROW`
  (Story 11.4) replaced the one ABORT, not 49 sites.
- `asm_die` (`assembler.asm:281`) is the single ABORT site for 9 shorthand
  entry points (`asm_bad_operand`, `asm_err_nested`, `asm_err_noname`,
  `asm_err_orphan`, `asm_err_label_after`, `asm_err_jr_range`,
  `asm_err_too_labels`, `asm_err_too_fixups`, `asm_err_equ_in_code`).
- `asm_print_error_with_name` (`assembler.asm:381`) is the single ABORT
  site for 2 callers (`asm_err_unresolved`, `asm_err_already`).

Inventory grouped by source file (alphabetical), then by line number.

### `src/assembler.asm`

| Line | Word / context | Trigger | Proposed THROW code | Migration story |
|---:|---|---|---|---|
| 281 | `asm_die` (fan-in: 9 shorthand entry points — see §c subgroup justification) | various assembler errors | antforth extension `-258..-266` (one per entry point) | **done — 11.5** (asm_die body retired by Story 11.6) |
| 337 | `asm_err_bare_int` (own JP, prints HL) | tagged operand expected, bare integer received | antforth extension `-267` | **done — 11.5** |
| 381 | `asm_print_error_with_name` (fan-in: `asm_err_unresolved`, `asm_err_already`) | unresolved / already-fixed label | antforth extension `-268`, `-269` | **done — 11.5** |
| 472 | `check_asm_mode` (Story 11.5 D1 deviation — missed by Story 11.1's grep-of-`JP\sw_ABORT_cf` because it routed through `asm_die`) | inline-assembler word used outside `CODE` block | antforth extension `-270 THROW_ASM_NOT_IN_CODE` | **done — 11.6** |
| 1204 | `asm_disp_range_err` (Story 11.5 D1 deviation — same reason; was `asm_range_err`, split by Story 11.5.6) | `+D` 8-bit displacement out of range | antforth extension `-271 THROW_ASM_DISP_RANGE` | **done — 11.6 / 11.5.6** |
| 1210 | `asm_bit_range_err` (Story 11.5.6 — split sibling of `asm_disp_range_err`) | `BIT,`/`RES,`/`SET,` bit number not in 0..7 | antforth extension `-272 THROW_ASM_BIT_RANGE` | **done — 11.5.6** |

### `src/compiler.asm`

| Line | Word / context | Trigger | Proposed THROW code | Migration story |
|---:|---|---|---|---|
| 48  | `'` (tick) `.tick_notfound` (DEFWORD body) | `'` parsed an undefined word | `-13` | **done — 11.5** |
| 398 | `:` `.colon_no_name` | `:` parsed an empty name | `-16` | **done — 11.5** |
| 451 | `COMP-ERROR` `.comp_err_abort` (fan-in from `INTERPRET`'s compile path) | undefined word during compilation | `-13` | **done — 11.5** |
| 469 | `;` (compile-state guard) | `;` outside compile mode | `-14` | **done — 11.5** |
| 577 | `CREATE` `.create_no_name` | `CREATE` parsed an empty name | `-16` | **done — 11.5** |
| 624 | `CONSTANT` `.const_no_name` | `CONSTANT` parsed an empty name | `-16` | **done — 11.5** |
| 641 | `DOES>` (compile-state guard) | `DOES>` outside compile mode | `-14` | **done — 11.5** |

### `src/control_flow.asm`

| Line | Word / context | Trigger | Proposed THROW code | Migration story |
|---:|---|---|---|---|
| 20 | `?COMP` (generic compile-only guard) | compile-only word interpreted | `-14` | **done — 11.5** |

### `src/outer_interpreter.asm`

| Line | Word / context | Trigger | Proposed THROW code | Migration story |
|---:|---|---|---|---|
| 226 | `INTERPRET` `.interp_error` | interpreted token failed both word-find and number-parse | `-13` | **done — 11.5** |

### `src/pictured.asm`

| Line | Word / context | Trigger | Proposed THROW code | Migration story |
|---:|---|---|---|---|
| 251 | `do_pic_overflow_error` (fan-in: `HOLD`, `#`, `SIGN`, `HOLDS` via `hold_common`) | pictured buffer would underrun | `-17` | **done — 11.6** |

### `src/strings.asm`

| Line | Word / context | Trigger | Proposed THROW code | Migration story |
|---:|---|---|---|---|
| 953 | `(` `.paren_missing` | `(` reached end-of-input without closing `)` | `-58` | **done — 11.6** |

### `src/system.asm`

| Line | Word / context | Trigger | Proposed THROW code | Migration story |
|---:|---|---|---|---|
| 80  | `MARKER` `.marker_no_name` | `MARKER` parsed an empty name | `-16` | **done — 11.5** |
| 139 | `(ABORT")` `.paq_do_abort` | runtime `(ABORT")` with truthy flag | `-2` | **done — 11.7** |
| 286 | `w_ABORT_cf` (the entry point itself) | direct `ABORT` invocation | `-1` | **done — 11.7** |
| 591 | `do_underflow_error` (fan-in: every `check_underflow{,_2,_3,_4}` caller — 49 callers) | parameter-stack underflow | `-4` | **done — 11.4** (`LD BC, -4 / JP w_THROW_cf.kernel_entry`) |

### Divisor-zero guards added by Story 11.4 (not pre-existing ABORT sites)

| File | Line | Word | Trigger | THROW code |
|---|---:|---|---|---|
| `src/arithmetic.asm` | 126 | `udivmod` (covers `/`, `MOD`, `/MOD` via `sdivmod`) | divisor = 0 | `-10` (done — Story 11.4) |
| `src/double.asm` | 569 | `UM/MOD` (covers `SM/REM`, `FM/MOD`, `*/`, `*/MOD`, bare `UM/MOD`) | divisor = 0 | `-10` (done — Story 11.4) |

### Inventory totals

- 17 `JP w_ABORT_cf` / `DW w_ABORT_cf` sites surveyed (18 pre-Story-11.4;
  `system.asm:559` (Story 11.1 line; now `:591`)'s `JP w_ABORT_cf` was
  retired by Story 11.4 in favour of `LD BC, -4 / JP w_THROW_cf.kernel_entry`);
  Story 11.7 retired the final 2 (`exception.asm:420` and `system.asm:131`,
  pre-Story-11.7 lines; now inlined / retargeted at `exception.asm:412+`
  and `system.asm:139` respectively); zero instruction-line ABORT-chain
  references remain in the kernel.
- 1 entry-point row (`w_ABORT_cf` itself at `system.asm:286` post-Story-
  11.7; was `:260` pre-Story-11.7; retargeted to `-1 THROW` body by
  Story 11.7 — label preserved as ABORT's DEFCODE entry).
- 2 divisor-zero guard rows (added by Story 11.4 — `udivmod`, `UM/MOD`).
- **17 surviving ABORT sites + 1 entry point + 2 divisor-zero guards →
  20 rows total post-Story-11.4 → all retired post-Story-11.7.**

---

## (e) Migration Ordering Proposal

Rationale (E11-D3, `architecture.md:302-306`): leaf primitives migrate
first (touch a single primitive's failure path with one THROW); compiler
and dictionary words migrate next (touch parser state); strings and
buffer-shaped I/O migrate after that (touch input source); `ABORT` and
`ABORT"` retarget last (so legacy `JP w_ABORT_cf` paths don't double-throw
during the transition).

Story 11.7 is the capstone (**done**): by the time `ABORT`/`ABORT"`
retargeted to `-1 THROW` / `-2 THROW`, every internal caller was already
on `THROW`. Post-Story-11.7 no site references `w_ABORT_cf` as a `JP`
target; only the entry-point label itself (`system.asm:286`) survives,
as the entry to ABORT's `-1 THROW` raise. FR19 (internal errors raise
THROW codes) and FR20 (ABORT/ABORT" become THROW wrappers) are both
fully delivered post-Story-11.7.

| Migration story | Theme | Sites migrated | Codes used |
|---|---|---|---|
| **11.4** | Stack / arithmetic / memory leaf primitives | `system.asm:559→591` (`do_underflow_error`) — done; `arithmetic.asm:130` (`udivmod` divisor=0 guard) — done; `double.asm:569` (`UM/MOD` divisor=0 guard) — done | `-4`, `-10` |
| **11.5** | Compiler / dictionary / control flow / assembler-internal state | `compiler.asm:48`, `compiler.asm:398`, `compiler.asm:451`, `compiler.asm:469`, `compiler.asm:577`, `compiler.asm:624`, `compiler.asm:641`, `control_flow.asm:20`, `outer_interpreter.asm:226`, `system.asm:80` (`MARKER`), `assembler.asm:281` (`asm_die` fan-in), `assembler.asm:337` (`asm_err_bare_int`), `assembler.asm:381` (`asm_print_error_with_name` fan-in) | `-13`, `-14`, `-16`, `-258..-269` |
| **11.6** | Strings / I-O / buffer-shaped errors + asm-die residual cleanup | `strings.asm:953` (`(` missing-`)`) — **done**; `pictured.asm:251` (pictured buffer overflow) — **done**; `assembler.asm:472` (`check_asm_mode`, Story 11.5 D1) — **done**; `assembler.asm:1204` (`asm_disp_range_err`, ex-`asm_range_err`, Story 11.5 D1; later split by Story 11.5.6) — **done**; `asm_die` body retired | `-17`, `-58`, `-270`, `-271` |
| **11.5.6** | F4 LOW-deferred closure: split generic `-271 range` into per-condition codes | `assembler.asm:1204` (`asm_disp_range_err`, +D path) — **done**; `assembler.asm:1210` (`asm_bit_range_err`, BIT/RES/SET path) — **done** | `-271` (semantic), `-272` (new) |
| **11.7** | `ABORT` / `ABORT"` retarget — capstone (**done**) | `system.asm:131→139` (`(ABORT")` `.paq_do_abort`) → `-2 THROW` (**done**); `system.asm:260→286` (`w_ABORT_cf` entry) → `-1 THROW` (**done**); `exception.asm:420` (`.throw_uncaught` recovery-chain delegate) → inlined chain at `exception.asm:412+` (**done**) | `-1`, `-2` |

Each row in §d is tagged with its target story; the cross-reference rule
holds (a site assigned to Story 11.x matches the AC topic of that story).

**Per-migration test discipline:** every story 11.4–11.7 adds at least one
REPL-piped Forth test of the form `' WORD CATCH . CR` asserting the
catalogued THROW code lands on the data stack (per
`feedback_repl_tests_preferred.md` — REPL tests, not assembly threads).
The ordering above is the contract that lets those tests be written before
the migration commit lands.
