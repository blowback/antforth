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

## Double precision arithmetic 

Here are some basic examples of double precision integers in action:

![Basic operations with doubles](/antforth/assets/images/2026-04-28/doubles.png)

Note that the `.` denotes a double-precision *integer* and has nothing to do 
with "floating point" or the decimal point. This is a classic Forth trap 
for the unwary. Witness:

![Tricky double precision integer literals](/antforth/assets/images/2026-04-28/surprising_doubles.png)

Here are a few more related words that were created in this sprint:

![More double operations](/antforth/assets/images/2026-04-28/double_ops.png)

We also get a set of useful multiply routines:

![double precision multiplication](/antforth/assets/images/2026-04-28/double_mults.png)

`M*` takes two signed single precision values and multiplies them together 
to give a double precision signed result. `UM*` takes two unsigned single 
precision values and multiplies them to give a double precision unsigned 
result. Finally `D*` takes two signed double precision values and multiplies 
them to give a double precision signed result: watch for overflow with this one!

Finally in this section we have some useful division routines:

![double precision division](/antforth/assets/images/2026-04-28/double_divs.png)

Why so many? Well, `UM/MOD` is an easy one, it divides an unsigned double 
by an unsigned single and returns an unsigned qotient and an unsigned remainder.

Once we introduce signedness, things get interesting. `SM/REM` is *symmetric* or 
*truncating* division, which rounds towards zero (truncating the decimal part) and
the remainder has the same sign as the dividend (the number that is being divided).

The "symmetric" description comes from the fact that `-7 / 3` and `7 / -3` yield 
the same magnitude quotient with opposite signs. 

This is the standard `/` operator in C, C++, Java, JavaScript etc. 

`FM/MOD` gives you *floored* division of a signed double by a signed single. 
This rounds down to the nearest integer in the direction of negative infinity.
The remainder always takes the sign of the divisor. You might be familiar with 
this sort of division from Python's `//` operator. 

## Pictured numeric output

[Pictured numeric output](https://www.complang.tuwien.ac.at/forth/gforth/Docs-html/Formatted-numeric-output.html) is Forth's traditional technique for displaying 
formatted numeric output. It operates on double precision signed integers,
and builds the ASCII representation digit-by-digit from right to left.

The important things to remember:

 - pictured numeric output always uses **double precision** ints 
 - pictured numeric output always uses **unsigned** ints

You start a conversion with `<#`, then you get the least significant digit 
with `#`. Then the next significant digit with `#`, and so on. At any point
you can say `#s` which means "as many #s as are left to finish converting 
the number". You can use `HOLD` to insert other characters at appropriate 
junctures.


![pictured numeric basics](/antforth/assets/images/2026-04-28/numpic_basic.png)

You can use `SIGN` to print a negative sign if needed, although it's behaviour 
is a little weird: it takes a (single precision signed) integer from the top-of-stack 
and it it is negative it prints a minus sign. So you need to have this value 
on the stack before you start number conversion, and you need to prefix your 
`SIGN` word with a `ROT` word, like so:

![pictured numeric sign handling](/antforth/assets/images/2026-04-28/numpic_sign.png)

You may be thinking "hold on, what's that `ROT` in there for?!" - I certainly did.
The answer is, at each `#` step the interpreter is doing `( ud-lo ud-hi -- quot-lo quot-hi )` so there's 
always a working quotient on the stack until we emit `#>` - so at the point that we 
emit `SIGN` (which must come before `#>`) the top three entries on the stack are `-1 0 0 ` - 
our original -1 and two cells for the remaining double precision quotient (which is 
zero). So the `ROT` brings the -1 to the top-of-stack so `SIGN` can consume it.

We can actually see this in action:

![pictured numeric sign intuition](/antforth/assets/images/2026-04-28/numpic_intuition.png)

`TUCK DABS ... ROT SIGN` is a common idom in Forth to display a signed double precision 
number, and `S>D TUCK DABS ... ROT` is another for single precision signed numbers.

![pictured numeric sign conversions](/antforth/assets/images/2026-04-28/numpic_conversions.png)


## */ and */MOD 

`*/` takes three single-precision numbers on the stack `(n1 n2 n3 -- n4)` - it multiples 
`n1` by `n2` giving a douple precision result, then divides that by `n3` to give the 
quotient `n4`.

`*/MOD` is similar but it also returns the remainder `(n1 n2 n3 -- n4 n5`).


![*/ and */MOD](/antforth/assets/images/2026-04-28/star_hash.png)

## EVALUATE

`EVALUATE` evaluates Forth code from a string exactly as if you had tyed it in. 
It's the equivalent to `eval()` from other languages.

![EVALUATE](/antforth/assets/images/2026-04-28/eval.png)

## ENVIRONMENT?

The `ENVIRONMENT` word lets you query certain environmental constants in the system. 
There are a number of different queries you can make, each identified by name.
The name precedes the `ENVIRONMENT` call and is in the usual Forth `(c-addr u --)`
(start address, count) convention. You'll get back a true or a false in TOS to indicate 
whether `ENVIRONMENT?` knows what you are talking about: a TRUE value is accompanied by 
other pertinent information in the rest of the stack.

Here are the queries AntForth supports:

|Name            |Type|Constant?|Meaning|
|-----------------|-------|----------------|------------------------------------------|
|`/COUNTED-STRING` | n | yes | max size of a counted string, in chars |
|`/HOLD`           | n | yes | Size of pictured numeric output string in chars |
| `/PAD`            | n | yes | size of scratch area pointed to by `PAD` |
| `ADDRESS-UNIT-BITS` | n | yes | size of one address unit, in bits |
| `FLOORED`       | flag | yes | true if floored division is the default |
| `MAX-CHAR`     | u | yes | maximum value of any character |
| `MAX-D`      | d | yes | largest usable signed double integer |
| `MAX-N`    | n | yes | largest usable signed integer |
| `MAX-U`  | u | yes | largest usable unsigned integer |
| `MAX-UD`  | ud | yes | largest usable unsigned double integer |
| `RETURN-STACK-CELLS` | n | yes | maximum size of the return stack, in cells |
| `STACK-CELLS` | n | yes | maximum size of the data stack, in cells |


AntForth also supports wordset queries from the 1994 ANS Forth standard, although 
the user should note that the 2012 standard makes these as obsolete:


|Name            |Type|Constant?|Meaning|
|-----------------|-------|----------------|------------------------------------------|
|`/CORE` | flag | no | True if complete Core wordset is present |
|`/CORE-EXT` | flag | no | True if Core extensions wordset is present |


Other values may become available as AntForth supports them.







