# Wishlist

Forward-looking feature ideas for Phase 3 and beyond. **Not** a debt / 
carry-forward list — for the prioritised Phase-3 stabilisation + standards close-out catalogue, see [`docs/PHASE-3-CARRY-FORWARD.md`](PHASE-3-CARRY-FORWARD.md).

# Banked RAM awareness

Available user RAM is getting tight as AntForth grows, but I don't 
want to sacrifice any of our core wordset, nor our built in assembler.
Proposal is to use bank swapping to make more memory available to users - 
see docs/antforth-banking-redesign.md (locked Phase-4 design) — the older docs/antforth-banking-design.md sketch is SUPERSEDED.

# STARTUP.FTH

File that, if present, is run at startup before interactive REPL.
Allows loading custom wordlists etc.

# Turnkey compilation to .com binary

Maybe this is a separate tool, but it's basically the Forth
interpreter without the outer-interpreter part, and a default
startup thread. We could maybe do some tree-shaking of words to
minimize the dictionary size.

In fact without the interpreter, do we even need a dictionary?
If compiled forth doesn't create new words, then everything is
already linked as CFA addresses...I guess we still need the
dictionary as a *storage medium* but we don't need any of the
apparatus for searching it.

# ANS Forth locals

`{: a b -- c :}` or just `VALUE` and `TO`. — `VALUE`/`TO` DELIVERED
in 3.1.0 (Story 23.2); full `{: :}` named locals remain a forward
candidate.

# SEE decompiler

Disassemble colon definitions back into something human
readable.

# TRAVERSE-WORDLIST

Makes it possible to write `SEE`, xref tools, and integrity
checkers in Forth itself. An ANS extension.

# OO

~Need to get hold of Dick Pountain's book first!~ Book now acquired! Just need to read it.

NEON/Yerk and FOBJ maybe worth looking at.

Forth Dimensions Volume IX onwards.

# MicroBeast hardware vocabulary

System timer ISR, GPIO, 24x14 segment LED matrix, beeper, UART,
I2C, memory banking control, Real-Time Clock anything else board-specific. 
System timer has strong fit with the multitasker via timer-driven `PAUSE`.
A PRNG and a word to access it

# Bigger input buffer

128 bytes is a bit restrictive.

# Line editing / command history 

Would be could to have previous line at least, and be able to edit it.

# Small tasks

See docs/dev_journal.md

---

## Shipped in v3.x (formerly wishlist items)

- **Z80 IO primitives** — v3.1.0, Story 23.3 (`IN`, `OUT` as built-in runtime port words)
- **`VALUE` / `TO`** — v3.1.0, Story 23.2 (the `VALUE` half of the locals item; `{: :}` locals are still a wish)
- **Multitasker** — v3.2.0, Epics 24–25 (64 Hz tick with `TICKS`, yielding `DELAY`/`MS`, `PAUSE`, `TASK`, `ACTIVATE`, `SLEEP`/`WAKE`, `.TASKS`, `KEY`/`ACCEPT` that call `PAUSE`, `Ctrl-\` keyboard break)
- **Semaphores** — v3.2.0, Epic 26 (`SEMAPHORE`/`SIGNAL`/`WAIT`, `MUTEX`/`LOCK`/`UNLOCK`, one-slot `MAILBOX`/`POST`/`FETCH`)
- **Small tasks from `docs/dev_journal.md`** — v3.3.0, Epic 27 (`NIP`, `TUCK`, `-ROT`, `?`, `<>`, `0<>`, `0>`, `U>`, `<=`, `>=`, `AGAIN`, `?DO`)

## Shipped in v2.0 (formerly wishlist items)

- **Comments** — Epic 5 (`(`, `\`)
- **Hex / binary prefixes for numeric literals** — Epic 9 (`0x`, `0b`, `$`, `#`, `%`, character literal prefixes)
- **Exception handling** — Epic 11 (`CATCH` / `THROW`)
- **Wordlists and vocabularies** — Epic 12 (`WORDLIST`, `SEARCH-WORDLIST`, `GET-ORDER`, `SET-ORDER`, `FORTH-WORDLIST`, `GET-CURRENT`, `SET-CURRENT`, `DEFINITIONS`, `ONLY`)

The "move z80 opcodes into ASSEMBLER word-list and automatically activate/deactivate it" sub-bullet of the wordlists wishlist item was explicitly **rejected** at the 2026-04-20 Epic-12 redraft (see `project_assembler_keep_assembly.md`); `src/assembler.asm` stays kernel-resident, hard-coded.
