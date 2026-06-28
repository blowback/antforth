# Story 17.5: `.BANKS` — minimal working form

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Context — why this story exists, why now

Fifth story of Epic 17 (Bank primitives + CL configuration), the
fifth binary-delta story of Phase 4. Stories 17.1 + 17.2 + 17.3 +
17.4 closed shipping the runtime banking primitives and the
boot-configuration surface: `src/banking.asm` subsystem, 29-entry
`bank-table[]` at `$D400` with the H3-fix LDIR clone at COLD, six
banking UserArea cells, nine user-facing words
(`BANK-MAPPING-ON`, `BANK-MAPPING-OFF`, `BANK@`, `BANK!`, `BANKS`,
`+BANK` with probe-on-add and cap-check, `-BANK`, `BANKS-CLEAR`,
`SET-BANK`), the CL-tail parser (`cl_tail_parse` in
`src/antforth.asm`) with six PD-P4-14 edge-case dispositions
(silent defaults / `bad? X` / `range?` / `dup? NN` / `probe? NN`
/ `empty?`), the banner advance to `v3.0.1` with the runtime
`- N banks available` clause on line 2, the shared
`cl_probe_and_add` helper, and the `cl_emit_hex_byte` /
`cl_emit_hex_digit` print helpers. Post-17.4 baseline = **25,983 B
/ 975 PASS / 0 FAIL / 2 SKIP-on-iz-cpm / 30 PASS on test-repl-
banking / 21 PASS + 3 SKIP on test-repl-banking-skip** (re-verify
at dev-pass start per B.3 — see Pre-edit baseline task). Epic-17
envelope post-17.4 = **955 B (acceptance-with-rationale ACCEPTED
2026-05-16 by project lead)** / ~400 B = ~239%; carry-forward
disposition Q6-a-extended remains binding into Story 17.5.

Story 17.5 lands the **observability surface** that turns the
runtime banking primitives + CL parser into a user-visible status
display:

1. **`.BANKS ( -- )`** — a new DEFCODE word in `src/banking.asm`
   per FR-P4-6. Reads `bank_count`, walks `active_pages[0..N-1]`,
   and prints a status table to the console: header row + one row
   per active bank + totals row at bottom. Each row carries:
   logical bank index (decimal), physical page (hex — matches the
   bare-hex convention from the CL parser + `probe?`/`dup?`
   warnings), current-bank marker (`*` next to the row whose
   index equals `BANK@`), per-bank `used` and `free` columns.
2. **Per-bank used/free are PLACEHOLDERS in Story 17.5** per
   the AC2 spec wording: "initial values: used = 0, free = 16384
   — full per-bank `here` tracking lands in Epic 19; Story 17.5's
   `.BANKS` reports zero-used and full-free placeholders." The
   minimal form does NOT compute used from each bank's HERE; it
   prints `0` and `16384` literally for every row. Epic 19's
   bank-aware `:` will make these values real (per
   `epics-phase4-epics-16-22.md:1064..1070`: "AC5 — update Story
   17.5's `.BANKS` probe to assert real per-bank used / free
   values after `5 BANK! : SOME-WORD ;`"). Epic 22 polishes the
   formatting + adds the optional REPL prompt indicator
   integration (per architecture.md:483 Epic-22 budget line:
   "`.BANKS` ~80 B; prompt indicator ~20 B").
3. **Totals row** — at the bottom of the table, sums used / free
   across all active banks. In Story 17.5's placeholder form:
   `used = 0`, `free = bank_count * 16384`. Trivially computed
   inline.
4. **80-column column-stable output** — column widths are fixed
   at draft-time; longest expected row text (line at full 28-bank
   cap with 6-digit free total) MUST fit within 80 chars per AC4.
5. **CCD-3 source flag + compliance-doc row** — `.BANKS` carries
   the `; antforth extension .BANKS — see
   docs/antforth-banking-redesign.md §1` source-comment block per
   NFR-P4-14; one new row added to
   `docs/ans-forth-core-compliance.md` antforth-extension table.

After Story 17.5 close, Story 17.6 owns the iron-spike +
antforth-3.x.1 tag close-out (verdict-table walk per Story-13.5.6
precedent, with Story 17.5 PASS as one row in the table).
**Phase-4 wordset progress** advances from 9/12 (post-17.4) to
10/12 (post-17.5); remaining 2 (`IN-BANK`, `BANK-OF`) are Epic 18.

## Story

As Marc (OG retrocomputing user) wanting to inspect the current
banking configuration at the REPL,
I want `.BANKS` to print a status table showing the logical bank
index, physical page, current-bank marker, and per-bank used /
free columns plus a totals row,
So that I have observability into the post-CL configuration
before bank-aware `:` (Epic 19) makes per-bank `here` / `latest`
meaningful — and so I can visually confirm at the prompt that
`BANK!` actually moves the `*` marker to the new active row.

## Acceptance Criteria

**Given** Story 17.4 has shipped (CL parser + banner; the post-CL
`active_pages[]` is populated at boot per AC2 of 17.4 — default
12 entries `[0x22, 0x35..0x3F]` or whatever the user-supplied CL
tail yielded; `BANK@` returns 0 (portal) at boot; `BANKS` returns
the post-CL count; cumulative Epic-17 envelope at 955 B / ~400 B
with Q6-a-extended accept-with-rationale disposition binding),
**When** Story 17.5 is dev-passed,

**Then** **AC1** (`.BANKS` DEFCODE + source location) — `.BANKS
( -- )` is implemented as a new DEFCODE in `src/banking.asm`,
placed after `w_SET_BANK_cf` (the last DEFCODE before the file's
current end, post-17.4). The word body reads
`(IY+UserArea.bank_count)`, prints the header row, walks
`active_pages[0..bank_count-1]` printing one row per active bank
with the AC2 column layout, then prints the totals row. Stack
effect is `( -- )` — no inputs, no outputs (the entire effect is
console output via `bdos_print_str` / `bdos_putchar` /
`bdos_crlf`). The word is callable both interactively at the REPL
and inside `:`-defined words per FR-P4-6.

**And** **AC2** (per-bank row content + format — FR-P4-6) — each
row in the table carries exactly four columns:
  - **logical bank index** in decimal (`0`..`28`; 1-2 digits) —
    decimal because logical-bank-index is a 0-based count, not an
    address-like quantity (matches the established
    `1 BANK!` / `BANK@ .` REPL convention where `BANK@` returns
    decimal).
  - **physical page** in hex (2 hex digits, uppercase, no `$` or
    `0x` prefix — matches the bare-hex convention established by
    the CL parser's `<bank-list>` syntax and the Story 17.3 /
    17.4 warning text `probe? NN` / `dup? NN`).
  - **current-bank marker** — a single character: `*` for the
    row whose logical-index equals `BANK@`, space (` `) for all
    other rows. The marker appears in its own column (fixed
    width = 1) so column-alignment is preserved across the
    current-bank row and inactive-bank rows.
  - **used** and **free** as the two right-aligned numeric
    columns. **Per the AC2 spec wording: Story 17.5 ships
    placeholder values — `used = 0` for every row; `free = 16384`
    (= the per-bank 16 KB byte capacity) for every row.** Full
    per-bank `here` tracking lands in Epic 19; Story 17.5 does
    NOT compute used from the per-bank HERE pointer. The
    placeholder framing is binding per the FR-P4-6 minimal-form
    scope.

**Q1 (column-layout finalisation):** the AC2 column-set is
binding; the exact column widths + header text + separator chars
are the wordsmithing question. Two candidate layouts under
consideration:
  - **(a) compact form** (recommended — fits comfortably in 80
    cols at all bank counts; mirrors `WORDS` / `.S` console
    aesthetics):
    ```
    BANK PAGE  USED   FREE
       0   22 *    0  16384
       1   35      0  16384
       2   36      0  16384
      ...
      11   3F      0  16384
    TOTAL          0 196608
    ```
    Column widths: BANK = 4 (right-aligned), PAGE = 4
    (right-aligned: 1 leading space + 2 hex + 1 trailing space),
    marker = 2 (1 char + 1 trailing space), USED = 6
    (right-aligned), FREE = 6 (right-aligned). Total line width
    = 4 + 5 + 2 + 7 + 7 = ~25 chars + trailing CRLF; fits well
    inside 80 cols even at 28-bank cap.
  - **(b) widened form** (alternate; uses the full 80-col width
    more conspicuously; ~10 B more in literal strings):
    ```
    BANK   PAGE   ACTIVE      USED        FREE
       0     22      *         0       16384
       1     35                0       16384
      ...
    TOTAL                      0      196608
    ```
**Recommended:** (a) compact form. Saves ~10 B of literal text;
matches the existing `.S` / `WORDS` density precedent (terse over
prosaic). The fixed-width header literal is ~24-25 B for (a) vs
~38-42 B for (b).

**And** **AC3** (totals row at bottom) — after the last per-bank
row, a totals row prints with the label `TOTAL` in the BANK
column (left-aligned in the same column-1 position as the
per-bank row indices) and the column-aligned totals: used =
`0` (sum of per-bank zero placeholders); free =
`bank_count * 16384` (= the sum of per-bank `16384` placeholders;
6 decimal digits at the 12-bank default = `196608`; 7 digits at
the 29-bank cap = `475136`). The PAGE column and the marker
column are BLANK on the totals row (no physical-page total
makes sense). **Q2 (totals-row computation point):** the totals
can be computed (a) on-the-fly during the walk loop (DE += 16384
per row), printed at the end; or (b) recomputed post-loop as
`bank_count * 16384` via a single multiply. **Recommended:**
(b) — simpler asm shape; the multiply is at most 5-cell since
`bank_count <= 29` and `16384 = 1<<14`, so `total_free =
bank_count << 14` is two RLCAs of a 32-bit value. Compact via
two `ADD HL, HL` shifts on the high cell after seeding HL =
bank_count. Or (c) hardcode at zero in the loop and emit one
literal "0" for total_used + a small computed free. The
project-lead pick gates the asm-level approach.

**And** **AC4** (column widths stable + 80-col fit per FR-P4-6
trailing clause) — column widths are FIXED at draft time and
stable across all printed rows including the totals row; visually
the header / per-bank rows / totals row all share aligned column
boundaries. The total line width MUST fit within 80 characters
(CP/M `bdos_putchar` does not wrap; a >80-char line just keeps
going on the same physical row until the terminal wraps, which
is ugly). **At the 29-bank cap with 7-digit free total
(`475136`), the line width MUST be ≤ 80** — the Q1 (a) layout
gives a per-row width of ~25 chars including padding, well
inside the budget. Verified by ASCII layout check at dev-pass
start; binding limit.

**And** **AC5** (source-comment block — Epic 17 minimal scope
flag per spec) — the `.BANKS` body in `src/banking.asm` carries
a source-comment block above its `DEFCODE ".BANKS"` line stating
verbatim (or equivalent): `; .BANKS — Epic 17 minimal form. Per-`
`; bank used/free are placeholders (0, 16384); Epic 19's bank-`
`; aware ":" makes them real (probe: 5 BANK! : SOME-WORD ;`
`; → used in bank 5 should reflect body byte-count). Epic 22`
`; polishes the column formatting + adds REPL prompt indicator`
`; integration (see architecture.md:483 Epic-22 budget line).`
This comment block locates the polish-pass for future readers +
captures the placeholder rationale + cites the relevant
forward-inheritance pointers. The marker text `Epic 17 minimal
form` is binding per the AC5 spec wording.

**And** **AC6** (CCD-3 source flag + compliance-doc row per
NFR-P4-14) — `.BANKS` carries the standard antforth-extension
source flag block per the established pattern:
`; antforth extension .BANKS — see docs/antforth-banking-`
`; redesign.md §1` immediately above the source-comment block
from AC5 (the two comment blocks stack, AC6 first then AC5).
One new row added to `docs/ans-forth-core-compliance.md`'s
antforth-extensions table at the end of the existing 9-BANK*-
words block (post-`SET-BANK` row at the file's current line
~877):
  - `| \`.BANKS\` | \`banking.asm:<line>\` | Non-standard
    (antforth extension — see \`docs/antforth-banking-redesign.md\`
    §1; FR-P4-6 — minimal form; per-bank used/free are
    placeholders, Epic 19 makes them real, Epic 22 polishes
    formatting) |`

**And** **AC7** (REPL probes — per S2 / NFR-P4-29; tests/banking_tests.fth) —
`tests/banking_tests.fth` extends with probes that exercise the
`.BANKS` output surface. Two distinct probe shapes are needed
because `.BANKS` emits multi-line console output (not a stack
value), and the existing `tests/banking_tests.fth` probe pattern
is `<setup> <assertion> ." PASS|FAIL: ..."` — the assertion has
to be Forth-side. Two approaches:
  - **Probe-side approach (a) — capture-and-grep via Makefile:**
    the .fth probe just calls `.BANKS` and prints a known
    grep-anchor sentinel (e.g. `." ---DOT-BANKS-PROBE-1-START---"`
    + `.BANKS` + `." ---DOT-BANKS-PROBE-1-END---"`); the Makefile
    grep-asserts that between the two sentinels the output
    contains the expected header line + at least 12 data rows
    + the totals row at default-12-banks. This is the
    `cl-probe-*` pattern from Story 17.4 — bridging
    console-emit to deterministic test surface via grep.
  - **Forth-side approach (b) — count CR characters in output:**
    redirect output to a counted buffer, count newlines, assert
    >= 14 (header + 12 rows + totals); too much plumbing for
    Story 17.5's MVP form.
  - **Recommended:** (a). Matches the Story 17.4 CL-probe pattern;
    no new console-redirect infrastructure needed; grep is
    deterministic.

Specifically, at least 4 probes:
  - **Probe X — header + row-count at default 12 banks:**
    print sentinel-start; `.BANKS`; print sentinel-end.
    Makefile grep-asserts: presence of `BANK PAGE` header
    substring; at least 12 data-row lines between the sentinels
    (the existing 12-bank default after CL-parser default
    `22 35-3F`); presence of `TOTAL` line; presence of `196608`
    (= 12 × 16384) on the totals line. PASS on iz-cpm-banking;
    PASS on iz-cpm baseline (`.BANKS` is bank-MMU-agnostic at
    the OUTPUT level — it just reads `bank_count` + walks
    `active_pages[]`, neither of which touches port 0x72; the
    CL parser's `active_pages[]` population under iz-cpm
    baseline is exactly the same as iz-cpm-banking because no
    actual MMU operations differentiate them; see Story 17.4
    AC10 iz-cpm-baseline analysis).
  - **Probe Y — current-bank marker tracking:** at boot, run
    `.BANKS` → assert `*` appears on the row matching `BANK@ = 0`
    (i.e. the row with logical index 0 and page 0x22); then
    `1 BANK!`; run `.BANKS` → assert `*` is now on the row
    matching `BANK@ = 1` (logical index 1, page 0x35). The
    marker-MOVED-with-BANK! assertion is the load-bearing
    correctness check for the current-bank-marker logic.
  - **Probe Z — placeholder values:** after a fresh `.BANKS`,
    assert every row's used column reads `0` (literal); every
    row's free column reads `16384`. The placeholder-binding-ness
    is the Epic 17 scope guard — if Story 17.5 accidentally
    starts reading per-bank HERE values from bank-table[N][0..1],
    the placeholder probe catches the scope creep.
  - **Probe W — totals row at 12-bank default:** assert presence
    of `TOTAL` keyword on its own row; assert the row contains
    `196608` (the 12-bank default free total). At higher
    bank-counts via `+BANK`, the totals scale accordingly; this
    is OPTIONAL extension at dev-pass discretion (the binding
    minimum is 4 probes per AC7).

All probes annotate per the Story 16.3 three-test-surface
convention: PASS on iz-cpm baseline (`.BANKS` output is
surface-AGNOSTIC); PASS on iz-cpm-banking; the hardware surface
is exercised via AC8 (single human-typed `.BANKS` boot probe).
The `cl-probe-bank-roundtrip` H3-regression probe from Story 17.4
exercises the prerequisite `BANK!` round-trip on real
MicroBeast; the AC8 probe extends that with a `.BANKS` call
between BANK! invocations.

**And** **AC8** (hardware-smoke per S9 / NFR-P4-11) — one
hardware-typed `.BANKS` probe runs on real CP/M 2.2 / MicroBeast
per the established `~/Downloads/beastty-<date>.bin` transcript
convention. **Single human-typed run per Lesson 16-A**:

  1. Boot `antforth` (default 12-bank config; or `antforth 24 35-3f`
     per Story 17.4 AC8 to maintain consistency with the prior
     hardware smoke).
  2. `.BANKS` ✓ — visually inspect: header row + 12 data rows +
     totals row; `*` on row 0 (portal page); column-stability
     across rows; total output fits the terminal width without
     wrapping.
  3. `1 BANK!` → `ok`.
  4. `.BANKS` ✓ — `*` now on row 1 (page 0x35); all other
     columns unchanged from step 2 (the placeholder `0 / 16384`
     values do not change with BANK! per AC2 binding).
  5. `0 BANK!` → `ok`.
  6. `.BANKS` ✓ — `*` back on row 0.
  7. Transcript saved per established
     `~/Downloads/beastty-<date>.bin` naming.

A SECOND optional hardware run with a non-default CL tail (e.g.,
`antforth 22 35-37` for a 4-bank config) MAY exercise the
shorter-than-default row-count path; OPTIONAL because the
load-bearing AC8 assertion is the column-stability + marker
tracking at default 12 banks. Transcript saved per S9.

**And** **AC9** (binary delta + Epic 17 envelope tracking) —
`wc -c build/antforth.com` grows by ≤ **~80 B** for this story
per the epic AC9 + architecture.md:483 Epic-22 budget line for
`.BANKS` (the architecture allocates ~80 B against Epic 22 as
the polish form; Story 17.5 ships the MVP form within the same
budget surface). **Per-component itemisation (B.2-compliant; no
"mirrors prior arm" rationale; no comparison-to-prior-story-body
shapes as load-bearing justification):**

  - **DEFCODE header for `.BANKS`** — 9-char dictionary entry
    name + 3-byte CFA header (LINK / NAME-LEN-FLAGS / CFA-JP) +
    NAME-padding alignment = **~14 B** (matches the empirical
    measurement for the existing 8-9-char DEFCODE headers in
    `src/banking.asm`: `BANK@` 5 chars = ~10 B header total).
  - **Header-row literal** + length EQU — Q1 (a) form
    "`BANK PAGE  USED   FREE`" + CRLF = 23 chars (incl. CRLF) =
    **~24 B** (literal bytes + 1 B length EQU).
  - **Row-printing loop body** — per iteration:
    - Read `active_pages[B]` into A (LD A,(HL); INC HL with HL
      seeded to ACTIVE_PAGES_BASE) = ~5 B
    - Print decimal bank index right-aligned in 4-col field — can
      reuse `w_DOT_cf` or `w_U_DOT_R_cf`; if reuse via DEFCODE-
      level call: ~6-8 B per call site (LD BC,index; PUSH BC; CALL
      w_U_DOT_R_cf) OR if inline asm: ~15-20 B (custom 4-col
      decimal print of a 0..28 number; cheaper as 1-2 ASCII digit
      hand-coded conversion via DAA or compare-with-9)
    - Print space + 2-hex-digit page via `cl_emit_hex_byte` (Story
      17.4 helper, re-used) = ~5-6 B per call site
    - Print marker (` ` or `*`) — `(IY+UserArea.current_bank) - B`
      → JR Z, .marker_star; LD E,' '; JR .emit_marker;
      .marker_star: LD E,'*'; .emit_marker: CALL bdos_putchar +
      LD E,' '; CALL bdos_putchar = ~12-15 B
    - Print "     0" (used column, right-aligned 6-col) — fixed
      literal `str_used_zero DB "     0"` (6 chars) +
      LD HL,str_used_zero; LD B,6; CALL bdos_print_str = ~10 B
      site + 6 B literal = ~16 B FIRST iteration (subsequent
      iterations re-use the literal: 10 B/site only)
    - Print " 16384" (free column, right-aligned 6-col) — fixed
      literal `str_free_full DB " 16384"` (6 chars) +
      LD HL,str_free_full; LD B,6; CALL bdos_print_str = same
      ~10 B/site + 6 B literal one-time
    - CRLF via `CALL bdos_crlf` = ~3 B per iteration
    - Loop epilogue: INC B / CP bank_count / JR NZ, .row_loop =
      ~6-8 B
    - **Per-iteration body subtotal: ~35-45 B inline cost
      (excluding the 12-16 B one-time literals)**
  - **Totals-row print site** — print `TOTAL` literal (5 chars
    + len EQU = ~7 B) + column-aligned spacers + `     0` (use
    same `str_used_zero` from row loop, 0 B additional literal)
    + computed `free_total` via Q2-disposition (a) running-sum
    or (b) `bank_count * 16384`:
    - Q2 (b) `bank_count << 14` — two `ADD HL,HL` after
      `LD H,0; LD L,(IY+UserArea.bank_count); ADD HL,HL ×14`
      via DJNZ loop OR `LD A,(IY+UserArea.bank_count); LD H,A;
      LD L,0; ADD HL,HL; ADD HL,HL` (two shifts for the high-
      byte * 256 * 64) — ~10-15 B
    - Print HL as decimal — reuse `w_U_DOT_cf` (DEFCODE) requires
      DStack push of the value: `PUSH BC` (save TOS) / `LD B,H;
      LD C,L` (HL → TOS BC) / `PUSH BC` (push the to-be-printed
      value) / `LD BC,...; CALL ...` — OR reuse `w_U_DOT_R_cf`
      with right-align — ~10-15 B
    - **Totals-row subtotal: ~30-40 B**
  - **CCD-3 + AC5 source-comment blocks** — 0 B kernel-binary
    contribution (source comments only); ~12-15 lines combined
    in `src/banking.asm`.
  - **Compliance-doc row** — 0 B kernel-binary contribution;
    one new line in `docs/ans-forth-core-compliance.md`.
  - **REPL probes in `tests/banking_tests.fth`** — 0 B kernel-
    binary contribution (.fth file extension only).
  - **Estimated total kernel-binary delta:**
    - DEFCODE header (~14) + header literal (~24) + 12-iteration
      row loop (~35-45 inline + 12-16 one-time literals) +
      totals row (~30-40) = **~115-140 B**

**Envelope-pressure note (cumulative; B.4 figure-drift
discipline):** post-17.4 Epic-17 envelope = 955 B / ~400 B
(~239%; Q6-a-extended ACCEPTED 2026-05-16). Story 17.5
estimated ~115-140 B brings cumulative to **~1,070-1,095 B /
~400 B (~268-274%)** at Story 17.5 close. The empirical-reality
> planning-estimate pattern continues (~2.4-2.7× the redesign-§7
guidance; consistent across all five Epic-17 binary-delta stories
when including Story 17.5 projection). **Q6 (envelope direction
for Story 17.5):** binding pick at dev-pass start:
  - **(a) accept-with-rationale forward** — Q6-a-extended
    precedent from Story 17.4 carries through; Epic-17 retro line
    item already in flight. **Recommended.**
  - **(b) descope to header + totals only** (skip per-bank rows,
    just print `BANK COUNT: N  TOTAL FREE: N*16384`) — saves
    ~80-100 B but fundamentally changes the FR-P4-6 deliverable
    from "status TABLE" to "status SUMMARY"; rejected at story
    draft on the grounds that the per-bank-rows + current-bank
    marker is the FR-P4-6 load-bearing surface (marker tracking
    is the visual signal users rely on).
  - **(c) defer to Epic 22 polish** — closes Epic 17 with no
    `.BANKS` shipped; rejected because FR-P4-6 lists `.BANKS` in
    the 12-word wordset that Epic 17 is supposed to ship per the
    Epic-17 close-out gate; deferring would leave 9 of 12 words
    shipped at Epic 17 close, missing the wordset-completion
    contract (the remaining 2 are `IN-BANK` / `BANK-OF` which
    are Epic 18).
**Recommended:** (a). The empirical-reality pattern is
established; the per-epic-budget figure is guidance not contract;
Epic-17 retro absorbs the cumulative overage.

If the measured delta exceeds the AC9 +20 B noise tolerance over
the ~140 B target (i.e. > 160 B), surface for project-lead
direction at close-out per the Story 17.4 SCP-trigger precedent
(Q6-d formal SCP if the overage is structural rather than
estimation-noise).

**And** **AC10** (regression baseline + banking-emu probes) —
`make test-repl` reports **≥ 975 PASS / 0 FAIL / 2 SKIP** on
iz-cpm (Phase-3 + 17.1 + 17.2 + 17.3 + 17.4 close-out baseline
preserved per FR-P4-41 / NFR-P4-10; baseline re-derived at
dev-pass start per B.3). `make test-repl-banking` reports
**≥ 30 PASS** (the 30-PASS post-Story-17.4 baseline) **+ 4 new
`.BANKS` probes per AC7** = **≥ 34 PASS** post-17.5.
`make test-repl-banking-skip` is unchanged at 21 PASS + 3 SKIP
unless any `.BANKS` probes are annotated SKIP-on-iz-cpm — per
AC7's `Recommended: (a). PASS on both surfaces.` analysis,
`.BANKS` is surface-AGNOSTIC and probes annotate PASS on both;
`test-repl-banking-skip` therefore grows to **24 PASS + 3 SKIP**
(adding the 3 surface-agnostic PASSes for `.BANKS` row-count /
marker / totals probes; the placeholder-values probe is
surface-redundant). `make check-doc-sync` exits 0; advisory
count may grow by 0-1 (the new `.BANKS` row in the antforth-
extension table is consistent with the 9 existing BANK* rows
post-Story-17.3, so no new advisory expected).

If binary-growth surfaces the iz-cpm test-643 quirk per
`feedback_iz_cpm_test_643_quirk.md`, the NOP-padding slot in
`src/antforth.asm:188..190` is the established mitigation;
re-tune at dev-pass close empirically (Story 17.4 retained the
3-NOP count; Story 17.5's +115-140 B growth may shift the layout
slightly and require a 4-6-NOP tune).

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes
  - Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift). Story 17.4 close was 25,983 B; re-verify at dev-pass start since hitch-hiker commits may have shifted it.
- [x] Capture current `make test-repl` baseline pass count → expected `975 PASS / 0 FAIL / 2 SKIP`
- [x] Capture current `make test-repl-banking` baseline → expected `30 PASS`
- [x] Capture current `make test-repl-banking-skip` baseline → expected `21 PASS + 3 SKIP`
- [x] Capture current `make check-doc-sync` baseline → expected `31 advisories / 0 drift`
- [x] Re-confirm `BANK_TABLE_BASE = $D400`, `ACTIVE_PAGES_BASE = $D4AE`, `BANK_TABLE_CAP = 29`, `BANK_TABLE_ENTRY_SIZE = 6` in `src/banking.asm:22..37` (per AC1 / Q2 totals computation paths). Re-confirm `(IY+UserArea.bank_count)` semantics + zero-extension invariant at `src/structures.asm:47`.
- [x] Re-confirm `cl_emit_hex_byte` (Story 17.4) location at `src/antforth.asm:627` and its calling-convention preservation requirements (clobbers A/BC/DE/HL per its comment) — needed for the per-row PAGE column print.
- [x] Re-confirm `w_DOT_cf` / `w_U_DOT_cf` / `w_U_DOT_R_cf` locations + DEFWORD-vs-DEFCODE distinction in `src/formatting.asm:184..232` — needed for the BANK column + FREE totals print.
- [x] Re-confirm `bdos_print_str` / `bdos_putchar` / `bdos_crlf` clobber sets in `src/io.asm:188..225` — known callable from DEFCODE bodies.
- [x] Re-derive the Q1 (a) column-layout ASCII width inventory: print one mock row at 28-bank cap (highest free total = `475136` = 6 chars) and confirm < 80 cols.

### Task 1 — `.BANKS` DEFCODE body in `src/banking.asm` (AC1, AC2, AC4, AC9)

- [x] 1.1 — Insert `w_DOT_BANKS` DEFCODE entry after `w_SET_BANK_cf` body in `src/banking.asm` (post-file-end of the existing Story 17.3 + 17.4 surface). Use the standard `DEFCODE ".BANKS", 0` header; CFA via `w_DOT_BANKS_cf` label.
- [x] 1.2 — Source-comment blocks above the DEFCODE: AC6 CCD-3 flag block FIRST (`; antforth extension .BANKS — see docs/antforth-banking-redesign.md §1`); AC5 Epic-17-minimal-form rationale block SECOND (`; .BANKS — Epic 17 minimal form. ... Epic 22 polishes ...`). Both blocks visible to grep + future-reader-protective per the established CCD-3 source-flag pattern.
- [x] 1.3 — Body: (1) print header row literal via `LD HL, str_dot_banks_hdr; LD B, str_dot_banks_hdr_len; CALL bdos_print_str; CALL bdos_crlf`; (2) bootstrap row-walk: `LD HL, ACTIVE_PAGES_BASE; LD A, (IY+UserArea.bank_count); CP 0; JR Z, .totals` (skip rows if `bank_count = 0` — edge case (vi) from CL parser); else `LD B, 0` (B = loop counter / current-row index).
- [x] 1.4 — Per-row body: (a) print BANK column (decimal, right-aligned 4-col — Q3 sub-disposition below); (b) print space + PAGE column (2 hex via `cl_emit_hex_byte`); (c) print marker: `LD A, B; CP (IY+UserArea.current_bank); JR Z, .star; LD E, ' '; JR .marker_done; .star: LD E, '*'; .marker_done: CALL bdos_putchar; LD E, ' '; CALL bdos_putchar`; (d) print used+free placeholder literals via `LD HL, str_used_zero; LD B, str_used_zero_len; CALL bdos_print_str; LD HL, str_free_full; LD B, str_free_full_len; CALL bdos_print_str`; (e) `CALL bdos_crlf`. Loop epilogue: `INC HL; INC B; LD A, (IY+UserArea.bank_count); CP B; JR NZ, .row_loop`.
- [x] 1.5 — Totals-row body (post-loop, `.totals` label): print `TOTAL` left-aligned in BANK column (5-char literal + padding), blank PAGE column (4 spaces), blank marker column (2 spaces), `     0` used (re-use `str_used_zero` literal), computed `free_total` via Q2-(b) `bank_count << 14` formula, CRLF. Print computed free via `w_U_DOT_R_cf` with right-align width = 6 (right-align matches header column).
- [x] 1.6 — String literals appended after the DEFCODE body: `str_dot_banks_hdr` (Q1=a "`BANK PAGE  USED   FREE`" + CRLF embedded OR separate `bdos_crlf` call) + `str_dot_banks_hdr_len` EQU; `str_used_zero` ("`     0`" 6 chars) + `str_used_zero_len` EQU; `str_free_full` ("` 16384`" 6 chars) + `str_free_full_len` EQU; `str_total` ("`TOTAL`" 5 chars) + `str_total_len` EQU; column-pad literals as needed.

**Q3 (BANK-column print — reuse `w_DOT_cf` vs hand-rolled 1-2 digit decimal):**
  - **(a) Reuse `w_DOT_cf`:** push BC onto DStack via `PUSH BC; LD BC, <index>; PUSH BC; LD DE, w_DOT_cf; ...` — but `w_DOT_cf` is a DEFWORD (not DEFCODE), so calling it from inside another DEFCODE requires the DOCOL/NEXT inner-interpreter dance; awkward and costly (~20-25 B per call site).
  - **(b) Reuse `w_U_DOT_R_cf` (right-aligned)** — same DEFWORD issue.
  - **(c) Hand-rolled 1-2 digit decimal printer:** at most 2 digits (0..28); `LD A, B; CP 10; JR C, .single; LD C, '0'-1; .tens: INC C; SUB 10; JR NC, .tens; ADD 10; LD E, C; CALL bdos_putchar; .single: ADD '0'; LD E, A; CALL bdos_putchar; (with appropriate leading-space padding for right-align)` — ~25-30 B but completely self-contained.
  - **(d) Hand-rolled with `cl_emit_hex_byte`-style helper** — `.BANKS` adds a new `bank_emit_dec_byte` helper similar in shape to `cl_emit_hex_byte`; ~25-30 B for the helper + ~5-8 B per call site.
  - **Recommended:** (c) inline hand-rolled. Single call site (only the per-row BANK column); no DOCOL/NEXT plumbing; self-contained; total cost (~25-30 B inline) is comparable to (a)/(b) DEFWORD-call overhead.

### Task 2 — Compliance-doc row + project-context update (AC6)

- [x] 2.1 — Append one row to `docs/ans-forth-core-compliance.md` antforth-extensions table at the end of the 9-BANK* block (post-`SET-BANK` row at the file's current line ~877): `| \`.BANKS\` | \`banking.asm:<line-of-w_DOT_BANKS>\` | Non-standard (antforth extension — see \`docs/antforth-banking-redesign.md\` §1; FR-P4-6 — minimal form; per-bank used/free are placeholders, Epic 19 makes them real, Epic 22 polishes formatting) |`.
- [x] 2.2 — Verify no other compliance-doc surface needs an update (Story 17.5 ships 1 wordset word; no §6.x rows affected because `.BANKS` is an antforth extension not a Core word).

### Task 3 — `tests/banking_tests.fth` `.BANKS` probes (AC7)

- [x] 3.1 — Probe X (header + row-count at default 12 banks): append to `tests/banking_tests.fth` after the existing Story 17.4 / Story 17.3 probe blocks. Pattern: print `." ---DOT-BANKS-PROBE-X-START---"` + CRLF, call `.BANKS`, print `." ---DOT-BANKS-PROBE-X-END---"` + CRLF. Makefile `test-repl-banking` grep-asserts: between the sentinels, presence of `BANK PAGE` header substring; presence of `TOTAL` keyword; presence of `196608` (12 × 16384) on totals.
- [x] 3.2 — Probe Y (current-bank marker tracking): print sentinel-start; `.BANKS` (at boot, marker on row 0); print mid-sentinel; `1 BANK!`; `.BANKS` (marker on row 1); `0 BANK!` (restore); print sentinel-end. Makefile grep-asserts: between start-mid sentinels, marker `*` appears in column-position-N (the 5th char of the bank-0 row text); between mid-end sentinels, marker `*` appears in same column-position on the bank-1 row.
- [x] 3.3 — Probe Z (placeholder values): print sentinel-start; `.BANKS`; print sentinel-end. Makefile grep-asserts: every row between sentinels (except header and totals) contains the `0  16384` substring (or whatever the Q1=a column-aligned form produces). This guards against accidental scope creep into real per-bank-HERE reads.
- [x] 3.4 — Probe W (totals row): part of Probe X if grep can multiple-pattern; OR separate probe for cleaner assertion shape. Assert: `TOTAL` keyword present + `196608` decimal present on same line (or adjacent lines if line-wrap concerns surface).
- [x] 3.5 — All 4 probes annotated PASS on iz-cpm baseline + PASS on iz-cpm-banking (surface-AGNOSTIC per AC7); no SKIPs introduced.

### Task 4 — `Makefile` `test-repl-banking` + `test-repl-banking-skip` recipe extension (AC10)

- [x] 4.1 — Extend `test-repl-banking` grep-list with 4 new patterns (or 3 if Probe X+W folded): `DOT-BANKS-PROBE-X` header + row-count assertions; `DOT-BANKS-PROBE-Y` marker-tracking; `DOT-BANKS-PROBE-Z` placeholders; `DOT-BANKS-PROBE-W` totals (if separate). Post-Task-4 count: `30 + 4 = 34 PASS` (or `30 + 3 = 33 PASS` if Probe W folded into Probe X).
- [x] 4.2 — Extend `test-repl-banking-skip` with the same 4 (or 3) patterns annotated PASS-on-both-surfaces per AC7 surface-agnostic disposition. Post-Task-4 count: `21 + 3 + 4 = 28 PASS` (no new SKIPs — `.BANKS` is surface-agnostic; the existing 3 SKIPs from Story 17.4 carry forward unchanged).

### Task 5 — Build + regression (AC10, AC9)

- [x] 5.1 — `make asm` exits 0 / 0 warnings. If new JR-out-of-range errors surface (the .BANKS body adds ~100+ B; layout may shift), convert offending JRs to JPs per Story 17.4 precedent.
- [x] 5.2 — `make test-repl` = `975 PASS / 0 FAIL / 2 SKIP` (baseline preserved per FR-P4-41 / NFR-P4-10). If test-643 hangs surface after binary growth, re-tune the 3-NOP slot at `src/antforth.asm:188..190` per `feedback_iz_cpm_test_643_quirk.md`.
- [x] 5.3 — `make test-repl-banking` = `34 PASS` (or `33 PASS` per Task 4.1 disposition).
- [x] 5.4 — `make test-repl-banking-skip` = `28 PASS + 3 SKIP` (or `27 PASS + 3 SKIP`).
- [x] 5.5 — `make check-doc-sync` exits 0; advisory count `≤ 32` (was 31 post-17.4; one new compliance-doc row may add at most 1 advisory).
- [x] 5.6 — `wc -c build/antforth.com` post-edit; record absolute size + delta against the dev-pass-start baseline. Target ≤ +160 B per AC9 noise tolerance. If > +160 B, surface for SCP evaluation per Q6-d precedent (Story 17.4 close).

### Task 6 — Hardware-smoke (AC8)

**DEFERRED to user-triggered hardware run** per `feedback_follow_process.md` and the established S9 precedent (Stories 17.1/17.2/17.3/17.4). Hardware smoke runs are user-initiated outside the dev-pass loop. The dev-pass cannot transfer `build/antforth.com` to real MicroBeast via SLIDE — that's a physical-machine action. Hardware verdict is the project lead's to capture at S9 time. Story status flips to `review` without Task 6 closed; hardware verdict + transcript path get appended to Completion Notes + File List at that time per the Story 17.4 Task 9 closure precedent.

- [x] 6.1 — Build `build/antforth.com`; transfer to real MicroBeast via SLIDE. Transferred 2026-05-16.
- [x] 6.2 — Single human-typed run per Lesson 16-A — booted with default `antforth` (12 banks). Executed 7-step probe per AC8: `.BANKS` (initial, marker only on row 0) ✓ column-stable layout with post-review header alignment ✓ 80-col fit ✓; `1 BANK!`; `.BANKS` (marker only on row 1) ✓; `0 BANK!`; `.BANKS` (marker back only on row 0) ✓. Totals `196608` (= 12 × 16384) ✓.
- [x] 6.3 — Optional second boot with non-default CL tail `antforth 22 35-37` exercised — 4-bank shorter table; `.BANKS` shows 4 rows (logical 0..3 / pages 22 + 35..37); totals `65536` (= 4 × 16384) ✓ confirms bank_count-varying totals computation works on hardware.
- [x] 6.4 — Transcript saved at `~/Downloads/beastty-20260516-225900.bin` (98,538 B terminal capture).
- [x] 6.5 — Verdict + transcript path appended to Completion Notes + File List + Change Log (this story file).

### Task 7 — Sprint-status + commit

- [x] 7.1 — `sprint-status.yaml`: 17-5 row flipped `ready-for-dev → in-progress → review` at dev-pass close.
- [x] 7.2 — Commit per user trigger (per `feedback_no_claude_coauthor.md`: NEVER add Claude co-author trailer in this repo). Suggested subject template: `Story 17.5: §banking .BANKS minimal-form (header + N rows + totals; * marker tracking; +~<actual> B / target ~80-140 B; cumulative Epic-17 ~<actual>/400 B accept-with-rationale)`.
- [x] 7.3 — Deliverables recorded in File List section below. Hardware transcript path TBD post-Task-6 user-triggered run.

### Review Follow-ups (AI) — 2026-05-16 code-review pass

Findings from the adversarial code-review pass on this story file. HIGH + MEDIUM items are fixed inline (see Change Log entry); LOW + deferred items are listed for follow-up.

- [x] [AI-Review][HIGH] H1 — AC4 column-stability defect: header literal `"BANK PAGE  USED   FREE"` (22 B) was off-by-1 vs per-row + totals (23 B) for USED + FREE right-edges. Fixed by widening header to `"BANK PAGE   USED   FREE"` (23 B); `str_dot_banks_hdr_len` EQU now 23. +1 B kernel-binary (`src/banking.asm:715-716`).
- [x] [AI-Review][MEDIUM] M2 — Probe Y marker-tracking regex only asserted marker PRESENCE on the expected row; bug putting `*` on every row would have passed. Tightened both copies of the recipe (test-repl-banking + test-repl-banking-skip) to additionally assert `grep -cE '\*' == 1` per phase, so the marker is now verified EXCLUSIVELY on the expected row (`Makefile:215-232, 339-358`).
- [x] [AI-Review][MEDIUM] M3 — Probe X marker regex used `\*?` (optional `*`). Now covered transitively by M2's exclusivity assertion in probe Y; X remains intentionally loose for row-COUNT / format verification only.
- [x] [AI-Review][HIGH] H2 — Pre-existing latent: `_probe-plus-bank-cap` (Probe G, Story-17.3 origin) silently false-PASSes via Makefile substring-grep matching the source-text echo of its `." PASS: ..."` literal. The DO LOOP body in `_do-29-+bank` trips the +BANK cap mid-loop (boot bank_count = 12, not 0; +17 adds hit cap), ABORT propagates uncaught past the CATCH. Per `feedback_no_preexisting_discharge.md`, this cannot be discharged as "pre-existing". Filed as new sprint-status row `17-5-1-probe-g-plus-bank-cap-false-pass-fix: ready-for-dev` (slots before Story 17.6 per project-lead direction 2026-05-16).
- [x] [AI-Review][MEDIUM] M4 — AC9 +245 B (post-H1) > AC9 +160 B noise tolerance trigger. **Project lead ACCEPTED 2026-05-16: Q6=a-extended (accept-with-rationale forward).** Cumulative Epic-17 envelope ~1,200 B / ~400 B (~300%) — consistent with Story-17.4 precedent; Epic-17 retro absorbs the overage. AC9 flipped to PASS in the verdict table above.
- [ ] [AI-Review][MEDIUM] M1 — `.BANKS` mixes formatting bases in non-decimal BASE: BANK col is hardcoded decimal, PAGE is hardcoded hex, per-row USED/FREE are literal decimal strings, but totals FREE follows BASE via D.R. In HEX mode the totals print "30000" alongside per-row "16384". Deferred to Epic 22 polish (per `epics-phase4-epics-16-22.md` Epic 22 line on `.BANKS` final formatting). Story 22.1 owns the unified-base rendering decision.
- [ ] [AI-Review][LOW] L1 — File List line ranges are off by 1-2 (`print_bank_col_4` is 678..712 not 678..713). Cosmetic.
- [ ] [AI-Review][LOW] L2 — ~10 lines of Q1-Q7 disposition prose in `src/banking.asm:528-536` duplicates Dev Notes content. Optional trim per `feedback_ceremony_diminishing_returns.md`.

## Dev Notes

### Project context

- **Story 17.5 is the fifth binary-delta story of Phase 4.** Story
  17.4 closed 2026-05-16 with 25,983 B / 975 PASS / 0 FAIL /
  2 SKIP-on-iz-cpm / 30 PASS on test-repl-banking / 21 PASS +
  3 SKIP on test-repl-banking-skip. Epic-17 envelope post-17.4 =
  955 B / ~400 B = 239% (Q6-a-extended ACCEPTED 2026-05-16 by
  project lead "AC9 overage is fine"; carry-forward disposition
  binding into Story 17.5). Story 17.5's estimated ~115-140 B
  contribution pushes cumulative to ~1,070-1,095 B / ~400 B
  (~268-274%) at Story 17.5 close — surfaced at story-draft time
  per B.4 figure-drift discipline; project-lead direction at
  dev-pass start is the binding pick per Q6 dispositions
  (recommended (a) accept-with-rationale forward).
- **Epic 17 ships antforth 3.0.1** at Story 17.6 close-out (the
  iron-spike + tag story). **Story 17.4 owned the banner-version
  edit from `v2.0.0` to `v3.0.1`** (Q10=a confirmed); Story 17.6
  owns the README + memory-`description` field updates + the git
  tag application. **Story 17.5 does NOT touch the banner.**
- **Phase-4 wordset progress** (12 words total per redesign §1):
  - Story 17.1 shipped 2 words: `BANK-MAPPING-ON`, `BANK-MAPPING-OFF`
    (2/12).
  - Story 17.2 shipped 3 words: `BANK@`, `BANK!`, `BANKS` (5/12).
  - Story 17.3 shipped 4 words: `+BANK`, `-BANK`, `BANKS-CLEAR`,
    `SET-BANK` (9/12).
  - Story 17.4 shipped 0 user-facing wordset words (CL parser is
    boot-time machinery, NOT a Forth word). Wordset count
    unchanged at 9/12.
  - **Story 17.5 ships 1 user-facing wordset word: `.BANKS`
    (minimal form). Post-17.5 wordset count: 10/12.**
  - Remaining 2 (`IN-BANK`, `BANK-OF`) are Epic 18.
  - At Story 17.6 close, Epic 17 has shipped 10 of 12 user-facing
    wordset words + the boot-config surface (CL parser + banner).
- **`.BANKS` minimal form vs polished form** — Story 17.5 ships
  the MVP per architecture.md:483 Epic-22 budget line
  (`.BANKS` ~80 B; prompt indicator ~20 B; Epic-22 polish ~100 B
  total). Story 17.5 lands ~80 B of the ~100 B Epic-22-allocated
  budget (because the FR-P4-6 minimal form IS the load-bearing
  surface; Epic 22 polishes the column formatting + adds the
  optional REPL prompt indicator integration). The placeholder
  framing for per-bank used/free is the AC2 spec binding; Epic
  19's bank-aware `:` makes the values real (per
  `epics-phase4-epics-16-22.md:1064..1070` — Epic 19 AC5 explicitly
  updates Story 17.5's `.BANKS` probe to assert real per-bank
  used/free values after `5 BANK! : SOME-WORD ;`).

### Architectural inputs consumed

- **Story 17.1** (banking foundation). Story 17.5 directly
  consumes:
  - `BANK_TABLE_BASE = $D400` + `ACTIVE_PAGES_BASE = $D4AE` from
    `src/banking.asm:22..37`. The `.BANKS` row-walk loop iterates
    `active_pages[0..bank_count-1]` starting at `ACTIVE_PAGES_BASE`.
  - UserArea cells `current_bank` (for the `*` marker comparison)
    + `bank_count` (for the loop bound). Both cells at
    `src/structures.asm:41,47`.
- **Story 17.2** (`BANK@` / `BANK!` / `BANKS`). Story 17.5
  directly consumes:
  - `(IY+UserArea.current_bank)` read pattern from `w_BANK_AT_cf`
    body (`src/banking.asm:102..103`) — re-used for the `*`
    marker comparison.
  - `(IY+UserArea.bank_count)` read pattern from `w_BANKS_cf`
    body (`src/banking.asm:255..256`) — re-used for the loop
    bound + totals computation.
- **Story 17.3** (`+BANK` / `-BANK` / `BANKS-CLEAR` / `SET-BANK`).
  Story 17.5 directly consumes:
  - The `active_pages[]` array populated by `+BANK` / drained
    by `-BANK` / cleared by `BANKS-CLEAR`. `.BANKS` walks
    whatever is currently in the array.
- **Story 17.4** (CL parser + banner + `cl_emit_hex_byte`). Story
  17.5 directly consumes:
  - `cl_emit_hex_byte` helper at `src/antforth.asm:627` — re-used
    for the PAGE column (2-hex-digit print). Clobber set:
    A/BC/DE/HL per its comment block.
  - The `active_pages[]` populated by the CL parser at boot —
    Story 17.5's `.BANKS` walks the post-CL state.
  - The H3-fix LDIR clone at `src/antforth.asm:175..189` —
    bank-table[N][0..1] is populated for all N at boot (the
    placeholder `0 / 16384` per-bank-row in Story 17.5 does
    NOT depend on this, but the Epic-19 follow-up that makes the
    values real WILL depend on it).
- **PRD FR-P4-6** (`docs/_bmad-output/planning-artifacts/prd.md:519`)
  — wordset-entry spec for `.BANKS`.
- **Redesign §1 row** (`docs/antforth-banking-redesign.md:18`) —
  `.BANKS` "Introspection" category entry with the
  summary-table semantics binding.
- **Architecture.md:483 Epic-22 budget line** — `.BANKS ~80 B`
  budget allocation; Story 17.5 lands the bulk of this; Epic 22
  polishes (column formatting + prompt indicator).
- **Story 16.4 §9.3 closure** — PD-P4-14 (architecture.md:406..427):
  six-edge-case warn-and-continue policy for the CL parser.
  Story 17.5 inherits the (vi) empty-surviving-list path:
  if `bank_count = 0` (CL parser emitted `empty?` warning,
  user reached the REPL with no banks), `.BANKS` MUST handle
  the zero-row case gracefully (print header + totals with
  `free_total = 0`; do NOT print any per-bank rows).

### Source-file structure (post-Story-17.4, pre-edit)

The current `src/banking.asm` post-17.4:

```
Line  1: file header / Phase-4 banking subsystem comment
Line 16-37: Phase-4 banking constants (BANK_TABLE_CAP, etc.)
Line 39-58: BANK-MAPPING-ON DEFCODE
Line 60-87: BANK-MAPPING-OFF DEFCODE + BIOS WBOOT escape
Line 90-105: BANK@ DEFCODE
Line 106-206: BANK! DEFCODE + .abort_bank + str_bank_q literal
Line 250-258: BANKS DEFCODE (VALUE proxy)
Line 260-360: +BANK DEFCODE + cl_probe_and_add helper +
              .abort_probe + .abort_cap + str_probe_q +
              str_cap_q literals
Line 403-466: -BANK DEFCODE
Line 469-487: BANKS-CLEAR DEFCODE
Line 490-501: SET-BANK DEFCODE (end of file pre-17.5)
```

Story 17.5 inserts `.BANKS` DEFCODE + string literals + comment
blocks at the file's current end (after `w_SET_BANK_cf`). Total
new lines: ~50-70 (DEFCODE body + 4-5 string literals + 2
source-comment blocks).

### Column-layout ASCII inventory (Q1=a recommended form)

Verified at draft time per AC4 80-col-fit binding requirement:

```
12345678901234567890123456789012345678901234567890
BANK PAGE  USED   FREE                            (header, 22 chars)
   0   22 *    0  16384                           (row, 22 chars)
   1   35      0  16384                           (row, 22 chars)
  ...
  11   3F      0  16384                           (row, 22 chars)
TOTAL          0 196608                           (totals, 22 chars; max at 12-bank default)
TOTAL          0 475136                           (totals at 28-bank cap; 22 chars)
```

Max row width: 22 chars + CRLF = 24 chars per line. Well inside
80-col limit. Column boundaries: BANK (0-3), space (4), PAGE (5-7),
space (8), marker (9), space (10), USED (11-15), space (16), FREE
(17-22). All columns right-aligned (except `TOTAL` which is
left-aligned in BANK column starting at col 0).

### Sentinel choice for probe text (re-confirmation from Story 17.4 CL-probes)

Story 17.4's CL probes use `cl-probe-<name>` sentinels (kebab-case,
prefixed with `cl-probe-` for grep deterministic). Story 17.5 adopts
the same convention: `dot-banks-probe-<name>-start` /
`dot-banks-probe-<name>-end` sentinels delimit each `.BANKS`-output
probe block. The Makefile grep patterns key on `dot-banks-probe-*`
prefix. The sentinels are printed via `." ..."` in the .fth file
and appear in the captured emulator stdout.

### iz-cpm baseline probe disposition (surface-AGNOSTIC for .BANKS)

`.BANKS` is fundamentally a console-output word: it reads
`(IY+UserArea.bank_count)` + `(IY+UserArea.current_bank)` +
walks `active_pages[]` (a fixed-memory array at `$D4AE`). It does
NOT touch port 0x70/0x72/0x74 (no MMU operations). Therefore the
`.BANKS` output is identical on iz-cpm baseline and iz-cpm-banking
(both populate `active_pages[]` identically via the CL parser's
default-12-banks path — see Story 17.4 AC10 iz-cpm-baseline
analysis). All 4 AC7 `.BANKS` probes annotate PASS-on-both-surfaces.

This contrasts with the Story 17.4 CL probes (which SKIP on iz-cpm
baseline because the actual MMU operations are no-op-traced) — the
`.BANKS` surface-agnosticity is a genuine win.

### Banner integration scope (NONE in Story 17.5)

The banner was advanced to `v3.0.1` + `- N banks available` clause
in Story 17.4. **Story 17.5 does NOT touch the banner.** The `.BANKS`
word stands alone as a user-callable introspection surface. The
banner's per-boot bank-count is the same information surfaced by
`.BANKS`'s totals row, but the banner is one-shot (boot-time) and
`.BANKS` is on-demand (REPL-callable).

### Body byte-budget (per-component itemisation — pre-edit estimate)

See AC9 for the load-bearing per-component itemisation. Summary:

| Component                                    | Estimated cost |
|----------------------------------------------|----------------|
| `.BANKS` DEFCODE header                      | ~14 B          |
| Header-row literal + len EQU                 | ~24 B          |
| Per-row loop body (BANK/PAGE/marker/USED/FREE/CRLF) | ~35-45 B inline |
| One-time literals (`str_used_zero`, `str_free_full`) | ~12-16 B |
| Totals-row print + computation               | ~30-40 B       |
| BANK-column hand-rolled decimal printer (Q3=c) | ~25-30 B  |
| CCD-3 + AC5 source-comment blocks            | 0 B (comments) |
| Compliance-doc row                           | 0 B            |
| REPL probes in `tests/banking_tests.fth`     | 0 B            |
| **Total estimated kernel-binary delta**      | **~115-140 B** |

**Envelope-pressure note (B.4 transparency):** post-17.4 cumulative
Epic-17 envelope = 955 B / ~400 B (239%). Story 17.5 estimated
~115-140 B brings cumulative to **~1,070-1,095 B / ~400 B
(~268-274%)** at Story 17.5 close. Per Story 17.4 Q6-a-extended
disposition (ACCEPTED 2026-05-16), the per-epic envelope is
guidance not contract; Epic-17 retro absorbs the cumulative overage.
Empirical-reality > planning-estimate pattern (~2.4-2.7× the
redesign-§7 ~400 B guidance) carries forward as a Phase-4
future-epic-envelope-estimation calibration data point.

### Standing commitments touched

- **S2 (REPL-piped Forth tests)** — Task 3 ships 4 `.BANKS` probes
  in `tests/banking_tests.fth` as REPL-piped probes per
  `feedback_repl_tests_preferred.md`; AC7 binding minimum = 4.
- **S9 (per-story hardware smoke)** — Task 6 is the S9 hardware-
  smoke probe batch; NFR-P4-11 applies to Story 17.5 as a
  binary-delta story.
- **S11 (user-visible version surface audit at tag close-out)** —
  Story 17.5 does NOT touch the banner; Story 17.6 owns the S11
  audit at tag application.
- **S12 (hardware-typed probe authoring discipline)** — Task 6.2
  is a single human-typed run (Lesson 16-A); the 7-step probe
  sequence (3 `.BANKS` calls + 2 `BANK!` switches) is type-able
  by a human in <2 minutes.

### Forward inheritance pointers

- **Story 17.6** inherits:
  - `.BANKS` user-facing word (10/12 wordset slot) — usable in
    the iron-spike + included in the S11 user-visible-version-
    surface audit (`.BANKS` is one of the 9 user-callable words
    available post-Story-17.5 for hardware-typed validation).
  - The verdict-table walk at Story 17.6 close includes Story
    17.5 PASS verdict per the Story-13.5.6 precedent.
  - Epic-17 envelope close-out figure includes Story 17.5
    contribution (~115-140 B; cumulative ~1,070-1,095 B / 400 B
    target; Q6-a-extended acceptance carries through).
- **Epic 18** inherits:
  - `.BANKS` as a debugging/observability tool for the descriptor-
    stub allocator + cross-bank dispatch experiments. After
    Epic 18 ships, `.BANKS` can be augmented with a stub-count
    column (banked-word count per bank) — but that's Epic 22
    polish work, not Epic 18.
- **Epic 19** inherits:
  - `.BANKS` placeholder-form scaffolding — Epic 19's bank-aware
    `:` makes per-bank HERE real; Epic 19's AC5 (per
    `epics-phase4-epics-16-22.md:1064..1070`) updates Story 17.5's
    `.BANKS` probe to assert real per-bank used / free values
    after `5 BANK! : SOME-WORD ;`. The `.BANKS` source itself
    needs to be updated to READ from each bank's `bank-table[N][0]`
    (HERE) instead of emitting the literal "0" / "16384" — this
    is Epic 19 source-edit work, NOT Story 17.5 scope.
- **Epic 22** inherits:
  - **Polish — column formatting:** Story 17.5 ships the Q1=a
    compact form; Epic 22 may revisit for wider columns or
    additional columns (banked-word count, last-defined-word
    name, etc.).
  - **Polish — REPL prompt indicator integration:** the
    architecture.md:483 Epic-22 budget line allocates `~20 B`
    for a prompt indicator (e.g., displaying `[bank 5] ok` in
    the REPL prompt). Independent of `.BANKS` per se but
    thematically related — Epic 22 may co-design the prompt
    indicator's display format with the `.BANKS` row format.
  - **Polish — `BANKS-CLEAR` + zero-bank `.BANKS` edge case:**
    Story 17.5 handles the zero-bank case (no per-bank rows;
    `total_free = 0`) but the visual presentation could be
    "no banks active" prose rather than an empty table; Epic
    22 polish call.

### Lessons applied

- **Lesson 16-A** (single human-typed hardware run) — Task 6 is
  a single human-typed run, not a probe batch. Verdict captured
  manually per the Story 17.4 Task 9 closure precedent.
- **Lesson 14-F** (ceremony has diminishing returns) — Story
  17.5 keeps the task list lean: 7 tasks (DEFCODE body + compliance
  doc + Forth probes + Makefile + build + hardware + sprint).
  Direct kernel edits + Makefile recipe extension + the standard
  test surface. The envelope-pressure surfaced in AC9 / Q6 is a
  SUBSTANTIVE concern, not ceremony; the project-lead direction
  at dev-pass start is binding without further codification.
- **Lesson 13.5-C / B.2** (no "mirrors prior arm" rationale) —
  AC9 byte-budget is per-component-itemised. No "this is the
  `.BANKS` arm of the pattern from Story 17.4" rationale; every
  component named with its opcode-level byte cost. References to
  Story 17.4's `cl_emit_hex_byte` helper (which Story 17.5 re-uses
  for the PAGE column) are FOR CONTEXT (the helper is a
  zero-cost re-use, not a body-shape mirror) — they are NOT
  load-bearing for byte-budget estimation. The Story 17.5
  per-iteration row-loop body is independently estimated at
  ~35-45 B based on the explicit op-level cost inventory in AC9.
- **B.3 / Lesson 13.5-F** (binary handoff) — Pre-edit baseline
  tasks re-`wc -c` and re-derive the 975-PASS baseline at
  dev-pass start; do not inherit any figure from this story's
  text (the 25,983 B / 30-PASS test-repl-banking figures are
  Story 17.4 close-out values that may have shifted via
  hitch-hiker commits).
- **B.4 / PD-2** (figure-drift discipline) — every figure quoted
  in this story (25,983 B baseline; 955 B cumulative envelope;
  ~115-140 B Story 17.5 estimate; 196608 = 12*16384 default-12-
  banks total; 475136 = 29*16384 cap-bank total; column-positions
  in the AC4 ASCII layout) is re-validated at dev-pass start by
  re-reading the cited source file or re-running the cited
  command.

### Project Structure Notes

- **`.BANKS` placement** — `src/banking.asm` (alongside the other
  9 BANK* DEFCODE words; the file is already the canonical
  Phase-4 banking surface per Story 17.1's authoring decision).
  No alternative location considered — `.BANKS` is clearly a
  banking-wordset word per its FR-P4-6 categorisation.
- **Column-layout** — Q1. Recommended: (a) compact form (22-char
  rows; matches `WORDS` / `.S` density precedent).
- **Totals computation** — Q2. Recommended: (b) compute
  post-loop as `bank_count << 14` (simpler asm; ~10-15 B; vs
  (a) running-sum which adds ~5-8 B to each loop iteration =
  ~60-100 B over 12 iterations).
- **BANK-column print** — Q3. Recommended: (c) hand-rolled
  inline decimal printer (~25-30 B; no DEFWORD-call overhead).
- **Q6 (envelope):** see §"Body byte-budget" + AC9. Recommended:
  (a) accept-with-rationale forward (Q6-a-extended carries
  through from Story 17.4).
- **Q7 (Makefile recipe shape):** N/A for Story 17.5 — the
  Story 17.4 per-variant-loop pattern (Q7=b) doesn't apply
  because `.BANKS` doesn't need per-variant CL-tail invocations;
  the existing single-invocation `tests/banking_tests.fth` flow
  pipes all `.BANKS` probes through one `iz-cpm-banking
  antforth.com` call.

### References

- [Source: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md`:561..582] — Story 17.5 spec (FRs covered: FR-P4-6 minimal form; final polish in Epic 22)
- [Source: `_bmad-output/planning-artifacts/prd.md`:519] — FR-P4-6 wordset-entry spec for `.BANKS`
- [Source: `_bmad-output/planning-artifacts/prd.md`:101,127,306,331] — `.BANKS` UX statements + 12-word wordset enumeration
- [Source: `_bmad-output/planning-artifacts/architecture.md`:45] — FR-P4-1..12 banking wordset architectural impact
- [Source: `_bmad-output/planning-artifacts/architecture.md`:425..427] — PD-P4-14 §9.3 closure pointer to Story 17.5 carrying post-CL state into `.BANKS` behavioural assertions
- [Source: `_bmad-output/planning-artifacts/architecture.md`:461,483,844,1092] — Epic 22 polish line including `.BANKS` (+~80 B budget)
- [Source: `docs/antforth-banking-redesign.md`:18] — `.BANKS` introspection row (semantics binding)
- [Source: `docs/antforth-banking-redesign.md`:145] — Epic 22 polish allocation including `.BANKS` formatting
- [Source: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md`:1064..1070] — Epic 19 AC5 updates Story 17.5's `.BANKS` probe to assert real per-bank used/free after bank-aware `:`
- [Source: `_bmad-output/implementation-artifacts/17-1-bank-table-allocator-userarea-cells-bank-mapping-on-bank-mapping-off-ccp-eviction-memory-map-edit.md`] — Story 17.1 close-out: bank-table base + UserArea cell semantics
- [Source: `_bmad-output/implementation-artifacts/17-2-bank-fetch-bank-store-banks-read-and-swap-primitives.md`] — Story 17.2 close-out: BANK@/BANK!/BANKS + current_bank cell read pattern
- [Source: `_bmad-output/implementation-artifacts/17-3-plus-bank-with-probe-on-add-minus-bank-banks-clear-set-bank.md`] — Story 17.3 close-out: active_pages[] population semantics
- [Source: `_bmad-output/implementation-artifacts/17-4-cl-tail-parser-boot-configuration-banner-update.md`] — Story 17.4 close-out: cl_emit_hex_byte helper + 30-PASS test-repl-banking baseline + cumulative envelope 955 B + Q6-a-extended acceptance disposition
- [Source: `src/banking.asm`:22..37] — `BANK_TABLE_BASE` / `ACTIVE_PAGES_BASE` / `BANK_TABLE_CAP` / `BANK_TABLE_ENTRY_SIZE` constants
- [Source: `src/banking.asm`:99..103] — `w_BANK_AT_cf` body (template for current_bank cell read in marker comparison)
- [Source: `src/banking.asm`:252..258] — `w_BANKS_cf` body (template for bank_count cell read in loop bound)
- [Source: `src/banking.asm`:289..360] — `w_PLUS_BANK_cf` + `cl_probe_and_add` (template for `active_pages[]` write semantics — Story 17.5 reads only)
- [Source: `src/structures.asm`:39..47] — Phase-4 UserArea cells (`saved_bank`, `current_bank`, `bank_table_base`, `bank_mapping_state`, `bank_count`)
- [Source: `src/antforth.asm`:175..189] — H3-fix LDIR clone of bank-table[0] triple to bank-table[1..28] at COLD (load-bearing for Epic 19's per-bank-HERE story; informational for Story 17.5)
- [Source: `src/antforth.asm`:627..645] — `cl_emit_hex_byte` / `cl_emit_hex_digit` helpers (Story 17.4) — re-used by Story 17.5 PAGE column print
- [Source: `src/formatting.asm`:184..232] — `w_DOT_cf` / `w_U_DOT_cf` / `w_U_DOT_R_cf` (DEFWORD definitions; reuse candidates considered in Q3, rejected for DOCOL/NEXT plumbing overhead)
- [Source: `src/io.asm`:188..225] — `bdos_putchar` / `bdos_crlf` / `bdos_print_str` (print primitives; clobber sets documented)
- [Source: `docs/ans-forth-core-compliance.md`:869..877] — existing 9-BANK*-word antforth-extensions table block (Story 17.5 appends one row)
- [Source: `Makefile`:88..128,200..209] — `test-repl-banking` + `test-repl-banking-skip` recipes (Story 17.5 extends grep-patterns)
- [Source: `tests/banking_tests.fth`] — 4 `.BANKS` probe blocks appended by Story 17.5 (existing 61 PASS/FAIL markers at file's current end)
- [Source: `_bmad-output/implementation-artifacts/epic-16-retro-2026-05-15.md`] — Lesson 16-A (single human-typed hardware run) precedent
- [Source: `tests/README.md`] — three-test-surface convention + SKIP-with-rationale shape (Story 17.5 probes annotate PASS-on-both-surfaces per AC7 surface-agnostic disposition)

## Questions for project lead

These ambiguities surfaced during story drafting. Each is annotated
with a recommended resolution; the dev-pass proceeds per the
recommendation unless overridden at dev-pass start.

- **Q1 (Column layout — compact vs widened):** AC2 + AC4 + Task
  1.6. Two candidate forms:
  - **(a) Compact form** (22-char rows; matches `.S` / `WORDS`
    density precedent; ~24 B header literal):
    ```
    BANK PAGE  USED   FREE
       0   22 *    0  16384
       1   35      0  16384
    TOTAL          0 196608
    ```
  - **(b) Widened form** (~30-char rows; uses more of the 80-col
    budget; ~38 B header literal; ~10 B more on the literal
    side):
    ```
    BANK   PAGE   ACTIVE      USED        FREE
       0     22      *         0       16384
    TOTAL                      0      196608
    ```
  **Recommended:** (a). Saves ~10 B literal; matches the
  established antforth console-output density precedent. Either
  form: fits within 80 cols at 29-bank cap.
- **Q2 (Totals-row computation — running-sum vs post-loop multiply):**
  AC3 + Task 1.5.
  - **(a) Running-sum** during the per-row walk (DE += 16384 per
    row, print at end). Adds ~5-8 B per loop iteration (~60-100 B
    cumulative over 12 iterations).
  - **(b) Post-loop multiply** `total_free = bank_count * 16384`
    via `bank_count << 14` (two `ADD HL,HL` shifts after seeding
    HL with high-byte = bank_count, low-byte = 0). One-shot;
    ~10-15 B total cost.
  - **(c) Literal-emit** (hardcode totals for known bank-counts)
    — rejected (bank_count varies post-`+BANK` / `-BANK`).
  **Recommended:** (b). Order-of-magnitude cheaper; simpler asm
  shape; the multiply is a literal shift not a real multiply.
- **Q3 (BANK-column decimal printer — reuse `w_DOT_cf` vs hand-
  rolled inline vs new helper):** AC2 + Task 1.4.
  - **(a) Reuse `w_DOT_cf`** (DEFWORD) via DOCOL/NEXT plumbing —
    ~20-25 B per call site (PUSH BC + LD BC + PUSH BC + LD DE,
    w_DOT_cf + JP NEXT semantics for inner-interpreter call from
    DEFCODE).
  - **(b) Reuse `w_U_DOT_R_cf`** (right-aligned width) — same
    DEFWORD-call overhead as (a).
  - **(c) Hand-rolled inline 1-2 digit decimal printer** — ~25-30 B
    inline; self-contained; no DEFWORD plumbing. Single call site
    (only the per-row BANK column).
  - **(d) New `bank_emit_dec_byte` helper** — ~25-30 B for the
    helper + ~5-8 B per call site (one site = ~30-38 B total).
  **Recommended:** (c). Lowest total cost (no DEFWORD-call
  overhead, no helper-creation overhead); single call site so no
  helper-reuse savings to capture.
- **Q4 (Page-column hex prefix — bare hex vs `$NN`):** AC2.
  - **(a) Bare hex** (e.g., `22`, `35`) — matches the CL parser's
    bank-list syntax + the `probe? NN` / `dup? NN` warning text.
  - **(b) `$NN` prefix** (e.g., `$22`, `$35`) — Forth-traditional
    hex literal prefix; visually distinguishes hex from decimal.
  **Recommended:** (a). Consistent with Story 17.3 + 17.4 console
  output; users already adjusted to bare-hex page numbers via the
  CL syntax + warning texts.
- **Q5 (Zero-bank `.BANKS` edge case — empty table vs "no banks"
  message):** AC1 + AC2 + PD-P4-14 (vi) inheritance.
  - **(a) Empty table** — print header + totals (with
    `total_free = 0`) + skip the per-bank-row loop. Visually
    clean: `BANK PAGE  USED   FREE\nTOTAL          0      0\n`.
  - **(b) "No banks active" prose** — print a one-line message
    like `No banks active.\n`; skip the table entirely.
  - **(c) Header + totals with zero rows** — same as (a).
  **Recommended:** (a) = (c). The table form is consistent with
  the non-zero case; zero rows is a degenerate but valid table
  shape; the totals row makes it clear the count is zero. Avoids
  introducing prose-style branch logic. Epic 22 may revisit for
  prose polish.
- **Q6 (Cumulative envelope pressure — accept vs SCP vs descope):**
  AC9 §"Envelope-pressure note" + Story 17.4 Q6-a-extended
  precedent (ACCEPTED 2026-05-16). Post-17.5 projected cumulative
  envelope ~1,070-1,095 B / ~400 B (~268-274%). Three dispositions:
  - **(a) accept-with-rationale forward** — Q6-a-extended carries
    through; Epic-17 retro line item already in flight.
    **Recommended.**
  - **(b) descope `.BANKS` to header+totals only** — saves
    ~80-100 B; fundamentally changes FR-P4-6 deliverable from
    "status TABLE" to "status SUMMARY"; rejected at story-draft
    on the grounds that per-bank-row + marker tracking is the
    FR-P4-6 load-bearing surface.
  - **(c) defer `.BANKS` to Epic 22 polish** — closes Epic 17
    with 9-of-12-wordset shipped; missing the wordset-completion
    contract; rejected.
  **Recommended:** (a). The accept-with-rationale precedent from
  Story 17.4 carries forward without further ceremony.
- **Q7 (Probe-output capture — sentinel-and-grep vs Forth-side
  count):** AC7 + Task 3.
  - **(a) Sentinel-and-grep** — `.BANKS` between
    `." ---DOT-BANKS-PROBE-X-START---"` and
    `." ---DOT-BANKS-PROBE-X-END---"` sentinels; Makefile
    grep-asserts on the captured stdout. Matches Story 17.4
    `cl-probe-*` pattern.
  - **(b) Forth-side line-count** — redirect output to a counted
    buffer, count CRLFs, assert ≥ 14 at default-12-banks. Heavy
    plumbing (no existing console-redirect infrastructure).
  **Recommended:** (a). Matches Story 17.4 precedent; no new
  infrastructure; grep is deterministic.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (1M context) — claude-opus-4-7[1m]

### Debug Log References

Dev-pass 2026-05-16. Pre-edit baseline re-`wc -c`-confirmed at **25,983 B / 975 PASS / 30 PASS (test-repl-banking) / 21 PASS + 3 SKIP (test-repl-banking-skip) / 31 advisories / 0 drift (check-doc-sync)**.

**Bug found + fixed in `print_bank_col_4` helper (Story 17.5 self-discovery):** initial draft emitted the 2 leading spaces via `LD E, ' '; CALL bdos_putchar` then read A for `CP 10`. BDOS function 2 (C_WRITE) returns through A, so the bank-index value was clobbered and every BANK col printed "0". Fixed by stashing A across the leading-space emissions via PUSH AF / POP AF (single-digit path: same fix). Verified end-to-end: row 0 shows "   0", row 10 shows "  10", row 11 shows "  11", marker '*' tracks current_bank correctly across `BANK!`.

**Story-spec defect noted (Q2(b) print-primitive):** the story's Q2 disposition (b) recommended printing the totals free via `w_U_DOT_R_cf` (~10-15 B). That recommendation is INFEASIBLE because (a) `U.R` is a DEFWORD not a DEFCODE (Q3 already names the same issue for `w_DOT_cf`), and (b) max free total = 29 × 16384 = 475136 overflows the 16-bit single-cell that U.R consumes. The Q2(b) computation formula `bank_count << 14` is correct, but the print step has to switch to double-cell (D.R, `( d +n -- )`). Fix in `src/banking.asm:w_DOT_BANKS_cf`: park caller TOS on data stack + caller IP on R-stack, run header+per-row inline, then for totals row, compute (d-low, d-high) from `bank_count`, set IP to a 3-cell inline thread `[w_D_DOT_R_cf, w_CR_cf, EXIT_CODE]` and NEXT into it; EXIT_CODE pops the saved caller IP, resumes the caller's thread, BC lands on the saved caller TOS at the right SP-depth, so the `( -- )` stack effect holds.

**Pre-existing test-infra latent surfaced (NOT fixed in this story):** `_probe-plus-bank-cap` in `tests/banking_tests.fth` (Probe G, Story-17.3 origin) does `_do-29-+bank` then asserts BANKS=29 + CATCH on the 30th +BANK. In actual runs under `iz-cpm-banking`, the `29 0 DO $22 +BANK LOOP` body trips the cap mid-loop and the ABORT propagates uncaught past `_probe-plus-bank-cap`, leaving bank_count=29 / BASE=16 (BASE flipped to HEX somewhere along the THROW recovery path — root cause unclear, did not investigate further as out-of-scope for Story 17.5). The Makefile recipe's grep for `PASS: plus-bank-cap` false-PASSes via the source-echoed `." PASS: plus-bank-cap ..."` literal regardless of whether the PASS branch ran. Workaround applied to Story-17.5 probes only: each probe colon definition opens with `_dot-banks-setup` (DECIMAL + BANKS-CLEAR + 12 unrolled `$22 +BANK` calls; no DO LOOP) for reproducible 12-bank state. Full fix of the pre-existing latent is out-of-scope (suggest filing a separate cleanup story; the Makefile grep pattern is the load-bearing root cause — substring grep on source-echoed text is brittle; recommend switching to sentinel-bounded grep for assertion patterns that don't overlap the source text).

**Q1–Q7 dispositions (story-recommended picks adopted):**
- Q1=a (compact column form) ✓
- Q2=b (`bank_count << 14` for totals) ✓ — print primitive switched single→double per defect note above
- Q3=c (hand-rolled inline 1-2 digit decimal printer) ✓ — split into `print_bank_col_4` helper (~40 B) for clean single call site
- Q4=a (bare-hex PAGE column) ✓ — re-uses `cl_emit_hex_byte` (Story 17.4)
- Q5=a (zero-bank case: header + totals only) ✓
- Q6=a-extended (accept-with-rationale forward) ✓ — see AC9 analysis
- Q7=a (sentinel-and-grep probe pattern) ✓

### Completion Notes List

**Implementation summary:**
- `.BANKS` DEFCODE shipped in `src/banking.asm:539..705` (after `w_SET_BANK_cf`) with body + helper + literals + Q1-Q7 disposition source-comment block. CCD-3 source flag + AC5 Epic-17-minimal-form rationale block stacked above the DEFCODE per the established CCD-3 pattern.
- `_dot-banks-setup` + 4 probe colon-definitions appended to `tests/banking_tests.fth:428..511` with surface-AGNOSTIC sentinel-and-grep pattern. Manual unrolled `12× $22 +BANK` setup sidesteps the pre-existing probe-G DO LOOP latent.
- Compliance-doc row appended to `docs/ans-forth-core-compliance.md` antforth-extensions table at the end of the 9-BANK* block (post-`SET-BANK` row, file line 878).
- Makefile `test-repl-banking` extended with 4 sentinel-bounded grep recipes (probes X / Y / Z / W); `test-repl-banking-skip` extended with the 3 surface-agnostic probes (X / Y / W; Z is surface-redundant per AC10 disposition).

**AC verdict table (re-validated post-review-pass 2026-05-16):**
- AC1 (DEFCODE + source location) — PASS (DEFCODE at `src/banking.asm:552`; body at `src/banking.asm:554..663`)
- AC2 (per-row content + format) — PASS (BANK col 4-char right-aligned decimal via `print_bank_col_4` helper at `src/banking.asm:678..712`; PAGE 2-hex via `cl_emit_hex_byte`; marker `*`/` `; USED/FREE placeholder literals)
- AC3 (totals row) — PASS (`TOTAL          0 <free_total>` with computed 24-bit free via D.R width-6 — inline thread at `src/banking.asm:664..666`; per-spec-defect note above, switched single→double cell)
- AC4 (column widths stable + 80-col fit) — PASS (post-review-fix: header literal widened from 22 B → 23 B so USED + FREE right-edges align at cols 15 + 22 respectively across header, per-bank rows, and totals row; per-row 23 chars + CRLF; well inside 80 cols at 29-bank cap with 6-digit free total)
- AC5 (source-comment block) — PASS (`src/banking.asm:547..551`; "Epic 17 minimal form" + Epic 19/22 inheritance pointers)
- AC6 (CCD-3 source flag + compliance-doc row) — PASS (source flag at `src/banking.asm:546`; compliance-doc row at `docs/ans-forth-core-compliance.md:878`)
- AC7 (REPL probes — 4 binding) — PASS (X / Y / Z / W in `tests/banking_tests.fth:451..510`; all PASS on iz-cpm-banking; review-pass tightened probe Y Makefile recipe to assert exactly 1 `*` per phase, catching "marker on every row" failure mode)
- AC8 (hardware smoke) — **PASS** (hardware smoke ran 2026-05-16; transcript at `~/Downloads/beastty-20260516-225900.bin`). Primary boot (default 12 banks): `.BANKS` shows header + 12 rows + totals `196608`; marker tracks `*` exclusively on row 0 → row 1 (after `1 BANK!`) → back to row 0 (after `0 BANK!`); post-review-fix column alignment (USED right-edge col 15, FREE right-edge col 22) confirmed on real terminal. Secondary boot `antforth 22 35-37` (4-bank shorter table): `.BANKS` shows 4 rows + totals `65536` — confirms bank_count-varying totals computation works on hardware.
- AC9 (binary delta + envelope) — **PASS (Q6=a-extended accept-with-rationale; project lead ACCEPTED 2026-05-16 at review-pass close)**. Measured delta **+245 B** (25,983 → 26,228; +244 B dev-pass + 1 B from H1 review-fix header widening) exceeds the AC9 +160 B noise tolerance trigger. Cumulative Epic-17 envelope now **~1,200 B / ~400 B (~300%)**. Per Story 17.4 Q6-a-extended precedent (project_epic17_envelope memory note: ~2.4× empirical pattern accepted), Epic-17 retro absorbs the cumulative overage. The empirical-reality > planning-estimate pattern (~2.4-2.7×) carries forward as the binding Phase-4 future-epic-envelope calibration data point.
- AC10 (regression baseline + banking-emu probes) — PASS: `make test-repl` = **975 PASS / 0 FAIL / 2 SKIP** (baseline preserved per FR-P4-41 / NFR-P4-10); `make test-repl-banking` = **34 PASS** (was 30; +4 new probes; probe Y tightened post-review); `make test-repl-banking-skip` = **24 PASS + 3 SKIP** (was 21+3; +3 surface-agnostic probes X / Y / W; probe Y tightened post-review); `make check-doc-sync` = **31 advisories / 0 drift** (unchanged; the new compliance-doc row didn't introduce a new advisory because it's consistent with the 9 existing BANK* rows).

**Post-edit binary size:** 26,228 B (delta +245 B; +244 B dev-pass + 1 B H1 review-fix).

**Post-HW-smoke recipe (typed-out for the hardware run — feedback_post_hw_smoke_steps_at_review.md):**
The hardware-smoke deliverable (`build/antforth.com`) is ready. To execute the AC8 probe sequence on real MicroBeast:
  1. Transfer `build/antforth.com` to MicroBeast via SLIDE.
  2. At the `B>` CCP prompt: `antforth` (boots default 12 banks; banner shows `v3.0.1`).
  3. Type `.BANKS`. Visually inspect: header row + 12 data rows (logical bank 0..11) + totals row; `*` on row 0 (portal page 22h); column-stability across rows; total output fits the terminal width without wrapping.
  4. Type `1 BANK!`. Expect `ok`.
  5. Type `.BANKS`. Verify `*` now appears on row 1 (page 35h); all other columns unchanged from step 3.
  6. Type `0 BANK!`. Expect `ok`.
  7. Type `.BANKS`. Verify `*` back on row 0.
  8. Optional second boot: `antforth 22 35-37` (4-bank config); type `.BANKS`; verify 4 data rows + smaller totals (`65536`).
  9. Capture transcript per the established `~/Downloads/beastty-<date>.bin` naming.

After the hardware run, append the verdict + transcript path here to close Task 6 and AC8.

### File List

**Source code (kernel binary):**
- `src/banking.asm` — appended `.BANKS` section (lines 503..721): section comment block (503..545) + CCD-3 source flag (546) + AC5 rationale block (547..551) + `w_DOT_BANKS` DEFCODE (552..663) + inline totals thread (664..666) + `print_bank_col_4` helper (678..712) + 4 string literals + length EQUs (714..721). **Post-review-fix:** `str_dot_banks_hdr` widened from 22 B → 23 B (H1 AC4 column-stability fix); `str_dot_banks_hdr_len` EQU updated 22 → 23; header-prose comment updated to reflect aligned right-edges.

**Documentation:**
- `docs/ans-forth-core-compliance.md` — appended `.BANKS` row to antforth-extensions table at the end of the 9-BANK* block (line 878).

**Test surface (no kernel-binary contribution):**
- `tests/banking_tests.fth` — appended Story 17.5 probe block (lines 428..511): comment block + `_dot-banks-setup` helper (lines 450..456) + 4 probe colon-definitions (`_dot-banks-probe-x` 461..467 / `_dot-banks-probe-y` 473..487 / `_dot-banks-probe-z` 493..500 / `_dot-banks-probe-w` 503..510) + their invocation lines.
- `Makefile` — appended `test-repl-banking` block (4 sentinel-bounded grep recipes for probes X / Y / Z / W after the Story-17.4 CL-tail probe section); appended `test-repl-banking-skip` block (3 surface-agnostic probe recipes X / Y / W; Z is surface-redundant per AC10). **Post-review-fix:** both copies of the probe-Y recipe tightened to additionally assert `grep -cE '\*' == 1` per phase (marker-exclusivity check; M2 fix).

**Sprint tracking:**
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `17-5-dot-banks-minimal-working-form` row flipped `ready-for-dev → review`. **Post-review-fix:** added new row `17-5-1-probe-g-plus-bank-cap-false-pass-fix: backlog` between 17.5 and 17.6 (filed per `feedback_no_preexisting_discharge.md`; H2 follow-up).

**Hardware-smoke transcript:**
- `~/Downloads/beastty-20260516-225900.bin` — 98,538 B terminal capture; covers both primary 12-bank boot (full 7-step `.BANKS` / `BANK!` / `.BANKS` probe sequence with marker tracking row 0 → 1 → 0) and secondary 4-bank boot (`antforth 22 35-37`; 4 rows + totals 65536). Captured 2026-05-16.

### Change Log

- 2026-05-16: **Hardware smoke complete (Task 6 / AC8).** Transcript `~/Downloads/beastty-20260516-225900.bin`. Primary 12-bank boot: all 7 steps PASS (column alignment, marker exclusivity 0→1→0, totals 196608). Secondary 4-bank boot (`antforth 22 35-37`): PASS — confirms bank_count-varying totals (65536). All Task 6 boxes flipped `[x]`; AC8 verdict flipped DEFERRED → PASS. Story 17.5 now fully closed at all 10 ACs.
- 2026-05-16: **Review pass close-out — project lead dispositioned remaining items.** M4 (AC9 envelope): ACCEPTED Q6=a-extended; AC9 flipped to PASS. H2 follow-up: promoted from `backlog` → `ready-for-dev`, slotted before Story 17.6 in sprint-status.yaml. Status flipped `review → done`.
- 2026-05-16: **Review pass (AI code-review).** Adversarial review found 2 HIGH + 4 MEDIUM + 2 LOW findings. Fixed inline: H1 (AC4 column-stability — header literal widened to align USED + FREE right-edges across header / per-bank rows / totals; +1 B kernel); M2 (probe Y marker-exclusivity — Makefile recipe now asserts exactly 1 `*` per phase; M3 covered transitively). Filed inline: H2 (probe G pre-existing false-PASS — new sprint-status row `17-5-1-probe-g-plus-bank-cap-false-pass-fix`). Surfaced for project-lead disposition: M4 (AC9 +245 B vs +160 B noise tolerance — Q6=a-extended recommended). Deferred to Epic 22: M1 (`.BANKS` BASE-handling unification). L1 + L2 noted as cosmetic, not actioned. Post-review tests: `make test-repl` = 975 PASS / 0 FAIL / 2 SKIP (baseline preserved); `make test-repl-banking` = 34 PASS; `make test-repl-banking-skip` = 24 PASS + 3 SKIP; `make check-doc-sync` = 31 advisories / 0 drift. Binary: 26,228 B (delta +245 B from 17.4 baseline).
- 2026-05-16: Story 17.5 dev-pass complete. `.BANKS` ships as a DEFCODE in `src/banking.asm` with the Q1=a compact column form (BANK PAGE + USED FREE placeholders + `*` current-bank marker + TOTAL row). Header + per-row inline; totals row uses inline-thread call to D.R for double-cell printing (single-cell U.R rejected as 24-bit value overflow risk — Q2 print-primitive defect-fix). +244 B (target ≤160 B) — SCP-trigger surfaced; Q6-a-extended accept-with-rationale carried forward per Story 17.4 close-out precedent. 4 surface-AGNOSTIC REPL probes (X / Y / Z / W) added to `tests/banking_tests.fth` with reproducibility wrapper (`_dot-banks-setup` — manual unrolled 12× `$22 +BANK` setup; sidesteps a pre-existing Probe-G DO LOOP latent that leaves bank_count=29 / BASE=16 post-probe-G). Compliance-doc row added. `make test-repl-banking` = 34 PASS (was 30); `make test-repl-banking-skip` = 24 PASS + 3 SKIP (was 21+3); `make test-repl` = 975 PASS / 0 FAIL / 2 SKIP (baseline preserved); `make check-doc-sync` = 31 advisories / 0 drift. Task 6 hardware-smoke deferred to user-triggered run per S9 + `feedback_follow_process.md`.
