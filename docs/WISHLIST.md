# Wishlist

Capturing ideas that are not in MVP, or PRD for any future phases.


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

# Hex and binary prefixes for numeric literals

Prefix hex numbers with 0x and binary numbers with 0b. This will 
require a change to the fundamental `NUMBER` or `INTERPRET`. 
If detected, stash the current `BASE`, change it to whatever the 
prefix identifies, convert the number, restore the old `BASE`.

Implement this system wide, and the assembler can also take 
advantage of it - hex is more usual in assembler. 

Hex/bin literals will be UNSIGNED, so we don't have to deal with 
ugly '-0xff' type prefixes.

# Compilation to .com binary

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

# Exception handling

`CATCH` and `THROW`, extremely useful, huge quality of life 
improvement.

# Wordlists and vocabularies

`SEARCH-ORDER`, `GET-ORDER`, `SET-ORDER`, `WORDLIST`, and 
`DEFINITIONS` from ANS. Namespace control!
Move z80 opcodes into ASSEMBLER word-list and automatically acticate/deactivate it.

# SEE decompiler

Disassemble colon definitions back into something human
readable. 

# TRAVERSE-WORDLIST 

Makes it possible to write `SEE`, xref tools, and integrity 
checkers in Forth itself. An ANS extension.

# OO 

Need to get hold of Dick Pountain's book first! 

NEON/Yerk and FOBJ maybe worth looking at.

Forth Dimensions Volume IX onwards.

## Comments - DONE

Argh! We don't support comment words! How have we got this far without me noticing...
Prolly should comment code more often.
