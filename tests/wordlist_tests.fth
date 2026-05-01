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

\ ============================================================
\ Section 8 — Story 12.4 — compilation wordlist control
\ ============================================================
\ Coverage of GET-CURRENT, SET-CURRENT, DEFINITIONS, and the
\ build_header parameterisation per Story 12.4 AC #14. Tests
\ 823..836 (14 tests).

\ T-GC1 — initial GET-CURRENT state: current = FORTH-WORDLIST at boot.
GET-CURRENT FORTH-WORDLIST = .          \ Makefile test 823 asserts: output contains "-1  ok"

\ T-SC1 — SET-CURRENT round-trip: WORDLIST pushes a wid; SET-CURRENT
\ stores it; GET-CURRENT returns the same wid. Reset to FORTH-WORDLIST.
WORDLIST DUP SET-CURRENT GET-CURRENT = .   FORTH-WORDLIST SET-CURRENT
\ Makefile test 824 asserts: output contains "-1  ok"

\ T-SC2a — `:` lands in the current wordlist (negative — NOT in FORTH-WORDLIST).
\ Define WL1, switch to it, define SC2FOO, switch back, prove FORTH-WORDLIST
\ does NOT have SC2FOO via SEARCH-WORDLIST miss flag = 0.
WORDLIST CONSTANT WL1   WL1 SET-CURRENT   : SC2FOO 77 ;   FORTH-WORDLIST SET-CURRENT
S" SC2FOO" FORTH-WORDLIST SEARCH-WORDLIST .
\ Makefile test 825 asserts: output contains "0  ok"

\ T-SC2b — `:` lands in the current wordlist (positive — IS in WL1).
\ SEARCH-WORDLIST hit on SC2FOO via WL1 returns ( xt -1 ); SWAP DROP keeps
\ the flag; `.` prints -1.
S" SC2FOO" WL1 SEARCH-WORDLIST SWAP DROP .
\ Makefile test 826 asserts: output contains "-1  ok"

\ T-SC3a — SET-CURRENT does NOT change search order: define SC3BAR in
\ a new wordlist; SC3BAR is unfindable from the search order (only
\ FORTH-WORDLIST is searched), so we get error -13.
WORDLIST CONSTANT WL2   WL2 SET-CURRENT   : SC3BAR 33 ;   FORTH-WORDLIST SET-CURRENT
SC3BAR
\ Makefile test 827 asserts: output contains "SC3BAR ?" AND "error -13: undefined word"

\ T-SC3b — SET-CURRENT does NOT change search order (positive): adding
\ WL2 to the search order makes SC3BAR findable. After execute, restore.
WL2 1 SET-ORDER   SC3BAR .   -1 SET-ORDER
\ Makefile test 828 asserts: output contains "33 "

\ T-DEF1 — DEFINITIONS sets current to slot 0 of search order. Install
\ depth-2 order [WL3, FORTH-WORDLIST] (slot 0 = WL3 for DEFINITIONS, slot
\ 1 = FORTH-WORDLIST so kernel words remain findable), then DEFINITIONS,
\ then verify GET-CURRENT = WL3. Reset minimum order + FORTH-WORDLIST
\ current afterwards.
WORDLIST CONSTANT WL3   FORTH-WORDLIST WL3 2 SET-ORDER   DEFINITIONS   GET-CURRENT WL3 = .
-1 SET-ORDER   FORTH-WORDLIST SET-CURRENT
\ Makefile test 829 asserts: output contains "-1  ok"

\ T-DEF2 — DEFINITIONS-driven partition with depth=2 search order.
\ Install [WL4, FORTH-WORDLIST] (slot 0 = WL4), DEFINITIONS makes WL4
\ current; define DEF2BAZ; reset; prove DEF2BAZ is NOT in FORTH-WORDLIST.
WORDLIST CONSTANT WL4   FORTH-WORDLIST WL4 2 SET-ORDER   DEFINITIONS   : DEF2BAZ 88 ;
-1 SET-ORDER   FORTH-WORDLIST SET-CURRENT
S" DEF2BAZ" FORTH-WORDLIST SEARCH-WORDLIST .
\ Makefile test 830 asserts: output contains "0  ok"

\ T-CCV-CREATE — CREATE in custom wordlist (negative — not in FORTH-WORDLIST).
WORDLIST CONSTANT WL5C   WL5C SET-CURRENT   CREATE CR5A   FORTH-WORDLIST SET-CURRENT
S" CR5A" FORTH-WORDLIST SEARCH-WORDLIST .
\ Makefile test 831 asserts: output contains "0  ok"

\ T-CCV-CONSTANT — CONSTANT in custom wordlist (negative).
WORDLIST CONSTANT WL5K   WL5K SET-CURRENT   42 CONSTANT CO5B   FORTH-WORDLIST SET-CURRENT
S" CO5B" FORTH-WORDLIST SEARCH-WORDLIST .
\ Makefile test 832 asserts: output contains "0  ok"

\ T-CCV-VARIABLE — VARIABLE in custom wordlist (negative).
WORDLIST CONSTANT WL5V   WL5V SET-CURRENT   VARIABLE VA5C   FORTH-WORDLIST SET-CURRENT
S" VA5C" FORTH-WORDLIST SEARCH-WORDLIST .
\ Makefile test 833 asserts: output contains "0  ok"

\ T-CCV-MARKER — MARKER in custom wordlist (negative). MARKER's header
\ lands in WL5M (per AC #5); the snapshot/restore body still reads
\ FORTH-WORDLIST (per AC #8 pick (a) limitation, documented).
WORDLIST CONSTANT WL5M   WL5M SET-CURRENT   MARKER MK5D   FORTH-WORDLIST SET-CURRENT
S" MK5D" FORTH-WORDLIST SEARCH-WORDLIST .
\ Makefile test 834 asserts: output contains "0  ok"

\ T-COMP-ERROR — error-recovery rolls back the wordlist that was current
\ at colon time, not FORTH-WORDLIST. Define WL6, switch to it, attempt
\ `: CE6FOO BOGUSWORD ;` — BOGUSWORD raises -13; the partial CE6FOO header
\ must be rolled back from WL6 (not FORTH-WORDLIST). REPL recovers.
WORDLIST CONSTANT WL6   WL6 SET-CURRENT   : CE6FOO BOGUSWORD ;
FORTH-WORDLIST SET-CURRENT   1 2 + .
S" CE6FOO" WL6 SEARCH-WORDLIST .
\ Makefile test 835 asserts: output contains "BOGUSWORD ?", "error -13: undefined word",
\ "3  ok" (REPL recovery), AND "0  ok" (CE6FOO rolled back from WL6).

\ T-DEF-DEPTH0 — DEFINITIONS with depth=0 (AC #4 pick (a) edge case):
\ DEFINITIONS reads slot 0 unconditionally regardless of depth. SET-ORDER
\ 0 only updates the depth field — it does NOT zero slot 0. At boot,
\ slot 0 = FORTH-WORDLIST (cold-start init step 8d), so `0 SET-ORDER
\ DEFINITIONS` yields current = FORTH-WORDLIST (the cached slot-0 value).
\ Wrap the depth-0 dance in a colon definition so its compiled body can
\ reach DEFINITIONS / GET-CURRENT / SET-ORDER / SET-CURRENT before
\ parsing returns to the REPL with an empty search order.
: T836 0 SET-ORDER DEFINITIONS GET-CURRENT FORTH-WORDLIST 1 SET-ORDER FORTH-WORDLIST SET-CURRENT ;
T836 FORTH-WORDLIST = .
: TWREC 9 ; TWREC .
\ Makefile test 836 asserts: output contains "-1  ok" AND "9 ".

\ T-MARKER-XWID-EXEC — MARKER from foreign wid does not corrupt
\ FORTH-WORDLIST when executed (Story 12.4 review H1). hash("MX") = 5.
\ FORTH-WORDLIST.buckets[5] lives at FORTH-WORDLIST + WORDLIST_BUCKET0
\ + 5*2 = FORTH-WORDLIST + 12. Capture pre-MX value, allocate XLM
\ (lands in bucket 41, not 5), define MARKER MX in XLM, switch back to
\ FORTH-WORDLIST, execute MX. With the H1 fix, the snapshot's bucket-5
\ fixup is skipped (because bh_wid != forth_wordlist), so DOMARKER
\ restores bucket 5 to its pre-MX value. Without the fix, the fixup
\ would overwrite snapshot[5] with XLM's old bucket-5 head (= 0 for a
\ fresh wordlist), and DOMARKER would zero out FORTH-WORDLIST.buckets[5]
\ — silently dropping every kernel word in that bucket.
FORTH-WORDLIST 12 + @
WORDLIST CONSTANT XLM   XLM SET-CURRENT   MARKER MX
FORTH-WORDLIST XLM 2 SET-ORDER          \ make MX findable for execution
MX
-1 SET-ORDER   FORTH-WORDLIST SET-CURRENT
FORTH-WORDLIST 12 + @ = .
\ Makefile test 837 asserts: output contains "-1  ok"

\ ============================================================
\ Section 9 — Story 12.5 — ONLY (Search-Order Extension)
\ ============================================================
\ Coverage of ONLY (ANS §16.6.2.1965). ONLY sets the search order to
\ the implementation-defined minimum (slot 0 = FORTH-WORDLIST, depth=1)
\ — matching the SET-ORDER -1 path. Tests 838..843 (6 tests).

\ T-ONLY-FROM-DEFAULT (test 838) — ONLY from boot state. The boot state
\ already IS the minimum search order, so ONLY is idempotent on it.
ONLY GET-ORDER 1 = SWAP FORTH-WORDLIST = AND .   \ Makefile test 838 asserts: output contains "-1  ok"

\ T-ONLY-FROM-5 (test 839) — ONLY from a 5-wordlist state. Push
\ FORTH-WORDLIST WLD WLC WLB WLA so SET-ORDER pops WLA → slot 0 (foreign);
\ then ONLY shrinks depth to 1 with FORTH-WORDLIST at slot 0.
WORDLIST CONSTANT WLA   WORDLIST CONSTANT WLB   WORDLIST CONSTANT WLC   WORDLIST CONSTANT WLD
FORTH-WORDLIST WLD WLC WLB WLA 5 SET-ORDER
ONLY GET-ORDER 1 = SWAP FORTH-WORDLIST = AND .   \ Makefile test 839 asserts: output contains "-1  ok"

\ T-ONLY-FROM-0 (test 840) — ONLY from a degenerate empty search order.
\ 0 SET-ORDER zeroes depth without zeroing slot 0 (per Story 12.4
\ DEFINITIONS depth=0 cache analysis); ONLY restores depth=1 + slot 0.
\ Wrap the depth-0 dance in a colon definition (mirroring test 836's
\ T-DEF-DEPTH0 fix): a depth-0 search order is unparseable at the REPL
\ because ONLY itself becomes unfindable via FIND. Compiling the body
\ resolves ONLY at compile time (xt cached in the thread) so execute-
\ time depth-0 doesn't matter.
: T840 0 SET-ORDER ONLY GET-ORDER 1 = SWAP FORTH-WORDLIST = AND ;
T840 .                                   \ Makefile test 840 asserts: output contains "-1  ok"

\ T-ONLY-IDEMPOTENT (test 841) — ONLY ONLY = ONLY. Build a non-trivial
\ search order [WLI, FORTH-WORDLIST] (slot 0 = WLI, foreign); call
\ ONLY twice; assert post-state is the canonical minimum.
WORDLIST CONSTANT WLI   FORTH-WORDLIST WLI 2 SET-ORDER
ONLY ONLY GET-ORDER 1 = SWAP FORTH-WORDLIST = AND .   \ Makefile test 841 asserts: output contains "-1  ok"

\ T-ONLY-PRESERVES-CURRENT (test 842) — ONLY does NOT touch
\ current_wordlist. WLO SET-CURRENT, ONLY, GET-CURRENT → still WLO.
\ Reset compilation wordlist to FORTH-WORDLIST for downstream tests.
WORDLIST CONSTANT WLO   WLO SET-CURRENT   ONLY   GET-CURRENT WLO = .   FORTH-WORDLIST SET-CURRENT
\ Makefile test 842 asserts: output contains "-1  ok"

\ T-ONLY-TOS-PRESERVES (test 843) — ONLY's stack effect ( -- ) means BC
\ (TOS) is preserved bit-exactly. Push 42, call ONLY, print 42. The
\ Makefile assertion anchors on '42  ok' (two spaces — `.`'s trailing
\ space + REPL's leading-space `ok`) so the iz-cpm input echo (which
\ contains "42 ONLY .") cannot satisfy the pattern; only `.` printing
\ 42 followed by the REPL prompt produces that substring.
42 ONLY .                                \ Makefile test 843 asserts: output contains "42  ok"

\ ============================================================
\ Section 10 — Story 12.6 Epic-12 closure suite (CCD-4 gate)
\ ============================================================
\ Tests 844..849 — Epic-12 close-out probes for the CCD-4 gate.
\ Audit-only story — these tests verify the surface Stories 12.1..12.5
\ delivered, exercising the worst-case shapes the per-story tests did
\ not directly hit. All tests reset state with ONLY at the end.

\ T-CCD4-DEPTH16 (test 844) — SET-ORDER ceiling = 16 (E12-D2 §332-336).
\ Push 16× FORTH-WORDLIST, SET-ORDER 16, GET-ORDER returns depth=16
\ + 16 wids. DUP 16 = . prints "-1". 16-cell drop + ONLY cleans up.
\ Wraps in colon defn so DO/LOOP (compile-only) is permitted.
: T844 16 0 DO FORTH-WORDLIST LOOP 16 SET-ORDER GET-ORDER DUP 16 = . 0 DO DROP LOOP ONLY ;
T844                                     \ Makefile test 844 asserts: output contains "-1  ok"

\ T-CCD4-MULTI-DEEP (test 845) — 5-slot search-order walk past 4 empties
\ to a deep-slot hit. M845 lives in WLE (slot 4). FORTH-WORDLIST sits at
\ slot 0 so the surrounding ., SET-ORDER, ONLY tokens still resolve.
WORDLIST CONSTANT WLA  WORDLIST CONSTANT WLB  WORDLIST CONSTANT WLC  WORDLIST CONSTANT WLE
WLE SET-CURRENT  : M845 845 ;  FORTH-WORDLIST SET-CURRENT
WLE WLA WLB WLC FORTH-WORDLIST 5 SET-ORDER  M845 .  ONLY
\ Makefile test 845 asserts: output contains "845  ok"

\ T-CCD4-FR31-CODE (test 846) — CODE assembly post-Epic-12 produces a
\ runnable definition; FR31 functional probe (the byte-identical gate is
\ verified analytically in Story 12.6 Task 3 against a pre-Epic-12 build).
CODE T846 BC PUSH, BC 846 # LD, NEXT, END-CODE  T846 .   \ test 846 asserts: "846  ok"

\ T-CCD4-IX-PRESERVE (test 847) — Story 11.4.1 i*x preservation across the
\ multi-vocab FIND walk. 1 2 3 ' ABORT CATCH . . . . — CATCH executes
\ ABORT (THROWs -1), restores i*x cells, returns -1 on TOS. Four `.`s
\ print "-1 3 2 1 ".
1 2 3 ' ABORT CATCH . . . .              \ Makefile test 847 asserts: output contains "3 2 1  ok"

\ T-CCD4-MARKER-MULTI-VOCAB (test 848) — Epic-12 closure cross-product.
\ MARKER + WORDLIST + SET-CURRENT + SET-ORDER + ONLY composed in one
\ flow. M848 marker placed, WL848 wordlist created, XX848 defined inside
\ WL848, search order set to [WL848, FORTH-WORDLIST]. XX848 . prints 848.
\ M848 rolls back (per Story 12.4 H1 fix walks per-wordlist hash table
\ without corrupting FORTH-WORDLIST). ONLY resets order.
MARKER M848  WORDLIST CONSTANT WL848  WL848 SET-CURRENT  : XX848 848 ;  FORTH-WORDLIST SET-CURRENT
FORTH-WORDLIST WL848 2 SET-ORDER  XX848 .  M848  ONLY
\ Makefile test 848 asserts: output contains "848  ok"

\ T-CCD4-WL-CHAIN (test 849) — Compose GET-CURRENT + SEARCH-WORDLIST +
\ EXECUTE in a single flow. Confirms GET-CURRENT is independent of the
\ search order, and SEARCH-WORDLIST returns a runnable xt.
WORDLIST CONSTANT WL849  WL849 SET-CURRENT  : M849 849 ;  FORTH-WORDLIST SET-CURRENT
GET-CURRENT FORTH-WORDLIST = .  S" M849" WL849 SEARCH-WORDLIST DROP EXECUTE .
\ Makefile test 849 asserts: output contains "-1 " AND "849 "
ONLY

\ ============================================================
\ Section 10b — Adversarial-review follow-up tests (L9 / L10 / L11)
\ ============================================================
\ Added by review pass to close coverage gaps:
\   850 — explicit multi-vocab miss-fallthrough (L9)
\   851 — depth-16 round-trip with DISTINCT wordlists (L10)
\   852 — MARKER rollback effect actually verified (L11)

\ T-CCD4-MULTI-MISS (test 850) — Probe FIND walking a 4-slot search order
\ where every slot is empty. Builds a counted string "NOPE850" at HERE,
\ sets order to 4 empty wordlists, calls FIND directly. FIND walks all
\ 4 slots, finds nothing in any bucket array, returns ( c-addr 0 ). NIP
\ drops c-addr; '.' prints 0. Wrapped in a colon defn so every token
\ compiles against the default search order — at execution time the
\ SET-ORDER reconfigure does not break the body's pre-resolved xt's.
\ Closes Finding L9 (no explicit multi-vocab miss-fallthrough probe).
HERE  7 C,  78 C, 79 C, 80 C, 69 C, 56 C, 53 C, 48 C,  CONSTANT NAMEBUF
WORDLIST CONSTANT WL850A  WORDLIST CONSTANT WL850B  WORDLIST CONSTANT WL850C  WORDLIST CONSTANT WL850D
: T850 WL850A WL850B WL850C WL850D 4 SET-ORDER  NAMEBUF FIND SWAP DROP .  ONLY ;
T850                                     \ Makefile test 850 asserts: "0  ok"

\ T-CCD4-DEPTH16-DISTINCT (test 851) — 16 DISTINCT wordlists at the
\ SET-ORDER ceiling, verifying slot-0 wid distinguishability across a
\ depth=16 round-trip. Uses 16 anonymous WORDLIST allocations inside a
\ colon defn (DUP+>R captures wid1 = the will-be-slot-0 wid before
\ SET-ORDER consumes it; GET-ORDER round-trips, drops n, compares the
\ top-of-stack wid against the saved one). 16 × 130 = 2080 bytes from
\ HERE (well within ~44 KB free).
: T851
  WORDLIST WORDLIST WORDLIST WORDLIST WORDLIST WORDLIST WORDLIST WORDLIST
  WORDLIST WORDLIST WORDLIST WORDLIST WORDLIST WORDLIST WORDLIST WORDLIST
  DUP >R 16 SET-ORDER GET-ORDER DROP R> = .
  15 0 DO DROP LOOP ONLY ;
T851                                     \ Makefile test 851 asserts: "-1  ok"

\ T-CCD4-MARKER-ROLLBACK-EFFECT (test 852) — Actually verify that home-
\ MARKER rollback removes a definition created after the MARKER. M852 is
\ a home marker (CURRENT = FORTH-WORDLIST at MARKER time). Define X852
\ (lands in FORTH-WORDLIST), exec it pre-rollback (prints 852), fire
\ M852, then SEARCH-WORDLIST X852 in FORTH-WORDLIST should return 0
\ (X852's bucket entry rolled back). Closes the L11 coverage gap that
\ test 848 left open (test 848 asserts on a value printed BEFORE MARKER
\ fires; this test asserts on the post-rollback FIND result).
MARKER M852  : X852 852 ;
S" X852" FORTH-WORDLIST SEARCH-WORDLIST DROP EXECUTE .   \ pre-print "852 "
M852
S" X852" FORTH-WORDLIST SEARCH-WORDLIST .                \ Makefile test 852 asserts: "0  ok"
ONLY
