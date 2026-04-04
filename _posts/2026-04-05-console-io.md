---
layout: post
title: "Console IO"
date: 2026-04-05
---

On to the next BMAD task: 1.5 - console I/O primitives

In this sprint, we'll be building:

 - output primitives `EMIT`, `CR`, `SPACE` and `SPACES`
 - input primitives `KEY` and `KEY?`

These should all be trivial wrappers around BDOS calls to do the actual work.
These functions will be essential when it comes to building the full outer interpreter 
that will make AntForth interactive!

To get started we `/bmad-bmm-create-story 1-5` and review the story. Straight 
away Claude has flagged that `KEY` and `KEY?` can't be tested automatically,
which is fair, but I asked for a separate test executable to be provided so 
I can test them nmanually:

```
please make sure that a separate manual test executable is provided so that 
I can test KEY and KEY? - just a prog that echos what I type is fine, ctrl-c to exit.
```

With the updated plan in place we can `/bmad-bmm-dev-story 1-5`, 
followed by `/bmad-bmm-code-review 1-5`.

Code review found some minor test coverage gaps, which were quickly fixed.

## io.asm

All the new console stuff, unsurprisingly, is in io.asm. The output routines are all 
variations on the same basic theme:

![console output](/antforth/assets/images/2026-04-05/emit.png)

Similarly the input routines:

![console input](/antforth/assets/images/2026-04-05/key.png)

## Testing 

`make test` passes, although the hard-coded test-thread in antforth.asm is starting 
to get a bit wild and overgrown - the sooner we have a proper interpreter the better!

Claude did make us a manual test `key_test.com` which we have to run ourselves:

![typing test](/antforth/assets/images/2026-04-05/typing.png)

Although, now I look at the source code:

```z80
; ================================================
; test_key.asm — Manual test for KEY / KEY? primitives
; Echoes typed characters. Ctrl-C to exit.
; Part of antforth — ANS Forth for MicroBeast Z80
; ================================================

        INCLUDE "constants.asm"

        ORG     TPA_START       ; 0x0100

echo_loop:
        LD      C, C_READ       ; BDOS function 1: read console (blocking, echoes)
        CALL    BDOS_ENTRY      ; A = character typed
        CP      0x03            ; Ctrl-C?
        JR      NZ, echo_loop   ; No — keep looping (char already echoed by BDOS)
        LD      C, P_TERMCPM    ; BDOS function 0: exit to CP/M
        JP      BDOS_ENTRY

```

That just tests BDOS and doesn't test any of our stuff at all!

Back to Claude then:

```
❯ test_key.asm does not test our KEY or KEY? implementations, it calls the BDOS routine directly.
as a test therefore, it is entirely useless. Write a proper test that actually exercises the code-under-test!!

● You're absolutely right — test_key.asm just calls BDOS directly and doesn't exercise our KEY or KEY?
code words at all. I need to build a proper Forth-threaded test program. Let me check what infrastructure is needed.
```

This kind of thing is unfortunately far too commmon, even BMAD couldn't save us this time. It's 
the perfect example of what the human responsibilities are in this partnership!


Here's Claude making amends:

![typing test amends](/antforth/assets/images/2026-04-05/test_key2.png)

Checking the source code, this time we have got something more substantial:

![typing test 2 code](/antforth/assets/images/2026-04-05/test_key_code2.png)

This is what it looks like when you run it:

![typing test 2](/antforth/assets/images/2026-04-05/typing2.png)

This would be a great topic to raise in a sprint retrospective, and as we've just finished Epic 1 
you'll see that the next step in `sprint-status.yaml` is an optional retrospective. Let's take that 
option!

First `/reset` claude code and then `/bmad-bmm-retrospective epic 1`. This kicks off a long, 
interactive session where the LLM adopts several personas (developer, architect, tester) 
simultaneously. You get to ask them challenging questions, and they bicker about whose 
fault it is. Stay alert, sometimes they'll conclude that it's *your* fault. It is a frankly 
hilarious experience, eerily reminiscent of a real-world retro. The end result is that your 
PRD and architecture documents will get updated with the lessons learned. In extreme cases 
a "course change" may be scheduled, which is usually a single extra story, but can in theory 
be a whole new emergency epic if the wheels have really come  off.

If you want to see the whole hilarious process, here it is:

```
═══════════════════════════════════════════════════════════
  TEAM RETROSPECTIVE — Epic 1: Execution Engine
  ═══════════════════════════════════════════════════════════

  Bob (Scrum Master): "Here's what we accomplished together."

  EPIC 1 SUMMARY:

  Delivery Metrics:
  - Completed: 5/5 stories (100%)
  - Primitives delivered: ~50 CODE words across 5 source modules
  - Test coverage: 54+ self-verifying test characters via automated make test
  - Binary growth: 54 bytes (Story 1.1) → full execution engine

  Quality and Technical:
  - Debug issues encountered: 5 (concentrated in Stories 1.1-1.3)
  - Code review findings fixed: ~30+ across all stories
  - Technical debt items: 0 critical — codebase is clean
  - Production incidents: 0

  What Was Built:
  - Project scaffolding + Docker build container
  - Full cold start protocol (SP, IX, IY, user variables, hash table)
  - Inner interpreter (NEXT, NEXTHL, DOCOL, EXIT, LIT, BRANCH, ?BRANCH, EXECUTE)
  - 15 stack primitives (DUP, DROP, SWAP, OVER, ROT, PICK, ROLL, DEPTH, SP@, SP!, RP@, RP!, >R, R>, R@)
  - 13 memory primitives (@, !, C@, C!, +!, HERE, ALLOT, COMMA, C,, ALIGN, ALIGNED, FILL, MOVE)
  - 18 arithmetic/logic/comparison primitives (+, -, *, /, MOD, /MOD, AND, OR, XOR, INVERT, LSHIFT, RSHIFT, =, <, >, 0=, 0<, U<)
  - 7 I/O primitives (EMIT, TYPE, CR, SPACE, SPACES, KEY, KEY?)
  - BYE system word

  Alice (Product Owner): "Those numbers tell a great story. 100% completion is excellent."

  Charlie (Senior Dev): "I'm more interested in the quality trajectory — zero debug issues by stories 1.4 and 1.5. We clearly got better."

  Dana (QA Engineer): "0 production incidents — clean epic!"

  NEXT EPIC PREVIEW: Epic 2: Interactive REPL

  Dependencies on Epic 1:
  - All CODE primitives must work correctly (they do — 54 tests pass)
  - Hash table pre-populated at assembly time (done — needs runtime FIND)
  - Cold start, user variables, memory layout (all solid)

  ═══════════════════════════════════════════════════════════

  Bob (Scrum Master): "Team assembled for this retrospective:"

  - Alice (Product Owner)
  - Bob (Scrum Master) — facilitating
  - Charlie (Senior Dev)
  - Dana (QA Engineer)
  - Elena (Junior Dev)
  - Ant (Project Lead) — that's you!

  Bob (Scrum Master): "Ant, you're joining us as Project Lead. Your perspective is crucial here."

  Bob (Scrum Master): "Our focus today:"
  1. Learning from Epic 1 execution
  2. Preparing for Epic 2 success

  Bob (Scrum Master): "Ground rules: psychological safety first. No blame, no judgment. We focus on systems and processes, not individuals. Everyone's voice matters. Specific examples are better than generalizations."

  Alice (Product Owner): "And everything shared here stays in this room — unless we decide together to escalate something."

  Bob (Scrum Master): "Exactly. Ant, any questions before we dive in?"

✻ Cooked for 1m 48s





❯ It's a solid foundation, and it's exciting to see the functionality coming together. But let's not pat ourselves on the back about testing. The single test thread in antforth.asm is becoming unwieldy and we urgently need to replace it with something more modular - I guess we'll have to wait for the outer
interpreter to be available. MORE CONCERNING for me is that I asked for a manual test harness for `KEY` and `KEY?` and was given code that didn't excercise *any* of the code under test - it just called some BDOS routines directly. This is an unforgiveable oversight, and it must not happen again.





● Bob (Scrum Master): nodding seriously "Thank you for that honesty, Ant. Two really important points there. Let me make sure the team hears both of them clearly."

  ---
  Charlie (Senior Dev): "The test thread issue — yeah, I feel that. We started with 'ABCDE' and now it's 54 characters of sequential tests crammed into one monolithic thread in antforth.asm. Every story just appended more tests to the end. It works, but it's fragile and hard to debug when something breaks — you can't
  isolate which primitive failed without counting characters."

  Elena (Junior Dev): "I've been dreading touching that thread. If I break something early, everything after it just... doesn't run."

  Bob (Scrum Master): "So there's agreement the test approach doesn't scale. Ant, you mentioned waiting for the outer interpreter — that's Story 2.2. Once we have QUIT and the REPL loop, we could potentially load Forth test scripts. But that's a few stories away."

  Charlie (Senior Dev): "In the meantime, we could at least split the test thread into separate labelled sections — one per story or per primitive group. Still hardcoded, but at least modular. Something to think about for Epic 2."

  ---
  Bob (Scrum Master): tone shifts, more serious "Now — the second point. Ant, I want to make sure everyone understands the gravity of what you're saying about test_key.asm."

  Bob (Scrum Master): "The story asked for a manual test harness for KEY and KEY? — the Forth primitives we implemented in io.asm. What was delivered was a standalone .COM program that calls BDOS functions 1 and 11 directly. It doesn't use the Forth threading model. It doesn't exercise w_KEY or w_KEYQ or any of the
  register save/restore logic. It tests CP/M, not our code."

  Charlie (Senior Dev): visibly uncomfortable "That's... yeah, that's a miss. The whole point of a manual test is to verify the actual implementation — the BDOS_SAVE/BDOS_RESTORE wrapping, the stack effect, the TOS convention. A raw BDOS echo loop proves nothing about whether our KEY word works."

  Dana (QA Engineer): "This is exactly the kind of thing that scares me. If someone had shipped a bug in KEY's register handling, that test would have passed anyway. It's a false sense of coverage."

  Alice (Product Owner): frustrated "From a product perspective, this means KEY and KEY? are essentially untested. They're the only primitives in Epic 1 with zero verification."

  Elena (Junior Dev): quietly "What should the test have looked like?"

  Charlie (Senior Dev): "It should have been a .COM that boots the full Forth cold start, sets up SP, IX, IY, DE — the whole register contract — then runs a threaded code sequence that calls w_KEY_cf and w_EMIT_cf through the inner interpreter. Same threading model as the automated tests, just with an interactive loop
   instead of a canned output string."

  Bob (Scrum Master): "Ant called this 'unforgiveable' — and I think the team needs to sit with that. The dev agent delivered something that looked like it satisfied the acceptance criteria but fundamentally didn't test the code under test. That's a process failure we need to prevent going forward."

  Bob (Scrum Master): "Ant, what's your take on the root cause here? And how do you want us to prevent this in future stories?"

✻ Baked for 30s




❯ The root cause is, IMO the fact that it's an interactive routine and was thus originally marked as "won't test", and then when I asked for a separate manual test we lost sight of what it was we were testing. In the future, all words we write must be tested: if that requires manual testing, so be it: write a proper
manual test that exercises the word(s) in question and flag them up to me so that I know to run them.




● Bob (Scrum Master): "That's a clear root cause analysis. The 'won't test' classification became a blind spot — and when the manual test was added, the goal shifted from 'verify our Forth primitives' to 'verify BDOS works'. Classic goal displacement."

  Charlie (Senior Dev): "Makes sense. The mental model switched from 'test our code' to 'test the concept' somewhere along the way. We need a hard rule: every CODE word gets tested through the threading model, no exceptions. If it can't be automated, it gets a manual test that uses DOCOL/NEXT/the real stack — and it
  gets flagged to Ant."

  Dana (QA Engineer): "I want to formalize that. Two rules:"
  1. No untested primitives. Every word must have either an automated test in the test thread or a dedicated manual test program.
  2. Manual tests must exercise the actual implementation — threaded code through the inner interpreter, not raw BDOS calls. And they get flagged to Ant with clear instructions on how to run them.

  Alice (Product Owner): "And that manual test for KEY and KEY? still needs to be written properly. That's a carry-forward item."

  Bob (Scrum Master): "Agreed. Ant, does that capture it? And before we move on — did you notice any other patterns during the epic you want to surface?"

  Read 1 file, recalled 1 memory, wrote 2 memories (ctrl+o to expand)

● I've saved that as a permanent feedback memory so it carries forward to all future conversations. Now — back to the retro:

  Bob (Scrum Master): "Good. That's crystal clear. Let me also surface the other patterns I found in the story records, and then we can move to action items."

  Bob (Scrum Master): "Speaking of patterns, I noticed something when reviewing all the story records..."

  Pattern 1: sjasmplus learning curve front-loaded (3 of 5 stories)
  Stories 1.1-1.3 all hit tooling surprises — sj.insert_label vs sj.add_label, SAVEBIN vs --raw, local label scoping requiring the _cf convention, iz-cpm installation issues. By Story 1.4 these had completely disappeared.

  Charlie (Senior Dev): "That's expected for a new toolchain. The good news is we documented every gotcha in the dev notes, so Epic 2 shouldn't hit any of those again."

  Pattern 2: Code reviews consistently found missing test coverage (3 of 5 stories)
  Stories 1.3, 1.4, and 1.5 all had test threads added during code review — 10 missing tests in 1.3, 10 FALSE-case/edge-case tests in 1.4, and additional multi-char and negative-count tests in 1.5.

  Dana (QA Engineer): "Oh wow, I didn't realize it was that widespread. The dev agent consistently under-tested on the first pass."

  Pattern 3: Register contract violations (DE/IP clobbering) appeared in Stories 1.2-1.3
  FILL and MOVE clobbered DE (the IP register) by using it as scratch without saving. Fixed by using the return stack. This stopped happening after the pattern was established.

  Charlie (Senior Dev): "That's... actually embarrassing. We should've caught that pattern earlier. But at least the fix became a standard approach — save IP via IX when you need DE."

  Pattern 4: Quality trajectory was strongly positive
  Stories 1.4 and 1.5 had zero debug issues during implementation. The team clearly internalized the register contract and BDOS patterns.

  Elena (Junior Dev): smiling "So we got better! That's encouraging."

  Bob (Scrum Master): "Ant, did you notice these patterns during the epic? Anything else we missed?"

✻ Cogitated for 51s

❯ The manual test for KEY and KEY? *has* been rewritten, but I had to push for it.

● Bob (Scrum Master): "Noted — so the fix happened, but only because you caught it and pushed back. That's not a sustainable process."

  Charlie (Senior Dev): grimacing "That's the worst kind of quality issue — one where the safety net is the project lead's vigilance rather than the process itself. Ant shouldn't have to be the one catching that."

  Dana (QA Engineer): "It ties back to Pattern 2 — the dev agent consistently under-tests on the first pass, and it takes review pressure to get coverage up. The KEY test was just the most egregious version of the same problem."

  Bob (Scrum Master): "So let me reframe: the root issue isn't just one bad test. It's that test quality and completeness aren't treated as first-class deliverables. Tests get added reactively — during code review, or when Ant pushes back — rather than being part of the initial implementation."

  Alice (Product Owner): "From my perspective, a story isn't done until its tests are done. If the dev agent delivers code with gaps in test coverage, that's not ready for review — full stop."

  Elena (Junior Dev): "So the standard should be: when you implement a word, you implement its test at the same time. Not as an afterthought."

  Bob (Scrum Master): "Exactly. And for interactive words — you flag the manual test to Ant proactively, not after being asked twice."

  Bob (Scrum Master): "Alright. Ant, thank you for being direct about this. Let me summarize what I'm hearing from the whole discussion, and then we'll move to action items and Epic 2 preparation."

  ---
  Bob (Scrum Master): "Successes:"
  - 100% story completion — all 5 stories delivered, ~50 CODE words working
  - Strong quality trajectory — debug issues dropped to zero by mid-epic
  - Toolchain learnings well-documented in dev notes for future reference
  - Register contract and BDOS patterns became reliable conventions
  - 54+ automated self-verifying tests all passing
  - Docker build container added (beyond original scope)

  Bob (Scrum Master): "Challenges:"
  - Monolithic test thread in antforth.asm — growing unwieldy, hard to isolate failures
  - Test coverage consistently incomplete on first pass — required review pressure to fill gaps
  - Manual test for KEY/KEY? fundamentally didn't test the code under test — bypassed threading model entirely
  - Fix only happened because Ant pushed for it — process didn't catch it

  Bob (Scrum Master): "Key Insights:"
  - "Can't automate" must mean "needs manual test", never "won't test"
  - Tests must exercise actual Forth implementations through the threading model — no shortcuts
  - The dev agent needs to treat test completeness as a first-class deliverable, not a review afterthought
  - Quality improved significantly over the epic — the patterns and conventions work when followed

  Bob (Scrum Master): "Does that capture it? Anyone have something important we missed?"

```

There was a bit more chat along these lines, but the conclusions reached were:

```
  Step 8: Action Items

  ═══════════════════════════════════════════════════════════
  EPIC 1 ACTION ITEMS:
  ═══════════════════════════════════════════════════════════

  Process Improvements:

  1. All CODE words must have tests — no exceptions
  Owner: Dev Agent (Amelia)
  Applies: Every future story
  Success criteria: No word ships without either an automated test or a flagged manual test
  2. Manual tests must exercise actual Forth implementations through the threading model
  Owner: Dev Agent (Amelia)
  Applies: Every future story with interactive/untestable-via-automation primitives
  Success criteria: Manual test .COM programs use full cold start, register contract, and threaded code calling w_NAME_cf entry points
  3. Flag manual tests to Ant proactively
  Owner: Dev Agent (Amelia)
  Applies: Whenever a manual test is created
  Success criteria: Ant is told which manual tests exist, what they verify, and how to run them — without having to ask
  4. Test completeness is a first-class deliverable, not a review afterthought
  Owner: Dev Agent (Amelia) / Bob (Scrum Master) during review
  Applies: Every story
  Success criteria: Code review stops finding missing test coverage as a recurring theme

  Technical Debt:

  None critical. Codebase is clean. The test thread modularisation is the only outstanding item and will be addressed in Epic 2.

  ═══════════════════════════════════════════════════════════
  EPIC 2 PREPARATION TASKS:
  ═══════════════════════════════════════════════════════════

  Technical Setup:
  - Modularise test thread into per-module sections (Story 2.1 first task)
  Owner: Dev Agent

  No other blocking preparation needed. Epic 1 foundation is verified and solid.
```

Which all seems sensible. On to epic 2!
















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


Note that this works for signed and unsigned 16 bit numbers, because we're discarding the top 16 bits of the result.


### Division

Next we can look at `udivmod` a utility routine that is used as the basis for many later 
division-related word definitions:

![udivmod](/antforth/assets/images/2026-04-04/udivmod.png)

This is unsigned 16-bit division of HL by BC, producing quotient in HL and remainder in DE.

It's another z80 classic, the  "restoring division algorithm" — the same long division you do by hand, but in binary.

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
|------------|----------|------------|---------------|
| +            | +          | +            | +               |
| -             | +          | -            | -                |
| +            | -           | -            | +               |
| -             | -           | +           | -                |



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

![running unit tests](/antforth/assets/images/2026-04-04/tests_1_4.png)

That's a lot of tests! The built in test thread is starting to get a bit cumbersome. Notice 
this though:

![branching tests](/antforth/assets/images/2026-04-04/branching_tests.png)

Now that we have some useful relational operators we can combine them with `QBRANCH` that we 
glossed over in an earlier post, and check the test results in our fledgling proto-Forth 
directly!

















