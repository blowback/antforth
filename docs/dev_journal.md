# Things we're missing, discovered during the course of development

(It's not for features or big ticket items, but for gaps).

 - `UD.` - display unsigned double precision int — RESOLVED 2026-06-28, Story 23.4
 - "EXCEPTION" and "EXCEPTION-EXT" environment queries — RESOLVED 2026-06-28, Story 23.4
 - "DOUBLE" and "DOUBLE-EXT" environment queries — RESOLVED 2026-06-28, Story 23.4
 - "SEARCH-ORDER" and "SEARCH-ORDER-EXT" environment queries — RESOLVED 2026-06-28, Story 23.4
 - `-ROT` — RESOLVED 2026-10-08, Story 27.1
 - `?` - does a fetch followed by a print `: ? ( addr -- ) @ . ` — RESOLVED 2026-10-08, Story 27.1
 - "MBB-VERSION" and "MBB-PLATFORM" environment queries, returning the firmware version 
   and platform (1 for MicroBeast, 2 for NanoBeast) respectively.
 - make startup banner say "MicroBeast" or "NanoBeast" depending on MBB-PLATFORM.
 - "ANTFORTH" environment query that returns AntForth version
 - TRUE/FALSE words that evaluate to -1 and 0 respectively
 - <=, >=, <> — RESOLVED 2026-10-08, Story 27.2
 - 0>, 0<> — RESOLVED 2026-10-08, Story 27.2
 - .(  (immediate print)
 - 2>R, 2R>
 - :NONAME 
 - ?DO — RESOLVED 2026-10-08, Story 27.4
 - AGAIN — RESOLVED 2026-10-08, Story 27.3
 - DEFER, DEFER!, DEFER@, IS
 - NIP, TUCK — RESOLVED 2026-10-08, Story 27.1
 - U.R, U> — RESOLVED 2026-10-08, Story 27.2 (U.R already present since Story 10.8)
 - random number facility: fast xorshift is fine: seed, rnd ( n -- ), random ( n -- 0..n-1 )

## 2026-10-11 (OPEN) — fixed RAM below `$8000` now holds only two TCBs

Found during Story 27.6. A TCB has to sit below `$8000` (`TASK` raises `-8`
otherwise), and that room is whatever the kernel leaves between the boot
`HERE` and `$8000`. Every kernel byte comes out of it. On the 31,336 B binary
(after 27.6) the boot `HERE` is 31,592, which leaves 1,176 B. A TCB is 535 B
(547 B with the `CONSTANT` that names it), so two tasks fit with about 80 B to
spare, and only if they are carved before anything else is defined. The
comment in `TASK` said "the slack below `$8000` is ~3 KB"; it was about 1.8 KB
before Epic 27 and 1,435 B on the 31,077 B binary (after 27.4).

What broke: `test-repl-multitasker-bank` and `test-repl-mailbox` were already
failing on HEAD `09b3c00` (27.1–27.4 had added 323 B; neither target is a
`test-repl` prerequisite, so nothing ran them). 27.6's +259 B broke
`test-repl-multitasker-throw`, `-semaphore` and `-multitasker-demo` the same
way: the second `TASK` raised `-8`. Fixed in 27.6 by carving every TCB before
other definitions: the four probes, and `disk/a/TRAFFIC.FTH` (`TASK CONSTANT
LIGHTS` moved to the top; the demo probe now asserts `LIGHTS` as ring index 1).
The bank probe is the tightest: its bank-1 task's code must also sit below
`$8000`, so it has 14 B to spare. Any kernel growth of more than 14 B (27.7?)
breaks it again.

Still open: the room shrinks with every kernel story. Options if it matters:
a smaller per-task data/return stack, TCBs carved from a pool outside the
dictionary, or accepting "two tasks, carved first" as the documented limit.

## 2026-10-11 (RESOLVED 2026-10-11, Story 27.6) — `>NUMBER` read ud1 with its cells swapped

`>NUMBER` stored the cell under c-addr1 as ud1-low and the one under that as
ud1-high; a double has its high cell nearer the top (§3.1.4.1). Every test
passed `0 0`, so it only showed with a nonzero ud1: `DECIMAL 1 0 S" 0"
>NUMBER 2DROP D.` printed `655360` (want `10`), and `0 0 S" 12" >NUMBER 2DROP
S" 34" >NUMBER 2DROP D.` printed `78643234` (want `1234`). Fixed by swapping
the two stores in `w_TO_NUMBER_cf` (0 B); the output pushes were already
right. Probe: `ur=`/`us=` in `tests/underflow_tests.fth`.

## 2026-10-08 (RESOLVED 2026-10-12, Story 27.7) — a word defined in one bank can hide `BANK!` from another

Found while writing the Story 27.3 probe. On the 31,009 B binary (before
27.3), under iz-cpm-banking:

```forth
BANKS-CLEAR $22 +BANK $22 +BANK $22 +BANK $22 +BANK
2 BANK!  : _by 1 ;
3 BANK!
0 BANK!        \ BANK! ?  error -13: undefined word
```

From bank 3, `BANK!` is no longer found; `' DUP` and `' BANK@` still are.
It depends on the name and the address:

| Case | `0 BANK!` from bank 3 |
|---|---|
| `_by` defined at bank 2's first `HERE` (`$8000`) | `-13` |
| `_zz` defined at the same place | works |
| `_by` defined after `$C000 HERE - 100 - ALLOT` in bank 2 | works |
| `_by` started in bank 2 but aborted by `-8`, then any `:` in bank 3 | `-13` |

Same result on real MicroBeast hardware (2026-10-08, 31,017 B binary, fresh
boot): `_by` gives `-13`, `_zz` is fine.

Not yet traced. The name dependence suggests `_by` shares `BANK!`'s hash
bucket and the bucket walk from bank 3 stops at the bank-2 entry instead of
following its link back to the kernel words; the address dependence (`$8000`
fails, `$BF9C` works) is unexplained. If the bucket reading is right, any
kernel word that shares a bucket with a word defined in another bank is exposed,
not only `BANK!`.

Second instance, found while writing the Story 27.4 probe: `_qk` defined in
bank 1 hides `CR` from banks 2 and 3, and from bank 0 after switching through
bank 3. Reproduced on the 31,017 B binary (before 27.4) and the 31,077 B
binary (after), no `?DO` involved:

```forth
BANKS-CLEAR $22 +BANK $22 +BANK $22 +BANK $22 +BANK
1 BANK! : _qk 1 ;
2 BANK!
CR             \ CR ?  error -13: undefined word
```

`_zz` in the same place is fine. This confirms that kernel words other than
`BANK!` are exposed.

Third instance, also during Story 27.4, and this one hangs instead of raising
`-13`. The +60 B of `?DO` made `test-repl-banking-23-6` hang (it has no
timeout) on its unchanged probe. Minimal repro on the 31,077 B binary:

```forth
BANKS-CLEAR $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK
0 BANK!  $C000 HERE - 3 - ALLOT
42 VALUE B0
6 BANK!  $C000 HERE - 2 - ALLOT
1 2 + . CR     \ prints 3, then CR never returns
```

| Variation (31,077 B binary) | Result |
|---|---|
| as above | hang in `CR` lookup |
| `ZZ`, `Q7`, `F0` instead of `B0` | works |
| bank 6 not driven to the brink (`6 BANK!` alone) | `CR` found |
| same input on the 31,017 B binary | works |

`CR` is the victim here as with `_qk`. The bank-0 `B0` header straddles
`$BFFD..$C000+`, so its start is in the window and only visible with bank 0
paged in. The probe word was renamed to `F0` so the 23-6 regression keeps
testing the `-8` guard; the bug itself is unchanged.

Same hang on real MicroBeast hardware (2026-10-11, 31,077 B binary): the
repro printed `3` and `CR` never returned. That run followed the 27.4 UAT
session rather than a fresh boot, with `BANKS-CLEAR` resetting the banks
first.

Resolved by Story 27.7. FIND was not at fault. Every repro used
`$22 +BANK $22 +BANK …`, and `$22` is bank 0's own slot-2 page, so every
logical bank was the same physical RAM: bank N's `$8000` was bank M's
`$8000`. `WORD` stages each token at `HERE`, so the first token parsed in
one bank overwrote the fat link of a header another bank had just built at
the same address. The bucket walk then followed a garbage link. The name
mattered because only a word in the victim's bucket sits on its chain:
`_by` and `BANK!` share bucket 1, `_qk`, `B0` and `CR` share bucket 41,
while `_zz`, `ZZ`, `Q7` and `F0` hash elsewhere. The address mattered
because only a header under the other bank's parse buffer is overwritten
(`_by` at `$8000` failed; at `$8014` or `$BF9C` it survived). Whether the
walk ended (`-13`) or looped (the hang) depended on the garbage. The same
three repros on distinct pages (`$22 $35 $36 … +BANK`) pass on the
unmodified 31,348 B binary. The hardware runs used the same setup.

The trace also found a separate defect that page aliasing doesn't explain.
A bank N > 0 could grow `HERE` to `$C000`, but `WORD` writes up to `HERE+128`
(a token is at most a TIB line) and `PAD` is `HERE+84..HERE+167`. Near the
top, both wrote into `$C000+`, which is fixed RAM, where bank 0's dictionary
continues once it grows past `$C000`. On distinct pages, a bank-0 `B0`
straddling `$C000` was lost after bank 6 at `$BFFE` parsed one long token.

Fix: `+BANK` refuses a page already in the active list (`dup?`, `-2`,
before the probe; the boot command-line parser shares the same scan,
`page_in_active_list`). Banks N > 0 now stop at `BANKED_CEILING` = `$BF58`,
which is `$C000` less `PAD_OFFSET` + `PAD_SIZE` (168). `.BANKS` shows an
empty bank as FREE 16216. Bank 0 is unchanged. Probes that repeated `$22`
now use distinct pages, the brinks moved to `$BF58`, the 27.3/27.4 probe
names went back to `B0` and `_qk`, and every bank-driving Makefile recipe
runs under `timeout`. New probe: `make test-repl-bank-lookup`. `WORD` now
throws `-18` (parsed string overflow) on a token longer than 128 characters
(`WORD_MAX_LEN`), so an `EVALUATE`d token can't run past the reserve either;
before, its copy loop had no limit. Byte cost: +47 B (31,348 → 31,395).

## 2026-10-08 (RESOLVED 2026-10-11, Story 27.6) — one-operand words don't check for underflow

Most one-operand words run on whatever is in BC when the stack is empty
instead of raising `-4`. Two-operand words call `check_underflow_2`; the
one-operand ones are inconsistent (`NEGATE` checks, `INVERT` doesn't).
Typing `DEPTH . <word> DEPTH .` on an empty stack (iz-cpm-banking, 30,830 B
binary):

| Word | Output |
|---|---|
| `0=` `0<` `1+` `1-` `2*` `2/` `INVERT` `ABS` `?DUP` `C@` `CELLS` `CELL+` `CHAR+` | `0 0  ok` — no error; the word ran on the phantom BC |
| `DUP` | `0 1  ok` — no error; a phantom cell is now on the stack |
| `NEGATE` `DROP` `@` `S>D` | `0 error -4: stack underflow` |

Affected: `0=`, `0<`, `1+`, `1-`, `2*`, `2/`, `INVERT`, `ABS`, `?DUP`, `C@`,
`CELLS`, `CELL+`, `CHAR+`, `DUP`. The new `0<>` and `0>` call
`check_underflow`, so they don't add to the list. Some of these (`0=`, `1+`,
`DUP`) are on hot paths, where a `CALL check_underflow` costs about 50
T-states per use; Story 27.6 has to weigh that.

Resolved by Story 27.6: every kernel word that takes stack items now raises
`-4` before any side effect. That is 51 words with a new `CALL
check_underflow`/`_2`/`_3` at entry (the one-operand words above plus
`TYPE`, `FILL`, `MOVE`, `EMIT`, `,`, `ALLOT`, `EXECUTE`, `?BRANCH`, `(DO)`,
`(+LOOP)`, `CONSTANT`, `ACTIVATE`, `BANK!` and others), `PICK`/`ROLL` via a
new `check_underflow_u` (needs u+2 items, so an oversized u raises too),
guards at the head of `ACCEPT`, `POST` and `SEMAPHORE`, the one-cell-short
checks in `SET-ORDER` and `RESTORE-INPUT` fixed, and the assembler's
operand-taking mnemonics. `ABS`, `TO`, `WAIT`, `LOCK`, `FETCH`, `SIGNAL`
inherit the check from their first word. Left unchecked: headerless helpers
with a fixed caller (`LC!`, `(EDIT)`, `(LINE)`, `(QUERY-FINISH)`,
`to_verify`), `COMP-ERROR`, and `TEST-BRIDGE` (test build only).

The real cost of `CALL check_underflow` is 94 T-states, not about 50: `DUP`
goes from 49 to 143 T, `1+` from 44 to 138 T. Measured on iz-cpm (Z80
cycles only, BDOS excluded): `INCLUDE` costs 9.7% more per found-word token
and 14.3% more on a file of colon definitions; typed input costs about 21%
more per token, mostly three checks per character in the line reader's key
loop, which waits on the serial line on hardware anyway. No unchecked kernel
entry points were added. Byte cost: +259 B (31,077 → 31,336).

## 2026-09-02 (RESOLVED) — `1 >R` at the prompt dropped the session to CP/M

`INTERPRET` runs each typed token with `EXECUTE` from inside its own `DOCOL`
frame, so a token that leaves the IX return stack at a different depth than it
found it overwrites `INTERPRET`'s return address. `1 >R` left the `1` on top;
at end of line `INTERPRET`'s `EXIT` popped it as the next IP and the inner
interpreter ran from address `0x0001` — straight into CP/M's warm boot, no
message, session gone. `R>` did the same by popping the frame outright.

Fixed with a return-stack balance canary in `INTERPRET`
(`(RMARK)` / `(RCHECK)`, `src/outer_interpreter.asm`): one canary cell is
pushed at entry and checked once per line at `.interp_done`, raising
`-274 THROW_RSTACK_IMBALANCE` on a mismatch instead of jumping through
garbage. The check is NET per line, not per token, because `1 >R R> .` typed
on one line is legitimate and is deliberately unbalanced in the middle. The
canary holds a one-cell `DW EXIT_CODE` thread so a bare `EXIT` typed at the
prompt still just ends the line as it always did. Regression probe:
`make test-repl-rstack-guard`. Cost: +75 B.

STILL OPEN, found while fixing this — and it is NOT a `CATCH` defect, though
it first looked like one. A colon body that is return-stack-unbalanced at its
own `EXIT` pops the stray cell as its return address: `: X 1 >R ;` then `X`
jumps through address `0x0001` and the session is gone, exactly as the
interpreter case did. It hangs identically with no `CATCH` anywhere near it.
`CATCH` itself is fine — `catch_resume_cf` re-anchors IX from `CATCH-TOP`
rather than trusting the incoming IX, so an unbalanced CODE word under `CATCH`
(`1 ' >R CATCH .`) returns 0 cleanly.

DECIDED 2026-09-02 (project lead): leave it. Per ANS Forth 1994 §3.2.3.3 an
unbalanced colon body is undefined, and gforth / SwiftForth / F83 all fail the
same way. The only place a guard could live is `EXIT_CODE`, taken on every
colon return, so the fix is a permanent tax on the hottest path in the system
to catch a programmer error the standard already calls undefined.

The option costed and rejected, recorded so it need not be re-derived: reject a
popped IP below `$0100` (`LD A,D` / `CP 1` / `JR C`) and raise -274 instead of
jumping into CP/M's warm boot. 11 bytes; +18 T-states on `EXIT_CODE`'s ~96,
roughly 2% overall once amortised across the other NEXT dispatches. It cannot
false-positive — every legitimate return address is a thread cell at `$0100` or
above — but it only catches strays below `$0100`, so `1000 >R` still gets
through. Partial cover for a permanent cost was judged the wrong trade.

The REPL surface — the one a user actually hits — is covered by the -274 guard
above. This entry is about the deeper case only.

## 2025-xx-xx (RESOLVED 2026-06-28, Story 23.4)

`UD.` now prints an unsigned double in the current `BASE` with a trailing space
and no sign (`4294967295. UD.` → `4294967295`, vs `D.` → `-1`). It is the `D.`
thread with the sign machinery (`DABS`/`SIGN`) removed; non-ANS (common-practice
extension, documented in `docs/ans-forth-core-compliance.md` — the epic's
§8.6.1.1230 citation is `DNEGATE`'s number, not `UD.`).

Six new `ENVIRONMENT?` wordset-presence rows were added, answering honestly:
`EXCEPTION` / `EXCEPTION-EXT` / `SEARCH-ORDER` → `( true true )` (fully present);
`DOUBLE` / `DOUBLE-EXT` / `SEARCH-ORDER-EXT` → `( false true )` —
recognised-but-not-fully-implemented (consistent with the existing `CORE-EXT`
precedent), pending full implementation of those wordsets (`D0< D0= D2* D2/
2CONSTANT 2LITERAL 2VARIABLE`; `2ROT 2VALUE DU<`; `ALSO FORTH ORDER PREVIOUS`)
in a future story/epic — out of 23.4 scope.

## 2025-05-20 (RESOLVED 2026-06-28, Story 23.1)

OUT and IN didn't follow the Zilog `<dst> <src>` convention for operand order.
Now fixed: `(C) A OUT,` = `OUT (C),A`, `$74 # A OUT,` = `OUT (n),A`,
`A (C) IN,` = `IN A,(C)`, `A $74 # IN,` = `IN A,(n)` — consistent with every
other mnemonic (`B C LD,` = `LD B,C`). The old src-dst order no longer
assembles.

