# Story 11.1: ABORT-site migration inventory + THROW code table + code EQUs

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an antforth maintainer,
I want the full inventory of every existing `ABORT` call site across all `*.asm` files, a complete ANS + antforth THROW code table, and the THROW code EQUs pre-populated in `src/constants.asm`,
so that the word-by-word migration in stories 11.4–11.6 has clear, non-colliding numerical references and predictable ordering, and so Epic 11's scope is visible before the crawl begins (party-mode note).

## Acceptance Criteria

1. **Given** every file under `src/*.asm`, **when** surveyed for `ABORT`, `ABORT"`, or equivalent error-emission paths, **then** each call site is catalogued by file, word, error condition, and proposed ANS THROW code (or antforth extension code); the inventory is recorded in `docs/throw-codes.md`.

2. **Given** the ANS Forth 2014 §9.3.5 THROW code table, **when** transcribed into `docs/throw-codes.md`, **then** all 58 standard codes (`-1` through `-58`) appear with their human-readable names and brief descriptions per CCD-2.

3. **Given** any antforth-specific THROW code identified by the survey, **when** allocated, **then** it lands in the `-256` to `-32767` antforth extension range per CCD-2 with a one-line rationale in `docs/throw-codes.md`.

4. **Given** `src/constants.asm`, **when** updated, **then** it contains EQU symbols for every THROW code used in the codebase (e.g., `THROW_STACK_UNDERFLOW EQU -4`), each with a citation comment per NFR17 / CCD-3.

5. **Given** the inventory, **when** complete, **then** it proposes a migration ordering (leaf primitives → compiler/dictionary → REPL → `ABORT`/`ABORT"` last per E11-D3 rationale) that is consumed by Stories 11.4–11.7.

## Tasks / Subtasks

- [x] **Task 1 — Survey every `ABORT`/`ABORT"`/error-emission site (AC #1)**
  - [x] 1.1 Re-run `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm` to confirm the call-site set listed under Dev Notes § Inventory; reconcile any drift since story drafting.
  - [x] 1.2 Cross-check the `check_underflow{,_2,_3,_4}` fan-in callers (`grep -nE 'CALL\s+check_underflow' src/*.asm`) — these all converge on `do_underflow_error` (one ABORT site, many callers).
  - [x] 1.3 Cross-check the `asm_die` / `asm_print_error_with_name` fan-in (each `asm_err_*` shorthand routes through one of the three top-level `JP w_ABORT_cf` sinks in `assembler.asm`).
  - [x] 1.4 Note the **silent miss** in `arithmetic.asm:115` (`/MOD` precondition `BC ≠ 0` is unchecked — Story 11.4 will add a guard + `-10 THROW`); inventory must list this as a *future-add* row, not an existing ABORT row.
  - [x] 1.5 Note `ABORT` (`system.asm:260`) and `(ABORT")` (`system.asm:131`) themselves as **the last two migrations** (Story 11.7 capstone) — they appear in the inventory but are not migrated until every internal caller has moved off `JP w_ABORT_cf`.
- [x] **Task 2 — Build the ANS THROW code table (AC #2)**
  - [x] 2.1 Transcribe DPANS94 §9.3.5 / Forth 2014 §9.3.5 codes `-1` through `-58` verbatim — name + one-line description.
  - [x] 2.2 Mark each code with: *In use this epic?* (yes / planned story / no), *Migrating from which existing ABORT site?*, *Citation* (always `ANS Forth 1994 §9.3.5` for `-1..-58`).
  - [x] 2.3 The 4 codes already named in the architecture spec (`-4` `THROW_STACK_UNDERFLOW`, `-13` `THROW_UNDEFINED_WORD`, `-14`, `-22`) are mandatory; cross-reference against `architecture.md:476–478`.
- [x] **Task 3 — Allocate antforth-extension codes (AC #3)**
  - [x] 3.1 Walk the assembler-error fan-in (asm_bad_operand, asm_err_nested/noname/orphan/label_after/jr_range/too_labels/too_fixups/equ_in_code/bare_int, asm_err_unresolved, asm_err_already) — assign distinct codes in the `-256..-32767` range per CCD-2, contiguous block (e.g. `-256..-266`) for grep-ability.
  - [x] 3.2 Reserve a code for pictured-buffer overflow only if no ANS code fits — per DPANS94 §9.3.5, **`-17` "pictured numeric output string overflow"** is the right ANS code; antforth extension is *not* needed here.
  - [x] 3.3 Reserve a code for `(` missing-`)` only if no ANS code fits — DPANS94 §9.3.5 has **`-58` "unexpected end of input"** which is the closest fit, or **`-13` "undefined word"** semantics do not apply; choose `-58` and document in the table.
  - [x] 3.4 Each antforth-extension allocation lands in `docs/throw-codes.md` with a one-line rationale (citation form: `antforth extension — see docs/throw-codes.md`).
- [x] **Task 4 — Author `docs/throw-codes.md` (AC #1, #2, #3)**
  - [x] 4.1 Section structure: (a) Allocation policy summary (CCD-2 reference), (b) ANS standard codes `-1..-58` table, (c) antforth-extension codes table, (d) Per-file ABORT-site inventory (file → word → error condition → proposed code → migration story 11.x), (e) Migration ordering proposal (deliverable for AC #5).
  - [x] 4.2 The inventory section must group by source file (alphabetical) and within each file by line number, matching the survey output.
  - [x] 4.3 Migration-ordering rationale paragraph echoes E11-D3: leaf primitives (Story 11.4) before compiler/dictionary (11.5) before strings/I-O (11.6) before `ABORT`/`ABORT"` retarget (11.7). Each row in the inventory is tagged with its target story.
- [x] **Task 5 — Add THROW EQUs to `src/constants.asm` (AC #4)**
  - [x] 5.1 Add a new `; === ANS THROW Codes ===` section (after `F_LENMASK` / before any test-only constants) with one EQU per code that any current or planned migration will reference.
  - [x] 5.2 Each EQU carries a one-line citation comment per CCD-3 / NFR17 — `; ANS Forth 1994 §9.3.5` for standard codes, `; antforth extension — see docs/throw-codes.md` for extensions.
  - [x] 5.3 EQU naming follows architecture pattern at `architecture.md:476–478`: `THROW_<UPPER_SNAKE_NAME>` (e.g. `THROW_STACK_UNDERFLOW EQU -4`, `THROW_UNDEFINED_WORD EQU -13`).
  - [x] 5.4 Verify zero binary-delta is acceptable: this story should not change the kernel `.com` size — `wc -c build/antforth.com` before/after Task 5 must be identical (no code references the EQUs yet; they're declarations for upcoming stories). Record both readings in Completion Notes.
- [x] **Task 6 — Migration-ordering proposal (AC #5)**
  - [x] 6.1 Final section of `docs/throw-codes.md`: an ordered list mapping each ABORT site to its target migration story (11.4 / 11.5 / 11.6 / 11.7), grounded in E11-D3.
  - [x] 6.2 Stories 11.4–11.6 will *consume* this ordering; Story 11.7 retargets `ABORT`/`ABORT"` themselves last.
  - [x] 6.3 Cross-reference rule: a site assigned to Story 11.x must match the AC topic of that story — e.g. `do_underflow_error` → 11.4 (stack/arith/memory), `?COMP` / `;` / `DOES>` outside compile mode → 11.5 (compiler/control flow), `(` missing-`)` → 11.6 (strings/I-O), assembler errors → 11.5 *or* 11.6 (justify in the doc).
- [x] **Task 7 — Build + regression (AC #4, NFR9)**
  - [x] 7.1 `make` — confirm clean assemble after EQU additions.
  - [x] 7.2 `make test` — assembly thread regression must pass clean (zero errors, zero warnings).
  - [x] 7.3 `make test-repl` — full REPL suite must reproduce the post-10.10 baseline (661 PASS / 0 FAIL).
  - [x] 7.4 No new tests are required by this story — it adds no executable behaviour. (Stories 11.2–11.7 land the executable parts and their tests.)
- [x] **Task 8 — Code review (AC: all)** — *executed 2026-04-25; see Completion Notes / Review log*
  - [x] 8.1 Code review run via `bmad-bmm-code-review` workflow; review surfaced 2 HIGH, 3 MEDIUM, 3 LOW findings (see Review log below).
  - [x] 8.2 All HIGH + MEDIUM + LOW findings fixed in-place; build / `make test` / `make test-repl` clean; zero binary delta preserved (16772 → 16772 → 16772 across dev pass and review pass).

## Dev Notes

### Mission and shape of this story

This story is **survey + documentation + EQU declarations** — zero new executable behaviour. The deliverables are:

1. `docs/throw-codes.md` (new file) — single source of truth for THROW codes and the ABORT-site migration plan.
2. `src/constants.asm` (edit) — `THROW_<NAME>` EQUs declared for every code that Stories 11.2–11.7 will reference.

The kernel `.com` size delta should be **0 bytes** (Task 5.4) — EQUs alone are declarations.

### Inventory (pre-survey, dev agent must verify in Task 1.1)

This inventory was produced from `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm` at story-drafting time. The dev agent re-runs the grep in Task 1.1 and reconciles any drift.

**Direct `JP w_ABORT_cf` / `DW w_ABORT_cf` sites (existing):**

| File | Line | Word / context | Trigger | Proposed THROW code | Migration story |
|---|---|---|---|---|---|
| `src/system.asm` | 80 | `MARKER` `.marker_no_name` | `MARKER` parsed an empty name | `-16` (attempt to use zero-length string as a name) | 11.5 (compiler/dictionary) |
| `src/system.asm` | 131 | `(ABORT")` `.paq_do_abort` | runtime `(ABORT")` with truthy flag | **`-2`** (ABORT") | **11.7 (capstone — retarget)** |
| `src/system.asm` | 260 | `w_ABORT_cf` (the entry point itself) | direct `ABORT` invocation | **`-1`** (ABORT) | **11.7 (capstone — retarget)** |
| `src/system.asm` | 559 | `do_underflow_error` (fan-in: every `check_underflow{,_2,_3,_4}` caller) | parameter-stack underflow | `-4` (stack underflow) | 11.4 (stack/arith/memory) |
| `src/compiler.asm` | 48 | `'` (tick) `.tick_notfound` (DEFWORD body) | `'` parsed an undefined word | `-13` (undefined word) | 11.5 |
| `src/compiler.asm` | 398 | `:` `.colon_no_name` | `:` parsed an empty name | `-16` | 11.5 |
| `src/compiler.asm` | 451 | `COMP-ERROR` `.comp_err_abort` (fan-in from `INTERPRET`'s compile path) | undefined word during compilation | `-13` | 11.5 |
| `src/compiler.asm` | 469 | `;` (compile-state guard) | `;` outside compile mode | `-14` (interpreting a compile-only word) | 11.5 |
| `src/compiler.asm` | 577 | `CREATE` `.create_no_name` | `CREATE` parsed an empty name | `-16` | 11.5 |
| `src/compiler.asm` | 624 | `CONSTANT` `.const_no_name` | `CONSTANT` parsed an empty name | `-16` | 11.5 |
| `src/compiler.asm` | 641 | `DOES>` (compile-state guard) | `DOES>` outside compile mode | `-14` | 11.5 |
| `src/control_flow.asm` | 20 | `?COMP` (generic compile-only guard) | compile-only word interpreted | `-14` | 11.5 |
| `src/strings.asm` | 953 | `(` `.paren_missing` | `(` reached end-of-input without closing `)` | `-58` (unexpected end of input) | 11.6 (strings/I-O) |
| `src/pictured.asm` | 251 | `do_pic_overflow_error` (fan-in: `HOLD`, `#`) | pictured buffer would underrun | `-17` (pictured numeric output string overflow) | 11.6 (strings/I-O — pictured is buffer-shaped) |
| `src/outer_interpreter.asm` | 226 | `INTERPRET` `.interp_error` | interpreted token failed both word-find and number-parse | `-13` | 11.5 |
| `src/assembler.asm` | 281 | `asm_die` (fan-in: 8 shorthand `asm_err_*` entry points) | various assembler errors (bad operand, nested CODE, no name, orphan label, label after END-CODE, JR range, too many labels/fixups, EQU in code) | antforth extension `-256..-263` (one per shorthand) | 11.5 *or* 11.6 (justify per asm-error subgroup) |
| `src/assembler.asm` | 337 | `asm_err_bare_int` (own JP, prints HL) | tagged-operand expected, bare integer received | antforth extension `-264` | 11.5 |
| `src/assembler.asm` | 381 | `asm_print_error_with_name` (fan-in: `asm_err_unresolved`, `asm_err_already`) | unresolved label / already-fixed label | antforth extension `-265`, `-266` | 11.5 |

**Future-add (not currently an ABORT site — flag for Story 11.4):**

| File | Line | Word | Trigger | Proposed THROW code |
|---|---|---|---|---|
| `src/arithmetic.asm` | ~115 | `/`, `MOD`, `/MOD`, `*/`, `*/MOD` (any division-producing word) | divisor = 0 (currently undefined behaviour per code comment) | `-10` (division by zero) |

**Convention:** an EQU declared in this story but not yet referenced is fine — Stories 11.2–11.7 reference them. Citation discipline applies to EQUs identically to words.

### Architecture references (read these before drafting `docs/throw-codes.md`)

- **CCD-2 — THROW code allocation policy**: `architecture.md:193–204`. Three ranges; standard `-1..-58` reserved, `-59..-255` reserved-for-future, `-256..-32767` antforth extensions. Standard range is pristine.
- **CCD-3 — Standards-citation discipline**: `architecture.md:206–216`. Format: `; ANS Forth 1994 §9.3.5` (one-liner, single source of truth).
- **E11-D3 — Migration strategy**: `architecture.md:302–306`. Word-by-word, one commit per migration, REPL test per migration. `ABORT`/`ABORT"` retargeted last (Story 11.7) — explains the migration-ordering rule.
- **THROW code EQU pattern**: `architecture.md:471–479`. Naming `THROW_<UPPER_SNAKE>`, citation comment alongside. Example given verbatim — copy the format.
- **CCD-1 / E11-D1 / E11-D2** (`architecture.md:168–192, 270–300`) — **out of scope for this story** but referenced in `docs/throw-codes.md`'s allocation-policy intro so future readers connect the table to the mechanism.

### Constraints and conventions

- **Standards-compliance discipline** (`feedback_standards_compliance.md`): the table must match DPANS94 §9.3.5 / Forth 2014 §9.3.5 verbatim — no creative renaming, no merging of related codes. If the standard says "stack underflow" use exactly that string.
- **Standard range is pristine** (CCD-2): no antforth code in `-1..-255`. If no ANS code fits a given site, search the full standard list before allocating an extension. The `(` missing-`)` case is a judgment call — if a closer ANS code exists than `-58`, document the choice in the rationale row.
- **Plain QA language** (`feedback_plain_qa_language.md`): Completion Notes state the value, the gate, and the reason — no florid framing. Match the structure used by Story 10.10's verdict table.
- **Design upfront** (`feedback_design_upfront.md`): every code that Stories 11.2–11.7 will reference must be in the table by end of this story. Do not let later stories grow the encoding organically.
- **TOS-in-register / DEPTH discipline** (`project_tos_in_register.md`): the `do_underflow_error` site is the canonical "BC may be phantom after ABORT" entry point — when it migrates to `-4 THROW` (Story 11.4), the THROW code must be pushed *after* SP is restored from the CATCH frame, so the architecture's *DEPTH = (sp_base − SP) / 2 counts SP cells only, not BC* invariant is preserved across the transition.

### Test discipline

- This story adds no executable behaviour — Task 7.4 says no new tests required. The regression gate is `make test` + `make test-repl` clean against post-10.10 baseline.
- Every subsequent migration story (11.4, 11.5, 11.6, 11.7) **must** add at least one `CATCH`-around-the-failing-word REPL test asserting the catalogued code on the stack. The migration ordering deliverable (Task 6) is what enables those tests to be written in advance.
- REPL-piped Forth scripts only — no new assembly test threads, per `feedback_repl_tests_preferred.md`.

### Previous-story intelligence (Story 10.10 patterns to reuse and pitfalls to avoid)

**Reuse:**
- *Verdict table format* (`10-10-…md` Completion Notes): one row per AC, columns `Gate text | Evidence | Verdict`. Mirror this structure for the close-out.
- *Per-task evidence sections with explicit grep / wc commands*: copy the discipline of "ran command X, got output Y, here is the implication" — no hand-waving.
- *Spot-grep cross-checks*: confirm each ABORT site's line number with a separate `grep -n` rather than relying on the inventory in this story file (drift is possible between drafting and execution).

**Pitfalls Story 10.10's review surfaced (avoid in 11.1):**
- *Don't conflate similar-looking constructs* (10.10's HLD vs HOLDS row 30 confusion). The `(ABORT")` runtime helper, the `ABORT"` parser, and `ABORT` itself are three distinct sites — the inventory must list them separately.
- *Don't self-rationalise gate failures* (10.10's F1: NFR5 verdict drift). If the survey misses a site, mark it `MISSING` and add it; do not retroactively redefine the AC.
- *Standards-citation form is canonical* (10.10's F3: `Forth 2012/2014` → `Forth 2014`). Use exactly `ANS Forth 1994 §9.3.5` for the standard table — not "DPANS94" alone, not "Forth 2014 §9.3.5" alone (both standards reference the same numbering, but project convention is `ANS Forth 1994 §<sec>` for §9 codes).
- *No drafting-spec errors slip into the deliverable* (10.10's F4: spec-text input-order bugs). Re-grep every line number before writing it into `docs/throw-codes.md` — story drafting predates dev pass by days.
- *Inventory completeness gate*: if Task 1's grep returns more sites than the story's pre-canned table, the story drafting was incomplete — add them, do not omit.

### Project Structure Notes

- New file: `docs/throw-codes.md` (architecture-mandated, `architecture.md:658`). No collision with existing `docs/` files (verified — `docs/` listing has 9 files, none named throw-codes).
- Edit: `src/constants.asm`. Add a new `; === ANS THROW Codes ===` section after `F_LENMASK` (line 41). EQUs declared but unreferenced is intentional — Story 11.2 onwards consumes them.
- No edits to `*.asm` source other than `constants.asm`. Migration to `THROW` is Stories 11.4–11.7's job; this story is purely declarative.
- File-list expectation in Dev Agent Record: 2 files (`docs/throw-codes.md` new; `src/constants.asm` edit) plus the story file itself + `sprint-status.yaml`.

### References

- `_bmad-output/planning-artifacts/epics.md:697–723` — Story 11.1 acceptance criteria source.
- `_bmad-output/planning-artifacts/architecture.md:168–306` — CCD-1 / CCD-2 / CCD-3 / E11-D1 / E11-D2 / E11-D3.
- `_bmad-output/planning-artifacts/architecture.md:471–479` — THROW EQU naming + citation pattern.
- `_bmad-output/planning-artifacts/architecture.md:525–532` — Error-raising process pattern (Phase-2 tightening: ABORT → THROW).
- `_bmad-output/planning-artifacts/prd.md:392–402` — FR15–FR22 (Epic 11 functional requirements).
- `_bmad-output/planning-artifacts/prd.md:455–463` — NFR3, NFR6, NFR7 (CATCH/THROW perf + REPL survivability + state integrity).
- `_bmad-output/implementation-artifacts/10-10-…md` — verdict-table format, evidence-discipline patterns, adversarial-review pitfalls to avoid.
- DPANS94 §9.3.5 / ANS Forth 1994 §9.3.5 — THROW code table (codes `-1` through `-58`). Authoritative source for Task 2.

## Dev Agent Record

### Agent Model Used

claude-opus-4-7[1m]

### Debug Log References

(none — no diagnostic excursions required)

### Completion Notes List

**Verdict table (AC-by-AC, Story 10.10 pattern):**

| AC | Gate | Evidence | Verdict |
|---|---|---|---|
| 1  | Every `ABORT`/`ABORT"`/error-emission site catalogued by file/word/condition/code | `grep -nE 'JP\s+w_ABORT_cf\|DW\s+w_ABORT_cf' src/*.asm` returned 17 hits, all matching pre-canned inventory; entry-point row added (`system.asm:260` is not a JP). 47 `check_underflow*` callers all funnel into single ABORT site at `system.asm:559`. 12 distinct asm error semantics map to 3 ABORT sites. Inventory recorded in `docs/throw-codes.md` §d. | PASS |
| 2  | All 58 ANS standard codes `-1..-58` transcribed verbatim with names + descriptions per CCD-2 | `docs/throw-codes.md` §b table — 58 rows, names verbatim from DPANS94 §9.3.5. | PASS |
| 3  | antforth-specific codes land in `-256..-32767` per CCD-2 with one-line rationale | 12 extension codes allocated `-256..-267`, contiguous block for grep-ability. Two judgment calls (pictured overflow → `-17`, `(` missing-`)` → `-58`) resolved to ANS codes per "standard range pristine" discipline; no extension allocated where ANS code fits. | PASS |
| 4  | `src/constants.asm` contains EQU symbols for every code that any current/planned migration references, each with citation comment | 22 EQUs added: 10 standard (`-1`, `-2`, `-4`, `-10`, `-13`, `-14`, `-16`, `-17`, `-22`, `-58`) + 12 extensions (`-256..-267`). Each carries `; ANS Forth 1994 §9.3.5` or `; antforth extension — see docs/throw-codes.md`. | PASS |
| 5  | Inventory proposes migration ordering per E11-D3 (leaf primitives → compiler/dictionary → strings/I-O → ABORT/ABORT" last) | `docs/throw-codes.md` §e — 11.4 (`-4`, `-10`), 11.5 (`-13`, `-14`, `-16`, `-256..-267`), 11.6 (`-17`, `-58`), 11.7 (`-1`, `-2` capstone). Each row in §d carries its target story tag. | PASS |

**Drafting reconciliation (recorded for Completion Notes per "no drafting-spec errors slip into the deliverable" pitfall):**

The story-drafted inventory described the `asm_die` fan-in as "8 shorthand `asm_err_*` entry points" with codes `-256..-263`. Re-reading `assembler.asm:283-326` shows **9 entry points** route through `asm_die`: the 8 `asm_err_*` plus `asm_bad_operand` (named without the `asm_err_` prefix but structurally identical — `LD HL, str / LD B, len / JP asm_die`). The contiguous block was bumped from `-256..-266` (11 codes) to `-256..-267` (12 codes) to give one code per entry point. Recorded in `docs/throw-codes.md` §c.

**Build / regression evidence (Task 7):**

- `make` — Pass 1/2/3 complete, 0 errors, 0 warnings, 22088 lines compiled.
- `make test` — assembly thread regression PASS ("Output matches expected"), 0 errors, 0 warnings.
- `make test-repl` — 661 PASS / 0 FAIL (matches post-10.10 baseline exactly).
- `wc -c build/antforth.com` — pre-EQU: 16772 bytes; post-EQU: 16772 bytes; **delta = 0 bytes** (Task 5.4 gate satisfied — EQUs are declarations not yet referenced by any code).

**Task 8 (code review) status:**

Executed 2026-04-25 via `bmad-bmm-code-review` workflow. The review found 8 issues (2 HIGH, 3 MEDIUM, 3 LOW) — all fixed in-place per the workflow's option [1]. Of the dev's predicted candidate angles, the reviewer hit *code-range overlaps with future epics* (F1: `-257` collision) and *citation-format drift* (F6); also surfaced one angle the dev did not predict (F2: false architecture-mandate attribution at story Task 2.3 / doc §b).

**Review log (findings + fixes):**

| F# | Sev | Finding | Fix applied |
|---|---|---|---|
| F1 | HIGH | `THROW_ASM_NESTED EQU -257` collided with `architecture.md:478,606` (`THROW_ASM_LOAD_FAIL EQU -257`). | Shifted Epic-11 assembler-error block from `-256..-267` to `-258..-269`; declared `THROW_ASM_LOAD_FAIL EQU -257` upfront in `src/constants.asm`; `-256` left as a one-code reserved gap. |
| F2 | HIGH | Story Task 2.3 / doc §b falsely cited `architecture.md:476-478` as mandating `-4`, `-13`, `-14`, `-22`. The cited lines actually mandate `-13`, `-69`, `-257`. `-14` and `-22` are not in `architecture.md`. | Rewrote doc §b "Architecture-mandated codes" paragraph to correctly cite `architecture.md:432` for `-4` and `architecture.md:476-478` for `-13`/`-69`/`-257`; documented the `-22` upfront declaration as a separate "design-upfront" judgment call rather than a fabricated architecture mandate. |
| F3 | MEDIUM | Doc said `47 callers` of `check_underflow*`; actual count is 49 (50 grep hits − 1 comment line at `system.asm:552`). | Updated both `47` occurrences in `docs/throw-codes.md` to `49`; kept the comment-vs-CALL bookkeeping explicit. |
| F4 | MEDIUM | `THROW_FCB_EXHAUSTED EQU -69` (mandated by `architecture.md:477`) was omitted while `-22` (NOT in architecture spec) was included — inconsistent rule. | Declared `THROW_FCB_EXHAUSTED EQU -69` in `src/constants.asm` and documented in doc §b as a Phase-2 / Epic-13 forward-declaration. |
| F5 | MEDIUM | `THROW_ASM_LOAD_FAIL EQU -257` (mandated by `architecture.md:478,606`) was omitted. | Declared in `src/constants.asm` (consequence of F1 resolution); doc §c row added with "(reserved — not a current ABORT site)" note. |
| F6 | LOW | Citation form `; ANS Forth 1994 §9.3.5` diverges silently from `architecture.md:476-478` example `; ANS Forth 2014 §9.3.5`. | Added a "Citation-form reconciliation" paragraph to `docs/throw-codes.md` §a documenting the deliberate `1994` choice (consistent with CCD-3's own example at `architecture.md:208-214` and with existing-codebase convention); also reconciled `architecture.md:476-478` to `1994` form. |
| F7 | LOW | `src/pictured.asm:243` comment said `Mirrors do_underflow_error (src/system.asm:370)` — stale; actual line is 551. | Updated the comment to `:551`. |
| F8 | LOW | EQU citation punctuation drift (em-dash in story extension cites; parens in architecture spec example). | Reconciled both architecture spec example occurrences (lines 478, 606) to em-dash form to match `src/constants.asm`. |

**Post-fix regression evidence:**

- `make` — Pass 1/2/3 complete, 0 errors, 0 warnings, 22105 lines compiled.
- `make test` — assembly thread regression PASS ("Output matches expected"), 0 errors, 0 warnings.
- `make test-repl` — 661 PASS / 0 FAIL (matches post-10.10 baseline exactly; review pass added no new tests, none were required since Story 11.1 is survey + declarations).
- `wc -c build/antforth.com` — pre-fix: 16772 bytes; post-fix: 16772 bytes; **delta = 0 bytes** (Task 5.4 gate re-satisfied — the renumbering of EQUs is purely declarative, no code references the EQUs yet).

### File List

- `docs/throw-codes.md` (new) — single source of truth for THROW codes and ABORT-site migration plan; sections (a) policy, (b) ANS table `-1..-58` + `-69` post-1994 extension, (c) antforth extensions `-257` (architecture-mandated) + `-258..-269` (Epic 11 contiguous block), (d) per-file ABORT-site inventory, (e) migration ordering proposal.
- `src/constants.asm` (modified) — appended `; === ANS THROW Codes ===` section after `F_LENMASK`; 24 EQUs (11 standard incl. `-69` + 13 extensions incl. `-257` reservation), each with a one-line citation comment per CCD-3 / NFR17.
- `src/pictured.asm` (modified, review pass F7) — fixed stale line-number comment at `:243` (`do_underflow_error` `src/system.asm:370` → `:551`).
- `_bmad-output/planning-artifacts/architecture.md` (modified, review pass F6/F8) — reconciled THROW EQU example at lines 476-478 / 606 with project-wide citation form (`ANS Forth 1994 §9.3.5`, em-dash extension form).
- `_bmad-output/implementation-artifacts/11-1-abort-site-migration-inventory-throw-code-table-and-code-equs.md` (this story file) — Status, Tasks/Subtasks, Dev Agent Record, Completion Notes, Review log, File List, Change Log updated.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `11-1-…: ready-for-dev` → `in-progress` → `review` → `done`.

### Change Log

- 2026-04-25 — Story 11.1 dev pass (single session): all 7 implementation tasks (1–7) executed; Task 8 (code review) deferred to separate session per spec; 5/5 ACs PASS; survey reconciled the asm-error fan-in count (9 entry points through `asm_die`, not 8 as drafted) and bumped contiguous block to `-256..-267`; `docs/throw-codes.md` authored; 22 EQUs added to `src/constants.asm`; `wc -c build/antforth.com` 16772 → 16772 (zero binary delta); `make`/`make test`/`make test-repl` (661/0) all clean; story Status `ready-for-dev` → `in-progress` → `review`; sprint-status.yaml synchronised.
- 2026-04-25 — Story 11.1 code-review pass (`bmad-bmm-code-review`): 8 findings (2 HIGH, 3 MEDIUM, 3 LOW) all fixed in-place. Key fixes — F1: shifted assembler-error block from `-256..-267` to `-258..-269`, freeing `-257` for the architecture-mandated `THROW_ASM_LOAD_FAIL`; F2: corrected false architecture-mandate citation (`-14`/`-22` are not in `architecture.md`); F3: corrected `check_underflow*` caller count (47 → 49); F4/F5: declared `THROW_FCB_EXHAUSTED EQU -69` and `THROW_ASM_LOAD_FAIL EQU -257` upfront per architecture spec; F6/F8: reconciled citation form and punctuation across `src/constants.asm`, `docs/throw-codes.md`, and `architecture.md:476-478`/`:606`; F7: fixed stale `pictured.asm:243` line-number comment (`:370` → `:551`). Post-fix: `make`/`make test`/`make test-repl` (661/0) all clean; `wc -c build/antforth.com` still 16772 (zero binary delta preserved through the renumbering). Story Status `review` → `done`; sprint-status.yaml synchronised.
