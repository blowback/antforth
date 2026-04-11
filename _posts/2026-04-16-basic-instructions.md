---
layout: post
title: "CODE word framework and basic instructions"
date: 2026-04-16
---

Many original Forths included an inline assembler for their host platform 
(or even for some other target platform) - one of the reasons that Forth 
was so popular for bringing up new hardware.

We're going to do the same thing, and we'll base our implementation on 
the approach taken by PolyForth and fig-Forth:

 - create new words with `CODE`
 - reverse polish opcodes!
 - programmer must maintain register discipline
 - programmer must call `NEXT` to end

In addition we'll add a couple of modern niceties like forward label
support and data definition directives like `DW`, `DB`, `DS` and `EQU`.

First we `/bmad-bmm-create-story 4.1` and review the story document. 
Initially the agent has chosen Intel format for our postfix notation 
opcodes, so `LD B, A` becomes `A B LD,` : the order is `src dst` so 
"load B *into* A". This is the approach MMSForth used to take.

However, I prefer Zilog convention which is `dst src` and we say 
`LD B, C` ("load B *from* C") which becomes `B C LD,`. Now we 
only have to remember that the operand has been shunted to the 
end, the registers are in the familiar order (I picture an 
invisible '=' between the first and second registers).

It's a trivial matter to explain this to Claude and have him 
re-write that part of the story spec.

One other thing we're going to have to watch out for is name 
collisions: all the opcodes and register constants are plain 
old Forth words, and we don't have a proper multi-dictionary 
vocabulary system yet, so they sit in the same dictionary as 
all the other words we've defined so far. 

Story development proceeded without drama, and code review just 
found some minor nits about duplicate code blocks that were easily 
cleaned up.

What we're expecting is the underlying framework for doing inline 
assembly, and maybe a few opcodes that we can try out - nothing fancy.


## assembler.asm 

Previously an empty stub, this file is now packed with marrowbone 
jelly. 

The basic approach, as described in the file's header, is to 
introduce a `CODE name` word that builds a dictionary header and 
puts the interpreter into "asm_mode" so we can do our machine 
code fu, which will be assembled into `HERE`.

Every new forth word that represents a register or an opcode 
checks that asm_mode is in force: this prevents them doing 
unusual things in "normal" Forth. 

Here are the words for the 8-bit registers:

![8-bit register words](/antforth/assets/images/2026-04-16/8bit_registers.png)

And here are the words for the 16-bit registers:

![16-bit register words](/antforth/assets/images/2026-04-16/16bit_registers.png)

You can see that each register word pushes a unique code that 
identifies its register onto the stack: it's basically an enum.

The `CODE` and `END-CODE` are mostly dictionary housekeeping 
of the kind that we've seen before, so we won't examine them here.

Here's the definition of the `PUSH` and `POP` words:

![PUSH and POP definitions](/antforth/assets/images/2026-04-16/16bit_registers.png)

They share a common helper routine `asm_pushpop_word` and each 
call it with a different opcode base value. `asm_pushpop_word` 
does some basic validation of the register constant in TOS, 
and if it's suitable masks it onto the opcode base to get the 
actual opcode to push the register in question.

So `PUSH`s start with 0xc5 (PUSH BC), 0xd5 is PUSH DE, 0xe5 is 
PUSH HL, and 0xF5 is PUSH AF.

Similarly `POP`s are 0xc1 (POP BC), 0xd1 (POP DE), 0xe1 (POP HL) 
and 0xF1 (POP AF).

Fun fact: In 1985 Sinclair released an electric 2-wheeled 
vehicle called a C5, which wags at the time claimed stood for 
"PUSH BC" or "PUSH BiCycle", as that's what you'd be doing when 
the battery ran out...

Next up we have `LD,` but thus far only implemented for 
moving one 8-bit register to another 8-bit register:


![LD, definition](/antforth/assets/images/2026-04-16/ld_comma.png)

This time we're checking that both of the register constants 
at the top of the stack identify 8 bit registers. If so we 
use those two register constants to compute the relevant 
opcode starting at base value 0x40.

The arithmetic words `ADD,`, `SUB,`, `AND,`, `XOR,`, `OR,` 
and `CP,` are implemented in the same fashion:

![arithmetic definitions](/antforth/assets/images/2026-04-16/arithmetic.png)

They mask register offsets into opcode bases of 0x80, 0x90,
0xa0, 0xa8, 0xb0 and 0xb8 respectively.

Finally we have `NEXT,` -- with which we are obliged to 
end every CODE word. It takes a copy of the builtin `NEXT` 
helper and appends it to the current word definition.

## Testing 

Let's take our new powers for a spin! First off we'll 
try the "Hello World" of Forth CODE words: MYDUP:

```forth
CODE MYDUP    \ start a new word called MYDUP
  BC PUSH,    \ push TOS onto NOS
  NEXT,       \ standard "exit code word" ritual
END-CODE      \ indicate we're done writing assembler
```

And here it is running:

![MYDUP test](/antforth/assets/images/2026-04-16/mydup.png)

Let's try something slightly more elaborate, a word 
that doubles the bottom byte of the cell in TOS:

```forth
CODE DBL       \ start a new word called DBL
    BC PUSH,   \ save old TOS to machine stack
    A XOR,     \ A = 0
    C ADD,     \ A = A + C  (C is low byte of TOS)
    C ADD,     \ A = A + C again, so A = 2*C
    C A LD,    \ LD C, A    — store result back into C
    A XOR,     \ A = 0
    B A LD,    \ LD B, A    — clear high byte of TOS
    NEXT,      \ "exit code word"
  END-CODE     \ back to forth

```


And here it is running:

![DBL test](/antforth/assets/images/2026-04-16/double.png)

