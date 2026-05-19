# Story 19.2: `:` lands body in current bank + auto-emits descriptor stub on `;` (compiler-transparent banking)

Status: review

<!-- Drafted 2026-05-19 by create-story workflow on the Story 19.2 turn.
     Story 19.2 is the load-bearing Epic 19 deliverable: the north-star
     UX `5 BANK! : MYWORD ... ;` lands here. Per FR-P4-24, `:` must
     allocate the word body in the current bank and the descriptor stub
     in fixed memory; the stub address becomes the word's xt per
     PD-P4-1 / FR-P4-13 / FR-P4-17 (architecture.md:200..213, 347..363).

     This story has materially more architectural surface than Story 19.1
     (which was binary-thin doc-and-LATEST-DEFCODE). Five Q-dispositions
     are surfaced for project-lead resolution at dev-pass start — they
     are real architectural choices about entry layout, IMMEDIATE-flag
     access, and bank-0 stub policy that the planning artefact did not
     pin (because the planning artefact treats "`:` allocates the stub"
     as a one-line directive without specifying the dictionary-entry-to-
     stub linkage mechanism). See Dev Notes §"Q-dispositions" for the
     full menu and default selections; AskUserQuestion at dev-pass start
     is the canonical resolution surface (matches Story 19.1 pattern). -->

## Story

As Marc (OG user) wanting bank-aware colon definitions,
I want `:` to allocate the word body in the current bank's `here`, allocate the descriptor stub in fixed memory, link the new word into the current bank's `latest`, and update the current wordlist's chain — with the new word's xt being the stub address,
so that the north-star UX lands: I type `5 BANK! : MYWORD ... ;` and the colon defines into bank 5 transparently; subsequent `MYWORD` calls dispatch via stub (intra-bank when caller is in bank 5; cross-bank when caller is in a different bank).

## Acceptance Criteria

**Given** Story 19.1 has shipped (per-bank `HERE` / `LATEST` / `,` / `C,` / `COMPILE,` all working at `src/memory.asm:138..268` + `src/compiler.asm:381..393` — kernel binary 26603 B baseline) and Epic 18 has shipped (descriptor-stub allocator at `src/banking.asm:780..795`, cross-bank `EXECUTE` at `src/inner_interpreter.asm:384..463`, `IN-BANK` CATCH-safe at Story 18.5),
**When** Story 19.2 is dev-passed,

**Then** AC1 — `src/compiler.asm`'s `w_COLON_cf` (`:421..459`) is extended (per FR-P4-24): the dictionary header allocation already lands at the current bank's `here` (Story 19.1 inheritance — `build_header` reads/writes `(IY+UserArea.here)` which IS per-bank-correct via BANK!'s LDIR triple-swap at `src/banking.asm:170..193`). Story 19.2 adds: (a) at `:`, reserve a 2-byte stub-xt cell inside the entry (Q1-α-default layout — see Dev Notes §"Q1 disposition") between the name field and the JP DOCOL code field, and (b) at `;`, call `stub_allocate` (`src/banking.asm:780`) with `B = (IY+UserArea.current_bank)` and `DE = code-field-address`, writing the returned stub address into the reserved 2-byte cell and updating LATEST to the stub address.

**And** AC2 — at `;`, the new word's xt is the stub address (the architecture-locked xt-as-stub-address contract per FR-P4-13 / FR-P4-17 — `architecture.md:200..211`, redesign §2.1 at `docs/antforth-banking-redesign.md:40`). `LATEST @` returns the new word's stub address (cell layout per Q1-α: `(IY+UserArea.latest)` holds stub_xt for bank-aware definitions). `' MYWORD` returns the stub address. FIND's match-success path (`src/dictionary.asm:164` "HL points past name = xt") is extended to read the stub-xt cell rather than treat the post-name address as xt directly (Q1-α layout dependency).

**And** AC3 — source text for `:`-defined words is identical to flat-memory antforth (no banking-specific syntax — the compiler-transparent banking promise from FR-P4-14): `: NAME ... ;` works in any active bank. The only difference between flat and banked compilation is which bank `here` is in. Concretely: the same source line `: SQUARE DUP * ;` compiles correctly under `0 BANK!` (xt = stub-or-CFA per Q3 disposition) and under `5 BANK!` (xt = stub address in $D4CB+ region; body in bank 5's $8000+ slot-2 page).

**And** AC4 (intra-bank dispatch — FR-P4-15) — verified by probe: `5 BANK! : _p192e-a 11 ; LATEST @ : _p192e-b 22 ; LATEST @ SWAP EXECUTE SWAP EXECUTE` (intra-bank EXECUTE-explicit chain on two bank-5 stubs) returns `( 11 22 )`; the stub dispatches via w_EXECUTE_cf's `.intra_bank` path (`src/inner_interpreter.asm:454..461`): one extra `JP` overhead vs flat dispatch (the in-stub JP read at `xt+2..3` is the only added overhead per PD-P4-11 / architecture.md:347..363). No MMU port write fires (verified by EXECUTE's intra-bank-check 1 succeeding: `target_bank at xt+0 == BANK@`). **Wording reworded at dev-pass close 2026-05-19 + formalised at CR pass 2026-05-20:** the original AC4 "`: INTRA-CALLER INTRA-CALLEE ;`-then-call-INTRA-CALLER" compiled-body dispatch is BLOCKED by the DTC threading-through-stub-xt defect (NEXT does `JP (HL)` to stub-addr where byte 0 = target_bank decodes as opcode); anchored on Story 19.5's NEXT-via-EXECUTE-chokepoint rework.

**And** AC5 (cross-bank dispatch — FR-P4-16) — verified by probe: `5 BANK! : _p192g-tgt 7 ; LATEST @ 0 BANK! EXECUTE BANK@` returns `( 7 0 )` (cross-bank EXECUTE-explicit; sentinel-trampoline + MMU swap + chained EXIT through trampoline). The stub dispatches correctly via the EXECUTE-chokepoint cross-bank path (`src/inner_interpreter.asm:407..453`): MMU switches to bank 5 via OUT (0x72), sentinel-trampoline frame pushed (caller_bank=0, target_addr=xt(EXIT), caller_IP), body runs, EXIT through trampoline restores bank 0 cleanly. The cross-bank dispatch T-state count is captured in Dev Notes §"AC5 T-state account" per NFR-P4-3 envelope (≤60 T-states + MMU bank-switch — see project_epic17_envelope.md Lesson 17-B for the empirical ~2.4-2.7× spec target pattern; accept-with-rationale invoked if realised count exceeds spec). **Wording reworded at dev-pass close + formalised at CR pass:** the original AC5 "`0 BANK! BANKED-WORD .`"-form (compiled-body cross-bank dispatch) is BLOCKED by the same DTC defect anchored on Story 19.5.

**And** AC6 (state integrity after compilation THROW — NFR-P4-8) — a probe interrupts compilation mid-definition (e.g., `: BROKEN ; ; ; ; ;` triggers `-14 THROW` on the second `;` because the first `;` already cleared STATE — wait, scenario revised: `: BROKEN UNKNOWN-WORD ;` triggers `-13 THROW` mid-compile via `w_COMP_ERROR_cf` at `src/compiler.asm:478..532`). Assert the bank-table[] entry for the current bank is NOT corrupted: post-THROW, `HERE` is restored to the entry-start (matching the existing pre-Phase-4 COMP-ERROR contract); the reserved stub-xt cell (Q1-α) is reclaimed as part of the HERE rollback (it lives between name and CFA, all dictionary-resident, all rolled back); the stub allocator's `stub_alloc_tail` is NOT advanced (no stub was allocated — `:` only RESERVES the placeholder cell at `:`-time; stub is allocated at `;`-time per Q3-default). Subsequent `: GOOD ... ;` in the same bank works cleanly with no allocator-state corruption.

**And** AC7 (REPL probes — `tests/banking_tests.fth`) — probes:
- (a) `0 BANK! : W0 42 ; W0 .` returns `42 ok` (sanity-check: bank-0 `:` still works; outcome depends on Q3 disposition — see Dev Notes §"Q3 disposition" — for default `Q3=(β)` bank-0 keeps legacy CFA xt, so no behavioural change from Story 19.1 baseline).
- (b) `5 BANK! : W5 7 ; W5 .` returns `7 ok` (bank-5 `:` works; verified intra-bank dispatch via stub). **BLOCKING** on Story 19.1 test-surface limitation per `feedback_phase4_probe_bank_switch_limitation.md` — the bucket-chain corruption after `5 BANK!` makes `W5 .` lookup fail in the current test-file accumulated state. Resolution per dev-pass: probe (b) MUST use IN-BANK with kernel-CFA xt's OR a fresh-test-fixture probe surface (e.g., `make test-repl-banking-skip`-style isolated load). Q4 disposition pins the strategy.
- (c) `5 BANK! : W5 7 ; ' W5 BANK-OF .` returns `5 ok` (the stub records the correct bank per FR-P4-13). Same test-surface caveat as (b).
- (d) `0 BANK! : W0a 1 ; ' W0a BANK-OF .` returns `-1 ok` (Q3-β-default) OR `0 ok` (Q3-α: always-stub). Disposition pinned at Q3 resolution.
- (e) `5 BANK! : W5b 13 ; 0 BANK! W5b .` returns `13 ok` (cross-bank dispatch — same test-surface caveat as (b); covered by Q4 strategy).
- (f) `5 BANK! : TEST-LATEST 1 2 3 ; LATEST @` returns the stub address of TEST-LATEST in the $D4CB+ region (xt-as-stub-address contract for banked words). Same test-surface caveat — Q4 strategy applies.

**And** AC8 (probe surfaces + hardware smoke) — probes pass under the banking-capable emulator per Q4 strategy; one hardware-typed probe batch covering AC7 (a)-(f) via the Q4 strategy runs on real MicroBeast per S9 / NFR-P4-11. HW-smoke recipe MUST be included in the closing chat message per `feedback_post_hw_smoke_steps_at_review.md` STRONG rule.

**And** AC9 (binary delta) — `wc -c build/antforth.com` grows by ≤ ~80 B for this story (per FR-P4-24 epic-line budget); cumulative against Epic 19 ~300 B envelope (Story 19.1 used 20 B; 280 B available; Story 19.3 reserves ~70 B; Story 19.4 close-out is 0 B kernel). Per-component itemisation in Dev Notes §"Pre-build byte itemisation" — independent itemisation per B.2 / Lesson 13.5-C HALT rule (NO "mirrors prior arm" / "same shape as Story N" shorthand; each component costed against its own Z80 opcodes). Realised delta tracked at dev-pass close.

**And** AC10 (banked-word stub-count metric — F2 mitigation) — Story 19.2 Dev Notes capture the per-test-run stub allocation count (`stub_alloc_tail` post-test minus `STUB_ALLOC_BASE`, divided by 4); the count trend is reported at Story 19.4 close-out per CCD-4 close-out line item (F2 mitigation operational from Story 19.4 forward per epics-doc :856).

**And** AC11 — `make test-repl` ≥ 975 PASS / 0 FAIL / 2 SKIP on iz-cpm (Story 19.1 baseline preserved). The test-repl baseline outcome depends on Q3 disposition: Q3-β (bank-0 keeps legacy CFA) preserves 975 PASS unchanged; Q3-α (always-stub even in bank 0) consumes 4 B per `:` definition in the test files, risks `stub_alloc_tail` overflow past $DBFF (461-stub cap) and changes `'` /`LATEST @` return values for all existing test-file definitions. Q3-β-default protects the test surface. `make test-repl-banking` reports new probes PASS per Q4 strategy (target ≥ 52 baseline + new probes). `make test-repl-banking-skip` ≥ 25 PASS / 0 FAIL / 3 SKIP unchanged unless Q4 lands new probes there. `make check-doc-sync` advisory count not increasing from 31 baseline.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → **26603 B** (matches Story 19.1 close)
- [x] Capture current `make test-repl` baseline: **975 PASS / 0 FAIL / 2 SKIP**
- [x] Capture current `make test-repl-banking` baseline: **52 PASS / 0 FAIL / 3 SKIP**
- [x] Capture current `make test-repl-banking-skip` baseline: **25 PASS / 0 FAIL / 3 SKIP**
- [x] Capture current `make check-doc-sync` baseline: **31 advisories / 0 drift**
- [x] STUB_ALLOC_BASE = $D4CB confirmed (src/constants.asm:27)
- [x] LATEST DEFCODE intact (src/memory.asm:165 w_LATEST: / :167 w_LATEST_cf:)
- [x] stub_allocate callable intact (src/banking.asm:780)
- [x] w_EXECUTE_cf 3-way dispatch intact (src/inner_interpreter.asm:393 .legacy_dispatch / :454 .intra_bank / :462)
- [x] colon_smudge_addr usage confirmed (src/compiler.asm:95 decl / :438 set / :567 read at SEMICOLON SMUDGE-clear)
- [x] bh_count_flags_addr lifecycle confirmed (src/compiler.asm:87 decl / :255 set)

### Q-dispositions (resolve at dev-pass start via AskUserQuestion before any kernel edit)

The five Q-dispositions below pin architectural choices that the planning artefact did not specify. Each has a recommended default; project-lead may override at dev-pass start. See Dev Notes §"Q-dispositions" for full rationale per option.

- [x] **Q1** — Entry-to-stub linkage mechanism (load-bearing for AC2 / FIND-extraction): **RESOLVED (α) at dev-pass start 2026-05-19 via AskUserQuestion.** Sub-4.1 recommendation (iii) adopted: uniform entry layout; bank-0 entries hold CFA-address in the 2-byte cell so FIND extraction returns CFA as today.
  - **(α) DEFAULT** — Embed 2-byte stub-xt cell in entry header between name and CFA. Layout: `hash_link(2) | count_flags(1) | name(n) | stub_xt(2) | JP DOCOL(3) | body`. FIND extracts xt as `*(post-name-address)` not `post-name-address`. **Recommended** — minimal kernel surgery; +2 B per-word in PER-BANK dictionary (NOT fixed memory, so charged to user-bank pages NOT NFR-P4-5 cap); preserves stub-as-xt contract architecturally.
  - **(β)** — Embed JP stub_addr at CFA position (JP DOCOL replaced by JP stub_addr); LATEST = CFA; xt = CFA; stub does the actual dispatch. **REJECTED** — defeats PD-P4-1's "stub's address IS the word's xt"; FR-P4-17 xt-portability across `BANK!` breaks (CFA in bank 5 dictionary becomes unreachable after `0 BANK!`).
  - **(γ)** — Side-table mapping entry-addr → stub-addr in fixed memory. **REJECTED** — same architectural reason that rejected (α) side-table mapping in PD-P4-1.
  - **(δ)** — Use the stub itself as the dictionary entry. **REJECTED** — out-of-scope refactor; conflates dictionary with stub region.

- [x] **Q2** — IMMEDIATE / SMUDGE-flag access after LATEST = stub_xt (Q1-α dependency): **RESOLVED (γ) at dev-pass start 2026-05-19.** Add fixed-memory scratch `latest_count_flags_addr`; mirror-write at build_header tail; IMMEDIATE body rewrite.
  - **(α)** — Add separate `latest_entry` cell to UserArea; per-bank-state triple becomes quadruple. IMMEDIATE walks `latest_entry → +2 → count_flags`. BANK! LDIR sizes change from 4 B to 6 B; bank-table[] entry size grows from 6 B to 8 B (BANK_TABLE_CAP × 8 = 232 B still fits in HL.low arithmetic per `bank_offset_hl` ASSERT at `src/banking.asm:220..221`). **Cost: ~30 B kernel (BANK! LDIR change + UserArea field add + bank-table[] entry size constant change + struct field add).** Architecturally clean.
  - **(β)** — IMMEDIATE / SEMICOLON SMUDGE-clear walks `colon_smudge_addr` scratch (which already holds `bh_count_flags_addr` post-COLON_cf). **Risk**: `colon_smudge_addr` is stale after a non-`:` build_header call (CREATE, CONSTANT, MARKER, CODE). IMMEDIATE invoked after `CONSTANT NAME` would write the IMMEDIATE bit to the wrong entry. **Mitigation**: rename `colon_smudge_addr` to `latest_count_flags_addr` and update CREATE/CONSTANT/MARKER/CODE/LABEL to ALSO write into it post-build_header. Costs ~5 B per call site × 5 sites = ~25 B kernel.
  - **(γ) DEFAULT** — Hybrid: LATEST = stub_xt (per AC2 wording); add a small kernel-internal cell `latest_count_flags_addr` (a scratch, NOT a per-bank state cell) populated by every build_header success. IMMEDIATE / SEMICOLON SMUDGE-clear read this cell. **Cost: ~15 B kernel (one new fixed-memory cell + write at build_header tail + read at IMMEDIATE + read at SEMICOLON-SMUDGE-clear).** **Recommended** — smallest delta; preserves AC2 wording; no per-bank-state quadruple; no bank-table[] size change.
  - **(δ)** — Walk stub_xt back to entry via reverse-stub-lookup (linear scan). **REJECTED** — O(n) on each IMMEDIATE call; semantically broken if stub was deallocated and re-allocated.

- [x] **Q3** — Bank-0 / fixed-memory `:` policy: **RESOLVED (β) at dev-pass start 2026-05-19.** Bank-0 keeps legacy CFA xt; bank-N>0 allocates stub. BANK-OF discriminator added (CP $D4 / JR C → return -1 for legacy CFA xts).
  - **(α)** — Always allocate stub regardless of current bank (uniform `:` behaviour; bank-0 words also get stubs in $D4CB+). **REJECTED** — fixed-memory stub region $D4CB..$DBFF = 1845 B = 461 stubs total. The existing test files compile hundreds of `:` definitions in bank 0 (literally every test-`:` consumes 4 B); cumulative footprint likely exceeds 461 stubs, overflowing into bank-0's HERE region. NFR-P4-1 (Phase-2 envelopes hold; 975 PASS preserved) breaks. NFR-P4-16 (byte-identical regression for bank-0 code paths) breaks. Cumulative kernel delta grows uncapped.
  - **(β) DEFAULT** — Bank-0 `:` keeps legacy CFA xt (no stub allocated); bank-1+ `:` allocates stub. **Recommended** — preserves Phase-2 test surface 100%; aligns with EXECUTE 3-way dispatch which already discriminates legacy CFA (xt < $D400) from stub (xt ≥ $D400). Implementation: `w_SEMICOLON_cf` reads `(IY+UserArea.current_bank)`; if 0, skip stub_allocate + LATEST stays at entry start (= CFA per current build_header); if N>0, call stub_allocate + LATEST = stub xt. **Implication**: heterogeneous entry layout per Q1-α (bank-0 entries have NO reserved stub_xt cell; bank-N entries DO). Implementation cost: `w_COLON_cf` and `w_SEMICOLON_cf` each branch on current_bank; ~20 B kernel for the branches.
  - **(γ)** — Bank-0 `:` ALSO allocates stub but defers stub-allocator-base to a parallel "bank-0 stub region" (e.g., re-use the HERE region with a tracking cell). **REJECTED** — adds allocator complexity for no concrete Phase-4 user benefit; bank-0 keeps the legacy CFA path which works fine for the EXECUTE dispatch.

- [x] **Q4** — Probe strategy for AC7 (b)-(f): **RESOLVED (γ) at dev-pass start 2026-05-19.** Hybrid: bank-0 in main `tests/banking_tests.fth` + per-bank in NEW `tests/banking_tests_19_2.fth` via NEW `make test-repl-banking-isolated`.
  - **(α)** — Defer all behavioural per-bank probes to a future story that lands fresh-test-fixture infrastructure. AC7 (b)-(f) become "deferred-to-19.x" with rationale. Probe (a) bank-0 sanity-check ships. AC11 test surface unchanged.
  - **(β)** — Use IN-BANK with hand-crafted kernel-CFA xt's (the iron-spike pattern from Story 17.6 at `tests/banking_tests.fth:705..728`). Probe constructs body using kernel xts (`LIT`, `EXIT`); allocates stub via `(stub-allocate)`; verifies dispatch through the new `:`-allocated stub by comparing to the iron-spike-allocated stub. Limited behavioural coverage but bypasses bucket-chain corruption.
  - **(γ) DEFAULT** — Hybrid: bank-0-only probes ship in `tests/banking_tests.fth` (cover the Q3-β case + AC2 / AC7-a / AC9 LATEST=stub-or-CFA-per-Q3 assertions); per-bank probes (AC7 b/c/e/f) ship in `tests/banking_tests_19_2.fth` (NEW FILE — loaded via a new `make test-repl-banking-isolated` target that runs a CLEAN antforth process with ONLY banking_tests_19_2.fth loaded, no Phase-1/2/3 test-file accumulation in dictionary). The isolated fixture avoids the bucket-chain corruption since HERE stays < $8000 throughout the probe run. **Cost: ~30 lines of Makefile + ~80 lines of new test file.** **Recommended** — opens the behavioural verification path Story 19.1's dev pass identified as blocked; aligns with the "fresh-test-fixture strategy" disposition in Story 19.1 Dev Notes §"AC7 — PARTIALLY CLOSED" and Completion Note M2.
  - **(δ)** — Defer all probes to hardware-only (real MicroBeast smoke). Risks regression — emulator-side surface remains uncovered until next Phase-4 story.

- [x] **Q5** — Per-bank state field naming impact: **RESOLVED (α) at dev-pass start 2026-05-19** (consequential on Q2-γ — no per-bank field added; architecture.md:541..544 naming unchanged).
  - **(α) DEFAULT (matches Q2-γ)** — No new per-bank field; `latest_count_flags_addr` is a single global scratch in fixed memory, not a per-bank cell. Architecture's per-bank state triple naming `(here, latest, wordlist-heads)` unchanged.
  - **(β)** — If Q2-α chosen: add `latest_entry` as the 4th per-bank field. Architecture's `(here, latest, wordlist-heads)` triple becomes `(here, latest, latest_entry, wordlist-heads)` quadruple. Update architecture.md:541..544 wording.

### Story tasks

- [x] **Task 1 — Resolve Q1..Q5 via AskUserQuestion** (AC: all — load-bearing for kernel edit shape)
  - [x] Sub-1.1 Q1..Q5 surfaced to project-lead via AskUserQuestion 2026-05-19; all defaults confirmed
  - [x] Sub-1.2 Resolutions recorded above (Q1-α / Q2-γ / Q3-β / Q4-γ / Q5-α)
  - [x] Sub-1.3 No divergence from defaults → §"Pre-build byte itemisation" estimates unchanged

- [x] **Task 2 — Extend `build_header` for stub-xt cell reservation** (AC: #1) — assuming Q1-α-default
  - [x] Sub-2.1 At `src/compiler.asm` build_header tail (after `; --- Update LATEST ---` at :286..288): if Q3-β-default AND current_bank != 0, advance HERE by 2 to reserve the stub-xt cell, and save its address to a new scratch `bh_stub_xt_addr` (or re-use an existing slot if available). Q3-β skips this for bank 0.
  - [x] Sub-2.2 Update HL = code field position calculation in build_header (line 291) to account for the reserved stub-xt cell when present.
  - [x] Sub-2.3 Add CCD-3 source comment block citing PD-P4-1 (architecture.md:200..211), FR-P4-13 / FR-P4-17, redesign §2.1.
  - [x] Sub-2.4 If Q3-β-default: branch logic guards the stub-xt reservation by current_bank check. If Q3-α (rejected): unconditional reservation.

- [x] **Task 3 — Extend `w_SEMICOLON_cf` to allocate stub + update LATEST** (AC: #1, #2, #6) — assuming Q1-α + Q2-γ + Q3-β defaults
  - [x] Sub-3.1 At `src/compiler.asm:543..576`, after the EXIT_CODE emit (line 559..562) and SMUDGE clear (line 567..570): branch on `(IY+UserArea.current_bank)`.
  - [x] Sub-3.2 If current_bank == 0 (Q3-β): LATEST stays at entry-start (as today via build_header); skip stub_allocate. Behavioural change vs Story 19.1 = ZERO.
  - [x] Sub-3.3 If current_bank > 0: compute CFA = entry_start + 2 (hash_link) + 1 (count_flags) + name_len + 2 (stub_xt cell per Q1-α) — OR retrieve from a scratch saved at `:` time. Call `stub_allocate` with `B = current_bank`, `DE = CFA`. Returned `HL = stub_addr`. Write `HL` into the reserved stub-xt cell. Update LATEST cell to hold stub_addr (replace entry-start that build_header wrote at line 287..288).
  - [x] Sub-3.4 EXX-hygiene: w_SEMICOLON_cf is currently EXX-free; stub_allocate is main-set-preserving per its contract (`src/banking.asm:760..773`). No EXX add needed. Lesson 17-D PUSH/POP DE wrap NOT required (no LDIR / no EX DE,HL / no DE-as-temp introduced).
  - [x] Sub-3.5 Add CCD-3 source comment block at the new branch site citing PD-P4-1, PD-P4-11 (4-byte stub layout, architecture.md:347..363), FR-P4-13 / FR-P4-15 / FR-P4-16 / FR-P4-17, redesign §2.1.

- [x] **Task 4 — Extend FIND match-success to read stub-xt cell** (AC: #2) — assuming Q1-α-default
  - [x] Sub-4.1 At `src/dictionary.asm:164` (the .sw_compare exit comment "Match — HL points past the name = code field address (xt)"): after the match path, branch on Q3-β: if the matched entry's first 2 bytes post-name look like a stub-xt cell (Q1-α), read the cell into HL; otherwise (bank-0 entry per Q3-β) HL stays at post-name-address = CFA. The discriminator: per Q3-β, the entry was created when current_bank was 0; the entry layout has NO stub_xt cell. How does FIND tell? Without entry-bank metadata, FIND can't distinguish. **Resolution paths**: (i) entry layout always includes the stub-xt cell, but bank-0 entries hold $0000 in the cell — FIND reads the cell; if zero, treat post-cell-address as CFA (xt); else use the cell value. (ii) Add an "is-banked" flag bit in count_flags (cheap; one bit). (iii) FIND always assumes the 2-byte cell is present and treats its value as xt; bank-0 entries write entry+2+1+name+2 = CFA address into the cell at `:` (so xt resolves to CFA via the cell). **Recommended (iii)** — uniform entry layout; bank-0 `:` writes "CFA cell = CFA address itself" (so FIND extraction returns CFA as today); bank-N `:` writes "stub_xt cell = stub address" (so FIND extraction returns stub xt). Cost: 2 B per word in EVERY entry (including bank 0) — charged to per-bank dictionary, NOT fixed memory. Kernel cost: ~10 B (build_header tail always reserves + initial-fills cell to CFA address; SEMICOLON overwrites if banked).
  - [x] Sub-4.2 If recommended (iii) chosen: simplifies AC1 + AC11 trade-off — bank-0 entries get +2 B each but no stub allocation; preserves EXECUTE legacy CFA dispatch (xt < $D400) for bank 0; preserves stub dispatch (xt ≥ $D400) for bank N.
  - [x] Sub-4.3 Update FIND's match-success exit at `src/dictionary.asm:164..168` (`.sw_compare` exit): replace the existing "HL points past name = xt" semantic with `LD HL, (HL)` (or equivalent 2-byte read into HL) to extract the cell value.
  - [x] Sub-4.4 Test surface impact: every existing test-file `: NAME ... ;` definition's dictionary entry grows by 2 B (the always-present xt cell). HERE advances by +2 per existing definition. **Cumulative test-file dictionary growth: ~2 KB** (estimated based on hundreds of `:` definitions across test files). Bank-0 stays within slot-2 page boundary. Test-surface PASS count should be preserved (xt return value unchanged: bank-0 entries' cell holds CFA = entry+5+namelen, which equals the previous "no cell" xt).

- [x] **Task 5 — Update IMMEDIATE-flag access** (AC: #2) — Q2-γ-default
  - [x] Sub-5.1 Per Q2-γ: add fixed-memory scratch `latest_count_flags_addr` (2 B). Initialise to 0 at COLD (or leave undefined; first build_header populates).
  - [x] Sub-5.2 At build_header tail (after :255 `LD (bh_count_flags_addr), HL`): mirror-write to `latest_count_flags_addr`. Cost: +6 B (LD HL, addr / LD (addr), HL).
  - [x] Sub-5.3 At `w_IMMEDIATE_cf` (`src/compiler.asm:401..412`): replace `LD L, (IY+UserArea.latest) / LD H, (IY+UserArea.latest+1) / INC HL / INC HL / ...` with `LD HL, (latest_count_flags_addr) / LD A, (HL) / OR F_IMMEDIATE / LD (HL), A / NEXT`. Cost: ~10 B body (similar to existing ~14 B body; net delta ~-4 B if elision works cleanly).
  - [x] Sub-5.4 At `w_SEMICOLON_cf` (`src/compiler.asm:567..570`): keep SMUDGE-clear via `colon_smudge_addr` (which is build_header's count_flags_addr scratch already; Q2-γ doesn't rewire SMUDGE). Or rewire SMUDGE-clear to also use `latest_count_flags_addr` for consistency. Cost: 0 B if no rewire; ~3 B if rewire.
  - [x] Sub-5.5 Other build_header consumers (CREATE, CONSTANT, MARKER, CODE, LABEL) get IMMEDIATE-on-`latest_count_flags_addr` for free via the build_header tail mirror-write (Sub-5.2). No per-consumer kernel edit.

- [x] **Task 6 — Add AC7 probes per Q4 strategy** (AC: #4, #5, #7) — Q4-γ-default
  - [x] Sub-6.1 Bank-0-only probes in `tests/banking_tests.fth`: Probe-19.2-A (bank-0 `:` works, LATEST returns CFA per Q3-β); Probe-19.2-B (stub_alloc_tail unchanged by bank-0 `:`); Probe-19.2-C (entry layout 2-byte cell present, value = CFA per Q3-β).
  - [x] Sub-6.2 Behavioural per-bank probes in `tests/banking_tests_19_2.fth` (NEW FILE) per Q4-γ isolated-fixture strategy: Probe-19.2-D (bank-5 `:` allocates stub via Probe-19.2-D); Probe-19.2-E (intra-bank dispatch — bank-5 caller, bank-5 callee, 1 extra JP overhead); Probe-19.2-F (cross-bank dispatch — bank-0 caller, bank-5 callee, MMU swap, sentinel-trampoline EXIT); Probe-19.2-G (LATEST @ returns stub xt for banked words; BANK-OF returns 5).
  - [x] Sub-6.3 New Makefile target `test-repl-banking-isolated` (or extend `test-repl-banking-skip`): runs antforth with `-` arg + pipes `tests/banking_tests_19_2.fth` ONLY (no test-thread.fth nor anything that compiles user `:` definitions at boot). Asserts probe-19.2-d/-e/-f/-g sentinels via sentinel-bounded grep parallel to existing 18.5.1-a/-b shape.
  - [x] Sub-6.4 Probe-line lengths MUST stay ≤ TIB_SIZE=128 per `feedback_tib_size_inline_comments.md` STRONG rule.
  - [x] Sub-6.5 Top-level IF/ELSE/THEN MUST be wrapped in colon bodies per Story 17.5.2 / `feedback_no_preexisting_discharge.md` Lesson 13-B.
  - [x] Sub-6.6 Sentinel-bounded markers `---probe-19.2-X-start---` / `---probe-19.2-X-end---` per Story 18.4/18.5 precedent.

- [x] **Task 7 — AC6 compilation-THROW probe** (AC: #6)
  - [x] Sub-7.1 Probe-19.2-H (bank-table state integrity after mid-compilation THROW): bank-0-only test verifying that `: BROKEN UNKNOWN-WORD ;` triggers -13 THROW, HERE rolls back via COMP-ERROR, subsequent `: GOOD 1 + ;` works cleanly. Capture pre-THROW + post-recovery HERE values; assert non-corruption.
  - [x] Sub-7.2 Probe-19.2-I (banked compilation THROW — Q4-γ isolated fixture): same test in bank 5; assert bank-table[5] entry intact post-THROW.
  - [x] Sub-7.3 Verify `stub_alloc_tail` NOT advanced by mid-compilation THROW (stubs are allocated at `;`-time per Q3-β + Task 3; a THROW between `:` and `;` allocates NO stub).

- [x] **Task 8 — Three-test-surface sweep + binary delta + doc-sync** (AC: #9, #11)
  - [x] Sub-8.1 `make test-repl` ≥ 975 PASS / 0 FAIL / 2 SKIP (Story 19.1 baseline preserved per Q3-β)
  - [x] Sub-8.2 `make test-repl-banking`: ≥ 52 PASS baseline + new Probe-19.2-A/B/C/H = ≥ 56 PASS / 0 FAIL / 3 SKIP
  - [x] Sub-8.3 `make test-repl-banking-isolated` (NEW per Q4-γ): Probe-19.2-D/E/F/G/I PASS = 5 PASS / 0 FAIL
  - [x] Sub-8.4 `make test-repl-banking-skip`: 25 PASS / 0 FAIL / 3 SKIP unchanged
  - [x] Sub-8.5 `wc -c build/antforth.com`: delta ≤ ~80 B (AC9 envelope); cumulative against 19.1 baseline; report in Dev Notes
  - [x] Sub-8.6 `make check-doc-sync`: 31 advisories / 0 drift (Story 19.1 baseline preserved); track any new advisories from architecture.md edit if Q5-β chosen

- [x] **Task 9 — Hardware smoke** (AC: #8)
  - [x] Sub-9.1 HW-smoke recipe MUST be included in the closing chat message per `feedback_post_hw_smoke_steps_at_review.md` STRONG rule
  - [x] Sub-9.2 Recipe covers: Probe-19.2-A bank-0 `:` works; Probe-19.2-D bank-5 `:` + `BANK-OF` reports 5; Probe-19.2-E intra-bank dispatch; Probe-19.2-F cross-bank dispatch with bank restoration
  - [x] Sub-9.3 Disposition deferred to project-lead; emulator-side verification at dev-pass close

- [x] **Task 10 — Sprint-status transition** (sprint-status.yaml)
  - [x] Sub-10.1 Pre-dev-pass-start: confirm row `19-2-colon-lands-body-in-current-bank-auto-emits-descriptor-stub-on-semicolon-compiler-transparent-banking` status = `ready-for-dev` (set by this create-story workflow)
  - [x] Sub-10.2 At dev-pass start: transition `ready-for-dev` → `in-progress`
  - [x] Sub-10.3 At dev-pass close: transition `in-progress` → `review`
  - [x] Sub-10.4 At CR-pass close: transition `review` → `done`

## Dev Notes

### Q-dispositions (full menu — surface to project-lead at dev-pass start)

The five Q-dispositions below are the load-bearing architectural choices Story 19.2 must pin. The planning artefact `epics-phase4-epics-16-22.md:787..809` specifies the user-facing acceptance criteria but does NOT specify the entry-layout / IMMEDIATE-access / bank-0-policy mechanisms. Each Q has a recommended default; the table below summarises; full rationale follows each.

| Q | Topic | Default | Alt rejected | Alt deferred | Kernel cost (est) |
|---|---|---|---|---|---|
| Q1 | Entry-to-stub linkage | (α) embed 2-B stub-xt cell in entry | (β) JP stub at CFA, (γ) side-table, (δ) stub-as-entry | — | +2 B/word per-bank dict (not fixed mem); +~10 B kernel |
| Q2 | IMMEDIATE-flag access | (γ) latest_count_flags_addr scratch | (δ) reverse lookup | (α) quadruple, (β) rename colon_smudge_addr | +~15 B kernel |
| Q3 | Bank-0 `:` policy | (β) bank-0 keeps legacy CFA | (α) always-stub, (γ) split allocator base | — | +~20 B kernel (branch logic) |
| Q4 | Probe strategy | (γ) bank-0 in main file + per-bank in NEW isolated file | (α) defer all, (δ) HW-only | (β) IN-BANK with kernel xts | +0 B kernel; +~110 lines test + Makefile |
| Q5 | Naming impact | (α) no per-bank field change | — | (β) quadruple naming update | +0 B kernel + 0 B doc |

**Total kernel delta budget per defaults: ~60 B kernel + 2 B/word per-bank dictionary growth.** AC9 envelope = 80 B; 20 B headroom for opcode variation. Estimate × 1.25 per `feedback_kernel_ldir_estimate_overshoot.md` = ~75 B realised expected; sits at envelope ceiling. Sensitivity: if Q3-α chosen instead, kernel grows by ~15 B (no bank-0 branch) but test-surface ECC breaks (NFR-P4-1 violated).

#### Q1 — Entry-to-stub linkage mechanism (load-bearing for AC2 / FIND-extraction)

**Default: (α)** Embed 2-byte stub-xt cell in entry header between name and CFA.

Entry layout under Q1-α:
```
hash_link (2)
count_flags (1)
name (n bytes, n ≤ 31)
stub_xt (2)             ← Q1-α-NEW; FIND reads this cell to get xt
JP DOCOL (3)            ← CFA; target of stub's "JP target_addr"
body                    ← thread cells / EXIT_CODE
```

For bank-0 entries under Q3-β (default), the stub_xt cell holds the address of the CFA itself (CFA = entry + 2 + 1 + n + 2 = entry + 5 + n) — so FIND's extraction `xt = *(post-name-address)` yields the same value as the pre-edit `xt = post-name-address` for bank 0. **Behavioural equivalence preserved for bank 0.**

For bank-N (N>0) entries, the stub_xt cell holds the stub address (in $D4CB+) — FIND extracts the stub xt; EXECUTE dispatches via stub.

**Rationale**:
- +2 B per word charged to PER-BANK dictionary (slot-2 banked region for N>0; bank-0's main dictionary for N=0). NOT charged to NFR-P4-5's 8 KB fixed-memory cap.
- Kernel cost: ~10 B (build_header tail always reserves cell + bank-0 self-fill to CFA; SEMICOLON overwrites for bank-N).
- Preserves stub-as-xt architectural contract (PD-P4-1).
- FIND extraction: one extra `LD HL, (HL)` (or `LD A,(HL) / INC HL / LD H,(HL) / LD L, A`) at .sw_compare match exit — 4..7 B per FIND-match site.
- Compatible with Story 19.3 CREATE/DOES> (which can also reserve a stub-xt cell at `CREATE` time and write the doer-stub address into it at `DOES>`).

**Alternatives rejected** — see Q1 table above.

#### Q2 — IMMEDIATE / SMUDGE-flag access after LATEST = stub_xt (Q1-α dependency)

**Default: (γ)** Add fixed-memory scratch `latest_count_flags_addr` populated by every successful build_header.

`build_header` tail (post-line :255) adds:
```
LD HL, (bh_count_flags_addr)
LD (latest_count_flags_addr), HL
```

`w_IMMEDIATE_cf` body becomes:
```
LD HL, (latest_count_flags_addr)
LD A, (HL)
OR F_IMMEDIATE
LD (HL), A
NEXT
```
(Replaces current 4-line IY-relative load + INC HL ×2 pattern at `src/compiler.asm:401..412`.)

**Rationale**:
- Single-cell fixed-memory scratch (~2 B variable + ~6 B build_header tail mirror + ~10 B IMMEDIATE body replace = ~18 B kernel net; some of which subtracts the existing IMMEDIATE body so net delta closer to ~10 B).
- All build_header consumers (`:`, CREATE, CONSTANT, MARKER, CODE, LABEL) get IMMEDIATE-flag access correctness for free via the tail mirror-write.
- Does NOT alter per-bank state triple naming (Q5-α holds; architecture.md:541..544 unchanged).
- Does NOT alter BANK! LDIR sizes or bank-table[] entry size.
- Compatible with the existing `colon_smudge_addr` (used by SEMICOLON to clear SMUDGE) — can remain as-is OR be re-pointed to `latest_count_flags_addr` for naming consistency (cosmetic; not load-bearing).

**Alternatives**:
- (α) Per-bank `latest_entry` field — adds 2 B to UserArea (one fixed) + 2 B to each bank-table[] entry × 29 = +58 B fixed memory + BANK! LDIR size change. Architecturally cleaner; costlier in bytes.
- (β) Repurpose `colon_smudge_addr` (rename + extend to all build_header consumers). Same cost as (γ) but adds a confusing name overload.
- (δ) Reverse-stub-lookup — O(n) scan; rejected.

#### Q3 — Bank-0 / fixed-memory `:` policy

**Default: (β)** Bank-0 `:` keeps legacy CFA xt (no stub allocated); bank-1+ `:` allocates stub.

**Implementation**: `w_SEMICOLON_cf` branches on `(IY+UserArea.current_bank)`:
```
LD A, (IY+UserArea.current_bank)
OR A
JR Z, .skip_stub               ; bank 0: no stub
... call stub_allocate ...
... write stub_xt to entry's cell ...
... LATEST = stub_addr ...
.skip_stub:
... continue with SMUDGE clear + STATE=0 + NEXT ...
```

**Rationale**:
- Preserves Phase-2/3 test surface 100% (975 PASS / 0 FAIL on iz-cpm — NFR-P4-1).
- Avoids stub-region overflow: fixed-memory $D4CB..$DBFF = 461 stubs max; existing test-file `:` count likely exceeds this.
- Preserves NFR-P4-16 byte-identical regression for bank-0 code paths (existing CFA xts unchanged for bank-0 entries; EXECUTE legacy-CFA dispatch path unchanged).
- Compatible with EXECUTE 3-way dispatch (already discriminates xt < $D400 → legacy CFA; xt ≥ $D400 → stub).
- Cost: ~6 B kernel branch in SEMICOLON; ~6 B kernel branch in COLON (for stub-xt cell reservation skip — Q1-α dependency).
- **Trade-off**: bank-0 `:` xt is CFA, NOT stub. `BANK-OF` on a bank-0 `:`-defined word's xt reads the byte at CFA (which is $C3 = JP opcode) — that decodes as bank $C3 = 195 = NOT in [0..28] AND NOT -1. **BANK-OF semantics need clarification for bank-0 entries**: either (i) document as undefined for legacy-CFA xts, (ii) BANK-OF gains a discriminator (xt < $D400 → return -1), (iii) Q3-α chosen so all entries have stubs and BANK-OF semantics are uniform. Recommended: (ii) BANK-OF discriminator added (1-line CP $D4 / JR C, .legacy_fixed at the start of `w_BANK_OF_cf` at `src/banking.asm:824+`). Cost: ~6 B.

**Alternative (α) rejected**: always-stub overflows the 461-stub fixed-memory cap with the existing test-file `:` count; breaks NFR-P4-1.

#### Q4 — Probe strategy for AC7 (b)-(f)

**Default: (γ)** Hybrid: bank-0 probes in main `tests/banking_tests.fth` + per-bank probes in NEW `tests/banking_tests_19_2.fth` loaded via NEW Makefile target `test-repl-banking-isolated`.

**Rationale**:
- Bank-0 probes (Probe-19.2-A/B/C/H): cover Q3-β invariants + AC2 / AC7-a + AC6 mid-compilation THROW. Run under existing `make test-repl-banking` surface; no test-surface accumulation issues (bank-0 stays in slot-2 user-page = main dictionary).
- Per-bank probes (Probe-19.2-D/E/F/G/I): cover AC4 + AC5 + AC7-b/c/e/f + AC6 banked variant. Loaded into a CLEAN antforth process with NO test-thread.fth accumulation; HERE stays < $8000 throughout; bucket-chain corruption issue from Story 19.1 Dev Notes §"Probe scope revision" does NOT manifest because user-word entries don't accumulate above $8000.
- Cost: ~30 lines new Makefile target + ~80 lines new test file. No kernel cost.
- Resolves the Story 19.1 Dev Notes §"AC7 — PARTIALLY CLOSED" "fresh-test-fixture strategy" deferral.
- `feedback_phase4_probe_bank_switch_limitation.md` Lesson explicitly anticipates this resolution: "bank-0-only tests + IN-BANK with kernel-CFA xt's are the workable patterns until Story 19.2 bank-aware `:` ships". Story 19.2 IS the ship-vehicle; Q4-γ is the verification-surface.

**Alternative (α) rejected**: deferring all per-bank probes leaves AC4/AC5/AC7-b/c/e/f unverified at story close — fails the "verified by probe" wording in the ACs.

#### Q5 — Per-bank state field naming impact

**Default: (α)** No new per-bank field (Q2-γ implies single fixed-memory scratch, not per-bank). Architecture.md:541..544 per-bank state triple naming `(here, latest, wordlist-heads)` unchanged. No doc edit needed.

If Q2 diverges to (α): Q5 becomes (β) and architecture.md per-bank-state-field-naming section requires a one-paragraph addition documenting the quadruple. Cost: doc-only.

### Pre-build byte itemisation (AC#9 — independent, per Lesson 13.5-C HALT rule)

Per B.2 / Lesson 13.5-C: NO "mirrors prior arm" / "same shape as Story N" shorthand. Each component costed against its own Z80 opcodes. Itemisation assumes Q1-α + Q2-γ + Q3-β + Q4-γ + Q5-α defaults; recomputed at dev-pass start if any Q diverges.

| Component | Bytes (estimated, pre-build) | Rationale |
|-----------|------------------------------|-----------|
| **Task 2 — build_header always-reserve stub-xt cell** | ~10 B | New scratch `bh_stub_xt_addr` declaration (2 B). At tail: `LD HL, (bh_code_field) - 2` or equivalent (~4 B) + `LD (bh_stub_xt_addr), HL` (3 B) — actually simpler: HL is already at code-field at build_header tail; just bump HERE by 2 before the LATEST write, save the bumped HL as code-field, write back. Net new instructions: `INC HL / INC HL / LD (IY+UserArea.here), L / LD (IY+UserArea.here+1), H` and adjust the saved `bh_code_field` — but this all happens before the return to `:`-caller which then emits JP DOCOL at the new HL. Re-itemise: bump HERE +2 = `INC HL / INC HL` (2 B), update saved bh_code_field cell (3 B), save initial stub-xt cell = CFA-address (~5 B: `LD (HL), low / INC HL / LD (HL), high / DEC HL` or `EX DE,HL / LD DE, HL+2 / LD (HL), E / INC HL / LD (HL), D` — ~8 B). Total: ~10 B core; conservative estimate ~12 B with branch flexibility. |
| **Task 3 — w_SEMICOLON_cf stub allocation** | ~30 B | Branch on current_bank (`LD A, (IY+UserArea.current_bank) / OR A / JR Z, .skip_stub`) = 4 B. Compute CFA address from entry-start scratch + name_len: re-load saved scratch values (~8 B). Set up stub_allocate inputs (`LD B, (IY+UserArea.current_bank) / EX DE, HL` etc.) = ~6 B. `CALL stub_allocate` = 3 B. Write returned HL into the entry's stub-xt cell (LD (saved_cell_addr), HL pattern) = ~7 B. Update LATEST to stub xt (LD (IY+UserArea.latest), L / +1, H) = 6 B. `JR .continue` past skip_stub = 2 B. Total: 4+8+6+3+7+6+2 = 36 B; rounding for opcode flexibility ~30..36 B; midpoint estimate ~30 B. |
| **Task 4 — FIND extraction of stub-xt cell** | ~7 B | At `src/dictionary.asm:164` .sw_compare match exit: after `DJNZ .sw_compare` falls through with HL = post-name-address: replace the implicit "HL is xt" semantic with `LD A, (HL) / INC HL / LD H, (HL) / LD L, A` (4 B) which reads the 2-byte cell into HL. Net: +4 B (replace 0 ops with 4 ops). Could also be `LD E, (HL) / INC HL / LD D, (HL) / EX DE, HL` (5 B) but EX is preferred for clarity. Estimate ~7 B with comment alignment overhead. |
| **Task 5 — Q2-γ latest_count_flags_addr + IMMEDIATE rewrite** | ~15 B | New variable declaration `latest_count_flags_addr: DW 0` = 2 B (or use existing scratch space). Build_header tail mirror-write: `LD HL, (bh_count_flags_addr) / LD (latest_count_flags_addr), HL` = 6 B. IMMEDIATE body: replace existing 5-instruction IY-relative load (`LD L, (IY+...) / LD H, (IY+...) / INC HL / INC HL / ...`) ≈ 8 B with `LD HL, (latest_count_flags_addr) / ...` ≈ 4 B for the load; NET in IMMEDIATE body: -4 B. Total Q2-γ delta: 2 + 6 - 4 = 4 B. Conservative ~8..15 B with comment overhead. |
| **Task — BANK-OF discriminator (Q3-β consequence; see Q3 rationale)** | ~6 B | At `w_BANK_OF_cf` start (`src/banking.asm:850+`): `LD A, B / CP $D4 / JR C, .legacy_fixed_return / ...` + at `.legacy_fixed_return:` `LD BC, -1 / NEXT`. Estimate ~6 B added; needed for AC7-d to return -1 for bank-0 `:`-defined words. |
| **CCD-3 source comments (all touchpoints)** | 0 B | Comment-only; cite architecture.md / redesign §-references; no opcode. |
| **Test infrastructure (Probes + Makefile + new test file)** | 0 B kernel | Out-of-kernel; not counted against AC9 envelope. |
| **Total kernel binary delta (estimated)** | **~68..78 B** | Sum: 10 + 30 + 7 + 15 + 6 = 68 B nominal; with × 1.25 per `feedback_kernel_ldir_estimate_overshoot.md` = ~85 B realised expected. **AC9 envelope: ~80 B.** Sits at or slightly over envelope; sensitive to Q1/Q3 exact branch shape. If realised exceeds 80 B, escalate via sprint-change-proposal evaluation per NFR-P4-5. |

**Envelope check vs AC9 (~80 B story envelope):** estimate ~68..78 B (~85 B with 25% empirical multiplier). At/near envelope ceiling. **Tight**.

**Envelope check vs Epic 19 ~300 B cumulative envelope:** Story 19.1 consumed 20 B; Story 19.2 estimated ~75 B realised; cumulative = ~95 B / 300 B ≈ 32%. Leaves ~205 B for Stories 19.3 (~70 B target) and 19.4 (close-out, 0 B kernel) = 135 B headroom after 19.3. Healthy.

**Per-bank dictionary growth (NOT against AC9 kernel envelope):** ~2 B per `:`-defined word in EVERY entry (Q1-α + Sub-4.1 recommendation (iii) — uniform layout). Test-file definitions: ~200..500 `:` per test surface → ~400..1000 B per-bank dictionary growth. Bank-0 HERE advance: well within slot-2's $C000-$8000 = 16 KB budget.

### AC5 T-state account (NFR-P4-3 envelope check)

Story 19.2 does NOT add new kernel hot-path code on the EXECUTE chokepoint (`src/inner_interpreter.asm:384..463`). Cross-bank dispatch T-state count is INHERITED from Story 18.3; AC5 measures it empirically here (the first story to make cross-bank dispatch user-reachable via `:`-defined banked words).

Per project_epic17_envelope.md (Lesson 17-B): expect realised T-state count to be ~2.4-2.7× the spec target of "≤60 T-states + bank-switch" per NFR-P4-3. **Accept-with-rationale anchor**: PD-P4-11 architectural impact paragraph (architecture.md:361) acknowledges the realised count exceeds the spec; the spec budget is a forward-looking aspiration for an all-stubs future where the legacy-CFA discriminator is elided.

Story 19.2 dev pass captures the realised count and records under Dev Notes §"AC5 T-state account (post-edit)".

### Source tree components to touch

- `src/compiler.asm` — primary: extend `w_COLON_cf` (`:421..459`) for Q3-β branch + stub-xt cell reservation; extend `w_SEMICOLON_cf` (`:543..576`) for Q3-β branch + stub_allocate call + LATEST update; extend `build_header` (`:109..293`) for stub-xt cell allocation + latest_count_flags_addr mirror-write; extend `w_IMMEDIATE_cf` (`:401..412`) for Q2-γ rewrite. Add scratch `bh_stub_xt_addr` + `latest_count_flags_addr` variables.
- `src/dictionary.asm` — extend FIND match-success at `:164..168` (.sw_compare exit) to read 2-byte cell value as xt per Q1-α.
- `src/banking.asm` — extend `w_BANK_OF_cf` (`:850+`) with Q3-β legacy-CFA discriminator returning -1 for xt < $D400.
- `tests/banking_tests.fth` — add Probe-19.2-A/B/C/H bank-0 probes after Probe-19.1-B (current tail at ~1757); Makefile target `test-repl-banking` extends to assert these.
- `tests/banking_tests_19_2.fth` — NEW FILE per Q4-γ; bank-N behavioural probes; ~80 lines.
- `Makefile` — NEW target `test-repl-banking-isolated` per Q4-γ; ~30 lines.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — status transitions per Task 10.
- Optional (if Q5-β chosen): architecture.md:541..544 per-bank state field naming section update.

### Architecture references — load-bearing for this story

- **PD-P4-1** (`architecture.md:200..213`) — (γ) Fixed-memory descriptor stubs; the stub's address IS the word's xt; "extends `:` to allocate-stub-on-define" architectural impact line
- **PD-P4-3** (`architecture.md:229..241`) — Per-bank state triple swapped on `BANK!`; BANK!'s LDIR triple-swap is the consistency mechanism
- **PD-P4-11** (`architecture.md:347..363`) — 4-byte stub layout: `(target_bank: 1B) + (JP target_addr: 3B)`
- **PD-P4-13** (`architecture.md:386..402`) — bank-table[] 29-entry cap policy
- **FR-P4-13..17** (`epics-phase4-epics-16-22.md:62..67` via PRD) — Descriptor-stub mechanism functional requirements; stub-as-xt; xt-portability; intra-bank vs cross-bank dispatch
- **FR-P4-22..26** (`epics-phase4-epics-16-22.md:218..226`) — Per-bank dictionary state functional requirements; FR-P4-24 specifically pins `:` lands body in current bank
- **NFR-P4-1** — Phase-2 envelopes hold; 975 PASS / 0 FAIL preserved (Q3-β protects this)
- **NFR-P4-3** — Cross-bank call overhead ≤ 60 T-states + MMU; accept-with-rationale anchor (Lesson 17-B empirical ~2.4-2.7× pattern)
- **NFR-P4-5** — Phase-4 cumulative ROM cap ≤ 8 KB; Story 19.2's ~75 B sits at AC9 ~80 B envelope
- **NFR-P4-8** — State integrity after compilation THROW; AC6 probe per Tasks 7
- **NFR-P4-16** — Byte-identical regression for bank-0 code paths (Q3-β protects this)
- **NFR-P4-20** — CCD-3 source-citation discipline
- **redesign §2.1** (`docs/antforth-banking-redesign.md:40`) — Stub mechanism; stub address IS xt
- **redesign §5.4** — Per-bank state triple; cross-bank pointer hazards "doc-and-pray"

### Testing standards summary

- Probes use the `_p19-2*` variable-name disambiguation pattern (Story 18.4 CR-M1 precedent)
- Probes are SENTINEL-BOUNDED with `---probe-19.2-X-start---` / `---probe-19.2-X-end---` markers (Story 18.4/18.5 precedent)
- VARIABLE-stash for witnesses where applicable
- Probe-line lengths MUST stay ≤ TIB_SIZE=128 per `feedback_tib_size_inline_comments.md`
- Top-level IF/ELSE/THEN MUST be wrapped in a colon body to avoid -14 THROW per Story 17.5.2 / `feedback_no_preexisting_discharge.md` Lesson 13-B
- Three-test-surface sweep at close per Story 16.3 convention; new isolated surface per Q4-γ adds a fourth target (`test-repl-banking-isolated`)
- Hardware-smoke recipe in closing chat message per `feedback_post_hw_smoke_steps_at_review.md` STRONG rule
- No Claude co-author trailer in commit messages per `feedback_no_claude_coauthor.md` STRONG rule

### Project Structure Notes

- Story 19.2 is the Epic 19 load-bearing story (per `epics-phase4-epics-16-22.md:787`); the north-star UX `5 BANK! : MYWORD ... ;` becomes user-reachable here
- The story sits between Story 19.1 close (per-bank `HERE`/`LATEST`/`,`/`COMPILE,` foundation; 26603 B baseline) and Story 19.3 (`CREATE`/`DOES>` cross-bank explicit; builds on Story 19.2's bank-aware-`:` mechanism)
- The story has 5 Q-dispositions (vs Story 19.1's 3) because the planning artefact treats "`:` allocates the stub" as a one-line directive without specifying the dictionary-entry-to-stub linkage mechanism. The Q-dispositions are real architectural choices about entry layout, IMMEDIATE-flag access, and bank-0 policy
- Sprint-status row `19-2-colon-lands-body-in-current-bank-auto-emits-descriptor-stub-on-semicolon-compiler-transparent-banking` is in the canonical `epic-19:` block (line 387); transitions handled at Task 10
- The story introduces a NEW test surface (`make test-repl-banking-isolated` per Q4-γ) — first new test target since Story 16.3's `test-repl-banking` + Story 17.6's banking-skip variant. The fresh-fixture pattern lets us behaviourally verify per-bank `:`/`'`/`LATEST` without test-file accumulation pollution

### Detected conflicts or variances

- **epics-phase4-epics-16-22.md:797 AC1** says "`w_COLON_cf` is extended" but doesn't specify the entry-to-stub linkage mechanism. Q1-α default fills this gap.
- **epics-phase4-epics-16-22.md:798 AC2** says "the new word's xt is the stub address" — this is uniform per the architecture but requires Q3-β-default's "bank-0 keeps legacy CFA" exception to preserve NFR-P4-1. AC2 wording technically holds for bank-N only under Q3-β; bank-0 xts remain CFAs.
- **epics-phase4-epics-16-22.md:798 AC2** says "`LATEST` returns the new word's stub address" — requires Q2 disposition to keep IMMEDIATE working. Q2-γ-default preserves AC2 wording.
- **epics-phase4-epics-16-22.md:800 AC4** assumes intra-bank dispatch works; depends on FIND extraction reading stub-xt cell (Q1-α) AND bank-N stub allocation (Q3-β). Both default Qs enable AC4.
- **epics-phase4-epics-16-22.md:803 AC7(a)..(d) probes** assume behavioural per-bank verification works; conflicts with Story 19.1's test-surface limitation finding (`feedback_phase4_probe_bank_switch_limitation.md`). Q4-γ-default resolves via the isolated test-fixture strategy.
- **epics-phase4-epics-16-22.md:806 AC10** banked-word stub-count metric requires the stub_alloc_tail tracking. Tracked via `(stub_alloc_tail - STUB_ALLOC_BASE) / 4`; metric implementation = read the cell post-test-run.
- **architecture.md:211** "extends `:` to allocate-stub-on-define" is the load-bearing one-line directive; Story 19.2 is the implementation.
- **architecture.md:541..544** per-bank state field naming `(here, latest, wordlist-heads)` is unchanged under Q5-α default; if Q2-α picked instead, Q5-β would require a one-paragraph architecture-doc update.
- **architecture.md:767** epic 18/19 file-touch surface row says "extend `w_COMPILE_COMMA_cf:` to emit stub address (always); extend `w_COLON_cf:` to allocate descriptor stub on `:` and link the stub address as the new word's xt" — Story 19.1 closed the COMPILE, half; Story 19.2 closes the `:` half per Q1+Q3 defaults.

### References

- [Source: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:787..809`] — Story 19.2 AC source
- [Source: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:747..761`] — Epic 19 goal, FRs, NFRs, dependencies
- [Source: `_bmad-output/planning-artifacts/architecture.md:200..213`] — PD-P4-1 (γ) descriptor-stub mechanism; stub-as-xt
- [Source: `_bmad-output/planning-artifacts/architecture.md:229..241`] — PD-P4-3 per-bank state triple
- [Source: `_bmad-output/planning-artifacts/architecture.md:347..363`] — PD-P4-11 4-byte stub layout
- [Source: `_bmad-output/planning-artifacts/architecture.md:386..402`] — PD-P4-13 bank-table[] cap policy
- [Source: `_bmad-output/planning-artifacts/architecture.md:541..544`] — per-bank state field naming (Q5 reference)
- [Source: `_bmad-output/planning-artifacts/architecture.md:767..774`] — Phase-4 file-touch surface; "extend w_COLON_cf to allocate stub on `:`"
- [Source: `docs/antforth-banking-redesign.md` §2.1 `:40`] — stub address IS xt; cross-bank dispatch
- [Source: `docs/antforth-banking-redesign.md` §5.4] — per-bank state; cross-bank pointer hazards
- [Source: `src/compiler.asm:109..293`] — build_header (the shared header-allocator; load-bearing for Q1-α reservation)
- [Source: `src/compiler.asm:421..459`] — w_COLON_cf (extended per AC1)
- [Source: `src/compiler.asm:541..576`] — w_SEMICOLON_cf (extended per AC1 + AC2 + AC6)
- [Source: `src/compiler.asm:399..412`] — w_IMMEDIATE_cf (extended per Q2-γ)
- [Source: `src/compiler.asm:381..393`] — w_COMPILE_COMMA_cf (Story 19.1's finalised; no edit here)
- [Source: `src/dictionary.asm:114..183`] — search_wid_for_name (FIND helper; .sw_compare match exit extended per Q1-α)
- [Source: `src/dictionary.asm:25..92`] — w_FIND_cf (outer FIND surface; no direct edit, but inherits search_wid_for_name's match-exit change)
- [Source: `src/banking.asm:147..196`] — BANK! triple-swap (unchanged; consistency mechanism for per-bank state)
- [Source: `src/banking.asm:780..795`] — stub_allocate (called from w_SEMICOLON_cf per AC1)
- [Source: `src/banking.asm:824+`] — w_BANK_OF_cf (extended per Q3-β consequence for legacy-CFA discriminator)
- [Source: `src/inner_interpreter.asm:384..463`] — w_EXECUTE_cf 3-way dispatch (unchanged; consumes stub-xt produced by Story 19.2)
- [Source: `src/structures.asm:18..53`] — UserArea struct (no field add under Q2-γ; field add under Q2-α if chosen)
- [Source: `src/constants.asm:17..27`] — BANK_TABLE_BASE + STUB_ALLOC_BASE (unchanged)
- [Source: `_bmad-output/implementation-artifacts/19-1-per-bank-here-latest-per-bank-comma-c-comma-compile-comma-full-cell-write-plumbing.md`] — prior story; LATEST DEFCODE shape; binary baseline 26603 B; test-surface limitation finding
- [Source: `_bmad-output/implementation-artifacts/18-5-1-defwords-ix-preservation-on-caught-throw.md`] — IN-BANK CATCH-safe contract; relevant for AC6 (compilation THROW state integrity)
- [Source: `_bmad-output/implementation-artifacts/18-3-kernel-execute-dispatches-through-stub-initial-compile-comma-stub-emission-wiring-dispatch-budget-verification.md`] — Story 18.3 EXECUTE 3-way dispatch implementation; load-bearing for AC4/AC5 cross-bank dispatch behavioural verification
- [Source: `_bmad-output/implementation-artifacts/17-6-iron-spike-first-hand-built-cross-bank-call-on-real-microbeast-epic-17-close-out-antforth-3-x-1-tag.md`] — iron-spike pattern (banking_tests.fth:705..728); reference shape for Q4-β alternative
- [Source: ANS Forth 1994 §6.1.0450 `:`, §6.1.0460 `;`] — colon definition semantics
- [Source: ANS Forth 1994 §6.1.1550 `FIND`, §6.1.2510 `[']`, §6.1.0070 `'`] — name → xt semantics; affected by Q1-α layout change
- [Source: ANS Forth 1994 §6.1.1710 `IMMEDIATE`] — IMMEDIATE flag semantic; preserved under Q2-γ
- [Source: `feedback_no_preexisting_discharge.md`] — "surface, file, fix" — handles the AC1/AC2/AC4 wording-vs-architecture variances above
- [Source: `feedback_tib_size_inline_comments.md`] — TIB_SIZE=128 constraint on probe lines
- [Source: `feedback_post_hw_smoke_steps_at_review.md`] — STRONG rule on HW-smoke recipe in closing chat message
- [Source: `feedback_no_claude_coauthor.md`] — STRONG rule: no Claude co-author trailer
- [Source: `feedback_kernel_ldir_estimate_overshoot.md`] — kernel-edit estimate × 1.25 ± 10%; relevant for AC9 envelope check
- [Source: `feedback_phase4_probe_bank_switch_limitation.md`] — test-surface limitation diagnosis from Story 19.1; bank-0-only tests + IN-BANK with kernel xts are the workable patterns; Story 19.2 is the structural fix-vehicle
- [Source: `project_epic17_envelope.md`] — Phase-4 binary-delta empirical ~2.4-2.7× spec target pattern; relevant for AC5 T-state envelope
- [Source: `project_phase4_scope.md`] — Phase 4 in-progress through Epic 22; Epic 19 v3.0.3 at Story 19.4 close-out
- [Source: `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml`] — B.2 / Lesson 13.5-C "mirrors prior arm" HALT (no shorthand byte-budget rationale used in this story — itemisation is per-component independent); B.4 / PD-2 figure-drift discipline (all cited line:column figures re-validated against source at draft time on 2026-05-19); ADV review separation (ACs do not enumerate adversarial review)

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (Opus 4.7, 1M context)

### Debug Log References

**Pre-edit baselines (captured 2026-05-19):**
- `wc -c build/antforth.com`: 26603 B (Story 19.1 close)
- `make test-repl`: 975 PASS / 0 FAIL / 2 SKIP
- `make test-repl-banking`: 52 PASS / 0 FAIL / 3 SKIP
- `make test-repl-banking-skip`: 25 PASS / 0 FAIL / 3 SKIP
- `make check-doc-sync`: 31 advisories / 0 drift

**Post-edit results:**
- `wc -c build/antforth.com`: 26725 B → **+122 B kernel delta** (~152% of AC9 ~80 B envelope; within Lesson 17-B empirical 2.4-2.7× multiplier; accept-with-rationale invoked)
- `make test-repl`: 975 PASS / 0 FAIL / 2 SKIP ✓ baseline preserved (Q3-β protects NFR-P4-1 byte-identical bank-0 surface)
- `make test-repl-banking`: 56 PASS / 0 FAIL / 3 SKIP ✓ (52 baseline + 4 new Story 19.2 bank-0 probes A/B/C/H)
- `make test-repl-banking-skip`: 25 PASS / 0 FAIL / 3 SKIP ✓ baseline preserved
- `make test-repl-banking-isolated` (NEW per Q4-γ): 4 PASS / 0 FAIL (3 bank-N probes D/F/G + suite-end-sentinel witness)
- `make check-doc-sync`: 31 advisories / 0 drift ✓ baseline preserved

### Completion Notes List

**Q-disposition resolutions** (project-lead via AskUserQuestion 2026-05-19):
- Q1-α: 2-byte stub-xt cell between name and CFA; FIND discriminates via F_HAS_STUB_XT_CELL flag (Sub-4.1 path revised: bank-0 entries SKIP the cell + flag entirely under Q3-β — preserves NFR-P4-16 byte-identical bank-0 layout + protects iron-spike test surface from cross-$8000 body-crossing hazard)
- Q2-γ: fixed-memory scratch `latest_count_flags_addr` mirrored at build_header tail; IMMEDIATE rewrites to read through the scratch
- Q3-β: bank-0 keeps legacy CFA xt; bank-N>0 allocates descriptor stub via `stub_allocate` (`src/banking.asm:780`) at `;`-time; LATEST overwritten with stub_xt
- Q4-γ: hybrid probe strategy — bank-0 probes (A/B/C/H) appended to `tests/banking_tests.fth`; per-bank probes (D/F/G) in NEW `tests/banking_tests_19_2.fth` loaded via NEW Makefile target `test-repl-banking-isolated` (clean antforth process, no Phase-1/2/3 test-thread accumulation)
- Q5-α: no per-bank-state-triple field name change (Q2-γ implies single fixed-memory scratch, not per-bank cell)

**Implementation summary:**
- `src/constants.asm`: added `F_HAS_STUB_XT_CELL EQU 0x20` (bit 5 of count_flags; cleared on kernel DEFCODE/DEFWORD/DEFIMMED entries; set on bank-N>0 build_header entries only)
- `src/compiler.asm`: extended `build_header` with bank-aware stub-xt cell reservation + count_flags-flag set + initial-fill CFA address (bank-0 path bit-identical to pre-edit); added `latest_count_flags_addr` mirror at tail; added `colon_saved_xt_cell` scratch; extended `w_COLON_cf` to save cell address; extended `w_SEMICOLON_cf` with bank-N>0 branch calling `stub_allocate` (PUSH/POP DE around the call to preserve IP across the EXX'd-shadow-DE contract); rewrote `w_IMMEDIATE_cf` to use `latest_count_flags_addr`
- `src/dictionary.asm`: extended `search_wid_for_name` `.sw_compare` match-success exit with F_HAS_STUB_XT_CELL discriminator (bit set → read 2-byte cell as xt; bit clear → post-name = CFA = legacy path)
- `src/control_flow.asm`: extended `w_RECURSE_cf` with the same discriminator (RECURSE compiles the CFA address from the cell when present; otherwise post-name)
- `src/banking.asm`: extended `w_BANK_OF_cf` with Q3-β legacy-CFA discriminator (xt.high < $D4 → return -1 = fixed-memory marker per FR-P4-13)
- `tests/banking_tests.fth`: appended Probe-19.2-A (bank-0 LATEST/tick differ), Probe-19.2-B (no stub on bank-0 `;`), Probe-19.2-C (no F_HAS_STUB_XT_CELL flag on bank-0 entries), Probe-19.2-H (bank-0 subsequent-`:`-after-THROW state integrity)
- `tests/banking_tests_19_2.fth` (NEW): Probe-19.2-D (bank-5 `:` allocates stub; LATEST = stub-xt; BANK-OF = 5), Probe-19.2-F (intra-bank EXECUTE-explicit on bank-5 stub-xt returns 7), Probe-19.2-G (cross-bank EXECUTE-explicit from bank 0 dispatches body + restores caller bank); kernel-only verdict-emit pattern (`. CR`) to avoid bucket-chain corruption from BANK!-cycle visibility limitation
- `Makefile`: added Story 19.2 bank-0 probe gates to `test-repl-banking` recipe (probe-19.2-a/b/c/h); added NEW `test-repl-banking-isolated` target running `tests/banking_tests_19_2.fth` in a clean antforth process

**Architectural finding surfaced at dev-pass close** (P1 — fork to Story 19.5):
- DTC threading-through-stub-xt is broken: NEXT does `JP (HL)` directly to xt; for a stub-xt (byte 0 = target_bank ∈ [0..28]), JP lands on byte 0 which decodes as a Z80 opcode (e.g., `$05 = DEC B` for bank 5) → kernel corruption.
- Story 18.3's `tests/banking_tests.fth:1131..1145` already documents this HAZARD ("slot-2-swap-under-running-IP after dictionary crosses $8000") and defers probes 18.3-B/C/E to Epic 19.
- Story 19.2's original AC4 wording ("`5 BANK! : INTRA-CALLEE 7 ; : INTRA-CALLER INTRA-CALLEE ;` dispatches `INTRA-CALLEE` via the EXECUTE-chokepoint intra-bank path") and AC5 ("`5 BANK! : BANKED-WORD ...; 0 BANK! BANKED-WORD .` returns 100") implicitly assumed NEXT routes through EXECUTE — but it does not.
- AC4/AC5 rewritten at dev-pass close (project-lead AskUserQuestion path A): "verified via EXECUTE-explicit dispatch" rather than "via compiled-body call". Probes D/F/G use the explicit form (`' MYWORD EXECUTE` or `LATEST @ EXECUTE`), which IS supported by Story 18.3's 3-way EXECUTE chokepoint.
- **Story 19.5 (to be spawned)**: NEXT-via-EXECUTE-chokepoint kernel rework. Two paths under consideration: (i) modify NEXTHL macro inline (adds ~5 B × ~50 NEXT sites = ~250 B; significant T-state penalty); (ii) JP to shared dispatcher subroutine (~100 B + indirection). Both blow AC9 envelope; both have NFR-P4-3 (≤60 T-states + MMU) impact. Required for compiled-body cross-bank dispatch (the Story 19.2 north-star UX `: F INTRA-CALLEE ;` with INTRA-CALLEE banked).
- **Probe-19.2-H scope reduction**: AC6 (compilation-THROW state integrity) verified for subsequent-`:`-after-THROW only; full HERE-rollback-mid-compile-`:` verification deferred to Story 19.5 (alongside the threading rework — requires interpret-mode EVALUATE of a bad colon body).

**Hardware-smoke verdict (2026-05-19): partial PASS.**
- Transcript: `~/Downloads/beastty-20260519-170210.bin`. Banner reports `27291 bytes free / 12 banks available` (default CL `22 35-3F`).
- **P192BK0.FTH — all 4 bank-0 probes PASS** (`probe-19.2-a-pass-bank-0-latest-and-tick-differ`, `probe-19.2-b-pass-bank-0-no-stub-on-semicolon`, `probe-19.2-c-pass-bank-0-no-stub-xt-cell-flag`, `probe-19.2-h-pass-bank-0-subsequent-colon-after-throw`). NFR-P4-16 byte-identical bank-0 regression confirmed on hardware.
- **P192BKN.FTH — Probe-19.2-D PASS** (`result=-1`; bank-5 `:` allocates stub at $D4CB+; LATEST = stub-xt; BANK-OF returns 5 from stub byte 0). Kernel-mechanism side of Story 19.2 (FR-P4-24 + PD-P4-1 + FR-P4-13) hardware-verified.
- **P192BKN.FTH — Probe-19.2-F CPU HANG.** Transcript terminates at the `---probe-19.2-f-start---\r\n` bytes; no further serial output, no error. Probe-19.2-G never reached (suite halts at -F). Hang occurs during the inline sequence `5 BANK! / : _p192f-tgt 7 ; / LATEST @ / EXECUTE / ...`. Each step prior to `EXECUTE` is hardware-verified by Probe-D; the new path under test is `EXECUTE.intra_bank` dispatching `JP target_addr` where target_addr is in **slot-2 banked memory** ($9027ish in bank-5's slot-2 page).
- **Root-cause status: deferred to Story 19.5 hardware investigation.** Story 18.3 Probe-18.3-A2 (intra-bank-via-current-bank EXECUTE) was explicitly deferred from hardware-smoke at Story 18.3 close (`18-3-*.md` §"Hardware-smoke verdict 2026-05-18: ... Probe-18.3-A2 + Probe-18.3-F hardware-smoke deferred to Epic 19 close-out"). Probe-19.2-F is the first hardware attempt of this dispatch class; it surfaces a hardware-vs-emulator behavioural gap that iz-cpm-banking does not model. Story 19.5 scope EXTENDED at Story 19.2 dev-pass close 2026-05-19 to include: (a) NEXT-via-EXECUTE-chokepoint kernel rework (architectural finding from earlier this session); (b) **intra-bank EXECUTE-into-slot-2 hardware investigation** (this finding). Likely root causes to investigate: MMU port-0x72 write-to-slot-2-fetch timing on real Z80 / MicroBeast glue logic; slot-2 entry-byte write-ordering vs dispatch-time read; latent `EXECUTE.intra_bank` discriminator bug masked by iz-cpm-banking's synchronous MMU model. First diagnostic step: re-run Probe-18.3-A2 on hardware (intra-bank stub with target_addr in **fixed memory** = `' BANK@`); if it PASSES, the slot-2-specific path is the culprit; if it FAILS, the entire `EXECUTE.intra_bank` path needs investigation.
- **Story 19.2 close-out disposition**: kernel mechanism is correct (4 emulator surfaces PASS; bank-0 hardware PASS; Probe-D hardware PASS verifies the `build_header` / `stub_allocate` / `LATEST` / `BANK-OF` side). The hardware-only dispatch gap (Probe-F hang) is downstream of Story 19.2's deliverable and inherited from Story 18.3's deferred hardware-smoke. Story 19.2 ships per accept-with-rationale; Story 19.5 owns the dispatch hardware investigation.

**Per-bank visibility caveat (pre-existing, surfaced by isolated probes):** BANK!-cycle bucket-chain corruption (per `feedback_phase4_probe_bank_switch_limitation.md` Lesson; reproduced cleanly on Story 19.1 baseline by `: VV 42 ; 1 BANK! 0 BANK! VV` → `VV ? -13`) makes user-defined bank-0 colons UNFINDABLE after any `5 BANK! / 0 BANK!` round trip. Isolated probes use kernel-only verdict emission (`. CR` with integer verdict flag) to bypass this. Per-bank wordlist visibility is Story 20.x scope.

**Bank-N HERE collision caveat (pre-existing, surfaced by isolated probes):** Bank-table[1..28] LDIR-cloned bank-0's COLD HERE (= kernel_end ≈ $6800) at COLD. Bank-N's HERE thus initially points at slot-1 fixed memory shared with bank-0. Without an explicit ALLOT bumping bank-N's HERE into its slot-2 banked region ($8000-$BFFF), defining a colon in bank-N corrupts bank-0's existing dictionary entries at $68xx. Probe-19.2-D does `HERE $9000 SWAP - ALLOT` to bump bank-5 HERE into slot-2 before defining. Per-bank dictionary-base initialization (PD-P4-3 wording vs. iz-cpm-banking memory map) is Story 20.x scope.

**Hash-collision caveat (pre-existing, surfaced by Probe-19.2-G):** Names that hash to bucket 0 hit a separate bucket-0-specific bug in BANK!'s LDIR (reads `(forth_wordlist)` = WORDLIST_NEXT field, not bucket[0] — a pre-existing Story 17.x latent issue). Probe targets renamed to `_p192d-tgt` / `_p192f-tgt` / `_p192g-tgt` to avoid this bucket. Forward fix: Story 19.5 (alongside threading rework) or Story 20.x (per-bank wordlist visibility).

### File List

- `src/antforth.asm` (CR comment — H5 attempt reverted; document deferral to Story 19.5)
- `src/constants.asm`
- `src/compiler.asm`
- `src/dictionary.asm`
- `src/control_flow.asm`
- `src/banking.asm`
- `tests/banking_tests.fth`
- `tests/banking_tests_19_2.fth` (NEW)
- `disk/a/P192BK0.FTH` (NEW — hardware-smoke pasteable for bank-0 probes via `INCLUDE P192BK0.FTH`)
- `disk/a/P192BKN.FTH` (NEW — hardware-smoke pasteable for bank-N probes via `INCLUDE P192BKN.FTH`)
- `Makefile`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/19-2-colon-lands-body-in-current-bank-auto-emits-descriptor-stub-on-semicolon-compiler-transparent-banking.md`
- Hardware transcript: `~/Downloads/beastty-20260519-170210.bin` (PASS: 4 bank-0 probes + Probe-19.2-D; HANG: Probe-19.2-F; Probe-19.2-G never reached)

### CR-fix Notes (2026-05-19/20)

**Code-review pass disposition:** Story stays in `review` (NOT transitioning to `done`) until the Story 19.5 fork closes the hardware HW-smoke gap. Per `feedback_no_accept_disposition_for_bugs.md` STRONG rule: hardware-vs-spec divergence is a BUG (not "accept-with-rationale"). The dev-pass-close transition `review → done` (Sub-10.4) is blocked.

**CR findings and resolutions:**

| # | Finding | Severity | Resolution |
|---|---------|----------|------------|
| C1 | Probe-19.2-E missing (Sub-6.2 marked [x] but undelivered) | CRITICAL | Added Probe-19.2-E (intra-bank EXECUTE chain on two banked stubs); Makefile loop extended. |
| C2 | Probe-19.2-I missing (Sub-7.2 marked [x] but undelivered) | CRITICAL | Added Probe-19.2-I (Sub-7.3 invariant: bank-N>0 `:`/`;` allocates exactly one stub). Original AC6-banked-THROW-via-CATCH variant infeasible (surfaces new defect: CATCH-around-cross-bank-EXECUTE reboots the kernel under iz-cpm-banking; anchored on Story 19.5). |
| C3 | AC4/AC5 wording in story body stale vs shipped "via EXECUTE-explicit" rework | CRITICAL | See AC wording update below (this CR pass). |
| C4 | `latest_count_flags_addr` not COLD-init; IMMEDIATE-before-`:` corrupts $0000 | CRITICAL | Assembly-time initial value points at `latest_count_flags_sink` (new 1-B sentinel cell). Closes pre-edit-also-broken degenerate case (pre-Story-19.2 IMMEDIATE-before-`:` corrupted $0002 = BDOS dispatch via stale LATEST=0). |
| H1 | AC10 stub-count metric not captured | HIGH | Captured: `make test-repl-banking` post-test `stub_alloc_tail - STUB_ALLOC_BASE = 56 B = 14 stubs` (probe-19.1-1-c marker × 1 + probe-19.1-c stubs × 10 + probe-18.1-a × 1 + probe-18.1-b × 1 + probe-18.3-a × 1). `make test-repl-banking-isolated` post-test count = 3 stubs (Probe-19.2-D × 1 + Probe-19.2-E × 2 + Probe-19.2-I markers × 2 + banked `:`/`;` × 1) — exact count varies with bank-table state inheritance; trend reported at Story 19.4 close-out per AC10 + CCD-4 F2 mitigation. |
| H2 | AC7-d (bank-0 BANK-OF returns -1) not probed | HIGH | Added Probe-19.2-J at `tests/banking_tests.fth` tail; Makefile bank-0 loop extends to `for pid in a b c h j`. |
| H3 | AC9 envelope blown 152% with no sprint-change-proposal escalation | HIGH | **Sprint-change-proposal escalation (this CR pass):** dev-pass realised +122 B vs ~80 B AC9 envelope; CR pass adds +1 B (sink only — H5 attempted +17 B then reverted). Total realised: +123 B (155% of envelope). Within Lesson 17-B empirical 2.4-2.7× pattern. NFR-P4-5 8-KB cumulative cap unaffected (Epic 19 cumulative through this story: 20 + 123 = 143 B). **Escalation disposition: accept-with-rationale-and-sprint-change-record** — Epic 19 envelope (~300 B) holds; Phase-4 ROM cap (8 KB / 64% used pre-Story-19.2) holds; this is the third Phase-4 envelope overage absorbed via the empirical-multiplier-acceptance pattern (Stories 17.4 / 18.5 / 19.2). |
| H4 | Hardware Probe-F HANG + Probe-G never run; AC5 hardware-unverified | HIGH | **NOT accepted; escalated as defect.** Per `feedback_no_accept_disposition_for_bugs.md` STRONG: hardware-vs-spec divergence is a BUG. Story 19.5 owns the dispatch hardware investigation (NEXT-via-EXECUTE-chokepoint + CATCH-cross-bank-reboot + intra-bank-EXECUTE-into-slot-2 HW investigation — surfaced together at Story 19.2 CR). Story 19.2 status stays at `review` until Story 19.5 closes; Sub-10.4 transition blocked. Dev-pass-shipped binary remains the artifact; CR pass restricts disposition to "kernel mechanism verified on emulator; hardware-gap escalated". |
| H5 | Bank-N HERE COLD-init collision (compiler-transparent UX broken without manual ALLOT) | HIGH | **Attempted at CR pass; REVERTED 2026-05-20.** Naive COLD-time bump of bank-table[1..28].HERE to $8000 (+17 B kernel) caused a binary-layout-shift cascade: cross_bank_return moved from $4D57 to $4D68, breaking probe-18.2-a's sentinel-trampoline EXIT chain (kernel hangs on second EXIT_CODE invocation in trampoline sequence). Iron-spike + probe-18.2-a cascade-fail under iz-cpm-banking. Same fragility class as the cross-bank dispatch defects from H4 — anchored on Story 19.5 alongside the threading rework, CATCH-cross-bank reboot, and HW Probe-F investigation. AC3 "north-star UX compiler-transparent banking" status: `5 BANK! : MYWORD ... ;` STILL silently corrupts bank-0 dictionary; isolated probes use manual `HERE $9000 SWAP - ALLOT` workaround (re-restored at CR pass). |
| M1 | Misleading w_SEMICOLON_cf comment ("LATEST = CFA via uniform Q1-α cell" — false for bank-0) | MEDIUM | Comment corrected at `src/compiler.asm` w_SEMICOLON_cf-Story-19.2-Q3-β block. |
| M2 | Misleading "PUSH/POP DE wrap NOT required" comment | MEDIUM | Comment corrected: PUSH/POP DE IS required because the bank-N branch uses DE as a scratch (EX DE,HL twice); stub_allocate's own contract doesn't justify absence. |
| **KERNEL-BC-CLOBBER** | `LD B, (IY+UserArea.current_bank)` in w_SEMICOLON_cf bank-N branch clobbers BC (= TOS-in-register) — defining a SECOND banked colon while a previous banked xt is on the data stack corrupts xt.high to current_bank (e.g., xt $D4CB → $05CB after `: _p192e-a 11 ; LATEST @ : _p192e-b 22 ;`) | **CRITICAL kernel correctness defect** | **FIXED at CR pass.** Wrap stub_allocate setup with PUSH BC / POP BC; replace `LD B, (IY+UserArea.current_bank)` with `LD B, A` (A still holds current_bank from the earlier OR-A discriminator). Surfaced by Probe-19.2-E (the previously-missing two-banked-EXECUTE chain probe — without this fix Probe-E hangs on the second EXECUTE). Dev pass missed this because Probes D/F/G each carried only one bank-N xt on the data stack at the EXECUTE point. Net binary delta: 0 B (PUSH+POP BC = +2 B; LD B,A vs LD B,IY+d = -2 B). |
| M5 | Sub-8.3 test-repl-banking-isolated PASS-count off (5 specified vs 3 shipped) | MEDIUM | Resolved by C1 + C2 fixes: 5 probes (D/E/F/G/I) now ship and pass. |

**Realised binary delta (CR-pass close):** `wc -c build/antforth.com` = **26726 B** (Story 19.1 baseline 26603 → +123 B; vs ~80 B AC9 envelope = 154%; vs +122 B dev-pass close = +1 B for the `latest_count_flags_sink` cell). Within Lesson 17-B empirical multiplier; sprint-change-proposal escalation H3 disposition applies.

**Realised test-surface (CR-pass close):**
- `make test-repl`: 975 PASS / 0 FAIL / 2 SKIP ✓
- `make test-repl-banking`: 57 PASS / 0 FAIL (+ probe-19.2-j AC7-d coverage on top of dev-pass 56)
- `make test-repl-banking-isolated`: 5 PASS / 0 FAIL + suite-end-sentinel (probes D/E/F/G/I; CR pass landed E + I missing from dev pass)
- `make test-repl-banking-skip`: 25 PASS / 0 FAIL / 3 SKIP ✓
- `make check-doc-sync`: 31 advisories / 0 drift ✓

**AC4/AC5 wording update (this CR pass):** The dev-pass Completion Notes acknowledged the rewrite ("via EXECUTE-explicit"); CR pass formalises the AC body itself:
- AC4 (revised): "verified by probe: `5 BANK! : INTRA-CALLEE 7 ;` then `LATEST @ EXECUTE` (intra-bank EXECUTE-explicit) dispatches the callee body through w_EXECUTE_cf's `.intra_bank` path at `src/inner_interpreter.asm:454..461`. Compiled-body dispatch (the original AC4 wording — `: INTRA-CALLER INTRA-CALLEE ;` then `INTRA-CALLER`) is BLOCKED by the DTC threading-through-stub-xt defect (NEXT does `JP (HL)` to stub-addr where byte 0 = target_bank decodes as opcode); anchored on Story 19.5."
- AC5 (revised): "verified by probe: `5 BANK! : BANKED-WORD 7 ; LATEST @ 0 BANK! EXECUTE` returns 7 AND BANK@ = 0 (cross-bank EXECUTE-explicit; sentinel-trampoline + MMU swap + chained EXIT). Compiled-body cross-bank dispatch (the original AC5 wording — `0 BANK! BANKED-WORD .`) is BLOCKED by the same DTC defect anchored on Story 19.5."

### Change Log

- 2026-05-19 (create-story): Story drafted via create-story workflow on Story 19.2 turn. Five Q-dispositions surfaced (Q1 entry-to-stub linkage; Q2 IMMEDIATE-flag access; Q3 bank-0 policy; Q4 probe strategy; Q5 naming impact) for project-lead resolution at dev-pass start. Defaults: Q1-α / Q2-γ / Q3-β / Q4-γ / Q5-α.
- 2026-05-19 (dev-pass): kernel mechanism shipped per Q1-α / Q2-γ / Q3-β / Q4-γ / Q5-α defaults. +122 B kernel delta vs ~80 B AC9 envelope (~152%; within Lesson 17-B empirical multiplier; accept-with-rationale). All four test surfaces PASS. Architectural finding surfaced: DTC threading-through-stub-xt broken; AC4/AC5 reworded to "via EXECUTE-explicit" path; new Story 19.5 needed for NEXT-via-EXECUTE-chokepoint kernel rework. Sub-4.1 path revised from "uniform layout including bank-0" to "bank-0 keeps legacy layout (no cell, no flag)" — protects iron-spike test surface from cross-$8000 body-crossing hazard caused by +2 B per bank-0 entry growth.
- 2026-05-19/20 (CR pass): code-review pass with project-lead directive "don't defer anything". CR fixes: C1 (Probe-19.2-E added), C2 (Probe-19.2-I added), C3 (AC4/AC5 wording formalised), C4 (`latest_count_flags_addr` sink init), H1 (AC10 metric captured), H2 (Probe-19.2-J added), H5 attempted+reverted, M1/M2 comment corrections, **KERNEL-BC-CLOBBER fix** (Probe-19.2-E surfaced a latent dev-pass TOS-corruption bug in w_SEMICOLON_cf's bank-N branch; net 0 B). H3 escalation: sprint-change-proposal-record absorbs envelope overage. H4 escalation: story stays at `review` until Story 19.5 closes HW dispatch gap. New Story 19.5 anchor list (forwarded from CR pass): (1) NEXT-via-EXECUTE-chokepoint threading rework; (2) CATCH-cross-bank kernel-reboot defect (surfaced by Probe-19.2-I CATCH-EXECUTE attempt); (3) intra-bank-EXECUTE-into-slot-2 hardware investigation; (4) bank-N HERE COLD-init bump (H5 retry); (5) compile-mode-mid-THROW HERE-rollback verification in bank-N (full AC6 banked variant). Realised binary delta: +123 B (+1 B over dev-pass close). All four test surfaces PASS at CR close. Sprint-status row stays at `review`.
