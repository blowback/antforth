\ number_prefixes_tests.fth — Epic 9 numeric-literal prefix tests
\ AntForth — A Forth for CP/M on Z80
\
\ Story 9.1 scope: `#` decimal prefix only (Forth 2014 §3.4.1.3).
\ Stories 9.2 through 9.5 will append tests for `$`, `0x`, `%`, `'c'`,
\ and leading-sign prefixes as those prefixes are implemented.
\
\ Each block is a one-liner sent to the REPL with the expected stdout
\ fragment next to it. The corresponding Makefile `test-repl` entries
\ (tests 266..) are the authoritative runners — keep these in sync.
\
\ NOTE ON `HEX #42 .`: The `#` prefix is parse-time only (Forth 2014
\ §3.4.1.3). `.` prints according to the current BASE. So in HEX mode
\ `#42 .` parses 42 decimal then prints it in hex as "2A " — NOT "42 ".
\ gforth confirms this behaviour. The original Story 9.1 AC draft had
\ `42 ` here; the correction is documented in the story's Dev Notes.

\ --- Basic parse ---
#42 .                    \ expect:  42
#0 .                     \ expect:   0

\ --- Sign in body (inherited from NUMBER? pattern) ---
#-5 .                    \ expect:  -5

\ --- Parse is decimal regardless of BASE ---
HEX #42 .                \ expect:  2A   (= decimal 42 in hex)

\ --- BASE is not mutated by the prefix ---
HEX #42 DROP BASE @ .    \ expect:  10   (= decimal 16 in hex; BASE still 16)

\ --- Graceful fallthrough on malformed body ---
#ABC                     \ expect:  #ABC ?

\ --- Story 9.2 additions: '$' (Forth 2014) and '0x' (antforth ext) hex ---
\
\ `$` is Forth 2014 §3.4.1.3 standard hex; `0x` is the one antforth
\ extension in Phase 2 (NFR13). Both parse body as base-16, leave BASE
\ unchanged, and accept mixed-case hex digits (OR 0x20 fold in
\ char_to_digit_base16 — covers the §3.4.1.3 case-insensitivity
\ requirement up front per memory `feedback_design_upfront.md`).
\
\ NOTE ON `U.` vs `.`: `.` prints signed; values > 0x7FFF print negative.
\ Tests that verify the full 16-bit parse (e.g., $FFFF → 65535) use `U.`
\ to match the unsigned interpretation called out in the AC. Smaller
\ positive values use `.` since signed/unsigned agree there.

\ --- '$' positive cases ---
$0 .                     \ expect:   0
$FF .                    \ expect: 255
$ff .                    \ expect: 255   (lower-case digits)
$1234 .                  \ expect: 4660
$ffff U.                 \ expect: 65535 (max unsigned 16-bit)

\ --- '$' mixed-case ---
$aBcD U.                 \ expect: 43981 (0xABCD unsigned)

\ --- '0x' positive cases ---
0x0 .                    \ expect:   0
0xFF .                   \ expect: 255
0xff .                   \ expect: 255   (all-lower-case: x and digits)
0XFF .                   \ expect: 255   (upper-case X)
0Xff .                   \ expect: 255   (mixed-case X with lower digits)
0xFFFF U.                \ expect: 65535

\ --- BASE integrity ---
HEX $FF DROP BASE @ .    \ expect:  10   (= 16 printed in hex; BASE unmoved)
DECIMAL 0xFF DROP BASE @ .   \ expect:  10   (= 10 printed in decimal)

\ --- Ambiguity / fallthrough ---
0 .                      \ expect:   0    (bare zero still parses via NUMBER?)
00 .                     \ expect:   0    ('00' still parses via NUMBER?)
HEX 0A .                 \ expect:   A    ('0A' via NUMBER?, printed in HEX)
DECIMAL 0A               \ expect:  0A ?  (undefined in DECIMAL, prefix fell through)
$                        \ expect:  $ ?   (bare $, undefined word)
0x                       \ expect:  0x ?  (bare 0x, undefined word)
$XYZ                     \ expect:  $XYZ ? (invalid body, undefined word)

\ --- Sign in body (mirrors 9.1 NUMBER?-parity pattern) ---
$-FF .                   \ expect:  -255
0x-FF .                  \ expect:  -255

\ --- Compile-time (inside a colon body) ---
: GETFF $FF ; GETFF .        \ expect: 255
: GETHEX 0x1234 ; GETHEX .   \ expect: 4660

\ --- Cross-handler sign-flag reset (.pref_negate is shared across #/$/0x) ---
\ Verifies the negate-flag scratch byte is properly reset on each token —
\ a regression here would silently sign every literal after the first
\ negative one. Two tokens, mixed sign, reverse-order print: -255 42.
#42 $-FF . .                 \ expect:  -255 42
