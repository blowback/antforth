# Story 23.6: Banked dictionary window-top overflow guard

Status: stub (needs create-story expansion before dev)

<!-- Numbered 23.6 to avoid the existing 23.4 (ud-environment-query-gaps) /
     23.5 (close-out) slots; re-home during epic planning if it fits better
     under a banking epic than Epic 23 (standards & I/O polish). -->

<!-- STUB drafted 2026-06-28 from a Story 23.2 code-review finding (#5).
     Not yet run through create-story / validate-create-story. The technical
     analysis below is load-bearing — it was derived from live source during
     the review; do NOT re-discover it, but DO expand ACs + tasks formally. -->

## Problem

A banked definition whose body crosses the slot-2 window top (`$C000`) is
silently broken — and broken at *execution* time, not just under `TO`.

The banked dictionary lives in the slot-2 window `$8000..$BFFF` (16 KB). The
defining words place a word's code field at the live banked `HERE` and emit the
body just above it (`CONSTANT`/`VALUE` value cell at `CFA+3`; `CREATE` does-slot
at `CFA+3..4`; `:` threaded body upward). The runtime doers read the body
through slot 2 only — `DOCON`/`DOVALUE` read `cf+3` (`src/inner_interpreter.asm`),
`(TO)` writes `cf+3` via `to_resolve_map_hl` which maps **slot 2** alone
(`mbb_set_slot2`). If `cf+3` (or any body byte) lands at or past `$C000`, that
byte resolves through **slot 3**, i.e. whatever page is mapped there — wrong
bank / fixed memory. Result: a banked word that reads or writes a corrupt high
byte with no diagnostic.

There is currently **no bound** on banked `HERE`: a search of the defining path
finds no dictionary-full / window-top check and no `-8` THROW. The `$C000`
literal at `src/banking.asm:870` is only `.BANKS` free-space *display*, not a
guard. So the exposure is real, general to every banked defining word, and
silent — it just requires a bank filled to within a few bytes of `$C000`.

This is a **pre-existing** gap (not introduced by Story 23.2/23.3); it was
surfaced as finding #5 in the 23.2/23.3 code review. The review also landed the
companion fixes (VALUE/CREATE/`;` re-keyed to `triple_owner`; `alloc_doer_stub`
helper; `STUB_ALLOC_BASE >= $C000` build assert) — this story is the remaining
item deferred for proper scoping.

## Proposed approach (to be ratified at create-story)

1. New THROW code: `THROW_DICT_OVERFLOW EQU -8` in `src/constants.asm`
   (ANS Forth 1994 §9.3.5, "dictionary overflow"); add the `-8` row to
   `src/exception.asm`'s `throw_desc_table` and to `docs/throw-codes.md`.

2. Shared guard helper in `src/banking.asm`, e.g.
   `check_banked_headroom ( HL = prospective end addr -- )`:
   no-op when `triple_owner == 0` (bank 0 = fixed memory, no window); else
   THROW `-8` when `HL >= $C000`. Sketch:

   ```asm
   check_banked_headroom:
           LD      A, (IY+UserArea.triple_owner)
           OR      A
           RET     Z
           LD      A, H
           CP      0xC0                    ; HL >= $C000 ?
           RET     C                       ; fits
           LD      BC, THROW_DICT_OVERFLOW
           JP      w_THROW_cf.kernel_entry
   ```

3. **Design call to resolve in create-story:** the choke point. Options —
   (a) check once in `build_header` against the header extent plus a
   per-doer body-size constant; (b) check at each `HERE`-advancing primitive
   (`,` / `ALLOT` / the doer emits). (a) is cheaper and catches the common
   defining words at one site; (b) is fully general but spread out. Prefer
   the deepest single mechanism over a per-word special case (altitude:
   do NOT bolt a VALUE-only guard — that was explicitly rejected in review).

## Acceptance criteria (skeleton — expand at create-story)

- AC1: A banked definition that would place any body byte at/past `$C000`
  raises `-8` instead of silently emitting a straddled word.
- AC2: Bank 0 definitions are unaffected (guard is a no-op there).
- AC3: Existing banking gates stay green; binary delta within envelope.

## Test (NEW — none exists today)

A REPL/banking probe that drives a bank's `HERE` to within a few bytes of
`$C000` (e.g. `ALLOT` to the brink), then attempts one more banked `CONSTANT`
/ `VALUE` / `:` and asserts the `-8` THROW and a still-live interpreter.
Without this the guard ships untested — it is the load-bearing deliverable.

## Out of scope

Resizing the banked window or relocating the dictionary; this story only
refuses an allocation that would cross the existing `$C000` top.
