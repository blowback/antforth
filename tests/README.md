# antforth tests — probe-authoring conventions

This file documents the conventions every author should follow when writing a
REPL-piped Forth probe (one of the `printf … | $(IZCPM) … $(TARGET)` pipelines
in `Makefile`'s `test-repl:` recipe) or a hardware-typed smoke-batch destined
for human typing on real CP/M 2.2 / MicroBeast.

The conventions encoded here came from concrete in-pass incidents during
Phase-2's Epic-13.5 cleanup-slate (Stories 13.5.1, 13.5.4, 13.5.6) and Story
13.6's hardware-smoke pass on real MicroBeast hardware. Each section names
the story that motivated the rule.

Cross-reference: the canonical, fuller statement of these conventions lives
in `_bmad-output/planning-artifacts/architecture.md` § "Process Patterns
(Phase-3-specific)". This README is the colocated, test-author-facing
summary.

---

## 1. Canonical transient buffer — PAD

For one-shot scratch space that must survive a single space-delimited
parse step, **use `PAD`**.

`PAD` is defined by ANS Forth 1994 §6.2.2000:

> `PAD ( -- c-addr )` — `c-addr` is the address of a transient region
> that can be used to hold data for intermediate processing.

ANS §3.3.3.6 pins the survival guarantee:

> The address returned by `PAD` shall be transient … A program may use
> the storage at the address as long as the application does not perform
> any intermediate operations that may require use of the same area:
> applications shall not assume that the contents of the region survive
> the application's parsing of any one space-delimited name.

In other words: `PAD`'s contents survive **at least one** space-delimited
parse step (one `WORD` call). Any storage that must outlive a single
parse step needs a different buffer class — see Section 3.

### antforth-specific implementation

In antforth, `PAD` returns `HERE + 84`:

- The word lands at `src/memory.asm:147` (`DEFCODE "PAD", 0`; body at
  `w_PAD_cf` immediately after the comment block at `src/memory.asm:133..145`).
- The offset is pinned by `PAD_OFFSET EQU 84` at `src/constants.asm:44`.
- The `/PAD` ENVIRONMENT? query returns `( 84 -1 )` (see
  `src/system.asm:458..460`), confirming the offset publicly.

Why HERE+84 satisfies §3.3.3.6 in normal use: `WORD` writes its
counted-string output at `HERE+0..HERE+u` — count byte at HERE+0, chars
at HERE+1..HERE+u (`src/strings.asm:85` for the `INC HL` past the count
byte; `:145` for the count store). The character count `u` is the actual
length of the parsed token; `WORD` itself does **not** clamp to
`F_LENMASK` (that mask is the dictionary-header name-length cap, applied
later in `src/compiler.asm:203..207` when a CREATEd name is stored, not
in `WORD`). For Forth tokens of conventional length (≤ 31 chars), `u`
stays ≤ 31, leaving `HERE+32..HERE+84+` untouched and PAD safe across
exactly one parse step. The hard upper bound is TIB length (128 bytes,
`src/constants.asm:41`), so a pathologically long single token (≥ 84
chars) would corrupt PAD — never expected in normal Forth source, and
the reason §4(b)'s TIB-128 lint is part of the discipline.

`PAD`-the-word landed in Story 13.5.4 (TD-6 closure, commit 6208a81) — it
did not exist in earlier antforth releases even though the `/PAD`
ENVIRONMENT? entry shipped from Epic-12 onwards. Probes targeting
post-2.0.0 antforth can rely on `PAD`; probes targeting pre-13.5.4 builds
cannot.

### Canonical idiom

The hardware-validated canonical idiom (Story 13.5.6 hardware Task 5
line 14, real CP/M 2.2 / MicroBeast PASS):

```forth
S" hi" PAD SWAP MOVE PAD 2 TYPE
```

Output: `hi`.

Stack trace, left to right:
- `S" hi"` pushes `( c-addr-S 2 )` — a counted string in the S" buffer.
- `PAD` pushes `c-addr-PAD` → stack: `( c-addr-S 2 c-addr-PAD )`.
- `SWAP` → `( c-addr-S c-addr-PAD 2 )` — the `MOVE` argument order.
- `MOVE` per ANS §6.1.1900 propagates 2 chars from `c-addr-S` into PAD.
- `PAD 2 TYPE` emits the two PAD bytes — `hi`.

Note: antforth implements `MOVE` (`src/memory.asm:292`, ANS §6.1.1900),
**not** `CMOVE` (DPANS94 §6.2.0945). See Section 4 for the
word-existence pre-flight discipline that catches this kind of slip.

---

## 2. Why not `HERE`

Pre-Story-13.5.4, when no `PAD` word existed, probe authors reached for
`HERE` (the dictionary boundary cursor) as a scratch buffer. Within a
single REPL line that worked. **Across REPL lines it corrupts silently.**

### The collision mechanism

The outer interpreter (`INTERPRET`, `src/outer_interpreter.asm:178..217`)
calls `WORD` once per token to scan the next space-delimited name from
TIB. `WORD` writes that name to `HERE` as a counted string: count byte
at `HERE+0`, chars at `HERE+1..HERE+u` (`src/strings.asm:78..150`). Any
byte you stored at `HERE+0..HERE+u` is destroyed the next time
`INTERPRET` scans a token — i.e. on **every** subsequent word in the
input stream, including the first token of the next REPL line.

Note: antforth's `S"` interpret-mode itself uses a separate transient
buffer (`s_quote_buf`, `src/strings.asm:739, :787`) and does **not**
write its parsed chars to `HERE`. So `S"` is not the direct allocator
of the corruption — the clobber comes from whatever token `INTERPRET`
parses *next* (any token will do; `WORD` is invoked unconditionally per
loop iteration in `src/outer_interpreter.asm:179..180`).

Concretely (Story 13.5.1's surfaced shape):

1. Line N: a probe writes data into a HERE-backed destination
   (e.g. `READ-FILE` pulls one byte to `HERE`).
2. Line N+1: the next REPL line's first parse step (any token —
   `S" T45B="`, `BYE`, `.`, anything) makes `INTERPRET` call `WORD`,
   which writes the new counted string at `HERE+0..HERE+u`, clobbering
   the byte stored on Line N.
3. `HERE C@` on Line N+1 returns the count byte from the next token's
   parse, **not** the read byte. Probe asserts the wrong value; the
   test silently passes for the wrong reason or fails with a confusing
   diff.

### Why HERE is volatile by design

`HERE` is the dictionary-allotment cursor. The threading model
deliberately uses `HERE+0..HERE+31` as parser scratch on every parse
step — the region is *meant* to be overwritten. Storing user data there
is structurally unsafe, not incidentally so.

### Where this was surfaced

- **Story 13.5.1 (TD-1/TD-2/TD-4 R/W per-FCB dirty-flag)** —
  `_bmad-output/implementation-artifacts/13.5-1-td-1-td-2-td-4-r-w-per-fcb-dirty-flag.md:650, :729, :749`.
  Probes (p2)/(p3)/(p4) initial drafts used `S" …"` for write-source +
  `HERE` for read-destination. The `HERE C@` post-`READ-FILE` returned
  the residual `S"` byte rather than the read byte. Fixed in-pass by
  switching to ALLOTed buffers `B45`/`B46`/`B47` (see Makefile REPL
  tests 944..948).
- **Story 13.6 hardware finding F-9** —
  `_bmad-output/implementation-artifacts/13-6-epic-13-fs-stress-bdos-audit-and-antforth-2-0-release-gate-ccd-4.md:1192`.
  Same shape, caught on real CP/M / MicroBeast: the file content
  reproducer surfaced as `\x04type\x1A` instead of the expected file
  content. Disposition recorded the structural diagnosis: *HERE is
  volatile across REPL lines.*
- **Story 13.5.4 (TD-6 PAD / HERE-cross-line correctness)** —
  `_bmad-output/implementation-artifacts/13.5-4-td-6-pad-here-cross-line-correctness.md:34..46`.
  Pinned the structural-fact pair: (i) `/PAD` ENVIRONMENT? claimed an
  84-byte region without `PAD`-the-word existing pre-13.5.4; (ii) every
  parse step writes ≤32 bytes at `HERE+0..HERE+31`, leaving
  `HERE+32..HERE+84+` untouched, so PAD-at-HERE+84 satisfies §3.3.3.6's
  single-parse survival guarantee by construction.

---

## 3. Buffer-class selection rubric

Three classes cover every transient-buffer need in REPL-piped probes:

| Class | Lifetime | How | When |
|---|---|---|---|
| **One-shot transient** | Survives exactly one space-delimited parse step | `PAD` (per ANS §6.2.2000 / §3.3.3.6) | Default for any probe needing scratch on a single REPL line — e.g. `S" hi" PAD SWAP MOVE PAD 2 TYPE` outputs `hi` |
| **Cross-parse named buffer** | Survives across multiple parse steps / multiple REPL lines | `CREATE B45 32 ALLOT` (or analogous) | Probes that span multiple lines / multiple parse steps — e.g. write a file, close, re-open, read back into the same buffer |
| **Never near HERE** | (No valid use for user data) | — | Avoid. `S"` and `WORD` write at `HERE+0..HERE+31` on every parse step; user data stored there is destroyed by the next parse step |

### One-shot transient — `PAD`

```forth
S" hi" PAD SWAP MOVE PAD 2 TYPE   \ outputs: hi
```

This is the canonical idiom. All bytes are touched within a single
REPL line (one parse step bounds the lifetime). PAD = HERE+84 puts the
data outside the WORD scratch region.

### Cross-parse named buffer — `CREATE … ALLOT`

The canonical Phase-2 application is Story 13.5.1's `B45`/`B46`/`B47`
in `Makefile` REPL tests 944..948. The pattern:

```forth
VARIABLE FA  CREATE B45 16 ALLOT
65 B45 C!
S" TS1351MX.TXT" R/W CREATE-FILE DROP FA !
B45 1 FA @ WRITE-FILE DROP
0 0 FA @ REPOSITION-FILE DROP
FA @ CLOSE-FILE DROP
S" TS1351MX.TXT" R/O OPEN-FILE DROP FA !
S" T45B=" TYPE B45 1 FA @ READ-FILE DROP DROP B45 C@ . CR
```

`B45` is a named, `ALLOT`ed buffer at a fixed dictionary address. Its
contents survive across every line of the probe — `S" T45B="` on a
later line cannot clobber `B45` because `B45` lives below the moving
HERE cursor, not at it. Use `B46`, `B47`, etc. when the probe needs
multiple cross-parse buffers (the names are conventional, not
load-bearing).

### Never near HERE — anti-pattern

The bug is cross-line, so the anti-pattern has to be an interpreted
multi-line REPL sequence — **not** a colon body. (Inside `: ... ;`,
`S"` compiles to `(S")` + a precompiled inline literal and runtime
does not call `WORD`, so the colon-body shape masks the failure mode.)

```text
REPL line N+0:  S" hi" HERE SWAP MOVE   \ writes "hi" to HERE+0..HERE+1
REPL line N+1:  HERE C@ .               \ expected 'h' (104) — actually
                                        \ returns the count byte from
                                        \ the *next* token INTERPRET's
                                        \ WORD scanned ('H' from "HERE",
                                        \ count = 4)
```

The corruption is structural: `INTERPRET` calls `WORD` on every token
of every subsequent REPL line, and `WORD` always writes at `HERE+0..`
(count byte plus chars). Anything you stored at `HERE+0..HERE+u` is
gone before the next read. Use `PAD` (one parse step) or an `ALLOT`ed
named buffer (cross-parse) — never `HERE`.

### Selection summary

- **One parse step / single REPL line** → `PAD`.
- **Multiple parse steps / multiple REPL lines** → `CREATE B45 N ALLOT`.
- **Anywhere in `HERE+0..HERE+31`** → never; this is parser scratch.

---

## 4. S12 — hardware-typed probe authoring discipline

A smoke-batch typed by a human at the MicroBeast keyboard has an extra
constraint set on top of the buffer-choice rules: every line must reach
the kernel exactly as authored, and every word must resolve. The two
mechanical pre-flights below are mandatory before committing any
hardware-typed probe (codified as S12 / NFR-P3-33 in the Phase-3 PRD).

### (a) Word-existence pre-flight

Every word in the probe must resolve in antforth's dictionary, or be
documented as a planned new word being introduced by the same story.

Mechanical check: extract the words and cross-reference against `WORDS`
output or the kernel source.

Motivating example: **Story 13.5.6 run-1 CMOVE-vs-MOVE incident**
(`_bmad-output/implementation-artifacts/13.5-6-epic-13-5-close-out-gate-and-antforth-2-0-tag.md:798`).
The dev-pass authored a hardware spot-check that used `CMOVE` (DPANS94
§6.2.0945), but antforth implements `MOVE` (`src/memory.asm:292`, ANS
§6.1.1900) and not `CMOVE`. Real-hardware run-1 produced `error -13:
undefined word`. Run-2 fix replaced `CMOVE` with `MOVE`; the probe then
PASSed. A pre-flight against `WORDS` would have caught this before the
batch was typed.

### (b) TIB-128 line-length lint

Every line in the probe must be ≤ 128 characters. antforth's input
buffer (TIB) is 128 bytes (`src/constants.asm:41`, `TIB_SIZE EQU 128`).
A line longer than 128 chars is silently truncated — the kernel sees a
different probe than what was typed.

Mechanical check:

```sh
awk 'length > 128' tests/*.fth
```

A clean pre-flight returns no rows. Probes intended for hardware-typing
must split logically across lines that fit.

**Probe colon-def corollary (Story 15.5).** The 128-char limit applies
to the source line as typed, not to the conceptual probe step. A
colon definition that folds verdict logic across constructs can grow
past 128 chars in a single line even when the logical step looks
small. Story 15.5's Probe 3 `TRY-CREATE` hit 134 chars after a CR-pass
fix added a per-iteration close-ior fold; truncation cut `NFILES`
mid-token and cascaded `error -13: undefined word`. Resolution: split
the colon-def at a `THEN` / `;` / `LOOP` boundary (legal in compile
state). Treat any colon-def line approaching 128 chars as a refactor
candidate before hardware paste.

### (c) iz-cpm-vs-hardware verdict-shape divergence (Story 15.5)

iz-cpm sanity-pass is **necessary but not sufficient** for any probe
whose load-bearing verdict is hardware-only.

Two recurring failure modes documented at Story 15.5 (transcripts
`~/Downloads/beastty-20260509-{123943,134543}.bin`):

- **Echoed source-line grep false-positive.** iz-cpm's Makefile grep
  can match a literal verdict-token string (`T6V=NO_LIMIT` etc.) in
  the *echoed source line* of `S" T6V=NO_LIMIT" TYPE`, not in actual
  probe output. Run-1 SKIP'd a real probe-design defect (bare-REPL
  `IF/ELSE/THEN` raising THROW −14) because the grep matched the echo,
  not the missing verdict. Mitigation: replace string-literal verdict
  tokens with numeric codes (`T6V=1`/`T6V=0` etc.); source-echo can no
  longer false-positive grep matches on numeric values.
- **Hardware-only failure paths.** Code paths that only execute under
  resource exhaustion (disk-full, directory-full) or specific REPL
  state-context boundaries cannot be exercised by iz-cpm's host-bounded
  filesystem. CR-1 M1 in Story 15.5 proposed a fix that iz-cpm
  sanity-passed but introduced `error -4: stack underflow` on the
  hardware-only failure path — surfaced only on real MicroBeast.

**Discipline.** Treat /CR proposed fixes that touch a probe's
hardware-only code path as hypotheses, not ready-to-merge edits.
Re-run on real hardware before merging. Probe authors should
explicitly identify which assertions are iz-cpm-load-bearing vs
hardware-load-bearing in a `\ ` comment near each probe stanza so
future readers know which path was actually verified where.

### Cross-reference

The full statement of S12 — including the rationale, the integration
into the dev-pass workflow, and the relationship to the Phase-3
standing-commitment set — lives in
`_bmad-output/planning-artifacts/architecture.md` § "Probe-authoring
discipline (S12 / NFR-P3-33)". This README summarises the rules; the
architecture document is the canonical authority.

---

## Story-archaeology footnote

The convention described above was assembled out of three concrete
incidents:

- Story 13.5.1's S"-vs-HERE collision in-pass (the structural diagnosis
  and the ALLOTed-buffer fix).
- Story 13.6's F-9 hardware reproducer (the same shape on real
  CP/M / MicroBeast).
- Story 13.5.4's PAD-the-word landing (HERE+84, ANS §6.2.2000) plus the
  documented §3.3.3.6 single-parse-survival proof.

Story 14.1 (Phase-3 carry-forward item B.1) is what made these
conventions discoverable in one place. Every probe author who hits a
buffer-choice question after 14.1 should land here first.
