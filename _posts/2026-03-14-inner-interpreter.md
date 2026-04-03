--- 
layout: post
title: "Inner interpreter"
date: 2026-03-15
--- 

On to the next BMAD task: 1.2 - inner interpreter and threading.

We `/bmad-bmm-create-story 1-2` to create the next story that will guide Claude's 
development. We got story 1-2 for free last time as part of the initial planning 
process, but from here on in we generate stories on-demand just before we need them. 
This helps the overall development workflow adapt to changes in direction caused by 
discoveries and pivots in ongoing development. It's preferable to trying to nail 
all the stories down in one go at the outset, as not all developmental challenges 
can be anticipated.

This produces a document in `_bmad-output/implementation-artificats/1-2-inner-interpreter-and-threading.md` 
which will be Claude's development plan. We must review the story carefully, and manually 
address any problems. Once we're happy we can kick off the development with  `/bmad-bmm-dev-story 1-2`
and once that is complete we will `/reset/` Claude to get a fresh context and start a 
code review with `/bmad-bmm-code-review 1-2`.

There are a couple of minor issues which we elect to fix automatically.

Finally, we've got an actual working test:

![First test](/antforth/assets/images/2026-03-15_01-03.png)

But how's that actually doing anything? We don't have an interpreter yet!

## inner_interpreter.asm

In Forth, the thing that executes "programs" is called the *outer interpreter*, and 
while we don't have that yet we do have a bare bones *inner* interpreter: this is 
the code that can execute sequences of Forth *words*.

A Forth *word* is either z80 machine code that gets executed directly, or it's 
a very specific bit of machine code called `DOCOL` that knows how to execute 
 sequences of other Forth words. So you build Forth words from other Forth 
words, and some of those words might be machine code primitives.

In our barebones inner interpreter, we've now got some basic primitives like `LIT`:


![LIT](/antforth/assets/images/2026-04-03/lit.png)

Here `w_LIT` is the header for the word (the header permits it to be linked 
into the dictionary of all Forth words), and `w_LIT_cf` is the actual code 
that gets implemented when `LIT` is used (the '_cf' means "code field").

`LIT` is what compiles a literal (like the `2` in `: DOUBLE 2 * `) into a 
word. It does this by taking the next argument after the `LIT`, let's say 
`2`, and sticking that on the top of the parameter stack, adjusting IP 
to move past the `2`. 

The code might look a little weird, but this is because we are using an 
optimisation and keeping our `TOS` (*Top of Stack*) in register BC, while 
the z80 stack holds the rest of the parameter stack. So that first 
`PUSH BC` moves TOS onto the z80 stack, and then we fetch a new value into 
BC, or into the new Top-of-Stack in other words.

We also have this definition for `EXECUTE`:

![EXECUTE](/antforth/assets/images/2026-04-03/execute.png)

This takes an "xt" (eXecution Token - a pointer to a function) from the 
parameter stack and executes it. We now know that the top of our parameter 
stack is in BC, so all we need to do is move BC into HL so that we can 
jump to it.

There are a couple of other new definitions (`BRANCH`, `?BRANCH`) which 
we'll gloss over for now: they implement unconditional and conditional 
branching respectively.

## io.asm 

We now also have the rather exciting primitive `EMIT`:

![EMIT](/antforth/assets/images/2026-04-03/emit.png)

Which takes a byte from the TOS (BC register again) and uses CP/M's 
BDOS to output it to the terminal. This routine is mostly register 
juggling to get the character we want to emit in the E register and 
the value `C_WRITE` into the C register before we call the BDOS.

Note that the call to BDOS is wrapped with `BDOS_SAVE` and `BDOS_RESTORE` 
to protect our registers from any corruption by BDOS.

## antforth.asm 

Now we can see how the test is actually implemented:

![test 1](/antforth/assets/images/2026-04-03/test1.png)

Here we're hardcoding a `thread` which is basically `LIT 'A' EMIT` and 
then executing it. 

We've also got a test of `DOCOL`:

![test 2](/antforth/assets/images/2026-04-03/test2.png)

whose definition looks like:

![test DOCOL](/antforth/assets/images/2026-04-03/test_docol.png)

Which is basically the same as test 1, but this time wrapped in a 
`DOCOL` - i.e. it's a simulation of a Forth word definition.

There are a few more tests to do with branching, and then one last 
one to test `EXECUTE`:

![test 6](/antforth/assets/images/2026-04-03/test6.png)

Rather than just call `BYE` directly, we're taking its address, 
pushing that onto the parameter stack, and then using `EXECUTE` to 
call it. 



