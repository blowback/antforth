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

## 2026-10-08 (OPEN) — a word defined in one bank can hide `BANK!` from another

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

## 2026-10-08 (OPEN, Story 27.6) — one-operand words don't check for underflow

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

