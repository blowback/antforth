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
.                                          \ expect: error -4: stack underflow
U.                                         \ expect: error -4: stack underflow
D.                                         \ expect: error -4: stack underflow
1 .R                                       \ expect: error -4: stack underflow
1 U.R                                      \ expect: error -4: stack underflow
1 1 D.R                                    \ expect: error -4: stack underflow

\ === Story 10.9 remaining Core gap words ===
\
\ Closes the §6.1 Core gap (129/133 → 133/133). Words covered:
\   */     (§6.1.0100)  */MOD  (§6.1.0110)
\   ENVIRONMENT? (§6.1.1345)  EVALUATE  (§6.1.1360)
\
\ Stack-display note: in REPL output, `.` prints TOS first, so a stack
\ ( a b c ) with c on TOS prints as "c b a" via `c b a` -> three `.` calls.
\ For tests below, expected stdout matches the canonical Makefile probe.

\ --- */ block (AC #14a) ---
10 20 5 */                                 \ expect: 40
-10 20 5 */                                \ expect: -40
7 3 2 */                                   \ expect: 10            (21/2 = 10 truncated toward zero)
32767 32767 32767 */                       \ expect: 32767         (double-intermediate overflow trap)

\ --- */MOD block (AC #14b) ---
10 20 6 */MOD                              \ expect: 2 33          (rem 2, quot 33)
17 3 5 */MOD                               \ expect: 1 10          (rem 1, quot 10)
-17 3 5 */MOD                              \ expect: -1 -10        (symmetric remainder sign = dividend)

\ --- EVALUATE block (AC #14c) ---
S" 10 20 +" EVALUATE                       \ expect: 30 on stack
S" 2 3 * 4 +" EVALUATE                     \ expect: 10 on stack
S" " EVALUATE                              \ expect: stack unchanged (empty string completes cleanly)
S" 99" EVALUATE 7 +                        \ expect: 106 (proves TIB restored — '7 +' parses from REPL)

\ Nested EVALUATE via a colon definition (antforth lacks Forth-2014 S\")
: __E910_INNER S" 32" EVALUATE ;
S" 10 __E910_INNER +" EVALUATE             \ expect: 42 (10 + 32)

\ --- ENVIRONMENT? block (AC #14d) — all 14 keys + unknown + case-sensitivity ---
S" /COUNTED-STRING" ENVIRONMENT?           \ expect: ( 255 -1 )
S" /HOLD" ENVIRONMENT?                     \ expect: ( 40 -1 )
S" /PAD" ENVIRONMENT?                      \ expect: ( 84 -1 )
S" ADDRESS-UNIT-BITS" ENVIRONMENT?         \ expect: ( 8 -1 )
S" CORE" ENVIRONMENT?                      \ expect: ( -1 -1 )    (true value, then true flag)
S" CORE-EXT" ENVIRONMENT?                  \ expect: ( 0 -1 )
S" FLOORED" ENVIRONMENT?                   \ expect: ( 0 -1 )
S" MAX-CHAR" ENVIRONMENT?                  \ expect: ( 255 -1 )
S" MAX-D" ENVIRONMENT?                     \ expect: ( 32767 -1 -1 )   (hi=$7FFF=32767, lo=$FFFF=-1, flag=-1; TOS=true)
S" MAX-N" ENVIRONMENT?                     \ expect: ( 32767 -1 )
S" MAX-U" ENVIRONMENT?                     \ expect: ( -1 -1 )    (-1 == 65535 unsigned)
S" MAX-UD" ENVIRONMENT?                    \ expect: ( -1 -1 -1 )
S" RETURN-STACK-CELLS" ENVIRONMENT?        \ expect: ( 128 -1 )
S" STACK-CELLS" ENVIRONMENT?               \ expect: ( 128 -1 )
S" XYZZY" ENVIRONMENT?                     \ expect: ( 0 )         (single-cell false; no i*x)
S" core" ENVIRONMENT?                      \ expect: ( 0 )         (case-sensitive: lowercase not found)

\ --- Underflow recovery (AC #10) ---
*/                                         \ expect: error -4: stack underflow
1 */                                       \ expect: error -4: stack underflow
1 2 */                                     \ expect: error -4: stack underflow
*/MOD                                      \ expect: error -4: stack underflow
1 */MOD                                    \ expect: error -4: stack underflow
1 2 */MOD                                  \ expect: error -4: stack underflow
EVALUATE                                   \ expect: error -4: stack underflow
1 EVALUATE                                 \ expect: error -4: stack underflow
ENVIRONMENT?                               \ expect: error -4: stack underflow
1 ENVIRONMENT?                             \ expect: error -4: stack underflow

\ --- Div-by-zero (Story 11.4 migrated to -10 THROW via UM/MOD funnel) ---
\ DPANS94 §6.1.0100/§6.1.0110 — divide-by-zero raises -10 THROW.
1 1 0 */                                   \ expect: error -10: division by zero
1 1 0 */MOD                                \ expect: error -10: division by zero
