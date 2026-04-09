---
layout: post
title: "Counted loops and RECURSE"
date: 2026-04-13
---

Last time we had a lot of fun discovering how Forth's simple 
primitives can be combined to produce sophisticated indefinite
loops. This time we'll look at the *definite* loops, where you 
know ahead of time how many iterations of the loop there will be.

We start with `/bmad-bmm-create-story 3.4` and review the story plan.
This time we'll be getting such delights as `DO`, `LOOP`, `+LOOP`, 
`LEAVE`, `I`, `J` and the mysterious `RECURSE`.

The first four are all compile time immediate words, but `RECURSE` is 
an immediate mode DEFCODE word. 

Story looks OK, so `/bmad-bmm-dev-story 3.4`. We note the developer LLM 
grumble: 

```
 I found a bug: the LEAVE approach in the story spec is broken 
when LEAVE appears inside IF/THEN (the intervening if-fwd is 
between do-addr and chain on the compile-time stack, so LEAVE 
picks up the wrong cell). I'll fix this by keeping the 
LEAVE-chain head in a dedicated memory cell (with DO/LOOP 
saving/restoring the outer chain through the data stack) — 
this is a well-known clean approach.
```

and:

```
2. LEAVE-chain design fix: The story's spec proposed passing 
the LEAVE chain head on the compile-time data stack. I found 
this broken when LEAVE is nested inside IF/THEN: the IF's 
forward-ref sits on top of the chain at LEAVE time, causing 
LEAVE to corrupt both structures (verified with FIND5 hanging). 
Fix: stored the chain head in a dedicated assembly cell 
leave_chain_head, with DO saving the outer value to the data 
stack and LOOP restoring it — LEAVE no longer touches the data 
stack at all. Added two internal helpers 
w_LCFETCH_cf/w_LCSTORE_cf (no dict header) for 
DO/LOOP/+LOOP/LEAVE to use.
```

We'll need to review that carefully. 

Next,  `/bmad-bmm-code-review 3.4` finds a couple of gaps in 
test converage but nothing more serious, so we let him go ahead
and fix those.

## control_flow.asm

Once again our changes are all in this file. First we'll look at 
`DO` and `LOOP` which are used like this:

```Forth
:foo 10 0 DO I . LOOP;
```

The first number is called the *limit* and the second number is called 
the *index*. The loop will add one to the loop count each iteration,
and loop around while the loop count is less than the limit. Inside 
the loop, `I` gives you the current loop count. So the routine above 
prints "0 1 2 3 4 5 6 7 8 9".

Why does the limit come before the index? Unclear. Perhaps given Forth's 
generally reversed syntax they decided to just lean in to it!

![The Sensational Reverse Brothers](/antforth/assets/images/2026-04-13/reverse_bros.webp)

Incidentally, if you have two nested loops, `I` is the inner loop 
count and `J` is the outer loop count:

![Two nested DO loops in GForth](/antforth/assets/images/2026-04-13/gforth_2loops.png)

To go beyond two loops, some Forth's have a variable `K` (e.g. GForth) 
but AntForth does not. In many Forths there is no `K`. So what do
you do if you need more than two nested loops? The received wisdom is,
*"refactor your code!"*. Split your code up into multiple words so that
triply-nested loops (or more) are avoided. The practical answer is,
*"store your outer loop index in a variable"*:

![Three nested DO loops in GForth](/antforth/assets/images/2026-04-13/gforth_3loops.png)

And the hacky answer is that, since all nested loops push their limit and
current index onto the return stack, you can get the address of the top of 
the return stack and PEEK your way to glory. But we haven't really dealt 
with the return stack much so we'll leave it there for now.

![Three nested DO loops in GForth with hacks](/antforth/assets/images/2026-04-13/gforth_3loops_hacks.png)

`DO`, `LOOP`, `+LOOP` and `LEAVE` are compile-time immediate words: you 
can only use them when compiling (like `IF` et al) but they execute immediately. 

Here's what `DO` does:

![DO implementation](/antforth/assets/images/2026-04-13/do.png)

It does the compile-time guard, then compiles the XT for something mysterious 
called `PAREN_DO` then pushes `HERE` (a backward jump target that we'll refer 
to as `do_addr`) then calls another mystery `LCFETCH` before stacking a zero
and passing it to `LCSTORE`.

`LCSTORE` and `LCFETCH` just access a bit of static memory:

![LCSTORE/LCFETCH implementation](/antforth/assets/images/2026-04-13/lcstore_lcfetch.png)

We'll call the value that `LCFETCH` leaves on the parameter stack `old_lc`.

`PAREN_DO` is the word `(DO)` and it's the *runtime* counterpart of `DO`.
Here's what `(DO)` does:

![(DO) implementation](/antforth/assets/images/2026-04-13/paren_do.png)

It pops the limit from the parameter stack and pushes it to the *return* 
stack (indexed by IX). Then it pops the index from the parameter stack
and pushes that to the return stack too. This pair of values pushed 
onto the return stack is called a *loop frame*.


Here's `LOOP`:

![LOOP implementation](/antforth/assets/images/2026-04-13/loop.png)

`LOOP` is compiling `PAREN_LOOP` (aka `(LOOP)` into the thread). `(LOOP)` 
is the runtime counterpart of `LOOP`. Then it compiles a backwards 
branch to `do_addr`. Then it walks the "leave_chain" and patches every
`LEAVE` placeholder to point forward to the address right after the 
branch, i.e. the natural exit. Finally it restores `leave_chain_head`
from the saved `old_lc`, so the outer loop's chain (if any) is back in scope.

Vy now you're probably wondering what on earth all this "leave chain" 
nonsense is all about, but let's defer that conversation until we 
discuss the `LEAVE` word...

`(LOOP)` is the runtime couterpart of `LOOP`:

![(LOOP) implementation](/antforth/assets/images/2026-04-13/paren_loop.png)

`(LOOP)` incrementsthe index at IX+0/1, compares the new index to the 
limit at IX+2/3, and if they're equal it drops the loop frame (IX += 4), 
skips past the inline offset cell (DE += 2), and continues with the 
next instruction. Then the loop is done. If the new index doesn't equal
the limit, it takes the backward branch — reading  the offset cell, 
adding it to its own address to compute the new IP, and jumping there. 
We're back at the top of the loop body.

Incidentally, what do you think happens if the limit and the initial 
index are the same size?

![limit same as index](/antforth/assets/images/2026-04-13/super_looper.png)

That's right: an awful lot of iterations. One for every value that the
Forth's cell size can take (which is why I demonstrated this in AntForth 
and not in 64-bit GForth!). This seems like an odd choice, and might 
have originally been a bug, but it is now enshrined in the ANS Forth 
standard and pretty much every Forth behaves this way.

`LEAVE` causes the loop to exit immediately:

![LEAVE implementation](/antforth/assets/images/2026-04-13/leave.png)

The catch is, `LEAVE` needs to leave *immediately*, even from within 
deeply nested `IF...THEN` chains. And there can be *multiple* `LEAVE`s 
in any given loop, and each one doesn't yet know where the loop's
exit is, because `LOOP` hasn't been compiled yet.

This is precisely what the developer LLM was complaining about when 
it was writing this story. The solution it came up with (an establised 
approach) is a linked list of "fix me later" placeholders, threaded 
through the compiled code itself. Each `LEAVE` emits:

```
  UNLOOP_xt    BRANCH_xt    <placeholder cell containing prev-link>
                            ↑ this is the new chain head
```

The placeholder cell does double duty: right now it stores a pointer 
to the previous `LEAVE`'s placeholder (or 0 if this is the first one). 
The head of the chain is kept in a global cell `leave_chain_head`.

Then when `LOOP` finally runs, it walks the chain:

```
  chain -> cell -> next_link -> cell -> next_link -> ... -> 0
```

For each cell, it overwrites the link with the forward branch offset
from that cell to `HERE`` (the address after the loop). 

After the walk, those cells no longer hold chain links — they hold 
real branch targets, and the runtime `BRANCH`` instructions will 
jump straight to the loop exit when executed.

We can't keep the chain head on the stack alongside `do_addr` because 
an `IF...THEN` pushes its own forward reference. 

We also have `+LOOP` and `(+LOOP)` which are exactly like `LOOP`, 
but instead of adding 1 to the loop index it adds whatever is in the
TOS:


![+LOOP implementation](/antforth/assets/images/2026-04-13/plus_loop.png)

Finally, we have `RECURSE`:

![RECURSE implementation](/antforth/assets/images/2026-04-13/recurse.png)

*Recursion* is simply the act of calling ourselves. In many languages,
if you're defining a new function, it can refer to itself:

```c
int sum(int k) {
  if (k > 0) {
    return k + sum(k - 1);
  } else {
    return 0;
  }
}
```

However, Forth has a special behaviour: when you're defining a NEW word 
that word isn't available until the final `;`, and if you're RE-defining 
an existing word, you get the *old* definition of that word until the 
final `;`. So you can redefine a word in terms of the previous version 
of the same name, if you see what I mean.

This presents a problem: a word can't call itself by name (we';; either 
get an error, or call the previous version of the word). This is where 
`RECURSE` comes in. 

It's an *immediate* `DEFCODE` word, so you know something spicy is coming.

`RECURSE` therefore runs at compile time. Its job is exactly one thing: 
at the current point in the thread being compiled, lay down a call to 
the word currently being defined. To do that, it needs the code-field 
address (CFA) of that word — the address that, when executed, runs the word.

It finds that address by reading `LATEST` directly. `LATEST` is a pointer 
in the user area `(IY+UserArea.latest)` that always points to the most 
recently created dictionary entry — and `:` updates `LATEST` before it 
starts compiling the body. So even though `F_SMUDGE` hides the entry 
from `FIND`, `LATEST` still points right at it.

`RECURSE` therefore sidesteps `FIND` entirely.


