---
layout: post
title: "IMMEDIATE, POSTPONE, string literals & WORDS"
date: 2026-04-14
---

## compiler.asm

First up, we have `COMPILE,` which does the same thing as `,` from memory.asm - 
in fact here they are side by side:

![COMPILE, implemenetation](/antforth/assets/images/2026-04-14/compile_comma.png)

The reason for the duplication is that the ANS Forth spec makes a specific 
distinction between the two: `,` is a general-purpose memory store ("compile 
any cell th HERE") whereas `COMPILE,` is specifically: "append the 
compilation semantics of this xt to the current definition".

Happily, in a direct-threaded Forth such as AntForth, they amount to the 
same thing. Having `COMPILE,` as a separate word means it will be easier 
in the future should we want to adopt a different threading model such as 
a subroutine threaded Forth or some sort of virtual machine implementation.



Next up we have `IMMEDIATE`, which makes the most recently defined word 
into an immediate word, i.e. a word that executes at compile time. 

![IMMEDIATE implemenetation](/antforth/assets/images/2026-04-14/immediate.png)

This is simply a matter of finding the most recent dictionary entry (from
`LATEST`), getting hold of its flags field, and setting the F_IMMEDIATE 
flag bit.

Next up we have `POSTPONE`, which is one of the trickier words to understand.
`POSTPONE` is an immediate word (runs at compile time) and it is always 
followed by another word e.g. `POSTPONE later_word` and  its behaviour is 
*"when the word I'm currently defining runs (at compile time),  compile 
the effect of the named word (later_word) rather than executing it now".

In other words (ho ho!), it defers compilation one level deeper. 

![Inception meme](/antforth/assets/images/2026-04-14/deeper.png)

To make things extra exciting, `later_word` can be either an immediate word 
or a non-immediate word itself! Let's break it down:

### POSTPONE of an immediate word

Normally an immediate word encountered inside a `:` definition executes 
IMMEDIATELY (obvs) at compilation time. `POSTPONE` suppresses that. 
It makes the immediate word's compilation behaviour happen *later*, 
when the word being defined is itself used in the future as a defining 
word to define a new word. Is that meta enough?!

For example:

```Forth
: MY-IF POSTPONE IF ; IMMEDIATE
```

When `MY-IF` is later used inside a `:` definition, it compiles exactly 
what `IF` would have compiled - a forward branch. Without `POSTPONE` 
writing `IF` inside `MY_IF`'s definition would have executed `IF` 
straight away, which is wrong.

So for immediate words, **`POSTPONE` compiles a call to that word's 
compile time behaviour.**

### POSTPONE of a non-immediate word

Non-immediate words are normally *compiled* (not executed) when they 
are encountered in a `:` definition. `POSTPONE` of a non-immediate 
word compiles code that will, *at the future run-time of the current 
word*, compile the named word into whatever definition is being built.

For example:

```Forth
: MY-DUP POSTPONE DUP ; IMMEDIATE
```

`DUP` is not immediate, so normally it would just be compiled into 
`MY-DUP`'s body. With `POSTPONE`, instead of compiling a call to 
`DUP` we compile call to `COMPILE,` so that when `MY-DUP` runs 
(at compile time, because it is immediate) `DUP` will be compiled
into whatever future word is being defined.

So for non-immediate words, **`POSTPONE` compiles code that will 
compile the named word.**

`POSTPONE` always shifts the named word's effect **one compilation 
level later: **

|Word type|Without `POSTPONE`|With `POSTPONE`|
|---------|----------------|---------------|
|Immediate|execute *now* (compile time of current def)|execute *later* (when current word runs)|
|Non-immediate|compiled into current def|comilation is deferred to when current word runs|

In both cases `POSTPONE` is saying "don't do the thing right now, arrange 
for it to happen later".

If this still isn't clear, I wouldn't worry. You only need `POSTPONE`
if you're writing a custom datatype with its own behaviour, or if 
you're writing a `:` definition that is itself IMMEDIATE and you find 
yourself needing to compile something.

For regular `:` definitions (i.e. non-immediate ones) `POSTPONE` is 
almost certainly NOT what you need.

## strings.asm

 `S"` is a compile time, IMMEDIATE word that parses the string that follows 
 in the  input and compiles it as inline data. 

`(S")` is the corresponding runtime helper word, it  reads that inline 
data and pushes the address/length to the stack.

But wait! Happily `S"` can also be used at interpret time, in which case 
`(S")` is not involved, instead the interpreter parses the string directly 
into `s_quote_buf` (a static 258-byte buffer) and pushes `c-addr` and `u`
to the stack immediately. 

The buffer is "transient" per the ANS standard — it's valid until the 
next `S"` call or anything else that reuses that memory. That's fine for 
typical REPL usage like `S" hello" TYPE`.

The definitions of these string routines are quite long, so I won't reproduce 
them here, as the inner workings are pretty tedious.

Finally we have `'"` which does the work of `S" ...." TYPE` - i.e. in 
compile mode the `S"` and the `TYPE` are compiled, and in interpret mode 
the string is immediately echoed to the display.

Fun BMM aside: the LLM originally implemented `."` as a compile-time ONLY 
word, having followed the ANS spec a bit too literally (*"interpretation 
semantics for this word are undefined"*) but failed to see *"an imlementation 
may define interpretation semantics for `."` if desired"*. Every Forth 
I've used (which is, er, 5 including AntForth) and every Forth book I've 
read (7 so far!) permits `."` at interpretation time - indeed that's 
usually where you first encounter it. So I used BMM to push back and have 
it reworked. If this sort of thing happens to you, the code review agent 
or dev agent are the best ways to approach it: fire them up directly and 
express your complaint in natural language:

![DOT-QUOTE misunderstanding](/antforth/assets/images/2026-04-14/dot_quote.png)

## dictionary.asm

Finally we have a welcome but odd-ball inclusion: `WORDS`. `WORDS` just
walks our dictionary and dumps out the names of *all* the currently 
defined words, be they system-defined or user-defined.

Here's the current tally of AntForth's powers:

![All AntForth words](/antforth/assets/images/2026-04-12/antforth_words.png)

Not a bad haul!  But we're about to get a *lot* more...


