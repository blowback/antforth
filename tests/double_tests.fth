\ double_tests.fth — Epic 10 Story 10.2 double-cell stack/memory tests
\ AntForth — A Forth for CP/M on Z80
\
\ Covers 2@, 2!, 2DUP, 2DROP, 2SWAP, 2OVER per DPANS94 §6.1.0310,
\ §6.1.0350, §6.1.0370, §6.1.0380, §6.1.0400, §6.1.0430 with the
\ E10-D1 byte-order convention (low cell on TOS, high cell below;
\ low cell stored at a-addr, high cell at a-addr+2).
\
\ Each block is a one-liner sent to the REPL with the expected stdout
\ fragment next to it. The corresponding Makefile `test-repl` entries
\ (tests 397..) are the authoritative runners — keep these in sync.

\ --- 2DUP depth and values ---
1 2 2DUP .S                              \ expect: <4> 1 2 1 2
0 0 2DUP .S                              \ expect: <4> 0 0 0 0
-1 -2 2DUP .S                            \ expect: <4> -1 -2 -1 -2

\ --- 2DROP depth and residual values ---
1 2 3 4 2DROP .S                         \ expect: <2> 1 2
100 200 2DROP .S                         \ expect: <0>

\ --- 2SWAP pair ordering (preserves intra-pair low/high order) ---
1 2 3 4 2SWAP .S                         \ expect: <4> 3 4 1 2
10 20 30 40 2SWAP .S                     \ expect: <4> 30 40 10 20

\ --- 2OVER copy-second-pair ---
1 2 3 4 2OVER .S                         \ expect: <6> 1 2 3 4 1 2
10 20 30 40 2OVER .S                     \ expect: <6> 10 20 30 40 10 20

\ --- 2@ round-trip via comma-compiled cells (E10-D1 byte order) ---
\ Memory: HERE+0 = $BEEF (low cell = x2), HERE+2 = $DEAD (high cell = x1).
\ 2@ on that address must leave: SP-2nd = $DEAD (x1), TOS = $BEEF (x2).
\ `.` prints signed in hex: $BEEF = -$4111, $DEAD = -$2153.
HEX CREATE D1 BEEF , DEAD , D1 2@ .S     \ expect: <2> -2153 -4111

\ --- 2! round-trip (2! stores, 2@ reads back — pair returns in push order) ---
\ Push order: x1=BEEF, x2=DEAD. 2! stores x2 (DEAD) at D2, x1 (BEEF) at D2+2.
\ 2@ then reads x1=BEEF (second), x2=DEAD (TOS). .S prints second-then-TOS
\ as signed hex: BEEF=-4111, DEAD=-2153.
HEX CREATE D2 0 , 0 , BEEF DEAD D2 2! D2 2@ .S  \ expect: <2> -4111 -2153

\ --- 2! / 2@ at boundary values ---
HEX CREATE D3 0 , 0 , 0 0 D3 2! D3 2@ .S         \ expect: <2> 0 0
HEX CREATE D4 0 , 0 , FFFF FFFF D4 2! D4 2@ .S   \ expect: <2> -1 -1
HEX CREATE D5 0 , 0 , 8000 8000 D5 2! D5 2@ .S   \ expect: <2> -8000 -8000

\ --- Stack-underflow recovery: each word on insufficient depth ---
\ All must produce the "? Stack underflow" diagnostic and recover to 'ok'.
2@                                       \ expect: ? Stack underflow  + ok
2!                                       \ expect: ? Stack underflow  + ok
2DUP                                     \ expect: ? Stack underflow  + ok
2DROP                                    \ expect: ? Stack underflow  + ok
2SWAP                                    \ expect: ? Stack underflow  + ok
2OVER                                    \ expect: ? Stack underflow  + ok

\ --- Near-threshold underflow (one cell short of the minimum DEPTH) ---
1 2DUP                                   \ expect: ? Stack underflow  + ok  (needs 2, has 1)
1 2DROP                                  \ expect: ? Stack underflow  + ok  (needs 2, has 1)
1 2 2!                                   \ expect: ? Stack underflow  + ok  (2! needs 3, has 2)
1 2 3 2SWAP                              \ expect: ? Stack underflow  + ok  (needs 4, has 3)
1 2 3 2OVER                              \ expect: ? Stack underflow  + ok  (needs 4, has 3)
