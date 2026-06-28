# Phase 4 Retrospective — Banked-RAM Enablement (antforth v3.0.1 → v3.0.7)

Date: 2026-06-14
Facilitator: Dev (Story 22.4 close-out)
Scope: Phase 4 — Epics 16, 17, 18, 19, **19.5 (stabilization interlude)**, 20, 21, 22 (8 sub-tracks, 38 stories)
Phase outcome: **CLOSED.** antforth **v3.0.7** (final) — the first feature phase since v2.0; the banked-RAM enablement promise delivered.

## Headline

Phase 4 took antforth from a flat 64 KB CP/M Forth to a banked Forth that addresses the MicroBeast's full 512 KB of RAM through the `$8000-$BFFF` MMU portal — and made banking **invisible to user code**: you define a word in a bank, call it by name from anywhere, `FIND`/`WORDS`/`MARKER`/`FORGET` all just work, and an `ABORT` never strands you in the wrong bank. The headline technical pivot was mid-phase: the Epic-18 sentinel-trampoline dispatch proved layout-fragile on the path to compiler-transparent banking, triggering the **Epic-19.5 stabilization interlude** that replaced it with a self-dispatching `RST $28` descriptor stub (0 T-states/NEXT). Phase-4 cumulative cost: **+3,504 B** (24,995 → 28,499), well inside the NFR-P4-5 ~6 KB @12-bank envelope. Stub region **0/461 at boot** (reclamation is lifecycle, not boot-count).

## Phase summary & metrics

| Epic | Tag | Stories | Theme | Net delta |
|---|---|---|---|---|
| 16 | — (prework) | 16.1–16.4 | CCP-eviction spike, doc-lock, emulator pick, §9 closures | infra |
| 17 | v3.0.1 (`39ac70b`) | 17.1–17.6 + 17.5.1/.2 | user-visible BANK* surface (10/12) + CL parser + iron-spike | +~1,232 B |
| 18 | v3.0.2 (`0aab73b`) | 18.1–18.5 + 18.5.1 | descriptor stubs + trampoline + BANK-OF + IN-BANK | +~249 B |
| 19 | v3.0.3 (`94c2ba0`) | 19.1–19.4 + 19.3.1 | bank-aware `:`/`,`/CREATE/DOES> (compiler-transparent) | +~251 B |
| 19.5 | v3.0.4 (`2808ce3`) | 19.5.0–19.5.4 | DTC dispatch rework: RST-$28 self-dispatch stub (ADR-led) | +~119 B |
| 20 | v3.0.5 (`0fb4434`) | 20.1–20.3 | bank-aware FIND (24-bit fat pointers) + unified WORDS | +680 B |
| 21 | v3.0.6 (`95cfe6d`) | 21.1–21.3 | bank-aware lifecycle: MARKER/FORGET + ABORT/QUIT restore | +181 B |
| 22 | v3.0.7 (this) | 22.1–22.4 | reflection + UX: `.BANKS`, prompt, CODE disposition, close | +450 B |

- **Phase-4 cumulative binary delta: +3,504 B** (Phase-3 close 24,995 B → 28,499 B). 1-byte baseline drift (24,995-vs-24,996) RESOLVED at 22.4 by re-`wc -c` of the v2.0.0 tag artifact → authoritative **24,995**.
- **Total banking-infra occupancy:** 3,504 B kernel code + 2,048 B reserved CCP-evicted-region structures (bank-table 174 B + active-pages 29 B + stub region 1845 B) = **5,552 B** vs NFR-P4-5 (≤8 KB @28-bank cap; ~6 KB @12 banks) — inside.
- **Dispatch latency (NFR-P4-2/3 final):** BANK! ≈425 T (incl ~22 T MMU port-write) vs re-baselined ≤400 T + MMU write; cross-bank call **0 T/NEXT** (RST-$28 stub, DR-2); intra-bank +1 JP vs flat (FR-P4-15).
- **Stub region: 0/461 used at boot** (reclamation is lifecycle).
- **Test surfaces at close:** Surface-1 `test-repl` 975/0/2 · Surface-2 `test-repl-banking` 62/0/3 + full isolated/CR/straddle battery green · Surface-3 silicon PASS per story (consolidated v3.0.7 batch pending, lead-gated).
- **Tags v3.0.1–v3.0.6 contiguous and verified;** v3.0.7 prepared, project-lead-gated.

## What went well

- **The (γ) descriptor-stub decision paid off across four epics.** One mechanism — a 4-byte fixed-memory stub keyed to a bank+CFA — became the substrate for EXECUTE dispatch (18), compiler-transparent `:` (19), self-dispatch (19.5), fat-pointer FIND (20), and lifecycle reclamation (21). A single well-chosen contract amortised enormously.
- **The Epic-19.5 interlude was the right call, made the right way.** When sentinel-trampoline dispatch proved layout-fragile, the response was a dedicated epic that *led with an ADR spike*, not code (per [[feedback_stabilisation_interlude]]). The ADR falsified three hypotheses (kernel-size-causal among them) and re-baselined NFR-P4-3 honestly. Result: 0 T/NEXT dispatch and a stable mechanism for the rest of the phase.
- **Hardware-smoke cadence (S9) caught real defects emulators hid.** 19.3.1 (bank-N CREATE bucket-skip + soft-EOF padding), DIV-1 (the `IN (0x72)` floating-readback bug — ports are write-only by design, [[project_div1_mmu_port_readback]]), and the banking→BIOS-MBB pivot all originated from silicon runs, not the emulator. The dual-surface + real-hardware discipline was load-bearing, not ceremonial.
- **Memory carried the hard-won gotchas across long gaps.** [[project_bank_table_clone_at_cold]], [[project_bank_triple_excludes_buckets]], [[project_div1_mmu_port_readback]], [[feedback_phase4_probe_bank_switch_limitation]] — each prevented a re-derivation or a false CR finding. The "verify empirically before fixing" discipline ([[project_bank_triple_excludes_buckets]]) saved at least 4 false-positive triple-corruption fixes.
- **Envelope discipline matured.** The ~2.4× empirical-vs-spec multiplier ([[project_epic17_envelope]]) became a planning tool; the Epic-20 retro refined it (a *mechanism substitution* voids the multiplier — re-derive from the new design). Every overage was itemised and dispositioned (SCP for design-substitutions, Dev-Notes accept-with-rationale for pure-additions).

## What didn't — challenges

- **Sentinel-trampoline dispatch was a false start.** Epic 18 shipped a mechanism that couldn't carry compiler-transparent banking; the layout-fragility only surfaced under Epic-19 compiled bodies. Cost: the entire Epic-19.5 interlude (+1 point release, +119 B). Mitigation lesson: a dispatch mechanism should be validated against the *hardest* downstream caller (compiled cross-bank body) before the epic that introduces it closes — not after.
- **Emulator/hardware divergence was a recurring tax.** BANK-MAPPING-OFF (port 0x74, [[project_phase4_banking_off_emulator]]), MMU port readback (0x70-0x73 write-only, the emulator wrongly modelled readback), and trampoline aliasing all diverged. Several verdicts were hardware-only. This is intrinsic to the target, but it slowed iteration.
- **Epic 20's FIND came in at 3.4× (+680 B)** — a design substitution (per-wordlist-bank-field → 24-bit fat header pointers) that voided the multiplier and required an SCP. Correctly handled, but a reminder that late mechanism swaps are expensive.
- **Tag application drifted from the mechanism.** v3.0.4 was held, then applied retroactively; several "tag deferred to user authorization" notes had to be reconciled. The banner-is-0 B precedent means silicon often ran an older banner than the tag implied — harmless but a bookkeeping smell.
- **The 24,995-vs-24,996 baseline drift persisted for the whole phase** before being resolved at the very last story. A 1-byte figure carried in memory unverified — small, but exactly the kind of unverified-inheritance the PD-2/B.4 discipline exists to prevent.

## Recurring review themes (across all 8 sub-tracks)

- **"Verify empirically before fixing" on the banking triple.** The per-bank triple is `(here, latest, wordlist-head)` only — the shared fat bucket array is NOT swapped. Most "triple corruption" CR findings were benign; reviewers learned to reproduce before patching ([[project_bank_triple_excludes_buckets]]).
- **EXX-hygiene / register-discipline at every raise site (S7).** Recurring CR catches: BC-clobber in SEMICOLON (19.2), BANK! IP-clobber (17.2), i*x preservation across caught THROW (18.5.1).
- **"Pre-existing" never discharged a correctness defect (S8).** DIV-1, the soft-EOF padding bug, and the EVALUATE saved-bank leak were all surfaced and fixed rather than accepted.
- **Probe authoring discipline (S12).** TIB-128 line limits ([[feedback_tib_size_inline_comments]]), 0x1A EOF termination ([[feedback_cpm_0x1a_eof_marker]]), bank-switch probe limitations ([[feedback_phase4_probe_bank_switch_limitation]]) — each cost a debugging session once, then became standing discipline.

## Previous-phase accountability (Phase 3 → Phase 4)

Phase-3 close (Lesson 14-F, [[feedback_ceremony_diminishing_returns]]) committed to *less ceremony, more mechanical sweeps* for the audience-of-one solo-dev context. Phase 4 honoured it: no new lints-on-lints; the verdict-table walk and three-surface sweep are mechanical checks, not bespoke tooling; debt-cleanup was framed as the explicit Epic-19.5 interlude rather than smuggled into feature epics. The 2.4× envelope multiplier replaced per-story byte-budget litigation.

## Standing-commitment S1–S12 hold-check (across Phase 4)

| # | Commitment | Hold | Evidence |
|---|---|---|---|
| S1 | Adversarial review in fresh-context CR | ✓ | Every binary-delta story ran CR post-dev-pass; 22.3 CR refuted 2 candidates; 19.5.2 CR fixed 7/18 |
| S2 | REPL-piped tests as default | ✓ | Entire banking corpus is REPL-piped .fth; no new assembly test threads ([[feedback_repl_tests_preferred]]) |
| S3 | Real-byte-count estimation + capstone-aware drafting | ✓ | Every story re-`wc -c` fresh (B.3); 22.4 resolved the 1-byte baseline drift |
| S4 | AC-composition validation | ✓ | create-story validated AC composition each epic; 22.4 AC2 corrected the stale planning enumeration |
| S5 | PARTIAL → HALT | ✓ | No partial mechanism shipped as "done"; 19→19.5 split rather than ship fragile dispatch; ABORT/QUIT restore (Epic 21) |
| S6 | Inventory grep covers helpers, not just leaves | ✓ | Migration sweeps (allocator, triple-swap helpers) grepped helpers; CR caught missing probes E/I/J (19.2) |
| S7 | EXX-hygiene per kernel-internal raise site | ✓ | BC/IP/i*x clobber fixes across 17.2/18.5.1/19.2 |
| S8 | "Pre-existing" cannot discharge correctness defects | ✓ | DIV-1, soft-EOF padding, EVALUATE leak all fixed not accepted ([[feedback_no_preexisting_discharge]]) |
| S9 | Mid-epic hardware-smoke cadence per story | ✓ | Per-story silicon PASS: 17.6, 18.5, 19.x, 19.5.2, 20.3, 21.3, 22.1/.2/.3 |
| S10 | workflow > memory > prompt | ✓ | Memory carried gotchas; workflow (dev-story/create-story/CR) drove every story |
| S11 | User-visible version-surface audit at tag close-out | ✓ | banner/README/memory aligned at each of v3.0.1…v3.0.7 (22.4 = final audit, doc-sync 0 drift) |
| S12 | Hardware-typed probe authoring discipline | ✓ | TIB-128, 0x1A-EOF, 5-helper-word recipe form (Lesson 17-F) standing |

**All 12 standing commitments held across Phase 4.**

## Carry-forward catalogue — Phase-5+ inputs (AC9; cross-referenced to `docs/WISHLIST.md`)

| Candidate | Why deferred | WISHLIST |
|---|---|---|
| **Multitasking** (`PAUSE`/`TASK`/`ACTIVATE`; bank = 1 byte of TCB seed from Epic-21 retro) | Cooperative scheduler is its own phase; the banking substrate (per-bank state) is now a natural TCB carrier | `# Multitasker` |
| **Semaphores** | Depends on the multitasker | `# Semaphores` |
| **ANS locals wordset** (`{: :}` / `VALUE`+`TO`) | Orthogonal to banking; a Core-Ext compliance push, not a Phase-4 banking goal | `# ANS Forth locals` |
| **`ALLOCATE` / per-bank heap (β)** | Heap-in-banks needs an allocator design; deferred from Phase-4 MVP (stub region is fixed-slot, not a heap) | `# Banked RAM awareness` |
| **MicroBeast hardware vocabulary (E.1)** — timer ISR / GPIO / LED matrix / beeper / UART / I2C / RTC | Hardware-driver layer, distinct from RAM banking; large surface | `# MicroBeast hardware vocabulary` |
| **`SEE` decompiler (E.4)** | Tooling; needs bank-aware traversal but no new mechanism | `# SEE decompiler` |
| **`TRAVERSE-WORDLIST` (E.5)** | Core-Ext word; bank-aware FIND (Epic 20) is the prerequisite, now shipped | `# TRAVERSE-WORDLIST` |
| **Z80 `IN`/`OUT` primitives (E.7)** | Deliberately omitted (page-port safety); revisit with the HW vocabulary | `# Z80 IO primitives` |
| **Turnkey compilation to standalone `.com` (E.8)** + **`STARTUP.FTH` auto-run** | Build/deploy feature; banking-independent | `# Turnkey compilation to .com binary`, `# STARTUP.FTH` |
| **Bigger input buffer / line-editing + history** | REPL UX; TIB-128 limit is a recurring friction ([[feedback_tib_size_inline_comments]]) | `# Bigger input buffer`, `# Line editing / command history` |
| **OO** | Large, speculative; no dependency yet | `# OO` |
| **Flat-build retention** | Deferred from Phase-4 MVP per redesign §4 (the banked build is the product; a flat fallback was descoped) | — |
| **Banked CODE words** (Phase-5 seed A1b) | 22.3 shipped fixed-memory-only CODE; the narrowed Phase-5 contract = a banked CODE word may loop within its own body + call fixed-memory/BIOS freely, may NOT absolute-jump into another bank's body (use stub/trampoline). Mechanism latent (extend descriptor-stub allocator to CODE bodies); raise as FR-P5-N | `# Banked RAM awareness` |

## Action items

- **AI-P4-1** Apply + push `git tag v3.0.7 <close-out commit>` (project-lead-gated). Owner: Ant.
- **AI-P4-2** Run + archive the consolidated Surface-3 HW smoke batch on the v3.0.7 binary. Owner: Ant.
- **AI-P4-3** At Phase-5 planning, file the banked-CODE-words contract (A1b) as FR-P5-N and the multitasker TCB-bank seed.
- **AI-P4-4** (optional, low) Validate a dispatch mechanism against its hardest downstream caller before the introducing epic closes — the lesson that cost the 19.5 interlude.

## Readiness assessment

Phase 4 is **complete and ready to close.** All 8 sub-tracks dev-passed and (per-epic) reviewed; emulator surfaces green; envelope reconciled and inside NFR-P4-5; verdict-walk complete (38/38 PASS); S1–S12 all held; both close-out retros authored. Outstanding = the two project-lead-gated items (tag + consolidated HW batch), both procedural rather than developmental. **antforth v3.0.7 is ready to ship.**

## Key takeaways

1. **One well-chosen contract amortises across a phase.** The 4-byte descriptor stub carried dispatch, compilation, lookup, and lifecycle. Design the substrate for full scope on day one ([[feedback_design_upfront]]).
2. **Validate a dispatch mechanism against its hardest caller before closing the epic that ships it** — the sentinel trampoline passed every Epic-18 test and still couldn't carry Epic-19 compiled bodies, costing a whole stabilization interlude.
3. **On this target, silicon is the final word.** Emulators hid DIV-1, the soft-EOF bug, and the OFF/readback divergences. The S9 per-story cadence was the single highest-value standing commitment.
4. **Verify before fixing on shared state.** The banking triple excludes the bucket array; "verify empirically" killed 4 false-positive corruption fixes ([[project_bank_triple_excludes_buckets]]).
5. **Itemise and disposition every byte at its own close.** SCP for design-substitutions, Dev-Notes accept-with-rationale for pure-additions; the phase close-out then sums, never re-litigates.
6. **Banking is delivered when it's invisible.** The phase's success metric is that user code never mentions a bank to call a banked word — `FIND`/`:`/`MARKER`/`ABORT` all just work across the full 512 KB.
