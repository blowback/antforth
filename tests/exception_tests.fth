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
\ AC #3 / AC #17 / AC #18 — Story 11.4 migrated do_underflow_error
\ to -4 THROW. `CATCH` on empty stack hits check_underflow → -4 THROW
\ → uncaught-handler prints "error -4: stack underflow" → QUIT
\ recovers to "ok", and QUIT must reset CATCH-TOP to 0 (CCD-1 chain
\ invariant).
CATCH                                   \ expect: error -4: stack underflow  ok
CATCH-TOP @ .                           \ expect: 0  ok    (post-recovery CATCH-TOP zeroed)

\ ===============================================================
\ Story 11.3 — `THROW` + uncaught-THROW REPL handler
\ ===============================================================
\ Covers Forth 2014 / ANS Forth 1994 §9.6.1.2275 `THROW` semantics:
\ n=0 no-op (Section 6), caught round-trip (Section 7), nested-CATCH
\ chain-walk (Section 8), uncaught diagnostic + REPL recovery
\ (Section 9). Per-line `\ expect:` fragments for single-line tests;
\ multi-line uncaught scenarios are exercised by Makefile blocks
\ that flatten output via `tr '\r\n' '  '` and ordered `grep -qE`.

\ --- Section 6: `THROW 0` no-op (AC #3) ---
1 2 0 THROW . .                         \ expect: 2 1  ok
0 0 THROW .                             \ expect: 0  ok

\ --- Section 7: Caught THROW round-trip (AC #1, AC #2, AC #8) ---
: T1 42 THROW ;
: T2 -13 THROW ;
' T1 CATCH .                            \ expect: 42  ok
' T2 CATCH .                            \ expect: -13  ok
1 2 3 ' T1 CATCH . . . .                \ expect: 42 3 2 1  ok
1 2 3 4 ' T1 CATCH DEPTH .              \ expect: 5  ok

\ --- Section 7.1: i*x preservation across colon-body THROW (Story 11.4.1) ---
\ Pre-Story-11.4.1, the `1 2 3 ' T1 CATCH . . . .` test above passed by
\ coincidence: T1's `LIT 42` PUSH BC=3 to [SP-2]=[old SP], restoring the
\ i*x's TOS-cell to its original memory location (with the same value).
\ The CATCH frame layout treated [old SP] as the i*x-TOS-cell holder,
\ which broke for any xt that did a CALL before any data-stack PUSH
\ (e.g. kernel primitives whose body started with CALL check_underflow_N).
\ Story 11.4.1 redesigned the frame: +2 now holds saved-BC (= i*x's
\ TOS-cell value), restored to data stack on THROW caught path.
\ Post-fix, this test passes by design.

\ --- Section 8: Nested CATCH semantics (AC #1) ---
: T3 -5 THROW ;
: N3 ['] T3 CATCH ;
' N3 CATCH . .                          \ expect: 0 -5  ok    (inner catches; outer normal-return)

: T4 -5 THROW ;
: N4 T4 ;
' N4 CATCH .                            \ expect: -5  ok      (outer catches; inner has no CATCH)

: T5 -5 THROW ;
: M5 T5 ;
: N5 M5 ;
' N5 CATCH .                            \ expect: -5  ok      (3-deep, only outermost catches)

: T6 -5 THROW ;
: M6 ['] T6 CATCH DROP -7 THROW ;
' M6 CATCH .                            \ expect: -7  ok      (inner catches, rethrows -7)

: T7 -5 THROW ;
: M7 ['] T7 CATCH ;
: N7 M7 ;
' N7 CATCH . .                          \ expect: 0 -5  ok    (3-deep, middle catches; outer normal-return)

\ Adversarial-review F2: most-negative 16-bit code through both paths.
\ -32768 = 0x8000; print_signed_dec_bc must emit "-32768" via the
\ unsigned-aware div_bc_by_e (negate-wraps-to-self idiom).
: T8 -32768 THROW ;
' T8 CATCH .                            \ expect: -32768  ok

\ Adversarial-review F3: THROW from non-colon IX frames. The 4-byte
\ DO-LOOP frame between the THROW site and the target CATCH frame is
\ abandoned wholesale by the IX restore (E11-D2 "snap back").
: DT 10 0 DO -5 THROW LOOP ;
' DT CATCH .                            \ expect: -5  ok

\ Adversarial-review F3: THROW mid-EXECUTE. EXECUTE adds an extra
\ return-addr frame on IX; the snap-back must skip past it.
: T9 -5 THROW ;
' T9 ['] EXECUTE CATCH .                \ expect: -5  ok

\ --- Section 8.1: i*x preservation under nested CATCH (Story 11.4.1 AC #12) ---
\ Inner CATCH catches -5; outer CATCH normal-returns with 0; the
\ pre-outer-CATCH i*x = (1, 2) is preserved underneath. Pre-fix
\ this would have shown garbage in place of the 1 / 2 cells; post-fix
\ it shows the spec form.
: T84 -5 THROW ;
: N84 ['] T84 CATCH ;
1 2 ' N84 CATCH . . . .                 \ expect: 0 -5 2 1  ok

\ --- Section 8.2: 3-level nested with inner-rethrow (review F4) ---
\ Outer wraps middle wraps T-throws-(-5). Middle CATCHes -5, DROPs it,
\ rethrows -7. Outer catches -7. Outer i*x = (11, 22) must survive
\ the middle frame's saved-BC slot remaining intact during the inner
\ unwind and reused on the outer THROW.
: TI3 -5 THROW ;
: MI3 ['] TI3 CATCH DROP -7 THROW ;
11 22 ' MI3 CATCH . . .                 \ expect: -7 22 11  ok

\ --- Section 8.3: i*x preservation across DO-LOOP frame snap-back (review F2) ---
\ Underflow inside a DO-LOOP body with multi-cell pre-CATCH i*x.
\ THROW snap-back must skip the 4-byte DO frame on IX AND the saved-BC
\ restore must repopulate i*x's TOS-cell at [SP_safe-2]. Pre-fix the
\ DO-frame skip worked but i*x's TOS-cell was clobbered by check_
\ underflow's CALL ret-addr.
: TDOL3 5 0 DO 2OVER LOOP ;
1 2 3 ' TDOL3 CATCH . . . .             \ expect: -4 3 2 1  ok

\ --- Section 9: Uncaught THROW + diagnostic + REPL recovery ---
\ AC #4 / AC #5. Multi-line scenarios live in the Makefile because the
\ diagnostic-then-recovery sequence requires `tr '\r\n' '  '`-flattened
\ output with ordered grep patterns. Sub-cases enforced by Makefile
\ tests 686..695 (see Makefile for canonical assertions):
\   - 42 THROW                       → "error 42"            (no description)
\   - -13 THROW                      → "error -13: undefined word"
\   - -1 THROW                       → "error -1: ABORT"     (Story 11.7 retargeted ABORT itself to -1 THROW)
\   - dictionary intact post-recovery (define HELLO, throw, run HELLO)
\   - BASE intact post-recovery     (HEX, throw, BASE @ DECIMAL .)
\   - asm_mode cleaned post-recovery (CODE BAD, throw, then CODE GOOD)
\   - CATCH-TOP zeroed post-recovery (throw, then CATCH-TOP @ .)
