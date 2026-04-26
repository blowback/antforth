\ throw_migration_tests.fth — Epic 11 Stories 11.4-11.7 — internal-error
\                              migration (ABORT → THROW) regression suite
\ AntForth — A Forth for CP/M on Z80
\
\ Covers the word-by-word migration of internal error sites from ABORT
\ to THROW per E11-D3 (architecture.md:302-306). One test per migrated
\ primitive minimum: ' WORD CATCH . asserts the THROW code lands on the
\ data stack, per the migration discipline rule in
\ feedback_repl_tests_preferred.md.
\
\ Each line is sent to the REPL with the expected stdout fragment in a
\ trailing `\ expect: <fragment>` comment. The Makefile `test-repl`
\ entries (tests 696..) are the authoritative runners — keep these in
\ sync. NOTE: at the REPL (interpret mode) we use `'` to obtain xts.
\ Inside colon definitions we must use `[']` (IMMEDIATE) because `'`
\ in antforth parses at execution time, not compile time.
\
\ Story 11.4 owns Sections 1 and 2 (stack underflow -4; divisor zero -10).
\ Story 11.5 will append Section 3 (compiler / dictionary / control flow).
\ Story 11.6 will append Section 4 (strings / I-O).
\ Story 11.7 will append Section 5 (ABORT / ABORT" retarget verification).
\
\ DIAGNOSTIC-FORMAT DEPENDENCY: The uncaught-recovery tests below assert
\ "error -4: stack underflow" / "error -10: division by zero" — those
\ description strings were seeded into throw_desc_table by Story 11.3
\ (src/exception.asm). If a future edit removes either entry, the
\ matching uncaught test will FAIL.
\
\ I*X PRESERVATION (Story 11.4.1): the Story 11.4 caveat that asserted
\ i*x cells could not be checked across kernel-internal THROW is CLOSED
\ by Story 11.4.1. The CATCH frame +2 slot now holds saved-BC (i*x's
\ TOS-cell value); THROW's caught path restores it to the data stack
\ via PUSH BC after LD SP, HL. Section 1.1 / 2.1 below assert the
\ full spec form including the i*x cells underneath the THROW code.

\ ============================================================
\ Section 1 — Stack underflow caught (-4) (AC #9)
\ ============================================================

\ --- Sample primitives across stack/arithmetic/memory categories ---
\ Each invokes the primitive on an empty stack so check_underflow
\ trips and raises -4 THROW; CATCH catches; -4 lands on the user stack.
' DROP CATCH .                          \ expect: -4  ok
' + CATCH .                             \ expect: -4  ok
' @ CATCH .                             \ expect: -4  ok
' ! CATCH .                             \ expect: -4  ok
' ROT CATCH .                           \ expect: -4  ok
' 2SWAP CATCH .                         \ expect: -4  ok

\ --- Positive control: DROP at depth 1 succeeds; CATCH returns 0 ---
5 ' DROP CATCH .                        \ expect: 0  ok

\ --- DEPTH-invariant after caught underflow (post-THROW DEPTH = 1) ---
\ Per Story 11.4 Note A, only the THROW code is reliably on top.
\ DEPTH itself pushes the depth, so it reads 1 and prints 1.
' DROP CATCH DEPTH .                    \ expect: 1  ok

\ --- Underflow inside DO-LOOP frame (review F3 analog from AC #18) ---
\ The LOOP body's DROP underflows on the second iteration (after the
\ first DROP empties the stack). THROW snap-back must skip the DO frame
\ on IX and land in the catching CATCH cleanly. Mirrors Story 11.3
\ test 694 which exercised the same DO-frame skip with an explicit
\ user-level THROW.
: TDOL 2 0 DO DROP LOOP ;
1 ' TDOL CATCH .                        \ expect: -4  ok

\ ============================================================
\ Section 1.1 — i*x preservation under caught underflow (Story 11.4.1)
\ ============================================================
\ Smallest reproducer of Story 11.4 Note A — pre-fix this printed
\ "-4 1483" (the 1 was clobbered by check_underflow's CALL ret-addr
\ byte). Post-Story-11.4.1: -4 fires, i*x's TOS-cell (= 1) is restored
\ to data stack via PUSH BC after LD SP, HL.
1 ' + CATCH . .                         \ expect: -4 1  ok

\ Three i*x cells preserved underneath caught -4 THROW. 2OVER needs 4
\ cells (BC + 3 SP); with 3 i*x cells (post-POP-BC depth=3), check_
\ underflow_4 trips and -4 THROW fires. Pre-fix the "3" was clobbered
\ by check_underflow_4's CALL ret-addr; post-fix all three cells survive.
\ (NB: AC #2 / AC #3 spec forms used `' DROP` which does not actually
\ underflow with 3 i*x cells — DROP needs only 1 SP cell. 2OVER is the
\ correct kernel word for the spec-form intent — see Story 11.4.1
\ Completion Notes "AC trace correction".)
1 2 3 ' 2OVER CATCH . . . .             \ expect: -4 3 2 1  ok
1 2 3 ' 2OVER CATCH . DEPTH .           \ expect: -4 3  ok    (combined value+depth per Story 11.4.1 review F6)

\ Two i*x cells preserved underneath caught -4 THROW. 2OVER needs 4
\ cells; with i*x=2 (post-POP-BC depth=2), check_underflow_4 trips
\ before any data-stack writes. Pre-fix the 2 was clobbered by the
\ ret-addr; post-fix both cells survive.
1 2 ' 2OVER CATCH . . .                 \ expect: -4 2 1  ok

\ ============================================================
\ Section 2 — Divisor zero caught (-10) (AC #9)
\ ============================================================

\ --- Single-cell divides (udivmod funnel): /, MOD, /MOD, */, */MOD ---
: T1 1 0 / ;
: T2 1 0 MOD ;
: T3 1 0 /MOD ;
: T4 1 1 0 */ ;
: T5 1 1 0 */MOD ;

' T1 CATCH .                            \ expect: -10  ok
' T2 CATCH .                            \ expect: -10  ok
' T3 CATCH .                            \ expect: -10  ok
' T4 CATCH .                            \ expect: -10  ok
' T5 CATCH .                            \ expect: -10  ok

\ --- Positive control: non-zero divisor returns the correct quotient ---
: P1 100 5 / ;
' P1 CATCH . .                          \ expect: 0 20  ok

\ --- Double-cell divides (UM/MOD funnel): UM/MOD, SM/REM, FM/MOD ---
\ M/MOD is not a kernel primitive in antforth (verified at write time);
\ omitted from this section per AC #9's conditional.
: T6 1 0 0 UM/MOD ;
: T7 1 0 0 SM/REM ;
: T8 1 0 0 FM/MOD ;

' T6 CATCH .                            \ expect: -10  ok
' T7 CATCH .                            \ expect: -10  ok
' T8 CATCH .                            \ expect: -10  ok

\ --- DEPTH-invariant after caught divisor-zero (post-THROW DEPTH = 1) ---
: TD 1 0 / ;
' TD CATCH DEPTH .                      \ expect: 1  ok

\ --- Edge case (review F2 watch): most-negative divisor does NOT false-trip ---
\ B = 0x80, C = 0x00 — OR C of 0x80 is non-zero, guard skipped, division
\ proceeds normally. Verifies the guard tests "BC == 0" not "BC < 0".
: PMN 1 -32768 / ;
' PMN CATCH . .                         \ expect: 0 0  ok

\ ============================================================
\ Section 2.1 — i*x preservation under caught divisor-zero (Story 11.4.1)
\ ============================================================
\ AC #4 spec form. T241 pushes 1 0 / which raises -10 THROW from the
\ udivmod divisor-zero guard added by Story 11.4. Post-fix the i*x
\ cells (5 6 7) are preserved underneath the -10 THROW code.
: T241 1 0 / ;
5 6 7 ' T241 CATCH . DEPTH .            \ expect: -10 3  ok    (combined value+depth per Story 11.4.1 review F6)
5 6 7 ' T241 CATCH . . . .              \ expect: -10 7 6 5  ok

\ ============================================================
\ Section 3 — Compiler / dictionary / control flow / assembler (Story 11.5)
\               (-13 / -14 / -16 / -258..-269)
\ ============================================================
\
\ AC #15 caveat: TICK (`'`) for an undefined name fires at execute time
\ in antforth (per tests/exception_tests.fth:13-15); within colon
\ definitions use [']. The undefined-word caught test at the colon-
\ thread level is best exercised via uncaught-recovery (Makefile)
\ since the `[']`-of-undefined form raises at compile time, before
\ the colon closes — outside any CATCH frame.
\
\ AC #15 caveat: assembler-error caught tests are deferred to uncaught-
\ recovery form (Makefile Section 3.4 blocks) because exercising
\ assembler errors via CATCH requires nested-compile shapes that are
\ non-trivial in antforth. The uncaught path validates that each
\ -258..-269 code reaches the user via the unified diagnostic; the
\ THROW code itself is identical on either path.

\ --- Section 3.1 — Compile-only guard caught (-14): ;, DOES>, ?COMP ---
\ All three are kernel words callable via `'` from the REPL. Each
\ raises -14 from the kernel-internal entry; CATCH catches; -14 lands.
' ; CATCH .                             \ expect: -14  ok
' DOES> CATCH .                         \ expect: -14  ok
' ?COMP CATCH .                         \ expect: -14  ok

\ --- i*x preservation across kernel-internal -14 raise (AC #15) ---
1 2 3 ' ; CATCH . . . .                 \ expect: -14 3 2 1  ok

\ --- Compile-only guard via DO-LOOP frame (review F3 analog) ---
\ ?COMP fired from inside a DO-LOOP body. The DO frame sits on IX
\ when the kernel-internal THROW fires; the snap-back must skip it.
: T3DOL 2 0 DO ?COMP LOOP ;
' T3DOL CATCH .                         \ expect: -14  ok

\ --- Positive controls: success path returns 0 ---
' DUP CATCH .                           \ expect: 0  ok
\ A successful CONSTANT (top-level — CONSTANT consumes its name from the
\ REPL parse area, so it cannot be wrapped inside a colon body without
\ the body's own compile-time INTERPRET trying to look up the name as a
\ word and raising -13). Verifies the success path of the migrated
\ CONSTANT site:
5 CONSTANT BAR BAR .                    \ expect: 5  ok

\ --- DEPTH-invariant after caught -14 (post-THROW DEPTH = 1) ---
' ; CATCH DEPTH .                       \ expect: 1  ok

\ ============================================================
\ Section 3.2 — Undefined-word and zero-length-name (uncaught form)
\ ============================================================
\ Caught-form coverage for -13 (TICK / INTERPRET) and -16 (no-name
\ parsers) is awkward at the REPL: TICK-of-undefined fires before
\ CATCH wraps; `:` / CREATE / CONSTANT / MARKER consume their own
\ name parse so they cannot be wrapped via CATCH directly. The
\ uncaught-recovery cases live in the Makefile blocks and verify
\ that (a) each catalogued THROW code lands with its description
\ text and (b) the REPL recovers cleanly to a live prompt.
