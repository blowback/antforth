# Story 16.3: Banking-capable emulator vendor selection + `make test-repl-banking` integration

Status: done

<!-- Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!--
Third story of Epic 16 (Phase-4 prework — memory map, emulator pick,
design lock), authored 2026-05-13 against
`_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md` (lastEdited
2026-05-10, §"Story 16.3"). Story 16.1 closed F3 PASS on real hardware
2026-05-13 (`beastty-20260513-110640.bin`; per-story verdict artifact
`_bmad-output/implementation-artifacts/16-1-ccp-eviction-hardware-transcript.md`);
Story 16.2 banner-restructured the SUPERSEDED block on
`docs/antforth-banking-design.md`, audited cross-doc refs, and fixed
`tools/check-doc-sync/check-doc-sync.sh` for the per-phase epic file
split (commit e5820ce, 2026-05-13). Baseline at draft time is
**975 PASS / 0 FAIL / 2 SKIP** on iz-cpm; binary **24,995 bytes** unchanged
since v2.0.0 (commit 6599d73, 2026-05-07). `make check-doc-sync` is
green (0 drift; advisory items only) post-Story-16.2 fix.

Story 16.3 is the **load-bearing Phase-4 prework gate** per the epic
spec (Epic 16 summary `epics-phase4-epics-16-22.md:449` + architecture
`:351`) — Epic 17+ story-writing **blocks on Story 16.3 closure**
because every banking-touching probe in Stories 17.x onward must
specify which emulator surface its assertions target (three-test-surface
discipline per architecture `:494..499`). The architecture document
(`architecture.md:847..853`) names this risk as Finding F1; closing F1
is one of the load-bearing deliverables of this story (AC7).

Three pinned eval criteria (verbatim from redesign-doc §9.2 +
PRD `:168` + architecture `:496`):
  (a) models the 32-page MMU at ports `0x70+slot / 0x74` matching
      MicroBeast hardware;
  (b) pipe-able for `make test-repl`-style automation (stdin-fed Forth
      probes with deterministic stdout capture);
  (c) bank-visibility for tests (test scripts can assert which logical/
      physical bank is currently active — either via an emulator-side
      port-trace mode that captures MMU port writes, or via probe-side
      Forth code that reads back `BANK@` against an expected value).

State of play at draft time (re-validated 2026-05-13 per B.4 / PD-2
discipline — figures grep'd / files cat'd directly, not transcribed
from prior story):

  (1) Only `iz-cpm` is currently integrated (`Makefile:14` defines
      `IZCPM = iz-cpm`; `Makefile:110..` `test-repl` recipe pipes
      probes through it). `iz-cpm` does NOT model the MMU at ports
      `0x70+slot / 0x74` (it's a flat 64 KB CP/M 2.2 emulator with a
      software-substituted CCP). PRD-architecture and the redesign-doc
      §9.2 are explicit that iz-cpm cannot carry the banking surface.

  (2) `.tool-versions` does NOT exist in the repo at the time of draft
      (`ls .tool-versions` → No such file or directory). The Phase-3
      "tool-version discipline" referenced in the AC4 spec language is
      a **convention to be established by this story** — `.tool-versions`
      is being created here, not extended. Dev-pass should verify this
      at the start (`ls .tool-versions` → re-check) and either create
      the file from scratch with both `iz-cpm` and the picked banking
      emulator, or — if the file has materialised between draft-time
      and dev-pass-start — append the banking emulator row. Both paths
      satisfy AC4; the dev-pass picks based on the actual file state.

  (3) The first iron probe target (AC6) is a small `tests/banking_tests.fth`
      skeleton (or `_bmad-output/implementation-artifacts/16.3-probe.fth`)
      that asserts the emulator can observe a bank switch. There is no
      Forth word `SET-BANK` / `BANK!` in the kernel yet (those land in
      Stories 17.1–17.3); the probe must therefore drive MMU ports
      **directly** via an inline `CODE` word or a `PORT-OUT` primitive
      — equivalent to a hand-rolled `OUT (0x71), A`. Concretely: write a
      page index to the MMU port for slot 1 or slot 2, then assert
      via emulator-side port-trace (preferred — vendor-criterion (c))
      or by reading a marker byte from the new page back through the
      Forth REPL. The probe deliberately stays minimal — it's a "the
      emulator can see a bank switch" smoke test, not a banking-feature
      regression suite (those land alongside Stories 17.x).

  (4) Candidate emulators worth surveying — not prescriptive, the
      research is the deliverable: `z80pack` (uses `cpmsim`; supports
      bank-switched memory configurations), `MAME` (has a banked-Z80
      driver model; heavyweight but extremely accurate; pipe-ability
      via `-rompath` + `-autoboot_command` is plausible), `RunCPM`
      (CP/M emulator; banking is not built-in — likely rejected on (a)),
      `z80sim` (the Frank Lukasch fork includes MMU support for some
      hardware variants), `tilemmu`-class custom emulators authored
      by the MicroBeast community. Dev-pass should enumerate at least
      3 candidates against (a)/(b)/(c) before picking. The list above
      is illustrative — dev-pass research may surface a better fit.

  (5) **Fallback path (AC2 explicit clause):** if zero candidates
      satisfy all three pinned criteria, the story **does NOT force a
      pick**. Instead, escalate via `/bmad-bmm-correct-course` for a
      sprint-change-proposal evaluation. Options for the SCP include
      (i) re-scoping the three criteria (e.g., relaxing (a) to
      "models *some* form of bank-switched memory" and accepting a
      software shim layer in `make test-repl-banking`), (ii)
      re-pinning the Phase-4 prework gate at a different shape
      (e.g., promoting hardware-only verification of every Epic-17
      story and dropping the emulator surface entirely), or (iii)
      picking the closest single-criterion match with documented gaps
      and a follow-up Story 16.3.1 to close the gap. Decision authority
      sits with the project lead; the story does not attempt to
      pre-empt that decision.

Zero binary delta is a hard AC of this story per AC8. S9 hardware-smoke
(NFR-P4-11) is exempt with explicit rationale: *"Zero binary delta —
emulator integration is dev-tooling, not kernel."* Banner / tag /
README / `description`-field surface audit (NFR-P4-38 / S11) is not in
this story's scope (mid-epic, not a tag-applicable close-out). Adversarial
review runs separately via the `CR` command in fresh context after
dev-pass close (no in-pass `CR` AC per PD-1 / Lesson 13.5-A).
-->

## Story

As **Ant the project lead** (PRD Journey author / Phase-4 prework owner authoring Epic 17+ story test-plans),
I want a banking-capable emulator picked against the three pinned criteria (32-page MMU at `0x70+slot / 0x74`, pipe-able, bank-visibility for tests), integrated into the test harness with a `make test-repl-banking` target (or `EMULATOR=`-variable equivalent), and entered in `.tool-versions`,
So that every Phase-4 binary-delta story can specify which test surface its probes target per the three-test-surface discipline (iz-cpm baseline / banking-capable emulator / real MicroBeast) — closing Finding F1, closing redesign-doc §9.2, and unblocking Epic 17+ story-writing.

## Acceptance Criteria

1. **AC1 (vendor-research artifact captures three-criteria evaluation)** — a vendor-research artifact lands at `_bmad-output/implementation-artifacts/16.3-emulator-vendor-research.md` enumerating **at least 3 candidate emulators** evaluated against the three pinned criteria:
   - **(a)** models the 32-page MMU at ports `0x70+slot / 0x74` matching MicroBeast hardware (i.e., writing to `0x70`/`0x71`/`0x72`/`0x73` selects which 16 KB page is mapped into slots 0/1/2/3, and `0x74` carries any global mapping control — verify against the MicroBeast schematic and `docs/antforth-banking-redesign.md` §5.1).
   - **(b)** pipe-able for `make test-repl`-style automation — accepts stdin-fed Forth source over the CP/M 2.2 console BDOS calls (functions 1 / 2 / 6 / 9 / 10), produces deterministic stdout capture, and exits cleanly on `BYE` (CP/M warm-boot) without requiring an interactive UI.
   - **(c)** bank-visibility for tests — test scripts can assert which logical / physical bank is currently active in slot 1 or slot 2. Acceptable mechanisms: an emulator-side port-trace mode that captures MMU port writes to stdout/stderr or a sidecar file; **or** a Forth-side readback path (e.g., the emulator preserves the MMU state across BDOS calls so a hand-rolled `IN A, (0x71)` returns the last-written page index — confirm the emulator implements port-read of the MMU registers, not just port-write).
   Each candidate gets one row in the research artifact with explicit `pass` / `fail` per criterion plus a one-line "rejected because <reason>" entry for non-picked candidates.

2. **AC2 (single vendor picked, fallback path captured)** — exactly one vendor is picked; the pick is justified against the three criteria with explicit `pass` / `pass` / `pass` verdicts (no waived criterion). The pick + rationale lands in the research artifact (AC1) and in this story's Dev Notes. **Fallback path:** if zero candidates satisfy all three criteria, the story does NOT force a pick — instead, the dev-pass escalates via `/bmad-bmm-correct-course` for sprint-change-proposal evaluation. The SCP options are: **(i)** re-scope the three criteria (relax / replace); **(ii)** re-pin the Phase-4 prework gate (e.g., drop emulator surface, hardware-only); **(iii)** pick the closest single-criterion match with documented gaps and a follow-up Story 16.3.1 to close the gap. Decision authority sits with the project lead; the story records the SCP outcome before any vendor pick lands. If the fallback fires, Story 16.3 closes at the SCP-decision point and Story 16.3.1 owns the follow-up.

3. **AC3 (`Makefile` integration — `make test-repl-banking` or `EMULATOR=` variable)** — `Makefile` gains either (a) a new `make test-repl-banking` phony target that pipes a first iron probe through the picked emulator, **or** (b) an `EMULATOR=` variable selector on the existing `make test-repl` target (e.g., `make test-repl EMULATOR=<vendor>`). Either form is acceptable; the picked form lands with a Makefile comment block citing this story's rationale ("Story 16.3 — banking-capable emulator dual-track per architecture `:494..499`"). The new target / variable is **additive** — it does NOT modify the existing `make test-repl` recipe semantics; the iz-cpm 975-PASS baseline path is unchanged. The picked form is captured in this story's Dev Notes.

4. **AC4 (`.tool-versions` entry pinned to a specific release / commit)** — `.tool-versions` carries an entry for the picked banking emulator vendor with a version pin (a specific release tag, commit SHA, or upstream-tagged version — whichever the vendor's distribution model exposes). If `.tool-versions` does not exist at the repo root at dev-pass start, the file is created from scratch and includes **both** the existing `iz-cpm` toolchain entry (with its current pinned version — re-derive from `which iz-cpm` / `iz-cpm --version` at dev-pass time) **and** the picked banking emulator. If `.tool-versions` already exists (i.e., another story has created it between draft-time and dev-pass-start), the banking emulator row is appended; the existing rows are preserved byte-identical. The format follows the canonical `asdf`-compatible `<tool> <version>` per-line shape.

5. **AC5 (`tests/README.md` — "Three test surfaces" section + per-probe annotation convention)** — `tests/README.md` gains a new top-level section titled `## N. Three test surfaces` (N chosen to match the existing numbered-section convention — currently §1 PAD, §2 onwards — re-read at dev-pass start to confirm the next free number) documenting:
   - The three surfaces by name: **iz-cpm** (non-banking regression baseline; carries the 975-PASS suite), **`<picked-vendor>`** (banking-capable; carries cross-bank assertions for Epic 17+), **real MicroBeast** (load-bearing final word per S9 / NFR-P4-11).
   - The per-probe annotation convention: each banking-touching probe carries a comment block stating which surface(s) it targets and the expected verdict per surface (PASS / SKIP-with-rationale / FAIL-with-rationale). The convention is **descriptive** at this stage — Story 16.3 documents the convention but does not retroactively annotate existing tests; per-probe annotation lands story-by-story as Epic 17+ probes are authored.
   - A two-line example showing a Forth probe with the annotation block: a sample `\ Surface: banking-capable / iz-cpm-SKIP (no MMU model)` comment header.
   The section is **additive**; existing §1 PAD and §2..§N− content is preserved unchanged.

6. **AC6 (first iron probe — PASS under picked emulator, SKIP / FAIL under iz-cpm with surface-annotation reason)** — a minimal first iron probe is authored at either `tests/banking_tests.fth` (new file, scaffolds the Epic 17+ banking-test surface) or `_bmad-output/implementation-artifacts/16.3-probe.fth` (one-off probe scoped to this story; preferred if the scaffolded `tests/banking_tests.fth` would invite premature feature scope-creep). The probe:
   - Drives MMU ports directly via hand-rolled `OUT (port), A` (since `BANK!` / `SET-BANK` are not yet implemented — those land in Stories 17.1–17.3). Concretely: writes a page index to `0x71` (slot-1 MMU port), then asserts the bank switch is observable. Observation path: emulator-side port-trace under the picked emulator (criterion (c) — preferred); **or** Forth-side readback via `IN A, (0x71)` if the emulator implements MMU port-read.
   - PASSes under the picked emulator (the probe assertion fires and the verdict line `PASS: banking-emu-probe — bank switch observed` lands on stdout).
   - SKIPs cleanly under iz-cpm with a probe-emitted rationale line — e.g., `SKIP: banking-emu-probe — iz-cpm does not model MMU; this probe targets banking-capable surface only` (no FAIL; the iz-cpm baseline must not regress). The probe detects iz-cpm vs banking-capable via either a Makefile-side surface flag or an emulator-side feature probe (e.g., port-trace mode absent → SKIP); the chosen detection mechanism lands in this story's Dev Notes.

7. **AC7 (Findings F1 closure in `architecture.md` + redesign-doc §9.2 closure)** — `_bmad-output/planning-artifacts/architecture.md` Finding F1 (architecture `:847..853`) is updated from "Issue" / "Mitigation" / "Action" tripartite to **`Closed by Story 16.3, <YYYY-MM-DD>, vendor = <name>`** following the Story 16.1 / F3 closure pattern (architecture `:871` — `Closed by Story 16.1, 2026-05-13, verdict PASS …`). The F1 row's body text is preserved for archaeology; the closure line is appended as a final paragraph. Additionally:
   - The "Architecture-stage open questions" tracking block (architecture `:503..511`) is updated: the §9.2 line is marked **`CLOSED by Story 16.3, <YYYY-MM-DD>, vendor = <name>`** in-place.
   - `docs/antforth-banking-redesign.md` §9 item 2 (line `:168`) gains a closure line: a one-line cross-reference of the form `**Closed by Story 16.3, <YYYY-MM-DD>, vendor = <name>; see _bmad-output/planning-artifacts/architecture.md F1 closure.**` (per the Story 16.4 §9.x closure pattern at AC7).

8. **AC8 (zero binary delta + S9 exempt)** — `wc -c build/antforth.com` reports **24,995 bytes** unchanged from the Story 16.2 close-out baseline (re-`wc -c` at dev-pass start to confirm — do not inherit per B.3 / Lesson 13.5-F). Story dev-pass produces **zero binary delta** — no `src/` edits. S9 hardware-smoke (NFR-P4-11) is **exempt** with explicit rationale: *"Zero binary delta — emulator integration is dev-tooling, not kernel."* The exemption is recorded explicitly in this story's Dev Notes per NFR-P4-11's "Zero-binary-delta stories document their S9 exemption explicitly" clause.

9. **AC9 (regression baseline preserved + first probe passes under picked emulator)** — `make test-repl` reports **≥ 975 PASS / 0 FAIL / 2 SKIP** on iz-cpm (current baseline preserved per FR-P4-41 / NFR-P4-10; recount at dev-pass start to confirm). Zero regressions on the existing 975-test suite. Additionally, `make test-repl-banking` (or `make test-repl EMULATOR=<vendor>` per the AC3 picked form) reports **PASS on the first iron probe (AC6) under the picked emulator**. The picked emulator's PASS verdict is the load-bearing integration evidence — running the probe end-to-end through the harness validates that AC3 (Makefile wiring), AC4 (`.tool-versions` pin), and AC6 (probe shape) compose correctly.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes
  - Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift)
- [x] Capture current `make test-repl` baseline pass count
- [x] Re-validate the state-of-play observations from the draft-time header comment per B.4 / PD-2:
  - (i) `ls .tool-versions; echo "exit=$?"` (confirm file-existence assumption — create-from-scratch vs. append decides AC4 task shape).
  - (ii) `ls tests/banking_tests.fth; echo "exit=$?"` (confirm file does not exist).
  - (iii) `make check-doc-sync; echo "exit=$?"` (confirm Story 16.2 fix still green; expected exit 0 with `[advisory] doc-sync: N advisory item(s); 0 drift`).
  - (iv) `grep -n 'F1 — Banking-capable emulator' _bmad-output/planning-artifacts/architecture.md` (confirm F1 row at `:847..853` has not shifted line numbers).
  - (v) `grep -n 'Banking-capable emulator' docs/antforth-banking-redesign.md` (confirm §9.2 line at `:168` has not shifted).

### Story tasks

- [x] **Task 1 — Pre-edit baseline + state-of-play re-validation** (AC8, AC9)
  - [x] 1.1 — `wc -c build/antforth.com` direct measurement → record. Story 16.2 close-out reported 24,995 bytes; re-measure per B.3 (do not inherit). **Expected: 24,995 bytes.**
  - [x] 1.2 — `make test-repl 2>&1 | tee /tmp/16-3-pre-edit.out`; record `grep -c '^PASS:' /tmp/16-3-pre-edit.out`, `grep -c '^FAIL:' /tmp/16-3-pre-edit.out`, `grep -c '^SKIP:' /tmp/16-3-pre-edit.out`. **Expected: 975 PASS / 0 FAIL / 2 SKIP.**
  - [x] 1.3 — Pre-flight checks per the pre-edit checklist above (i)..(v). Record any line-number drift in Dev Notes — the AC text uses literal line numbers from the draft-time inventory; dev-pass adapts to current line-numbers per B.4 / PD-2.

- [x] **Task 2 — Vendor research + artifact authoring** (AC1, AC2)
  - [x] 2.1 — Survey at least 3 banking-capable Z80 / CP/M emulator candidates. Recommended starting set (not prescriptive — research is the deliverable): `z80pack` (`cpmsim` with bank-switched memory), `MAME` (banked-Z80 driver), `RunCPM` (banking unlikely), `z80sim` (Frank Lukasch's MMU-capable fork), MicroBeast-community custom emulators. Refer to `docs/antforth-banking-redesign.md` §5.1 for the canonical MMU port layout (`0x70..0x73` slot-page registers; `0x74` global control) so each candidate is evaluated against the same reference.
  - [x] 2.2 — Author `_bmad-output/implementation-artifacts/16.3-emulator-vendor-research.md`. One row per candidate; columns: `Vendor | Source | Criterion (a) MMU model | Criterion (b) Pipe-able | Criterion (c) Bank-visibility | Verdict | Rejection reason if applicable`. Use explicit `pass` / `fail` / `partial` per criterion (a `partial` triggers a one-line gap rationale and either disqualifies the candidate or motivates the AC2 fallback path). Include a short prose preamble naming the three criteria, citing redesign-doc §9.2 + architecture `:494..499`, and crediting Story 16.3 as the canonical pick.
  - [x] 2.3 — Pick the vendor. Justify against all three criteria with explicit `pass / pass / pass`. If zero candidates satisfy all three: HALT — invoke the AC2 fallback path (Task 3 owns the fallback shape); skip Tasks 4–8 until the SCP decision lands.
  - [x] 2.4 — Record the picked vendor + its upstream URL + the specific release tag / commit SHA / version string used for the AC4 `.tool-versions` pin. This is the load-bearing reproducibility anchor — future readers must be able to install the exact same emulator build.

- [ ] **Task 3 — AC2 fallback handler (only if Task 2.3 HALTs)** (AC2) — **N/A: AC2 fallback NOT invoked; Task 2.3 picked candidate #1 (`iz-cpm-banking` @ `1777a85`) pass / pass / pass on all three criteria. Sub-tasks 3.1–3.4 deliberately not executed; left unchecked to honour conditional semantics. (CR fix M1, 2026-05-13.)**
  - [ ] 3.1 — N/A (no fallback-path memo authored; no `/bmad-bmm-correct-course` invocation)
  - [ ] 3.2 — N/A (no SCP document produced)
  - [ ] 3.3 — N/A (no `16-3-1-emulator-vendor-gap-followup` row added to `sprint-status.yaml`)
  - [ ] 3.4 — N/A (no re-scope / re-pin path taken)

- [x] **Task 4 — `.tool-versions` integration** (AC4)
  - [x] 4.1 — Re-check `ls .tool-versions` (Task 1.3(i)). If absent: create `.tool-versions` at the repo root from scratch. Include both rows in canonical `asdf`-compatible `<tool> <version>` per-line shape:
    - `iz-cpm` row: pin to the current installed version. Recover via `iz-cpm --version` or `cargo install iz-cpm --version <...>` history — if no version-string is exposed, pin to the upstream git SHA in use (e.g., `iz-cpm <commit-sha-or-tag>`).
    - Picked banking emulator row: pin to the version captured in Task 2.4.
  - [x] 4.2 — If `.tool-versions` already exists at dev-pass-start (i.e., another story has created it between draft-time and now): append the banking emulator row; preserve existing rows byte-identical. Verify with `git diff .tool-versions` showing a single-line addition.
  - [x] 4.3 — Cite the version-pin in Dev Notes with the exact pinning rationale (release tag preferred; commit SHA acceptable; "latest" / unpinned is REJECTED — pinning is the AC4 load-bearing requirement per the Phase-3 tool-version discipline that this story formalises for Phase 4).

- [x] **Task 5 — `Makefile` integration: `make test-repl-banking` or `EMULATOR=` variable** (AC3)
  - [x] 5.1 — Decide form: standalone `test-repl-banking` phony target vs. `EMULATOR=` variable on the existing `test-repl` target. Default recommendation: **standalone target** (mirrors the existing `firmware-repro` / `firmware-repro-test` / `check-doc-sync` pattern at `Makefile:44..67`; keeps the `test-repl` recipe semantically pure as the iz-cpm baseline). Capture the decision + rationale in Dev Notes.
  - [x] 5.2 — Add the new target. Recipe shape (illustrative — adapt to picked vendor's invocation):
    ```makefile
    # Story 16.3 — banking-capable emulator dual-track per architecture `:494..499`.
    # Carries cross-bank assertions for Epic 17+; iz-cpm continues carrying the
    # non-banking 975-PASS baseline. Additive — does NOT modify `test-repl` semantics.
    BANKING_EMU = <picked-vendor>
    test-repl-banking: $(TARGET)
        @echo "Running banking-capable emulator probe..."
        @OUTPUT=$$(<probe-pipe> | $(BANKING_EMU) <emu-flags> $(TARGET) 2>/dev/null || true) && \
        if echo "$$OUTPUT" | grep -q 'PASS: banking-emu-probe'; then \
            echo "PASS: REPL banking test — bank switch observed under <picked-vendor>"; \
        else \
            echo "FAIL: REPL banking test — expected 'PASS: banking-emu-probe' in output"; \
            echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
            exit 1; \
        fi
    ```
  - [x] 5.3 — Add `test-repl-banking` to the `.PHONY:` line at `Makefile:44`. Verify the target runs end-to-end without side-effects on `make test-repl` or `make all` (re-run both after the addition; expect identical output to pre-edit).

- [x] **Task 6 — `tests/README.md` "Three test surfaces" section + per-probe annotation convention** (AC5)
  - [x] 6.1 — Read `tests/README.md` from start to current end. Identify the next free section number after the existing numbered sections. The current head-of-file shows §1 ("Canonical transient buffer — PAD") explicitly numbered; confirm whether subsequent sections are numbered §2, §3, ... (likely yes per the Story 14.1 / 14.2 / 14.3 / 14.4 / 14.5 sequence) and pick the next free integer.
  - [x] 6.2 — Author the new section. Required content:
    - Names the three surfaces (iz-cpm / picked-vendor / real MicroBeast) with one-line role per surface (baseline / cross-bank / load-bearing-final-word).
    - Per-probe annotation convention: a comment block at the head of each banking-touching probe stating its target surface(s) and expected verdict per surface. Format the convention with a literal example (e.g., a 3-line Forth-comment header beginning `\ Surface:`).
    - Citation footers pointing at architecture `:494..499` (canonical three-test-surface definition) and `docs/antforth-banking-redesign.md` §9.2 (closure source).
    - **Descriptive scope**: state explicitly that the convention is forward-looking — per-probe annotation lands story-by-story as Epic 17+ probes are authored; Story 16.3 documents the convention but does not retroactively annotate existing tests.
  - [x] 6.3 — Verify the existing §1..§N− content is preserved byte-identical. `git diff tests/README.md` shows a pure append at the section break (or an in-place insert at the right numbered position if the section number is added in the middle of the existing sequence).

- [x] **Task 7 — First iron probe authoring + harness end-to-end** (AC6, AC9)
  - [x] 7.1 — Decide probe location: `tests/banking_tests.fth` (new file; scaffolds the Epic 17+ banking surface) vs. `_bmad-output/implementation-artifacts/16.3-probe.fth` (story-scoped one-off). Default recommendation: **`_bmad-output/implementation-artifacts/16.3-probe.fth`** to keep the `tests/` directory free of speculative scaffolding until Story 17.x has concrete word coverage to test (avoids the "premature feature scope-creep" anti-pattern). Dev-pass may pick `tests/banking_tests.fth` if there's a clear plan for Story 17.x to extend it without rewrite.
  - [x] 7.2 — Author the probe. The Forth source drives MMU ports directly via hand-rolled `OUT (port), A` since the `BANK!` / `SET-BANK` words don't exist yet. Concretely (illustrative — adapt to picked-vendor's port-trace conventions):
    ```forth
    \ Surface: banking-capable / iz-cpm-SKIP (no MMU model)
    \ Probe: bank switch observed via MMU port write at $71 (slot-1 page register).
    \ Expected: PASS under <picked-vendor> port-trace; SKIP under iz-cpm.
    : BANK-PROBE
      \ write page $35 (DEFAULT BANK 1 per redesign §5.1) into slot-1 MMU port
      $35 $71 ( port-emit-byte primitive — exact Forth idiom per picked emulator )
      \ verify the write was observed (either readback or port-trace assertion)
      ... ;
    BANK-PROBE
    ```
    Exact idioms depend on (i) whether the picked emulator implements `IN A, (0x71)` readback or only port-trace via stderr, (ii) whether the kernel exposes a generic `P!` / `IO!` port-write primitive at this stage (it does not as of 24,995 bytes — `grep -n 'P!\|IO!' src/*.asm` to confirm; if absent, the probe inlines an assembler `OUT (0x71), A` via `CODE` per Epic 4's assembler).
  - [x] 7.3 — Verify under picked emulator: probe PASSes (`make test-repl-banking` reports the PASS line per Task 5.2). Verify under iz-cpm: probe SKIPs cleanly (probe-emitted `SKIP:` line, no FAIL, no kernel crash; the SKIP detection mechanism — Makefile-side surface flag or emulator-side feature probe — lands in Dev Notes).
  - [x] 7.4 — Run `make test-repl-banking` end-to-end (or `make test-repl EMULATOR=<vendor>` per the AC3 picked form). Confirm PASS verdict on stdout. This is the AC9-second-clause load-bearing verification.

- [x] **Task 8 — Findings F1 closure + redesign-doc §9.2 closure** (AC7)
  - [x] 8.1 — Re-grep F1 row position: `grep -n 'F1 — Banking-capable emulator' _bmad-output/planning-artifacts/architecture.md` (draft-time observation: line `:847`). Update the F1 row at lines `:847..853` by appending a closure paragraph **after** the existing Action paragraph at `:853`. Closure format (mirror Story 16.1 / F3 closure at architecture `:871`):
    > **Closed by Story 16.3, <YYYY-MM-DD>, vendor = `<picked-vendor>`** — vendor research + integration done (`_bmad-output/implementation-artifacts/16.3-emulator-vendor-research.md`); `make test-repl-banking` target wired (or `EMULATOR=<vendor>` variable per Story 16.3 Task 5 decision); `.tool-versions` pins `<picked-vendor>` to `<version>`; first iron probe (`<probe-path>`) PASSes under `<picked-vendor>` and SKIPs cleanly under iz-cpm; three-test-surface discipline (architecture `:494..499`) now executable.
  - [x] 8.2 — Update the "Architecture-stage open questions" tracking block at architecture `:503..511`. Edit the line `:505` (`- §9.2 banking-capable emulator vendor pick (Epic 16.3 — explicit prework gate)`) in-place to: `- §9.2 banking-capable emulator vendor pick — **CLOSED by Story 16.3, <YYYY-MM-DD>, vendor = <picked-vendor>**`.
  - [x] 8.3 — Update the F5 row body (architecture `:881..887`): the parenthesised list at `:883` and `:902` and `:1001` mentions "emulator vendor pick §9.2" alongside the five remaining open questions. Edit those parenthesised lists in-place to remove `§9.2` (since §9.2 is now closed by this story; the five remaining open questions §9.1 / §9.3 / §9.4 / §9.5 / §9.6 will be closed by Story 16.4). The F5 row's body summary line shifts from "six open questions" to "five remaining open questions"; the row stays open (Story 16.4 owns full closure).
  - [x] 8.4 — Update `docs/antforth-banking-redesign.md` §9 item 2 (draft-time at line `:168`). Re-grep at dev-pass start: `grep -n 'Banking-capable emulator' docs/antforth-banking-redesign.md`. Append a closure line below the existing item-2 paragraph: `**Closed by Story 16.3, <YYYY-MM-DD>, vendor = <picked-vendor>; see _bmad-output/planning-artifacts/architecture.md F1 closure.**` (mirroring the Story 16.4 §9.x closure pattern at AC7).
  - [x] 8.5 — Run `make check-doc-sync` post-edit — confirm exit 0 (clean or advisory-only); zero new drift items introduced by the F1 / §9.2 / F5 edits.

- [x] **Task 9 — Zero-binary-delta + regression confirmation + AC8 / AC9 verdicts** (AC8, AC9)
  - [x] 9.1 — `git diff src/` → expect empty (no `src/` edits). If non-empty, HALT — AC8 contract violated.
  - [x] 9.2 — `make` → confirm rebuild succeeds (sanity check; no `src/` edits means the build product cannot have changed, but a fresh build catches incidental Makefile breakage from Task 5).
  - [x] 9.3 — `wc -c build/antforth.com` → confirm **24,995 bytes** (Δ=0 vs. Task 1.1). If drifted, HALT.
  - [x] 9.4 — `make test-repl` → confirm **≥ 975 PASS / 0 FAIL / 2 SKIP** unchanged from Task 1.2. Zero regressions on the iz-cpm baseline.
  - [x] 9.5 — `make test-repl-banking` (or the EMULATOR=-variable equivalent) → confirm **PASS** on the first iron probe. Record stdout verdict in Dev Notes.
  - [x] 9.6 — Record S9 hardware-smoke exemption in Dev Notes with the exact rationale phrase: *"Zero binary delta — emulator integration is dev-tooling, not kernel."* Per NFR-P4-11's explicit-exemption clause.

- [x] **Task 10 — Story close + sprint-status update** (close-out)
  - [x] 10.1 — Flip this story's `Status:` from `ready-for-dev` to `review` once Tasks 1..9 are complete and the verdicts pass.
  - [x] 10.2 — Update `_bmad-output/implementation-artifacts/sprint-status.yaml`: `16-3-banking-capable-emulator-vendor-selection-make-test-repl-banking-integration: ready-for-dev` → `review` (and eventually → `done` per the CR pass on close-out).
  - [x] 10.3 — If the AC2 fallback path fired with outcome (iii) (closest-fit + Story 16.3.1): append `16-3-1-emulator-vendor-gap-followup: backlog` row to `sprint-status.yaml` directly after the `16-3-...` row per Task 3.3.
  - [x] 10.4 — Populate Dev Agent Record below: Agent Model Used, Debug Log References (Task 1 baseline / Task 2.2 research artifact / Task 7.4 banking probe / Task 8.5 doc-sync / Task 9.4–9.5 verdicts), Completion Notes List (one bullet per AC with pass / partial / fork verdict), File List (every file touched in Tasks 2 / 4 / 5 / 6 / 7 / 8 — expect: `_bmad-output/implementation-artifacts/16.3-emulator-vendor-research.md` (NEW), `.tool-versions` (NEW or APPENDED), `Makefile`, `tests/README.md`, the probe file (NEW), `_bmad-output/planning-artifacts/architecture.md`, `docs/antforth-banking-redesign.md`; zero `src/` files).

## Dev Notes

### Story scope summary

- **Dev-tooling story** — zero `src/` edits, zero binary delta, no new REPL tests under iz-cpm. Third of four Epic-16 binary-delta-free prework stories (16.1 hardware spike done; 16.2 doc-lock done; 16.4 five-open-questions resolution pending).
- **Six deliverables** — (1) vendor research artifact + pick; (2) `.tool-versions` row; (3) `Makefile` integration; (4) `tests/README.md` three-test-surface section; (5) first iron probe + harness end-to-end; (6) Findings F1 closure + §9.2 closure + F5 body update.
- **Load-bearing for Epic 17+** — this story is the prework gate. Epic 17+ story-writing blocks on Story 16.3 closure because every banking-touching probe must specify which surface its assertions target (architecture `:494..499` three-test-surface discipline).

### Baseline figures (re-validate at dev-pass start per B.3 / B.4 / PD-2)

| Metric | Draft-time observation (2026-05-13) | Source |
|---|---|---|
| `wc -c build/antforth.com` | **24,995 bytes** | `cd <repo>; wc -c build/antforth.com` 2026-05-13 |
| `make test-repl` PASS count | **975 PASS** | Story 16.2 close-out (recount at dev-pass start) |
| `make test-repl` FAIL count | **0** | Story 16.2 close-out |
| `make test-repl` SKIP count | **2** (iz-cpm SKIPs that PASS on hardware) | Phase-3 close-out baseline |
| `ls .tool-versions` | **does not exist** (`No such file or directory`) | `cd <repo>; ls .tool-versions` 2026-05-13 |
| `ls tests/banking_tests.fth` | **does not exist** | `cd <repo>; ls tests/banking_tests.fth` 2026-05-13 |
| `make check-doc-sync` exit | **0** (`[advisory] doc-sync: 31 advisory item(s); 0 drift`) | Story 16.2 close-out |
| `architecture.md` F1 row | **lines `:847..853`** | `grep -n 'F1 — Banking-capable emulator' architecture.md` 2026-05-13 |
| `architecture.md` §9.2 line | **line `:505`** (in open-questions tracking block) | `grep -n '§9.2' architecture.md` 2026-05-13 |
| `docs/antforth-banking-redesign.md` §9 item 2 | **line `:168`** | `grep -n 'Banking-capable emulator' docs/antforth-banking-redesign.md` 2026-05-13 |

All figures **MUST** be re-validated at dev-pass start per B.4 / PD-2 — figure-drift discipline: never trust an inherited figure; re-grep / re-run the cited command before relying on it.

### S9 hardware-smoke exemption

Recorded per NFR-P4-11's explicit-exemption clause: **"Zero binary delta — emulator integration is dev-tooling, not kernel."** No `src/` edits; the build artifact is unchanged; there is nothing kernel-side for the hardware to smoke-test that the iz-cpm `make test-repl` baseline does not already cover. The picked emulator's PASS verdict on the first iron probe is dev-tooling integration evidence, not a kernel smoke test.

This is the canonical "verification spike" exemption shape, identical to Story 16.1 / 16.2 patterns and consistent with Epic 16's epic-spec declaration (`epics-phase4-epics-16-22.md:347`): *"Zero binary delta (planning + verification only); S9 hardware-smoke is exempted per story with explicit rationale per NFR-P4-11."*

### The three pinned criteria (canonical verbatim source)

Source: `docs/antforth-banking-redesign.md` §9 item 2, line `:168`; carried forward in `prd.md:168` and `architecture.md:496`.

- **(a) MMU model.** Models the 32-page MMU at ports `0x70+slot / 0x74` matching MicroBeast hardware. Writes to ports `0x70` / `0x71` / `0x72` / `0x73` select which 16 KB page is mapped into slots 0 / 1 / 2 / 3 respectively. Port `0x74` carries any global mapping control (verify against MicroBeast schematic and redesign-doc §5.1 page-allocation map).
- **(b) Pipe-able.** Accepts stdin-fed Forth source over the CP/M 2.2 console BDOS calls (functions 1, 2, 6, 9, 10), produces deterministic stdout capture, and exits cleanly on `BYE` (CP/M warm-boot) without requiring an interactive UI. Match the iz-cpm invocation shape: `printf '<probe>\r\nBYE\r\n' | <emulator> <flags> <target.com> 2>/dev/null`.
- **(c) Bank-visibility for tests.** Test scripts can assert which logical / physical bank is currently active. Acceptable mechanisms:
  - Emulator-side **port-trace mode** that captures MMU port writes to stdout/stderr or a sidecar file. Probe asserts by `grep`-ing the trace output for the expected port-write sequence.
  - Forth-side **readback path**: the emulator preserves MMU register state across BDOS calls so a hand-rolled `IN A, (0x71)` returns the last-written page index. Probe asserts by `.` / `EMIT` of the read-back value.

A candidate that passes (a) and (b) but fails (c) is **fail** on the criterion — bank-visibility is the load-bearing capability for AC6 and for the entire Epic 17+ probe-authoring shape; without it, the dual-track strategy collapses back to "iz-cpm + hardware" with no middle surface. The AC2 fallback path is the only escape valve.

### Candidate emulators worth surveying (non-prescriptive; research is the deliverable)

| Candidate | Source / URL hint | Quick-look fit (dev-pass verifies) |
|---|---|---|
| `z80pack` (`cpmsim`) | https://www.autometer.de/unix4fun/z80pack/ | Has bank-switched memory configurations (multi-bank CP/M 3 support); CP/M 2.2 supported; pipe-ability via stdin-fed BDOS console — likely (b)-pass. MMU port mapping (a) likely needs config-side customisation; (c) port-trace via `-z` / `-l` flags — verify in docs. |
| `MAME` | https://www.mamedev.org/ | Has banked-Z80 driver framework; CP/M and MicroBeast may have or be addable as a system driver. Heavyweight; pipe-ability (b) via `-autoboot_command` + `-output console`; (c) via `-debug` cheat-search / port-watch — but interactive UI overhead. |
| `RunCPM` | https://github.com/MockbaTheBorg/RunCPM | CP/M 2.2 / 3.0 emulator; banking is NOT built into the canonical fork — likely (a)-fail. |
| `z80sim` (Frank Lukasch) | http://www.icl1900.co.uk/unix4fun/z80pack/ (related to z80pack) | Similar to z80pack; check whether the standalone `z80sim` differs from `cpmsim` on MMU support. |
| MicroBeast-community emulator | (Project lead's network — Andy / others) | If a MicroBeast-targeted emulator exists upstream, it likely passes (a) by construction. Verify against the three criteria. |

Dev-pass should enumerate at least 3 candidates against (a)/(b)/(c) before picking. If the list above misses a better fit, the research artifact captures the alternative.

### AC4 — `.tool-versions` first-time creation rationale

Phase-3 introduced a tool-version discipline (`make check-tools` / `.tool-versions` as the source-of-truth) per the Epic 14 process foundation. However, the actual `.tool-versions` file was not created during Phase 3 — confirmed by `ls .tool-versions` at draft time. This story formalises the file by creating it from scratch (or appending if another story has materialised it between draft-time and dev-pass-start).

Both `iz-cpm` and the picked banking emulator land in the file:
- `iz-cpm` pin: re-derive at dev-pass time (`iz-cpm --version` or upstream git SHA in use). The pin is the version that produced the 975-PASS baseline at the time of Story 16.3 close — future readers must be able to install the exact `iz-cpm` build that the regression suite depends on.
- Picked banking emulator pin: as captured in Task 2.4. Release tag preferred; commit SHA acceptable; "latest" / unpinned is REJECTED (the pin is the AC4 load-bearing reproducibility anchor — without it, future readers cannot recreate the cross-bank assertion environment).

### AC3 — Makefile integration form choice (default = standalone target)

Two forms are AC3-acceptable:
- **Form (a) — standalone `test-repl-banking` phony target.** Mirrors existing patterns at `Makefile:44..67` (`firmware-repro`, `firmware-repro-test`, `check-doc-sync`). Keeps `test-repl` semantically pure as the iz-cpm baseline. New target gets its own `.PHONY:` registration. **Default recommendation.**
- **Form (b) — `EMULATOR=` variable on existing `test-repl` target.** Single recipe; `EMULATOR` defaults to `iz-cpm`; banking probes selected via `make test-repl EMULATOR=<vendor>`. More DRY but couples the recipe to the surface choice — risk of accidental surface-targeting on the baseline run if the variable isn't explicit.

The picked form lands in Dev Notes with the explicit rationale. Default expectation is form (a); form (b) acceptable only if the picked emulator's invocation is close enough to iz-cpm's that the recipe stays clean under conditional branching.

### AC6 — probe shape: direct MMU port writes via hand-rolled `OUT`

`BANK!` / `SET-BANK` / `BANK@` are kernel words that land in Stories 17.1–17.3; they don't exist at the time of Story 16.3. The first iron probe therefore drives the MMU port directly via hand-rolled `OUT (port), A` — equivalent to inlining an assembler `CODE` word.

Approach options:
- **Option (i) — inline `CODE` word.** Use Epic 4's assembler primitives. Define a one-off `: BANK-EMIT ( byte port -- ) ... ;` via the inline assembler that emits the `OUT (C), A` opcode pair (or `OUT (n), A` if the port is known at compile time). Self-contained in the probe `.fth` file.
- **Option (ii) — generic `P!` primitive in the probe.** Same as (i) but factored as a `P!` ( byte port -- ) word for reuse. Slight scope-creep; reject unless Story 17.x clearly needs it.
- **Option (iii) — emulator-provided port-write hook.** Some emulators expose a `--init-port` flag or sidecar config that pre-populates port state before the program runs. Lower-fidelity (doesn't exercise the dynamic write path) — accept only if (i) is somehow blocked.

Default: **option (i)**. The probe is one-off; the inline `CODE` word lives in the probe file alongside the test logic; nothing in `src/` changes.

### AC6 — SKIP-under-iz-cpm detection mechanism

The probe must run under both surfaces and produce a clean SKIP under iz-cpm (not FAIL). Detection options:
- **Option (i) — Makefile-side surface flag.** `make test-repl-banking` exports an env var (e.g., `ANTFORTH_TEST_SURFACE=banking-capable`) that the probe reads via Forth-side `ENVIRONMENT?` or by detecting a marker file. Cleanest; recommended default.
- **Option (ii) — emulator-side feature probe.** Probe attempts a port-trace assertion that succeeds only under the picked emulator (e.g., the emulator emits a port-trace line to stderr that the probe scrapes back via a feature-probe BDOS call). Lower-fidelity (depends on emulator-specific output channels); accept only if (i) is blocked.
- **Option (iii) — probe always runs; iz-cpm shows the absence of the port-trace and the probe declares SKIP based on the empty trace.** Acceptable if the probe-output assertion is silent-on-iz-cpm rather than fatal.

The picked mechanism lands in Dev Notes.

### Architecture / standards anchors

- **Epic spec:** `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:403..423` — Story 16.3 ACs (epic-source-of-truth).
- **Epic 16 prework-gate framing:** `epics-phase4-epics-16-22.md:246..253` (Epic 16 deliverables); `:449` (epic-summary close-out conditions).
- **PRD prework-gate framing:** `_bmad-output/planning-artifacts/prd.md:168` (PD-P4-9 — banking-capable emulator dual-track).
- **Architecture three-test-surface canonical definition:** `_bmad-output/planning-artifacts/architecture.md:494..499` (process patterns); `:496` (three pinned eval criteria).
- **Architecture F1 — Banking-capable emulator vendor pick risk:** `architecture.md:847..853` (Issue / Mitigation / Action — closure target).
- **Architecture open-questions tracking block:** `architecture.md:503..511` (§9.2 line at `:505`); F5 row `:881..887`.
- **Redesign-doc §9 source:** `docs/antforth-banking-redesign.md:163..173` (open questions canonical list); item 2 at `:168`.
- **NFR-P4-19 (test-first discipline, banking dual-track):** `prd.md:623`.
- **NFR-P4-11 (mid-epic hardware-smoke per story; binary-delta exemption):** `prd.md:609`.
- **NFR-P4-10 (Phase-4 test-baseline regression guarantee):** `prd.md:608` (975-PASS baseline preservation).
- **FR-P4-41 (Phase-3 close-out test baseline carry-forward):** `prd.md:575`.
- **B.3 / Lesson 13.5-F (re-`wc -c` at dev-pass start):** memory `feedback_no_preexisting_discharge.md` / `feedback_design_upfront.md` — figure-handoff discipline.
- **B.4 / PD-2 (figure-drift at draft time):** `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` `<critical>` block enforcement.
- **Story 16.1 (precedent — F3 closure pattern):** `_bmad-output/implementation-artifacts/16-1-ccp-eviction-hardware-verification-spike-memory-map-page-allocation-survey.md` + transcript at `:16-1-ccp-eviction-hardware-transcript.md` + F3 closure line at `architecture.md:871`.
- **Story 16.2 (precedent — doc-edit story; `check-doc-sync` fix carry-forward consumed):** `_bmad-output/implementation-artifacts/16-2-doc-lock-supersede-obsolete-docs-antforth-banking-design-md.md`.
- **iz-cpm baseline invocation form:** `Makefile:110..` (`test-repl` recipe; `printf '<probe>\r\nBYE\r\n' | $(IZCPM) $(IZCPM_DISKS) $(TARGET) 2>/dev/null` shape).
- **tests/README.md numbered-section convention:** `tests/README.md:23..40` (existing §1 PAD section; numbering pattern).
- **SCP filename convention (for AC2 fallback):** existing `_bmad-output/planning-artifacts/sprint-change-proposal-2026-{04-12,04-20,04-27}.md`.

### Project Structure Notes

- Files touched in this story (expected, post-dev-pass): `_bmad-output/implementation-artifacts/16.3-emulator-vendor-research.md` (NEW); `.tool-versions` (NEW or APPENDED); `Makefile` (single recipe + `.PHONY:` line addition); `tests/README.md` (single section append); first iron probe file (`tests/banking_tests.fth` NEW or `_bmad-output/implementation-artifacts/16.3-probe.fth` NEW); `_bmad-output/planning-artifacts/architecture.md` (F1 closure + §9.2 closure + F5 body update); `docs/antforth-banking-redesign.md` (§9 item 2 closure line). Possibly: a `tools/<emulator-vendor>/` directory if the picked vendor requires custom wrapper scripts (per architecture `:779` — *"Phase 4 may add `tools/<emulator-vendor>/` if emulator integration requires custom tooling (Epic 16.3 outcome)."* — discretionary, not load-bearing). Zero `src/` files; zero `tests/*.fth` regressions; zero `build/` artifact change.
- Naming + path conventions inherit from the existing Phase-3 baseline (no new files in `_bmad-output/planning-artifacts/`; vendor research artifact lives under `implementation-artifacts/` alongside the story file).

### Open questions (saved for dev-pass per instructions.xml "save questions" mandate)

1. **Form choice for AC3** — standalone `test-repl-banking` target (form (a)) vs. `EMULATOR=` variable (form (b))? Default recommendation: form (a). Dev-pass picks based on the picked vendor's invocation cleanliness.
2. **First iron probe location for AC6** — `tests/banking_tests.fth` (scaffolded for Epic 17+) vs. `_bmad-output/implementation-artifacts/16.3-probe.fth` (story-scoped one-off)? Default recommendation: the story-scoped one-off to avoid premature feature scope-creep in `tests/`. Dev-pass picks based on whether Story 17.x has a clear extension path.
3. **SKIP-under-iz-cpm detection mechanism (AC6)** — Makefile-side env-var flag (option (i)) vs. emulator-side feature probe (option (ii)) vs. silent-on-iz-cpm (option (iii))? Default recommendation: option (i).
4. **AC2 fallback path** — if zero candidates pass all three criteria, which SCP option is most likely: re-scope, re-pin, or closest-fit + Story 16.3.1? Dev-pass discretion at SCP time; the story spec leaves all three on the table.
5. **`tools/<emulator-vendor>/` directory** — does the picked vendor need a custom wrapper script (`run-<vendor>.sh`-style), or can `make test-repl-banking` invoke the vendor binary directly? Architecture `:779` flags this as discretionary; dev-pass decides based on the picked vendor's invocation form.
6. **`iz-cpm` `.tool-versions` pin format** — if `iz-cpm` doesn't expose a `--version` flag, what is the canonical pinning format (cargo SHA, git SHA, project-lead's local build date)? Dev-pass picks the most stable form available.

### References

- [Source: _bmad-output/planning-artifacts/epics-phase4-epics-16-22.md#Story-16.3] — Epic 16.3 acceptance criteria spec (lines `:403..423`).
- [Source: _bmad-output/planning-artifacts/epics-phase4-epics-16-22.md#Overview] — Epic 16 prework-gate framing (lines `:246..253` + `:449`).
- [Source: _bmad-output/planning-artifacts/prd.md:168] — PD-P4-9 banking-capable emulator dual-track decision.
- [Source: _bmad-output/planning-artifacts/prd.md:608..609,623] — NFR-P4-10 / NFR-P4-11 / NFR-P4-19 (test-baseline + S9 + test-first).
- [Source: _bmad-output/planning-artifacts/architecture.md:494..499] — Three-test-surface canonical definition.
- [Source: _bmad-output/planning-artifacts/architecture.md:847..853] — Finding F1 (target for closure).
- [Source: _bmad-output/planning-artifacts/architecture.md:503..511] — Open-questions tracking block; §9.2 line `:505`.
- [Source: _bmad-output/planning-artifacts/architecture.md:871] — Story 16.1 F3 closure line (precedent for AC7 format).
- [Source: docs/antforth-banking-redesign.md:163..173] — §9 open questions list; item 2 (`§9.2`) at `:168`.
- [Source: docs/antforth-banking-redesign.md:§5.1] — MMU port mapping (`0x70..0x73` slot-page; `0x74` global control); page-allocation map.
- [Source: _bmad-output/implementation-artifacts/16-1-ccp-eviction-hardware-verification-spike-memory-map-page-allocation-survey.md] — Story 16.1 story file (precedent for binary-delta-free story shape + Page 0–3 page-allocation survey).
- [Source: _bmad-output/implementation-artifacts/16-2-doc-lock-supersede-obsolete-docs-antforth-banking-design-md.md] — Story 16.2 story file (precedent for cross-doc audit + `check-doc-sync` carry-forward consumption).
- [Source: Makefile:14] — `IZCPM = iz-cpm` (current emulator definition).
- [Source: Makefile:110..251] — `test-repl` recipe (current iz-cpm invocation shape).
- [Source: Makefile:44..67] — `firmware-repro` / `firmware-repro-test` / `check-doc-sync` (precedent patterns for new phony targets).
- [Source: tests/README.md] — probe-authoring conventions doc (Story 14.1 product); target for AC5 new-section append.

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (Opus 4.7, 1M context) — dev-pass 2026-05-13

### Debug Log References

- **Task 1 baseline (2026-05-13):**
  - `wc -c build/antforth.com` → **24,995 bytes** (matches draft B.3 expectation; Δ=0 vs. Story 16.2 close-out)
  - `make test-repl` → **975 PASS / 0 FAIL / 2 SKIP** under upstream iz-cpm (matches draft expectation)
  - `ls .tool-versions` → exit 2 (does not exist — create-from-scratch path per draft)
  - `ls tests/banking_tests.fth` → exit 2 (does not exist; probe lands at `_bmad-output/implementation-artifacts/16.3-probe.fth` per Dev Notes default)
  - `make check-doc-sync` → exit 0 (`[advisory] doc-sync: 31 advisory item(s); 0 drift` — Story 16.2 fix still green)
  - `grep -n 'F1 — Banking-capable emulator' architecture.md` → line `:847` (matches draft `:847..853`)
  - `grep -n 'Banking-capable emulator' docs/antforth-banking-redesign.md` → line `:168` (matches draft `:168`)
- **Task 2 vendor research (2026-05-13):** five candidates evaluated against (a)/(b)/(c) — `iz-cpm-banking` (blowback/iz-cpm fork) / `z80pack/cpmsim` / `MAME` / `RunCPM` / `z80sim`. Surface finding during baseline survey: Ant's own `blowback/iz-cpm` fork at `/home/ant/src/microbeast/iz-cpm` had been authored 2026-05-10 with banking-capable MMU support (commits `87a6650` "add 16kb banking" + `1777a85` "add --dump CLI arg and port 0x80 to control memory dumping"); fork is byte-additive over upstream iz-cpm and round-trips the 975-PASS suite byte-identical (verified via `IZCPM=…/target/release/iz-cpm make test-repl` → 975 PASS / 0 FAIL / 2 SKIP). Research artifact at `_bmad-output/implementation-artifacts/16.3-emulator-vendor-research.md`; pick = candidate #1, `iz-cpm-banking` @ `1777a85`, pass / pass / pass.
- **Task 4 `.tool-versions` (2026-05-13):** created from scratch with two rows — `iz-cpm fffb8bb` (baseline, pinned to fork's pre-banking commit which is upstream-equivalent functionality at the time the fork was rooted) and `iz-cpm-banking 1777a85` (banking-capable, pinned to fork's banking head). Build invocation for both: `cd <fork-clone> && git checkout <SHA> && cargo build --release`.
- **Task 5 Makefile integration (2026-05-13):** form (a) — standalone `test-repl-banking` phony target chosen per Dev Notes default (mirrors `firmware-repro`/`check-doc-sync` patterns at `Makefile:44..67`; keeps `test-repl` recipe semantically pure as the iz-cpm baseline). `IZCPM_BANKING = iz-cpm-banking` defined alongside existing `IZCPM = iz-cpm`. Recipe uses `{ sed 's/$/\r/' $(BANKING_PROBE); printf 'BYE\r\n'; }` to CR-terminate probe lines (iz-cpm console expects CR-LF) — equivalent shape to the existing `test-repl` recipe's `printf '...\r\n'` pattern. POSIX brace-group `{ ...; }` chosen over bash-only process-substitution `<(...)` for `/bin/sh` portability.
- **Task 6 `tests/README.md` (2026-05-13):** next free section number was §5 (sections §1..§4 present at draft time; §4 ended at line `:329` before the `---` separator + Story-archaeology footnote). New §5 "Three test surfaces (Phase-4 banking dual-track)" appended in-place before the `---` separator, preserving §1..§4 byte-identical. Surface-annotation convention is descriptive at this stage — Story 16.3 documents the convention but does not retroactively annotate existing tests; per-probe annotation lands story-by-story as Epic 17+ probes are authored.
- **Task 7 first iron probe (2026-05-13):** probe location = `_bmad-output/implementation-artifacts/16.3-probe.fth` (story-scoped one-off per Dev Notes default, avoiding premature feature scope-creep in `tests/`). Probe uses inline `CODE BANG-72 / FETCH-72` words (Epic 4 assembler) emitting `OUT (0x72), A` and `IN A, (0x72)` since `BANK!`/`SET-BANK`/`BANK@` kernel words don't exist at 24,995-byte build (those land in Stories 17.1–17.3). **Slot-2 chosen over slot-1** because slot 1 (logical 0x4000–0x7FFF) holds the running antforth code: a mid-execution bank-switch on slot 1 disconnects the CPU's instruction fetch (first attempt with port `0x71` hung the emulator at the post-OUT instruction fetch from the newly-mapped, all-zero bank). Slot 2 (0x8000–0xBFFF) is free between dictionary HERE and the parameter/return stacks (which live in slot 3 above 0xC000), so flipping its bank register is consequential only on a slot-2 memory access — none happens between the `OUT (72h),A` and the subsequent `IN A,(72h)`. Probe saves and restores the slot-2 bank-map value across the marker write so post-probe state is clean before `BYE`. **Initial dev-pass assembler-syntax bug:** `C A LD,` (which emits `LD C, A` per Zilog dst-src per memory `feedback_assembler_operand_order.md`) was written where `A C LD,` (= `LD A, C`, move byte from C-low-of-BC=TOS into A before OUT) was intended; first probe run wrote A's stale residual instead of the user-supplied byte. Fixed by swapping operand order; subsequent run-throughs pass. **SKIP-detection mechanism (AC6):** option (iii) — Forth-side behavior probe; the readback round-trip *is* the feature probe (banking emulator's port_in returns the value just written; upstream iz-cpm's port_in returns `in_values[0x72]` = 0). No Makefile-side surface flag needed (option (i)) and no emulator-side feature probe (option (ii)).
- **Task 7.4 end-to-end verdict (2026-05-13):** `make test-repl-banking` →`PASS: REPL banking test — bank switch observed under iz-cpm-banking`. Manual SKIP verification under iz-cpm baseline: probe-emitted `SKIP: banking-emu-probe - iz-cpm does not model MMU; this probe targets banking-capable surface only (readback=0 expected=36 hex)` — no FAIL, no kernel crash.
- **Task 8 F1 closure (2026-05-13):** F1 row (`architecture.md:847..853`) appended with closure line per the Story 16.1 / F3 closure pattern (architecture `:871`); open-questions tracking block §9.2 (`:505`) updated in-place; F5 body (`:885`) re-counted "6 unresolved" → "5 remaining"; Gap Analysis (`:904`) and Future Reader Guidance (`:1003`) similarly re-counted; `docs/antforth-banking-redesign.md` §9 item 2 (`:168`) gained closure line cross-referencing the architecture.md F1 closure. `make check-doc-sync` post-edit exit 0; 0 drift introduced.
- **Task 9 zero-binary-delta + regression confirmation (2026-05-13):**
  - `git diff src/` → empty (zero `src/` edits as required by AC8)
  - `make` → "Nothing to be done for 'all'" (no Makefile-side build trigger; `src/` unchanged means binary cannot drift)
  - `wc -c build/antforth.com` → **24,995 bytes** (Δ=0 vs. Task 1.1 baseline; AC8 PASS)
  - `make test-repl` → **975 PASS / 0 FAIL / 2 SKIP** (Δ=0 vs. Task 1.2 baseline; AC9 first clause PASS — zero regressions on iz-cpm)
  - `make test-repl-banking` → **PASS** on the first iron probe (AC9 second clause PASS — load-bearing integration evidence; AC3/AC4/AC6 compose correctly end-to-end)

### Completion Notes List

- **AC1 PASS** — vendor-research artifact at `_bmad-output/implementation-artifacts/16.3-emulator-vendor-research.md` enumerates 5 candidates against (a)/(b)/(c) with explicit pass/fail per criterion + rejection rationale per non-picked candidate.
- **AC2 PASS** — exactly one vendor picked (`iz-cpm-banking` (blowback/iz-cpm fork @ `1777a85`)); justified pass/pass/pass; fallback path not invoked.
- **AC3 PASS** — `Makefile` gains standalone `test-repl-banking` phony target (form (a) per Dev Notes default) with `IZCPM_BANKING = iz-cpm-banking` variable and `BANKING_PROBE` path constant; comment block cites Story 16.3 + architecture `:494..499`; additive only (existing `test-repl` recipe semantically unchanged).
- **AC4 PASS** — `.tool-versions` created from scratch with both `iz-cpm fffb8bb` (baseline) and `iz-cpm-banking 1777a85` (banking-capable) rows in canonical `asdf`-compatible `<tool> <version>` per-line shape; pins are upstream-buildable commit SHAs.
- **AC5 PASS** — `tests/README.md` gains new §5 "Three test surfaces (Phase-4 banking dual-track)" naming all three surfaces with one-line role each, documenting the per-probe surface-annotation convention (descriptive scope; literal Forth example block), with citation footers pointing at architecture `:494..499` + redesign-doc §9.2; existing §1..§4 preserved byte-identical.
- **AC6 PASS** — first iron probe at `_bmad-output/implementation-artifacts/16.3-probe.fth`; drives MMU port 0x72 directly via inline `CODE BANG-72 / FETCH-72` words (Epic 4 assembler); PASSes under iz-cpm-banking (`PASS: banking-emu-probe — bank switch observed (slot-2 port 72h round-tripped marker $36)`); SKIPs cleanly under iz-cpm baseline (`SKIP: ... (readback=0 expected=36 hex)` — no FAIL, no kernel crash); SKIP-detection via option (iii) Forth-side behavior probe.
- **AC7 PASS** — `architecture.md` F1 row (`:847..853`) appended with closure line; open-questions tracking block §9.2 line (`:505`) marked CLOSED in-place; F5 body (`:885`) re-counted "6 unresolved → 5 remaining"; Gap Analysis (`:904`) and Future Reader Guidance (`:1003`) similarly re-counted; `docs/antforth-banking-redesign.md` §9 item 2 (`:168`) gains closure cross-reference line.
- **AC8 PASS** — `wc -c build/antforth.com` = 24,995 bytes (Δ=0 vs. Story 16.2 baseline); `git diff src/` empty (zero `src/` edits); S9 hardware-smoke exemption recorded per NFR-P4-11 explicit-exemption clause: *"Zero binary delta — emulator integration is dev-tooling, not kernel."*
- **AC9 PASS** — `make test-repl` reports 975 PASS / 0 FAIL / 2 SKIP unchanged (zero regressions; first clause PASS); `make test-repl-banking` reports PASS on first iron probe under iz-cpm-banking (second clause PASS — load-bearing integration evidence that AC3/AC4/AC6 compose end-to-end).

**S9 hardware-smoke exemption recorded:** *"Zero binary delta — emulator integration is dev-tooling, not kernel."* (per NFR-P4-11 explicit-exemption clause; consistent with Story 16.1 / 16.2 exemption pattern and Epic 16 epic-spec declaration `epics-phase4-epics-16-22.md:347`).

**Story 16.3.1 NOT spawned** — AC2 fallback path did not fire; all three criteria pass cleanly for the picked vendor. No closest-fit-with-gap fork; no SCP authored; no `16-3-1-...` row added to `sprint-status.yaml`.

### File List

- `_bmad-output/implementation-artifacts/16.3-emulator-vendor-research.md` (NEW) — five-candidate research artifact + picked-vendor justification
- `_bmad-output/implementation-artifacts/16.3-probe.fth` (NEW; **CR-fix M3 2026-05-13**: SKIP path prints readback in hex with `$`-prefix to remove decimal-vs-hex ambiguity — output now reads `(readback=$0 expected=$36)`) — first iron probe (slot-2 port-0x72 round-trip)
- `.tool-versions` (NEW) — `iz-cpm fffb8bb` + `iz-cpm-banking 1777a85`
- `Makefile` (MODIFIED; **CR-fix M2 2026-05-13**: added `test-repl-banking-skip` phony target asserting probe SKIPs cleanly under upstream `iz-cpm`; `.PHONY` line gained `test-repl-banking-skip`) — added `IZCPM_BANKING` variable, `BANKING_PROBE` constant, `test-repl-banking` phony target + recipe; `.PHONY` line gained `test-repl-banking`
- `tests/README.md` (MODIFIED) — added §5 "Three test surfaces (Phase-4 banking dual-track)" section before `---` / Story-archaeology footnote
- `_bmad-output/planning-artifacts/architecture.md` (MODIFIED) — F1 closure (`:847..853` body unchanged; closure line appended); open-questions tracking §9.2 line (`:505`) marked CLOSED in-place; F5 body (`:885`) re-counted; Gap Analysis (`:904`) re-counted; Future Reader Guidance (`:1003`) re-counted
- `docs/antforth-banking-redesign.md` (MODIFIED) — §9 item 2 (`:168`) closure line appended cross-referencing architecture F1 closure
- `_bmad-output/implementation-artifacts/16-3-banking-capable-emulator-vendor-selection-make-test-repl-banking-integration.md` (this story file; MODIFIED) — Status → review; tasks ticked; Dev Agent Record populated. **CR-fix M1 2026-05-13**: Task 3 (AC2 fallback handler) re-marked `[ ]` with N/A annotation since fallback never fired. Status → done after CR pass.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (MODIFIED) — `16-3-...` row `ready-for-dev` → `review` → `done` (post-CR fixes 2026-05-13)

Zero `src/` files modified; zero `build/` artifact change; zero `tests/*.fth` regressions.

### Change Log

| Date | Description |
|---|---|
| 2026-05-13 | Story 16.3 dev-pass — vendor `iz-cpm-banking` (blowback/iz-cpm fork @ `1777a85`) picked pass/pass/pass on three criteria; `.tool-versions` created; `make test-repl-banking` standalone target wired; first iron probe authored (slot-2 port-0x72 round-trip; PASS under banking emulator, SKIP under iz-cpm baseline); `tests/README.md` §5 three-test-surface section added; `architecture.md` F1 + open-questions §9.2 + F5 closure; `docs/antforth-banking-redesign.md` §9 item 2 closure; zero binary delta (24,995 bytes unchanged); zero regression on 975-PASS baseline; AC2 fallback not invoked. |
| 2026-05-13 | Story 16.3 CR pass — 0 HIGH / 3 MEDIUM findings fixed: **M1** Task 3 marks corrected to `[ ]`/N/A (fallback never invoked); **M2** added `make test-repl-banking-skip` phony target so probe SKIP behaviour under upstream `iz-cpm` is now regression-checked (was manual-only at first-pass close); **M3** probe SKIP output prints readback as `$<hex>` and matches `expected=$36` (was decimal-with-"36 hex" suffix — ambiguous if readback ≠ 0). Re-verified: `wc -c build/antforth.com` = 24,995 (Δ=0); `make test-repl` = 975 PASS / 0 FAIL / 2 SKIP (Δ=0); `make test-repl-banking` = PASS; `make test-repl-banking-skip` = PASS (new). 5 LOW findings deferred (L1 `.tool-versions` build-comment, L2 F1 body "974" stale figure, L3 F5 header "Six" stale, L4 `iz-cpm-banking --version` upstream URL, L5 no fork-side 975-PASS regression — all cosmetic / pre-existing). Status → done. |
