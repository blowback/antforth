# Things we're missing, discovered during the course of development

(It's not for features or big ticket items, but for gaps).

 - `UD.` - display unsigned double precision int — RESOLVED 2026-06-28, Story 23.4
 - "EXCEPTION" and "EXCEPTION-EXT" environment queries — RESOLVED 2026-06-28, Story 23.4
 - "DOUBLE" and "DOUBLE-EXT" environment queries — RESOLVED 2026-06-28, Story 23.4
 - "SEARCH-ORDER" and "SEARCH-ORDER-EXT" environment queries — RESOLVED 2026-06-28, Story 23.4

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
