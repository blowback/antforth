---
layout: post
title: "Error handling"
date: 2026-04-09
---

Last time we got into a fight with Claude, but ended up being able to 
see the results of basic operations in our interactive AntForth interpreter.

What wasn't apparent from the demo I showed was that a stack underflow, or 
any other exception caused the interpreter to simply crash.

This sprint is going to be all about improving our error handling and recovery.

We want the following behaviours:

 - an undefined word causes the interpreter to print `?`, and `ABORT` is called 
 - a stack underflow causes the interpreter to print `? Stack undergflow`, and `ABORT` is called 
 - `ABORT` resets our stacks, but other state remains (e.g. the dictionary)
 - if a bad token occurs on the same line as some preceding good tokens, then the good
tokens have already been executed: in other words there is no "line-level context". 

A stack underflow is the particular case that we'll keep a close eye on after the
intervention we had to make about TOS-in-stack in the previous story.

We `bmad-bmm-create-story 2.4` and check the story file *scrupulously* to make sure 
that the new TOS-in-register approach is being honoured, and that Claude hasn't gone 
back to his old ways. He seems to have got the message:

![Claude getting the message](/antforth/assets/images/2026-04-09/claude_enlightenment.png)


Then we `bmad-bmm-dev-story 2.4` in the usual way. This could be a long one, it looks 
like there are 30 or more routines that need a stack underflow check, the majority of 
words that have been implemented before. Good job we found that stack depth bug 
before we embarked on this!

Didn't take long at all in the end: we follow up with a quick `bmad-bmm-code-review 2.4` 
just to keep things honest. This finds one missing stack underflow check, and a couple 
of weak tests, which we let it fix automatically.

I'm not going to show any code for this one, as it's mainly `CALL check_underflow` or 
`CALL check_underflow_2` getting added all over the shop.

## Testing 

The two hard-coded unit tests and the manual key test still work fine. When we run the 
AntForth interpreter we get:


![AntForth error handling](/antforth/assets/images/2026-04-09/error_handling.png)




