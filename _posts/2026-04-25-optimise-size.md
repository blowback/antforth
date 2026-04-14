---
layout: post
title: "Optimising for code size"
date: 2026-04-25
---

MVP is done! Before starting to think about additional phases and new 
features, I wanted to do a bit of optimisation for code size, in part 
prompted by the tentative offer of putting AntForth into the MicroBeast's 
romdisk - where space is at a premium.

When we made our first release (before we added the inline assembler) our 
antforth.com binary weighed in at 6.82 KB, and when we'd finished the 
assembler (with 100% z80 opcode coverage) we were up to 15.2 KB. That's 
nearly 8.5 KB on the assembler alone, which seems like a lot.

The smallest z80 assembler I can find is Kroc's v80, which is a table driven
assembler that weighs in at 6.7 KB according to the author. I'd give you a 
link, but he's deleted the entire repo as an act of anti-AI defiance. Oh dear.
(Ironic that I only discovered v80 through the AI search thingy at the top 
of google search).

But if his [post](https://oldbytes.space/@Kroc/112594109189791371) is to be believed,
AntForth is 1.8 KB off the pace.

I'd noticed that there was a lot of duplication in outputting console messages,
with a lot of places in the code setting up their own BDOS calls. In addition 
it seemed like there was a lot of duplication, particularly around stacking 
registers, that might benefit from factoring out the common functionality (which 
is a very Forth thing to do!).

I assembled the LLM team and set them to finding opportunities to reduce the code size.
We created a new epic 6 just for optimisation, covering the stdout type stuff 
I already mentioned, and various 'peephole' optimisations around refactoring code.
They came up with an ingenious `LD,` rework on their own. 

At every story in this sprint the assembler remained fully functional whilst 
gradually reducing in size. No regressions at all. 

While doing the retro at the end of sprint 6, it occured to me that much of the 
complexity that remained in `LD,` (and in many other words) was to do with stacking 
registers while we juggled them for other purposes - something that the alternate 
register set would be ideal for, and which we hitherto had not used at all. 

Cue epic 7 (only 3 stories this time) for shadow register optimisations. 

During the retro for epic 7, a few more optimisations were identified, including 
that we hadn't taken advantage of `EX AF, AF'` either, so another epic (8) was 
created, with 4 short stories this time around.

## TL;DR - how big is it now?

After 14 sprints-worth  of refactoring, the final binary size is:

** 13.7 KB **

That means our assembler is 6.9 KB, so we're roughly 200 bytes larger than the 
most compact assembler on record - 1.5 KB smaller than the original implementation!


 
![BInary size optimisation graph](/antforth/assets/images/2026-04-25/binary-size-trajectory.svg)


