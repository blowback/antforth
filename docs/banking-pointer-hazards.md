# Cross-bank pointer hazards

antforth gives each memory bank its own dictionary state — its own `HERE`,
`LATEST`, and wordlist heads — kept in a fixed-memory `bank-table[]` and
swapped in and out by `BANK!` (see `docs/antforth-banking-redesign.md` §5.4).
That per-bank state is what lets you compile independent code into several
banks, but it also means **an address you obtained while in one bank is only
meaningful in that bank**. Switching banks does not rewrite pointers you are
already holding. antforth follows the Forth tradition of trusting the
programmer here: these hazards are documented, not guarded at runtime.

## Bank-sensitive pointers

These all change meaning across a `BANK!`:

- **`HERE` / `LATEST`** (FR-P4-26) — the dictionary allocation pointer and the
  most-recent definition. Each bank has its own; a `HERE` read in bank 5 names
  an offset into bank 5's dictionary, not bank 7's.
- **`CREATE` PFA / data-cell addresses** (FR-P4-25) — the body address handed
  back by a `CREATE`d word (or `'` / `>BODY`) points into the bank the word was
  defined in. Reading or writing through it after switching banks hits the same
  offset in a *different* bank's address space.
- **Raw allocator pointers** — any address you captured from `HERE`, `,`,
  `ALLOT`, `PAD`, etc., to use as scratch or a buffer.
- **Wordlist-head pointers** held outside `FIND` — if you cache a wordlist link
  yourself, it belongs to the bank that was current when you read it.

## Anti-pattern (do not do this)

```forth
5 BANK!              \ working in bank 5
HERE CONSTANT SAVED  \ SAVED = bank 5's allocation pointer
7 BANK!              \ now in bank 7
123 SAVED !          \ writes 123 into bank 7 at bank 5's offset — garbage
```

`SAVED` was bank 5's `HERE`. After `7 BANK!` that same numeric address lands
somewhere inside bank 7's dictionary, so the store silently corrupts whatever
bank 7 had there. Nothing throws; you just get wrong results later.

## Cross-bank return-stack overflow

Recursive or deeply nested **cross-bank** calls cost more return-stack space
than ordinary calls. Each cross-bank dispatch pushes a 3-cell return frame
(versus one cell for an intra-bank call), so the standard return stack fills
roughly 3× faster. When it overflows you get the standard
`-5 RETURN-STACK-OVERFLOW THROW` — there is no separate cross-bank guard. Keep
cross-bank recursion shallow, or restructure it to recurse within one bank and
cross bank boundaries only at the top level.

## Recommendation

> Do all your work in one bank per logical session, and swap banks only at
> well-defined boundaries.

Capture data you need to carry across a `BANK!` as *values* on the data stack
(or in fixed-memory storage), never as live pointers into a bank you are about
to leave.

To keep track of which bank you are about to type into, enable the opt-in REPL
prompt indicator with `-1 PROMPT-SHOW-BANK`: the `ok` prompt then shows the
current bank as a `[N]` prefix (e.g. `[5] ok`). It is off by default and is
always suppressed in bank 0. Disable it again with `0 PROMPT-SHOW-BANK`.
