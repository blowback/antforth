# Story 24.3: Standing $8000-straddle guard (test-infra interlude)

Status: ready-for-dev

> Post-close test-infra interlude under Epic 24 (mirrors the 23.7/23.8 pattern:
> epic stays `done`, follow-ups land under it). Gates **Epic 25**, not the Epic-24
> retro. **Zero kernel bytes** — Makefile/tests/tools only; no NFR-P6-10 envelope
> consumption. Disposition: AI-24-1, **greenlit 2026-06-29** ("build a standing
> guard (lint)").

## Context — why

The `$8000` slot-2 straddle halt has now hung a probe **four times** (Epic 22,
23.2, 23.6, 24.2), each fixed reactively by de-colon-ing the probe and driving it
at interpret level. Story 23.8 migrated the probes *at-risk at 23.8's kernel
size* but established **no standing guard**, so Story 24.2's +97 B pushed a
**fresh** colon body (`_probe-minus-bank-ldir`) across the window — both PASS
lines printed, then the IP wedged crossing `$8000` (an infinite hang, not a FAIL).

Root cause (`feedback_banking_probe_straddle_halt`): a colon body that **mutates
the bank window** (`+BANK` / `-BANK` / `BANK!` / `BANKS-CLEAR`) is straddle-fatal
once cumulative kernel growth pushes its threaded cells across `$8000` — after a
switch, the body's upper half is in a re-mapped window and the IP reads garbage.
The established safe pattern is **interpret-level orchestration** (`'` not `[']`;
witnesses printed for the Makefile to assert). This story makes that rule
**mechanical** and makes any residual hang **fail loud**.

Why the existing tools don't cover it:
- `lint-banking-probes` only greps `BANK!`, excludes `0 BANK!`, ignores
  `+BANK`/`-BANK`, and covers only `tests/banking_tests.fth`. The 24.2 probe used
  `+BANK -BANK 0 BANK!` — invisible to it.
- `test-straddle-regression` characterizes the straddle *class* against a
  synthetic fixture; it never scans the *real* probe files.

## Acceptance Criteria

**AC1 — colon-body bank-mutation lint (root-cause prevention).**
A static lint flags any bank-window-mutating token — `+BANK`, `-BANK`, `BANK!`
(including `0 BANK!`), `BANKS-CLEAR`, and `[']`/`'`-deferred forms of these —
that appears **inside a colon body** (`: … ;`) in the non-isolated in-suite probe
files (at minimum `tests/banking_tests.fth`; cover every `.fth` fed into a
concatenated multi-probe run). Comment text (`\ …`) and `."`-string contents are
exempt. An explicit `\ LINT-ALLOW-STRADDLE: <reason>` line-marker is the escape
hatch for a body proven safe (bank-0-only, or a guaranteed-small isolated
fixture). Fold into `lint-banking-probes` (extend) or a sibling `lint-straddle`
target — implementer's call; keep one `make` entry point.

**AC2 — fail-loud timeout (the "no infinite hang" guarantee).**
Every REPL-probe emulator invocation (`$(IZCPM)` / `$(IZCPM_BANKING)` pipes) is
wrapped so a wedge terminates with a nonzero exit + diagnostic instead of hanging
CI forever. Use `timeout` with a generous bound that never trips a healthy run
(start ~30 s; tune if any real probe legitimately runs longer). On the timeout
exit code emit: `FAIL: <recipe> — probe run timed out (possible $8000 straddle
hang; see feedback_banking_probe_straddle_halt)`. If Story 24.4 lands first, the
timeout lives in its shared helper and this AC is satisfied by adopting it.

**AC3 — HERE-headroom early warning (trend signal, optional-but-recommended).**
After the in-suite banking run, assert `HERE` sits below a safety margin from
`$8000` (e.g. fail if `HERE > $7C00`). This warns when probe accumulation is
trending toward the cliff **before** a future story tips a probe over. Honest
caveat to put in the recipe comment: this is a *trend* warning, not a per-probe
hang preventer — a body that straddles mid-run has already hung (caught by AC2).

**AC4 — the lint is itself tested (positive + negative).**
A self-test proves the lint **flags** the pre-24.2 `_probe-minus-bank-ldir`
colon-body form (use a committed at-risk snippet fixture) and **passes** the
current interpret-level form. A lint that can't fail is not a guard.

**AC5 — wired in + green.** The new check runs in the default test/gate target
and passes on the current tree. No false positives on existing isolated fixtures.

## Mechanism (recommended)

- **AC1 lint** — `awk` over each target file tracking colon scope: increment a
  depth flag on a standalone `:` token, clear it on `;`; while in-scope, scan for
  the bank-mutating token set (after stripping `\ …` comments and `." … "`
  strings) minus `LINT-ALLOW-STRADDLE` lines. Emit file:line on any hit, list
  them, `exit 1`. Mirror the existing `lint-banking-probes` message style (name
  the fix: "drive it at interpret level, or add `\ LINT-ALLOW-STRADDLE:`").
- **AC2 timeout** — `timeout 30 <emu-cmd> … || rc=$?;` map `rc==124` to the
  diagnostic. (`timeout` is already available in the toolchain image.)
- **AC3 headroom** — append `." here-headroom: " HERE . CR` to the in-suite run
  (or a dedicated one-line probe) and assert the printed value `< 31744` ($7C00)
  in the recipe; or read it from the existing CL-tail probe boot.

## Files

- `Makefile` — extend `lint-banking-probes` (or add `lint-straddle`); add
  `timeout` to REPL-probe pipes; add the HERE-headroom assert.
- `tests/` — at-risk snippet fixture for AC4; lint self-test script.
- (no `src/` changes — zero kernel delta.)

## Test plan / validation

- `make lint-banking-probes` (or `lint-straddle`) PASS on current tree.
- Self-test: feed the at-risk fixture → lint FAILs; feed current
  `banking_tests.fth` → PASS.
- Temporarily lower the AC2 timeout to ~1 s against a deliberately-wedged probe →
  confirms a loud `FAIL … timed out`, not an infinite hang.
- Full `make test` gate green, identical PASS set otherwise.

## References

- `feedback_banking_probe_straddle_halt` — drive bank orchestration at interpret
  level; keep colon-body probes clear of `$8000`.
- `feedback_phase4_probe_bank_switch_limitation` — bank-0-only + IN-BANK with
  kernel-CFA xt's are the workable colon-body patterns.
- Epic 24 retro AI-24-1; existing `lint-banking-probes` (Makefile) and
  `test-straddle-regression` (`tests/straddle_repro_sweep.sh`).
