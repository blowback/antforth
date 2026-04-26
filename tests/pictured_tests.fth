\ pictured_tests.fth — Epic 10 Story 10.7 pictured numeric output tests
\ AntForth — A Forth for CP/M on Z80
\
\ Covers <#, #, #S, #>, HOLD, SIGN (DPANS94 §6.1.0490, §6.1.0030,
\ §6.1.0050, §6.1.0040, §6.1.1670, §6.1.2210) and HOLDS (Forth-2012
\ §6.2.1675) with the E10-D1 byte-order convention (low cell on TOS,
\ high cell below).
\
\ Stack-order note: E10-D1 puts the LOW cell on TOS. Typing "0 65535"
\ leaves (high=0, low=65535) — double value = 65535. Typing "65535 0"
\ leaves (high=65535, low=0) — double value = 65535 * 65536.
\
\ Each block is a one-liner sent to the REPL with the expected stdout
\ fragment next to it. The corresponding Makefile `test-repl` entries
\ (tests 550..) are the authoritative runners — keep these in sync.

\ === Story 10.7 pictured numeric output (<#, #, #S, #>, HOLD, SIGN, HOLDS) ===

\ --- Core primitives: basic decimal round-trip (AC #2-#4, #7) ---
0 123 <# #S #> TYPE                       \ expect: 123
0 12345 <# # # # # # #> TYPE              \ expect: 12345  (five fixed # digits)
0 0 <# #S #> TYPE                         \ expect: 0      (AC #4: #S emits >=1 digit)

\ --- Base-switching (AC #8) ---
\ Literals parse in DECIMAL; BASE changes apply to output only.
DECIMAL 0 65535 <# #S #> TYPE                           \ expect: 65535
DECIMAL 0 65535 HEX <# #S #> TYPE DECIMAL               \ expect: FFFF
DECIMAL 0 255 2 BASE ! <# #S #> TYPE DECIMAL            \ expect: 11111111
DECIMAL 0 511 8 BASE ! <# #S #> TYPE DECIMAL            \ expect: 777
DECIMAL 0 35 36 BASE ! <# #S #> TYPE DECIMAL            \ expect: Z

\ --- Sign handling via canonical signed-double recipe (AC #6) ---
\ Canonical form: ( d -- ) SWAP OVER DABS <# #S ROT SIGN #> TYPE
\ Single-cell variant uses S>D then the same recipe.
-1 S>D SWAP OVER DABS <# #S ROT SIGN #> TYPE                  \ expect: -1
5 S>D SWAP OVER DABS <# #S ROT SIGN #> TYPE                   \ expect: 5
-12345 S>D SWAP OVER DABS <# #S ROT SIGN #> TYPE              \ expect: -12345

\ --- HOLD explicit char (non-digit) ---
\ Builds "1,23" (hundreds, comma, tens, units). Pictured fills RTL.
0 123 <# # # 44 HOLD #S #> TYPE                               \ expect: 1,23   ( 44 = ',' )

\ --- HOLDS left-to-right string insertion (AC #9) ---
: PICT-ABC S" abc" HOLDS ;
0 99 <# #S PICT-ABC #> TYPE                                   \ expect: abc99

\ --- Worst case: double $FFFFFFFF (-1 -1) across bases (AC #8) ---
-1 -1 <# #S #> TYPE                                           \ expect: 4294967295
DECIMAL -1 -1 HEX <# #S #> TYPE DECIMAL                       \ expect: FFFFFFFF
DECIMAL -1 -1 2 BASE ! <# #S #> TYPE DECIMAL                  \ expect: 11111111111111111111111111111111

\ --- Buffer overflow diagnostic (AC #5) ---
\ 41 HOLD calls exceed the 40-byte buffer; 41st triggers
\ "? Pictured buffer overflow" and ABORT recovers the REPL.
: OV41 0 0 <# 41 0 DO 65 HOLD LOOP #> TYPE ;
OV41                                                          \ expect: ? Pictured buffer overflow

\ --- Underflow recovery (AC #11) ---
\ <# consumes 0 cells (no underflow possible).
<#                                                            \ expect: ok
1 #                                                           \ expect: error -4: stack underflow
1 #S                                                          \ expect: error -4: stack underflow
1 #>                                                          \ expect: error -4: stack underflow
HOLD                                                          \ expect: error -4: stack underflow
SIGN                                                          \ expect: error -4: stack underflow
1 HOLDS                                                       \ expect: error -4: stack underflow

\ --- HLD user-variable smoke test (AC #12 — antforth extension) ---
\ <# is idempotent: two consecutive <# reset HLD to the same sentinel.
\ (Pre-10.8 this read `HLD @ <# HLD @ = .` — which tested cold-start init
\  == <# reset. Story 10.8 rewrote U./. on pictured output, so the startup
\  banner's U. mutates HLD before the REPL prompt. The idempotent-<# form
\  captures the same invariant without depending on cold-start immutability.)
<# HLD @ <# HLD @ = .                                         \ expect: -1   ( TRUE flag )

\ --- HOLDS boundary u=0 (no-op) and u=1 (single char) ---
\ u=0 path: ?BRANCH WHILE exits before any HOLD; 2DROP; net no-op.
0 99 <# #S HERE 0 HOLDS #> TYPE                               \ expect: 99
\ u=1 path: single iteration writes one char, then exits.
: PICT-X S" X" HOLDS ;
0 99 <# #S PICT-X #> TYPE                                     \ expect: X99

\ --- digit_to_char A-Z mid-range coverage (catches 'A'-10 off-by-one) ---
\ Base 36: digit value 10 → 'A'; 19 → 'J'; 25 → 'P'; 35 → 'Z'.
DECIMAL 0 10 36 BASE ! <# #S #> TYPE DECIMAL                  \ expect: A
DECIMAL 0 19 36 BASE ! <# #S #> TYPE DECIMAL                  \ expect: J
DECIMAL 0 25 36 BASE ! <# #S #> TYPE DECIMAL                  \ expect: P
