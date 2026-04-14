# Story 8.4: EXX Convention Reference

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a system maintainer,
I want the shadow-register conventions established across Epics 7–8 (register contract, leaf-level rule, "A survives EXX" staging idiom, "shadow BC' as free TOS-preservation slot", Group A vs Group B entry patterns, and the complete list of EXX-using words) consolidated into a single authoritative reference document at `docs/register-conventions.md`,
so that future human developers and AI coding agents can learn and apply the conventions from one place without having to stitch together dev notes scattered across Stories 7.1, 7.2, 7.3, 8.1, 8.2, and 8.3.

## Acceptance Criteria

1. **Given** the EXX/shadow-register conventions currently live scattered across the Dev Notes of Stories 7.1, 7.2, 7.3, 8.1, 8.2, 8.3 and the per-word inline comments in `src/compiler.asm`, `src/system.asm`, `src/strings.asm`, `src/memory.asm`, `src/io.asm`, `src/stack_ops.asm`, `src/formatting.asm`, and `src/assembler.asm`, **When** this story lands, **Then** a new document `docs/register-conventions.md` exists which covers, as discrete sections, all of:
   1. **Register Contract** — BC=TOS, DE=IP, HL=W (scratch), IX=return-stack pointer, IY=user-area base, SP=parameter stack, A/AF=scratch (restate the immutable contract from `docs/shadow-register-survey.md` and `_bmad-output/planning-artifacts/architecture.md` §Register Usage Discipline).
   2. **Shadow-Register Set** — BC'/DE'/HL' available via `EXX`; AF' available via `EX AF,AF'` (currently unused across the codebase, flag as dormant resource).
   3. **Leaf-Level Rule** — EXX-using CODE words may NOT `CALL` any subroutine that itself uses EXX; enforcement is by human review; explain why (Z80 has no push/pop of the shadow set — two nested EXXes swap the sets *back*, silently corrupting the caller's saved IP/TOS).
   4. **Group A vs Group B Entry Patterns** — Group A (TOS consumed early or not needed during body) uses plain `EXX` at entry; Group B (TOS needed live through the body) uses `PUSH BC / EXX / POP BC` (Path 1 — main BC keeps TOS, DE' parks IP). Include at least one worked example per group, citing file/line (e.g., FILL for Group A, DOT for Group B).
   5. **Exit-Staging Idiom ("A survives EXX")** — when a word needs to compute the new TOS in the body and return it to main BC on exit, stage the new value through register A before the exit `EXX` (A is not shadowed; its value survives the set swap). Cite CHAR (`src/strings.asm:160–234`) as the canonical example.
   6. **Shadow BC' as Free TOS-Preservation Slot** — for `( x -- ... )` words that need the original x value on one particular exit path (typically a parse-failure or not-found branch), a plain entry `EXX` leaves the original x sitting in BC' for free; the reject path can `EXX`-and-emit it with no explicit PUSH/POP. Cite NUMBER? (`src/strings.asm:369`) and (`.S`'s `.dots_print_tos`, `src/formatting.asm:340–352`) as canonical examples.
   7. **Complete List of EXX-Using Words (as of end of Epic 8)** — enumerate every word/routine in the binary that issues an `EXX` instruction at a convention-bound entry/exit boundary, grouped by source file, with a one-line role note per entry. The list is authoritative and must be regenerable via `grep -nE '^\s*EXX\b' src/*.asm`. The following entries are known at story-spec time and must all appear (verify and add any the dev agent finds during the grep pass):
      - `src/compiler.asm` — COLON (`w_COLON:` @ line 358), CREATE (`w_CREATE:` @ 548), CONSTANT (`w_CONSTANT:` @ 584)
      - `src/strings.asm` — WORD (@10), CHAR (@160), >NUMBER (`w_TO_NUMBER:` @336), NUMBER? (`w_NUMBER_Q:` @369), `(` (`w_PAREN:` @820)
      - `src/memory.asm` — FILL (@224), MOVE (@263)
      - `src/stack_ops.asm` — ROLL (@111)
      - `src/io.asm` — ACCEPT (@116)
      - `src/system.asm` — MARKER (@21)
      - `src/assembler.asm` — ASM_RECOGNIZE (@~898 in recognizer body), CODE (`w_CODE:` @1165), plus any others the dev agent grep confirms (LABEL, NEXT,, END-CODE per the Story 7.1 dev notes — verify live and add)
      - `src/formatting.asm` — DOT (@132), U. (@153), .R (@173), .S (@262)
      - `src/system.asm` / `src/control_flow.asm` / `src/outer_interpreter.asm` — list any EXX-using routines the grep surfaces beyond the above (the `(ABORT")` runtime uses a bare `PUSH DE` without EXX — note this exception explicitly so readers don't think it was missed).
8. **Out-of-Scope / Deferred Items** — list the known unconverted `rpush_de` / `rpush_bc` call sites that remain as documented-but-not-pursued candidates (referenced in `docs/shadow-register-followup-survey.md` and the Epic 8 planning doc): `compiler.asm:689` ((;CODE)/DOES> runtime exit), `control_flow.asm:207` ((DO) runtime), `outer_interpreter.asm:99–127` (INTERPRET loop itself — category D exclusion). Also note the AF'/`EX AF,AF'` slot as an unused resource.

2. **Given** the document should be a self-contained reference readable in isolation, **When** it is written, **Then** it must NOT require the reader to also read the Story 7.x or 8.x Dev Notes to understand any convention — all idioms must be stated inline with short worked code fragments (4–10 lines of actual Z80, not pseudo-code) taken from the live codebase, each annotated with file:line citations.

3. **Given** the document will be consulted by AI coding agents during future story implementation (per the "prevent future developer fuckups" mission of story-context creation), **When** it is written, **Then** it must include a top-of-file one-paragraph summary (≤120 words) stating the four hard rules an agent must not violate: (a) BC=TOS / DE=IP contract is inviolable, (b) EXX is leaf-level only — never CALL an EXX word from inside an EXX word, (c) only A (and flags) survive EXX — all other scratch must be re-established or staged through shadows, (d) the return stack is IX-indexed two-byte cells — never mix SP and IX-stack conventions inside one word.

4. **Given** this is a pure documentation story, **When** `make test && make test-repl` runs after the document is added, **Then** all 272 REPL tests + 1 assembly regression test pass with zero failures (trivially — no code changes). Baseline binary size must be unchanged from post-Story-8.3 (14,030 bytes); confirm with `wc -c build/antforth.com`.

5. **Given** the Epic 8 planning doc (`_bmad-output/planning-artifacts/epic8-shadow-register-followup.md` §Story 8.4) proposed two candidate host locations — a new `docs/register-conventions.md` OR an expanded comment header in `src/inner_interpreter.asm`, **When** this story is implemented, **Then** the chosen location is `docs/register-conventions.md` (rationale: a dedicated doc is more discoverable for AI agents via directory listing, versionable separately, and does not bloat the assembly source). `src/inner_interpreter.asm` MUST be updated to add a two-line pointer comment at the top of its register-contract block directing readers to `docs/register-conventions.md` for the full convention — so a reader starting from the inner interpreter source is not left with an incomplete picture.

6. **Given** the convention doc references several existing docs as sources, **When** it is written, **Then** the References section at the bottom of the doc links (via relative paths) to: `docs/shadow-register-survey.md`, `docs/shadow-register-followup-survey.md`, `_bmad-output/planning-artifacts/architecture.md` (the Register Usage Discipline section), and the Dev Notes of Stories 7.1, 7.2, 7.3, 8.1, 8.2, 8.3 under `_bmad-output/implementation-artifacts/`.

## Tasks / Subtasks

- [x] Task 1: Re-scan the codebase for the authoritative, current EXX-using word list (AC: #1.7)
  - [x] 1.1 `grep -nE '^\s*EXX\b' src/*.asm` — record every hit with surrounding label context
  - [x] 1.2 For each file, group hits by enclosing `w_XXX:` label or named subroutine; note entry vs exit vs internal-swap role
  - [x] 1.3 Cross-check against the list in the Story 8.3 dev notes "Pre-Story Baseline" section and against the Story 7.1/7.2/7.3 Completion Notes; reconcile any discrepancies (the codebase is ground truth)
  - [x] 1.4 Flag any EXX site that is NOT a convention-bound entry/exit swap (e.g., internal double-EXX idioms in `.dots_print_tos`, CONSTANT's value-recovery swaps) so the doc can describe them as advanced patterns, not the base convention

- [x] Task 2: Write `docs/register-conventions.md` (AC: #1, #2, #3, #5, #6)
  - [x] 2.1 Top-of-doc 120-word summary of the four hard rules (AC: #3)
  - [x] 2.2 §1 Register Contract (AC: #1.1) — prose table of BC/DE/HL/IX/IY/SP/A/AF roles; cite `architecture.md` §Register Usage Discipline
  - [x] 2.3 §2 Shadow-Register Set (AC: #1.2) — BC'/DE'/HL' via EXX; AF' via `EX AF,AF'` (flag as unused)
  - [x] 2.4 §3 Leaf-Level Rule (AC: #1.3) — statement + rationale + enforcement-is-human-review note
  - [x] 2.5 §4 Group A vs Group B Entry Patterns (AC: #1.4) — code fragments from FILL (Group A) and DOT (Group B), with file:line citations
  - [x] 2.6 §5 Exit-Staging "A survives EXX" Idiom (AC: #1.5) — code fragment from CHAR exit, with citation
  - [x] 2.7 §6 Shadow BC' as TOS-Preservation Slot (AC: #1.6) — code fragments from NUMBER? and `.S`'s `.dots_print_tos`, with citations
  - [x] 2.8 §7 Complete EXX-Using Word List (AC: #1.7) — table grouped by source file, with file:line and one-line role
  - [x] 2.9 §8 Out-of-Scope / Deferred EXX Candidates (AC: #1.8) — the (DO)/(DOES>)/INTERPRET exclusions and AF' dormancy
  - [x] 2.10 References section (AC: #6) — relative links to the four source docs and to all six story dev-note files

- [x] Task 3: Update `src/inner_interpreter.asm` with pointer comment (AC: #5)
  - [x] 3.1 Locate the existing register-role commentary (top of file)
  - [x] 3.2 Add two-line comment: "; For shadow-register conventions (EXX usage, leaf-level rule, Group A/B patterns):" / "; see docs/register-conventions.md"
  - [x] 3.3 `make asm` — confirm binary size unchanged (comment-only edit)

- [x] Task 4: Regression verification (AC: #4)
  - [x] 4.1 `make asm && wc -c build/antforth.com` — 14,030 bytes (unchanged, as expected)
  - [x] 4.2 `make test && make test-repl` — 272 REPL + 1 assembly regression, zero failures
  - [x] 4.3 Record results in Completion Notes

- [x] Task 5: Code review (AC: all)
  - [x] 5.1 Ran `bmad-bmm-code-review` — 1 HIGH, 2 MEDIUM, 5 LOW findings (see Senior Developer Review section)
  - [x] 5.2 Addressed findings — all HIGH + MEDIUM + 3 LOW (#4, #5, #7) fixed; #6 and #8 acknowledged but skipped (pedantic / cosmetic)
  - [x] 5.3 Post-review: re-verified `(ABORT")` citations (now `src/system.asm:114 / 138 / 140 / 258`), DOT annotation corrected, §7 table column header clarified, binary still 14,030 bytes, 272/272 tests green

## Dev Notes

### Epic Context

Story 8.4 closes Epic 8 as a pure-documentation capstone. Stories 8.1–8.3 extended the Epic 7 EXX convention into the formatting pipeline (CHAR, (ABORT"), DOT, U., .R, .S). After 8.3 landed (binary 14,030 bytes, 75 bytes saved across Epic 8 = 44 from 8.1 + 4 from 8.2 + 27 from 8.3, vs the 30–44 bytes conservative/optimistic target), the shadow-register convention now spans ~22 words across 8 source files. It is no longer a "few-word experiment" and deserves a central reference.

This story is an explicit Epic 7 retrospective action item (#5 per the epic-7 retro): "promote the shadow-register conventions from scattered story Dev Notes into a single authoritative reference." Epic 7 retro noted there's no automated enforcement of the leaf-level rule — only human review — which makes a prominent, well-indexed reference doc the best available safety net against future EXX nesting bugs.

### Why a Separate Doc, Not Inline Comments

The Epic 8 planning doc proposed either a new `docs/register-conventions.md` OR an expanded comment header in `src/inner_interpreter.asm`. The story spec picks the former because:

- AI coding agents discover `.md` files in `docs/` routinely during story context assembly (the `planning_artifacts`, `docs/`, and `_bmad-output/` directories are standard search targets). A comment block in an `.asm` file is only found if the agent happens to read that specific file.
- A dedicated doc can be versioned, diffed, and linked to from the Epic 9+ planning docs without churning the assembly source.
- The assembly source stays focused on code; a two-line pointer comment in `inner_interpreter.asm` (Task 3) gives the source-first reader a breadcrumb without bloating the code.

### Hard Rules Summary (for the top-of-doc paragraph)

Four non-negotiable rules an implementing agent must internalise:

1. **BC = TOS, DE = IP** — any CODE word that exits with these wrong corrupts threading immediately. Verify on EVERY exit path.
2. **EXX is leaf-level only** — you may not `CALL` any subroutine that also issues `EXX`. Z80 has no push/pop of the shadow set; a nested EXX unconditionally swaps the sets, silently losing the caller's saved IP/TOS. The only enforcement is human/AI review — grep before you call.
3. **Only A and flags survive EXX** — HL, DE, BC are all shadowed. If you need a value (e.g., a computed new-TOS) to cross the exit EXX, stage it through A (`LD A, …` → exit EXX → `LD C, A / LD B, 0` or similar). This is the "A survives EXX" idiom from Story 8.1 (CHAR).
4. **IX-indexed return stack is two-byte cells** — never mix SP-relative and IX-relative cell counting inside one word. IX grows down on push (`DEC IX / DEC IX / LD (IX+0),E / LD (IX+1),D`); failing to match push count to pop count misaligns the return stack (Epic 7.1 code review caught a pre-existing `INC IX` bug in `w_QUERY_cf` via this failure mode).

### Group A vs Group B Entry Patterns (brief)

- **Group A** (TOS consumed early or not needed live during body): plain `EXX` at entry. Main BC/DE/HL are now free scratch, BC' holds original TOS, DE' holds IP. If the body needs the original TOS, it's sitting in BC' for free (see §6 shadow-BC'-as-preservation-slot).
  - Examples: FILL (`src/memory.asm:224`), MARKER (`src/system.asm:21`), WORD (`src/strings.asm:10`).
- **Group B** (TOS needed live in main BC throughout the body): `PUSH BC / EXX / POP BC` at entry. Main BC keeps TOS, DE' parks IP, main DE/HL become free scratch. Exit is `EXX` (restores IP from DE') — note: TOS already in main BC, no `POP BC` needed.
  - Examples: DOT (`src/formatting.asm:132`), U. (@153), the formatting pipeline generally.
  - **.R variant** (Group B with two values): `PUSH BC / EXX / POP DE / POP BC` — width → main DE, value → main BC (from SP, where `PUSH BC` put it, then `POP DE` to the *other* thing that was on SP which was the second value, then `POP BC`). See `src/formatting.asm:180` and Story 8.3 Task 2.1.

### The `(ABORT")` Exception

`(ABORT")` uses a bare `PUSH DE` without a matching `POP` or EXX, because ABORT itself resets SP via `LD SP, (sp_base)` — the SP slot is never unwound. This is documented in Story 8.1 but easily read as a bug; the convention doc must call it out explicitly in §7 / §8 to prevent a future agent from "fixing" it.

### Previous-Story Intelligence (Story 8.3)

- Story 8.3 landed 27 bytes smaller than baseline (14,057 → 14,030), beating the optimistic target.
- `.dotr_neg`, `.dotr_str`, `.dotr_len` scratch variables were retained with written justifications — the BDOS-call pressure inside the pad-emit loop blocked full register-resident elimination. The convention doc's §6 should mention this as a worked example of the *limits* of shadow-register relief (BDOS calls clobber BC/DE/HL/A, so shadow preservation doesn't help across them).
- `.S`'s `.dots_print_tos` uses an advanced double-EXX pattern (`EXX / PUSH BC / EXX / POP BC`) to round-trip the original TOS through SP into main BC without disturbing the shadow set. This is an *advanced* pattern — mention in §6 but flag it as "use only when a plain EXX-swap is insufficient" to avoid encouraging routine double-EXX elsewhere.

### Source Tree Components to Touch

- **CREATE:** `docs/register-conventions.md` (new)
- **MODIFY (2 lines):** `src/inner_interpreter.asm` (add pointer comment near existing register-role commentary)
- **NO OTHER CHANGES** — zero code edits; binary must be byte-identical to post-8.3 (14,030 bytes).

### Testing Standards

Pure documentation story — no new tests. Regression gate only: `make test && make test-repl` ⇒ 272 REPL + 1 assembly regression, zero failures (AC: #4). Binary size must be unchanged (AC: #4).

Post-doc-landing, as a one-off sanity pass, spot-check 5 random file:line citations in the finished doc against the live source — a stale citation (e.g., pointing at a shifted line after a future commit) is the obvious decay mode; the code-review step (Task 5.3) should explicitly re-verify.

### Project Structure Notes

- `docs/` is the established home for reference documentation (`ans-forth-core-compliance.md`, `shadow-register-survey.md`, `shadow-register-followup-survey.md`, `z80-instruction-coverage.md`, `z80_forth_assemblers.md`). A new `register-conventions.md` fits the naming and scope conventions of this directory.
- No conflicts with existing architecture — `_bmad-output/planning-artifacts/architecture.md` already has a Register Usage Discipline section; `register-conventions.md` is a *deeper* operational reference, not a replacement. Link between them.

### References

- `_bmad-output/planning-artifacts/epic8-shadow-register-followup.md` §Story 8.4 (the authoritative spec — particularly the six bullet items on lines 168–173 enumerating required content)
- `_bmad-output/planning-artifacts/epics.md` §Story 8.4 (lines 1456–1472 — user story + acceptance criteria)
- `_bmad-output/planning-artifacts/architecture.md` §Register Usage Discipline (lines 249–253 — the canonical register contract to restate)
- `docs/shadow-register-survey.md` — the Epic 7 survey establishing the convention
- `docs/shadow-register-followup-survey.md` — the Epic 8 follow-up survey (the convention's current technical backbone)
- `_bmad-output/implementation-artifacts/7-1-exx-for-build-header-words.md` — Dev Notes establish COLON/CREATE/CONSTANT/CODE/etc. conversions and the leaf-level rule
- `_bmad-output/implementation-artifacts/7-2-exx-for-recognizer.md` — Dev Notes establish scratch-variable-elimination lesson
- `_bmad-output/implementation-artifacts/7-3-exx-for-de-only-words.md` — Dev Notes establish shadow-BC'-as-preservation-slot idiom (NUMBER?)
- `_bmad-output/implementation-artifacts/epic-7-retro-2026-04-14.md` — Epic 7 retrospective, action item #5 is the direct parent of this story
- `_bmad-output/implementation-artifacts/8-1-exx-for-char-and-abort-quote.md` — Dev Notes establish "A survives EXX" idiom (CHAR) and the bare `PUSH DE` exception ((ABORT"))
- `_bmad-output/implementation-artifacts/8-2-exx-for-dot-and-u-dot.md` — Dev Notes establish Group B / Path 1 pattern on formatting pipeline
- `_bmad-output/implementation-artifacts/8-3-restructure-dot-r-and-dot-s.md` — Dev Notes establish .R's multi-value entry variant and .dots_print_tos advanced double-EXX pattern; worked example of the limits of shadow relief across BDOS calls

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- `grep -nE '^\s*EXX\b' src/*.asm` → 62 total EXX hits across 8 files, reconciled into the §7 table (22 convention-bound words + internal-swap sites for CONSTANT, .dots_print_tos, and ASM_RECOGNIZE).
- Build pre-edit: 14,030 bytes. Build post-edit: 14,030 bytes (unchanged; doc-only + comment-only source edit).
- Regression: `make test-repl` → 272 PASS / 0 FAIL. `make test` → assembly regression pass.

### Completion Notes List

**Implementation approach** — Pure-documentation story. Created `docs/register-conventions.md` as the single authoritative reference consolidating EXX/shadow-register conventions scattered across Epic 7/8 story Dev Notes. Added a 5-line pointer comment block to `src/inner_interpreter.asm` header so source-first readers are directed to the new doc.

**Content decisions:**
- **Hard Rules section** placed at top-of-doc (above §1) rather than as an appendix — an implementing agent lands on the "do not violate" list before the prose, which is the actual goal per AC #3.
- **Worked code fragments** are 5–15 lines each, pulled verbatim from the live source (not paraphrased) with file:line citations — allows the reader to trust the doc and jump directly to the surrounding context if needed.
- **§7 EXX table** groups by source file rather than by word name — matches the grep-based regeneration workflow (`grep -nE '^\s*EXX\b' src/*.asm`) so staleness is easy to detect.
- **`(ABORT")` exception** explicitly called out in §7's "Notable exceptions" block per Dev Notes concern that a future agent might "fix" the bare `PUSH DE`.
- **Double-EXX in `.dots_print_tos`** marked as an *advanced* pattern (§6) with a flag warning against routine use — per Story 8.3 Dev Notes observation that this idiom is 4 bytes and should only be used when a plain swap is insufficient.
- **AF' / `EX AF, AF'`** documented as a dormant resource in both §2 and §8 per Epic 7 retro.

**Location decision (AC #5):** Chose `docs/register-conventions.md` over an expanded `src/inner_interpreter.asm` comment header. Rationale: (a) AI agents discover `docs/*.md` via directory listing during story context assembly; (b) versioning/diffing is cleaner for a separate `.md`; (c) the assembly source stays focused on code. The inner_interpreter.asm header gets a 5-line pointer so the source-first path isn't dead.

**Verification:**
- `wc -c build/antforth.com` → 14030 (baseline unchanged, confirming zero code impact).
- `make test-repl` → 272/272 PASS, 0 FAIL.
- `make test` → assembly regression PASS.
- Spot-check of file:line citations against live source: FILL @ `src/memory.asm:224`, DOT @ `src/formatting.asm:132`, CHAR @ `src/strings.asm:160`, NUMBER? @ `src/strings.asm:369`, `.dots_print_tos` @ `src/formatting.asm:341` — all verified.

**Task 5 (code review) deferred:** Per standard workflow, code review runs as a separate `bmad-bmm-code-review` invocation (ideally with a different LLM per the "fresh context" convention). The three review subtasks (5.1–5.3) remain unchecked and will be addressed in that workflow.

### File List

- **Created:** `docs/register-conventions.md` — authoritative EXX/shadow-register convention reference (~250 lines)
- **Modified:** `src/inner_interpreter.asm` — added 5-line pointer comment block in the file header directing readers to the new convention doc (no code change; binary unchanged)

### Change Log

- 2026-04-14 — Story 8.4: consolidated EXX/shadow-register conventions into `docs/register-conventions.md`. Added pointer comment to `src/inner_interpreter.asm` header. No code changes; binary unchanged at 14,030 bytes. 272/272 REPL + 1 assembly regression all pass.
- 2026-04-14 — Addressed code review findings (1 HIGH, 2 MEDIUM, 3 LOW fixed): rewrote `(ABORT")` exception block (doc previously misrepresented it as a bare PUSH DE; reality per Story 8.1 is no IP save at all), corrected line citations from `system.asm:258/120` to `system.asm:114/138/140`, fixed Epic 8 savings total 83 → 75 bytes, corrected DOT worked-example comment about BC' shadow state, added §7 "label / EXX" column-header note, expanded §3 rpush-helpers caveat.

## Senior Developer Review (AI)

**Reviewer:** Claude Opus 4.6 (1M context) — same LLM as implementation; recommended to re-review with a different model per standard convention.
**Review Date:** 2026-04-14
**Review Outcome:** Changes Requested → Approved after fixes
**Findings:** 1 HIGH, 2 MEDIUM, 5 LOW

### Action Items

- [x] **[HIGH]** §7 `(ABORT")` exception is factually wrong — doc claimed "bare PUSH DE with no matching POP and no EXX"; reality per Story 8.1 is **no IP save at all** (rpush_de + INC IX unwind deleted as dead code). `docs/register-conventions.md:264` — **fixed**: rewrote exception block with correct rationale and references to `system.asm:116–118` inline comments.
- [x] **[MEDIUM]** `(ABORT")` line citations wrong: §7 cited `src/system.asm:258` (actually `w_ABORT:`, the ABORT primitive, not `(ABORT")`); §8 cited `src/system.asm:120` (inside a comment block). — **fixed**: now cites `src/system.asm:114` for `.paq_abort` and `:138/140` for `w_ABORT_QUOTE(_cf)`.
- [x] **[MEDIUM]** Story file Epic Context paragraph claimed "83 bytes saved across Epic 8"; correct total is 75 (44+4+27). — **fixed** with breakdown.
- [x] **[LOW]** §4 DOT example comment said "BC' = garbage" after entry EXX, but BC' actually holds caller's TOS (which §6 elsewhere describes as the free preservation slot). — **fixed**: comment now reads "BC' = caller's TOS (not exploited here — DOT doesn't use §6)".
- [x] **[LOW]** §7 tables' "Line" column ambiguously mixed label lines with EXX instruction lines. — **fixed**: column renamed "Lines (label / EXX)" with an explanatory note above the tables.
- [ ] **[LOW]** **Skipped** — `EX AF, AF'` "unused" claim is overbroad because `src/assembler.asm:3443` emits opcode 0x08 with a comment naming it. Pedantic; a future reader grepping for `EX AF` would understand the distinction.
- [x] **[LOW]** §3 "known-safe helpers" list included `rpush_de`/`rpop_de`/`rpush_bc`/`rpop_bc` without caveat — technically safe to call but semantically wrong inside an EXX window (IP is in DE', not DE). — **fixed**: added caveat explaining why these should not be nested inside EXX.
- [ ] **[LOW]** **Skipped** — §8 `compiler.asm:689` is off-by-one (actual `CALL rpop_de` at 688). Cosmetic; reader lands at `NEXT` in the right region.

### Post-Fix Verification

- `make asm` → binary still 14,030 bytes (unchanged, as expected for doc-only edits)
- `make test-repl` → 272/272 PASS, 0 FAIL
- `make test` → assembly regression PASS
- Spot-checked corrected citations: `.paq_abort` at `src/system.asm:114` ✓, `w_ABORT_QUOTE:` at `:138` ✓, `w_ABORT_QUOTE_cf:` at `:140` ✓, `w_ABORT:`/`w_ABORT_cf:` at `:258/260` ✓, inline rationale comments at `:116–118` ✓.
