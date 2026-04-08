---
layout: post
title: "Conditionals & Indefinite loops"
date: 2026-04-12
---

Dijkstra teaches us that in order to reach [Structured Programming](Structured_programming) 
enlightenment we need:

 - "sequence": group sequences of code so that they act like and
   single statement
 - "selection": decide whether to execute a block based on the 
   state of the program 
 - "iteration": a block can be executed repeatedly until the  
   program reaches a certain state.

We are *all over* "sequence", but a bit lacking in "selection" and 
"iteration": this sprint will start to address those shortcomings!

We kick off with a `/bmad-bmm-create-story 3.3` and review the 
story document. The plan is to implement:

- `IF/THEN`: basic conditional 
- `IF/ELSE/THEN`: alternating conditional 
- `BEGIN/UNTIL`: basic indefinite loop 
- `BEGIN/WHILE/REPEAT`: variation on our basic indefinite loop 
- nested conditional statements 
- error checking: these are all IMMEDIATE words so they can 
  only be used in compile mode, not interpret mode

Implementation and code review proceed without drama. Let's 
look at what we have.


## control_flow.asm

In this file we have `IF`, `ELSE` and `THEN`:

### IF / THEN / ELSE

![IF implementation](/antforth/assets/images/2026-04-11/if.png)

`IF` is an **immediate word** `DEFIMMED "IF"`: it's used at compile time to 
help compile a new word, but it executes its own definition
right then and there. So the `DW` instructions you see here 
aren't being compiled into the new word, they are being 
executed at compile time.

Here's the dilemna that `IF` faces:

![IF dilemna](/antforth/assets/images/2026-04-11/forth_if.png)

When Forth is compiling a word and it hits an `IF` then if the value 
in TOS is TRUE the execution path is obvious: execute the following 
word. *BUT* if the value in TOS is FALSE, Forth needs to jump forward
to after the `THEN`, but the position of the `THEN` depends on the 
number of words in `Words...`, and while the interpreter's sat looking 
at the `IF` it doesn't yet have any idea how big a jump that is.

This is also the reason why you can only use branching words in 
compile mode and not in interpret mode.

So it does something sneaky: it pushes a *placeholder* value of zero,
pushes the address of that placeholder on to the parameter stack, 
and leaves it to `THEN` to alter ("patch" as Forthfolk like to call it) 
the placeholder, because  `THEN` knows where the falsey code is.

So the code above does this: `IF` pushes the address of `?BRANCH` 
onto the parameter stack with `LIT`, then uses `COMMA` to 
compile it into `HERE`. Then it calls the `HERE` word to 
get the next free compile slot in TOS. Then it compiles a literal 0 
placeholder with `w_LIT_cf, 0` - this placeholder will be 
rewritten ("patched") later, and the address left in TOS tells that 
later entity *where* to patch.

A quick recap on a couple of important words:

- `LIT`: takes the next value in the thread and pushes it into TOS
- `?BRANCH`: takes the next value in the thread, treats it as an offset 
  and if the value in TOS is **FALSE** it adds it to the current IP.
- `BRANCH`: takes the next value in the thread, treats it as an offset 
  and adds it to the current IP **unconditionally**.

So after IF runs, the definition being compiled contains 
`[?BRANCH][0]` and `HERE` has advanced past both cells.

The address of that `[0]` placeholder is left on the 
compile-time stack — it's a forward reference that 
`THEN` (or `ELSE`) will patch later.

Why's it on the stack? Because that provides an easy way to nest 
`IF`...`THEN` statements as deeply as you please - memory permitting.
The first `THEN` pops the stack, which is guaranteed to be the address 
of the placeholder for the matching `IF`.

![THEN implementation](/antforth/assets/images/2026-04-11/then.png)

THEN resolves IF's forward reference. It calculates 
`offset = HERE - fwd-ref` and writes it back into the placeholder 
that `IF` left. At runtime, when the `?BRANCH` fires 
(flag was FALSE/zero), it reads that offset from the 
cell and computes:

```
  new_IP = offset_cell_addr + offset
         = fwd-ref + (HERE - fwd-ref)
         = HERE    ← which is right after the IF clause
```

So the branch lands at whatever was compiled after `THEN`.


![ELSE implementation](/antforth/assets/images/2026-04-11/else.png)

`ELSE` is a combination of the two, and has the same problem two 
times over:

![ELSE dilemna](/antforth/assets/images/2026-04-11/forth_else.png)

`ELSE` does two things in one word:

1. Compile an unconditional `BRANCH` + placeholder (for 
   the true clause to skip over the else clause)
2. Resolve `IF`'s forward reference to point here 
   (start of else clause)

Remember that `?BRANCH` branches if the condition is FALSE.
Mnemonic: "if TRUE do the next bit".

### BEGIN/UNTIL

In the same file we have `BEGIN`, `UNTIL`, `WHILE` and `REPEAT`.

`BEGIN` is the easy one:

![BEGIN implementation](/antforth/assets/images/2026-04-11/begin.png)

It's just marking a backwards jump target by pushing HERE into TOS.
It just remembers where we are in the dictionary so that `UNTIL` or
`REPEAT` can jump back here.

![UNTIL implementation](/antforth/assets/images/2026-04-11/until.png)

`UNTIL` compiles a `?BRANCH` which will branch if TOS is false. To 
do that it pushes its own HERE address, subtracts from the (earlier) 
address that is in TOS (from `BEGIN`) to compute a jump offset.

The offset is negative because we're jumping backward. At runtime:

```
  new_IP = offset_cell_addr + offset
         = HERE + (begin-addr - HERE)
         = begin-addr
```

`BEGIN...UNTIL` is used like this:

```forth
  : TCNT 0 BEGIN 1 + DUP 5 = UNTIL ; 
```

Its compiled form looks like:

```
  [JP DOCOL]
  [LIT][0]
  [LIT][1]         ← begin-addr points here
  [+]
  [DUP]
  [LIT][5]
  [=]
  [?BRANCH][neg-offset]  ← jumps back to begin-addr when FALSE
  [EXIT]
```

So this code counts 0→1→2→3→4→5, loop exits when `5 =`  is TRUE.

### WHILE/REPEAT

Finally we have `WHILE` and `REPEAT` which are used like this:

```forth
BEGIN 
  Words1...
  condition 
WHILE 
  words2...
REPEAT
```


If you picture `Words1...` as empty for a moment, this is like 
`BEGIN...UNTIL` except that now we're testing the condition at the 
*top* of the loop rather than at the bottom, and the loop executes
`Words2...`. This is how it's normally used, but `Words1...` can be
as long as you please, giving you a loop that loops over `Words1...` 
and then `Words2...` effectively allowing you to place the condition 
anywhere in the loop body that you like. Crazy stuff.

`WHILE` looks like this:


![WHILE implementation](/antforth/assets/images/2026-04-11/while.png)

Like `IF`, it compiles ``?BRANCH`` with a placeholder — but this 
forward reference will be patched by `REPEAT`, not `THEN`.

The `SWAP`` at the end puts `begin-addr`` back on top so `REPEAT`
can grab it first for the backward jump. The stack ends up as 
`( while-fwd begin-addr )`.

`REPEAT` looks like this:

![REPEAT implementation](/antforth/assets/images/2026-04-11/repeat.png)

`REPEAT` does two things — the backward jump and the forward patch.

The backward `BRANCH` sends execution back to the top of the loop 
`(begin-addr)`. Then it patches `WHILE`'s `?BRANCH` placeholder 
so that when the condition is FALSE, it jumps forward to just 
past the `REPEAT` — exiting the loop.

`BEGIN...WHILE...REPEAT` is used like this:

```forth
: TSUM 0 5 BEGIN DUP 0 > WHILE SWAP OVER + SWAP 1 - REPEAT DROP ; 
```

Its compiled form looks like:

```
[JP DOCOL]
  [LIT][0]
  [LIT][5]
  [DUP]              ← begin-addr points here
  [LIT][0]
  [>]
  [?BRANCH][fwd-offset]   ← WHILE compiled; REPEAT patched fwd-offset
  [SWAP]
  [OVER]
  [+]
  [SWAP]
  [LIT][1]
  [-]
  [BRANCH][back-offset]   ← REPEAT compiled; jumps to begin-addr
  [DROP]              ← fwd-offset lands here (loop exit)
  [EXIT]
```

 At runtime with the initial stack ( 0 5 ):

  - Loop tests `DUP 0 >` —- is counter > 0?
  - TRUE → `?BRANCH`` falls through, executes body (accumulate sum, decrement counter)
  - `BRANCH` jumps back to `begin-addr`
  - When counter reaches 0 → `?BRANCH` takes the forward jump past `REPEAT`
  - `DROP` removes the zero counter, leaving the sum (15)

In summary:


|Structure|Test when?|Loop when...|Exit when...|
|---------|----------|------------|------------|
| BEGIN/UNTIL        | Bottom     | condition FALSE | condition TRUE  |
| BEGIN/WHILE/REPEAT | Top        | condition TRUE  | condition FALSE |


That was an exceedingly long post! Sorry about that: I was keen to 
demonstrate the sort of complexity and elegance of which Forth is 
capable, simply by stringing quite basic operations together in 
creative ways.

