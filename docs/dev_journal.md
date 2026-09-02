# Things we're missing, discovered during the course of development

(It's not for features or big ticket items, but for gaps).

 - `UD.` - display unsigned double precision int — RESOLVED 2026-06-28, Story 23.4
 - "EXCEPTION" and "EXCEPTION-EXT" environment queries — RESOLVED 2026-06-28, Story 23.4
 - "DOUBLE" and "DOUBLE-EXT" environment queries — RESOLVED 2026-06-28, Story 23.4
 - "SEARCH-ORDER" and "SEARCH-ORDER-EXT" environment queries — RESOLVED 2026-06-28, Story 23.4
 - `-ROT`
 - ?
 - "MBB-VERSION" and "MBB-PLATFORM" environment queries, returning the firmware version 
   and platform (1 for MicroBeast, 2 for NanoBeast) respectively.
 - make startup banner say "MicroBeast" or "NanoBeast" depending on MBB-PLATFORM.
 - "ANTFORTH" environment query that returns AntForth version
 - TRUE/FALSE words that evaluate to -1 and 0 respectively
 - <=, >=, <> 
 - 0>, 0<>
 - .(  (immediate print)
 - 2>R, 2R>
 - :NONAME 
 - ?DO 
 - AGAIN 
 - DEFER, DEFER!, DEFER@, IS
 - NIP, TUCK 
 - U.R, U>
 - random number facility: fast xorshift is fine: seed, rnd ( n -- ), random ( n -- 0..n-1 )

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

