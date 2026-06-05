# Story 19.5.2: Dispatch rework — self-dispatching RST stub + return thunk (option C)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Drafted 2026-06-05 by create-story workflow. Implements ADR 19.5 DR-2
     (docs/adr-19-5-cross-bank-dispatch.md, ACCEPTED 2026-06-04) verbatim:
     option C — the descriptor stub becomes self-dispatching
     [RST $28][target_bank][target_addr.lo][target_addr.hi]; a kernel
     handler at the $0028 RST vector performs bank-aware dispatch for
     BOTH NEXT-threaded calls and EXECUTE; cross-bank return reworked to
     a dispatch-site 2-cell frame + fixed-memory return thunk (handles
     DOCOL and non-DOCOL targets uniformly — root cause (b) subsumed);
     EXIT_CODE sentinel discriminator, cross_bank_return trampoline, and
     the EXECUTE 3-way all RETIRE. Sprint-status row key (immutable):
     19-5-2-dispatch-rework-stub-aware-next-plus-non-docol-trampoline-targets. -->

## Story

As Marc (OG user) whose banked colon definitions can only be invoked via explicit `' name EXECUTE` (and whose cross-bank `VARIABLE`/`CREATE` references hang outright),
I want every dispatch site — `NEXT`'s blind `JP (HL)`, `EXECUTE`, `CATCH`'s xt-execute — to handle descriptor-stub xts correctly via a self-dispatching RST-$28 stub, with cross-bank returns routed through a fixed-memory thunk that works for DOCOL and non-DOCOL targets alike,
so that the two Epic-19 dispatch root causes ((a) DTC-threading-through-stub-xt; (b) non-DOCOL trampoline hang, Probe-19.3-F class) are fixed at the architecture level with 0 T-states added per thread step (NFR-P4-1), unblocking 19.5.3's compiled-body verification of the Epic-19 north-star UX.

## Acceptance Criteria

1. **AC1 (stub layout v2).** `stub_allocate` (`src/banking.asm:835..850`) emits `[$EF][target_bank][target_addr.lo][target_addr.hi]` — byte 0 becomes the constant `RST $28` opcode (`$EF`); byte 1 becomes `target_bank` (signed; `-1`/`$FF` = fixed-memory per FR-P4-13); bytes 2..3 unchanged. Same 4 stores, same 4-byte size, same `$D4CB..$DBFF` region / 461-stub capacity / xt-is-stub-address identity (PD-P4-1) / NFR-P4-4 ≤ 5 B pin — **all unchanged**. The dead `$C3` of Story 18.3 CR-H1 is thereby retired (byte 0 is now live code again, by design). Allocator's main-set-preservation contract (`:816..828`) unchanged.
2. **AC2 (RST-$28 self-dispatch handler).** A COLD-time install writes `JP stub_dispatch` at `$0028..$002A` (zero page is RAM under CP/M; placement in `src/antforth.asm` after the existing banking-foundation init, near the F2 loop region `:225..235`). `stub_dispatch` (kernel-resident, suggested home `src/banking.asm` near the retired trampoline's slot):
   - RST entry: `POP HL` immediately (the RST pushed `stub+1` onto SP — the **data stack** in antforth; transient 2-byte push, popped before anything else; note this transient in the handler comment against the `check_overflow` 32-byte margin).
   - Read `target_bank` at `(HL)` (= stub byte 1). If `== (IY+UserArea.current_bank)` OR `== $FF` (fixed-memory) → **intra path**: load `HL ← target_addr` from stub bytes 2..3, `JP (HL)` with **HL = target CF** (the Story-18.3 CR-H1 DOCOL `body = HL+3` precondition, `src/inner_interpreter.asm:14..25` — preserve it exactly).
   - Else → **cross path**: push the 2-cell frame `[caller_bank][caller_IP = DE]` on the IX R-stack, set `DE ← xbank_thunk`, MMU lookup `active_pages[target_bank]` + `OUT (0x72)`, update `(IY+UserArea.current_bank)`, load `HL ← target CF`, `JP (HL)`.
   - `NEXT`/`NEXTHL` (`src/macros.asm:32..47`) stay **byte-for-byte untouched** — the blind `JP (HL)` lands on stub byte 0, which is now an instruction. 0 T per thread step for non-stub words (NFR-P4-1 PASS by construction); bank-0 `:` keeps legacy CFA-as-xt (19.2 Q3-β), so the Phase-2/3 surface never touches a stub.
3. **AC3 (return thunk + `xbank_restore` — root cause (b) subsumed).** `xbank_thunk`: one fixed-memory thread cell `DW xbank_restore` (read-only, always mapped, re-entrant — each nesting level has its own 2-cell frame). `xbank_restore` (DEFCODE-shaped code, no dictionary header needed): pop `[caller_bank][caller_IP]` from the IX R-stack, MMU restore via `active_pages[caller_bank]` + `OUT (0x72)`, update `current_bank`, `DE ← caller_IP`, `NEXT`. Uniform return for **both** target shapes: DOCOL targets' terminal EXIT pops the DOCOL-pushed thunk-IP → `NEXT` fetches the thunk cell → restore; DOVAR/DOCON/DEFCODE targets `NEXT` directly with `IP = xbank_thunk` → same path. Probe-19.3-F's hang class (cross-bank `VARIABLE`/`CREATE` reference) becomes structurally impossible. The 2-cell frame replaces the old 3+1-cell sentinel frame (cross-bank R-stack pressure drops; FR-P4-21 gotcha improves — note in redesign doc).
4. **AC4 (retirements — the old contract is deleted, not patched).** (a) EXIT_CODE sentinel discriminator (`src/inner_interpreter.asm:61..68`, re-counted 13 B at draft time) removed — `EXIT_CODE` label, R-stack pop, and `NEXT` remain (hand-built threads' `DW EXIT_CODE` cells, e.g. `src/banking.asm:1062`, unaffected); the Story-18.2 comment block `:36..54` rewritten to cite ADR DR-2. (b) `cross_bank_return` trampoline body (`src/banking.asm:1187..1203`, re-counted 32 B) + its comment block (`:1064..1186`) removed. (c) `w_EXECUTE_cf` 3-way (`src/inner_interpreter.asm:386..463`, body re-counted 77 B) folds to `LD H,B / LD L,C / POP BC / JP (HL)` (4 B) — legacy CFAs execute directly, stub xts self-dispatch via RST; the `:281..383` comment block replaced with the option-C contract. Post-edit grep gate: zero remaining **code** references to `cross_bank_return`; stale comment references updated at: `src/dictionary.asm:173`, `src/compiler.asm:445`, `:681`, `src/banking.asm:799`, `:921`, plus any others surfaced by `grep -rn "cross_bank_return\|3-way\|sentinel" src/`.
5. **AC5 (`BANK-OF` offset).** `w_BANK_OF_cf` (`src/banking.asm:912..936`) reads stub byte 1 (`INC HL` before the read, +1 B); the `$D4` legacy-CFA discriminator (`:923..925`) and the `-1`-for-legacy return are **unchanged**. PD-P4-1's "one-byte read" property survives at +1 B. Comment block (`:879..911`, byte-0 references) updated.
6. **AC6 (CATCH-cross-bank frame fix — designed AND landed here, behaviourally verified in 19.5.3).** `CATCH`'s frame additionally saves `current_bank` at frame push, and `THROW`'s **caught** path restores it (MMU `OUT (0x72)` via `active_pages[]` + `current_bank` cell) during snap-back — a THROW across an abandoned cross-bank thunk frame must land in the catcher's bank. Q1 disposition decides the frame shape (Dev Notes; default α appends a `+8` slot, preserving all existing field offsets). `catch_resume_cf` (normal return) needs **no** bank restore — the thunk balances every cross-bank entry on the non-THROW path — but its frame-pop advance (and THROW's `LD BC, 8 / ADD IX, BC` at `src/exception.asm:507..508`) grows to match the widened frame. Scope fence: bank restore on the **uncaught** path (`.throw_uncaught` → QUIT) is Epic 21 scope (sprint row 21-2) — note the fence in the THROW comment. Minimal in-story witness: one probe (AC8c) asserting `BANK@` = catcher's bank after a caught cross-bank THROW; the full banked NFR-P4-8 variant is 19.5.3 scope.
7. **AC7 (consumer/probe/doc migration — ADR checklist, all 6 items).**
   - (1) `stub_allocate` emit-order swap — AC1.
   - (2) `w_EXECUTE_cf` fold — AC4c. Thread-cell consumers (`src/outer_interpreter.asm:204`, `:215`) unaffected (CF address semantics preserved).
   - (3) `BANK-OF` — AC5.
   - (4) `;`-emit (`src/compiler.asm:690..718`) and CREATE-emit (`:831..847`) call `stub_allocate` with unchanged inputs — **verify-only, no code change**; update their 3-way/sentinel comment references.
   - (5) Test-side: probe-18.1-a byte asserts (`tests/banking_tests.fth:845..848`: byte0 `255→239`, byte1 `195→255`) and probe-18.1-b (`:879..882`: byte0 `5→239`, byte1 `195→5`); probe-18.1-c geometry asserts unchanged; the `:752..763` "inspected via C@, NOT executed" comment updated (stubs are now genuinely executable). **Probe-18.2-a is RETIRED-AND-REPLACED**, not patched: it synthesizes the old 3-cell sentinel frame and reads `EXIT_CODE+20..22` bytes — both mechanisms cease to exist, and its layout-shift ELSE branch emits `FAIL` (Makefile `:370..375` exits 1). Retirement scope is the **full `:956..1046` block** — `_xbr-exit-code` CONSTANT + `_xbr-addr-cell` VARIABLE (`:968..969`) and the `_p18a-inner` helper (`:1002..1006`) must go with the probe body: a surviving `_p18a-inner` with an unfilled `_xbr-addr-cell` pushes garbage `>R` and crashes at file load. Replace with a same-slot RST-dispatch witness (suggested probe-19.5.2-a: intra-bank dispatch through a `(stub-allocate)`-built fixed-memory stub via `EXECUTE` — the folded `JP (HL)` → RST → handler chain end-to-end) + update the Makefile grading block. Probe-18.2-b (intra-bank EXIT round-trip, `:1048..1070`) stays as-is (EXIT miss-path is now the only path).
   - (6) Docs: PD-P4-11 prose (`architecture.md:347..365` — byte-semantics row) + PD-P4-2 (`architecture.md:215..227` — sentinel mechanism SUPERSEDED-by-ADR-DR-2 note, not silent rewrite); redesign `§2.1` (`docs/antforth-banking-redesign.md:34..42`, stub layout), `§2.2` (`:44..49`, sentinel decision superseded), `§3` (`:54..`, cross-bank call mechanism — thunk description); `make check-doc-sync` 0 drift at close.
   - (+) Sweep-script anchor migration: both `tests/layout_fragility_sweep.sh` (`:54`, `:100`) and `tests/straddle_repro_sweep.sh` (`:41..47`) use `^cross_bank_return:` as the K-knob insertion anchor with a loud `ANCHOR-NOT-FOUND` guard — retiring the label trips the K>0 paths. Migrate the anchor to a retained, layout-equivalent label (suggested: `xbank_restore:` or `stub_dispatch:` — same src/banking.asm region) keeping the loud-failure discipline; `test-straddle-regression` (K=0, no source mutation) must stay green throughout.
8. **AC8 (test surfaces + new witnesses).** At story close: `make test-repl` ≥ 975 PASS / 0 FAIL; `make test-repl-banking` ≥ 63 PASS / 0 FAIL (with probe-18.2-a's replacement graded); `test-repl-banking-isolated` ≥ 6/0; `-19-3` ≥ 5 PASS + 2 DEFER (**probes F/G stay DEFER-sentinel stubs — re-enablement is 19.5.3 scope, do not write their bodies here**); `-19-4` 2/0 (its EXECUTE-explicit probes now route through the folded `JP (HL)` → RST chain — a live end-to-end witness for cross-bank DOCOL dispatch + thunk return); `-19-5-1` 2/0; `test-repl-banking-skip` 0 FAIL; `test-straddle-regression` 3/3 (self-calibrating pads absorb this story's layout shift); `make check-doc-sync` 0 drift. New witnesses: (a) probe-19.5.2-a — the 18.2-a replacement (AC7.5); (b) **non-DOCOL cross-bank witness** (Q2 disposition; default: one minimal probe in `tests/banking_tests_19_3.fth` — cross-bank `EXECUTE` of a bank-5 `CREATE`'d/`VARIABLE` word returning cleanly through the thunk; the very shape that hung as Probe-19.3-F, kept distinct from the F/G DEFER stubs); (c) CATCH-cross-bank bank-restore probe (AC6). Layout-shift discipline (19.5.1 AC7 precedent): any banking-probe trip is diagnosed via the straddle harness (which body straddles, under which mapping), never reflex-reverted; the flat-iz-cpm test-643 `*/` quirk, if (and only if) flat test 643 itself trips, is re-tuned via the cold_start NOP slot (`feedback_iz_cpm_test_643_quirk`) — a known, separate quirk.
9. **AC9 (byte budget + T-states — independently itemised per B.2).** Draft-time per-component itemisation (Dev Notes table; the three retirement figures re-counted from live source at draft time: 13 B / 32 B / 77 B — all match the ADR): core net ≈ **−13 B**; CATCH fix (Q1=α) ≈ **+25 B**; nominal total ≈ **+12 B**. Envelope: additions (11+56+2+35+1+25 = 130 B) × 1.25 (`feedback_kernel_ldir_estimate_overshoot`) − retirements (118 B, fixed — deletions don't overshoot) → **carry −13..+45 B**. Dev-pass re-itemises as-built opcodes; `wc -c build/antforth.com` delta reported against the Epic 19.5 plan (~+30..+100 B, epics:902) — 19.5.1 spent +65 B, so a close above +35 B breaches the epic plan upper bound and must be flagged for the 19.5.4 close-out reconciliation (state the measured value and the gate plainly). T-states: record the as-built per-opcode dispatch counts in Dev Notes — intra-bank-through-stub (ADR anchor ≈ 107 T, faster than the 123 T shipped EXECUTE intra path), cross-bank dispatch (≈ 343 T) + thunk return (≈ 196 T) — against the **re-baselined NFR-P4-3 ≤ 400 T + MMU port write** (rider signed off with ADR acceptance; the formal NFR re-baseline statement lands at 19.5.4 close-out per epics:890). Non-banked words: 0 T delta (FR-P4-19 preserved exactly).
10. **AC10 (hardware exemption + RST-vector contingency).** S9 / NFR-P4-11 hardware smoke DEFERRED to Story 19.5.4 per the ADR's named assumptions — A2 (`$0028` claimability under MicroBeast CP/M: zero page is RAM; BIOS IM-1 uses `$0038`; iz-cpm intercepts only `$0000`/`$0005`) is **emulator-verified this story, hardware-verified at 19.5.4**; if 19.5.4's HW pass finds `$0028` occupied, the fallback is an equal-cost re-vector to `$0008`/`$0010`/`$0018`/`$0020` (keep the vector address a single EQU so the re-vector is a one-constant change). A3 (Probe-19.2-F re-test under C dispatch + F2 COLD-init) also rides 19.5.4. Per `feedback_post_hw_smoke_steps_at_review` (**STRONG**): the dev-pass close message MUST post the deferred-HW-smoke recipe in the chat, not only in Dev Notes.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes
  - Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F). Draft-time verified 2026-06-05: **26898 B** at eda591f (clean tree). Re-verify anyway at dev-pass start.
  - Dev-pass verified 2026-06-05: **26898 B** at eda591f working tree (only bmad artifacts modified). Matches draft-time figure.
- [x] Capture current test baselines (draft-time, from 19.5.1 CR close): `test-repl` 975/0/2 · `test-repl-banking` 63/0/3 · isolated 6/0 · 19-3 5 PASS + 2 DEFER · 19-4 2/0 · 19-5-1 2/0 · skip 0 FAIL · `test-straddle-regression` 3/3 · `check-doc-sync` 31 advisory / 0 drift — re-run and record actuals
  - Dev-pass actuals 2026-06-05: `test-repl` **975/0/2** · `test-repl-banking` **63 PASS / 0 FAIL** · isolated **6/0** · 19-3 **5 PASS + 2 DEFER** · 19-4 **2/0** · 19-5-1 **2/0** · skip **0 FAIL** · `test-straddle-regression` **3/3** · `check-doc-sync` **31 advisory / 0 drift**. All match draft-time baselines exactly.

### Story tasks

- [x] **Task 1 — Stub layout v2 + RST vector install (AC: #1, #2, #10)**
  - [x] Sub-1.1 `stub_allocate`: byte 0 ← `$EF`, byte 1 ← `B` (target_bank); update the allocator comment block (`src/banking.asm:806..834`) + PD-P4-11 references
  - [x] Sub-1.2 `STUB_DISPATCH_VECTOR EQU $0028` (or similar) in `src/constants.asm`; COLD-time install (`LD A,$C3 / LD (VECTOR),A / LD HL,stub_dispatch / LD (VECTOR+1),HL`, ~11 B) in `src/antforth.asm` after the F2 bank-HERE loop; step-comment in COLD sequence style
  - [x] Sub-1.3 Verify under iz-cpm-banking that `$0028` writes stick and dispatch fires (A2 emulator-half; HW half deferred per AC10) — witnessed by probe-19.4-a PASS: cross-bank EXECUTE routes JP (HL) → RST $28 → stub_dispatch → DOCOL → EXIT → thunk → xbank_restore end-to-end
- [x] **Task 2 — `stub_dispatch` handler + thunk + `xbank_restore` (AC: #2, #3)**
  - [x] Sub-2.1 Handler per AC2 sketch (Dev Notes); preserve BC=TOS and DE=IP contracts; comment the transient RST push on the data stack
  - [x] Sub-2.2 `xbank_thunk` cell + `xbank_restore` code per AC3 sketch; EXX-hygiene walk per docs/register-conventions.md §3 (leaf, main-set only — match the retired trampoline's audit discipline)
  - [x] Sub-2.3 Re-entrancy note (nested cross-bank) + R-stack pressure note (2-cell vs old 3+1) in the handler comment
- [x] **Task 3 — Retirements + EXECUTE fold (AC: #4)**
  - [x] Sub-3.1 Remove EXIT_CODE discriminator (`src/inner_interpreter.asm:61..68`); rewrite `:36..54` comment per ADR DR-2
  - [x] Sub-3.2 Remove `cross_bank_return` body + comment block (`src/banking.asm:1064..1203`) — replaced in-place by the stub_dispatch/thunk/xbank_restore block
  - [x] Sub-3.3 Fold `w_EXECUTE_cf` to 4 B; replace `:281..383` comment with the option-C contract (legacy JP-direct; stub self-dispatches)
  - [x] Sub-3.4 Comment-reference sweep: `grep -rn "cross_bank_return\|3-way\|sentinel" src/` → update every stale site (known: dictionary.asm:173, compiler.asm:445/:681, banking.asm:799/:921) — also updated banking.asm:135 ("EXECUTE chokepoint" phrasing); remaining src/ mentions are deliberate retirement-context citations in the new comment blocks
- [x] **Task 4 — `BANK-OF` offset (AC: #5)**
  - [x] Sub-4.1 `INC HL` before the byte read; comment block update (`src/banking.asm:879..911`)
- [x] **Task 5 — CATCH-cross-bank frame fix (AC: #6)**
  - [x] Sub-5.1 Q1 disposition (default α: append bank slot at frame +8; sketch in Dev Notes); CATCH push saves `current_bank`
  - [x] Sub-5.2 THROW caught path: restore MMU + `current_bank` from the frame (placed BEFORE the field reads per the Dev-Notes placement caution — HL/BC/DE all free right after the chain walk); widen both frame-pop advances (THROW + `catch_resume_cf`, 8 → 10); update the frame-layout comments. Knock-on: two JR→JP conversions (+2 B) — the caught-path insertion pushed both `.throw_uncaught` and `.throw_zero` past JR's +127 range (the original JR comment anticipated exactly this switch-back)
  - [x] Sub-5.3 Epic-21 fence note at `.throw_uncaught` (uncaught-path bank restore = sprint row 21-2)
- [x] **Task 6 — Probe + sweep-script + doc migration (AC: #7, #8)**
  - [x] Sub-6.1 Probe-18.1-a/b byte-index updates (a: byte0 255→239, byte1 195→255; b: byte0 5→239, byte1 195→5); 18.1 comment block update; Makefile PASS-message byte descriptions updated; 18.3 block header + 18.3-F mechanism comment + 19.2-J byte note also migrated
  - [x] Sub-6.2 Probe-18.2-a retire-and-replace with probe-19.5.2-a (RST intra-bank dispatch witness — full `:956..1046` block incl. `_xbr-*` + `_p18a-inner` removed wholesale); Makefile grading block updated; PASS verified (63/0 on test-repl-banking)
  - [x] Sub-6.3 Q2 non-DOCOL cross-bank witness probe-19.5.2-b in `tests/banking_tests_19_3.fth` (the exact Probe-19.3-F hang shape, minus the FR-P4-26 `@` read; F/G DEFER stubs untouched, placed after 19.3.1 block so existing sentinel ordering unchanged); Makefile grading clause keyed on distinct `probe-19.5.2-*` id family; PASS verified
  - [x] Sub-6.4 AC6 CATCH-cross-bank bank-restore probe-19.5.2-c (bank-5 thrower, CATCH from bank 0, asserts code=77 AND BANK@=0); same fixture per Q2; PASS verified
  - [x] Sub-6.5 Sweep-script anchor migration (`^cross_bank_return:` → `xbank_restore:` in both drivers; layout_fragility's after-anchor → "resume caller in restored bank"; `.sym` lookup + probe-18.2-a verdict grep → 19.5.2-a); K=16 straddle-sweep anchor-fire verified + source-restore verified; `test-straddle-regression` (K=0) 3/3 green post-shift
  - [x] Sub-6.6 Docs: architecture.md PD-P4-2 supersede note (decision history retained) + PD-P4-11 layout-v2 note; redesign §2.1 (self-dispatch note) / §2.2 (SUPERSEDED + uniform-return contract + R-stack pressure) / §3 (thunk mechanism); `check-doc-sync` 0 drift / 31 advisory (= baseline; story-cite wording uses "Epic 19.5 dispatch-rework story" since 19.5.x stories are epic-file bullets, not `### Story` headers)
- [x] **Task 7 — Budget, sweep, close-out (AC: #8, #9, #10)**
  - [x] Sub-7.1 As-built per-component itemisation + `wc -c` delta vs 26898 B baseline: **26921 B = +23 B** (itemisation table in Dev Agent Record sums to exactly +23). Epic-envelope check: +23 ≤ +35 → **no breach**; Epic 19.5 cumulative 65 + 23 = 88 B, inside the ~+30..+100 B plan (epics:902)
  - [x] Sub-7.2 As-built T-state account (Dev Agent Record): intra-through-stub 103 T (same-bank) / 117 T ($FF marker) — both faster than the retired EXECUTE intra path's 123 T; cross-bank dispatch 368 T incl. the OUT; thunk return 183 T body (+38 T thunk-cell fetch, +38 T resume NEXT) — all legs ≤ re-baselined NFR-P4-3 400 T + MMU port write. Non-banked words: 0 T delta (NEXT 0-line diff; EXIT and legacy EXECUTE both got FASTER — discriminators retired)
  - [x] Sub-7.3 Full test-surface sweep per AC8: test-repl 975/0/2 · test-repl-banking 63/0/3 · isolated 6/0 · 19-3 8 PASS + 2 DEFER / 0 FAIL · 19-4 2/0 · 19-5-1 2/0 · skip 25/0 · straddle-regression 3/3 · check-doc-sync 0 drift/31 advisory. One trip during dev: flat test 643 (the known iz-cpm `*/` quirk — flat test itself tripped) re-tuned via the sanctioned cold_start NOP slot (3→4 NOPs) per AC8's explicit carve-out; no banking-probe trips, no straddle-harness diagnosis needed, no reverts
  - [x] Sub-7.4 Sprint-status → `review`; deferred-HW-smoke recipe posted in the close message (AC10, STRONG)

## Dev Notes

### Why this story exists (context)

ADR 19.5 DR-2 (ACCEPTED 2026-06-04) chose **option C** on decisive static itemisation: option A (inline discriminator at every `NEXT`) re-itemised at ≈ +1990 B (320 expansion sites — `grep` total 322 − macro def − test_key); option B (shared `next_dispatch`) saves ~875 B but costs +28 T on **every** thread step = +22.6% on the measured 124.1 T/iter loop anchor — both fail NFR-P4-1's "no measurable regression" clause. Option C moves the dispatch into the stub itself: `NEXT`'s blind `JP (HL)` lands on stub byte 0 = `RST $28` — an instruction that performs exactly the dispatch `NEXT` was never taught, at 0 T for every non-stub word. The same property makes **every** `JP (HL)` dispatch site stub-aware for free: `EXECUTE` (folds to 4 B), `CATCH`'s xt-execute (`src/exception.asm:245` — no change needed), and the outer interpreter. The dispatch-site 2-cell frame + fixed thunk replaces the DOCOL/EXIT-pair-assuming sentinel contract, so non-DOCOL cross-bank targets (root cause (b), Probe-19.3-F's hang) return uniformly instead of being specially handled. Two prior dispatch defects die together: (a) DTC-threading-through-stub-xt (19.2's architectural finding) and (b) the non-DOCOL trampoline hang (19.3's). **19.5.3 — not this story — re-enables the compiled-body probes** (19.2 AC4/AC5, 19.3 AC3/DOES>, the `$9000` ALLOT workaround removal, probes F/G); this story ships the mechanism plus minimal witnesses.

### Draft-time verified citations (PD-2: all re-checked against working tree 2026-06-05, eda591f, 26898 B)

- `NEXT`/`NEXTHL` macros: `src/macros.asm:32..47` (`LD E,(HL)/INC/LD D,(HL)/INC/EX DE,HL/JP (HL)`) — untouched by this story
- EXIT_CODE: `src/inner_interpreter.asm:55..70`; discriminator `:61..68` = `LD A,LOW(2) CP E(1) JR NZ(2) LD A,HIGH(2) CP D(1) JR NZ(2) JP(3)` = **13 B** (re-counted; matches ADR −13)
- `cross_bank_return`: body `src/banking.asm:1187..1203` = **32 B** (re-counted per-opcode; matches ADR −32); comment block `:1064..1186`
- `w_EXECUTE_cf`: `src/inner_interpreter.asm:386..463`; body re-counted = **77 B** (matches ADR; → 4 B = −73); comment block `:281..383`; thread-cell consumers `src/outer_interpreter.asm:204`, `:215` (unaffected)
- `stub_allocate`: `src/banking.asm:835..850` (4 stores; emit-order swap is 0 B); `(stub-allocate)` wrapper `:866..877`; `;`-emit `src/compiler.asm:690..718` (CALL at `:708`); CREATE-emit `:831..847` (CALL at `:839`) — both pass `B = bank, DE = CFA`, no change
- `BANK-OF`: `src/banking.asm:912..936`; `$D4` discriminator `:923..925` (kept); byte-0 read `:928` (→ byte 1, `INC HL` +1 B). The only two `CP $D4` sites in the kernel are EXECUTE (`inner_interpreter.asm:392`, retiring) and BANK-OF (`banking.asm:924`, kept) — verified by grep
- CATCH: `src/exception.asm:114..245` (8-byte frame push `:158..187`; `JP (HL)` xt-execute at `:245` — works with self-dispatching stubs unmodified); `catch_resume_cf` `:269..` (fixed +8 advance); THROW caught path `:420..520` (field reads `:450..468`; `LD BC, 8 / ADD IX, BC` at `:507..508`); frame-layout comments `:15..47`, `:84..96`; depth_word/stash mechanism (Story 18.5.1) sits BELOW frame base — bank-slot placement must not disturb stash offsets (`(IX-2)` depth_word reads at `:486..487` and `catch`-side `:204..227`)
- COLD banking init: `src/antforth.asm` — stub_alloc_tail seed (`:165..168` region), clone LDIR + F2 bank-HERE loop (`:225..235` region); RST install goes after these
- Probes: 18.1-a byte asserts `tests/banking_tests.fth:845..848`; 18.1-b `:879..882`; 18.1-c `:793..827` (geometry only, no byte-semantic asserts); 18.2-a block `:956..1046` incl. `_xbr-exit-code`/`_xbr-addr-cell` `:968..969` + `_p18a-inner` `:1002..1006` — synthesizes the 3-cell sentinel frame via `>R` and reads `EXIT_CODE+20..22` (extraction `:1019..1020`); its layout-shift ELSE emits `FAIL` → Makefile `:370..375` exits 1 → **must be retired-and-replaced wholesale, not left to its SKIP-ish branch** (that branch FAILs, by design of its era; partial removal leaving `_p18a-inner` crashes at load); 18.2-b `:1048..1070` (keep)
- Sweep anchors: `tests/layout_fragility_sweep.sh:54` (`ANCHOR='^cross_bank_return:'`), `:100` (`.sym` lookup); `tests/straddle_repro_sweep.sh:41..47` (awk insert + `ANCHOR-NOT-FOUND` guard). K=0 regression path mutates no source (19.5.1 F3 property — preserve)
- Docs: PD-P4-11 `architecture.md:347..365`; PD-P4-2 `architecture.md:215..227`; redesign `§2.1` `:34..42`, `§2.2` `:44..49`, `§3` `:54..`; `docs/register-conventions.md` (EXX-hygiene walk for the new code)
- ADR: `docs/adr-19-5-cross-bank-dispatch.md` — DR-2 decision + option-C itemisation table + consumer checklist (AC2c section) + per-opcode T-state tables + named assumptions A2/A3

### Implementation sketches (drafts — as-built opcode sums are the figures of record)

**RST install (~11 B, COLD):**

```asm
        LD      A, $C3                          ; 2 B  JP opcode
        LD      (STUB_DISPATCH_VECTOR), A       ; 3 B
        LD      HL, stub_dispatch               ; 3 B
        LD      (STUB_DISPATCH_VECTOR+1), HL    ; 3 B
```

**`stub_dispatch` (~56 B per ADR; entry state: BC = TOS, DE = IP, data-stack [SP] = stub+1 pushed by RST):**

```asm
stub_dispatch:
        POP     HL                              ; HL = stub+1 (bank byte addr)
        LD      A, (HL)                         ; A = target_bank (signed)
        CP      (IY+UserArea.current_bank)      ; same bank?
        JR      Z, .enter                       ; → intra path
        CP      $FF                             ; fixed-memory marker?
        JR      Z, .enter
        ; --- cross path: 2-cell frame [caller_bank][caller_IP], DE ← thunk ---
        DEC     IX
        DEC     IX
        LD      (IX+0), E                       ; caller_IP
        LD      (IX+1), D
        LD      E, (IY+UserArea.current_bank)
        DEC     IX
        DEC     IX
        LD      (IX+0), E                       ; caller_bank (high byte: see note)
        LD      (IX+1), 0
        LD      DE, xbank_thunk                 ; IP ← thunk
        ; --- MMU lookup + swap (BANK!-shape, src/banking.asm:207..210) ---
        PUSH    BC                              ; save TOS
        LD      C, A
        LD      B, 0
        PUSH    HL
        LD      HL, ACTIVE_PAGES_BASE
        ADD     HL, BC
        LD      A, (HL)
        POP     HL
        OUT     (0x72), A
        LD      (IY+UserArea.current_bank), C
        POP     BC                              ; restore TOS
.enter:
        INC     HL                              ; HL = stub+2 (target.lo)
        LD      A, (HL)
        INC     HL
        LD      H, (HL)
        LD      L, A                            ; HL = target CF
        JP      (HL)                            ; DOCOL sees HL = CF (CR-H1)
```

(Frame field order/offsets are the dev's call — keep `xbank_restore`'s pops mirror-consistent; the sketch's per-opcode sum ≈ 53 B, within the ADR's 56 B line. Frame-push shape vs `LD BC,-4 / ADD IX,BC` wrap: pick whichever sums smaller as-built.)

**`xbank_thunk` + `xbank_restore` (~2 + ~35 B):**

```asm
xbank_thunk:
        DW      xbank_restore                   ; 1 thread cell, fixed memory, read-only

xbank_restore:                                  ; reached via NEXT with IP = xbank_thunk
        PUSH    BC                              ; save TOS
        LD      C, (IX+0)                       ; caller_bank.low
        LD      B, 0
        INC     IX
        INC     IX
        LD      HL, ACTIVE_PAGES_BASE
        ADD     HL, BC
        LD      A, (HL)
        OUT     (0x72), A
        LD      (IY+UserArea.current_bank), C
        POP     BC                              ; restore TOS
        LD      E, (IX+0)                       ; caller_IP
        LD      D, (IX+1)
        INC     IX
        INC     IX
        NEXT
```

(Note `xbank_restore` is raw code reached by `NEXT`'s `JP (HL)` on a thread cell — it needs no DEFCODE header. NEXT macro expands ~7 B; sketch sum ≈ 33 B vs ADR 35.)

**CATCH bank slot (Q1 = α, ~25 B itemised):** append `current_bank` at frame **+8** (pushed FIRST, before the existing `+6` prev-CATCH-TOP push) so all existing field offsets (+0/+2/+4/+6), CATCH-TOP = frame base, and the Story-18.5.1 stash zone below the base are untouched. CATCH push: `DEC IX ×2 (4) + LD A,(IY+current_bank) (3) + LD (IX+0),A (3)` = 10 B (high byte not stored; reader forces 0 — bank ≤ 28). THROW caught path, after the existing field reads (`:450..468`) and before `LD SP, HL`: `LD C,(IX+8) (3) + LD B,0 (2) + LD HL,ACTIVE_PAGES_BASE (3) + ADD HL,BC (1) + LD A,(HL) (1) + OUT (2) + LD (IY+current_bank),C (3)` = 15 B — **placement caution:** HL/BC/DE are all live in that window (SP_safe/saved-BC/catching-IP); sequence the bank restore BEFORE those reads or via the scratch cells (`throw_stash_*` precedent) — dev's call, re-itemise. Frame-pop advances: `LD BC, 8` → `10` at `:507`, and `catch_resume_cf`'s `+8` → `+10` (0 B deltas). Both frame-layout comment blocks updated.

### Byte budget (independently itemised per B.2 — each component summed from its sketch/source, not inherited)

| Component | Δ B | Basis |
|---|---|---|
| RST-vector COLD install | +11 | sketch above, per-opcode |
| `stub_dispatch` handler | +56 | ADR itemisation; sketch sums ≈ 53 — carry 56 |
| `xbank_thunk` cell | +2 | one DW |
| `xbank_restore` | +35 | ADR; sketch ≈ 33 — carry 35 |
| `BANK-OF` `INC HL` | +1 | one opcode |
| `stub_allocate` emit-order swap | +0 | same 4 stores |
| Retire EXIT_CODE discriminator | −13 | re-counted from `src/inner_interpreter.asm:61..68` |
| Retire `cross_bank_return` body | −32 | re-counted from `src/banking.asm:1187..1203` |
| `w_EXECUTE_cf` 77 → 4 | −73 | body re-counted per-opcode |
| **Core net** | **≈ −13** | |
| CATCH bank slot (Q1=α) | +25 | itemised above (10 + 15) |
| **Story nominal** | **≈ +12** | |

Envelope: additions 130 B × 1.25 − retirements 118 B → **carry −13..+45 B**. Epic 19.5 plan ~+30..+100 B (epics:902) has +65 B spent (19.5.1): nominal close ≈ 77 B cumulative fits; an as-built above +35 B breaches the plan's upper bound → flag plainly for 19.5.4 reconciliation, do not absorb silently.

### Q-dispositions (defaults adopted unless Ant overrides at dev-pass start)

- **Q1 — CATCH frame shape.** α (default): append the bank slot at frame +8 (pushed first; all existing offsets preserved; ~25 B; matches the ADR's +~20 B intent). β: repurpose the depth_word's high byte (`(IX-1)`, invariantly 0 while PS_SIZE = 256) — saves ~8 B but couples bank restore to the PS_SIZE invariant and violates the depth_word's documented future-proofing contract (`src/exception.asm:220..224`); rejected by default, listed for completeness.
- **Q2 — non-DOCOL cross-bank witness placement.** Default: one minimal probe appended to `tests/banking_tests_19_3.fth` (it already has bank-5 CREATE machinery + the `$9000` ALLOT workaround + DEFER-grading recipe). The recipe's grading loop is a **hardcoded id list** (`Makefile:683` `for pid in d e f g`) — new probes are NOT graded until added there (use a distinct id family, e.g. a separate grading clause keyed on `probe-19.5.2-*`, so F/G's DEFER clauses stay untouched), and the suite-end sentinel `---probe-19.3-suite-end---` must remain the LAST marker emitted or the suite-halt check (`:694`) fails. The AC6 CATCH probe can ride the same fixture (cross-bank xt + THROW inside, CATCH outside, assert `BANK@` = 0 after). Alternative: a new isolated fixture if 19-3's layout proves hostile — same Q3-fallback discipline as 19.5.1.
- **Q3 — RST vector.** `$0028` (default, per ADR). Keep it one EQU. If the emulator half of A2 fails (it should not — iz-cpm intercepts only `$0000`/`$0005`), shift to `$0008`/`$0010`/`$0018`/`$0020` at equal cost and record why. HW claimability rides 19.5.4.

### Constraints and guardrails

- **Scope fences:** compiled-body probe re-enablement (19.2 AC4/AC5, 19.3 AC3/DOES>, `$9000` workaround removal, probes F/G bodies, banked NFR-P4-8 full variant) = **19.5.3**. Uncaught-path bank restore (ABORT/QUIT) = **Epic 21** (row 21-2). HW verification (A1/A2/A3) = **19.5.4**. F1/F2/F3 (19.5.1) are dispatch-architecture-independent — do not touch them; the F3 regression target must stay green through every layout shift this story makes.
- **NEXT is untouchable.** AC2's "byte-for-byte" is load-bearing: the entire NFR-P4-1 case for option C rests on `src/macros.asm:32..47` not changing. Any temptation to "just add one check" in NEXT is options A/B — already rejected on itemised evidence.
- **DOCOL CR-H1 precondition:** every `JP (HL)` into a CF must have HL = CF (DOCOL computes `body = HL+3`). Both handler paths end `HL ← target CF / JP (HL)` — preserve under any refactor.
- **RST pushes on the data stack:** SP is the Forth data stack; the handler's `POP HL` must be the first instruction. Document the 2-byte transient against `check_overflow`'s 32-byte margin.
- **Layout-shift discipline (AC8):** this story moves the dictionary base (net ≈ +12 B nominal). Straddle harness is the diagnostic for any banking-probe trip; `feedback_iz_cpm_trampoline_fragility` is SUPERSEDED — no emulator/trampoline framing, no reflex reverts, no test-643 NOP re-tuning unless flat test 643 itself trips.
- **B.2 / PD-2:** every figure above is a draft-time itemisation; three ADR retirement figures were re-counted at draft time (all matched — unlike 19.5.1, where two ADR figures needed correction; stay alert anyway, e.g. the ADR's 56/35 handler figures vs the sketches' 53/33). Re-itemise as-built.
- **REPL probe hygiene:** lines ≤ 128 chars (TIB_SIZE); colon-body wrappers with run-time `result=` emission; `0 BANK!` before `BANKS-CLEAR`; no disk/a/ files this story (no HW pass — if any fixture migrates for 19.5.4, 0x1A-terminate per `feedback_cpm_0x1a_eof_marker`).
- **Solo-dev calibration:** the probe surface for this story is three small witnesses + two byte-index migrations + one retire-and-replace — not a new probe framework. Keep the handler/thunk comments in the established house style (contract + EXX-audit + forward pointers), at the retired trampoline's level of rigor but not beyond.

### Previous-story intelligence (19.5.1, done 2026-06-04)

- **Bucket-chain pollution (lookup-path DR-1 variant):** by the main suite's tail, hash chains contain window-resident definitions; FIND under a foreign bank reads the foreign page → `-13` strands. Probes that switch banks mid-main-suite are structurally unsafe — behavioural bank-switching witnesses belong in **isolated fixtures** (kernel-words-only, dictionary below `$8000`). This story's Q2 witnesses follow that rule. Epic 20's per-wordlist bank field is the owning fix; interim gotcha documented at redesign §5.5.
- **F1 guard interplay:** `BANK!` now THROWs `-273` on a foreign-bank switch from window-resident code. The RST handler and thunk do NOT go through `BANK!` (they write the MMU port directly) — the guard does not constrain this story's dispatch paths, by design. Don't "reuse" `w_BANK_STORE_cf` for the handler's swap; the BANK!-shape MMU lookup (`src/banking.asm:207..210`, the `.window_ok` block) is the pattern, minus guard and minus the per-bank triple swap.
- **CR lesson (byte-trims):** 19.5.1's CR collapsed F1's two-compare range test to `AND $C0 / CP $80 / JR NZ` (−2 B). The handler's two-branch intra check (`CP current` / `CP $FF`) may have an analogous fold — worth one look at CR time, not worth pre-optimising.
- **As-built vs sketch drift ran −1..0 B** on 19.5.1's components (sketches were honest). The ×1.25 discipline still applies to this story's larger additive surface.
- **Self-calibrating F3 worked:** the straddle target re-derives pads per run — trust it across this story's shifts; a straddle FAIL with `e273` present means fixture geometry drift (re-derive the +24 offset), not a kernel regression (see the target's header comment, `Makefile:786..795`).

### Git intelligence

Recent commits: `eda591f` (19.5.1 dev+CR, +65 B — the guard/COLD-init/regression-gate pattern this story builds beside), `8fe78d0` (19.5.1 create-story + row renames), `158641c` (19.5.0 ADR spike — reproducers under tests/, sweep drivers' backup/restore discipline), `a954976` (19.4 CR follow-up, fid_validate), `94c2ba0` (19.4 close + v3.0.3 tag). Patterns to follow: kernel edits land with comment blocks citing ADR/PD/FR ids; CR pass runs separately after dev-pass close (`CR` command, fresh context); commit messages name the story + byte delta; **no Claude co-author trailer** (STRONG).

### Web research

N/A — Z80/CP/M kernel, zero external dependencies. RST-vector semantics verified against the live emulator + ADR A2's zero-page survey rather than web sources.

### Project Structure Notes

- Kernel edits: `src/banking.asm` (stub_allocate v2, stub_dispatch, xbank_thunk/xbank_restore, BANK-OF, trampoline removal), `src/inner_interpreter.asm` (EXIT_CODE discriminator removal, EXECUTE fold), `src/exception.asm` (CATCH/THROW bank slot), `src/antforth.asm` (RST install), `src/constants.asm` (vector EQU). No `src/macros.asm` change (load-bearing).
- Tests: `tests/banking_tests.fth` (18.1-a/b byte indices, 18.2-a replacement), `tests/banking_tests_19_3.fth` (Q2 witnesses), `Makefile` (grading updates), both sweep scripts (anchor migration).
- Docs: `_bmad-output/planning-artifacts/architecture.md` (PD-P4-2 supersede note, PD-P4-11 bytes), `docs/antforth-banking-redesign.md` (§2.1/§2.2/§3). No new throw codes; no docs/throw-codes.md change.

### References

- ADR (decision + itemisation + checklist + T-tables + assumptions): `docs/adr-19-5-cross-bank-dispatch.md` §DR-2 (status Accepted 2026-06-04; NFR-P4-3 re-baseline rider rides with it)
- Epic 19.5 stories block: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:885..902` (19.5.2 row at :888)
- Story 19.5.1 artifact (predecessor; F1/F2/F3 + bucket-pollution finding): `_bmad-output/implementation-artifacts/19-5-1-portal-aliasing-guards-bank-n-here-cold-init-h5-reproducer-regression-slot.md`
- Kernel sites: listed under "Draft-time verified citations" above
- Memories: `feedback_kernel_ldir_estimate_overshoot` (×1.25) · `feedback_phase4_probe_bank_switch_limitation` + 19.5.1's bucket-pollution finding (isolated-fixture rule) · `feedback_post_hw_smoke_steps_at_review` (**STRONG** — recipe in close message) · `feedback_iz_cpm_test_643_quirk` (separate quirk, conditional) · `feedback_no_preexisting_discharge` (surface-file-fix if the rework exposes adjacent defects) · `feedback_plain_qa_language` (envelope breach reporting) · `feedback_ceremony_diminishing_returns` (probe-surface calibration)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.8 (claude-opus-4-8[1m]) — Claude Code dev-story workflow, 2026-06-05

### Implementation Plan

Q-dispositions: all defaults adopted (Q1=α frame +8 bank slot; Q2 witnesses in `tests/banking_tests_19_3.fth` with distinct `probe-19.5.2-*` id family; Q3 `$0028` vector). Task order followed as written, with two co-location notes: (1) the stub_dispatch/thunk/xbank_restore block (Task 2) landed as an in-place replacement of the cross_bank_return comment+body (Sub-3.2) since the new code's suggested home IS the retired trampoline's slot; (2) Task 4 (BANK-OF) was applied before the first assembly so the kernel was layout-coherent at the first build checkpoint.

### As-built byte itemisation (AC9 / B.2 — per-opcode, sums to the measured delta exactly)

| Component | Δ B | draft est. |
|---|---|---|
| RST-vector COLD install (`src/antforth.asm`) | +11 | +11 |
| `stub_dispatch` handler | +61 | +56 (ADR) / 53 (sketch) |
| `xbank_thunk` cell | +2 | +2 |
| `xbank_restore` (incl. trailing NEXT expansion 7 B) | +38 | +35 (ADR) / 33 (sketch) |
| `BANK-OF` `INC HL` | +1 | +1 |
| `stub_allocate` emit-order swap (LD (HL),n 2 B ↔ LD (HL),B 1 B swap places) | +0 | +0 |
| CATCH bank-slot push (frame +8) | +10 | +10 |
| THROW caught-path bank restore | +15 | +15 |
| JR→JP ×2 (`.throw_uncaught`, `.throw_zero` — pushed past +127 by the insertion; anticipated by the original JR comment) | +2 | — |
| cold_start NOP slot 3→4 (flat test 643 re-tune per AC8 carve-out) | +1 | — |
| Retire EXIT_CODE discriminator | −13 | −13 |
| Retire `cross_bank_return` body | −32 | −32 |
| `w_EXECUTE_cf` 77 → 4 | −73 | −73 |
| **Total (= 26921 − 26898)** | **+23** | nominal +12 |

Envelope: +23 within the story's −13..+45 B carry. Epic 19.5 cumulative: 65 (19.5.1) + 23 = **88 B**, inside the ~+30..+100 B plan (epics:902) — no breach flag needed (gate was +35; measured +23).

The handler/restore as-built figures ran +5/+3 over the ADR's lines (sketch sums had undercounted IX-prefixed opcode widths); the deliberate-overshoot ×1.25 envelope absorbed it, as designed.

### As-built T-state account (AC9, per-opcode; vs re-baselined NFR-P4-3 ≤ 400 T + MMU port write)

- **Intra-bank through stub** (NEXT's `JP (HL)` on stub byte 0 → target CF): RST 11 + vector JP 10 + POP HL 10 + LD A,(HL) 7 + CP (IY+d) 19 + JR Z taken 12 + enter-tail 34 = **103 T** (same-bank branch); $FF-marker branch +14 (JR not-taken 7 + CP n 7) = **117 T**. Both beat the retired EXECUTE intra path (123 T) and the ADR anchor (≈107 T) brackets them.
- **Cross-bank dispatch** (RST entry → first instruction of target CF): entry+branches 78 + 2-cell frame push 135 + LD DE,thunk 10 + MMU lookup/OUT/cell 111 + enter-tail 34 = **368 T** (OUT included) ≤ 400 T ✓.
- **Thunk return** (`xbank_restore`): thunk-cell NEXT fetch 38 + body 183 (frame pops + MMU restore + cell) + resume NEXT 38 = **259 T** end-to-end ≤ 400 T ✓.
- **Non-banked words: 0 T delta** — `src/macros.asm` has a 0-line diff (NEXT byte-for-byte untouched, AC2's load-bearing constraint). EXIT is FASTER (the ~23 T sentinel CP miss penalty is retired); legacy EXECUTE is FASTER (the 18 T `LD A,H / CP / JR C` discriminator is retired). FR-P4-19 preserved exactly, with margin.

### Debug Log References

- First build checkpoint (post Tasks 1–4): 26893 B, clean assembly. Flat suite tripped at test 643 (suite truncated at 651 PASS) — the known iz-cpm `*/`-underflow layout quirk, flat test itself tripped → re-tuned cold_start NOP slot 3→4 per AC8's explicit carve-out (`feedback_iz_cpm_test_643_quirk`). 975/0 after.
- CATCH/THROW widening (Task 5): two JR-range assembly errors (`.throw_uncaught` +129, then `.throw_zero` +130) — the original code's comment anticipated exactly this ("switch back to JP Z"); both converted, +2 B.
- probe-19.5.2-b/c first run: both PASS first time — the 19.3-F hang shape returns cleanly through the thunk; caught cross-bank THROW lands in the catcher's bank.
- Sweep-anchor verification: `straddle_repro_sweep.sh 16 5500` inserts the knob at `xbank_restore:`, builds, runs, restores source; `layout_fragility_sweep.sh before 0` resolves the `xbank_restore`/`kernel_end` symbols and classifies (HANG at the pre-19.3 inline configuration — the harness's documented diagnostic purpose, not a regression; the shipped-config gates are green).

### Completion Notes List

- **AC1** stub layout v2 shipped: `[$EF][bank][lo][hi]`, same 4 stores / 4 B / region / capacity / xt-identity / NFR-P4-4 pin; allocator main-set-preservation contract untouched; dead `$C3` retired (byte 0 live code).
- **AC2** RST-$28 handler shipped; COLD installs `JP stub_dispatch` at `$0028` (single EQU `STUB_DISPATCH_VECTOR` + documented one-constant re-vector contingency incl. the RST opcode byte table in the EQU comment). NEXT untouched (0-line diff). A2 emulator-half verified: probe-19.4-a routes the full `JP (HL)` → RST → cross path → DOCOL → EXIT → thunk → restore chain end-to-end under iz-cpm-banking.
- **AC3** thunk + `xbank_restore` shipped; uniform return for DOCOL and non-DOCOL targets — **probe-19.5.2-b runs the exact Probe-19.3-F hang shape (cross-bank EXECUTE of a bank-5 CREATE'd word) and returns cleanly**. Root cause (b) subsumed. 2-cell frame replaces 3+1 (R-stack pressure note in handler comment; redesign §2.2 updated).
- **AC4** all three retirements done; EXECUTE folded to 4 B; comment-reference sweep clean (remaining src/ mentions are deliberate retirement-context citations).
- **AC5** BANK-OF reads byte 1 (+1 B); `$D4` discriminator and -1-for-legacy unchanged (now the kernel's only CP $D4 site, noted in comment).
- **AC6** CATCH frame +8 bank slot (Q1=α — all existing offsets preserved, 18.5.1 stash zone undisturbed); THROW caught path MMU-restores the catcher's bank (sequenced BEFORE the field reads, where HL/BC/DE are free); both frame-pop advances widened 8→10; Epic-21 fence note at `.throw_uncaught`. In-story witness probe-19.5.2-c PASSES (code=77 delivered AND BANK@=0 after caught cross-bank THROW).
- **AC7** all 6 ADR checklist items + sweep-anchor migration done (see Task 6 checkboxes). Item (4) verify-only confirmed: `;`-emit and CREATE-emit pass B=bank / DE=CFA unchanged; their stale comment refs updated.
- **AC8** all 9 surfaces green (counts in Sub-7.3); 3 new witnesses (a: RST intra end-to-end; b: non-DOCOL cross-bank; c: CATCH bank restore).
- **AC9** +23 B (≤ +35 gate; epic cumulative 88/100); T-state legs 103/117/368/259 ≤ 400; 0 T non-banked delta.
- **AC10** HW smoke deferred to 19.5.4 per ADR A2/A3; recipe posted in the close chat message per `feedback_post_hw_smoke_steps_at_review` (STRONG).

### File List

- `src/banking.asm` — stub_allocate v2 (emit-order + comment block); stub_dispatch + xbank_thunk + xbank_restore (replaces cross_bank_return block); BANK-OF byte-1 read + comments; F1-guard comment phrasing
- `src/inner_interpreter.asm` — EXIT_CODE discriminator removal + comment rewrite; w_EXECUTE_cf fold to 4 B + option-C contract comment
- `src/exception.asm` — CATCH frame +8 bank slot; THROW caught-path bank restore; frame-pop advances 8→10 (×2); frame-layout comments (×2); JR→JP ×2; Epic-21 fence note
- `src/antforth.asm` — RST-vector COLD install; NOP slot 3→4
- `src/constants.asm` — STUB_DISPATCH_VECTOR EQU + stub-layout-v2 comment
- `src/dictionary.asm` — FIND xt-cell comment (dispatch-mechanism reference)
- `src/compiler.asm` — COMPILE, + `;`-emit comment updates (3-way → RST references)
- `tests/banking_tests.fth` — 18.1 block comment; 18.1-a/b byte asserts v2; 18.2 block retire-and-replace (probe-19.5.2-a; `_xbr-*` + `_p18a-inner` removed wholesale); 18.3 block header + 18.3-F mechanism comment; 19.2-J byte note
- `tests/banking_tests_19_3.fth` — probe-19.5.2-b (non-DOCOL cross-bank witness) + probe-19.5.2-c (CATCH bank restore) + 19.5.2 suite sentinel; probe-F defect-class note
- `tests/layout_fragility_sweep.sh` — anchor migration (before: `^xbank_restore:`; after: thunk-body comment line); sym lookup; verdict grep 18.2-a → 19.5.2-a; header comments
- `tests/straddle_repro_sweep.sh` — anchor migration `^cross_bank_return:` → `^xbank_restore:`; comments
- `Makefile` — probe-19.5.2-a grading block (replaces 18.2-a); 18.1-a/b PASS-message bytes; 19-3 recipe: probe-19.5.2-b/c + suite-sentinel grading clauses
- `_bmad-output/planning-artifacts/architecture.md` — PD-P4-2 SUPERSEDED note; PD-P4-11 layout-v2 note
- `docs/antforth-banking-redesign.md` — §2.1 self-dispatch note; §2.2 SUPERSEDED + uniform return; §3 mechanism rewrite
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — story status row
- `_bmad-output/implementation-artifacts/19-5-2-dispatch-rework-stub-aware-next-plus-non-docol-trampoline-targets.md` — this story file

## Change Log

- 2026-06-06 (code-review pass): 18 candidates across 7 finder angles; 11 refuted (incl. FR-P4-26 pointer hazard and uncaught-THROW bank state — both documented scope fences; JR→JP conversions verified necessary at +130 displacement), 7 fixed:
  - **CR-F1 (CONFIRMED correctness defect)**: THROW's caught path restored MMU + current_bank from frame +8 but NOT the live (HERE, LATEST, wordlist_head) triple — a real `BANK!` between CATCH and THROW left the catcher running with the foreign triple, and a later same-bank `BANK!` made the corruption sticky (saved the foreign triple over the table slot). Fix: `triple_owner` UserArea byte (written by COLD / real BANK! / caught THROW), CATCH records it in the formerly-unwritten frame +9 slot, caught path swaps the triple back via `bank_triple_swap` — the swap cascade factored out of `w_BANK_STORE_cf` so both sites share it. Witness: new probe-19.5.2-d (bank-0 thrower does real `5 BANK!` then `88 THROW`; asserts 88 + BANK@ 0 + HERE unchanged); probe-19.5.2-c keeps the skip-shape (dispatch-only THROW) covered. Probe note: bank-0 runtime words have no stub-xt — the probe uses `'`, not `LATEST @`.
  - stub_dispatch cross-path frame pushes routed through `rpush_de` (−13 B; one R-stack push convention; subsumes the `LD (IX+1),0` encoding finding).
  - `SLOT2_WINDOW_BASE EQU 0x8000` added to constants.asm; the F1-guard compare, bank-N HERE COLD-init, and +BANK probe address now derive from it.
  - Handler DE-contract documented at the stub_dispatch RETURN block (DODOES now enumerated) and in the inner_interpreter.asm header (mechanism verified sound for all four current handlers; doc-only).
  - banking_tests_19_4.fth stale sentinel-trampoline narration updated to the 19.5.2 mechanism (was presenting the retired trampoline as live).
  - Declined: F1 straddle-gap (ADR DR-1 "contained, not abolished" — unfixable in DTC at CREATE time; F3 regression-gated); MMU-swap 4-site dedup (refuted: per-site register divergence defeats a clean helper, ~3-10 B at best).
  - Bytes: +19 B (26940; triple-restore machinery net of the −13 B rpush saving). Story total +42 B; **epic cumulative 107 B — exceeds the ~100 B ADR guidance by 7 B** (correctness fix; carry to epic close / NFR-P4-3 re-baseline). NOP slot re-tuned 4→5 (flat 643 tripped at 4). All nine surfaces re-green incl. probe-19.5.2-d.
  - CR-pass file additions beyond the dev-pass File List: `src/structures.asm` (triple_owner field), `tests/banking_tests_19_4.fth` (comment refresh).
- 2026-06-05 (dev-story): Story implemented end-to-end at +23 B (26898 → 26921). Stub layout v2 (`$EF` RST-$28 self-dispatch) + `$0028` vector install + stub_dispatch/xbank_thunk/xbank_restore landed; EXIT_CODE discriminator / cross_bank_return trampoline / EXECUTE 3-way retired (−118 B); BANK-OF → byte 1; CATCH frame +8 bank slot + THROW caught-path bank restore (Q1=α; two anticipated JR→JP conversions). Probe migration: 18.1-a/b byte asserts v2; 18.2-a retired-and-replaced by probe-19.5.2-a; new witnesses probe-19.5.2-b (non-DOCOL cross-bank — the 19.3-F hang shape now returns cleanly) + probe-19.5.2-c (CATCH bank restore); sweep anchors migrated to `xbank_restore:`. Docs: PD-P4-2 superseded, PD-P4-11 v2, redesign §2.1/§2.2/§3. Flat test 643 re-tuned via NOP slot (3→4) per AC8 carve-out. All 9 test surfaces green; 0 doc drift; T-state legs 103/117/368/259 ≤ 400 T re-baseline; NEXT 0-line diff. HW smoke deferred to 19.5.4 (recipe in close message). Status → review.
- 2026-06-05 (create-story): Story drafted from ADR 19.5 DR-2's option-C decision (self-dispatching RST-$28 stub + 2-cell dispatch frame + fixed-memory return thunk; EXIT_CODE discriminator / cross_bank_return / EXECUTE 3-way retired; BANK-OF +1; CATCH-cross-bank bank slot designed and landed per Q1=α). PD-2 draft-time verification: all three ADR retirement figures re-counted from live source and CONFIRMED (13 B / 32 B / 77 B — no drift this time, unlike 19.5.1's two corrections); all kernel/test/doc line citations re-checked at eda591f (26898 B baseline). Fresh-context adversarial validation pass (checklist.md) returned 0 CRITICAL / 0 MAJOR / 5 MINOR — all applied: probe-18.2-a retirement scope widened to the full `:956..1046` block (incl. `_xbr-*` + `_p18a-inner` helpers — partial removal crashes at load); `_xbr` extraction citation corrected to `:1019..1020`; BANK!-shape MMU citation corrected to `banking.asm:207..210` (was comment prose at `:157..161`); 19-3 recipe's hardcoded `for pid in d e f g` grading loop + suite-end-sentinel-last constraint made explicit in Q2. Status: ready-for-dev.
