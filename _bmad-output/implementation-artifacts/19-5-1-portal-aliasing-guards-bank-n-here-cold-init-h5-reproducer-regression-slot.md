# Story 19.5.1: Portal-aliasing guards + bank-N HERE COLD-init (H5) + reproducer regression slot

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Drafted 2026-06-04 by create-story workflow, first implementing story
     of Epic 19.5 after the 19.5.0 ADR spike locked DR-1 + DR-2
     (docs/adr-19-5-cross-bank-dispatch.md, ACCEPTED 2026-06-04).
     Sprint-status row RENAMED at this create-story turn per the ADR's
     flagged disposition (ADR status line + epics:902 + 19.5.0 Sub-3.2):
     was `19-5-1-trampoline-stabilization-layout-fragility-fix` — DR-1
     found no trampoline defect to fix; the story is now the DR-1 fix
     proposal F1+F2+F3. The 19-5-3 row was renamed in the same pass
     (H5 reference moved here, its natural home). -->

## Story

As Marc (OG user) whose interpreted-mode definitions can land at/above `$8000` (the MMU slot-2 portal window) and switch banks,
I want `BANK!` to THROW a catchable error instead of silently corrupting execution when called from window-resident code, banked dictionaries to start page-resident at `$8000` from COLD, and the straddle reproducer wired into the Makefile as a permanent regression gate,
so that the portal-aliasing corruption class (ADR 19.5 DR-1 — the root cause of every "trampoline layout-fragility" hang that forced the 19.2-H5 and 19.3 reverts) is contained for users and can never silently regress as the kernel grows.

## Acceptance Criteria

1. **AC1 (F1 — `BANK!` window guard).** `w_BANK_STORE_cf` (`src/banking.asm:149`) gains a guard between the existing precondition (`:150..156`, BC.high==0 + BC.low<bank_count) and the MMU port write: if `target_bank ≠ (IY+UserArea.current_bank)` AND the caller's IP (DE at DEFCODE entry, per `src/inner_interpreter.asm:7` convention) lies in `$8000..$BFFF`, then `LD BC, THROW_BANK_FROM_BANKED` / `JP w_THROW_cf.kernel_entry` (the `.abort_bank` precedent at `:198..203` shows the exact exit idiom) — THROW fires BEFORE any MMU/state mutation. Behavior preserved: (a) same-bank switches from window code stay legal (probe-18.2-a's `0 BANK!` while in bank 0, `tests/banking_tests.fth:1025`, must keep passing); (b) interpreted-mode `BANK!` is unaffected (the outer-interpreter EXECUTE chokepoint leaves IP in kernel space < `$8000`); (c) callers with IP < `$8000` or ≥ `$C000` are unaffected. Documented residual (ADR DR-1, honest-coverage note): the guard checks the immediate caller's IP only; a bank-0 body whose switch-site cell is below `$8000` but whose later cells straddle still corrupts (R-stack walking rejected on cost) — restate this limit in the `BANK!` docstring.
2. **AC2 (THROW code `-273` registered).** `THROW_BANK_FROM_BANKED EQU -273` added to `src/constants.asm` (after `:169`). **PD-2 correction locked at draft time: the ADR's "next free in the -257.. series" resolves to `-273`, NOT `-272` — `-272` = `THROW_ASM_BIT_RANGE`, allocated by Story 11.5.6 (`src/constants.asm:169`).** Registration surface: (a) `docs/throw-codes.md` allocation table gains the `-273` row (description "bank switch from banked code", site `banking.asm w_BANK_STORE_cf`, story 19.5.1); (b) `throw_desc_table` entry per Q1 disposition (see Dev Notes — byte cost is the decision variable); (c) the kernel-raised-codes enumeration comment at `src/exception.asm:410..416` ("-258..-271") is extended to name `-273`.
3. **AC3 (F2 — bank-N HERE COLD-init, the H5 fix re-landed).** Immediately after the COLD bank-table clone LDIR (`src/antforth.asm:194..197`), a loop sets `bank-table[1..28].here = $8000` (low byte then high; entry stride `BANK_TABLE_ENTRY_SIZE` = 6; `BANK_TABLE_BASE` = `$D400`, `BANK_TABLE_CAP` = 29 per `src/constants.asm:17..`). LATEST + wordlist_head clone semantics are UNCHANGED (kernel words stay findable in bank N per the 19.3.1 bucket-skip contract; only the `here` field is overridden). The stale H5 revert comment block (`src/antforth.asm:198..213`, "the cross-bank dispatch trampoline is fragile…") is REWRITTEN to cite ADR 19.5 DR-1: the 2026-05-20 revert was against a test-configuration portal-aliasing hazard, not a defect in this fix; re-landing is unblocked because the hang is explained and regression-gated (F3).
4. **AC4 (F3 — straddle-reproducer Makefile regression slot).** A new `.PHONY` Makefile target (suggested name `test-straddle-regression`) drives `tests/straddle_repro_sweep.sh` at K=0 (no kernel-source mutation; the K>0 knob stays sweep-only) and asserts BOTH verdicts: (a) a PASS configuration (victim body fully below `$8000`) emits all of `[m1]..[m5]` + `survived`; (b) a HANG configuration (mid-straddle class: `1 BANK!` cell below `$8000`, later body cells above — the class F1 cannot guard) truncates markers and never emits `survived`. Pad values MUST be self-calibrating against layout drift: derive them at run time from the fixture's in-band `HERE U.` outputs (transition is pinned to absolute body-start 32696/32697 per ADR evidence E4, invariant under kernel growth), OR pin pads with a loud recalibration failure mode — silent false-PASS via wrong pad placement is the failure the `ANCHOR-NOT-FOUND` guard in the sweep script (`tests/straddle_repro_sweep.sh:44..48`) exists to prevent; match that discipline. Target listed in `.PHONY` (`Makefile:50`) and documented alongside the `test-repl-banking-isolated-*` family.
5. **AC5 (REPL probes).** New probes, following the colon-body-wrapper + `result=` grading pattern (`feedback_phase4_probe_bank_switch_limitation`; lines ≤ 128 chars per TIB_SIZE): (a) **window-guard probe** — a colon word compiled at/above `$8000` that attempts a foreign-bank `BANK!`; `CATCH` returns `-273`; current bank and MMU state unchanged after the catch (guard fires before mutation). The probe must assert its own precondition (`HERE` already ≥ `$8000` at compile point, true late in `tests/banking_tests.fth` per the probe-18.2-a region evidence `:995..999`; emit an explicit `SKIP`+reason if not) or live in an isolated fixture with an `ALLOT` shim per `tests/straddle_repro.fth.in`. (b) **bank-N HERE probe** — first visit to a fresh bank N>0 shows `HERE` = `$8000` exactly (e.g. `BANKS-CLEAR $22 +BANK $35 +BANK 1 BANK! HERE` → 32768; remember `0 BANK!` BEFORE `BANKS-CLEAR` per the `banking.asm:454` trap). (c) The three isolated suites' `HERE $9000 SWAP - ALLOT` workaround lines (`tests/banking_tests_19_2.fth:64`, `_19_3.fth:52,140`, `_19_4.fth:49`) still compute a valid forward ALLOT from the new `$8000` base — verify all isolated surfaces stay green; REMOVAL of the workaround is explicitly 19.5.3 scope (ADR consequences), not this story's.
6. **AC6 (byte budget — independently itemised per B.2).** Draft-time per-component itemisation (Dev Notes): F1 guard 21 B + `-273` EQU 0 B + F2 loop 16 B = **37 B core**; desc-table entry +31 B if Q1=α. ×1.25 kernel-story discipline (`feedback_kernel_ldir_estimate_overshoot`) → envelope **≤ ~47 B (Q1=β) / ≤ ~85 B (Q1=α)**. **PD-2 correction: the ADR's "F1 = 20 B" re-sums to 21 B per-opcode; 21 is the planning figure.** Dev-pass re-itemises against as-built opcodes; `wc -c build/antforth.com` delta reported in Dev Notes against the Epic 19.5 ~+30..+100 B plan (epics:902).
7. **AC7 (test surfaces preserved + layout-shift discipline).** At story close: `make test-repl` ≥ 975 PASS / 0 FAIL; `make test-repl-banking` ≥ 61 PASS / 0 FAIL plus the new AC5 probes; `test-repl-banking-isolated` (base, -19-3, -19-4) all PASS / 0 FAIL; `test-repl-banking-skip` 0 FAIL; new `test-straddle-regression` PASS; `make check-doc-sync` 0 drift. **The +37..68 B of F1+F2 shifts the interpreted-dictionary base — exactly the knob DR-1 proved moves the `$8000` crossing point.** If any banking probe trips after the shift, diagnose via the portal-aliasing mechanism (which probe body now straddles, fetched under which mapping — `tests/straddle_repro_sweep.sh` is the diagnostic harness); do NOT revert per the old fragility reflex (`feedback_iz_cpm_trampoline_fragility` is SUPERSEDED by DR-1) and do NOT re-tune the test-643 cold_start NOP slot for this (separate quirk, `feedback_iz_cpm_test_643_quirk` — only relevant if flat-iz-cpm test 643 itself trips).
8. **AC8 (docs + hardware exemption).** `docs/antforth-banking-redesign.md` §5.4 (`BANK!`) documents the window guard (THROW `-273`, the residual bank-0-straddle exposure, and the F2 page-resident-from-first-byte property); `docs/throw-codes.md` row per AC2. S9 / NFR-P4-11 hardware smoke: DEFERRED to Story 19.5.4 per the ADR's named assumptions (A1 straddle signature on real HW; the F2 COLD-init rides A3's Probe-19.2-F re-test) — documented here as the explicit exemption. Per `feedback_post_hw_smoke_steps_at_review` (**STRONG**): the dev-pass close message MUST post the deferred-HW-smoke recipe in the chat, not only in Dev Notes.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [ ] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes
  - Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F). **Draft-time baseline RESOLVED 2026-06-04 (post-create-story commit pass): the 19.4 CR follow-up (`src/file_access.asm`, −1 B, commit a954976) and the 19.5.0 close-out artifacts (158641c) are now committed; verified baseline at story creation = 26833 B with the full sweep green (975/0/2 · 61/0/3 · isolated at counts). Re-verify anyway at dev-pass start.**
- [ ] Capture current `make test-repl` baseline pass count (draft-time verified: 975/0/2) and `make test-repl-banking` (61/0/3)

### Story tasks

- [ ] **Task 1 — F1 `BANK!` window guard (AC: #1, #2)**
  - [ ] Sub-1.1 Add `THROW_BANK_FROM_BANKED EQU -273` to `src/constants.asm` (extend the antforth-extension block comment at `:142..151`; note the block is no longer assembler-only)
  - [ ] Sub-1.2 Insert the guard in `w_BANK_STORE_cf` after the precondition, before the `OUT (0x72)` (implementation sketch in Dev Notes; THROW exit via `JP w_THROW_cf.kernel_entry` with BC = code, `.abort_bank` idiom)
  - [ ] Sub-1.3 Q1 disposition: add (α) or omit (β) the `throw_desc_table` entry (`src/exception.asm:826..`; format `DW code / DB len / DB text`, len hand-counted); update the kernel-raised-codes comment at `src/exception.asm:410..416` either way
  - [ ] Sub-1.4 Update the `BANK!` docstring (`src/banking.asm:125..146`) + CCD-3 citation: guard semantics, `-273`, residual bank-0-straddle exposure, ADR DR-1 reference
- [ ] **Task 2 — F2 bank-N HERE COLD-init (AC: #3)**
  - [ ] Sub-2.1 Add the `bank-table[1..28].here = $8000` loop after the clone LDIR (`src/antforth.asm:194..197`); itemised sketch in Dev Notes (~16 B)
  - [ ] Sub-2.2 Rewrite the stale H5 revert comment (`src/antforth.asm:198..213`) per AC3 (cite ADR DR-1; drop the "trampoline is fragile" attribution)
  - [ ] Sub-2.3 Confirm no other reader assumes bank-N `here` = clone-of-bank-0 (grep `bank_table`/`BANK_TABLE` consumers; `.BANKS` minimal form prints BANK/PAGE only — `src/banking.asm:554..` — real-HERE display is Epic 22 scope)
- [ ] **Task 3 — F3 regression slot (AC: #4)**
  - [ ] Sub-3.1 Choose calibration mechanism (self-calibrating from in-band `HERE U.` output recommended; transition body-start 32696/32697 is the layout-invariant anchor) and implement the Makefile target at K=0
  - [ ] Sub-3.2 Wire PASS + HANG assertions with loud failure on calibration mismatch; add to `.PHONY`; do NOT add to the default `test` chain (it builds its own kernel into /tmp; document the target's purpose header per Makefile house style)
- [ ] **Task 4 — REPL probes (AC: #5)**
  - [ ] Sub-4.1 Window-guard CATCH probe (`-273`, state unchanged after catch) with compile-address precondition or isolated-fixture shim
  - [ ] Sub-4.2 Bank-N first-visit `HERE = $8000` probe
  - [ ] Sub-4.3 Run all isolated suites; verify the `$9000` workaround lines still pass untouched (removal = 19.5.3)
- [ ] **Task 5 — Docs, budget, close-out (AC: #2, #6, #7, #8)**
  - [ ] Sub-5.1 `docs/throw-codes.md` `-273` row; `docs/antforth-banking-redesign.md` §5.4 guard + F2 note
  - [ ] Sub-5.2 As-built byte itemisation vs the 37 B (+31 Q1=α) draft figure; `wc -c` delta vs ×1.25 envelope; record in Dev Notes
  - [ ] Sub-5.3 Full sweep per AC7 (incl. `check-doc-sync`); any post-shift probe trip diagnosed via the straddle harness, never reflex-reverted
  - [ ] Sub-5.4 Sprint-status → `review`; dev-pass close message includes the deferred-HW-smoke recipe (AC8, STRONG memory)

## Dev Notes

### Why this story exists (context)

ADR 19.5 DR-1 (ACCEPTED 2026-06-04) proved the hang class that forced the 19.2-H5 and 19.3 reverts is **portal-window dictionary aliasing**: a body compiled at/above `$8000` physically lives in the page mapped at compile time; if its cells at ≥ `$8000` are fetched while a foreign bank is mapped (because the body itself ran `BANK!`), the fetch reads the foreign page → `JP $0000` warm boot or opcode-soup hang. Kernel size was never causal — it only moves the dictionary's `$8000` crossing point (knob-equivalence: PASS→HANG transition absolute address invariant at body-start 32696/32697, evidence E4). There is **no trampoline fix to land** — this story ships DR-1's fix proposal verbatim: F1 converts the user-facing silent-corruption act (foreign `BANK!` from window-resident code) into a catchable THROW; F2 makes bank-N>0 bodies page-resident from byte 0 (they then never straddle and never alias once 19.5.2's dispatch enters them with their own page mapped); F3 pins the mechanism's PASS/HANG signature as a regression gate. The dispatch rework itself (option C, RST-$28 self-dispatching stub) is **19.5.2 — do not start it here**; F1/F2 deliberately have zero dependency on the stub contract.

### Draft-time verified citations (PD-2: all re-checked against working tree 2026-06-04)

- `w_BANK_STORE_cf`: `src/banking.asm:149`; precondition `:150..156`; MMU write `OUT (0x72)` `:157..160`; `.abort_bank` THROW idiom `:198..203` (prints "bank?" then `LD BC, THROW_ABORT_QUOTE / JP w_THROW_cf.kernel_entry`)
- DE = IP at DEFCODE entry: `src/inner_interpreter.asm:7`; BANK! already PUSHes DE later for its LDIR (`:169..171` region) — the guard reads D only, no save needed at guard point
- `w_THROW_cf.kernel_entry`: `src/exception.asm:418` (BC = THROW code; non-zero required — `-273` is); kernel-raised-codes comment to extend: `:410..416`
- `throw_desc_table`: `src/exception.asm:826..`; entry format `DW code / DB len / DB "<text>"`, terminator `DW 0`; antforth-extension codes `-258..-272` all have entries (precedent favors Q1=α)
- THROW code allocation: `-257..-272` all taken (`src/constants.asm:154..169`; `-272` = `THROW_ASM_BIT_RANGE`, Story 11.5.6). **Next free = `-273`. The ADR's "-272" guess is superseded — drift caught at draft time per PD-2.**
- COLD clone LDIR: `src/antforth.asm:194..197` (`BANK_TABLE_ENTRY_SIZE * (BANK_TABLE_CAP - 1)` = 6 × 28 = 168); stale H5 comment `:198..213`; `BANK_TABLE_BASE = $D400` `src/constants.asm:17`
- Bank-table triple layout: [here:2][latest:2][wordlist_head:2] per entry (clone-at-COLD contract: `project_bank_table_clone_at_cold` memory + `src/antforth.asm:169..193`)
- probe-18.2-a same-bank `0 BANK!` (must stay green under F1): `tests/banking_tests.fth:1025`; its body compiles past `$8000` (`:995..999` comment)
- Reproducers: `tests/straddle_repro.fth.in` (`@PAD@` knob; markers m1..m5 + `survived`), `tests/straddle_repro_sweep.sh` (K=0 path mutates NO kernel source; `ANCHOR-NOT-FOUND` loud-failure precedent `:44..48`), `tests/layout_fragility_sweep.sh` (kernel-knob variant — sweep diagnostics, not the regression slot)
- ADR: `docs/adr-19-5-cross-bank-dispatch.md` — DR-1 fix proposal (F1/F2/F3), evidence E1–E5 + appendix B (dose-response matrix: pad 5593 PASS / 5594 loses m5 at K=0, here0=27090 — these pads are STALE the moment this story's bytes land; hence AC4's self-calibration requirement)

### F1 implementation sketch (itemised — 21 B)

Insert between the precondition's `JR NC, .abort_bank` and the `LD HL, ACTIVE_PAGES_BASE`:

```asm
        ; --- F1 portal-window guard (ADR 19.5 DR-1): foreign-bank switch
        ;     from window-resident code ($8000..$BFFF IP) THROWs -273
        ;     BEFORE any MMU/state mutation. Same-bank switch stays legal. ---
        LD      A, C                            ; 1 B  target bank
        CP      (IY+UserArea.current_bank)      ; 3 B
        JR      Z, .window_ok                   ; 2 B  same-bank → legal
        LD      A, D                            ; 1 B  caller IP high byte
        CP      $80                             ; 2 B
        JR      C, .window_ok                   ; 2 B  IP < $8000 → legal
        CP      $C0                             ; 2 B
        JR      NC, .window_ok                  ; 2 B  IP ≥ $C000 → legal
        LD      BC, THROW_BANK_FROM_BANKED      ; 3 B
        JP      w_THROW_cf.kernel_entry         ; 3 B
.window_ok:
```

Sum = 21 B (the ADR's "= 20 B" line under-sums its own components by 1 — use 21). BC is clobbered only on the THROW path (fine); A is scratch; DE untouched.

### F2 implementation sketch (itemised — 16 B)

After the clone LDIR (entry stride 6; from entry's byte 1 to next entry's byte 0 is +5):

```asm
        LD      HL, BANK_TABLE_BASE + BANK_TABLE_ENTRY_SIZE  ; 3 B  &bank-table[1].here
        LD      DE, BANK_TABLE_ENTRY_SIZE - 1                ; 3 B  stride 5 after INC
        LD      B, BANK_TABLE_CAP - 1                        ; 2 B  28 entries
.bank_here_init:
        LD      (HL), $00                                    ; 2 B  here.low
        INC     HL                                           ; 1 B
        LD      (HL), $80                                    ; 2 B  here.high → $8000
        ADD     HL, DE                                       ; 1 B
        DJNZ    .bank_here_init                              ; 2 B
```

(H5's reverted attempt measured +17 B empirical — consistent.) Placement note: this runs at COLD only; `BANKS-CLEAR` does not wipe the bank-table (the straddle reproducer's `BANKS-CLEAR … 1 BANK!` sequence works off the COLD-time table), so no re-init hook is needed there — verify with Sub-2.3's consumer grep.

### Q-dispositions (defaults adopted unless Ant overrides at dev-pass start)

- **Q1 — `throw_desc_table` entry for `-273`.** α (default): add `DW -273 / DB 28 / DB "bank switch from banked code"` = **+31 B** — matches the project precedent that every antforth-extension code has a description (uncaught-THROW UX per Story 11.5.4). β: omit — uncaught surface shows bare `THROW #-273`; saves 31 B and keeps the story ≤ ~47 B if epic-envelope pressure matters (epic plan ~+30..+100 B must also absorb 19.5.2's −13..+45 B). The CATCH probe (AC5a) is description-independent either way.
- **Q2 — F3 target shape.** Default: `test-straddle-regression`, K=0 only, self-calibrating pads, PASS + HANG assertions. Optional third assertion (cheap, recommended if Q1 lands): a GUARD configuration (body fully above `$8000` → F1 fires → `-273` surfaced + interpreter survives to `survived`) — turns the regression slot into F1's end-to-end witness as well; if adopted, note the fixture's `1 BANK!` THROW path leaves bank 0 mapped (guard fires pre-mutation), so the fixture's trailing `BANKS-CLEAR` still runs in bank 0.
- **Q3 — probe placement.** Default: AC5 probes appended to `tests/banking_tests.fth` (main suite — its dictionary is already past `$8000` late in the file, satisfying AC5a's precondition naturally) + recipe greps in the `test-repl-banking` Makefile pattern list (`Makefile:88..` pattern-loop precedent). Isolated fixture only if the main-suite placement proves layout-coupled in a way the precondition-SKIP can't absorb.

### Constraints and guardrails

- **19.5.2 scope fence:** no stub-layout, EXECUTE, EXIT_CODE, or trampoline edits in this story. F1/F2/F3 are dispatch-architecture-independent by design (they survive the option-C rework untouched).
- **Layout-shift discipline (AC7):** this story's bytes move the dictionary base. Any banking-probe trip post-edit is diagnosed with the straddle harness (which body straddles, under which mapping), never reflex-reverted. `feedback_iz_cpm_trampoline_fragility` is SUPERSEDED — do not act on its "emulator/trampoline" framing.
- **B.2 / PD-2:** every byte figure above is a draft-time per-component itemisation; re-itemise as-built. Two ADR figures were corrected at draft time (`-272`→`-273`; 20→21 B) — treat the ADR's other transcribed figures (e.g. appendix pad values) as stale-able and re-derive where load-bearing.
- **REPL probe hygiene:** lines ≤ 128 chars (TIB_SIZE); colon-body wrappers with run-time `result=` emission, not top-level IF/ELSE (Story 17.5.2 lesson); `0 BANK!` before `BANKS-CLEAR` (`banking.asm:454` trap). No disk/a/ files this story (no HW pass) — if any fixture later migrates to disk/a/ for 19.5.4, it must be 0x1A-terminated (`feedback_cpm_0x1a_eof_marker`).
- **Solo-dev calibration (`feedback_ceremony_diminishing_returns`):** F3 is a deliberate, permanent regression slot (it guards a proven corruption mechanism) — but keep it ONE target with two-three assertions, not a parameterised sweep framework.

### Previous-story intelligence (19.5.0, status review)

- The ADR spike measured everything on the live kernel rather than prototypes — same spirit here: the 21 B/16 B sketches are drafts; the as-built opcode sum is the figure of record.
- 19.5.0's sweep drivers back up + restore `src/banking.asm` and rebuild pristine on exit; F3's K=0 path avoids even that (no source mutation) — preserve that property so the regression target is safe in any working tree.
- Working tree at draft time: 19.5.0 close-out artifacts UNCOMMITTED (ADR, 3 fixtures, story/sprint/epics) + an uncommitted `src/file_access.asm` 19.4-CR-follow-up. Baseline hygiene at dev-pass start per the pre-edit task.
- Recent commits for patterns: `94c2ba0` (19.4 close + CR fixes, v3.0.3), `010e8f2` (19.3.1), `c97f87d` (19.3), `92b725c` (19.2 CR), `3b66fed` (19.1).

### Project Structure Notes

- Kernel edits: `src/banking.asm` (F1), `src/constants.asm` (EQU), `src/exception.asm` (desc table + comment), `src/antforth.asm` (F2 + comment rewrite). Tests: `tests/banking_tests.fth` (probes), `Makefile` (F3 target + probe greps). Docs: `docs/throw-codes.md`, `docs/antforth-banking-redesign.md`.
- No new isolated `.fth` suite expected (Q3 default); no disk/a/ artifacts this story.

### References

- ADR (both DRs + fix proposal + evidence): `docs/adr-19-5-cross-bank-dispatch.md` (DR-1 fix proposal = this story's spec; status Accepted 2026-06-04)
- Epic 19.5 stories block: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:885..902`
- Story 19.5.0 artifact (evidence summary, reproducer usage): `_bmad-output/implementation-artifacts/19-5-0-adr-spike-trampoline-layout-fragility-root-cause-dtc-dispatch-architecture.md`
- Kernel sites: listed under "Draft-time verified citations" above
- Memories: `feedback_no_accept_disposition_for_bugs` (THROW, not document-the-boundary) · `feedback_kernel_ldir_estimate_overshoot` (×1.25) · `project_bank_table_clone_at_cold` · `feedback_phase4_probe_bank_switch_limitation` · `feedback_post_hw_smoke_steps_at_review` (**STRONG** — recipe in close message) · `feedback_iz_cpm_trampoline_fragility` (SUPERSEDED — context only)

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

## Change Log

- 2026-06-04 (create-story): Story drafted from ADR 19.5 DR-1's fix proposal (F1 window guard + F2 H5 re-land + F3 regression slot). Sprint-status rows renamed per the ADR's flagged disposition: `19-5-1-trampoline-stabilization-layout-fragility-fix` → `19-5-1-portal-aliasing-guards-bank-n-here-cold-init-h5-reproducer-regression-slot`; `19-5-3-compiled-body-verification-bank-n-here-cold-init-h5` → `19-5-3-compiled-body-verification-banked-catch-variant`. PD-2 draft-time corrections: THROW code is `-273` (ADR said "-272", already taken by `THROW_ASM_BIT_RANGE` since Story 11.5.6); F1 itemisation re-sums to 21 B (ADR said 20). Draft-time working-tree caveat recorded (uncommitted 19.5.0 artifacts + `src/file_access.asm` follow-up — baseline re-measure mandatory at dev-pass start). Status: ready-for-dev.
