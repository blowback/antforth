# AntForth Banking Architecture for MicroBeast — Phase 4 Design

**Status:** Locked.
**Source:** `/bmad-party-mode` session, 2026-05-09 (session id `31ac37c9-c1c1-49aa-80e1-d290ce73f819`).
**Supersedes:** `docs/antforth-banking-design.md` (initial sketch dated 2026-05-07).

This document is the authoritative banked-RAM design for antforth Phase 4. Where it conflicts with the older `antforth-banking-design.md`, this document wins. The older doc is preserved with a `SUPERSEDED` banner for traceability of the design evolution; do not consult it for current decisions.

## 1. Wordset (12 words)

| Category | Word | Stack effect | Semantics |
|---|---|---|---|
| Core | `BANK@` | `( -- n )` | Current logical bank index. |
| Core | `BANK!` | `( n -- )` | Switch logical bank. `ABORT" bank?"` if `n` is not in the active list. `THROW -273` on a foreign-bank switch from window-resident code (caller IP `$8000..$BFFF`) — see §5.4 portal-window guard (Story 19.5.1). |
| Core | `BANKS` | `( -- n )` | Count of available banks (a `VALUE`, derived from list length). |
| Core | `IN-BANK` | `( n xt -- )` | Execute `xt` with bank `n` active; restore prior bank on exit; `CATCH`-safe. **Kernel-blessed** (not a user library word). Reference body: `: IN-BANK BANK@ >R SWAP BANK! EXECUTE R> BANK! ;`. |
| Introspection | `BANK-OF` | `( xt -- n )` | Bank a word lives in (`-1` for fixed memory). One-byte read from the descriptor stub at `xt+1` (byte 1 = signed `target_bank` under stub layout v2; byte 0 is `$EF`/`RST $28`) — essentially free under the (γ) mechanism. |
| Introspection | `.BANKS` | `( -- )` | Print summary table (logical-#, physical page, current marker, used/free per bank, total). |
| Configuration | `+BANK` | `( page -- )` | Add a physical page to the available list. **Probe-on-add** verifies it is RAM (rejects ROM / unmapped pages); `ABORT`s if probe fails. |
| Configuration | `-BANK` | `( page -- )` | Remove a page from the active list. |
| Configuration | `BANKS-CLEAR` | `( -- )` | Empty the list (lets user rebuild from scratch in startup config). |
| Low-level | `SET-BANK` | `( page slot -- )` | Raw MMU port write; kept for diagnostics. |
| Low-level | `BANK-MAPPING-ON` | `( -- )` | Enable mapping hardware. Auto-run in `COLD`. |
| Low-level | `BANK-MAPPING-OFF` | `( -- )` | CP/M warm-boot escape via BIOS WBOOT (`JP $0000`). Does NOT write the MMU bit — kernel-resident port-0x74 write disconnects RAM mid-instruction-fetch (Story 17.1 AC10 hardware finding). |

**Replaces** the obsolete doc's `USER-BANK / USER-BANK@ / SET-BANK / ENABLE-MAPPING + THUNK-TO-USER-BANK*` family. The `USER-` prefix is gone (only one kind of user-controllable bank exists, so the prefix was noise). The `BANK@ / BANK!` pair mirrors the established `BASE @ / BASE !` idiom — getter/setter for ambient state.

The user-typed `THUNK-TO-USER-BANKn` family is **deleted**. Cross-bank calls are compiler-emitted and transparent (see §3).

## 2. Architectural decisions (Greek-letter shorthand)

The session used Greek-letter labels for decision options under specific architecture-question subheads. Two distinct sets appear; do not conflate them.

### 2.1 S6 — `EXECUTE` across banks (the (γ) decision)

Three options were named for how an `xt` carries bank information:

- **(α) Side-table mapping `xt → bank`.** Rejected — awkward to maintain on `FORGET`.
- **(β) 24-bit `xt`.** Rejected — breaks the Forth-standard cell-as-address invariant.
- **(γ) Fixed-memory descriptor stubs.** ★ **CHOSEN.** Every banked word, when defined, also gets a 3–5-byte stub in fixed memory containing `(target_bank, target_addr_in_bank)`. **The stub's address is the word's xt.**

Why it matters: **(γ) collapses S1 (cross-bank EXIT) + S6 (`EXECUTE`) + S7 (`COMPILE,`) into one artifact.** Single most important design call in the banking effort. Endorsed by Ant during the session.

> **Stub layout v2 (Story 19.5.2 / ADR 19.5 DR-2):** the shipped 4-byte stub is **self-dispatching** — `[$EF = RST $28][target_bank][target_addr.lo][target_addr.hi]`. `NEXT`'s blind `JP (HL)` and the folded 4-byte `EXECUTE` both land on byte 0; the `RST $28` vectors through `$0028` (COLD-installed `JP stub_dispatch`) to the kernel handler, which takes the intra path (same bank or `$FF` fixed-memory marker: `HL ← target CF`, `JP (HL)`) or the cross path (2-cell R-stack frame `(caller_bank, caller_IP)`, `DE ← xbank_thunk`, MMU switch, `JP` target CF). 0 T-states added per thread step for non-stub words (NFR-P4-1 by construction).

> **Compiled-body dispatch verified 19.5.3 (status append, no history rewrite).** Story 19.5.3 re-expressed the 19.5.2 EXECUTE-form witnesses in genuine **compiled-body** form — a banked word dispatched through `NEXT`'s `JP (HL)` from a thread cell in another word's parameter field, not via a runtime `EXECUTE` of a stack value. FR-P4-15 (intra-bank, probe-19.5.3-ac2) and FR-P4-16 (cross-bank from bank 0, the north-star case, probe-19.5.3-ac3) confirmed PASS under `iz-cpm-banking`; the cross-bank case returns through `xbank_thunk`/`xbank_restore` with the caller's bank restored. Source-syntax by-name (`: CALLER ... BANKED-WORD ... ;` for a bank-N callee referenced from bank 0) still awaits the Epic-20 bank-aware FIND (§5.5) — the probes inject the portable stub-xt via the `[ COMPILE, ]` idiom, exercising the dispatch path byte-identically.

### 2.2 S1 — Cross-bank EXIT (the (b) sentinel decision — SUPERSEDED)

The obsolete doc proposed a `BIT 7,H` heuristic on the return-address high byte to detect cross-bank returns. **Broken** — user code lives at $8000-$BFFF, so bit 7 is always set on every user-code return-address; the heuristic detects nothing.

**(b) as shipped at Epic 18:** sentinel-tagged returns. Intra-bank returns push 1 cell (zero overhead). Cross-bank returns push three cells: `(sentinel_addr, caller_bank, target_addr)`. A single `cross_bank_return` trampoline in fixed memory restores the caller's bank then jumps to the target. The sentinel is a fixed-memory address recognised by `EXIT`.

> **SUPERSEDED by ADR 19.5 DR-2 (Story 19.5.2).** The sentinel contract assumed a DOCOL/EXIT pair in every cross-bank callee — non-DOCOL targets (`VARIABLE`/`CREATE` references, Probe-19.3-F) hung. Option C replaces it: the **dispatch site** (`stub_dispatch`'s cross path) pushes a 2-cell frame `(caller_bank, caller_IP)` and pre-loads `IP = xbank_thunk` (one fixed-memory thread cell → `xbank_restore`). DOCOL targets return through their terminal EXIT popping the thunk-IP; DOVAR/DOCON/DEFCODE targets `NEXT` directly with the thunk-IP — **one uniform return path for every target shape**. `EXIT` is back to plain pop + NEXT (FR-P4-19 exact); the sentinel discriminator, the trampoline, and EXECUTE's 3-way are deleted. Cross-bank R-stack pressure drops from 3+1 cells to 2 per nesting level (the FR-P4-21 gotcha improves from 4× to 2× the intra-bank rate).

### 2.3 ALLOCATE futures (separate (α) (β) (γ′) reuse — Phase 5+)

The Greek labels reappear in a future-proofing sketch for ALLOCATE/heap design. Distinct from the S6 letters above. **Recommended future direction:** (β) per-bank heap with a `BANK-OF-ALLOC` helper. Not Phase 4 scope.

## 3. Cross-bank call mechanism

**Compiler-emitted, transparent.** `COMPILE,` always emits the stub address (xt). The stub itself decides intra-bank vs cross-bank dispatch at run time. From a user's vantage: type `5 BANK!`, then define and call words like always — banked `:` is **indistinguishable from flat `:`**. Existing programs run unmodified.

The `COMPILE,` mechanism does not need to know whether the target is in the same bank as the call site. The stub handles it — **literally, post-Story-19.5.2**: the stub's own `RST $28` byte performs the dispatch via the kernel `stub_dispatch` handler. This means:

- Same-bank call (or `$FF` fixed-memory target): handler loads the target CF from stub bytes 2..3 and `JP (HL)`s — the dispatch cost is the RST + handler intra path (~107 T, cheaper than the retired EXECUTE 3-way's intra path).
- Cross-bank call: handler pushes the 2-cell return frame `(caller_bank, caller_IP)` on the R-stack, sets `IP = xbank_thunk`, switches the MMU to the target bank, and jumps to the target CF. The return routes through `xbank_restore` (bank + IP restore) uniformly for DOCOL and non-DOCOL targets.

The user-visible thunk word from the obsolete doc (`5 THUNK-TO-USER-BANK5 GRAPHICS-APP`) is deleted.

> **Behaviourally delivered — verified 19.5.3.** The "define and call words like always" north-star above is proven on the emulator in compiled-body form: FR-P4-15/16 compiled-body dispatch (probe-19.5.3-ac2/ac3), FR-P4-25 non-DOCOL (DOVAR) cross-bank dispatch+return and intra-bank CREATE/DOES> (re-enabled probe-19.3-F/G), and the full banked NFR-P4-8 CATCH-cross-bank state-integrity variant (probe-19.5.3-ac6 — caught THROW after a real `BANK!` leaves HERE/LATEST/wordlist_head and both banks' tables clean). Documented limits remain Epic-owned: cross-bank-from-bank-N bodies and cross-bank DOES> bodies are the DR-1 portal-aliasing hazard (§5.5, Epic 20); the cross-bank `@` data read is the FR-P4-26 doc-and-pray pointer hazard (§5.4).

## 4. Conditional compilation / flat build

**Phase 4 scope: banked build only (MVP).** Flat-build retention is a Phase-5+ option, not an MVP gate. Phase 4 stories should not slow down to preserve flat-build compatibility.

The obsolete doc's "same source, different binaries" story is preserved as a future direction but is not a Phase-4 deliverable. Specification of flat-build semantics for the new 12-word set is deferred to Phase 5 (or whenever flat-build re-emerges as a priority).

## 5. Memory layout

### 5.1 Page-allocation map

```
0x20-0x21  slot 0/1 default content       kernel — fixed, not bankable
0x22       slot 2 default content         ★ DEFAULT BANK 0 (the "portal page", reclaimed)
0x23       slot 3 default content         stacks/user/CCP-eaten/BDOS/BIOS — fixed
0x24       virtual console buffer         reusable (trades VC for one extra bank)
0x25-0x34  RAM disk (16 pages)            reusable (trades RAM disk for 16 extra banks)
0x35-0x3F  default user banks (11)        ★ DEFAULT BANKS 1-11
```

**Default 12 banks × 16 KB = 192 KB user RAM.**
**Theoretical max 29 banks × 16 KB = 464 KB** (sacrificing VC + RAM disk).

### 5.2 CP/M residency layout (fixed memory, Page 3)

```
$D400-$DBFF  CCP    DISPOSABLE — eaten for +2 KB Page 3 (Ant: "ja throw CCP out")
$DC00-$E9FF  BDOS   must stay; CALL 0005h works unchanged from banked code
$EA00+       BIOS   IM 2 vector table; BIOS work area; BIOS stack
```

Eviction of CCP yields +2 KB. BDOS calls work unchanged from banked code (`CALL 0005h` lands in fixed memory).

### 5.3 ISR invariant

No banked code is reachable from an interrupt vector. ISR bodies live in fixed memory only.

### 5.4 Per-bank state (S2 resolution)

Each bank carries its own `(here, latest, wordlist-heads)` triple in a fixed-memory `bank-table[]`, swapped on `BANK!`. Cross-bank pointer hazards (e.g. holding a `HERE` value from one bank then `BANK!`-ing to another) are accepted as "doc-and-pray" — documented gotcha, no runtime guard.

**Portal-window guard (Story 19.5.1, ADR 19.5 DR-1 fix F1).** `BANK!`
raises `THROW -273` (`THROW_BANK_FROM_BANKED`, "bank switch from banked
code") when a foreign-bank switch is attempted from window-resident
code — caller IP in `$8000..$BFFF` — **before** any MMU or state
mutation. Rationale: a threaded body physically resident in the slot-2
window keeps fetching its cells from whatever page is mapped; switching
the page under itself aliases subsequent fetches onto the foreign page
(the DR-1 corruption class — opcode soup or `JP $0000` warm boot).
Same-bank switches from window code stay legal, as does every
interactive `BANK!` (the outer-interpreter EXECUTE chokepoint keeps IP
in kernel space). *Residual exposure (documented limit):* the guard
checks the caller IP only — the address of the cell **after** the
invoking `BANK!` xt (NEXT has already advanced IP), which is exactly
the cell the post-swap NEXT would fetch from the foreign page. A
bank-0 body whose post-`BANK!` cell sits below `$8000` but whose later
cells straddle into the window still corrupts (R-stack walking
rejected on cost); conversely a `BANK!` xt cell at `$7FFE` IS guarded
(its next-fetch address is `$8000`). The residual class is pinned as a
regression signature by `make test-straddle-regression`
(tests/straddle_repro_sweep.sh, K=0).

**Page-resident-from-first-byte (Story 19.5.1, fix F2 — the re-landed
19.2-H5).** COLD initialises `bank-table[1..28].here = $8000`, so every
bank-N>0 dictionary starts at the window base: banked bodies occupy
their own page from byte 0, never straddle the `$8000` boundary, and
never alias once dispatch enters them with their own page mapped.
LATEST/wordlist-head clone semantics are unchanged (kernel words remain
findable from bank N).

### 5.5 Bank-aware FIND (S3 resolution)

Each wordlist gets a `bank` field. `FIND` saves current bank, switches, walks the chain, restores. System wordlists (FORTH, ASSEMBLER) are tagged `bank=fixed` so the common case incurs no MMU switch.

**INTERIM GOTCHA (until Epic 20 / story 20-1 lands).** The hash-bucket
chains are shared across banks (only `here`/`latest`/`wordlist_head`
swap on `BANK!`), and FIND walks them under whatever page is mapped.
Once the bank-0 dictionary has grown past `$8000`, its chains contain
window-resident entries; any token lookup while a foreign bank is
mapped can walk such a chain into the window and read the foreign page
— the DR-1 aliasing mechanism on the *lookup* path (observed at the
19.5.1 dev-pass: interactive `1 BANK!` then any word → `-13` strand;
retro-explains 19.3.1 Defect-2). The F1 `BANK!` guard (§5.4) covers
only the threading path; until the per-wordlist bank field ships,
interpret across a `BANK!` cycle only while the bank-0 dictionary is
below `$8000`, or restrict foreign-bank interpretation to kernel words
(the isolated-fixture discipline in tests/banking_tests_19_5_1.fth).

### 5.6 ABORT/QUIT bank-state restore (S5 resolution)

`QUIT` re-asserts the saved current-bank — the last value set by interactive `BANK!` from the outermost interpret loop. So an `ABORT` mid-execution doesn't strand the user in a wrong bank.

## 6. Boot configuration

**Command-line:** `antforth 24 35-3f` (the user's example: 24 = 0x24 portal page, 35-3f = banks 0x35 through 0x3F). Defaults to `22 35-3F` if absent. Probe-on-startup rejects bad pages with one-line warnings.

`STARTUP.FTH` was rejected as the configuration mechanism because it cannot run before the boot banner — bank availability needs to be known at banner-print time.

## 7. Performance & memory budgets

| Item | Budget |
|---|---|
| Cross-bank call overhead | ~60 T-states + bank-switch time |
| Stub size (per banked word) | 3 bytes minimum, 4–5 bytes realistic with `JP` opcode |
| Per-1000-words stub cost | 4–5 KB fixed memory |
| Total banking infrastructure | ~6 KB fixed memory worst case (default 12 banks); ~7–8 KB at 28-bank cap |
| Fixed-memory headroom over current 24 KB antforth.com | ~8 KB — banking fits, "not by miles, fits" |
| CL parser + probe loop | ~200 bytes |
| Configuration words (`+BANK`/`-BANK`/`BANKS-CLEAR`) | ~120 bytes total |
| `FIND` cross-bank cost | ~20 T-states + chain-walk per missing-from-FORTH lookup; "interactive use, invisible; batch loading slower by ~5–15%" |
| Bank-state-table size cap | 29 entries × ~16 B = ~448 B worst case |

## 8. Phase-4 epic structure

Phase 4 = banking. Estimated 25–30 stories across 7 epics:

| Epic | Theme | ~Stories |
|---|---|---|
| **16 — Memory map & doc lock (prework)** | H1 memo, page-allocation survey, CCP overwrite policy, IM 2 confirmation, doc rewrite (this document); 16.3 = emulator-vendor selection (banking-capable, alongside iz-cpm) | 3–4 |
| **17 — Bank primitives + CL config** | All 12 wordset words; `+BANK`/`-BANK`/`BANKS-CLEAR`; command-line parser; probe-on-add; banner update; hardware spike: cross-bank call on iron | 5–6 |
| **18 — Stub mechanism (γ) + cross-bank EXIT (S1 b)** | Per-word descriptor stubs; sentinel-trampoline return; kernel `EXECUTE` switch; `BANK-OF`; `IN-BANK` | 4–5 |
| **19 — Bank-aware compiler** | Per-bank `HERE`/`LATEST`; `,` and `COMPILE,` writing into target bank; `:` lands body in current bank; stub auto-emitted; **`CREATE`/`DOES>` cross-bank explicit** (PFA stores doer-stub address + data cell) | 4–5 |
| **20 — Bank-aware FIND + interpreter loop** | Wordlist `bank` tagging; `FIND` traversal; `WORDS`; error messages | 3–4 |
| **21 — `MARKER`/`FORGET` + ABORT/QUIT bank state (S5)** | Per-bank dictionary tail tracking; saved-bank restore on `ABORT` | 2–3 |
| **22 — Polish** | `.BANKS`; REPL prompt indicator; CODE-words-in-banks decision; test-harness sweep | 3–4 |

### 8.1 Phase-4 prework gate

**Must close before story-writing in Epic 17 onwards:**

1. **Banking-capable emulator selection.** iz-cpm does not support banking. Phase 4 needs a banking-capable emulator running dual-track alongside iz-cpm (so existing 1000-test baseline continues passing while banking work proceeds). Ant's responsibility; vendor research outstanding.
2. **Doc rewrite.** Closed by this document.

### 8.2 Phase 5+ shape (out of scope for Phase 4)

The session future-proofed banking against multitasking, locals, and ALLOCATE — confirmed no corners painted:

- **Phase 5 — Multitasking** (bank = 1 byte of TCB; stubs/sentinels ride preemption cleanly).
- **Phase 6 — Semaphores** (depends on multitasking).
- **Locals** — all three styles (`{: a b -- c :}`, `VALUE`/`TO`, etc.) compatible with banking design.
- **ALLOCATE** — recommended (β) per-bank heap when the day comes.

## 9. Open questions for Phase-4 architecture

The session left these unresolved. They are inputs to the Phase-4 Architecture document (not the PRD) — capture as `TODO(P4-arch)` items there, or as Epic-16 spike stories.

1. **CODE words in banks.** Can user-defined CODE (assembler) words live in banks? Affects S7 dispatch. Epic 22 was left ambiguous.
   **Closed by Story 16.4, 2026-05-14, fixed-memory-only; see `_bmad-output/planning-artifacts/architecture.md` PD-P4-15.**
2. **Banking-capable emulator vendor pick.** Ant's research outstanding. Three eval criteria pinned: models 32-page MMU at ports 0x70+slot/0x74; pipe-able; bank-visibility for tests.
   **Closed by Story 16.3, 2026-05-13, vendor = `iz-cpm-banking` (blowback/iz-cpm fork @ `1777a85`); see `_bmad-output/planning-artifacts/architecture.md` F1 closure.**
3. **CL parser edge cases.** Listed in session: no args, bad token, reverse range, dup, probe-fail, empty surviving list. Final policy for each not signed off.
   **Closed by Story 16.4, 2026-05-14, warn-and-continue across all six edge cases (never abort the boot); see `_bmad-output/planning-artifacts/architecture.md` PD-P4-14.**
4. **Bank-state-table cap (29 entries).** ABORT-on-`+BANK`-past-cap policy not formally specced.
   **Closed by Story 16.4, 2026-05-14, `+BANK` past cap raises `ABORT" cap?"`; see `_bmad-output/planning-artifacts/architecture.md` PD-P4-13.**
5. **Stub size: 3 vs 4–5 bytes.** Final size pinning not done. Affects per-word cost calculations.
   **Closed by Story 16.4, 2026-05-14, 4 bytes — `(target_bank: 1B) + (JP target_addr: 3B)`; see `_bmad-output/planning-artifacts/architecture.md` PD-P4-11.**
6. **Recursive cross-bank R-stack overflow.** Documented gotcha or runtime guard? No FR or limit defined.
   **Closed by Story 16.4, 2026-05-14, documented-gotcha (standard `-5 RETURN-STACK-OVERFLOW` THROW; no runtime guard); see `_bmad-output/planning-artifacts/architecture.md` PD-P4-12.**
7. **Flat-build semantics for the 12-word set.** Resolved by project-lead direction 2026-05-10: flat build is non-MVP for Phase 4. Specification deferred to Phase 5+.
