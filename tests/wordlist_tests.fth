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
