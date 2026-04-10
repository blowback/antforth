---
layout: post
title: "Startup banner"
date: 2026-04-15
---

The previous blog post marked the end of epic 3 development, so the "team" had 
another retro and we all agreed that everything had gone swimmingly. Next up 
is a built-in assembler! This was a crucial feature of early Forths and was  
one of the main reasons Forth was often the first thing ported to a new board
or device: it gives you a real-time execution environment where you can test 
out hardware andbegin software development with very little to port. Forth's 
ability to *metacompile* (define new words for a *target* system on a more 
highly specced *host* system) was another huge draw.

As I've previously mentioned, Forth's built-in assembler was the inspiration 
behind BBC BASIC's built-in assembler: a huge advantage over the ZX Spectrum 
at the time, and the reason that a lot of folk started their assembler journey 
with 6502 rather than z80 (until they could get their hands on a hooky copy 
of the incomparable ZEUS z80 assembler, that is!)

But first a digression: AntForth is currently 6953 bytes and contains 124 words
and is approaching "genuinely useful" status: and as such, I think it deserves
a startup banner! So I created a new story (4.0) to implement one.

## antforth.asm

The new startup banner is implemented in proto-Forth, and I'm not including the
source code here so as not to ruin the big reveal! You can look in the github 
repo for details, but it's nothing too earth shattering. Look for `cold_thread` 
and you'll find it.

Here's the new startup banner:

![AntForth startup banner](/antforth/assets/images/2026-04-15/antforth.png)

Pretty sweet right? Most of the complexity in the startup banner is to do with 
working out that free bytes total, and I swiped the "type BYE to exit" from 
GForth, as that's pretty handy advice for beginners (AntForth has no truck with
ctrl-c getting you out of trouble).

But wait! There's more! Let's zoom out slightly from that previous screenshot...

![AntForth running on MicroBeast](/antforth/assets/images/2026-04-15/antforth_on_beast.png)

It was running on the MicroBeast the whole time!!

We've got just under 48K of free space, not bad at all. Compare this with
AntForth running under iz-cpm:

![AntForth running on iz-cpm](/antforth/assets/images/2026-04-15/antforth_izcpm.png)

I guess iz-cpm has a slightly smaller BIOS.
