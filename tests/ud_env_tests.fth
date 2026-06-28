\ ud_env_tests.fth - Story 23.4: UD. + ENVIRONMENT? wordset-presence rows.
\ Self-printing PASS:/FAIL: probe. Harness greps are COLUMN-0-ANCHORED
\ (^PASS: / ^FAIL: / ^udA= ...): runtime output lands at column 0, while the
\ echoed source (begins with ." , : , or whitespace) does not, so it cannot
\ false-green (the 23.2 lesson). Runs under iz-cpm via `make test-repl-ud-env`.
\
\ Coverage:
\   - AC1 UD.: 0. ; a >0x7FFF value ; full-range 4294967295. (no sign-flip) ; HEX.
\   - control: 4294967295. D. -> -1 (proves UD. != D. for a high-bit-set value).
\   - AC2/AC3 env: 3 complete sets -> ( true true ), 3 incomplete -> ( false true );
\     CORE (true), CORE-EXT (false), NOPE (single false) regression asserts.

\ --- AC5 pre-flight: UD. must resolve (interpret level; -13 here fails loud) ---
' UD. DROP

\ --- AC1 UD. decimal: tagged column-0 lines (Makefile asserts exact text) ---
." udA=" 0. UD. CR
." udB=" 4294967295. UD. CR
." udC=" 100000. UD. CR
\ --- no-sign-flip control: same value via D. prints -1 ---
." udD=" 4294967295. D. CR
\ --- AC1 UD. hex ---
HEX ." udE=" 1234ABCD. UD. CR DECIMAL

\ --- AC2/AC3 env queries: in-Forth self-assert ---
\ complete sets -> ( true true ): both cells -1, AND = -1
: _e1 S" EXCEPTION" ENVIRONMENT? AND -1 = IF ." PASS: env-excep" ELSE ." FAIL: env-excep" THEN CR ;
: _e2 S" EXCEPTION-EXT" ENVIRONMENT? AND -1 = IF ." PASS: env-excep-x" ELSE ." FAIL: env-excep-x" THEN CR ;
: _e3 S" SEARCH-ORDER" ENVIRONMENT? AND -1 = IF ." PASS: env-srch" ELSE ." FAIL: env-srch" THEN CR ;
\ incomplete sets -> ( false true ): flag=0, recognised=-1 -> 0= over flag, R> -1 = , AND = -1
: _e4 S" DOUBLE" ENVIRONMENT? >R 0= R> -1 = AND IF ." PASS: env-dbl" ELSE ." FAIL: env-dbl" THEN CR ;
: _e5 S" DOUBLE-EXT" ENVIRONMENT? >R 0= R> -1 = AND IF ." PASS: env-dbl-x" ELSE ." FAIL: env-dbl-x" THEN CR ;
: _e6 S" SEARCH-ORDER-EXT" ENVIRONMENT? >R 0= R> -1 = AND IF ." PASS: env-srch-x" ELSE ." FAIL: env-srch-x" THEN CR ;
\ regression: existing present key, existing incomplete key, miss (single false)
: _e7 S" CORE" ENVIRONMENT? AND -1 = IF ." PASS: env-core" ELSE ." FAIL: env-core" THEN CR ;
: _e8 S" CORE-EXT" ENVIRONMENT? >R 0= R> -1 = AND IF ." PASS: env-core-x" ELSE ." FAIL: env-core-x" THEN CR ;
: _e9 S" NOPE" ENVIRONMENT? DEPTH 1 = SWAP 0= AND IF ." PASS: env-miss" ELSE ." FAIL: env-miss" THEN CR ;
_e1 _e2 _e3 _e4 _e5 _e6 _e7 _e8 _e9
