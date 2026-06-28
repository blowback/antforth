# Story 23.9: Complete banked window-top guard coverage

Status: review

<!-- Drafted 2026-06-28 from a /code-review of the banked_memory branch (Stories
     23.5-23.8). The review surfaced that the Story 23.6/23.7 window-top guard,
     though correct in mechanism, was INCOMPLETE: five further code paths grow
     the banked dictionary at HERE through their own hand-rolled stores with no
     headroom check. Every file:line below was read live on 2026-06-28 (PD-2 /
     B.4 figure-drift discipline), and the guards + probe were implemented and
     gate-verified the same day before this story was written (retroactive
     story for already-committed work — commit 1b3c3eb).

     POST-CLOSE-OUT FOLLOW-UP. Phase 5 is CLOSED (v3.1.0 shipped). Like 23.6/23.7
     this is a standalone correctness fix for the next release (v3.1.1 or folded
     into the next epic); it does NOT gate the already-shipped v3.1.0 tag.
     Story number 23.9 is PROVISIONAL pending project-lead assignment.

     DESIGN CALL (resolved at implementation; do NOT regress):
     The 23.6 infrastructure (check_banked_headroom non-throwing predicate +
     dict_overflow_throw -8 raise + GUARD_BANKED_WRITE macro) is reused verbatim.
     The five paths split into two shapes:
       (a) fixed-width writes (`;` EXIT=2, LITERAL=4, DOES>=2) → one
           GUARD_BANKED_WRITE per site, identical to the existing ,/C,/COMPILE,
           wiring.
       (b) arbitrary-length inline-string copiers (S"/." compile_string,
           ABORT" w_ABORT_QUOTE_cf) → a framing GUARD_BANKED_WRITE 3 for the
           leading xt+count, PLUS a per-character check_banked_headroom inside
           the copy loop (the only shape that scales the overrun with user
           input). The char is live in A and the check clobbers AF, so the
           per-char guard is bracketed PUSH AF / POP AF; the orphaned PUSH AF on
           the throw path is discarded by THROW/ABORT's SP reset.
     An up-front bound from the TIB remaining-count was REJECTED for the string
     copiers: it over-rejects a short string with a long line tail, breaking the
     exact-$C000 boundary semantics 23.6 established. -->

## Story

As a **MicroBeast Forth programmer compiling into a banked dictionary**,
I want **every word that grows the dictionary at `HERE` in a bank — not just the
`,`/`C,`/`ALLOT`/`COMPILE,`/defining-word/`MARKER` paths 23.6/23.7 already cover —
to raise a clean `-8` dictionary overflow before it would place any byte at or past
the slot-2 window top (`$C000`)**,
so that **`;`, `LITERAL`, `DOES>`, `S"`, `."` and `ABORT"` in a near-full bank can
never silently write through slot 3 (wrong bank / fixed memory) and corrupt it.**

## Context — the residual (verified live 2026-06-28; do NOT re-discover)

Story 23.6 bounded the fixed-width growth primitives (`,`/`C,`/`ALLOT`/`COMPILE,`
via `GUARD_BANKED_WRITE`, `src/macros.asm`) and the defining-word header
(`build_header`'s `DOER_RESERVE` guard, `src/compiler.asm`); Story 23.7 folded
`MARKER`'s 372-byte body into the same pre-commit guard. All route through
`check_banked_headroom` (`src/banking.asm`, non-throwing, no-op on
`triple_owner == 0`) + `dict_overflow_throw` (`-8`).

**Five paths were still writing to `HERE` with no headroom check** — each only
reachable while compiling, i.e. inside a banked colon/defining-word body
(bank-aware `:`, Story 19.2):

| Path | Bytes | Site |
|------|-------|------|
| `;` (SEMICOLON) | `EXIT_CODE` (2) | `src/compiler.asm` `w_SEMICOLON_cf` |
| `LITERAL` | `LIT` xt + value cell (4) | `src/compiler.asm` `w_LITERAL_cf` |
| `DOES>` | `(DOES>)` xt (2) | `src/compiler.asm` `w_DOES_cf` |
| `S"` / `."` | `(S")` xt + count + inline string (arbitrary) + `TYPE` xt for `."` | `src/strings.asm` `compile_string` (+ `w_DOT_QUOTE_cf` tail) |
| `ABORT"` | `(ABORT")` xt + count + inline string (arbitrary) | `src/system.asm` `w_ABORT_QUOTE_cf` |

**The hazard:** in a bank `N≥1` with live `HERE` near `$C000`, each writes its
bytes at/past the window top into slot 3 (whatever page is mapped there) — silent
corruption with no diagnostic. `;` is the sharpest: the 23.6-guarded body compilers
deliberately permit `HERE` to reach exactly `$C000` (one-past-end legal), and **every**
banked colon definition ends with `;`, so a body filled to the brink then closed
overruns. The string copiers are the most damaging: the overrun scales with the
string length, not a fixed 2-4 byte slop.

**Why a correctness defect, not accept-with-rationale:** silent straddle = corrupt
write. Per S8 (`feedback_no_preexisting_discharge`) and
`feedback_no_accept_disposition_for_bugs`, "pre-existing"/"out of 23.6 scope" does
not discharge it. (The 23.7 probe-file comment even claimed MARKER was "the one path
23.6 left unguarded" — demonstrably wrong; corrected here.)

## Acceptance Criteria

**AC1 — Fixed-width writes refuse a straddle (`-8`).** On a bank `N≥1`, a `;`,
`LITERAL`, or `DOES>` whose write would place any byte at/past `$C000` raises `-8`
before the store, leaving `HERE` untouched; the interpreter stays live.

**AC2 — Inline-string compilers refuse a straddle (`-8`), and the overrun is bounded
per character.** On a bank `N≥1`, an `S"`, `."`, or `ABORT"` whose framing bytes or
any string character would cross `$C000` raises `-8`. The string body is guarded
PER CHARACTER (not by an up-front TIB bound), so a string that fits is accepted to
the exact boundary and one that does not throws at the first over-`$C000` char.

**AC3 — Exact boundary preserved.** A write whose one-past-end is exactly `$C000` is
accepted (consistent with 23.6's strictly-`> $C000` semantics, `src/banking.asm`).

**AC4 — Bank 0 strict no-op.** When `triple_owner == 0`, all five paths behave
byte-for-byte as before (`check_banked_headroom` no-ops on bank 0). Verified by the
full bank-0 `test-repl` suite staying green.

**AC5 — No new THROW infrastructure.** Reuse `THROW_DICT_OVERFLOW = -8`,
`check_banked_headroom`, `dict_overflow_throw`, and `GUARD_BANKED_WRITE` from 23.6.
No new throw code, no new `throw_desc_table` row.

**AC6 — Gates green; binary delta recorded.** Full bank-0 `test-repl` plus the
banked overflow probes (23.6, 23.7) and the lint stay green; binary delta re-`wc -c`
recorded and itemised (CCD-4).

**AC7 — New regression probe (load-bearing).** `tests/banking_tests_23_9.fth` +
`make test-repl-banking-23-9`, mirroring 23.6/23.7 (INTERPRET-level drivers,
self-calibrated brink, runtime-computed liveness witness): cases A-F assert each of
the five paths throws `-8` in a bank; G asserts a fitting banked def is NOT
over-rejected; H asserts a strict bank-0 no-op. NON-VACUITY confirmed (A-F fail
against an unguarded kernel).

**AC8 — Docs + test hardening.** `docs/throw-codes.md` `-8` row notes the new sites;
the stale "MARKER is the one path 23.6 left unguarded" comment in
`tests/banking_tests_23_7.fth` corrected. (Opportunistic, surfaced by the same
review: the 23.6 ALIVE gate made echo-proof via a computed `===42`; the
`lint-banking-probes` regex tightened to catch hex/variable/computed/post-string
`BANK!`.)

## Tasks / Subtasks

### Task 1 — Fixed-width guards (AC1)
- [x] `GUARD_BANKED_WRITE 2` in `w_SEMICOLON_cf` before the `EXIT_CODE` store.
- [x] `GUARD_BANKED_WRITE 4` in `w_LITERAL_cf` before the `LIT`+value store.
- [x] `GUARD_BANKED_WRITE 2` in `w_DOES_cf` before the `(DOES>)` store.
- [x] Confirm each site runs in the PRIMARY register set (their existing THROWs
  `JP w_THROW_cf.kernel_entry` with no EXX), so `dict_overflow_throw` is reached
  directly with no EXX dance, and `BC`(=TOS) is preserved across the check.

### Task 2 — Inline-string guards (AC2)
- [x] `compile_string` (S"/."): `GUARD_BANKED_WRITE 3` for the `(S")` xt + count
  framing; per-character `PUSH AF / GUARD_BANKED_WRITE 1 / POP AF` in the copy loop.
- [x] `w_DOT_QUOTE_cf`: `GUARD_BANKED_WRITE 2` for the trailing `TYPE` xt.
- [x] `w_ABORT_QUOTE_cf`: `GUARD_BANKED_WRITE 3` framing + per-character guard in
  `.aq_copy`.
- [x] Confirm S"/."/ABORT" all save IP to a scratch cell (no EXX) → primary set →
  direct `dict_overflow_throw`; the pad byte is implicitly safe (a guarded last char
  at `$BFFF` leaves `HERE = $C000`, even → no pad write).

### Task 3 — Regression probe (AC7)
- [x] `tests/banking_tests_23_9.fth` (cases A-H) + `make test-repl-banking-23-9`,
  `.PHONY` wired. Each case reseeds the bank table (`_RS`) so an aborted banked
  definition's committed SMUDGEd header cannot accumulate into the bucket-chain
  corruption that breaks FIND in the next case
  (`feedback_phase4_probe_bank_switch_limitation`).
- [x] Liveness + accept witnesses are runtime-computed (`===42`, `G-OK=-1`,
  `H-DONE=7`), never echo-satisfiable sentinels.
- [x] Non-vacuity check: stash the source guards, rebuild, re-run → A-F FAIL.

### Task 4 — Docs + test hardening (AC8)
- [x] `docs/throw-codes.md` `-8` row updated.
- [x] Corrected the stale claim in `tests/banking_tests_23_7.fth`.
- [x] 23.6 ALIVE gate → computed `===42` (`tests/banking_tests_23_6.fth` + Makefile).
- [x] `lint-banking-probes` regex hardened (strip `."` strings, flag any non-`0`
  `BANK!`).
- [ ] **Hardware-smoke (PENDING — project-lead/Ant to run; recipe posted in the
  closing chat message per `feedback_post_hw_smoke_steps_at_review`).** Same-mechanism
  additions to the HW-verified 23.6/23.7 guard, so risk is low, but a binary-delta
  story → HW-smoke before `done`.

## Dev Notes

### Itemised byte budget (actual)

Measured re-`wc -c`: **29,091 B (pre-edit) → 29,179 B = +88 B.** Per site
(GUARD_BANKED_WRITE n ≈ n INC HL + CALL + JP C + n DEC HL):

- `;` (w=2) ≈ 10 B · `LITERAL` (w=4) ≈ 14 B · `DOES>` (w=2) ≈ 10 B
- `compile_string` framing (w=3) ≈ 12 B + per-char (PUSH AF + w=1 guard + POP AF) ≈ 10 B
- `."` TYPE (w=2) ≈ 10 B
- `ABORT"` framing (w=3) ≈ 12 B + per-char ≈ 10 B

Raw ≈ 88 B — matches the measured delta exactly (these are repeated macro
expansions of an existing primitive, so the register-juggle overshoot calibration
does not apply). No data cells added; reuses 23.6's `check_banked_headroom` /
`dict_overflow_throw` / `THROW_DICT_OVERFLOW`.

### Boundary semantics (identical to 23.6 — reused, not re-derived)

Window `$8000..$BFFF` usable; `$C000` first illegal byte; `check_banked_headroom`
throws iff prospective one-past-end `> $C000` (strict). For a width-`w` store at
`HERE`, `GUARD_BANKED_WRITE w` advances HL by `w`, checks, throws on overflow, then
restores `HL = HERE`. For the string copiers, each character store is its own
`w = 1` check, so the body is guarded to the exact boundary.

### Why per-character (not an up-front bound) for the string copiers

The copy loop stops at the closing `"`; the actual length is unknown until then. An
up-front bound from the TIB remaining-count would over-reject a short string when a
long line tail follows — a false rejection that breaks 23.6's exact-`$C000`
semantics. Per-character checking is `O(n)` `CALL`s at compile time (acceptable) and
refuses precisely at the brink. The first framing write (`(S")`/`(ABORT")` xt +
count, 3 B) is guarded once up front; the per-char guard covers the body; the
alignment pad needs no separate guard (a guarded last char at `$BFFF` leaves
`HERE = $C000`, even, so `BIT 0,L` skips the pad).

### Scope confirmations
- CODE/LABEL route to fixed memory (Story 22.3) and run `build_header` with
  `triple_owner == 0` → the guard no-ops; out of scope.
- The colon-body word-xt compiler (compiling `DUP` etc.) routes through guarded
  `COMMA`/`COMPILE,` — already covered by 23.6; the 23.9 probe drives the brink via
  `[ ... ALLOT ]` so it does not depend on that path.

## Dev Agent Record

### Implementation Plan / Approach

Implemented per the frontmatter design call: reuse 23.6 infrastructure, two shapes
(fixed-width macro vs framing+per-char for strings). All five sites verified to run
in the primary register set, so the throw needs no EXX. The `."` TYPE-append and the
S"/ABORT" framing are guarded as separate fixed writes; the string bodies per-char.

### Debug Log / Decisions

- **Guard mechanism re-verified independently.** A line-by-line asm review of the
  23.6 additions (check_banked_headroom flag/HL preservation, the macro's
  advance/restore, the build_header reserve) found the mechanism provably correct;
  23.9 only adds call sites, so no new mechanism risk.
- **Probe bucket-chain corruption (caught during dev).** First probe draft ran all 6
  throw cases back-to-back in one emulator; cases D/E/F failed with `ALLOT ?` /
  `error -13` inside the `[ ... ]` bracket. Root cause: each throwing banked
  definition leaves a committed SMUDGEd header, and several accumulate into the
  banked bucket-chain corruption documented in
  `feedback_phase4_probe_bank_switch_limitation` — which breaks FIND in the NEXT
  banked definition. Confirmed the guard itself is fine (case D throws `-8` cleanly
  in isolation, and with only one prior throw). Fixed the PROBE by reseeding the bank
  table (`_RS = BANKS-CLEAR + 8x $22 +BANK`) before each case. This is a harness
  limitation, not a guard bug.
- **23.6 ALIVE gate / lint hardening (opportunistic).** The same review found the
  23.6 liveness gate was echo-satisfiable (bare sentinel) and the
  `lint-banking-probes` regex was decimal-anchored (missed hex/variable/computed/
  post-string `BANK!`); both fixed and folded into this story's commit.

### Completion Notes

- **Binary delta:** 29,091 → **29,179 = +88 B** (test-harness changes add 0 kernel
  bytes). Well-understood (repeated macro expansion); no HALT/re-itemise needed.
- **Gates (all green, from committed source):** `test-repl` 1005/0 ·
  `test-repl-banking-23-6` 7/0 (now with computed ALIVE gate) ·
  `test-repl-banking-23-7` 4/0 · **`test-repl-banking-23-9` 8/0 (new)** ·
  `lint-banking-probes` PASS · **non-vacuity:** A-F FAIL against an unguarded kernel.
- **HW-smoke: PENDING** (recipe in closing chat message). Same-mechanism extension of
  the HW-verified 23.6/23.7 guard.
- AC1✓ AC2✓ AC3✓ AC4✓ AC5✓ AC6✓ AC7✓ AC8✓ (HW-smoke item open).
- Committed as `1b3c3eb` (`feedback_no_claude_coauthor` — no co-author trailer).

### File List

- `src/compiler.asm` — `GUARD_BANKED_WRITE` in `w_SEMICOLON_cf` (2), `w_LITERAL_cf`
  (4), `w_DOES_cf` (2).
- `src/strings.asm` — `compile_string` framing guard (3) + per-char guard;
  `w_DOT_QUOTE_cf` TYPE-append guard (2).
- `src/system.asm` — `w_ABORT_QUOTE_cf` framing guard (3) + per-char guard.
- `tests/banking_tests_23_9.fth` — new isolated coverage probe (cases A-H).
- `tests/banking_tests_23_6.fth` — ALIVE gate → computed `===42`.
- `tests/banking_tests_23_7.fth` — stale "one path" comment corrected.
- `Makefile` — `BANKING_23_9_PROBE`, `test-repl-banking-23-9` target, `.PHONY`;
  23.6 ALIVE gate; `lint-banking-probes` regex hardened.
- `docs/throw-codes.md` — `-8` row notes the 23.9 sites.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `23-9` → review.

## Change Log

| Date | Change |
|------|--------|
| 2026-06-28 | Story 23.9 implemented (commit 1b3c3eb): banked window-top guard coverage completed for `;`/`LITERAL`/`DOES>` (fixed-width `GUARD_BANKED_WRITE`) and `S"`/`."`/`ABORT"` (framing guard + per-char `check_banked_headroom`). +88 B (29,091→29,179). New probe `tests/banking_tests_23_9.fth` + `make test-repl-banking-23-9` (8/0, non-vacuity confirmed). Opportunistic test hardening: 23.6 ALIVE gate → computed `===42`; `lint-banking-probes` regex tightened. Stale 23.7 comment corrected; `docs/throw-codes.md` updated. All gates green; bank-0 `test-repl` 1005/0. Status → review (HW-smoke pending). |
