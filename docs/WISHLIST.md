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

# Multitasker

A polyForth/fig-Forth style cooperative multitasking system based
around tasks yielding with `PAUSE`.

Task Control Blocks are allocated with `TASK` and given a word to
run with `ACTIVATE`.

Make anything that blocks on I/O (including `KEY`) call `PAUSE`, and
suddenly our interactive REPL multitasks too!

Could add an event handler for the Beast's system timer interrupt
that also calls `PAUSE`. Maybe have it increment a counter, then
an event handler task is just any task that wakes up and does
something when it detects an increment of the timer.

# Semaphores

Add simple counting semaphores with `SIGNAL` ( sem -- ) and
`WAIT` ( sem -- ) to allow cooperating threads to share resources.

Can also use a mutex to protect a **shared variable**, which can
then be used as a primitive mailbox between threads.

Since the whole interpreter is single-threaded, our semaphores
don't need to be *atomic* (except maybe from ISR).

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

# Z80 IO primitives

IN and OUT. Easy enough to provide as custom code words, but
it would be nice to have them built in.

# ANS Forth locals

`{: a b -- c :}` or just `VALUE` and `TO`.

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

# Bigger input buffer

128 bytes is a bit restrictive.

# Line editing / command history 

Would be could to have previous line at least, and be able to edit it.

# Small tasks

See docs/dev_journal.mdi

---

## Shipped in v2.0 (formerly wishlist items)

- **Comments** — Epic 5 (`(`, `\`)
- **Hex / binary prefixes for numeric literals** — Epic 9 (`0x`, `0b`, `$`, `#`, `%`, character literal prefixes)
- **Exception handling** — Epic 11 (`CATCH` / `THROW`)
- **Wordlists and vocabularies** — Epic 12 (`WORDLIST`, `SEARCH-WORDLIST`, `GET-ORDER`, `SET-ORDER`, `FORTH-WORDLIST`, `GET-CURRENT`, `SET-CURRENT`, `DEFINITIONS`, `ONLY`)

The "move z80 opcodes into ASSEMBLER word-list and automatically activate/deactivate it" sub-bullet of the wordlists wishlist item was explicitly **rejected** at the 2026-04-20 Epic-12 redraft (see `project_assembler_keep_assembly.md`); `src/assembler.asm` stays kernel-resident, hard-coded.
