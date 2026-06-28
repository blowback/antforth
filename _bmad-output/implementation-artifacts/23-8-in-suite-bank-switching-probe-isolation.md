# Story 23.8: In-suite bank-switching probe isolation (close AI-22-5)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Drafted 2026-06-28 (Epic-23 retrospective, action item AI-23-1) to discharge
     the Epic-22 retro commitment AI-22-5, re-verified against live test sources
     the same day.

     POST-CLOSE-OUT, TEST-INFRA ONLY. Phase 5 is CLOSED (v3.1.0 shipped). This
     story touches NO kernel source — 0 binary bytes. It does not gate the v3.1.0
     tag. Scheduled into Epic 23 as Story 23.8 (sprint-status 2026-06-28,
     ready-for-dev).

     HONEST CURRENT-STATE FINDING (verified 2026-06-28, drives the framing):
     There are CURRENTLY ZERO in-suite probes at risk. The 2026-06-28 de-coloning
     done inside Story 23.6 already converted the at-risk .BANKS display probes
     (X/Y/Z/M1/W in tests/banking_tests.fth:368-467) to INTERPRET level, and the
     Story 22.2 prompt probes were earlier moved to an isolated fixture
     (tests/banking_tests_22_2.fth). Every remaining in-suite colon-bodied probe
     either stays < $8000 or does NOT cross-bank-invoke. So this is NOT a
     fix-a-live-break story. It is the HARDENING the retro chose over "accept the
     reactive pattern as standing practice": make the main suite STRUCTURALLY
     immune to kernel growth (carry no foreign-BANK! probe at all) and add a
     regression lint so the discipline cannot silently rot back. Ant chose "do the
     isolated-fixture migration" over "accept reactive" at the 23 retro — this is
     that, done minimally. -->

## Story

As a **maintainer of the antforth banking test suite**,
I want **the main in-suite `test-repl-banking` run to contain no probe that
switches into a foreign bank, with a lint that fails the build if one is
re-introduced**,
so that **future kernel growth can never again push a bank-switching probe across
the `$8000` portal boundary and trip the unguardable straddle halt — we stop
relying on per-incident de-coloning discipline (the whack-a-mole of stories
22.2 / 23.2 / 23.6) and make immunity structural.**

## Context — the recurring fragility and why "reactive" was rejected

The portal-window aliasing halt (`feedback_banking_probe_straddle_halt`,
`feedback_phase4_probe_bank_switch_limitation`, ADR 19.5 DR-1): when an in-suite
probe (a) defines a colon body that lands above `$8000` because kernel growth has
pushed bank-0 `HERE` up, and (b) invokes that body after a foreign `BANK!`, the
iz-cpm-banking emulator takes an F1-unguardable halt (`-273` portal guard) — the
banking gate hangs and downstream suite output vanishes. The feature is fine; the
*probe placement* is the hazard.

This has been patched reactively three times:

- **Story 22.2** — prompt-indicator probes moved to an isolated fixture
  (`tests/banking_tests_22_2.fth`; declared isolated at its header "every probe
  switches into a non-zero bank").
- **Story 23.2** — `+BANK`-cap probe restructured to interpret-level driving.
- **Story 23.6** — its +100 B guard tipped the `.BANKS` display section across
  `$8000`; probes X/Y/Z/M1/W de-coloned to interpret level
  (`tests/banking_tests.fth:368-467`, comments dated 2026-06-28).

Epic-22's retrospective committed **AI-22-5**: *"if Phase 5 grows the kernel
further, pre-emptively migrate remaining in-suite non-zero-bank probes to isolated
fixtures."* That pre-emptive migration was never done — each recurrence was handled
in place. The Epic-23 retrospective (2026-06-28) made the call: **do the migration
/ hardening, don't bless the reactive pattern.** This story is that discharge.

**Current state (verified 2026-06-28 — state plainly, do not overclaim a fire):**
0 in-suite probes are presently at risk. The `.BANKS` probes run at interpret
level; the remaining in-suite colon probes (`_probe-1`..`_probe-d`, the 18.x
probes, `_probe-19.5.2-a`) do not foreign-`BANK!` after definition. So the value
here is *prevention and structural guarantee*, not repair: interpret-level
placement is robust but is a **discipline** a future careless edit (re-coloning a
`.BANKS` probe, or adding a new bank-switching probe to the main file) can break
silently — and it would only surface as a mysterious suite hang on some later
kernel-growing story.

## Acceptance Criteria

**AC1 — Bank-switching display probes live in an isolated fixture.** The `.BANKS`
probes that switch banks (X/Y/Z/M1/W, currently interpret-level in
`tests/banking_tests.fth:368-467`) are moved into a dedicated isolated fixture
(`tests/banking_tests_dot_banks.fth`) run by its own `make
test-repl-banking-isolated-dot-banks` target (mirroring the existing
`test-repl-banking-isolated-22-*` targets). Their assertions (the `PASS:`/`INFO:`
witnesses) are preserved byte-for-byte in intent; the isolated fixture reproduces
the same coverage in a fresh emulator instance (where bank-0 `HERE` is low, so the
probes are layout-immune regardless of how the probe file itself is structured).

**AC2 — The main `test-repl-banking` suite carries no foreign `BANK!`.** After the
move, `tests/banking_tests.fth` contains no probe that switches into a bank `N≥1`
and then relies on in-suite execution (colon body or otherwise) — `BANK!` to a
non-zero bank appears only in already-isolated fixtures. Any genuinely
bank-0-only / setup `BANK!` usage that must remain is documented inline with why
it is safe.

**AC3 — Regression lint (the durability deliverable).** A new lightweight check —
`make lint-banking-probes` (grep-based; wired into the default test/gate sweep and
`.PHONY`) — **fails** if `tests/banking_tests.fth` (the main in-suite file only,
not the isolated fixtures) contains a foreign `BANK!` (`[1-9]... BANK!` / any
`BANK!` not preceded by `0`) outside an explicitly allow-listed, commented setup
line. The check is a few lines of `grep`, not a framework
(`feedback_ceremony_diminishing_returns` — right-sized: it is the single
enforcement that makes the migration durable, nothing more).

**AC4 — Negative test for the lint.** Demonstrate (in the story's Dev Notes, via a
throwaway planted violation reverted before commit) that `make lint-banking-probes`
actually FAILS on an injected `3 BANK!` in the main file — a lint that cannot fail
is theater.

**AC5 — All gates green, zero binary delta.** `make test-repl` (975/0),
`test-repl-banking`, every `test-repl-banking-isolated*` (including the new
dot-banks fixture), `test-straddle-regression` (3/3), `test-file-sanity` all green.
`wc -c build/antforth.com` is **byte-identical** to the pre-story build (no kernel
source touched — confirm and record).

**AC6 — Authoring rule documented + AI-22-5 closed.** A one-line test-authoring
rule is recorded where the suite conventions live (the banking-test header comment
and/or the relevant `docs/` test note): *"No probe in the main in-suite
`banking_tests.fth` may `BANK!` into a non-zero bank; bank-switching probes go in
an isolated fixture (`test-repl-banking-isolated-*`)."* The Epic-22 retro action
AI-22-5 is noted discharged (memory `antforth-3-1-0-phase-5-scope` follow-up
entry updated).

## Tasks / Subtasks

### Pre-edit baseline

- [x] `wc -c build/antforth.com` → record (must be byte-identical at close; this
  story is test-only).
- [x] Run the full gate green once (`make test-repl test-repl-banking
  test-straddle-regression test-file-sanity` + the `test-repl-banking-isolated*`
  set) to confirm a clean start and capture current `.BANKS`-probe pass counts.

### Task 1 — Carve out the isolated dot-banks fixture (AC1)

- [x] Create `tests/banking_tests_dot_banks.fth` (end with `BYE`; 0x1A-terminate
  only if it will be SLIDE-transferred). Move probes X/Y/Z/M1/W
  (`tests/banking_tests.fth:368-467`) into it, preserving each sentinel pair
  (`---dot-banks-probe-x-start---` … etc.) and assertion so the grep witnesses are
  unchanged.
- [x] In a fresh isolated emulator instance, bank-0 `HERE` is low — the probes may
  even be re-coloned safely there, but keep them as-is to minimise churn; the point
  is isolation, not re-structuring.

### Task 2 — Wire the make target (AC1)

- [x] Add `make test-repl-banking-isolated-dot-banks` mirroring the recipe shape of
  `test-repl-banking-isolated-22-2` (`Makefile:~1158`): `sed 's/$$/\r/'
  tests/banking_tests_dot_banks.fth | $(IZCPM_BANKING) $(IZCPM_DISKS) $(TARGET)`
  then grep each `PASS:` witness. Add to `.PHONY` and to the aggregate
  isolated-banking sweep (and the close-out/regression sweep), NOT to plain
  `test-repl`.

### Task 3 — Strip the main suite + document (AC2, AC6)

- [x] Remove the migrated probe blocks from `tests/banking_tests.fth`; leave a
  one-line breadcrumb comment pointing to the new fixture (what + why, no
  provenance bloat — `feedback_source_comment_discipline`).
- [x] Add the authoring-rule one-liner to the banking-test header comment.
- [x] Audit the remaining file for any other foreign `BANK!` (grep `BANK!`); for
  each surviving occurrence, confirm it is bank-0-only/setup and annotate, or move
  it.

### Task 4 — Regression lint + negative test (AC3, AC4)

- [x] Add `make lint-banking-probes`: grep `tests/banking_tests.fth` for a
  non-zero-bank `BANK!` outside allow-listed commented lines; exit non-zero with a
  clear message if found. Keep it to a handful of lines.
- [x] Wire into the default gate sweep + `.PHONY`.
- [x] Negative test: plant a `3 BANK!` line, confirm `make lint-banking-probes`
  fails, revert. Record the observed failure output in Dev Notes (AC4).

### Task 5 — Close (AC5, AC6)

- [x] Full gate green; `wc -c` byte-identical (record).
- [x] Update memory `antforth-3-1-0-phase-5-scope` follow-up entry: AI-22-5
  discharged via Story 23.8 (structural isolation + lint).
- [x] No S9 hardware-smoke needed (no binary delta, emulator-only test infra) —
  state this explicitly at close rather than omitting it.

## Dev Notes

### Why this is hardening, not repair (read before sizing effort)

The recon at draft time (2026-06-28) found **0 currently-at-risk in-suite probes**.
Do not pad this story into a large migration — the at-risk display probes are
already interpret-level; the job is to (1) move them into a fixture so the main
suite is structurally clean, and (2) add the grep-lint so it stays clean. If during
the work you find an in-suite foreign-`BANK!` probe the recon missed, that is the
genuine migration target — handle it the same way (fixture + lint catches it).

### Scope / non-goals

- **0 kernel bytes.** If you find yourself editing `src/`, stop — this story is
  test-infra only.
- Not retrofitting the already-isolated 19.x/20.x/21.x/22.x fixtures — they are
  fine.
- Not touching `test-straddle-regression` (it is a calibrated regression driver,
  not an in-suite probe).
- Lint stays a grep, not a framework — the retro explicitly weighed this against
  ceremony-diminishing-returns and chose the minimal enforcement.

### Ledger

Binary: 0 B (test-infra). This discharges Epic-22 AI-22-5 and Epic-23 AI-23-1.

## Dev Agent Record

### Implementation Plan

Test-infra only (0 kernel bytes). Migrate every in-suite foreign (`N≥1`) `BANK!`
probe out of `tests/banking_tests.fth` into an isolated fixture run by its own
make target, then add a grep lint (prereq of `test-repl-banking`) that fails if a
foreign `BANK!` is re-introduced without an allow-list marker.

### Completion Notes

- **Recon corrected the draft.** The draft asserted "0 in-suite probes at risk."
  A `grep -nE '[1-9][0-9]*[[:space:]]+BANK!' tests/banking_tests.fth` at dev time
  found the draft had only inspected the `.BANKS` display probes — two live
  foreign-`BANK!` sites remained: **`_probe-7`** (`1 BANK!` round-trip, colon
  body) and **`.BANKS` probe Y** (`1 BANK!`, interpret-level). So this was part
  *repair*, part *hardening*, not pure hardening.
- **AC1 + AC2 — migration.** Created `tests/banking_tests_dot_banks.fth`
  (`make test-repl-banking-isolated-dot-banks`) holding probe 7 + `.BANKS` probes
  X/Y/Z/M1/W with byte-identical sentinels/assertions. Removed both blocks from
  the main suite (breadcrumbs left), removed `bank-store-round-trip-1` from the
  main recipe's pattern list, and deleted the main-recipe `.BANKS` grep block
  (moved into the new target). 7 PASS in the fresh emulator (probe-x `TU=199`
  confirms low bank-0 HERE → layout-immune). Main `test-repl-banking` carries no
  foreign `BANK!` now; the 4 legitimate stayers are documented + allow-listed:
  `99 BANK!` (aborts before switch), `5 BANK!`×2 (`_iron-spike-test`, run only in
  an isolated subprocess), `_p1951a-victim 1 BANK!` (F1 portal-guard, CATCHes
  -273).
- **AC3 — lint.** `make lint-banking-probes` (grep-only): matches
  `[1-9][0-9]*[[:space:]]+BANK!`, structurally skips `\` comment lines and `."`
  verdict strings, excludes `LINT-ALLOW-BANK`-marked lines. Wired as a prereq of
  `test-repl-banking` (+ `.PHONY`). PASSes on the cleaned file.
- **AC4 — negative test.** Appended `3 BANK!` to the main file →
  `make lint-banking-probes` printed `FAIL: ... 1839:3 BANK!` and exited 2;
  reverted; re-ran → PASS. Output in Debug Log below.
- **AC5 — gates + bytes.** `wc -c build/antforth.com` = **29091, byte-identical**
  pre/post (no `src/` touched). Full sweep green, 0 FAIL lines across: `test-repl`
  (1005 PASS / 0 FAIL / 2 SKIP — the AC's "975" is a stale baseline figure),
  `test-repl-banking`, all `test-repl-banking-isolated*` (incl. new dot-banks),
  `test-repl-banking-23-6/23-7`, `test-straddle-regression`, `test-file-sanity`,
  `lint-banking-probes`.
- **AC6 — authoring rule + AI-22-5.** One-line rule added to the
  `banking_tests.fth` header. Memory `antforth-3-1-0-phase-5-scope` Story-23.8
  follow-up entry updated: AI-22-5 discharged.
- **No S9 hardware-smoke required.** This story has zero binary delta and is
  emulator-only test infrastructure — there is no silicon-affecting change to
  smoke. (Stated explicitly per the close-out task, not omitted.)

### Debug Log — AC4 negative-test evidence

```
$ printf '\n3 BANK!\n' >> tests/banking_tests.fth   # planted violation
$ make lint-banking-probes
FAIL: lint-banking-probes — foreign (non-zero) BANK! in main in-suite tests/banking_tests.fth.
  Move it to an isolated fixture (test-repl-banking-isolated-*), or if it ABORTs/CATCHes before any switch add a trailing '\ LINT-ALLOW-BANK:' marker:
1839:3 BANK!
make: *** [Makefile:378: lint-banking-probes] Error 1   # exit 2
$ # reverted planted line
$ make lint-banking-probes
PASS: lint-banking-probes — no un-allow-listed foreign BANK! in tests/banking_tests.fth
```

### File List

- `tests/banking_tests_dot_banks.fth` (NEW) — isolated fixture: probe 7 +
  `.BANKS` probes X/Y/Z/M1/W.
- `tests/banking_tests.fth` (MOD) — removed probe 7 + `.BANKS` block (breadcrumbs
  left); added `\ LINT-ALLOW-BANK:` markers to the 4 stayers; authoring-rule
  header comment.
- `Makefile` (MOD) — new `test-repl-banking-isolated-dot-banks` target; new
  `lint-banking-probes` target (prereq of `test-repl-banking`); both added to
  `.PHONY`; removed migrated `bank-store-round-trip-1` pattern + `.BANKS` grep
  block from the main `test-repl-banking` recipe.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (MOD) — `23-8` →
  in-progress → review.

### Change Log

- 2026-06-28 — Story 23.8 implemented: migrated in-suite bank-switching probes
  (probe 7 + `.BANKS` X/Y/Z/M1/W) to `tests/banking_tests_dot_banks.fth`; added
  `lint-banking-probes` regression lint; allow-listed 4 legitimate stayers;
  authoring rule documented. 0 binary bytes (29091 byte-identical). Discharges
  AI-22-5 / AI-23-1. Status → review.
- 2026-06-28 — Code review complete (zero binary delta, emulator-only test
  infra, no S9 HW-smoke required); `lint-banking-probes` + `test-repl` re-run
  green. All ACs met. Status → done.
