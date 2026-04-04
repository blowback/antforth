---
layout: post
title: "Arithmetic, logic and relational primitives"
date: 2026-04-04
---

On to the next BMAD task: 1.4 - arithmetic, logic and relational operators.

In this sprint, we'll be building:

 - arithmetic operators: `+`, `-`, `*`, `/`, `MOD`, `/MOD`
 - logical operators: `AND`, `OR`, `XOR`, `INVERT`, `LSHIFT`, `RSHIFT`
 - relational operators: `=`, `<`, `>`, `0=`, `0<`, `U<` 

 That's a lot of very useful functionality that will significantly boost the 
abilities of our implementation. Most of these will be relatively trivial 
wrappers around the equivalent z80 machine code instructions, but some of them 
will be a little more involved: anything relating to multiplication and division 
in particular.

Claude will implement tests for each of these, adding them to the current hard-coded 
test thread in antforth.asm.

To get started we `/bmad-bmm-create-story 1-4`, review the story, then
`/bmad-bmm-dev-story 1-4`, followed by `/bmad-bmm-code-review 1-4`.


Code review threw up a few missing tests, but nothing more serious. We let Claude go ahead 
and fix those himself (it's worth noting that the code review is an *adversarial* code review, 
so the reviewer MUST find some bones to pick - he's not allowed to just wave work through).


## arithmetic.asm

### Add and subtract

Let's start with a couple of those simple wrappers:

![add and subtract](/antforth/assets/images/2026-04-04/simple_maths.png)

Nothing too complex in there: BC is our top of stack, and we POP HL to get next-top-of-stack, 
then do an add or a subtract and leave the result in top-of-stack (BC). Simple. 


### Multiplication

Next up we have `*` which multiplies two signed 16-bit words and returns the signed 16-bit 
result (i.e. the result is truncated from the maximum possible 32-bit result):

![multiply](/antforth/assets/images/2026-04-04/star.png)

This is the classic "shift-and-add" z80 multiplication — the binary equivalent of long multiplication by hand. The Z80 has no multiply instruction, so this is done in software:

  1. Setup: n2 is already in BC (top-of-stack), get n1 in DE, set HL = 0
  2. Main loop (16 iterations, one per bit of the multiplier):

  2. a. `ADD HL, HL` — left-shift the accumulator. This is the positional weighting — each previously-added value gets shifted up one place, just like when you indent each row in long multiplication.

  2. b. `SLA C / RL B`  — left-shift BC (the multiplier). The most significant bit falls out into carry. This examines the multiplier bits from MSB to LSB.

  2. c. `JR NC, .mul_skip`  — if that bit was 0, skip the add.

  2. d. `ADD HL, DE` — if the bit was 1, add the multiplicand to the accumulator.
  3. Finish: copy result (HL) into top-of-stack (BC) and restore Instruction Pointer (DE) before NEXT

#### Why MSB-first?

This scans the multiplier from the top bit down, which avoids needing to shift the multiplicand. Instead, the accumulator is shifted left each iteration, which has the same effect. Compare the two equivalent approaches:

  - LSB-first: shift multiplicand left each step, add to fixed accumulator
  - MSB-first (used here): shift accumulator left each step, add fixed multiplicand

The MSB-first approach is slightly more efficient on Z80 because `ADD HL, HL` is a single instruction to shift the accumulator, whereas shifting DE left would require two instructions.

Here's a simple worked example (4-bit: 5 * 3):

```
  DE=0101 (5), BC=0011 (3), HL=0000

  Iter 1: HL=0000, shift BC -> MSB=0, skip
  Iter 2: HL=0000, shift BC -> MSB=0, skip
  Iter 3: HL=0000, shift BC -> MSB=1, add -> HL=0101
  Iter 4: HL=1010, shift BC -> MSB=1, add -> HL=1111

HL = 1111 = 15
```


Note that this works for signed and unsigned 16 bit numbers, becasue we're discarding the top 16 bits of the result.


### Division

Next we can look at `udivmod` a utility routine that is used as the basis for many later 
division-related word definitions:

![udivmod](/antforth/assets/images/2026-04-04/udivmod.png)

This is unsigned 16-bit division of HL by BC, producing quotient in HL and remainder in DE.

It's another z80 classic, the  "restoring division algorithm"" — the same long division you do by hand, but in binary.

1. Setup: DE (remainder) = 0, A (bit counter) = 16
2. Main loop (one iteration per bit of the dividend):

  a. Shift the dividend's MSB into the remainder:
    - `ADD HL, HL` — left-shifts HL, pushing the top bit into carry
    - `RL E / RL D` — rotates that carry bit into the bottom of DE (the remainder)

  This is like "bringing down the next digit" in long division. After 16 iterations, all dividend bits have been shifted out of HL and the quotient bits have been shifted in.

  b. Swap registers: `EX DE, HL` so HL = remainder, DE = partial quotient. This is needed because `SBC` only works on HL.

  c. Trial subtraction: `SBC HL, BC` — try subtracting the divisor from the remainder. The `OR A` first clears carry so `SBC` behaves like `SUB`.

  d. Does the divisor fit?

    - Yes (no carry): The subtraction is kept. Swap back (`EX DE, HL`), then `SET 0, L` sets the lowest bit of the quotient to 1
    - No (carry set): The divisor was too large. Restore the remainder with `ADD HL, BC`` (undoing the subtraction — this is what makes it "restoring" division). Swap back. The quotient bit stays 0

  e. Loop: Decrement counter, repeat

3. Finish: After 16 iterations, HL holds the quotient and DE holds the remainder


HL serves double duty: it starts as the dividend and ends as the quotient. Each iteration shifts 
one dividend bit out the top (into the remainder) and shifts one quotient bit in at the bottom 
(via `SET 0, L`). After 16 iterations, all 16 dividend bits have been consumed and replaced by 16
  quotient bits.

Here's a simple workedexample (4-bit: 13 / 3)

  HL=1101 (13)  DE=0000  BC=0011 (3)

```
  Iter 1: shift -> DE=0001, try 0001-0011 -> no fit, restore  -> quot bit=0
  Iter 2: shift -> DE=0011, try 0011-0011 -> fits (DE=0000)   -> quot bit=1
  Iter 3: shift -> DE=0001, try 0001-0011 -> no fit, restore  -> quot bit=0
  Iter 4: shift -> DE=0010, try 0010-0011 -> no fit, restore  -> quot bit=0

  HL=0100 (quotient=4), DE=0001 (remainder=1)   13 = 4 * 3 + 1
```


Now we look at `sdivmod`, another utility routine:

![sdivmod](/antforth/assets/images/2026-04-04/sdivmod.png)

This is a signed 16-bit division that truncates toward zero (symmetric/C-style semantics), 
where the remainder takes the sign of the dividend.

It's qute a sneaky routine: it converts both operands to positive, uses `udivmod` to do the actual work, 
then fix up the signs of the results afterwards.

1. Initialize sign flags: A = 0. Bit 0 will track whether to negate the quotient, bit 1 whether to negate the remainder
2. Check dividend (HL) sign: If HL is negative (bit 7 of H set), set both bits 0 and 1 in A (OR 3)
   This means: a negative dividend means the remainder should be negative (bit 1), and tentatively the
   quotient should be negated (bit 0). Then negate HL to make it positive via the 0 - HL two's
   complement pattern
3. Check divisor (BC) sign: If BC is negative, toggle bit 0 (XOR 1)
   This handles the sign logic: if both operands are negative, the two toggles cancel out and
   the quotient stays positive. Only negate BC to make it positive
4. Call `udivmod`: Now both operands are positive, so unsigned division gives the correct magnitudes for quotient (HL) and remainder (DE)
5. Fix remainder sign: If bit 1 is set (dividend was negative), negate DE
6. Fix quotient sign: If bit 0 is set (signs differed), negate HL


The repeated pattern (`XOR A / SUB L / LD L,A / SBC A,A / SUB H / LD H,A`) is a standard Z80
two's complement negate: it computes `0 - reg_pair` using the carry propagation from `SBC A,A`
(which produces 0xFF if there was a borrow, 0x00 if not).

The truth table for restoring "signedness" is:


|Dividend|Divisor|Quotient|Remainder|
|--------|-------|--------|---------|
| +        | +       | +        | +         |
| -        | +       | -        | -         |
| +        | -       | -        | +         |
| -        | -       | +        | -         |



We close out with the relatively simple definitions for `/`, `/MOD` and `/MOD` - they're 
simple because they all build on `sdivmod`.



## logic.asm

This file also has some word definitions of varying complexity. First the simple logical 
operators:

### AND, OR, XOR, INVERT

![simple logical operators](/antforth/assets/images/2026-04-04/simple_logic.png)

These are essentially 16-bit wrappers around the equivalent 8-bit z80 instructions.

### LSHIFT and RSHIFT

![shift operators](/antforth/assets/images/2026-04-04/shifts.png)

Again, simple and elegant implementations. Notice the `ADD Hl, HL` trick again in `w_LSHIFT`.

### EQUALS, LESS, GREATER, ZERO_EQUALS, ZERO_LESS, U_LESS 

More simple wrapper functions, nothing particularly worth talking about in here.


## Testing 

Once again we perform our solemn "Human In The Loop" duty, and scrutinise the test results:

![running unit tests](/antforth/assets/images/2026-04-04/test_1_4.png)

That's a lot of tests! The built in test thread is starting to get a bit cumbersome. Notice 
this though:

![branching tests](/antforth/assets/images/2026-04-04/branching_tests.png)

Now that we have some useful relational operators we can combine them with `QBRANCH` that we 
glossed over in an earlier post, and check the test results in our fledgling proto-Forth 
directly!

















