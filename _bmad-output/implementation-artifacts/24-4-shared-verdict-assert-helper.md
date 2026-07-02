# Story 24.4: Shared Makefile verdict-assert helper (test-infra interlude)

Status: done

> Post-close test-infra interlude under Epic 24 (mirrors 23.7/23.8). Gates
> **Epic 25** (probe-heavy). **Zero kernel bytes** — Makefile/tests/tools only.
> Disposition: AI-24-2 (escalated from AI-23-4 after its 4th re-derivation),
> **greenlit 2026-06-29** ("build it now"). Land **before or with** Story 24.3 so
> 24.3's AC2 timeout can live in this helper.

## Context — why

The REPL-verdict-grep block has been hand-re-derived in **6+** recipes
(`test-repl-timer`, `-value-to`, `-in-out`, `-ud-env`, `-asm`, `-banking`). Each
re-implements the same gnarly, easy-to-get-wrong assertion logic:

- `^FAIL:` runtime-fail detection;
- per-pattern column-0-anchored match `grep -aqE "^$pat"` (the **23.2 lesson**:
  unanchored matches false-green on the REPL's echoed `." PASS: …"` source);
- `grep -a` for NUL-byte safety (the 23.3 lesson);
- `\r`/CRLF stripping;
- `xxd` dump of OUTPUT on any miss.

Story 24.2's `test-repl-timer` re-derived all of it again. The recurrence cost has
overtaken the "weigh against ceremony" caveat — this is the build-it threshold.

## Acceptance Criteria

**AC1 — one shared assertion helper.**
A single script `tests/assert_verdicts.sh` reads emulator OUTPUT **on stdin** and
encapsulates the entire verdict block. Reading on stdin is deliberate: it
**decouples** the assertion (the repeated boilerplate) from the emulator
invocation (which legitimately varies — `$(IZCPM)` vs `$(IZCPM_BANKING)`,
`$(IZCPM_DISKS)`, single vs concatenated probe files). The recipe keeps its
bespoke pipe; the helper owns only the gnarly part.

Interface (suggested):
```
… | tests/assert_verdicts.sh --label "timer probe" [--mode anchored|strip-source] \
        [--timeout-note] PATTERN [PATTERN …]
```
- `--mode anchored` (default): fail if any `^FAIL:` present; for each PATTERN
  assert `grep -aqE "^PATTERN"`. Covers timer / value-to / in-out / ud-env / asm.
- `--mode strip-source`: pre-filter echoed source (`grep -vE '^[[:space:]]*\."'`)
  then unanchored `grep -q PATTERN`. Covers `banking` (verdicts can appear
  mid-line after a caught-abort `bank?`, and witnesses like `mbl-count: 2` aren't
  `PASS:`-prefixed).
- On a miss: print `FAIL: <label> — expected '<PATTERN>' …`, dump
  `xxd` of OUTPUT, exit nonzero.
- On all-pass: print the per-pattern `PASS: <label> — <PATTERN>` lines (preserve
  current human-readable output).

**AC2 — migrate the consumers.**
Convert the 6 recipes above to call the helper. Each ~15-line verdict block
collapses to ~2 lines. **No change to what is asserted** — the resulting PASS set
must be byte-identical to today's. (The emulator-feed pipe — `sed 's/$/\r/' FILE;
printf 'BYE\r\n' | EMU DISKS TARGET | tr -d '\r'` — may optionally also be
factored into a companion `tests/run_probe.sh`, but the assertion helper is the
load-bearing win; the feeder is optional.)

**AC3 — preserves every current guarantee + has a self-test.**
The helper keeps: `grep -a` NUL safety, column-0 anchoring (23.2 false-green
defense), `\r` strip, `xxd`-on-fail diagnostic. A self-test
`tests/assert_verdicts_selftest.sh` feeds known-good OUTPUT (all patterns at
col 0 → exit 0) and known-bad OUTPUT (missing pattern, and a `." PASS: x"`
source-echo-only line that must NOT false-green in `anchored` mode → exit 1),
proving both paths.

**AC4 — optional timeout ownership (composes with 24.3 AC2).**
The helper (or the companion feeder) may own a `--timeout N` so Story 24.3's
fail-loud timeout lives in one place. If 24.3 lands first, adopt its mechanism
instead — don't duplicate.

**AC5 — green.** Full `make test` / gate suite passes with the identical PASS set
before and after migration.

## Files

- `tests/assert_verdicts.sh` (new) — the helper.
- `tests/assert_verdicts_selftest.sh` (new) — AC3 self-test.
- `Makefile` — migrate the 6 consumer recipes; (optional) `tests/run_probe.sh`.
- (no `src/` changes — zero kernel delta.)

## Test plan / validation

- Self-test passes both arms (good → 0, bad / source-echo-only → nonzero).
- Each migrated recipe emits the **same** PASS lines as before (diff the gate
  output pre/post).
- Deliberately break one probe's verdict → confirm the helper FAILs with the
  `xxd` dump, same as the hand-rolled block did.

## References

- Epic 23 retro AI-23-4; Epic 24 retro AI-24-2 (escalation).
- `feedback_tib_size_inline_comments`, 23.2 column-0 / 23.3 `grep -a` lessons
  (the hygiene the helper must preserve).
- Existing exemplar block: `test-repl-timer` recipe (Makefile ~231–260).
