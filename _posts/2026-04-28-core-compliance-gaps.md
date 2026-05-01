---
layout: post
title: "Core compliance gaps"
date: 2026-04-28
---

Epic 10 is all about mopping up the remaining bits of missing functionality
that stop us claiming 100% compliance with the ANS Forth Core wordset. 

The main omissions are:

 - double-precision integers and their operators
 - the traditional "pictured numeric output" system for printing formatted numbers
 - `EVALUATE` and `ENVIRONMENT?` and a couple of other stragglers

Once pictured numbers are available, we can re-implement all the current 
baked-in number formatting routines (`.`, `.S` etc) on top of it: so there 
shouldn't be an appreciable increase in overall code size.

## Planning

Nothing too remarkable, just the usual cycle of `/bmad-create-story`, `/mad-dev-story` and
`/bmad-code-review` finishing off with a retro `/bmad-bmm-retrospective`.




Epic 9 is all about making numeric literals in AntForth more pleasant to use.

Currently, when you type `42` then decimal 42 goes onto the stack, and if you 
actually wanted 0x42 hexadecimal then you'd write `HEX 42 DECIMAL .`. Both 
`HEX` and `DECIMAL` change the radix that's used for numbers, and it affects 
both the "input" and output of numbers, which is oft-times inconvenient.

![Changing the radix](/antforth/assets/images/2026-04-27/base.png)

This sprint add code that lets us prefix a hex number with `$` or `0x`, a 
binary number with `%`, a decimal number with `#`, and it also understands 
character literals by putting single characters inside single quotes like 
this `'A'`.

So now we can change our "input" base on the fly without mucking about with
`HEX` or `DECIMAL` or `BASE`.

Here are some examples, running on the MicroBeast:

![Numeric literals](/antforth/assets/images/2026-04-27/numeric_prefixes.png)

## Re-planning

Mid way through this sprint I had a change of heart regarding the whole phase 2 
goal of moving our inline assembler out into a separate `ASSEMBLER.FTH` file that 
would be loaded on demand.

The original idea was to get the binary down as small as possible so that AntForth 
might be a contender for inclusion in the MicroBeast's boot ROM (where space is 
at a premium).

I reversed this decision for two reasons:

1. our current z80 version of the assembler is really quite elegant, and has been 
heavily optimised, and I haven't even properly exercised it yet. It seems a shame two
throw all that work away without first even trying it.
2. nobody wants an embedded Forth without an assembler and the ability to drop into 
z80 for the odd `CODE` word. So that means `ASSEMBLER.FTH` would need to be in the boot 
ROM anyway, and I have a feeling that it will be significantly larger than the (native 
z80) code it is replacing.

To pull off a course correction like this we simply `/bmad-bmm-correct-course` and 
explain ourselves. The LLM will rewrite all the planning documents accordingly. It seems 
a little miffed that I have effectively nixed its "north star" demo (it's obsessed with 
north stars), and it would have been cool, but just loading and saving Forth files from/to 
disk will do me.

## Bug!

...or is it?

While preparing the above screenshots, I noticed a "bug". `HEX` and `DECIMAL` are meant 
to change the value of `BASE`. But when I printed it out it always came back as `10`. 

![Is this a bug](/antforth/assets/images/2026-04-27/confused.png)

> `HEX` changes the radix to 16, `BASE` puts the address of the BASE variable on to 
the stack so that `@` ("fetch") can read it, and `.` prints the top value of the stack.

I actually got as far as loading up GForth to screenshot a counter-example before 
the penny dropped. 

As I said at the start, `HEX` and `DECIMAL` change `BASE` both for input and output 
of numbers, and 16 in hex is, of course 0x10...


Still not convinced? Perhaps this will make it clearer:


![Proof it's not a bug](/antforth/assets/images/2026-04-27/proof.png)

Here we create a variable `old_base`, switch to `HEX`,  store a copy of `BASE` in
`old_base`, switch back to `DECMINAL`, and finally fetch and print out `old_base`
in the current number base, which is of course decimal.


