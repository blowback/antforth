# Story 22.2: REPL prompt indicator (current-bank visibility) + F4 cross-bank-pointer-hazard user-docs entry

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Drafted 2026-06-13 by create-story workflow.
     Story 22.2 is the SECOND story of Epic 22 (Polish + Phase-4 close-out),
     following 22.1 (.BANKS final form, done). It has TWO independent
     deliverables glued by the F4 theme:
       (A) an OPT-IN REPL prompt indicator that shows the current bank as a
           `[N]` prefix on the `ok` prompt, default OFF; and
       (B) a NEW user-docs markdown file documenting the cross-bank pointer
           hazards (F4 closure) + the README "Banking" link to it.

     SIX load-bearing findings were resolved at DRAFT TIME by reading live
     source (B.4 / PD-2 figure-drift discipline). Do NOT re-discover them at
     dev-pass:

       (1) THE PROMPT IS THREADED CODE, NOT RAW ASSEMBLY. The `ok` prompt is
           emitted by the QUIT loop's `.quit_ok` block as four threaded cells
           (src/outer_interpreter.asm:461-465):
             DW w_LIT_cf, str_ok / DW w_LIT_cf, STR_OK_LEN / DW w_TYPE_cf / DW w_CR_cf
           `str_ok = " ok"` (LEADING space, no trailing, no CR — CR is the
           separate w_CR_cf cell), 3 bytes, at src/antforth.asm:797-798. The
           block is reached only when STATE=0 (interpret mode; the QBRANCH at
           :456 skips it while compiling) and only from the interactive QUIT
           loop — EVALUATE / INCLUDE bypass QUIT entirely, so they never
           prompt. The byte-minimal extension inserts ONE new threaded cell
           (a named prefix word) BEFORE the `str_ok` print; the prefix word
           prints `[N]` and the existing ` ok` leading space becomes the
           separator → `[5] ok`. See AC1 + finding (3).

       (2) NO GENERIC `ON` / `OFF` WORDS EXIST. The epics-file AC1 illustrates
           the toggle as `PROMPT-SHOW-BANK ON` / `OFF` (two tokens), but a
           grep of src/*.asm finds NO standalone `ON` / `OFF` words and no
           VARIABLE/VALUE machinery for them (VALUE/TO are deliberately
           omitted, structures.asm:51-52). The established flag-word precedent
           is the DEFCODE pair `BANK-MAPPING-ON` / `BANK-MAPPING-OFF`
           (src/banking.asm:32-68), each writing a UserArea cell. The toggle
           API is therefore a genuine design choice (Q1): a single setter word
           `PROMPT-SHOW-BANK ( flag -- )` is byte-cheapest (one header). The
           epics "ON/OFF" wording is illustrative ("e.g."), not binding.

       (3) THE PHASE-3 PROMPT IS `" ok"` (LEADING space), NOT `"ok "`. The
           epics-file AC1 paraphrases the Phase-3 prompt as `ok ` (trailing
           space); the REAL literal is `str_ok = " ok"` (leading space) +
           CRLF. So the indicator must produce `[5] ok` by emitting `[`, the
           decimal bank, `]`, then FALLING THROUGH to the unchanged ` ok`
           print — the leading space gives the `] ok` gap for free, with NO
           new trailing space and NO reorder. When the indicator is suppressed
           (flag OFF, or bank 0), the output is byte-identical to Phase-3
           (` ok\r\n`), which is what keeps the 975-test iz-cpm baseline green
           (AC8). See AC1 + AC3.

       (4) DEFAULT MUST BE OFF (forced, not preferred). AC8 requires
           `make test-repl` ≥ 974/0 on iz-cpm AND that default-OFF "preserves
           the Phase-3 prompt format exactly". If the default were ON, every
           iz-cpm REPL line in bank 0 would still print bare ` ok` (bank-0
           suppresses the bracket regardless of flag — finding (3)), so the
           bank-0 case is safe either way — but the SAFE, spec-mandated
           disposition is default OFF (Q2). Bank 0 ALSO always suppresses the
           bracket even when the flag is ON (a `[0]` prompt is noise; the
           epics AC1 says "suppressed if the user has not banked or is in
           bank 0").

       (5) THE USER-DOCS ENTRY IS ARCHITECTURE-BOUND TO COVER MORE THAN THE
           EPICS AC2 LISTS. Epics-file Story-22.2 AC2 enumerates four
           bank-sensitive pointers (HERE/LATEST, CREATE PFA data cells, raw
           allocator pointers, wordlist-head pointers). But architecture.md
           §F4 (the source-of-truth for the F4 finding, :995-1001) BINDS the
           SAME user-docs entry — "Per Story 16.4 §9.6 closure (PD-P4-12) the
           same user-docs entry is extended to cover the cross-bank-R-stack-
           overflow gotcha" (recursive cross-bank calls fill the return stack
           3× faster → `-5 RETURN-STACK-OVERFLOW`). The doc MUST include that
           section. The redesign-doc guidance the doc cites lives at
           docs/antforth-banking-redesign.md §5.4 (:109-111); the "do all your
           work in one bank per logical session, swap banks at well-defined
           boundaries" recommendation text lives at architecture.md:1001 (NOT
           verbatim in §5.4 — cite §5.4 for the doc-and-pray disposition and
           architecture.md:1001 for the recommendation). See AC2 + finding
           (5) variance.

       (6) check-doc-sync DOES NOT SCAN docs/. The tool's registry is seven
           HARDCODED planning files (tools/check-doc-sync/check-doc-sync.sh:56-62:
           PRD, architecture, four epics-phase files, the compliance doc); it
           never globs docs/. A new docs/ markdown file is therefore INVISIBLE
           to it — `make check-doc-sync` clean-passes automatically with the
           new file present (no new drift). AC8's "the new user-docs file
           recognised" is thus a disposition choice (Q5): the byte-cheap,
           ceremony-light reading (clean-pass holds; the README link target
           resolves) is recommended over extending the tool's registry, per
           `feedback_ceremony_diminishing_returns` (solo-dev: stop building
           tooling-on-tooling). -->

## Story

As Marc (OG retrocomputing user) doing multi-bank REPL work,
I want the `ok` prompt to optionally show my current bank as a `[N]` prefix (opt-in, default OFF so the Phase-3 prompt is untouched for everyone else), and a single canonical user-docs entry that names the bank-sensitive pointers and shows the anti-pattern,
So that I get visible feedback that I am about to type into bank N (I can't silently compile into the wrong bank), and I have one place to read about cross-bank pointer hazards before I write my first multi-bank application.

## Acceptance Criteria

> UX polish + F4 finding closure. Two deliverables: (A) an opt-in REPL prompt indicator (`[N] ok`) gated on a kernel flag word, default OFF; (B) a new user-docs markdown file "Cross-bank pointer hazards" + a README "Banking" link to it. **FRs covered:** none directly. **Finding closed:** F4 (cross-bank pointer hazard documented in user-docs). The epics-file AC set is re-specced here against repo reality: the Phase-3 prompt is `" ok"` (leading space, finding (3)); no generic `ON`/`OFF` words exist so the toggle API is a design choice (finding (2) / Q1); the user-docs entry is architecture-bound to ALSO cover the cross-bank R-stack-overflow gotcha (finding (5), architecture.md:1001); check-doc-sync does not scan `docs/` so "recognised" is a disposition (finding (6) / Q5).

**Given** Epic 21 has shipped (saved-bank cell + QUIT bank-restore working; `w_REASSERT_BANK_cf` at the head of the QUIT loop, src/outer_interpreter.asm:448) AND Story 22.1 is done (current build 28331 B at HEAD `d32b8dc`; banner reads v3.0.6 — re-`wc -c` and re-confirm banner at dev-pass start per B.3), AND the Phase-3 prompt is emitted as threaded code at `.quit_ok` (src/outer_interpreter.asm:461-465) printing `str_ok = " ok"` (src/antforth.asm:797-798, leading space, 3 bytes) then `w_CR_cf`, gated on STATE=0,
**When** Story 22.2 is dev-passed,

**Then** **AC1** (REPL prompt indicator — opt-in, default OFF, bank-0-suppressed) — the QUIT-loop prompt print at `.quit_ok` (src/outer_interpreter.asm:461-465) is extended to optionally prepend a current-bank indicator:
- A new kernel flag cell `prompt_show_bank` is added to the UserArea struct (src/structures.asm, alongside `bank_mapping_state` at :47 — a DEFCODE-readable kernel cell, NOT an ANS VARIABLE/VALUE per structures.asm:51-52); COLD zero-inits it (default **OFF**, finding (4)).
- A new threaded cell is inserted at the HEAD of `.quit_ok` (before the `str_ok` print) referencing a new named DEFCODE prefix word (working name `(BANK-PROMPT)` — exact spelling per Q3) that: reads `prompt_show_bank`; if 0 → return (prints nothing); else reads `(IY+UserArea.current_bank)` (the same field `BANK@` reads, src/banking.asm:112); if 0 → return (bank-0 suppressed, finding (4)); else prints `[`, the bank index in **decimal**, `]`. Execution then falls through to the UNCHANGED ` ok` + CR print, so the leading space of `str_ok` provides the `] ok` gap → `[5] ok` (finding (3)). No new trailing space, no reorder.
- The toggle word (Q1) sets/clears `prompt_show_bank`. Default disposition is **OFF** (Q2, finding (4)) so users who prefer the Phase-3 prompt are unaffected; the user-docs entry (AC2) recommends enabling it for multi-bank work.

**And** **AC2** (F4 mitigation — user-docs entry, architecture-bound scope) — a new user-docs markdown file is created (filename per Q4 — recommend `docs/banking-pointer-hazards.md`; record the chosen name in Dev Notes) titled **"Cross-bank pointer hazards"**, containing:
- The bank-sensitive pointers: `HERE` / `LATEST` (FR-P4-26, epics:70); data-cell PFA addresses from `CREATE` (FR-P4-25, epics:69); raw allocator pointers; wordlist-head pointers held outside `FIND`.
- An **example anti-pattern**: code that captures `HERE` while in bank 5, switches to bank 7 with `BANK!`, then writes through the captured pointer — writing garbage into bank 7's address space at bank 5's `here` offset.
- The **cross-bank R-stack-overflow gotcha** (architecture-bound per architecture.md:1001 §9.6 closure / PD-P4-12, finding (5)): recursive cross-bank calls accumulate 3-cell return frames and fill the standard return stack ~3× faster than intra-bank calls, triggering the standard `-5 RETURN-STACK-OVERFLOW THROW`; no runtime guard.
- The **recommendation**: "do all your work in one bank per logical session, swap banks at well-defined boundaries" (architecture.md:1001; the redesign §5.4 "doc-and-pray" disposition, docs/antforth-banking-redesign.md:111).
- A cross-reference to the AC1 toggle word for visual feedback.

**And** **AC3** (README link) — `README.md` gains a `## Banking` section heading (recommended placement: after the `## Version 3.0.6` block ending ~line 49 and before `## Coming up in the next version` at line 97) that links to the AC2 user-docs file. (There is no existing `## Banking` heading today — README:14/97/104/113 are the only `##` headings; banking content currently lives inside `## Version 3.0.6`.)

**And** **AC4** (CCD-3 source citation) — the AC1 prompt-extension source comment (in src/outer_interpreter.asm and/or src/banking.asm where the prefix word lands) cites the F4 mitigation + the user-docs filename; the user-docs file's first paragraph cites `docs/antforth-banking-redesign.md §5.4`. Per `feedback_source_comment_discipline`: what + why-not-obvious, NO provenance dump (no story/CR/date beyond a single "see <doc>" pointer).

**And** **AC5** (REPL probes) — probes verify the three prompt states. Because all three require switching into a non-zero bank (the straddling-bucket-chain hazard, `feedback_phase4_probe_bank_switch_limitation` / ADR 19.5 DR-1), the behavioural probes live in a **NEW isolated fixture `tests/banking_tests_22_2.fth` + `make test-repl-banking-isolated-22-2`** (mirror Story 22.1's `-22-1` target and the 21-1/21-2 recipes), NOT the main suite:
- (a) toggle ON + `5 BANK!` → the indicator emits `[5]` (grep the emitted prefix);
- (b) bank 0 (after `0 BANK!`) → bare ` ok`, NO bracket, even with the flag ON (bank-0 suppressed, finding (4));
- (c) toggle OFF + `5 BANK!` → bare ` ok`, no bracket.
- **Observability note (probe-design, dev-pass):** because the QUIT prompt interleaves with echoed input in a piped session, the robust probe calls the named prefix word `(BANK-PROMPT)` DIRECTLY (it is a kernel-resident, bank-0-xt DEFCODE word — safe to invoke from the isolated fixture) and greps its TYPE output for `[5]` / absence-of-`[`, rather than depending on capturing the QUIT prompt line. If the harness DOES surface the prompt line, an additional grep on `[5] ok` may be added. Lines ≤ TIB_SIZE 128 (`feedback_tib_size_inline_comments`); file 0x1A-terminated (`feedback_cpm_0x1a_eof_marker`).

**And** **AC6** (hardware smoke per S9 / NFR-P4-11) — one hardware-typed probe verifies the prompt format on real MicroBeast under each toggle setting: boot (default OFF → bare ` ok`), enable the toggle, `5 BANK!` (prompt shows `[5] ok`), `0 BANK!` (prompt returns to bare ` ok`), disable the toggle, `5 BANK!` (bare ` ok`). Visually confirm the bracket renders + 80-col fit. Transcript saved per the `~/Downloads/beastty-<date>.bin` convention. DEFERRED to user-triggered run per the established S9 precedent; the recipe is posted **IN THE CLOSING CHAT MESSAGE** per `feedback_post_hw_smoke_steps_at_review` (STRONG).

**And** **AC7** (binary delta + envelope) — `wc -c build/antforth.com` delta is tracked against the epics' **≤ ~30 B** target (`epics-phase4-epics-16-22.md:1207`) and the architecture's "prompt indicator ~20 B" line (architecture.md:499). **Envelope-tension note (B.4):** a new UserArea flag cell (~0 code) + a setter word (header ~20 B + body ~8 B) + the prefix word (header + flag/bank read + `[`/decimal/`]` print ~40-60 B) + the one-cell thread edit (+2 B) realistically lands ~70-90 B — the ~2.4× Phase-4 empirical multiplier (`project_epic17_envelope`) on a ~30 B target. This is a **pure addition** (no design substitution → the multiplier-void carve-out does NOT apply). Disposition is Q6: recommend accept-with-rationale in Dev Notes if ≤ ~80 B (mirroring Story 22.1's Q4 accept-with-rationale precedent, which carried +282 B); surface for SCP only if structurally larger. Minimise via: reuse an existing small decimal-emit path for the 0..28 bank index (e.g. the Story-22.1 printers in banking.asm, or `cl_emit_hex_byte`'s shape — but decimal); keep the prefix word straight-line DEFCODE (no inline-thread trampoline).

**And** **AC8** (regression baselines preserved — re-validate at dev-pass start per B.3) — `make test-repl` ≥ **975 PASS / 0 FAIL** on iz-cpm (default-OFF makes the prompt byte-identical to Phase-3; the prompt change is invisible to iz-cpm); `make test-repl-banking` ≥ **62 PASS / 0 FAIL** (the 22.1 close measured 62/0 — re-confirm; no main-suite prompt probes are added, so this stays flat unless a surface-agnostic guard is added); `make test-repl-banking-isolated-22-2` ≥ **1 PASS** (the new fixture); all other isolated targets (`-19-3 -19-4 -19-5-1 -20-1 -20-2 -20-3 -21-1 -21-2 -21-3 -22-1`) unchanged; `make test-straddle-regression` = **3/3**; `make test-file-sanity` = **0 errors**; `make check-doc-sync` clean-pass (no NEW drift; per finding (6) the new docs file is invisible to the tool, so "recognised" = the README link resolves + no drift introduced — Q5).

**FRs covered:** none directly (UX polish + F4 user-docs entry). **Findings closed:** F4 (cross-bank pointer hazard documented in user-docs, incl. the §9.6 R-stack-overflow extension per architecture.md:1001).

> **Adversarial review (`CR`) is NOT an acceptance criterion** and is not a dev-pass task — it runs separately via the `CR` command in fresh context after dev-pass close (PD-1, Story 13.5.0). Do not add a "trigger adversarial review" AC.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: clean `make clean && make && wc -c build/antforth.com`. **Do not inherit any number from this story text** (B.3 / Lesson 13.5-F). For orientation only: Story 22.1 closed at **28331 B** (HEAD `d32b8dc` "Story 22.1 status -> done") — but re-`wc -c` from the actual current artifact at YOUR dev-pass start. Record the absolute size + which HEAD it reflects. — **Measured 28331 B at HEAD `d32b8dc` (matches orientation).**
- [x] Confirm banner reads **v3.0.6** (src/antforth.asm:781 `AntForth v3.0.6`). Story 22.2 does NOT touch the banner/version — the final Phase-4 tag (v3.0.7 per the 21.3 downstream-mapping shift) is Story 22.4. — **Confirmed (now src/antforth.asm:785; untouched).**
- [x] Capture `make test-repl` (expect **975 / 0**), `make test-repl-banking` (expect **62 / 0** post-22.1), all isolated targets (`-19-3 -19-4 -19-5-1 -20-1 -20-2 -20-3 -21-1 -21-2 -21-3 -22-1`; re-validate exact counts), `make test-straddle-regression` (**3/3**), `make test-file-sanity` (**0 errors**), `make check-doc-sync` (clean / advisory-only). Record all in Dev Notes. — **All captured (975/0 · 62/0 · 15/2/2/7/5/5/5/5/6/1 · 3/3 · 0 errors · 0 drift).**
- [x] Re-confirm constants against source-of-truth (B.4 — line numbers shift): `str_ok` + `STR_OK_LEN` (src/antforth.asm:797-798); the `.quit_ok` threaded block (src/outer_interpreter.asm:461-465) + its STATE=0 gate (:453-460); `w_BANK_AT_cf` reading `(IY+UserArea.current_bank)` (src/banking.asm:108-114); the UserArea layout + `bank_mapping_state` flag-cell precedent (src/structures.asm:44-66) + the `ENDS` insertion point (:66); the `BANK-MAPPING-ON`/`OFF` DEFCODE flag-word pattern (src/banking.asm:32-68); architecture F4 (architecture.md:995-1001); redesign §5.4 (docs/antforth-banking-redesign.md:109-111); check-doc-sync registry (tools/check-doc-sync/check-doc-sync.sh:56-62). — **All re-confirmed against live source.**
- [x] Re-read the current `.quit_ok` block + `str_ok`, and the README heading structure (README.md:14/97/104/113), before editing.

### Q-dispositions (resolve at dev-pass start via AskUserQuestion BEFORE any edit)

- [x] **Q1 — toggle-word API shape.** Recommend **(a) a single setter DEFCODE word `PROMPT-SHOW-BANK ( flag -- )`** — `-1 PROMPT-SHOW-BANK` enables, `0 PROMPT-SHOW-BANK` disables — byte-cheapest (one header), matches the "DEFCODE-readable kernel cell" precedent (structures.asm:51). Alternative (b): the purpose-named pair `PROMPT-SHOW-BANK-ON` / `PROMPT-SHOW-BANK-OFF` (mirror `BANK-MAPPING-ON`/`OFF`; +~40 B name cost, but matches the epics "ON/OFF" wording). Alternative (c): a VARIABLE `PROMPT-SHOW-BANK` + new generic `ON`/`OFF` words (most ANS-idiomatic + reusable, but adds two generic words = scope + 975-baseline risk). The epics "ON/OFF" is illustrative ("e.g."), so probe syntax adapts to the chosen API. **(a) recommended.** — **User chose (a): single setter `PROMPT-SHOW-BANK ( flag -- )`.**
- [x] **Q2 — default disposition.** Recommend **OFF by default** (finding (4); forced by AC8 — default-OFF preserves the Phase-3 iz-cpm prompt byte-identically). Confirm. Also confirm bank-0 always suppresses the bracket even when the flag is ON (a `[0]` prompt is noise; epics AC1 says suppress "in bank 0"). — **Confirmed: default OFF (COLD zero-init); bank-0 always suppressed even with flag ON.**
- [x] **Q3 — prefix word name + format.** Recommend the prefix word be a NAMED kernel DEFCODE word (working name `(BANK-PROMPT)`) so the AC5 probe can call it directly and capture its output (sidesteps prompt-capture-in-pipe fragility). Format `[N]` printed before the unchanged ` ok` → `[5] ok` (finding (3)); confirm exact bytes `[`, decimal index, `]`. — **User chose `(BANK-PROMPT)`; format `[` + decimal index + `]`.**
- [x] **Q4 — user-docs filename.** Recommend **`docs/banking-pointer-hazards.md`** (descriptive of the F4 title; kebab-case per docs/ convention). Alternatives: `docs/users-guide-banking.md`, `docs/banking-gotchas.md`. Record the chosen name in Dev Notes. Confirm the doc covers the architecture-bound R-stack-overflow gotcha (finding (5)) in addition to the pointer hazards. — **User chose `docs/banking-pointer-hazards.md`; doc includes the R-stack-overflow gotcha section.**
- [x] **Q5 — check-doc-sync "recognised" disposition (AC8).** Recommend **(a) lightweight**: clean-pass already holds (the new docs file is invisible to the tool's 7-file registry, finding (6)); treat "recognised" as "the README `## Banking` link target resolves to an existing file + no new drift" — optionally add a one-line existence check only if cheap. Per `feedback_ceremony_diminishing_returns` (solo-dev; stop tooling-on-tooling). Alternative (b): extend the script registry + add a drift-check (heavier ceremony). **(a) recommended.** — **User chose (a) lightweight: README link resolves + 0 new drift; tool registry NOT extended.**
- [x] **Q6 — envelope disposition (AC7).** Recommend **accept-with-rationale in Dev Notes** if the measured delta is ≤ ~80 B (pure addition, inside the ~2.4× multiplier on ~30 B); escalate to a dedicated SCP only if structurally larger. (Mirror Story 22.1's Q4 accept-with-rationale precedent.) — **User chose accept-with-rationale. Measured +132 B (see Dev Notes envelope reconciliation — accepted; well inside Story 22.1's +282 B precedent for "not structurally larger").**

### Story tasks

- [x] **Task 1 — UserArea flag cell + toggle word** (AC: #1)
  - [x] Sub-1.1 Add `prompt_show_bank DW 0` to the UserArea struct (src/structures.asm, before `ENDS`, alongside `bank_mapping_state`). COLD does NOT blanket-zero UserArea (it inits each field), so an explicit zero-init was added next to the other banking cells (src/antforth.asm step 8h).
  - [x] Sub-1.2 Added `PROMPT-SHOW-BANK ( flag -- )` DEFCODE (Q1-a): `check_underflow`, store TOS → `prompt_show_bank`, `POP BC` (drop), NEXT. Placed with the banking flag words (src/banking.asm, right after `BANK-MAPPING-OFF`).
- [x] **Task 2 — Prompt-prefix word + QUIT-loop thread edit** (AC: #1, #3-format)
  - [x] Sub-2.1 Added `(BANK-PROMPT)` DEFCODE (Q3) in src/banking.asm: if `prompt_show_bank`==0 → NEXT; if `(IY+UserArea.current_bank)`==0 → NEXT; else save TOS/IP, print `[`, decimal index (inline tens/ones peel, no padding — bank 1..28), `]`, restore, NEXT. Straight-line; stack-neutral (preserves BC=TOS and DE=IP across BDOS).
  - [x] Sub-2.2 Inserted `DW w_BANK_PROMPT_cf` at the HEAD of `.quit_ok` (src/outer_interpreter.asm), BEFORE `DW w_LIT_cf, str_ok`. The ` ok` + CR print is UNCHANGED.
  - [x] Sub-2.3 Verified: flag OFF / bank 0 → byte-identical Phase-3 prompt (975-test iz-cpm baseline stays green); flag ON + bank 5 → `[5] ok` (isolated probe 22.2-a).
- [x] **Task 3 — User-docs entry** (AC: #2, #4)
  - [x] Sub-3.1 Created `docs/banking-pointer-hazards.md` (Q4), title "Cross-bank pointer hazards"; first paragraph cites `docs/antforth-banking-redesign.md §5.4`. Covers bank-sensitive pointers (HERE/LATEST, CREATE PFA, raw allocator, wordlist heads), the BANK!-across anti-pattern, the cross-bank R-stack-overflow gotcha (architecture.md:1001 §9.6), the "one bank per logical session" recommendation, and a cross-ref to `PROMPT-SHOW-BANK`.
  - [x] Sub-3.2 Source comment on the `.quit_ok` thread edit + the two new words cites the F4 mitigation + `docs/banking-pointer-hazards.md` (no provenance dump).
- [x] **Task 4 — README Banking section** (AC: #3)
  - [x] Sub-4.1 Added `## Banking` to README.md (after the `## Version 3.0.6` block, before `## Coming up`) linking to `docs/banking-pointer-hazards.md` + a `PROMPT-SHOW-BANK` tip.
- [x] **Task 5 — Probes** (AC: #5)
  - [x] Sub-5.1 NEW `tests/banking_tests_22_2.fth`: probes (a) flag ON + bank 5 → `(BANK-PROMPT)` emits `[5]`; (b) bank 0 → no bracket even with flag ON; (c) flag OFF + bank 5 → no bracket. Calls `(BANK-PROMPT)` directly, anchored as `P=[N]=` / `P==`. 0x1A-terminated; lines ≤ 128.
  - [x] Sub-5.2 `Makefile`: new `test-repl-banking-isolated-22-2` target + `.PHONY` entry (mirrors `-22-1`). Q5-a chosen → no check-doc-sync registry change.
- [x] **Task 6 — Build + regression** (AC: #7, #8)
  - [x] Sub-6.1 `make asm` — 0 errors, 0 warnings.
  - [x] Sub-6.2 `make test-repl` 975/0 (2 hw-deferred SKIP); `make test-repl-banking` 62/0; `make test-repl-banking-isolated-22-2` 4 PASS; all other isolated targets unchanged (15/2/2/7/5/5/5/5/6/1); straddle 3/3; file-sanity 0 errors; check-doc-sync 0 drift. **(See Dev Notes: a probe-y layout-fragility fix was required — kernel growth crossed $8000; details below.)**
  - [x] Sub-6.3 `wc -c build/antforth.com` = **28463 B** (delta **+132 B** vs 28331 baseline). Q6 accept-with-rationale applied (Dev Notes).
- [x] **Task 7 — Hardware smoke** (AC: #6) — **HW UAT PASS** on real MicroBeast (AntForth v3.0.6)
  - [x] Sub-7.1 HW-smoke run by Ant; transcript `~/Downloads/beastty-20260613-165829.bin`. Sequence confirmed clean: enable in bank 0 → bare ` ok` (bank-0 suppressed even with flag ON); `5 BANK!` → `[5] ok`; `0 BANK!` → ` ok`; re-enable + `5 BANK!` → `[5] ok`; `0 PROMPT-SHOW-BANK` + `5 BANK!` → ` ok` (flag OFF wins in bank 5); `0 BANK!` → ` ok`. Bracket renders, 80-col fit fine.
- [x] **Task 8 — Sprint-status + commit**
  - [x] Sub-8.1 `sprint-status.yaml`: `22-2-…` `ready-for-dev` → `in-progress` (dev-pass start) → `review` (close).
  - [ ] Sub-8.2 Commit per user trigger. NO `Co-Authored-By: Claude` trailer (`feedback_no_claude_coauthor`, STRONG). *Awaiting Ant's commit trigger.*

## Dev Notes

### The prompt is threaded code (the load-bearing AC1 input — verified at draft time)

The `ok` prompt is NOT a raw assembly print — it is four threaded cells in the QUIT loop (`.quit_ok`, src/outer_interpreter.asm:461-465):

```asm
.quit_ok:
        DW      w_LIT_cf, str_ok        ; ( -- addr )
        DW      w_LIT_cf, STR_OK_LEN    ; ( addr -- addr len )
        DW      w_TYPE_cf               ; print " ok"
        DW      w_CR_cf                 ; newline
```

`str_ok = " ok"` (src/antforth.asm:797-798) is a **leading**-space, 3-byte string; the newline is the separate `w_CR_cf` cell. The block runs only when STATE=0 (the QBRANCH at :456 skips it while compiling) and only from interactive QUIT — EVALUATE/INCLUDE never reach it. The byte-minimal, lowest-risk extension prepends ONE threaded cell (`DW (BANK-PROMPT)_cf`) before `str_ok`; the prefix word prints `[N]` (or nothing), and the existing leading space of `str_ok` gives the `] ok` gap for free → `[5] ok`. When the prefix prints nothing (flag OFF or bank 0) the output is byte-for-byte the Phase-3 ` ok\r\n` — the property AC8 leans on.

### Flag-word precedent + no generic ON/OFF (finding (2))

There is no generic `ON`/`OFF` word and no VARIABLE/VALUE machinery for them (VALUE/TO are deliberately omitted, structures.asm:51-52). The established kernel flag-word is the DEFCODE pair `BANK-MAPPING-ON` / `BANK-MAPPING-OFF` (src/banking.asm:32-68), each writing a UserArea cell (`bank_mapping_state`, structures.asm:47). The toggle for this story follows that "DEFCODE-readable kernel cell" model. Q1 picks the surface: the byte-cheapest is a single setter `PROMPT-SHOW-BANK ( flag -- )` (one dictionary header vs two). The epics-file `PROMPT-SHOW-BANK ON / OFF` two-token wording is illustrative ("e.g."), not binding — probe syntax adapts to the chosen API.

### Bank index read (AC1)

The prefix word reads the SAME field `BANK@` reads: `(IY+UserArea.current_bank)` (src/banking.asm:112; the field is `current_bank` at structures.asm:45, a DW, high byte invariantly 0 for bank < 29). No need to go through the `BANK@` word — read the IY-relative cell directly (cheaper, and matches `w_BANK_AT_cf`'s own access).

### User-docs scope is architecture-bound wider than epics AC2 (finding (5))

Epics-file Story-22.2 AC2 lists four bank-sensitive pointers. But the **source-of-truth for the F4 finding** is architecture.md §F4 (:995-1001), and its **Action** (:1001) binds the SAME user-docs entry to ALSO cover the cross-bank R-stack-overflow gotcha "Per Story 16.4 §9.6 closure (PD-P4-12)": recursive cross-bank calls accumulate 3-cell return frames, fill the standard return stack ~3× faster than intra-bank, and trigger `-5 RETURN-STACK-OVERFLOW` (no runtime guard). The doc MUST include that section (AC2). Citations: the "doc-and-pray" disposition is redesign §5.4 (docs/antforth-banking-redesign.md:111); the "do all your work in one bank per logical session, swap banks at well-defined boundaries" recommendation text is at architecture.md:1001 (it is NOT verbatim in §5.4). Related but out-of-scope-for-this-doc gotchas exist (FORGET does not roll back `+BANK`/`-BANK` bank-list changes, epics 21.1 AC4 / :1063) — the dev-pass MAY add a one-line note if it reads naturally, but the binding content is the F4 pointer hazards + the §9.6 R-stack extension.

### check-doc-sync does not scan docs/ (finding (6))

`tools/check-doc-sync/check-doc-sync.sh` validates drift only across seven HARDCODED planning files (:56-62: PRD, architecture, four epics-phase files, the compliance doc). It never globs `docs/`. A new `docs/` markdown file is invisible to it, so `make check-doc-sync` clean-passes automatically once the file exists (no new drift). AC8's "the new user-docs file recognised" is therefore a disposition (Q5): the recommended ceremony-light reading is "clean-pass holds + the README `## Banking` link resolves to a real file", NOT extending the tool registry (`feedback_ceremony_diminishing_returns`). If the dev-pass wants a guard, the cheapest is a `test-file-sanity`-style existence check that the README link target exists — not a new drift category.

### Why the prompt probes need an isolated fixture

`feedback_phase4_probe_bank_switch_limitation` + ADR 19.5 DR-1: the main `tests/banking_tests.fth` dictionary straddles `$8000`; any token lookup while a non-zero bank is mapped can walk a bucket chain through the portal window and read a foreign page. All three AC5 prompt probes require a non-zero bank, so they live in a dedicated `tests/banking_tests_22_2.fth` + `make test-repl-banking-isolated-22-2` (mirror Story 22.1's `-22-1` at the Makefile; 21-1/21-2 recipes). The robust observation is to call the named `(BANK-PROMPT)` word directly (kernel-resident, bank-0 xt) and grep its TYPE output, rather than depending on the harness surfacing the interleaved QUIT prompt line.

### Envelope tension (AC7)

Epics target ≤ ~30 B (`epics-phase4-epics-16-22.md:1207`); architecture allocates "prompt indicator ~20 B" (architecture.md:499). Realistically: flag cell (~0 code) + setter word (header ~20 B + ~8 B body) + prefix word (header + flag/bank read + `[`/decimal/`]` ~40-60 B) + the +2 B thread cell → ~70-90 B (the ~2.4× Phase-4 multiplier, `project_epic17_envelope`). Pure addition (no mechanism substitution → multiplier-void carve-out does NOT apply). Minimise via: reuse a small existing decimal-emit for the 0..28 index; straight-line DEFCODE prefix word; single setter word (Q1-a) not a pair. Q6: accept-with-rationale if ≤ ~80 B (mirror Story 22.1's +282 B accept-with-rationale precedent).

### Project Structure Notes

- Story 22.2 is the SECOND story of Epic 22 (Polish + Phase-4 close-out). Epic 22 is already `in-progress` (22.1 done) — creating this story does not change the epic status.
- Story 22.2 does NOT touch the banner/version. The final Phase-4 tag (**v3.0.7** per the 21.3 downstream-mapping shift) is applied by Story 22.4. The version surface is out of scope here.
- The sprint-status key + filename keep the full descriptive slug `22-2-repl-prompt-indicator-current-bank-visibility-f4-cross-bank-pointer-hazard-user-docs-entry` per the workflow's `{story_key}.md` rule.
- **Do not touch** the per-bank state machinery, the saved-bank/QUIT-restore wiring (Epic 21, done), or the `.BANKS` body (Epic 22.1, done). The only kernel edits are: the new UserArea flag cell, the toggle word, the prefix word, and the one-cell `.quit_ok` thread insertion.

### Detected conflicts or variances

- **Epics AC1 says `ok ` (trailing space); the real Phase-3 prompt is `" ok"` (leading space)** — re-specced in AC1/AC3 + finding (3). The `[N]` prefix reuses the leading space as the `] ok` separator.
- **Epics AC1 illustrates `PROMPT-SHOW-BANK ON / OFF`, but no generic ON/OFF words exist** — re-specced as a design choice (finding (2) / Q1); recommend a single setter word.
- **Epics AC2 lists four pointers; architecture.md:1001 BINDS the same doc to also cover the cross-bank R-stack-overflow gotcha (§9.6 / PD-P4-12)** — folded into AC2 (finding (5)). Source-of-truth (architecture F4) is wider than the epics AC.
- **Epics AC8 "the new user-docs file recognised" by check-doc-sync — but check-doc-sync doesn't scan docs/** — re-specced as a disposition (finding (6) / Q5); recommend the ceremony-light "clean-pass + README link resolves" reading.
- **Epics AC7 ~30 B is optimistic** — reconciled in AC7 / Dev Notes (pure-addition, ~2.4× multiplier; Q6 disposition).
- **Default disposition (epics AC1 "likely OFF")** — confirmed forced OFF by AC8 (finding (4) / Q2).

### References

- [Source: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:1186-1210`] — Story 22.2 spec (the AC set re-specced here); Epic 22 overview `:1147-1163`; Epic 22 summary `:1260`; FR-P4-25 `:69`, FR-P4-26 `:70`.
- [Source: `_bmad-output/implementation-artifacts/22-1-dot-banks-final-formatting-polish-per-bank-used-free-reflect-real-here-values.md`] — predecessor Story 22.1 (done); the isolated-fixture + Q-disposition + accept-with-rationale house style mirrored here; baseline 28331 B at HEAD `d32b8dc`; `test-repl-banking` 62/0 post-22.1.
- [Source: `src/outer_interpreter.asm:444-468`] — the QUIT loop; `.quit_ok` threaded prompt block `:461-465`; STATE=0 gate `:453-460`; `w_REASSERT_BANK_cf` re-assert `:448`.
- [Source: `src/antforth.asm:797-798`] — `str_ok = " ok"` (leading space, 3 bytes), `STR_OK_LEN EQU 3`; `:781` banner `AntForth v3.0.6`.
- [Source: `src/banking.asm:32-68`] — `BANK-MAPPING-ON`/`BANK-MAPPING-OFF` DEFCODE flag-word precedent; `:103-114` `BANK@` / `w_BANK_AT_cf` reads `(IY+UserArea.current_bank)`.
- [Source: `src/structures.asm:44-66`] — UserArea layout: `current_bank` `:45`, `bank_mapping_state` flag-cell precedent `:47`, VALUE/TO-omitted note `:51-52`, `ENDS` insertion point `:66`.
- [Source: `_bmad-output/planning-artifacts/architecture.md:499`] — Epic-22 budget (prompt indicator ~20 B); `:995-1001` F4 finding + Action (user-docs entry; the §9.6 R-stack-overflow extension per PD-P4-12; the "do all your work in one bank…" recommendation text).
- [Source: `docs/antforth-banking-redesign.md:109-111`] — §5.4 per-bank state + the "doc-and-pray" cross-bank-pointer-hazard disposition (cited by the new user-docs file's first paragraph).
- [Source: `README.md:14,97,104,113`] — current `##` headings (no `## Banking` today); banking content embedded in `## Version 3.0.6` (:14-49); natural insertion point after :49.
- [Source: `tools/check-doc-sync/check-doc-sync.sh:56-62`] — the 7-file hardcoded registry; `Makefile:105-106` `check-doc-sync` target. `Makefile` `-22-1` / `-21-2` / `-21-1` isolated recipes to mirror for `-22-2`.
- Memory: `project_phase4_scope`, `feedback_phase4_probe_bank_switch_limitation`, `feedback_source_comment_discipline`, `feedback_ceremony_diminishing_returns`, `feedback_post_hw_smoke_steps_at_review` (STRONG), `feedback_no_claude_coauthor` (STRONG), `feedback_cpm_0x1a_eof_marker`, `feedback_tib_size_inline_comments`, `project_epic17_envelope`, `feedback_plain_qa_language`, `feedback_no_preexisting_discharge`, `feedback_systematic_reference_check`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Opus 4.8)

### Debug Log References

- Pre-edit baseline: 28331 B @ HEAD `d32b8dc`; test-repl 975/0 (2 SKIP), test-repl-banking 62/0, isolated `-19-3..-22-1` all PASS, straddle 3/3, file-sanity 0, check-doc-sync 0 drift.
- First full rebuild surfaced a `test-repl-banking` regression (PASS dropped 62→28, recipe died with no `FAIL:` line). Root-caused to the in-suite `_dot-banks-probe-y`: my +132 B kernel growth pushed `kernel_end` $6FAB → $702F, and the accumulated bank-0 test dictionary crossed $8000, so probe-y's **in-colon-body `1 BANK!`** ran from window-resident code (caller IP ≥ $8000) and tripped the Story-19.5.1 portal-window guard (`THROW -273`). Fixed by running probe-y's BANK! switches interactively (caller IP in the kernel QUIT loop, < $8000) — layout-independent. Blast radius was exactly probe-y (verified: no cascade).

### Completion Notes List

- **AC1 — REPL prompt indicator (opt-in, default OFF, bank-0 suppressed):** new UserArea cell `prompt_show_bank` (DEFCODE-readable, default OFF via explicit COLD zero-init since COLD inits each field rather than blanket-zeroing); setter `PROMPT-SHOW-BANK ( flag -- )` (Q1-a single setter); prefix word `(BANK-PROMPT)` inserted as one threaded cell at the head of `.quit_ok`. `(BANK-PROMPT)` prints nothing when the flag is 0 or the current bank is 0, else `[` + decimal index + `]`; it is stack-neutral (preserves BC=TOS and DE=IP across BDOS) and falls through to the unchanged ` ok` print so flag-OFF/bank-0 output is byte-identical to Phase-3.
- **AC2 — F4 user-docs entry:** `docs/banking-pointer-hazards.md` ("Cross-bank pointer hazards") cites redesign §5.4; covers HERE/LATEST, CREATE PFA, raw allocator + wordlist-head pointers, the BANK!-across anti-pattern, the architecture-bound cross-bank R-stack-overflow gotcha (architecture.md:1001 §9.6 / PD-P4-12), the "one bank per logical session" recommendation, and a `PROMPT-SHOW-BANK` cross-ref.
- **AC3 — README link:** new `## Banking` section linking to the user-docs file + a prompt-indicator tip.
- **AC4 — source citations:** `.quit_ok` thread edit + both new words carry what/why comments citing the F4 mitigation and the docs filename (no provenance dump).
- **AC5 — probes:** `tests/banking_tests_22_2.fth` + `make test-repl-banking-isolated-22-2` — 4 PASS (states a/b/c + suite-end), calling `(BANK-PROMPT)` directly, anchored as `P=[N]=`/`P==`.
- **AC6 — hardware smoke:** **HW UAT PASS** on real MicroBeast (transcript `~/Downloads/beastty-20260613-165829.bin`, v3.0.6 build). All six states verified: bank-0 suppression with flag ON, `[5] ok` on `5 BANK!`, return to bare ` ok` on `0 BANK!`, and flag-OFF producing bare ` ok` even in bank 5. Bracket renders correctly; 80-col fit confirmed.
- **AC7 — envelope:** measured **+132 B** (28331 → 28463). Accept-with-rationale (Q6): pure addition (no mechanism substitution), two necessarily-named DEFCODE words (`PROMPT-SHOW-BANK` 16 chars + `(BANK-PROMPT)` 13 chars = 29 B of name text alone) + their bodies + COLD init + the +2 B thread cell. This overshoots the optimistic ~30 B epics target / ~80 B Q6 first-cut, but is comfortably **not "structurally larger"** — Story 22.1 accepted +282 B with rationale, so +132 B sits well inside that precedent band. The ~2.4× Phase-4 multiplier underestimated here only because the two human-readable word names are long.
- **AC8 — regressions:** all green AFTER the probe-y fix (975/0 · 62/0 · isolated incl. new 22-2 · straddle 3/3 · file-sanity 0 · check-doc-sync 0 drift). check-doc-sync "recognised" per Q5-a: the README `## Banking` link resolves to the new file and no new drift is introduced (the tool's 7-file registry does not scan `docs/`, so it was not extended).

**FINDING surfaced (not discharged) — test-suite layout fragility (probe-y).** The main `tests/banking_tests.fth` compiles ~4 KB of test definitions on top of the kernel; with kernel_end now at $702F the bank-0 test dictionary crosses $8000. `_dot-banks-probe-y` performed a foreign `1 BANK!` from inside a colon body, so once that body landed above $8000 the portal-window guard fired (`-273`). This is the documented `feedback_phase4_probe_bank_switch_limitation` class — the same reason the iron-spike test was previously moved to an isolated subprocess (banking_tests.fth:603-620). I applied the **minimal robust fix**: run probe-y's `BANK!` switches interactively (kernel-loop caller IP) instead of from a colon body, preserving the exact marker-tracking verdict semantics. **This is a shared-fixture change forced by my legitimate kernel growth; flagged here + in the closing message so it can be reviewed.** Alternative dispositions if preferred: isolate probe-y to its own subprocess (iron-spike precedent), or relocate the bank-switching probes earlier in the file. Note this fragility will recur for future kernel-growing stories (22.3/22.4).

### File List

- `src/structures.asm` — add `prompt_show_bank` cell to the UserArea struct
- `src/antforth.asm` — COLD explicit zero-init of `prompt_show_bank` (step 8h)
- `src/banking.asm` — new `PROMPT-SHOW-BANK ( flag -- )` setter + `(BANK-PROMPT) ( -- )` prefix word
- `src/outer_interpreter.asm` — insert `DW w_BANK_PROMPT_cf` at the head of `.quit_ok`
- `tests/banking_tests_22_2.fth` — NEW isolated prompt-indicator probe fixture (0x1A-terminated)
- `tests/banking_tests.fth` — probe-y un-wrapped from colon body to interactive (layout-fragility fix; see Completion Notes)
- `Makefile` — new `test-repl-banking-isolated-22-2` target + `.PHONY` entry
- `docs/banking-pointer-hazards.md` — NEW user-docs "Cross-bank pointer hazards" (F4)
- `README.md` — new `## Banking` section linking to the user-docs file
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — 22-2 → in-progress → review

### Change Log

- 2026-06-13 — Story 22.2 dev-pass: opt-in REPL prompt bank indicator (`PROMPT-SHOW-BANK` + `(BANK-PROMPT)`, default OFF, bank-0 suppressed); F4 user-docs entry `docs/banking-pointer-hazards.md` + README `## Banking` link; isolated probe fixture `tests/banking_tests_22_2.fth` + Makefile target. Binary 28331 → 28463 B (+132 B, accept-with-rationale). Fixed an exposed layout-fragility in `tests/banking_tests.fth` probe-y (colon-body foreign `BANK!` crossed $8000 → interactive). All gates green. **HW UAT PASS on real MicroBeast** (transcript `beastty-20260613-165829.bin`): `[5] ok` indicator + bank-0/flag-OFF suppression all confirmed on silicon. Commit deferred to Ant. Status → review.
- 2026-06-14 — Story 22.2 CR-fix (2 code-review findings, commit `a9208d9`): (1) cleanup — extracted shared `bdos_emit_dec_byte` leaf; `(BANK-PROMPT)`'s `[N]` prompt and `print_bank_col_4`'s `.BANKS` column now share one base-10 decode (binary −17 B → 28446 B, byte-identical output); (2) test robustness — probe-y switch+print combined onto one input line (`1 BANK! .BANKS`) to drop the `source_id==0` / REASSERT-BANK coupling. Gates green (test-repl 975/0 · banking 62/0 · isolated-22-2 4/4 · straddle 3/3 · asm thread PASS). **HW UAT PASS** (transcript `beastty-20260614-084832.bin`): `[5]`/bank-0/flag-OFF + `.BANKS` right-align (single+double digit, marker row 5) on v3.0.6 silicon. Status → done.
