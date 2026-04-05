---
layout: post
title: "Outer interpreter"
date: 2026-04-07
---

OK, this is the big one! Story 2.2 will introduce the *outer* interpreter, which means that
AntForth will be interactive for the first time! Probably won't be able to actually *do* 
much, but we will be able to interact!


In this sprint, we'll be building:

 - `STATE`, `SOURCE`, `BASE`, `>IN`, `#TIB` user variables
 - `ACCEPT` and `WORD` input processing routines
 - `INTERPRET` - this is the biggy

## strings.asm

First up, we have gained a word, `WORD`, that parses a word out of 
a longer string (like user's console input) and returns it as a 
nice byte-counted string with leading delimiters (spaces) removed.

We also gained `>NUMBER` which is a string to integer conversion 
done in the currently active number base, and `NUMBER?` which is 
a moderately more useful version of the same. 

## system.asm

Here we've gained `ABORT` which is like `QUIT` but it also clears 
the parameter stack. 

## io.asm

The new word in here is `ACCEPT` which reads a line of input characters.
In AntForth this has been implemented as a wrapper around the BDOS 
`C_READSTR` function, which is fair enough.

## outer_interpreter.asm

This is the big one! For starters we've got some words that give 
access to existing user variables:

 - `STATE` - gets the current interpret/compile state 
 - `BASE` - gets the current radix for number conversion
 - `>IN` ("to IN") - gets ptr to the unparsed part of current input
 - `#TIB` - gets the number of chars in the input buffer
 - `SOURCE` - get the address and size of the current input buffer

 Then the bulk of the new work is in `INTERPRET`:

![INTERPRET implementation](/antforth/assets/images/2026-04-07/interpret.png)

The interesting thing here is that `INTERPRET` is essentially 
implemented in proto-Forth: it's a hard-coded list of Code Field 
Addresses that get called in sequence, exactly what we'd get if 
we defined a new Forth word (if we had that facility, which we don't...yet).

The code is quite easy to follow as a consequence: it's the classic 
Forth outer interpreter loop: get some input, break it into words,
look up each word in the dictionary and if it's there call it otherwise
attempt to convert it into a number and push it into the stack.

Also in this file we have the traditional Forth word `QUIT`: it's 
tempting to think of this as meaning "quit Forth" (like `BYE`) but 
actually it means "quit whatever word, loop or error state you were 
executing and return to the interpreter loop". 

## Testing 

All tests pass, and the manual `KEY` test still works.

And now, for the first time, we can do this:

![running the interpreter](/antforth/assets/images/2026-04-07/interpreting.png)

We can't see the result, or dump the stack, or define new words 
or anything, but we got our first "ok" and that's a promising 
start!








