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

\ --- Story 9.3 additions: '%' (binary) and "'c'" (character-code) ---
\
\ Both are Forth 2014 §3.4.1.3 standard prefixes (NOT antforth extensions
\ — 0x remains the only extension in Epic 9 per NFR12). '%' mirrors '$'
\ in structure (base-2 digit accumulate, sign-in-body allowed). "'c'" is
\ a dedicated handler — exactly 3 bytes, closing-quote required, no
\ sign-in-body, does not touch .pref_negate.
\
\ Bare ' is intercepted by FIND before reaching the recogniser (the
\ existing TICK word at src/compiler.asm:26); the prefix arm only sees
\ 'c-style tokens that FIND did not match.

\ --- '%' positive cases ---
%0 .                     \ expect:   0
%1 .                     \ expect:   1
%1010 .                  \ expect:  10   (DECIMAL)
%11111111 .              \ expect: 255   (DECIMAL)
%1111111111111111 U.     \ expect: 65535 (max unsigned 16-bit)

\ --- '%' BASE integrity ---
HEX %11111111 DROP BASE @ .      \ expect:  10   (BASE=16 printed in hex as 10)
DECIMAL %1010 DROP BASE @ .      \ expect:  10

\ --- '%' sign in body (mirrors 9.1/9.2 NUMBER?-parity) ---
%-1010 .                 \ expect:  -10

\ --- '%' HEX cross-base print ---
HEX %11111111 .          \ expect:  FF    (decimal 255 printed in hex)

\ --- '%' malformed / fallthrough ---
%102                     \ expect:  %102 ?  (non-binary digit)
%                        \ expect:  % ?     (bare %)
%-                       \ expect:  %- ?    (bare sign)

\ --- "'c'" positive cases ---
'A' .                    \ expect:  65
'0' .                    \ expect:  48
'a' .                    \ expect:  97
'9' .                    \ expect:  57
'+' .                    \ expect:  43
'*' .                    \ expect:  42

\ --- "'c'" BASE integrity ---
HEX 'A' DROP BASE @ .    \ expect:  10    (BASE=16 printed in hex as 10)

\ --- "'c'" malformed / fallthrough ---
'ab'                     \ expect:  'ab' ?   (too long)
'a                       \ expect:  'a ?     (no closing quote)
''                       \ expect:  '' ?     (empty middle — 2 bytes)
'abc'                    \ expect:  'abc' ?  (4-byte body)

\ --- "'c'" TICK interaction (bare ' still reaches TICK via FIND) ---
' DROP .                 \ expect:  <xt for DROP, decimal>

\ --- Compile-time (inside a colon body) ---
: GETTEN %1010 ; GETTEN .        \ expect:  10
: GETA 'A' ; GETA .              \ expect:  65

\ --- Cross-handler negate reset — #/% pairing mirrors 9.2 test 299 ---
#42 %-1010 . .               \ expect:  -10 42

\ --- "'c'" additional edge cases (review follow-ups) ---
\ Apostrophe as char literal — legal Forth 2014 §3.4.1.3: middle byte
\ is ASCII 0x27 (39). Arrives as the 3-byte token ' ' ' (count=3).
''' .                    \ expect:  39
\ Four-apostrophe token (count=4) — CP 3 fails, fallthrough.
''''                     \ expect:  '''' ?

\ --- Story 9.4 additions: leading '-' sign + case-insensitivity audit ---
\
\ Story 9.4 delivers the leading-'-' sign modifier (Forth 2014 §3.4.1.3
\ — leading sign is standard) that composes with every other prefix
\ (#, $, 0x, %, 'c'). The outer '-' pre-pass (.pref_sign_entry) peeks
\ the second char OUTSIDE the EXX window so '-42', '-2A' etc. still
\ fall through to NUMBER? cleanly (FR47 preservation).
\
\ Double-sign composition (e.g. '-#-5' = +5) is an antforth observable —
\ not specified by the standard, but a direct consequence of the XOR-
\ semantic sign flag. See story 9.4 Dev Notes for the design rationale.

\ --- Outer sign + each prefix (single sign) ---
-#42 .                   \ expect:  -42
-#0 .                    \ expect:   0   (negative zero collapses)
-$FF .                   \ expect: -255
-$ff .                   \ expect: -255  (lower-case hex)
-0xFF .                  \ expect: -255
-0XFF .                  \ expect: -255  (upper-case X)
-0xff .                  \ expect: -255  (all-lower)
-%1010 .                 \ expect: -10
-%11111111 .             \ expect: -255
-'A' .                   \ expect: -65
-'a' .                   \ expect: -97
-'0' .                   \ expect: -48
-'+' .                   \ expect: -43

\ --- Double-sign (XOR composition, antforth behaviour) ---
-#-5 .                   \ expect:   5
-$-FF .                  \ expect: 255
-0x-FF .                 \ expect: 255
-%-1010 .                \ expect:  10

\ --- BASE integrity under outer sign ---
HEX -#42 DROP BASE @ .   \ expect:  10   (BASE=16 printed in hex)
DECIMAL -$FF DROP BASE @ .   \ expect:  10   (BASE=10 printed in decimal)

\ --- Case-insensitivity audit (hex digits, inherited from 9.2) ---
$ABCD U.                 \ expect: 43981
$abcd U.                 \ expect: 43981
$aBcD U.                 \ expect: 43981
0xABCD U.                \ expect: 43981
0xabcd U.                \ expect: 43981
0xAbCd U.                \ expect: 43981

\ --- Case-insensitivity audit (0x prefix letter, inherited from 9.2) ---
0xFF .                   \ expect: 255
0XFF .                   \ expect: 255
-0xFF .                  \ expect: -255  (sign + lower-x)
-0XFF .                  \ expect: -255  (sign + upper-X)

\ --- FR47 regression guards (MUST NOT be captured by the pre-pass) ---
-42 .                    \ expect: -42    (DECIMAL, NUMBER? owns)
HEX -2A . DECIMAL        \ expect: -2A    (HEX, NUMBER? owns)

\ --- Malformed outer-sign fallthrough ---
-#                       \ expect: -# ?
-$                       \ expect: -$ ?
-%                       \ expect: -% ?
-0x                      \ expect: -0x ?
-''                      \ expect: -'' ?
-'ab'                    \ expect: -'ab' ?

\ --- Cross-handler carry-over (one-time dispatch reset) ---
\ Verifies .pref_negate is reset exactly once per recogniser entry, so
\ outer-sign state from token 1 does not bleed into token 2.
-#42 -$-FF . .           \ expect:  255 -42

\ --- Story 9.5 additions: prefix reach across parse contexts ---
\
\ Story 9.5 is a verification-only story: it proves that the prefix
\ recogniser wired into the single shared INTERPRET thread at
\ src/outer_interpreter.asm:.try_number reaches identically into
\ REPL, colon bodies, and CODE...END-CODE assembler source. No new
\ assembly machinery is introduced; these are observational tests.
\
\ Sub-sections (Makefile tests 364..):
\   - Colon body:  every prefix * sign variant + BASE-cross + BASE
\                  integrity snapshots + compile-error.
\   - CODE block:  every prefix * sign variant + BASE-cross + BASE
\                  integrity + ABORT-on-malformed.
\   - Cross-ctx:   mixed-context session, plus FR47 spot-checks.

\ --- Colon body: single-prefix + sign cross-product ---
\ Each test defines a throw-away word F_<name> and invokes it, printing
\ the computed value. DECIMAL (baseline) unless otherwise noted.
: F_CH #42 ; F_CH .              \ expect:  42   (# inside colon body)
: F_CHN -#42 ; F_CHN .           \ expect: -42   (outer - + # in colon body)
: F_CHS $-FF ; F_CHS .           \ expect: -255  (inner - on $ arm, colon body)
: F_CDS -$FF ; F_CDS .           \ expect: -255  (outer - + $ in colon body)
: F_CX -0xFF ; F_CX .            \ expect: -255  (outer - + 0x in colon body)
\ NOTE: plain '%1010' colon-body already covered by existing test 324 (: GETTEN)
\ NOTE: plain "'A'"   colon-body already covered by existing test 325 (: GETA)
: F_CBN -%1010 ; F_CBN .         \ expect: -10   (outer - + % in colon body)
: F_CQN -'A' ; F_CQN .           \ expect: -65   (outer - + 'c' in colon body)

\ --- Colon body: BASE-cross — parse BASE-independent, print uses prevailing BASE ---
HEX : F_DH #100 . ; F_DH DECIMAL     \ expect: 64    (100 decimal printed in HEX)
DECIMAL : F_HD $ff . ; F_HD          \ expect: 255

\ --- Colon body: BASE integrity across define + invoke ---
\ Four snapshots on one REPL line: before-define, after-define,
\ computed-value, after-invoke. BASE must be unchanged throughout.
BASE @ . : F_BH #42 ; BASE @ . F_BH . BASE @ .   \ expect: 10 10 42 10
BASE @ . : F_BD $FF ; BASE @ . F_BD . BASE @ .   \ expect: 10 10 255 10
BASE @ . : F_BX 0xFF ; BASE @ . F_BX . BASE @ .  \ expect: 10 10 255 10
BASE @ . : F_BB %1010 ; BASE @ . F_BB . BASE @ . \ expect: 10 10 10 10
BASE @ . : F_BQ 'A' ; BASE @ . F_BQ . BASE @ .   \ expect: 10 10 65 10

\ --- Colon body: compile-time error on malformed prefix ---
\ The compile-error path at outer_interpreter.asm:.not_number with STATE!=0
\ calls COMP_ERROR, which aborts and unlinks the half-built entry.
\ The follow-on F_BAD . reference must itself error — no survivor entry.
: F_BAD #ABC ;           \ expect:  #ABC ?  (compile error aborts, F_BAD unlinked)
F_BAD .                  \ expect:  F_BAD ? (no half-built entry survived)

\ --- CODE block: single-prefix + sign cross-product ---
\ Each CODE word stacks BC, loads C = low byte and B = high byte from
\ prefixed literals, returns via NEXT,. The caller then prints.
\ Operand order for immediate LD,: Zilog dst-first — `C 0xFF # LD,` =
\ `LD C, 0xFF`. See src/assembler.asm:29.
CODE MK_FF BC PUSH, C 0xFF # LD, B 0 # LD, NEXT, END-CODE   MK_FF .    \ expect: 255
CODE MK_FFu BC PUSH, C 0XFF # LD, B 0 # LD, NEXT, END-CODE  MK_FFu .   \ expect: 255 (upper-X)
CODE MK_D100 BC PUSH, C #100 # LD, B 0 # LD, NEXT, END-CODE MK_D100 .  \ expect: 100 (# in CODE)
CODE MK_NEG BC PUSH, C -#5 # LD, B 0xFF # LD, NEXT, END-CODE MK_NEG .  \ expect: -5 (-#5 sign-extended)
CODE MK_DS BC PUSH, C $FF # LD, B 0 # LD, NEXT, END-CODE    MK_DS .    \ expect: 255 ($ in CODE)
CODE MK_DSN BC PUSH, C $-FF # LD, B 0xFF # LD, NEXT, END-CODE MK_DSN . \ expect: -255 ($-FF, inner sign)
CODE MK_DSO BC PUSH, C -$FF # LD, B 0xFF # LD, NEXT, END-CODE MK_DSO . \ expect: -255 (-$FF, outer sign)
CODE MK_X BC PUSH, C -0xFF # LD, B 0xFF # LD, NEXT, END-CODE MK_X .    \ expect: -255 (-0xFF)
CODE MK_B BC PUSH, C %1010 # LD, B 0 # LD, NEXT, END-CODE   MK_B .     \ expect: 10
CODE MK_BN BC PUSH, C -%1010 # LD, B 0xFF # LD, NEXT, END-CODE MK_BN .  \ expect: -10 (outer sign on % arm, CODE block)
CODE MK_Q BC PUSH, C 'A' # LD, B 0 # LD, NEXT, END-CODE     MK_Q .     \ expect: 65
CODE MK_QN BC PUSH, C -'A' # LD, B 0xFF # LD, NEXT, END-CODE MK_QN .   \ expect: -65

\ --- CODE block: multi-byte (16-bit BC pair) via 0x1234 ---
CODE MK_1234 BC PUSH, BC 0x1234 # LD, NEXT, END-CODE MK_1234 .  \ expect: 4660

\ --- CODE block: BASE-cross — prefix is parse-BASE-independent ---
HEX CODE MK_CDEC BC PUSH, C #100 # LD, B 0 # LD, NEXT, END-CODE MK_CDEC . DECIMAL   \ expect: 64 (100 decimal printed in HEX)
DECIMAL CODE MK_CHEX BC PUSH, C $ff # LD, B 0 # LD, NEXT, END-CODE MK_CHEX .        \ expect: 255

\ --- CODE block: BASE integrity across CODE + invoke ---
BASE @ . CODE MK_BS BC PUSH, C 0xFF # LD, B 0 # LD, NEXT, END-CODE BASE @ . MK_BS . BASE @ .
\ expect: 10 10 255 10

\ --- CODE block: ABORT on malformed prefix inside CODE (asm_cleanup rollback) ---
CODE C_BAD #ABC BC PUSH, NEXT, END-CODE   \ expect: #ABC ?  (asm_cleanup unlinks)
C_BAD .                                   \ expect: C_BAD ? (no survivor)

\ --- Cross-context single session: REPL + colon-body + CODE all in one ---
\ Verifies asm_mode and .pref_negate do not leak across context boundaries.
#42 . : F_MIX $FF ; F_MIX . CODE C_MIX BC PUSH, C 0xFF # LD, B 0 # LD, NEXT, END-CODE C_MIX .
\ expect: 42 255 255

\ --- FR47 spot-checks per parse context ---
\ Colon body: -42 must still route through NUMBER? (not the prefix pre-pass).
: F42N -42 ; F42N .      \ expect: -42
\ CODE block: bare unprefixed literal still works via NUMBER? fallthrough.
CODE MK_42 BC PUSH, C 42 # LD, B 0 # LD, NEXT, END-CODE MK_42 .   \ expect: 42
