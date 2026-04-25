\ exception_tests.fth — Epic 11 Story 11.2 — CATCH (normal-return)
\ AntForth — A Forth for CP/M on Z80
\
\ Covers CATCH normal-return behaviour (Forth 2014 / ANS Forth 1994
\ §9.6.1.0875): pure / producing / consuming xts, the CATCH-TOP USER
\ variable, nested CATCH frames (both normal-return), state-integrity
\ invariants (BASE / STATE / HERE / DEPTH), and the empty-stack
\ underflow ABORT path. THROW-side tests land in Stories 11.3+.
\
\ Each line is sent to the REPL with the expected stdout fragment in a
\ trailing `\ expect: <fragment>` comment. The Makefile `test-repl`
\ entries (tests 653..) are the authoritative runners — keep these in
\ sync. NOTE: at the REPL (interpret mode) we use `'` to obtain xts.
\ Inside colon definitions we must use `[']` (IMMEDIATE) because `'`
\ in antforth parses at execution time, not compile time.

\ --- Section 1: Pure / producing / consuming xts (AC #13, AC #14) ---
: NOOP ;
: DUP-DROP DUP DROP ;
: MAKE-42 42 ;
: MAKE-1-2 1 2 ;
: DROP-IT DROP ;
: ADD-IT + ;
: BL2 ['] BL EXECUTE ;
: A 1 ;
: B A A + ;

' NOOP CATCH .                          \ expect: 0  ok
5 ' DUP-DROP CATCH . .                  \ expect: 0 5  ok
' MAKE-42 CATCH . .                     \ expect: 0 42  ok
' MAKE-1-2 CATCH . . .                  \ expect: 0 2 1  ok
5 ' DROP-IT CATCH .                     \ expect: 0  ok
1 2 ' ADD-IT CATCH . .                  \ expect: 0 3  ok
' BL CATCH . .                          \ expect: 0 32  ok
' BL2 CATCH . .                         \ expect: 0 32  ok
' B CATCH . .                           \ expect: 0 2  ok
1 ' DUP CATCH . . .                     \ expect: 0 1 1  ok

\ --- Section 2: CATCH-TOP value preservation (AC #13 fifth, AC #17) ---
CATCH-TOP @ .                           \ expect: 0  ok
' NOOP CATCH . CATCH-TOP @ .            \ expect: 0 0  ok
' MAKE-42 CATCH . . CATCH-TOP @ .       \ expect: 0 42 0  ok

\ --- Section 3: Nested CATCH (both normal-return) (AC #13 sixth) ---
: INNER ['] BL CATCH ;
' INNER CATCH . . .                     \ expect: 0 0 32  ok

\ 3-level nested: outer wraps L2 wraps L1 wraps BL. Exercises a non-zero
\ prev-of-prev link in the middle frame; Story 11.3's THROW chain-walk
\ depends on the prev-link discipline being correct at depth.
: L1 ['] BL CATCH ;
: L2 ['] L1 CATCH ;
' L2 CATCH . . . .                      \ expect: 0 0 0 32  ok

\ Probe: CATCH-TOP inside an enclosing CATCH must be non-zero, and
\ restored to zero after the outer CATCH returns. After `' PROBE CATCH`
\ the stack is ( probe-saw-CT 0 ). `.` prints the 0 success code, then
\ `0= 0=` reduces probe-saw-CT to -1 (non-zero → 0 → -1) confirming
\ PROBE saw a non-zero CATCH-TOP, then CATCH-TOP @ confirms post-CATCH
\ value is 0. Avoids unstable rstack-address printing.
: PROBE CATCH-TOP @ ;
' PROBE CATCH . 0= 0= . CATCH-TOP @ .   \ expect: 0 -1 0  ok

\ --- Section 4: State integrity (AC #15) ---
HEX ' NOOP CATCH DROP BASE @ DECIMAL .  \ expect: 16  ok
STATE @ ' NOOP CATCH DROP STATE @ = .   \ expect: -1  ok
HERE ' NOOP CATCH DROP HERE = .         \ expect: -1  ok
1 2 3 DEPTH . ' NOOP CATCH DROP DEPTH . \ expect: 3 3  ok

\ --- Section 5: Empty-stack CATCH triggers stack-underflow ABORT ---
\ AC #3 / AC #17 / AC #18 — pre-Epic-11 ABORT path; Story 11.4 will
\ migrate to THROW -4. Until then `CATCH` on empty stack hits
\ check_underflow → "? Stack underflow" → ABORT → QUIT recovers to
\ "ok", and QUIT must reset CATCH-TOP to 0 (CCD-1 chain invariant).
CATCH                                   \ expect: ? Stack underflow  ok
CATCH-TOP @ .                           \ expect: 0  ok    (post-recovery CATCH-TOP zeroed)
