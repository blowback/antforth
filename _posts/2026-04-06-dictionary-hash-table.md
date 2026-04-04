---
layout: post
title: "Dictionary and hash table"
date: 2026-04-06
---

We're now starting Epic 2, which is all about getting us to a functional AntForth interpreter.

The first story (2.1) is about the dictionary and has table. The dictionary is where 
all our Forth word definitions are stored, so that they can be looked up when they're 
used. Traditionally this is a single-linked list, which is simple to implement but gets 
slower and slower the more words are added.

We've specified that our interpreter should use a more optimised hash-based approach. Effectively
we keep 64 separate dictionaries, and decide which dictionary a word belongs to by using some 
simple mathematical function (the "has function") on its name. 

The hash function needs to be fast and easy to implement on a z80 - we're using a rotating XOR 
 hash function and 64 mini-dictionaries to meet these needs, but really any function that 
distributes words across the dictionaries evenly will do.

We've already been using this hash lookup approach, but up to now the hashes have been 
built at assembly time using sjasmplus' Lua scripting ability.


In this sprint, we'll be building:

 - a z80 native version of the hash function
 - the `FIND` word, for looking up word names in the dictionary 
 - the `COUNT` word, to tell us the length of byte counted strings (like the names of words 
   in the dictionary)

## hash.asm 

The runtime hashing algorithm is pretty simple:

![hash algorithm](/antforth/assets/images/2026-04-06/hash.png)

It converts the string to uppercase, XORs the current hash value (initial hash value is 
zero) with the uppercase character, and rotates the current hash value left one bit. 
Remember that `RLC A` is an 8 bit rotate as the comment makes clear.

The upper-case conversion code was originally explicit in here, with a whinging comment 
about there being duplicate code in dictionary.asm and dire warnings about keeping the 
two synchronized - so I asked it to replace all instances of that code with a macro 
`UPPER`.

## dictionary.asm

`COUNT` also gets quite a simple implementation:

![count algorithm](/antforth/assets/images/2026-04-06/count.png)

When a word is stored in a forth dictionary, its name is a byte counted string (the 
string is preceded by a byte that is the count of the number of its characters), but 
a couple of the top bits of the length byte are used for other purposes, so this 
routine is basically masking those extra bits out, so we can treat it as a regular 
byte-counted string.

The implementation of `FIND` is also here, but it's a bit too long to include in 
this blog post.

In essence what it's doing is:

 - hash the name we're looking up to identify the relevant dictionary "chain" (mini-dictionary)
 - search that chain for a match, searching by length first, then a full name comparison
 - if it's found return the "xt" (execution token) and a +1 or -1 flag depending on whether the word is "immediate" or not (more on this later)
 - else return the original address with a zero pushed on top if there was no match.

The `FIND` routine uses some static storage, so it's not re-entrant. As we're 
single threaded by design, this shouldn't be an issue.

## Testing 

All tests pass, and the manual `KEY` test still works.








These should all be trivial wrappers around BDOS calls to do the actual work.
These functions will be essential when it comes to building the full outer interpreter 
that will make AntForth interactive!

To get started we `/bmad-bmm-create-story 1-5` and review the story. Straight 
away Claude has flagged that `KEY` and `KEY?` can't be tested automatically,
which is fair, but I asked for a separate test executable to be provided so 
I can test them nmanually:

```
please make sure that a separate manual test executable is provided so that 
I can test KEY and KEY? - just a prog that echos what I type is fine, ctrl-c to exit.
```

With the updated plan in place we can `/bmad-bmm-dev-story 1-5`, 
followed by `/bmad-bmm-code-review 1-5`.

Code review found some minor test coverage gaps, which were quickly fixed.

## io.asm

All the new console stuff, unsurprisingly, is in io.asm. The output routines are all 
variations on the same basic theme:

![console output](/antforth/assets/images/2026-04-05/emit.png)

Similarly the input routines:

![console input](/antforth/assets/images/2026-04-05/key.png)

## Testing 

`make test` passes, although the hard-coded test-thread in antforth.asm is starting 
to get a bit wild and overgrown - the sooner we have a proper interpreter the better!

Claude did make us a manual test `key_test.com` which we have to run ourselves:

![typing test](/antforth/assets/images/2026-04-05/typing.png)

Although, now I look at the source code:

```z80
; ================================================
; test_key.asm — Manual test for KEY / KEY? primitives
; Echoes typed characters. Ctrl-C to exit.
; Part of antforth — ANS Forth for MicroBeast Z80
; ================================================

        INCLUDE "constants.asm"

        ORG     TPA_START       ; 0x0100

echo_loop:
        LD      C, C_READ       ; BDOS function 1: read console (blocking, echoes)
        CALL    BDOS_ENTRY      ; A = character typed
        CP      0x03            ; Ctrl-C?
        JR      NZ, echo_loop   ; No — keep looping (char already echoed by BDOS)
        LD      C, P_TERMCPM    ; BDOS function 0: exit to CP/M
        JP      BDOS_ENTRY

```

That just tests BDOS and doesn't test any of our stuff at all!

Back to Claude then:

```
❯ test_key.asm does not test our KEY or KEY? implementations, it calls the BDOS routine directly.
as a test therefore, it is entirely useless. Write a proper test that actually exercises the code-under-test!!

● You're absolutely right — test_key.asm just calls BDOS directly and doesn't exercise our KEY or KEY?
code words at all. I need to build a proper Forth-threaded test program. Let me check what infrastructure is needed.
```

This kind of thing is unfortunately far too commmon, even BMAD couldn't save us this time. It's 
the perfect example of what the human responsibilities are in this partnership!


Here's Claude making amends:

![typing test amends](/antforth/assets/images/2026-04-05/test_key2.png)

Checking the source code, this time we have got something more substantial:

![typing test 2 code](/antforth/assets/images/2026-04-05/test_key_code2.png)

This is what it looks like when you run it:

![typing test 2](/antforth/assets/images/2026-04-05/typing2.png)

This would be a great topic to raise in a sprint retrospective, and as we've just finished Epic 1 
you'll see that the next step in `sprint-status.yaml` is an optional retrospective. Let's take that 
option!

First `/reset` claude code and then `/bmad-bmm-retrospective epic 1`. This kicks off a long, 
interactive session where the LLM adopts several personas (developer, architect, tester) 
simultaneously. You get to ask them challenging questions, and they bicker about whose 
fault it is. Stay alert, sometimes they'll conclude that it's *your* fault. It is a frankly 
hilarious experience, eerily reminiscent of a real-world retro. The end result is that your 
PRD and architecture documents will get updated with the lessons learned. In extreme cases 
a "course change" may be scheduled, which is usually a single extra story, but can in theory 
be a whole new emergency epic if the wheels have really come  off.



The whole chat is too long to include here, but this was what I kicked off with:

```
❯ It's a solid foundation, and it's exciting to see the functionality coming together. But let's not pat ourselves on the back about testing. The single test thread in antforth.asm is becoming unwieldy and we urgently need to replace it with something more modular - I guess we'll have to wait for the outer
interpreter to be available. MORE CONCERNING for me is that I asked for a manual test harness for `KEY` and `KEY?` and was given code that didn't excercise *any* of the code under test - it just called some BDOS routines directly. This is an unforgiveable oversight, and it must not happen again.
```

And you can see the [resulting document](https://github.com/blowback/antforth/blob/main/_bmad-output/implementation-artifacts/epic-1-retro-2026-04-04.md) with the conclusions they came to.

Which all seems sensible. On to epic 2!










