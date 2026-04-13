# Story 5.3: ANS Forth Core Word Compliance Survey

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth standards enthusiast,
I want a systematic audit of antforth against the ANS Forth Core word set,
so that I know exactly how compliant the system is and which words (if any) are missing.

## Acceptance Criteria

1. **Given** the ANS Forth (DPANS94) Core word set **When** each required Core word is checked against the antforth dictionary **Then** a report is produced listing every Core word, whether antforth implements it, and any semantic differences from the standard

2. **Given** the report is complete **When** reviewed **Then** it includes a compliance percentage and categorises any gaps as: (a) deliberately omitted, (b) oversight, or (c) partially implemented with noted differences

3. **Given** any Core Extension words that antforth happens to implement **When** the report is produced **Then** these are listed as bonus coverage beyond the Core requirement

4. **Given** the report **When** reviewed **Then** it is an audit/report only — no implementation of missing words within this story

## Tasks / Subtasks

- [ ] Task 1: Establish the authoritative ANS Forth Core word list (AC: #1, #2)
  - [ ] 1.1 Use DPANS94 section 6.1 as the canonical source for the Core word set (~133 required words)
  - [ ] 1.2 Enumerate every Core word with its standard stack effect and semantics
  - [ ] 1.3 Separately list Core Extension words (DPANS94 section 6.2) for bonus coverage check

- [ ] Task 2: Audit antforth dictionary against Core word list (AC: #1, #2)
  - [ ] 2.1 For each Core word, determine: (a) implemented with matching name, (b) implemented with different name/semantics, (c) not implemented
  - [ ] 2.2 For implemented words, verify stack effect matches the standard (spot-check via REPL, not exhaustive re-testing)
  - [ ] 2.3 For implemented words, note any semantic differences from the standard (e.g., single-cell only where standard requires double-cell support)
  - [ ] 2.4 For missing words, classify as: deliberate omission (with rationale), oversight, or partially implemented
  - [ ] 2.5 Check words defined via all four macro types: DEFCODE, DEFWORD, DEFIMMED, and direct labels (EXIT_CODE)

- [ ] Task 3: Audit Core Extension bonus coverage (AC: #3)
  - [ ] 3.1 For each Core Extension word (DPANS94 section 6.2), check if antforth implements it
  - [ ] 3.2 List any implemented Core Extension words as bonus coverage
  - [ ] 3.3 Note any semantic differences for bonus words

- [ ] Task 4: Compile the report (AC: #1, #2, #3, #4)
  - [ ] 4.1 Create report document at `docs/ans-forth-core-compliance.md`
  - [ ] 4.2 For each Core word: word name, standard stack effect, status (implemented/missing/partial), antforth source location, and notes on any differences
  - [ ] 4.3 For each gap: classify per AC #2 categories (a/b/c)
  - [ ] 4.4 Summary section with total/implemented/missing/partial counts and compliance percentage
  - [ ] 4.5 Separate section for Core Extension bonus words
  - [ ] 4.6 Organise report by functional category (stack, arithmetic, memory, logic, control, compiler, I/O, string, system) for readability

- [ ] Task 5: Verify no regressions (AC: #4)
  - [ ] 5.1 `make test` — all 73 regression tests pass
  - [ ] 5.2 `make test-repl` — all 237 REPL tests pass
  - [ ] 5.3 No source code changes expected (this is an audit story)

## Dev Notes

### This Is an Audit/Report Story

This story produces a **report document only** — no code changes. If gaps are found, they are documented but NOT implemented. The project lead will decide later which gaps (if any) to address.

The output is a markdown document at `docs/ans-forth-core-compliance.md`.

### Authoritative Reference

The canonical source is **DPANS94** (ANS Forth standard, ANSI X3.215-1994). The Core word set is defined in section 6.1 (required words) and section 6.2 (extension words).

The developer MUST cross-reference the actual standard document for each word's specified stack effect and semantics. Do NOT enumerate from memory — the standard is authoritative. Use web search to access the DPANS94 word list if needed.

### What Already Exists — Complete Word Inventory

Words are defined via four macro types in antforth:
- **DEFCODE** — assembly-level CODE words (most primitives)
- **DEFWORD** — high-level Forth colon definitions (compiled at assembly time)
- **DEFIMMED** — immediate colon definitions (compile-time words)
- **Direct labels** — e.g., EXIT_CODE exists as a label in inner_interpreter.asm but has no dictionary entry

**Source file → word mapping (non-assembler words only):**

| Source File | Words |
|---|---|
| `arithmetic.asm` | + - * /MOD / MOD |
| `bootstrap.asm` | NEGATE ABS MIN MAX VARIABLE |
| `compiler.asm` | COMPILE, IMMEDIATE : COMP-ERROR ; [ ] LITERAL CREATE CONSTANT DOES> (DOES>) POSTPONE |
| `control_flow.asm` | ?COMP (DO) (LOOP) (+LOOP) UNLOOP I J RECURSE IF THEN ELSE BEGIN UNTIL WHILE REPEAT DO LOOP +LOOP LEAVE |
| `dictionary.asm` | COUNT FIND WORDS |
| `formatting.asm` | . U. .R .S HEX DECIMAL |
| `inner_interpreter.asm` | LIT BRANCH ?BRANCH EXECUTE (EXIT_CODE as label, no dictionary entry) |
| `io.asm` | EMIT TYPE CR SPACE SPACES ACCEPT KEY KEY? |
| `logic.asm` | AND OR XOR INVERT LSHIFT RSHIFT = < > 0= 0< U< |
| `memory.asm` | @ ! C@ C! +! HERE ALLOT , C, ALIGN ALIGNED CELLS FILL MOVE |
| `outer_interpreter.asm` | STATE BASE >IN #TIB SOURCE BL QUERY INTERPRET QUIT |
| `stack_ops.asm` | DUP DROP SWAP OVER ROT PICK ROLL DEPTH SP@ SP! RP@ RP! >R R> R@ |
| `strings.asm` | WORD >NUMBER NUMBER? (S") S" ." \ ( |
| `system.asm` | BYE MARKER ABORT |

### Preliminary Coverage Assessment (for developer orientation — MUST be verified against DPANS94)

**Likely implemented Core words (~90+):** ! * + +! +LOOP , - . ." / /MOD 0< 0= : ; < = > >IN >NUMBER >R @ ABORT ABS ACCEPT ALIGN ALIGNED ALLOT AND BASE BEGIN BL C! C, C@ CELLS CONSTANT COUNT CR CREATE DECIMAL DEPTH DO DOES> DROP DUP ELSE EMIT EXECUTE FILL FIND HERE I IF IMMEDIATE INVERT J KEY LEAVE LITERAL LOOP LSHIFT MAX MIN MOD MOVE NEGATE OR OVER PICK POSTPONE QUIT R> R@ RECURSE REPEAT ROT RSHIFT S" SOURCE SPACE SPACES STATE SWAP THEN TYPE U. U< UNLOOP UNTIL VARIABLE WHILE WORD XOR [ ]

**Likely missing Core words (~30+):** */ */MOD 1+ 1- 2! 2* 2/ 2@ 2DROP 2DUP 2OVER 2SWAP >BODY ?DUP ABORT" CELL+ CHAR CHAR+ CHARS ENVIRONMENT? EXIT HOLD M* S>D SIGN SM/REM ['] [CHAR] # #> #S <# '

**Key observations for the audit:**
- **EXIT**: EXISTS as `EXIT_CODE` label in inner_interpreter.asm (line 23) but has **no dictionary entry** — cannot be called from Forth. This is "partially implemented"
- **'** (tick): Not found in any dictionary definition macro
- **Pictured numeric output** (#, #>, #S, <#, HOLD, SIGN): Completely absent — antforth uses . and U. directly without the ANS pictured output subsystem
- **Double-cell operations** (2!, 2@, 2*, 2/, 2DROP, 2DUP, 2OVER, 2SWAP, M*, S>D): None found — antforth appears to be single-cell only
- **ABORT"**: ABORT exists but ABORT" (with message) does not
- **Character words** (CHAR, CHAR+, CHARS): Missing — but on Z80 where char=1 byte, CHAR+ is equivalent to 1+, and CHARS is a no-op
- **(** comment word: Implemented in strings.asm (story 5.1) — this IS a Core word

### Report Format

Follow the same pattern as the Z80 instruction coverage report at `docs/z80-instruction-coverage.md`:
- Tabular format with one row per word
- Columns: Word | Stack Effect (standard) | Status | Source Location | Notes
- Summary statistics at the top
- Organised by functional category
- Gap classification per AC #2

### Testing Strategy

**No code changes = no new tests needed.** Verify existing test suites still pass:
- `make test` — 73 assembly regression tests
- `make test-repl` — 237 REPL tests

For the audit, spot-check a few implemented words via REPL to confirm stack effects match the standard. For example:
```
5 3 /MOD .S    \ should show quotient and remainder per standard order
```

### Anti-Patterns to Avoid

1. **Do NOT implement missing words** — this is an audit/report story only
2. **Do NOT enumerate Core words from memory** — use DPANS94 as the authoritative source; check via web search
3. **Do NOT count assembler words** (CODE, END-CODE, LD,, etc.) as Core words — these are antforth-specific extensions
4. **Do NOT count internal runtime words** ((DO), (LOOP), (+LOOP), (S"), (DOES>), LIT, BRANCH, ?BRANCH, COMP-ERROR, ?COMP, NUMBER?, QUERY, INTERPRET, #TIB) as Core compliance — these are implementation internals
5. **Do NOT count non-standard words** (SP@, SP!, RP@, RP!, WORDS, .S, .R, HEX, KEY?, ROLL, PICK beyond Core) as Core compliance — list them separately if they happen to overlap with Core Extension
6. **Do NOT modify any source files** — report only
7. **Do NOT skip the Core Extension bonus section** — AC #3 requires it

### Previous Story Intelligence (from Story 5.2)

- Story 5.2 (MARKER) completed successfully — all 237 REPL tests + 73 assembly tests pass
- Report stories (like 5.0) produce a markdown document in `docs/` and no code changes
- The Z80 survey (story 5.0) at `docs/z80-instruction-coverage.md` is the model for report format
- A re-audit was also done at `docs/z80-instruction-coverage-reaudit.md` — the project lead values thoroughness

### Git Intelligence

Recent commits follow one-commit-per-story pattern:
```
9433498 completed story 5.2
69d87df completed story 5.1
1f07b30 completed story 5.0.5
33c7747 add re-audit report for z80 opcodes
```

### Project Structure Notes

- Report output: `docs/ans-forth-core-compliance.md` (new file, alongside existing Z80 coverage reports)
- No source file modifications
- No new tests
- No changes to Makefile

### References

- [Source: src/arithmetic.asm] — +, -, *, /MOD, /, MOD
- [Source: src/bootstrap.asm] — NEGATE, ABS, MIN, MAX, VARIABLE
- [Source: src/compiler.asm] — :, ;, IMMEDIATE, LITERAL, CREATE, CONSTANT, DOES>, POSTPONE, COMPILE,, [, ]
- [Source: src/control_flow.asm] — IF, THEN, ELSE, BEGIN, UNTIL, WHILE, REPEAT, DO, LOOP, +LOOP, LEAVE, UNLOOP, I, J, RECURSE
- [Source: src/dictionary.asm] — COUNT, FIND, WORDS
- [Source: src/formatting.asm] — ., U., .R, .S, HEX, DECIMAL
- [Source: src/inner_interpreter.asm:22-29] — EXIT_CODE label (no dictionary entry)
- [Source: src/io.asm] — EMIT, TYPE, CR, SPACE, SPACES, ACCEPT, KEY, KEY?
- [Source: src/logic.asm] — AND, OR, XOR, INVERT, LSHIFT, RSHIFT, =, <, >, 0=, 0<, U<
- [Source: src/memory.asm] — @, !, C@, C!, +!, HERE, ALLOT, ,, C,, ALIGN, ALIGNED, CELLS, FILL, MOVE
- [Source: src/outer_interpreter.asm] — STATE, BASE, >IN, #TIB, SOURCE, BL, QUERY, INTERPRET, QUIT
- [Source: src/stack_ops.asm] — DUP, DROP, SWAP, OVER, ROT, PICK, ROLL, DEPTH, SP@, SP!, RP@, RP!, >R, R>, R@
- [Source: src/strings.asm] — WORD, >NUMBER, NUMBER?, (S"), S", .", \, (
- [Source: src/system.asm] — BYE, MARKER, ABORT
- [Source: docs/z80-instruction-coverage.md] — Model for report format (Z80 survey from story 5.0)
- [Source: docs/z80-instruction-coverage-reaudit.md] — Re-audit report showing thoroughness expectations
- [Memory: feedback_systematic_reference_check.md] — "Complete X" specs must cross-reference the authoritative manual
- [Memory: feedback_standards_compliance.md] — Investigate the standard before defending code
- [Memory: feedback_repl_tests_preferred.md] — REPL tests only (not applicable here — no code changes)

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
