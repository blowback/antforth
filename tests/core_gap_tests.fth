\ core_gap_tests.fth — Epic 10 Story 10.8 number-output regression tests
\ AntForth — A Forth for CP/M on Z80
\
\ Covers the six display words post-rewrite on pictured-output foundation:
\   .   (§6.1.0180)  U.  (§6.1.2320)  D.  (§8.6.1060)
\   .R  (§6.2.0210)  U.R (§6.2.2330)  D.R (§8.6.1070)
\
\ Stack-order note: E10-D1 puts the LOW cell on TOS. For doubles, typing
\   "hi lo" leaves (hi under, lo TOS) — so "-1 -1" = signed double -1,
\   and "32768 0" = double $80000000 = INT_MIN (-2147483648).
\
\ Each block is a one-liner sent to the REPL with the expected stdout
\ fragment next to it. The corresponding Makefile `test-repl` entries
\ (tests 579..) are the authoritative runners — keep these in sync.

\ === Story 10.8 number-output on pictured foundation ===

\ --- . regression block (AC #1, #14a) ---
0 .                                        \ expect: 0
1234 .                                     \ expect: 1234
-5 .                                       \ expect: -5
32767 .                                    \ expect: 32767
-32768 .                                   \ expect: -32768
255 HEX . DECIMAL                          \ expect: FF     (decimal 255 printed in HEX)

\ --- U. regression block (AC #1, #14b) ---
0 U.                                       \ expect: 0
1234 U.                                    \ expect: 1234
65535 U.                                   \ expect: 65535
65535 HEX U. DECIMAL                       \ expect: FFFF

\ --- .R regression block incl. no-truncation (AC #3, #14c) ---
42 10 .R                                   \ expect: 8 spaces + 42
-5 10 .R                                   \ expect: 8 spaces + -5
1234 3 .R                                  \ expect: 1234 (no truncation, no leading space)
0 0 .R                                     \ expect: 0
0 5 .R                                     \ expect: 4 spaces + 0
42 -5 .R                                   \ expect: 42     (negative width: SPACES no-ops, no truncation)

\ --- D. block incl. worst-case + INT_MIN corner (AC #6, #14d, #15) ---
0 0 D.                                     \ expect: 0
0 123 D.                                   \ expect: 123
-1 -1 D.                                   \ expect: -1
0 -1 D.                                    \ expect: 65535   (hi=0, lo=-1 = unsigned 65535 as double)
0 -1 HEX D. DECIMAL                        \ expect: FFFF
32768 0 D.                                 \ expect: -2147483648   (INT_MIN corner — DABS($80000000) preserves $80000000; SIGN still fires)

\ --- U.R block (AC #14e) ---
42 10 U.R                                  \ expect: 8 spaces + 42
65535 10 U.R                               \ expect: 5 spaces + 65535
0 0 U.R                                    \ expect: 0
65535 8 HEX U.R DECIMAL                    \ expect: 4 spaces + FFFF

\ --- D.R block (AC #14f) ---
0 0 10 D.R                                 \ expect: 9 spaces + 0
0 123 10 D.R                               \ expect: 7 spaces + 123
-1 -1 10 D.R                               \ expect: 8 spaces + -1
-1 -1 0 D.R                                \ expect: -1 (no truncation, no leading space)
32768 0 15 D.R                             \ expect: 4 spaces + -2147483648

\ --- Pictured-path explicit (AC #14g) ---
\ Custom recipe via pictured primitives should produce byte-identical
\ output to `.` for the same input.
: DOT-VIA-PICT S>D OVER >R DABS <# #S R> SIGN #> TYPE SPACE ;
1234 DOT-VIA-PICT                          \ expect: 1234
-5 DOT-VIA-PICT                            \ expect: -5

\ --- Early-binding HOLD-redefinition (AC #8, #14h) ---
\ Standard-compliance check. Redefining HOLD at Forth level does not
\ disturb `.`. Antforth uses early binding plus direct Z80 `CALL
\ hold_common` inside the pictured DEFCODE primitives; the pictured
\ wordset is fully isolated from the user dictionary's HOLD entry.
: HOLD DROP ;
42 .                                       \ expect: 42

\ --- .S preservation smoke (AC #7, #14i) ---
\ `.S` still uses u_to_str / emit_unsigned / num_buf — helpers were
\ preserved despite removing the DEFCODE bodies for ./U./.R.
1 2 3 .S                                   \ expect: <3> 1 2 3

\ --- Underflow-parity block (AC #9, #14j) ---
.                                          \ expect: ? Stack underflow
U.                                         \ expect: ? Stack underflow
D.                                         \ expect: ? Stack underflow
1 .R                                       \ expect: ? Stack underflow
1 U.R                                      \ expect: ? Stack underflow
1 1 D.R                                    \ expect: ? Stack underflow
