\ wordlist_tests.fth — Story 12.1 — FORTH-WORDLIST regression smoke
\ AntForth — A Forth for CP/M on Z80
\
\ Verifies that the kernel-resident FORTH-WORDLIST struct is wired
\ correctly through the regression net: define a word, FIND it, execute
\ it, MARKER-roll it back, and re-confirm it is gone. Per Story 12.1
\ AC #7, FORTH-WORDLIST is not yet a Forth word (lands in Story 12.3),
\ so coverage is by-construction — there is only one wordlist, so any
\ word defined via `:` lands in FORTH-WORDLIST and any FIND walks
\ FORTH-WORDLIST's bucket array.
\
\ Each line is sent to the REPL with the expected stdout fragment in a
\ trailing `\ expect: <fragment>` comment. The Makefile `test-repl`
\ entries (tests 802..) are the authoritative runners — keep these in
\ sync.

\ ============================================================
\ Section 1 — Define + lookup + execute (regression sentinel)
\ ============================================================

\ T1 — `:` lands in FORTH-WORDLIST; TWFOO is then findable & executable.
: TWFOO 42 ; TWFOO .                    \ Makefile test 802 asserts: output contains "42 "

\ ============================================================
\ Section 2 — MARKER round-trip (snapshot/restore via FORTH-WORDLIST)
\ ============================================================

\ T2 — define MARKER, define a word, run it, MARKER it away. After
\ TWMK rolls back, referencing TWBAR raises -13 at REPL parse time
\ (the REPL prints "TWBAR ?" + "error -13: undefined word") and the
\ REPL continues running.
MARKER TWMK : TWBAR 99 ; TWBAR . TWMK   \ Makefile test 803 sequence (line 1 of 3):
TWBAR                                   \ Makefile test 803 sequence (line 2 of 3):
1 2 + .                                 \ Makefile test 803 sequence (line 3 of 3):
\ Makefile test 803 asserts: output contains all of "99 ", "TWBAR ?",
\ "error -13: undefined word", and "3 " (REPL recovery).
\
\ NOTE: a `: TWGHOST ['] TWBAR ;` form was considered for compile-time
\ verification but rejected — `[']` would resolve TWBAR at compile time
\ (after MARKER it is gone, so this raises -13 mid-compile and leaves
\ the dictionary smudged). Test 803 asserts the runtime path instead.

\ ============================================================
\ Section 3 — WORDS smoke (FORTH-WORDLIST bucket-array walk)
\ ============================================================

\ T3 — WORDS runs without crash and lists kernel primitives.
WORDS                                   \ Makefile test 804 sequence (line 1 of 2):
1 2 + .                                 \ Makefile test 804 sequence (line 2 of 2):
\ Makefile test 804 asserts: output contains "DUP" (a kernel primitive
\ proves the bucket walk reached at least one populated bucket) and
\ "3 " (REPL recovery proves the walk terminated cleanly).

\ ============================================================
\ Section 4 — Pre-Epic-12 regression sentinel
\ ============================================================

\ T4 — a representative one-liner that exercises FIND/compile/execute
\ end-to-end via the FORTH-WORDLIST bucket array. Comparison `=` returns
\ -1 (true) on equality; `.` prints "-1 ".
1 2 + 3 = .                             \ Makefile test 805 asserts: output contains "-1 "

\ ============================================================
\ Section 5 — FIND of a kernel word returns valid xt + -1 flag
\ ============================================================

\ T5 — FIND of a kernel word returns flag = -1 for non-IMMEDIATE.
\ BL WORD MARKER parses "MARKER" as a counted string at HERE; FIND
\ walks FORTH-WORDLIST's bucket array and returns ( xt -1 ) for a
\ non-IMMEDIATE match.
BL WORD MARKER FIND SWAP DROP .         \ Makefile test 806 asserts: output contains "-1 "

\ ============================================================
\ Section 6 — Story 12.2 — WORDLIST + SEARCH-WORDLIST
\ ============================================================

\ T-WL1 — WORDLIST advances HERE by exactly 130 bytes.
\
\ NOTE: Story 12.2 AC #8 sketched `HERE WORDLIST OVER OVER SWAP - .`
\ but that prints 0 — wid equals the pre-WORDLIST HERE (the struct's
\ base address per E12-D3 / AC #1), so the difference is zero. Use
\ the post-call HERE instead to prove the +130 advance. (In-pass-fix
\ per Task 6; AC #11(e) HERE-advance probe.)
HERE WORDLIST DROP HERE SWAP - .        \ Makefile test 807 asserts: output contains "130 "

\ T-WL2 — fresh wid's next-link cell and first bucket are both zero.
\ Probes WORDLIST's full zero-init via the two boundary cells of the
\ struct: WORDLIST_NEXT (offset 0) and WORDLIST_BUCKET0 (offset 2).
WORDLIST DUP @ . DUP 2 + @ . DROP       \ Makefile test 808 asserts: output contains "0 0 "

\ T-SW1 — SEARCH-WORDLIST against an empty wordlist returns single 0.
\ Verifies the (depth 3 -> depth 1) stack-shrink on miss per AC #11(a).
\ DEPTH after the `.` (which prints the 0 flag) must be 0 — proves no
\ residual c-addr/u was left on the stack.
WORDLIST CONSTANT WL1   S" DUP" WL1 SEARCH-WORDLIST .   DEPTH .
\ Makefile test 809 asserts: output contains "0 0 " (the miss flag,
\ then DEPTH=0 confirming clean shrink).

\ T-SW2 — length > F_LENMASK (33 chars). Per AC #11(b) pick (ii) the
\ length is passed unchanged; the chain compare rejects every entry
\ whose stored length-mask doesn't match → pure miss; no crash.
WORDLIST   S" XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" ROT SEARCH-WORDLIST .
\ Makefile test 810 asserts: output contains "0 ".

\ T-SW3 — zero-length name. hash_name returns bucket 0; bucket walk
\ on an empty wordlist sees a 0 head and returns miss immediately.
\ Per AC #11(c).
WORDLIST   S" " ROT SEARCH-WORDLIST .   \ Makefile test 811 asserts: output contains "0 "

\ T-SW4 — pre-Story-12.1 regression sentinel re-asserted. FIND walks
\ the same shared helper (search_wid_for_name, post-Story-12.2) so a
\ trailing FIND probe re-confirms the helper-extract refactor is
\ regression-clean — `BL WORD DUP FIND SWAP DROP .` should still
\ print -1 for the kernel DUP word.
BL WORD DUP FIND SWAP DROP .            \ Makefile test 812 asserts: output contains "-1 "

\ ============================================================
\ Section 7 — Story 12.3 — search-order infrastructure
\ ============================================================
\ Coverage of FORTH-WORDLIST, GET-ORDER, SET-ORDER, and the rewritten
\ FIND search-order walk per Story 12.3 AC #15. Tests 815/816/817 close
\ Story 12.2 review CR-L3 / CR-L4 (direct SEARCH-WORDLIST hit-path probe
\ + FIND/SEARCH-WORDLIST IMMEDIATE-flag probes).

\ T-GO1 — initial GET-ORDER state: depth=1, slot 0 = FORTH-WORDLIST.
GET-ORDER 1 = SWAP FORTH-WORDLIST = AND .   \ Makefile test 813 asserts: output contains "-1  ok"

\ T-FW1 — FORTH-WORDLIST self-consistency: pushed twice, both copies equal.
FORTH-WORDLIST FORTH-WORDLIST = .       \ Makefile test 814 asserts: output contains "-1  ok"

\ T-FW2 — FORTH-WORDLIST drives the canonical kernel wordlist (CR-L3
\ from Story 12.2 review): SEARCH-WORDLIST hit on a kernel word DUP
\ returns ( xt -1 ); SWAP DROP keeps the flag; `.` prints -1 (non-
\ IMMEDIATE). Proves SEARCH-WORDLIST hit path against the canonical
\ wordlist for the first time. (Story spec sketch had `DROP DROP DUP`
\ which empties the stack and DUPs stale BC — corrected here to
\ `SWAP DROP` per the flag-extraction pattern used in T-FW3a/b.)
S" DUP" FORTH-WORDLIST SEARCH-WORDLIST SWAP DROP .  \ Makefile test 815 asserts: output contains "-1  ok"

\ T-FW3a — FIND IMMEDIATE-flag probe (CR-L4 from Story 12.2 review):
\ IF is IMMEDIATE; FIND returns flag = 1.
BL WORD IF FIND SWAP DROP .             \ Makefile test 816 asserts: output contains "1  ok"

\ T-FW3b — SEARCH-WORDLIST IMMEDIATE-flag probe (CR-L4 from Story 12.2
\ review): IF via SEARCH-WORDLIST against FORTH-WORDLIST returns flag = 1.
S" IF" FORTH-WORDLIST SEARCH-WORDLIST SWAP DROP .   \ Makefile test 817 asserts: output contains "1  ok"

\ T-SO1 — SET-ORDER round-trip preserves state.
GET-ORDER SET-ORDER GET-ORDER 1 = SWAP FORTH-WORDLIST = AND .   \ Makefile test 818 asserts: output contains "-1  ok"

\ T-SO2 — SET-ORDER -1 minimum reset. After installing depth=2 with
\ FORTH-WORDLIST at slot 0 (top-of-search-order — the wid pushed last
\ before n goes to slot 0 per ANS direction) + a custom wordlist at
\ slot 1 (FORTH-WORDLIST kept in slot 0 so `-1 SET-ORDER` itself stays
\ findable), `-1 SET-ORDER` resets to the canonical depth=1 /
\ FORTH-WORDLIST minimum.
WORDLIST FORTH-WORDLIST 2 SET-ORDER -1 SET-ORDER GET-ORDER 1 = SWAP FORTH-WORDLIST = AND .  \ Makefile test 819 asserts: output contains "-1  ok"

\ T-SO3 — SET-ORDER depth-overflow raises -49. Pushes 17 cells then
\ asks for depth = 17. The REPL prints "error -49: search-order
\ overflow"; subsequent `1 2 + .` confirms recovery.
0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 SET-ORDER   \ Makefile test 820 sequence (line 1 of 2)
1 2 + .                                 \ Makefile test 820 sequence (line 2 of 2)
\ Makefile test 820 asserts: output contains "error -49: search-order overflow" AND "3  ok".

\ T-SO5 — depth-2 search-order walk: FIND must walk PAST an empty
\ slot 0 to find TWFOO in slot 1. ANS direction: the wid pushed
\ LAST before n goes to slot 0, so `FORTH-WORDLIST WORDLIST 2
\ SET-ORDER` puts the (empty) custom wordlist in slot 0 and
\ FORTH-WORDLIST in slot 1. : TWFOO 99 ; lands in FORTH-WORDLIST
\ (Story 12.4 SET-CURRENT not yet wired); FIND walks slot 0 (custom,
\ empty — miss) → slot 1 (FORTH-WORDLIST — hits TWFOO). This is
\ the genuine multi-slot walk probe; the prior shape
\ `WORDLIST FORTH-WORDLIST 2 SET-ORDER` placed FORTH-WORDLIST in
\ slot 0 and never iterated past the first slot. Restores depth-1
\ minimum order at the end so subsequent tests are unaffected.
FORTH-WORDLIST WORDLIST 2 SET-ORDER : TWFOO 99 ; TWFOO . -1 SET-ORDER    \ Makefile test 821 asserts: output contains "99 "

\ T-FIND-REGRESSION — pre-Story-12.3 sentinel via the new search-order
\ walk: 1 2 + . prints "3 " (FIND of `+` and `.` via depth-1 walk),
\ : TWBAZ 7 ; TWBAZ . prints "7 " (compile + execute via the new walk).
1 2 + . : TWBAZ 7 ; TWBAZ .             \ Makefile test 822 asserts: output contains "3 " AND "7 "
