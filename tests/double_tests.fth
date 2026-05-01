\ double_tests.fth — Epic 10 Story 10.2 double-cell stack/memory tests
\ AntForth — A Forth for CP/M on Z80
\
\ Covers 2@, 2!, 2DUP, 2DROP, 2SWAP, 2OVER per DPANS94 §6.1.0310,
\ §6.1.0350, §6.1.0370, §6.1.0380, §6.1.0400, §6.1.0430. Post-
\ Story-13.0.1 (2026-05-01) the byte-order convention is HIGH cell on
\ TOS, LOW cell below (per ANS Forth 1994 §3.1.4.1); HIGH cell at
\ a-addr, LOW cell at a-addr+2 (per §6.1.0310 + §6.1.0350).
\
\ NOTE: the `expect:` annotations in the Epic-10 hand-stacked sections
\ below (lines ~14-260) document the PRE-Story-13.0.1 convention (low
\ cell on TOS) for historical reference. The authoritative runners are
\ the Makefile `test-repl` entries (tests 397..); those have been
\ rewritten to the new high-on-TOS convention. To validate against
\ live antforth, consult the Makefile runners. The Story 13.0
\ literal-input section (lines ~264+) is convention-symmetric — the
\ recogniser produces the cells in the right order for the active
\ convention, so those tests work either way.
\
\ Each block is a one-liner sent to the REPL with the expected stdout
\ fragment next to it (see NOTE above re: convention).

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
\ All must produce the "error -4: stack underflow" diagnostic and recover
\ to 'ok' (Story 11.4 migrated do_underflow_error to -4 THROW).
2@                                       \ expect: error -4: stack underflow  + ok
2!                                       \ expect: error -4: stack underflow  + ok
2DUP                                     \ expect: error -4: stack underflow  + ok
2DROP                                    \ expect: error -4: stack underflow  + ok
2SWAP                                    \ expect: error -4: stack underflow  + ok
2OVER                                    \ expect: error -4: stack underflow  + ok

\ --- Near-threshold underflow (one cell short of the minimum DEPTH) ---
1 2DUP                                   \ expect: error -4: stack underflow  + ok  (needs 2, has 1)
1 2DROP                                  \ expect: error -4: stack underflow  + ok  (needs 2, has 1)
1 2 2!                                   \ expect: error -4: stack underflow  + ok  (2! needs 3, has 2)
1 2 3 2SWAP                              \ expect: error -4: stack underflow  + ok  (needs 4, has 3)
1 2 3 2OVER                              \ expect: error -4: stack underflow  + ok  (needs 4, has 3)

\ === Story 10.3 single<->double conversions ===
\ S>D sign-extend: TOS = low cell = original n; second = high cell (0 or -1).

\ --- S>D positive / zero / negative ---
5 S>D .S                                 \ expect: <2> 0 5
0 S>D .S                                 \ expect: <2> 0 0
-5 S>D .S                                \ expect: <2> -1 -5

\ --- S>D boundary values ---
32767 S>D .S                             \ expect: <2> 0 32767
-32768 S>D .S                            \ expect: <2> -1 -32768
-1 S>D .S                                \ expect: <2> -1 -1

\ --- D>S pure-sign-extended doubles (positive / negative) round-trip cleanly ---
0 5 D>S .S                               \ expect: <1> 5
-1 -5 D>S .S                             \ expect: <1> -5

\ --- D>S truncation: non-sign-extended double silently drops high cell (AC#2) ---
1 5 D>S .S                               \ expect: <1> 5

\ --- S>D D>S round-trip preserves the value across the signed-16 range ---
0 S>D D>S .                              \ expect: 0
1 S>D D>S .                              \ expect: 1
-1 S>D D>S .                             \ expect: -1
32767 S>D D>S .                          \ expect: 32767
-32768 S>D D>S .                         \ expect: -32768
100 S>D D>S .                            \ expect: 100
-100 S>D D>S .                           \ expect: -100

\ --- >NUMBER single-cell accumulation (baseline, pre-existing semantics) ---
0 0 S" 42" DROP 2 >NUMBER 2DROP .S       \ expect: <2> 0 42

\ --- >NUMBER double-cell accumulation across the 16-bit boundary ---
\ "65536" decimal = (high=1, low=0). u2=0 (fully consumed).
0 0 S" 65536" DROP 5 >NUMBER 2DROP .S    \ expect: <2> 1 0

\ --- >NUMBER well above the 16-bit boundary ---
\ "1000000" decimal = 15*65536 + 16960 = (high=15, low=16960).
0 0 S" 1000000" DROP 7 >NUMBER 2DROP .S  \ expect: <2> 15 16960

\ --- >NUMBER binary base: 17-bit string parses into ud-high=1, ud-low=0 ---
\ Literals stay decimal; BASE flips to 2 only for the >NUMBER call itself.
0 0 S" 10000000000000000" DROP 17 2 BASE ! >NUMBER DECIMAL 2DROP .S  \ expect: <2> 1 0

\ --- S>D / D>S / >NUMBER underflow recovery ---
S>D                                      \ expect: error -4: stack underflow  + ok  (S>D needs 1, has 0)
D>S                                      \ expect: error -4: stack underflow  + ok  (D>S needs 2, has 0)
1 D>S                                    \ expect: error -4: stack underflow  + ok  (D>S needs 2, has 1)
>NUMBER                                  \ expect: error -4: stack underflow  + ok  (>NUMBER needs 4, has 0)
1 >NUMBER                                \ expect: error -4: stack underflow  + ok  (>NUMBER needs 4, has 1)
1 2 >NUMBER                              \ expect: error -4: stack underflow  + ok  (>NUMBER needs 4, has 2)
1 2 3 >NUMBER                            \ expect: error -4: stack underflow  + ok  (>NUMBER needs 4, has 3)

\ === Story 10.4 double-cell arithmetic (additive / sign / compare / mixed) ===
\ Covers D+, D-, DNEGATE, DABS, D=, D<, DMAX, DMIN, M+ per DPANS94 §8.6
\ sections 1040, 1050, 1230, 1160, 1120, 1110, 1210, 1220, 1830 with
\ the E10-D1 byte-order convention (low cell on TOS).

\ --- D+ (§8.6.1040) double-cell add ---
0 0 0 0 D+ .S 2DROP                      \ expect: <2> 0 0
0 5 0 7 D+ .S 2DROP                      \ expect: <2> 0 12
0 -1 0 1 D+ .S 2DROP                     \ expect: <2> 1 0
-1 -1 0 1 D+ .S 2DROP                    \ expect: <2> 0 0
32767 -1 0 1 D+ .S 2DROP                 \ expect: <2> -32768 0

\ --- D- (§8.6.1050) double-cell subtract ---
0 10 0 4 D- .S 2DROP                     \ expect: <2> 0 6
0 4 0 10 D- .S 2DROP                     \ expect: <2> -1 -6
0 0 0 1 D- .S 2DROP                      \ expect: <2> -1 -1
1 0 0 1 D- .S 2DROP                      \ expect: <2> 0 -1
-1 -1 0 1 D- .S 2DROP                    \ expect: <2> -1 -2

\ --- DNEGATE (§8.6.1230) double-cell two's-complement negate ---
0 0 DNEGATE .S 2DROP                     \ expect: <2> 0 0
0 1 DNEGATE .S 2DROP                     \ expect: <2> -1 -1
-1 -1 DNEGATE .S 2DROP                   \ expect: <2> 0 1
0 -32768 DNEGATE .S 2DROP                \ expect: <2> -1 -32768

\ --- DABS (§8.6.1160) double-cell absolute value ---
0 0 DABS .S 2DROP                        \ expect: <2> 0 0
0 5 DABS .S 2DROP                        \ expect: <2> 0 5
-1 -5 DABS .S 2DROP                      \ expect: <2> 0 5
-1 0 DABS .S 2DROP                       \ expect: <2> 1 0

\ --- D= (§8.6.1120) double-cell equality ---
0 0 0 0 D= .                             \ expect: -1
0 5 0 5 D= .                             \ expect: -1
0 5 0 6 D= .                             \ expect: 0
1 5 2 5 D= .                             \ expect: 0
-1 -1 -1 -1 D= .                         \ expect: -1

\ --- D< (§8.6.1110) double-cell signed less-than (signed high / unsigned low) ---
0 0 0 1 D< .                             \ expect: -1
0 1 0 0 D< .                             \ expect: 0
-1 -1 0 0 D< .                           \ expect: -1
0 0 -1 -1 D< .                           \ expect: 0
0 -1 1 0 D< .                            \ expect: -1
1 0 1 0 D< .                             \ expect: 0
-1 0 -1 1 D< .                           \ expect: -1

\ --- DMAX (§8.6.1210) double-cell max (signed) ---
0 5 0 7 DMAX .S 2DROP                    \ expect: <2> 0 7
-1 -1 0 0 DMAX .S 2DROP                  \ expect: <2> 0 0
0 5 0 5 DMAX .S 2DROP                    \ expect: <2> 0 5
0 -1 1 0 DMAX .S 2DROP                   \ expect: <2> 1 0

\ --- DMIN (§8.6.1220) double-cell min (signed) ---
0 5 0 7 DMIN .S 2DROP                    \ expect: <2> 0 5
-1 -1 0 0 DMIN .S 2DROP                  \ expect: <2> -1 -1
0 5 0 5 DMIN .S 2DROP                    \ expect: <2> 0 5
0 -1 1 0 DMIN .S 2DROP                   \ expect: <2> 0 -1

\ --- M+ (§8.6.1830) mixed single+double add (sign-extended) ---
0 0 1 M+ .S 2DROP                        \ expect: <2> 0 1
0 0 -1 M+ .S 2DROP                       \ expect: <2> -1 -1
0 -1 1 M+ .S 2DROP                       \ expect: <2> 1 0
0 0 -5 M+ .S 2DROP                       \ expect: <2> -1 -5
-1 -5 -1 M+ .S 2DROP                     \ expect: <2> -1 -6

\ --- Story 10.4 underflow recovery (one per word at DEPTH = N-1) ---
1 2 3 D+                                 \ expect: error -4: stack underflow  + ok  (D+ needs 4, has 3)
1 2 3 D-                                 \ expect: error -4: stack underflow  + ok  (D- needs 4, has 3)
1 DNEGATE                                \ expect: error -4: stack underflow  + ok  (DNEGATE needs 2, has 1)
1 DABS                                   \ expect: error -4: stack underflow  + ok  (DABS needs 2, has 1)
1 2 3 D=                                 \ expect: error -4: stack underflow  + ok  (D= needs 4, has 3)
1 2 3 D<                                 \ expect: error -4: stack underflow  + ok  (D< needs 4, has 3)
1 2 3 DMAX                               \ expect: error -4: stack underflow  + ok  (DMAX needs 4, has 3)
1 2 3 DMIN                               \ expect: error -4: stack underflow  + ok  (DMIN needs 4, has 3)
1 2 M+                                   \ expect: error -4: stack underflow  + ok  (M+ needs 3, has 2)

\ === Story 10.5 double-cell multiplication (UM*, M*, D*) ===

\ --- UM* (§6.1.2360) unsigned mixed multiply ---
0 0 UM* .S 2DROP                         \ expect: <2> 0 0     (zero × zero)
0 5 UM* .S 2DROP                         \ expect: <2> 0 0     (zero × nonzero)
1 1 UM* .S 2DROP                         \ expect: <2> 0 1     (trivial product fits in low cell)
$100 $100 UM* .S 2DROP                   \ expect: <2> 1 0     (256×256=65536; clean carry into high cell)
$FFFF $FFFF UM* .S 2DROP                 \ expect: <2> -2 1    ($FFFE0001; max unsigned squared)
$FFFF 2 UM* .S 2DROP                     \ expect: <2> 1 -2    ($1FFFE; low-cell wraps)

\ --- M* (§6.1.1810) signed mixed multiply ---
0 0 M* .S 2DROP                          \ expect: <2> 0 0
5 3 M* .S 2DROP                          \ expect: <2> 0 15    (positive × positive)
-5 3 M* .S 2DROP                         \ expect: <2> -1 -15  (negative × positive → negative double)
5 -3 M* .S 2DROP                         \ expect: <2> -1 -15  (positive × negative → negative)
-5 -3 M* .S 2DROP                        \ expect: <2> 0 15    (negative × negative → positive)
-32768 -32768 M* .S 2DROP                \ expect: <2> 16384 0 ($40000000; ABS($8000) trap collapses)
32767 32767 M* .S 2DROP                  \ expect: <2> 16383 1 ($3FFF0001; max positive squared)
-32768 32767 M* .S 2DROP                 \ expect: <2> -16384 -32768  (-$3FFF8000; sign + magnitude)

\ --- D* (§8.6.1090) double-cell signed multiply (truncating) ---
0 0 0 0 D* .S 2DROP                      \ expect: <2> 0 0
0 5 0 3 D* .S 2DROP                      \ expect: <2> 0 15    (both fit in single cells)
0 -1 0 1 D* .S 2DROP                     \ expect: <2> 0 -1    (65535 × 1 = $0000FFFF)
0 -1 0 -1 D* .S 2DROP                    \ expect: <2> -2 1    (65535 × 65535 = $FFFE0001)
-1 -1 0 1 D* .S 2DROP                    \ expect: <2> -1 -1   (-1 × 1 signed double)
-1 -1 -1 -1 D* .S 2DROP                  \ expect: <2> 0 1     (two's-complement -1 × -1 = 1)
0 1 -1 0 D* .S 2DROP                     \ expect: <2> -1 0    (cross-term carry: $FFFF0000)

\ --- Story 10.5 underflow recovery (one per word at DEPTH = N-1) ---
1 UM*                                    \ expect: error -4: stack underflow  + ok  (UM* needs 2, has 1)
1 M*                                     \ expect: error -4: stack underflow  + ok  (M* needs 2, has 1)
1 2 3 D*                                 \ expect: error -4: stack underflow  + ok  (D* needs 4, has 3)

\ === Story 10.6 double/mixed-precision division (UM/MOD, SM/REM, FM/MOD) ===

\ --- UM/MOD (§6.1.2370) unsigned mixed divide ---
0 0 1 UM/MOD .S 2DROP                    \ expect: <2> 0 0       (zero dividend)
0 1 1 UM/MOD .S 2DROP                    \ expect: <2> 0 1       (unity / unity)
0 10 3 UM/MOD .S 2DROP                   \ expect: <2> 1 3       (10 / 3 = 3 rem 1)
0 -1 1 UM/MOD .S 2DROP                   \ expect: <2> 0 -1      ($FFFF / 1 = $FFFF rem 0)
1 0 2 UM/MOD .S 2DROP                    \ expect: <2> 0 -32768  ($10000 / 2 = $8000 rem 0)
0 -1 -1 UM/MOD .S 2DROP                  \ expect: <2> 0 1       ($FFFF / $FFFF = 1 rem 0)
-2 -1 -1 UM/MOD .S 2DROP                 \ expect: <2> -2 -1     ($FFFEFFFF / $FFFF = $FFFF rem $FFFE — max quot just-fits)

\ --- SM/REM (§6.1.2214) symmetric signed mixed divide ---
\ (remainder sign matches dividend; quotient truncates toward zero)
0 10 3 SM/REM .S 2DROP                   \ expect: <2> 1 3       (+10 / +3 = +3 rem +1)
-1 -10 3 SM/REM .S 2DROP                 \ expect: <2> -1 -3     (-10 / +3 = -3 rem -1)
0 10 -3 SM/REM .S 2DROP                  \ expect: <2> 1 -3      (+10 / -3 = -3 rem +1)
-1 -10 -3 SM/REM .S 2DROP                \ expect: <2> -1 3      (-10 / -3 = +3 rem -1)
0 0 7 SM/REM .S 2DROP                    \ expect: <2> 0 0       (zero dividend)
-1 -5 10 SM/REM .S 2DROP                 \ expect: <2> -5 0      (|-5|<10 → quot 0 rem -5)
-1 -32768 1 SM/REM .S 2DROP              \ expect: <2> 0 -32768  ($FFFF8000 / 1 = -32768 rem 0)

\ --- FM/MOD (§6.1.1561) floored signed mixed divide ---
\ (remainder sign matches divisor; quotient rounds toward -∞)
0 10 3 FM/MOD .S 2DROP                   \ expect: <2> 1 3       (same-sign — matches SM/REM)
-1 -10 3 FM/MOD .S 2DROP                 \ expect: <2> 2 -4      (-10 floored /3 = -4 rem 2 — discriminates from SM/REM's -1 -3)
0 10 -3 FM/MOD .S 2DROP                  \ expect: <2> -2 -4     (+10 floored /-3 = -4 rem -2 — discriminates from SM/REM's 1 -3)
-1 -10 -3 FM/MOD .S 2DROP                \ expect: <2> -1 3      (same-sign negative — matches SM/REM)
0 0 7 FM/MOD .S 2DROP                    \ expect: <2> 0 0       (zero dividend)
0 9 3 FM/MOD .S 2DROP                    \ expect: <2> 0 3       (exact — no correction applied)
-1 -9 3 FM/MOD .S 2DROP                  \ expect: <2> 0 -3      (exact negative — no correction)

\ --- Story 10.6 underflow recovery (one per word at DEPTH = N-1) ---
1 2 UM/MOD                               \ expect: error -4: stack underflow  + ok  (UM/MOD needs 3, has 2)
1 2 SM/REM                               \ expect: error -4: stack underflow  + ok  (SM/REM needs 3, has 2)
1 2 FM/MOD                               \ expect: error -4: stack underflow  + ok  (FM/MOD needs 3, has 2)

\ === Story 13.0 literal-input regression — ANS Forth 1994 §3.4.1.3 ===
\ Dot-bearing digit-string parses to a double-cell integer; the dot is
\ a marker (not a place-holder), ignored for value. Unprefixed and
\ prefixed forms supported; sign composes with prefix; multi-dot rejects.
\ DPL is a USER variable carrying digits-after-dot, -1 if no dot
\ (de-facto Forth convention; not in ANS Core).

\ --- Trailing-dot (the canonical idiom) ---
1000000.   D.                            \ expect: 1000000   (single line, double-cell)
0.         D.                            \ expect: 0
1.         D.                            \ expect: 1
-1.        D.                            \ expect: -1
-1000000.  D.                            \ expect: -1000000

\ --- Leading-dot ---
.5         D.                            \ expect: 5
.0         D.                            \ expect: 0
-.5        D.                            \ expect: -5
-.0        D.                            \ expect: 0

\ --- Embedded-dot ---
1.000      D.                            \ expect: 1000
12.34      D.                            \ expect: 1234
999.999    D.                            \ expect: 999999
-1.000     D.                            \ expect: -1000

\ --- Prefix combinations (Epic 9 prefix × Story 13.0 dot) ---
#1000.     D.                            \ expect: 1000      (decimal prefix + dot)
$FFFF.     D.                            \ expect: 65535
%1010.     D.                            \ expect: 10
0xDEAD.    D.                            \ expect: 57005
-#1000.    D.                            \ expect: -1000
-$FF.      D.                            \ expect: -255

\ --- BASE-relative unprefixed ---
HEX FF. D. DECIMAL                       \ expect: FF        (parsed in HEX, displayed in HEX)
2 BASE ! 1010. D. DECIMAL                \ expect: 1010      (parsed in binary, displayed in binary)

\ --- Multi-dot rejection (parser-level) ---
\ 1.2.3 → undefined word; dot-alone, sign+dot only, prefix+dot only similar
\ (Tested through REPL piping in Makefile to capture error -13)

\ --- DPL probe section ---
1000000. DROP DROP DPL @ .               \ expect: 0         (trailing dot → 0 digits after)
1.000    DROP DROP DPL @ .               \ expect: 3
12.34    DROP DROP DPL @ .               \ expect: 2
999.999  DROP DROP DPL @ .               \ expect: 3
.5       DROP DROP DPL @ .               \ expect: 1
.0       DROP DROP DPL @ .               \ expect: 1
42       DROP DPL @ .                    \ expect: -1        (single-cell parse → DPL = -1)

\ --- Compile-state preservation ---
: STORY13-T1 1000000. ; STORY13-T1 D.        \ expect: 1000000
: STORY13-T2 -1000000. ; STORY13-T2 D.       \ expect: -1000000
: STORY13-T3 $DEADBEEF. ; STORY13-T3 D.      \ expect: -559038737   (bit pattern preserved)
: STORY13-T4 1.000 DPL @ ; STORY13-T4 .      \ expect: 3            (DPL preserved at execute-time)

\ --- Operator-with-literal-input variants (parallel to Epic 10 hand-stacked tests) ---
1000000. 2000000. D+ D.                  \ expect: 3000000           (D+ via literal input)
-1000000. 1. D+ D.                       \ expect: -999999           (signed D+)
1.000 1.000 D= .                         \ expect: -1                (D= via literal input)
.0 .0 D= .                               \ expect: -1
12.34 1234. D= .                         \ expect: -1                (12.34 == 1234 — same value)
