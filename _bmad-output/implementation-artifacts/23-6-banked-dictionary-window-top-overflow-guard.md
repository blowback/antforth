# Story 23.6: Banked dictionary window-top overflow guard

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Expanded 2026-06-28 by create-story workflow (context-engine pass) from the
     2026-06-28 STUB drafted out of the Story 23.2 code-review finding #5. The
     stub's "Problem" analysis is LOAD-BEARING and was re-verified against live
     source at this expansion (B.4 / PD-2 figure-drift discipline — every cited
     file:line below was re-read on 2026-06-28, not transcribed from the stub).

     This story is NOT in the epic file. Epic 23 in
     epics-phase5-epic-23.md ends at Story 23.5 (close-out). 23.6 was appended to
     sprint-status.yaml AFTER 23.5 from the 23.2/23.3 review. Consequence: the
     v3.1.0 close-out gate (23.5) and this story are BOTH open; sequencing is a
     project-lead call (see "Sequencing vs Story 23.5" in Dev Notes). The epic's
     FR inventory does not cover this; the requirement source-of-truth is the
     review finding distilled below, plus the carried-forward Phase-5 constraints
     (S1–S12) in epics-phase5-epic-23.md:96-118.

     DESIGN CALL RESOLVED AT EXPANSION (the stub deferred it):
     The stub asked (a) one check in build_header vs (b) a check at each
     HERE-advancing primitive. Verified at expansion that NO single subroutine
     funnels every HERE advance — build_header, the four doer code-field emits,
     and ,/C,/ALLOT/COMPILE, each do their own LD HL,(here) … LD (here),HL. So:
       • (a)-only is INSUFFICIENT — it cannot bound a colon (`:`) body, which
         grows AFTER build_header via COMPILE, and , (compiler.asm:439-441,
         485-497; memory.asm:217-229). A long banked colon body silently crosses
         $C000 → the doer/NEXT reads body cells through slot 3. The stub's own
         hazard statement ("broken at execution time … any body byte") names
         exactly this case.
       • CHOSEN: a shared `check_banked_headroom` helper (the stub's sketch),
         called from BOTH build_header (covers every defining word's header +
         fixed code field, incl. CREATE/CONSTANT/VALUE/`:`) AND the four
         dictionary-growth primitives ,/C,/ALLOT/COMPILE, (covers colon-body
         growth + raw CREATE…ALLOT/`,` building). One mechanism, ~5 call sites,
         all bank-0-exempt. This is the "deepest single mechanism" the stub asked
         for, given there is no single routine to bolt it to. Do NOT regress this
         to a VALUE-only or build_header-only guard — both were considered and
         rejected here (and the VALUE-only shape was explicitly rejected in the
         23.2/23.3 review). -->

## Story

As a **MicroBeast Forth programmer building a banked dictionary**,
I want **a banked definition (or raw dictionary growth) that would place any byte
at or past the slot-2 window top (`$C000`) to raise a clean `-8` dictionary
overflow THROW**,
so that **I never get a silently-corrupt banked word that reads/writes a stray
high byte through slot 3 (wrong bank / fixed memory) with no diagnostic.**

## Context — the defect (verified live 2026-06-28; do NOT re-discover)

The banked dictionary lives in the slot-2 window `$8000..$BFFF` (16 KB; banking.asm
comment at `src/banking.asm:843` — "banks N≥1 are slot-2 windows (base $8000,
ceiling $C000)"). Defining words place a word's code field at the live banked
`HERE` and emit the body just above it:

- `CONSTANT` → `JP DOCON` + value cell at `cf+3` (`src/compiler.asm:889-924`)
- `VALUE` → `JP DOVALUE` + value cell at `cf+3` (`src/compiler.asm:950-988`)
- `CREATE` → `JP DOVAR` + 2-byte does-slot at `cf+3..4` (`src/compiler.asm:842-871`)
- `:` → `JP DOCOL`, then a threaded body that grows upward via `COMPILE,` / `,`
  (`src/compiler.asm:527-570`, `485-497`; `src/memory.asm:217-229`)

The runtime doers read the body **through slot 2 only**: `DOCON`/`DOVALUE` read
`cf+3` (`src/inner_interpreter.asm:81-107`; `DOVALUE` is `JP DOCON`), and `(TO)`
writes `cf+3` via `to_resolve_map_hl`, which maps **slot 2** alone
(`src/compiler.asm:1086-1170` → `mbb_set_slot2`, `src/banking.asm:124-125`). A
banked colon word executes with slot 2 mapped to its home bank and `IP` walking
the body; `NEXT` fetches each xt cell through slot 2.

**The hazard:** if `cf+3` (or any code-field / body byte) lands at or past
`$C000`, that address resolves through **slot 3** — whatever page is mapped there
(wrong bank / fixed memory). Result: a banked word that reads or writes a corrupt
high byte, or a colon body whose threading derails, **with no diagnostic.**

**There is currently NO bound on banked `HERE`.** A search of the defining path
finds no dictionary-full / window-top check and no `-8` THROW. The `$C000`
literal at `src/banking.asm:870` (`LD BC, SLOT2_WINDOW_BASE + 0x4000`) is only
`.BANKS` free-space *display*, not a guard. The exposure is real, general to every
banked defining word **and** to raw `,`/`C,`/`ALLOT` growth, and silent — it just
requires a bank filled to within a few bytes of `$C000`.

This is a **pre-existing** gap (NOT introduced by 23.2/23.3); it was finding #5 in
the 23.2/23.3 code review. The review already landed the companion fixes
(VALUE/CREATE/`;` re-keyed to `triple_owner`; the `alloc_doer_stub` helper at
`src/compiler.asm:798-832`; the `ASSERT STUB_ALLOC_BASE >= 0xC000` build assert at
`src/compiler.asm:1109`). This story is the remaining deferred item.

**Why this is a correctness defect, not an "accept-with-rationale":** silent
straddle = lost/corrupt write. Per S8 (`feedback_no_preexisting_discharge`) and
`feedback_no_accept_disposition_for_bugs`, "pre-existing" does not discharge it —
surface and fix.

## Acceptance Criteria

**AC1 — Defining words refuse a straddle (`-8`).** On a bank `N≥1`, a defining
word (`CONSTANT`, `VALUE`, `CREATE`, `:`) whose header + code field + immediate
body would place any byte at or past `$C000` raises `-8` (dictionary overflow)
**before committing** — `HERE`, `LATEST`, and the hash bucket are left unchanged
(no half-built header, no orphaned bucket link), the value-stack inputs are
consumed per each word's existing zero-length-name precedent, and the interpreter
stays live. A word whose final byte is exactly `$BFFF` is **accepted** (boundary:
the one-past-end `HERE` may equal `$C000`; THROW only when a byte would be written
**at or above** `$C000`).

**AC2 — Colon-body growth refuses a straddle (`-8`).** A banked `:` definition
whose body grows across `$C000` via the compiler (`COMPILE,` for compiled xts, `,`
for literals/data) raises `-8` at the offending cell write, not silently. (This is
the case `build_header`-only cannot catch — see the design note in the header
comment.)

**AC3 — Raw dictionary growth refuses a straddle (`-8`).** `,`, `C,`, and `ALLOT`
on a bank `N≥1` raise `-8` when the requested advance would write a byte at or
past `$C000` (e.g. `CREATE X  $5000 ALLOT` on a near-full bank). `COMPILE,`
likewise (it is the colon-body path of AC2 and the same call site).

**AC4 — Bank 0 is unaffected (guard is a strict no-op there).** When
`triple_owner == 0` (bank 0 = fixed memory, no slot-2 window), the guard returns
immediately and changes nothing: fixed-memory `HERE` legitimately runs past
`$C000` up toward the active-pages / stub-allocator region (`STUB_ALLOC_BASE =
$D4CB`, `src/constants.asm:25`), and every existing bank-0 definition / `ALLOT` /
colon body must behave byte-for-byte as before. (No fixed-memory dictionary-full
guard is added — out of scope.)

**AC5 — `-8` is a first-class THROW code.** `THROW_DICT_OVERFLOW EQU -8` is added
to `src/constants.asm` (ANS Forth 1994 §9.3.5, "dictionary overflow"); a
`-8 / "dictionary overflow"` row is added to `throw_desc_table` in
`src/exception.asm` (so an uncaught `-8` prints `: dictionary overflow`); and the
raise uses the kernel-internal entry `JP w_THROW_cf.kernel_entry` with primary-set
`BC` per the existing contract (`src/exception.asm:398`, `:288-296`). `CATCH` of
the offending operation yields `-8`.

**AC6 — Existing gates stay green; binary delta within envelope.** The full
Phase-4 baseline (975 PASS / 0 FAIL · 61/0 · isolated-banking variants · straddle
3/3 · file-sanity) plus the Phase-5 probes (23.1–23.4) stay green on iz-cpm +
iz-cpm-banking. Binary delta vs the re-`wc -c` dev-pass baseline is recorded and
justified against the itemised byte budget below (CCD-4 logging; S3).

**AC7 — New regression probe (the load-bearing deliverable).** A new
banking-probe test (`tests/banking_tests_23_6.fth` + a `make test-repl-...` witness
target, mirroring `test-repl-ud-env` / `test-repl-value-to`) drives a bank's
`HERE` to within a few bytes of `$C000` and asserts `-8` for: (a) a defining word,
(b) a colon body that crosses, (c) a raw `ALLOT`/`,`; plus the **acceptance**
boundary (a word ending exactly at `$BFFF` succeeds) and a **bank-0 control** (the
same near-top operation in bank 0 does NOT throw). Each asserted via a printed
`PASS:` / `INFO:` witness grepped by the Makefile (S2; per
`feedback_phase4_probe_bank_switch_limitation` + `feedback_banking_probe_straddle_halt`
— interpret-level orchestration, printed witnesses, no late colon-body straddle).

**AC8 — Docs/compliance updated.** `docs/throw-codes.md:82` (`-8 | dictionary
overflow | no | —`) is flipped to `done — Story 23.6` with the `banking.asm`
site; `docs/ans-forth-core-compliance.md:52` (the §9.3.5 implemented-subset row)
adds `-8`; `make check-doc-sync` clean-pass.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in Dev Notes
  - Do NOT inherit a prior number. The expansion observed **28,947 B** at HEAD
    `5b4baba` (Story 23.4) on 2026-06-28, but re-`wc -c` the actual current build
    artifact — it is the load-bearing baseline (B.3 / Lesson 13.5-F; cf. Story
    13.5.5 close-out 6-byte doc-drift).
- [x] Capture current `make test-repl` baseline pass count (expect 975/0) and run
  `make test-repl-banking test-straddle-regression test-file-sanity` once green to
  confirm a clean starting point.

### Task 1 — THROW code + description (AC5, AC8)

- [x] Add `THROW_DICT_OVERFLOW EQU -8   ; ANS Forth 1994 §9.3.5` to
  `src/constants.asm` (it currently jumps -4 → -10 at lines 140-141; insert the
  -8 row in numeric order with the others).
- [x] Add a row to `throw_desc_table` (`src/exception.asm:824`), inserted in the
  existing rough code-order between the `-4` (stack underflow) and `-10` (division
  by zero) rows:
  ```asm
          DW      THROW_DICT_OVERFLOW     ; -8
          DB      19
          DB      "dictionary overflow"
  ```
  (Count the bytes: `"dictionary overflow"` = 19 chars — the `DB len` must match,
  per the table contract at `src/exception.asm:626`. Re-count at edit time; do not
  trust this figure blind — PD-2.)
- [x] `docs/throw-codes.md:82`: flip the `-8` row from `no | —` to
  `done — Story 23.6 | banking.asm (check_banked_headroom)`.

### Task 2 — Shared guard helper (AC1–AC4)

- [x] Add `check_banked_headroom` to `src/banking.asm` (near the other slot-2 /
  bank helpers). Contract — `( HL = prospective one-past-end address -- )`:
  - No-op when `triple_owner == 0` (bank 0): `LD A,(IY+UserArea.triple_owner) / OR
    A / RET Z`.
  - Else THROW `-8` when a byte would be written at or above `$C000`, i.e. when
    the prospective one-past-end `HL > $C000` (a word ending exactly at `$BFFF`
    has one-past-end `== $C000` and MUST pass — get the boundary right; the stub's
    `CP 0xC0 / RET C` sketch throws at `== $C000` too, which is off-by-one
    conservative and would refuse a perfectly-fitting last byte). Implement the
    `> $C000` compare (e.g. via `EX DE,HL / LD HL,$C000 / SCF / SBC HL,DE` or an
    equivalent that treats `$C000` as the inclusive legal ceiling for one-past).
  - Raise: `LD BC, THROW_DICT_OVERFLOW / JP w_THROW_cf.kernel_entry` (primary-set
    BC contract — see `src/exception.asm:288-296`, `:398`).
  - Document the clobber set; keep it small (callers on the `,`/`COMPILE,` hot
    path must not need a heavy spill — see Task 3 EXX/spill notes).

### Task 3 — Wire the guard at every banked HERE-advance (AC1–AC4)

- [x] **`build_header`** (`src/compiler.asm:137`): after the name is parsed and
  `bh_name_len` is known (`.bh_scan_done`, ~`:230-237`) and **before any header
  byte / hash-bucket / LATEST write is committed**, compute the prospective
  one-past-end of the worst-case defining word:
  `prospective = HERE + header_overhead + name_len + DOER_RESERVE`, where
  `DOER_RESERVE = 5` (the largest fixed code-field+immediate-body among the doers:
  CREATE/CONSTANT/VALUE each emit `JP doer` (3) + 2-byte body = 5; `:` emits 3).
  Determine `header_overhead` from the actual header layout build_header writes
  (hash-link + count_flags + name + reserved CFA/stub cell) — read the tail of
  `build_header` (`:258`-end) to get the exact byte count; do not guess. Call
  `check_banked_headroom`. On THROW the early-return contract leaves HERE/LATEST/
  bucket untouched (the check precedes every commit) — verify this by reading
  where the first header byte is actually stored.
  - This single site covers the header + fixed code field of **all** build_header
    consumers: `CONSTANT`, `VALUE`, `CREATE`, `:`, `MARKER`. (`CODE`/`LABEL`: see
    Task 5 scoping — CODE bodies are routed to fixed memory by Story 22.3, so the
    assembler's opcode-emit path is out of scope; confirm.)
- [x] **`,`** (`w_COMMA_cf`, `src/memory.asm:217`): before the cell store, call
  the guard with prospective `HERE + 2`.
- [x] **`C,`** (`w_C_COMMA_cf`, `src/memory.asm:242`): prospective `HERE + 1`.
- [x] **`ALLOT`** (`w_ALLOT_cf`, `src/memory.asm:195`): prospective `HERE + n` (n =
  TOS). Note ALLOT already computes `HERE + n` in HL — guard there.
- [x] **`COMPILE,`** (`w_COMPILE_COMMA_cf`, `src/compiler.asm:485`): prospective
  `HERE + 2` (this is the load-bearing colon-body site for AC2).
- [x] Mind the register/EXX context at each site: `,`/`C,`/`ALLOT`/`COMPILE,` run
  in the main register set with `BC = TOS`; the guard must preserve whatever each
  site needs after the call (HL is reloaded/recomputed at each anyway). The doers
  (CREATE/CONSTANT/VALUE/`:`) are EXX'd when they call build_header — the guard
  fires inside build_header before EXX restore, and raises via the THROW kernel
  entry which has its own EXX/primary-set contract; verify EXX hygiene per S7.

### Task 4 — Regression probe (AC7) — the load-bearing deliverable

- [x] Create `tests/banking_tests_23_6.fth` (0x1A-terminate if it will ever go to
  `disk/a/` for SLIDE — `feedback_cpm_0x1a_eof_marker`). Drive the witness at
  **interpret level** (not inside a late colon body — `feedback_banking_probe_straddle_halt`):
  - **Self-calibrating brink:** `N BANK!` then compute headroom from the live
    `HERE`: `$C000 HERE -` gives bytes free; `ALLOT` `(headroom - k)` for a small
    `k` chosen so the next defining word cannot fit. This is robust to whatever
    the bank's starting HERE is (no hard-coded address).
  - **Capture the numeric `-8` without the parse-in-colon-body problem** via the
    `EVALUATE`+`CATCH` idiom: `S" 42 VALUE OOPS" ['] EVALUATE CATCH` pushes the
    THROW code; assert `= -8`. (EVALUATE runs the offending definition from a
    string so the name is parsed at run time, and CATCH yields the code — cleaner
    than ticking a defining word.) Repeat for a colon body
    (`S" : BIG ... ;"` sized to cross), a raw `S" $5000 ALLOT"`, and a raw
    `S" 1 ,"` at the brink.
  - **Acceptance boundary:** with headroom set so the word ends exactly at
    `$BFFF`, assert the same `EVALUATE`/`CATCH` returns `0` (succeeds).
  - **Bank-0 control:** the same near-top `ALLOT`/`VALUE` sequence executed in
    bank 0 returns `0` (no THROW) — proves AC4.
  - Emit a printed `PASS: dict-overflow-<case>` per assertion and an
    `INFO: <metric>` line if useful; assert a still-live interpreter by printing a
    final witness after the THROWs.
- [x] Add a `make test-repl-banking-23-6` (or fold into the banking-isolated
  variant set) target that boots `iz-cpm-banking` and greps for each `PASS:`
  witness — mirror the `test-repl-banking` grep-loop at `Makefile:276-298` and the
  `test-repl-ud-env` / `test-repl-value-to` single-feature targets. Wire it into
  the `.PHONY` list and (advisory) into the close-out sweep, not into the plain
  `test-repl` semantics.

### Task 5 — Scoping confirmation + docs (AC4, AC8)

- [x] Confirm `CODE` words are routed to **fixed memory** by Story 22.3
  (`project_code_words_fixed_memory_redirect`: build_header keys layout off
  `triple_owner`, CODE redirects to bank 0), so a banked `CODE` body never enters
  the slot-2 window and the assembler opcode-emit path needs no guard. Note the
  finding in Dev Notes; if (and only if) the confirmation fails, raise scope with
  the project lead rather than silently extending into `src/assembler.asm`.
- [x] `docs/ans-forth-core-compliance.md:52`: add `-8` to the §9.3.5
  implemented-subset enumeration.
- [x] `make check-doc-sync` clean-pass.

### Task 6 — Close (S9, S11-not-applicable)

- [x] Post the deferred **hardware-smoke recipe IN THE CLOSING CHAT MESSAGE**
  (STRONG — `feedback_post_hw_smoke_steps_at_review`): on real MicroBeast, `BANK!`
  to a bank, `ALLOT` to the brink, attempt a `VALUE`/`:`/`ALLOT` and confirm the
  `-8` "dictionary overflow" message + live REPL; confirm a normally-sized banked
  definition still works.
- [x] No version-surface bump in this story (not a tag story); the v3.1.0 surface
  audit belongs to Story 23.5. Record the binary delta for 23.5's CCD-4 row.

## Dev Notes

### Itemised byte budget (S3 / B.2 — per-component, NOT "mirrors prior arm")

Estimate the fixed-memory delta by summing the new code/data — no comparison-to-
prior-story shorthand:

- `check_banked_headroom` helper:
  - `LD A,(IY+UserArea.triple_owner)` (3) + `OR A` (1) + `RET Z` (1) = 5 B
  - `> $C000` compare (e.g. `EX DE,HL` (1) + `LD HL,0xC000` (3) + `OR A`/`SCF` (1)
    + `SBC HL,DE` (2) + `RET NC`/`RET C` (1)) ≈ 8 B
  - raise: `LD BC,THROW_DICT_OVERFLOW` (3) + `JP w_THROW_cf.kernel_entry` (3) = 6 B
  - helper subtotal ≈ **19 B**
- `build_header` call site: load HERE → HL (already partly in hand), add
  `header_overhead + name_len + 5`, `CALL check_banked_headroom`. New ops:
  fetch name_len (≈3) + `LD BC,const`/`ADD HL,BC` ×1-2 (≈7) + `ADD A,…`/spill (≈4)
  + `CALL` (3) ≈ **15 B**
- `,` site: prospective `HERE+2` + `CALL` (HL already = HERE; `INC HL`×2 or reuse
  the post-store HL) ≈ **6 B**
- `C,` site: ≈ **6 B**
- `ALLOT` site: HL already = `HERE+n` after its `ADD HL,BC`; insert `CALL` before
  the `LD (here),L` ≈ **4 B**
- `COMPILE,` site: ≈ **6 B**
- `throw_desc_table` row: `DW`(2) + `DB len`(1) + 19 text = **22 B**
- `constants.asm` EQU: **0 B** (equate, no emitted bytes)

Raw sum ≈ 19 + 15 + 6 + 6 + 4 + 6 + 22 = **78 B**. Apply the kernel register-
juggle / scratch overshoot calibration (×1.25 ± 10%, `feedback_kernel_ldir_estimate_overshoot`)
→ **planning envelope ≈ 95–110 B**. Well inside a polish-phase budget; log the
actual re-`wc -c` delta at close (CCD-4). If the actual lands > ~130 B, HALT and
re-itemise before accepting (do not rationalise via comparison to another story).

### Boundary semantics (get this exactly right — it is AC1/AC7)

- Window: `$8000..$BFFF` usable; `$C000` is the first **illegal** byte address.
- `HERE` = address of the next byte to write (one-past the last committed byte).
- A write of width `w` at `HERE` touches `HERE … HERE+w-1`; legal iff
  `HERE+w-1 ≤ $BFFF`, i.e. `HERE+w ≤ $C000`. So the guard takes the prospective
  one-past-end `p = HERE + w` and THROWs iff `p > $C000`. `p == $C000` is LEGAL
  (last byte at `$BFFF`). This is why the helper compares `> $C000`, not `≥`.

### Sequencing vs Story 23.5 (project-lead call)

23.5 is the Epic-23 close-out + v3.1.0 tag gate and is currently `ready-for-dev`;
23.6 is `backlog`→`ready-for-dev` (this expansion). 23.6 is a real correctness fix
and changes the binary, so its delta must be inside 23.5's CCD-4 accounting.
Cleanest order: **land 23.6 before 23.5's gate run** so the close-out sweep and
v3.1.0 byte-budget row include this fix. If 23.5 has already been gated/tagged,
23.6 becomes a v3.1.1 point-fix — flag to the project lead; do not silently fold
it into a shipped tag.

### Key source coordinates (re-verified 2026-06-28; re-read before editing — PD-2)

- Window ceiling `$C000`: `src/banking.asm:843` (comment), `:870` (`.BANKS`
  display only — NOT a guard).
- Doer emits: `src/compiler.asm:842-871` (CREATE), `:889-924` (CONSTANT),
  `:950-988` (VALUE), `:527-570` (`:`); shared `build_header` `:137`,
  `alloc_doer_stub` `:798-832`.
- Doer reads (slot-2-only): `src/inner_interpreter.asm:67` (DOVAR), `:85` (DOCON),
  `:106` (DOVALUE = `JP DOCON`); `(TO)` write `src/compiler.asm:1032-1170`
  (`to_resolve_map_hl` → `mbb_set_slot2`, `src/banking.asm:124`).
- HERE-advance primitives: `src/memory.asm:195` (ALLOT), `:217` (`,`), `:242`
  (`C,`); `src/compiler.asm:485` (`COMPILE,`).
- THROW infra: `src/constants.asm:137-149` (THROW EQUs; -8 absent),
  `src/exception.asm:398` (`.kernel_entry`), `:626` (table format), `:824`
  (`throw_desc_table`), `:646` (`print_throw_description`).
- `triple_owner`: `src/structures.asm:55`, set `0` at COLD `src/antforth.asm:162`.
- CODE→fixed redirect (scoping): `project_code_words_fixed_memory_redirect`.

### Standing-rule compliance for this story

- **S2** — REPL-piped Forth probe is the test (Task 4), not an assembly thread.
- **S7** — EXX hygiene checked at each raise site (doers EXX'd → guard fires in
  build_header pre-restore; comma family in main set).
- **S8 / no-accept-for-bugs** — this is a correctness fix, not an accept-with-
  rationale; the "pre-existing" framing does not discharge it.
- **No in-pass adversarial-review AC** — the `/CR` pass runs separately after
  dev-pass close (PD-1); it is deliberately NOT an AC here.
- **Probe hazards** — interpret-level orchestration + printed witnesses; avoid the
  `$8000`-straddle colon-body halt (`feedback_banking_probe_straddle_halt`) and the
  per-bank-body bucket-corruption limitation (`feedback_phase4_probe_bank_switch_limitation`).

### Project Structure Notes

- New helper lives in `src/banking.asm` (slot-2 region), consistent with the other
  banking guards/accessors; the guard call sites are existing primitives in
  `src/compiler.asm` / `src/memory.asm`. No new source file.
- New test `tests/banking_tests_23_6.fth` follows the `banking_tests_NN_N.fth`
  naming already used through Epic 22; new Makefile witness target follows the
  `test-repl-<feature>` pattern (`test-repl-ud-env`, `test-repl-value-to`).
- No banking-subsystem structural change (no new UserArea cell, no triple change);
  the guard reads existing state (`triple_owner`, `HERE`) only.

### References

- Stub source: this file's pre-expansion content (Story 23.2 review finding #5,
  drafted 2026-06-28) — preserved/expanded above.
- [Source: src/banking.asm#843,#870] window ceiling `$C000` (.BANKS display).
- [Source: src/compiler.asm#137 build_header; #485 COMPILE,; #798 alloc_doer_stub; #1109 STUB_ALLOC_BASE assert]
- [Source: src/memory.asm#195 ALLOT; #217 `,`; #242 `C,`]
- [Source: src/inner_interpreter.asm#85 DOCON; #106 DOVALUE]
- [Source: src/exception.asm#398 kernel_entry; #824 throw_desc_table; #626 table format]
- [Source: src/constants.asm#137-149 THROW EQUs; #25 STUB_ALLOC_BASE=$D4CB]
- [Source: docs/throw-codes.md#82] `-8 dictionary overflow` — documented, unimplemented.
- [Source: docs/ans-forth-core-compliance.md#52] §9.3.5 implemented-subset row.
- [Source: epics-phase5-epic-23.md#96-118] carried-forward S1–S12 constraints.
- ANS Forth 1994 §9.3.5 (`-8` dictionary overflow); §3.2.6 (THROW semantics).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (dev-story workflow, 2026-06-28)

### Implementation Plan

Verified against live source before editing (PD-2). The guard is a shared,
non-throwing predicate plus an EXX-aware raise:

- `check_banked_headroom ( HL = prospective one-past-end -- )` — returns CY=1 on
  overflow (`prospective > $C000`), CY=0 otherwise; no-op (CY=0) on bank 0
  (`triple_owner == 0`). Clobbers AF only (preserves BC/DE/HL so the comma-family
  store pointer survives). Lives in `src/banking.asm`.
- `dict_overflow_throw` (primary-set) — `LD BC,-8 / JP w_THROW_cf.kernel_entry`.
- `build_header` runs in the **EXX shadow set** (every defining-word caller EXX's
  at entry — confirmed in `:`/CREATE/CONSTANT/VALUE/MARKER), and the kernel
  THROW contract requires the **primary** set (`.colon_no_name` precedent,
  `src/exception.asm:288-296`). So the build_header site does
  `CALL check_banked_headroom / JR NC,ok / EXX / JP dict_overflow_throw`.
- The four comma-family sites (`,`/`C,`/`ALLOT`/`COMPILE,`) run primary-set (no
  internal callers — verified) and `JP C, dict_overflow_throw` directly.

`DOER_RESERVE = 5` (largest fixed code field: CREATE/CONSTANT/VALUE emit JP doer
(3) + 2-byte body); header_overhead = 6 (3 fat hash-link + 1 count_flags + 2
bank-N stub-xt cell). build_header prospective = `HERE + name_len + 11`.

### Debug Log References

- **iz-cpm-banking straddle-halt (the hard part).** The +100 B kernel growth
  pushed the `tests/banking_tests.fth` dot-banks section's `_dot-banks-setup`
  colon body across `$8000` (measured: body 32686→32785 at +100 B; 32586→32685
  at baseline). Invoking a >`$8000` body **after a foreign `BANK!`** (probe Y)
  portal-aliases and halts the emulator — the documented
  `feedback_banking_probe_straddle_halt` / portal-window-aliasing class.
  **Isolation proof:** neutralising the guard (always-return-"ok", same size)
  still hung → pure layout, my guard logic is sound. Fix: de-coloned the dot-banks
  probes (X/Y-already/Z/M1/W) and inlined `_dot-banks-setup` at interpret level,
  so the section compiles no colon body near `$8000` (matches the probe-Y
  precedent). iron-spike now PASSes (it gained headroom from the ~200 B of removed
  probe colon bodies).
- **Probe harness reality.** `CATCH`/`EVALUATE` recovery is fragile under piped
  console stdin (`feedback_phase4_probe_bank_switch_limitation`): a caught throw
  leaves STATE dirty / skips the rest of the line. The probe therefore uses the
  **uncaught** -8 form (REPL prints `error -8: dictionary overflow`, QUIT cleanly
  resets STATE + re-asserts the bank).

### Completion Notes List

- **AC1** (defining-word straddle → -8): `build_header` guard. Probe case A
  (VALUE). **AC1 boundary** (last byte exactly `$BFFF` accepted): probe case E
  (VALUE whose value cell ends at `$BFFF`, one-past == `$C000`, passes — confirms
  the `> $C000` compare, not `>=`).
- **AC2** (banked colon body straddle → -8): `COMPILE,` guard. Probe case B
  (16 compiled DUP xts overrun the window top; header fits, body throws).
- **AC3** (raw `,`/`C,`/`ALLOT` straddle → -8): guards at all three primitives.
  Probe cases C (`ALLOT`) and D (`,`).
- **AC4** (bank 0 strict no-op): `check_banked_headroom` returns immediately when
  `triple_owner == 0`. Probe case F (the same near-top VALUE that throws in a
  bank succeeds in bank 0).
- **AC5** (-8 first-class): `THROW_DICT_OVERFLOW EQU -8` in `constants.asm`;
  `-8 / "dictionary overflow"` (19 chars) row in `throw_desc_table`; raise via
  `JP w_THROW_cf.kernel_entry` with primary-set BC. The uncaught probe prints
  `error -8: dictionary overflow`, exercising the code + description-table lookup;
  CATCH yields the same -8 by the shared THROW mechanism (the uncaught form is
  used because behavioural CATCH/EVALUATE probes are harness-fragile here).
- **AC6**: gates green — test-repl 1005/0, test-repl-banking 62/0 (+3 pre-existing
  Epic-19-deferred SKIPs), straddle 3/3, file-sanity 1/1, all isolated banking
  variants (19.3..22.3) green. Binary 28947 → **29047 B (+100 B)**, inside the
  itemised 95–110 B envelope (< the ~130 B HALT threshold).
- **AC7**: `tests/banking_tests_23_6.fth` + `make test-repl-banking-23-6`
  (per-case awk-span verdicts: A-D + G throw, E-F don't, ALIVE witness). 7/7 PASS.
  (Case G — banked positive `ALLOT` wrapping past `$FFFF` — added at code review.)
- **AC8**: `docs/throw-codes.md` -8 row flipped to done; `ans-forth-core-compliance.md`
  §9.3.5 row adds -8; `make check-doc-sync` → 0 drift.
- **Task 5 scoping**: confirmed `CODE` (Story 22.3) sets `triple_owner = 0` before
  `build_header` (`src/assembler.asm:1326-1336`), so the guard no-ops for CODE and
  the assembler opcode-emit path lands in fixed memory — no guard needed there.
- **HARDWARE SMOKE — PASS (real MicroBeast, 2026-06-28).** `1 BANK!` → `BANK@ .`
  prints `1`; `$C000 HERE - 3 - ALLOT` then `42 VALUE FOO` →
  `error -8: dictionary overflow` with a live REPL; `2 BANK! : OK1 1 2 + ; OK1 .`
  → `3` (a normal banked definition still compiles/runs). Byte-identical to the
  emulator transcript. Validates AC1 + AC5 + AC6-survivability on silicon. (A
  first attempt that omitted `1 BANK!` ran entirely in bank 0 — guard correctly
  dormant per AC4 — and the operator's repeated bank-0 brink-`ALLOT`s tripped the
  pre-existing, out-of-scope bank-0 unbounded-`ALLOT` hazard: `$C000 HERE -`
  underflows once bank-0 HERE passes `$C000`, marching the kernel dictionary
  pointer into the `$D400`+ region and crashing on the next define. Not a
  regression — bank 0 has no dictionary-full guard by design, AC4 — but a sharp
  edge worth a follow-up alongside the MARKER residual below.)
- **SURFACED RESIDUAL (out of AC scope — flag to project lead).** A banked
  `MARKER` emits a fixed **192-byte** saved-bucket body via LDIR
  (`src/system.asm:87`), NOT through `build_header`'s code field or the comma
  family. `DOER_RESERVE = 5` covers MARKER's header + `JP DOMARKER` (3) but NOT
  the 192-byte body, so a `MARKER` created within ~195 bytes of `$C000` in a bank
  could still straddle silently. This is the same defect class but is not in this
  story's ACs (which enumerate CONSTANT/VALUE/CREATE/`:` + `,`/`C,`/`ALLOT`/`COMPILE,`),
  and banked MARKER is already documented-degraded (`project_banked_marker_no_stub`).
  Per the Task-5 "raise scope rather than silently extend" directive: surfaced
  here for a follow-up story rather than bolting a risky guard into the MARKER
  LDIR (which would also need a pre-build_header check to avoid leaving a
  half-built header). Recommend a small follow-up to guard the MARKER body emit.

### File List

- src/constants.asm — add `THROW_DICT_OVERFLOW EQU -8`
- src/banking.asm — add `check_banked_headroom` + `dict_overflow_throw`
- src/compiler.asm — guard at `build_header` (EXX-aware) and `COMPILE,`
- src/memory.asm — guards at `ALLOT`, `,`, `C,`
- src/exception.asm — `-8 / "dictionary overflow"` row in `throw_desc_table`
- tests/banking_tests.fth — de-colon dot-banks probes (Z/M1/W) + inline
  `_dot-banks-setup` (AC6 straddle-halt fix from the +100 B growth)
- tests/banking_tests_23_6.fth — NEW regression probe (AC7)
- Makefile — `test-repl-banking-23-6` target + `BANKING_23_6_PROBE` var + `.PHONY`
- docs/throw-codes.md — -8 row → done (Story 23.6)
- docs/ans-forth-core-compliance.md — §9.3.5 row adds -8

## Change Log

- 2026-06-28 — Story 23.6 implemented: banked dictionary window-top (`$C000`)
  overflow guard raising -8 ("dictionary overflow") at every banked HERE-advance
  (defining words via `build_header`; raw growth via `,`/`C,`/`ALLOT`/`COMPILE,`),
  bank-0-exempt. New `-8` THROW code + description. New regression probe
  `banking_tests_23_6.fth` + `make test-repl-banking-23-6`. Binary +100 B
  (28947 → 29047). De-coloned the dot-banks probes to clear a +100 B-induced
  iz-cpm straddle halt (AC6). Docs synced. Surfaced an out-of-scope MARKER
  192-byte-body residual for follow-up. Status → review.
- 2026-06-28 — Hardware smoke PASS on real MicroBeast: banked `42 VALUE FOO` at
  the `$C000` brink raised `error -8: dictionary overflow` with a live REPL; a
  normal banked colon still compiled/ran. Validates AC1/AC5/AC6 on silicon.
- 2026-06-28 — Code-review fixes (high-effort review, all gates re-green):
  (1) **ALLOT 16-bit wrap gap** — a banked positive `ALLOT` whose `HERE+n` wraps
  past `$FFFF` (wrapped prospective lands below `$C000`) slipped the headroom
  predicate and silently corrupted HERE. `w_ALLOT_cf` now branches on the
  `ADD HL,BC` carry: negative `n` is a legitimate release (store), non-negative
  `n` that carried is a wrap → -8 on a bank, no-op on bank 0. (2) **Guard
  dedup** — the `INC/CALL check_banked_headroom/JP C/DEC` scaffold at `,`/`C,`/
  `COMPILE,` factored into a new `GUARD_BANKED_WRITE width` macro (`src/macros.asm`;
  same instruction expansion, single contract). (3) New probe **Case G** in
  `banking_tests_23_6.fth` (banked `$7000 ALLOT` at HERE=`$BFFE` wraps to
  `$2FFE`) asserts the wrap path throws -8; Makefile throw-set now `A B C D G`.
  Binary 28947 → 29062 (+115 B, ~+15 B over the pre-review +100 B for the wrap
  branch). Finding-3 (provenance-comment tags) deferred to the comment-debloat
  interlude. Gates: asm clean · test · straddle 3/3 · repl/asm/value-to/ud-env/
  in-out 0-FAIL · banking 0-FAIL · banking-23-6 A-D+G throw / E,F accept.
