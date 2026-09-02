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

STILL OPEN, found while fixing this: `CATCH` assumes its `xt` is
return-stack-neutral — its success path pops the 10-byte frame relative to the
current IX. `' X CATCH` where `X` is unbalanced (e.g. `: X 1 >R ;`) therefore
resumes through a bad address and hangs. This predates the fix above and is
unchanged by it; the interpreter guard cannot see inside `CATCH`.

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

