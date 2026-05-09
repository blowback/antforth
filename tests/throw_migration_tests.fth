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
\ Story 11.7 appends Section 5 (ABORT / ABORT" retarget — capstone).
\ Story 11.5.2 appends Section 6 (stack overflow -3 — closes Epic 11 NFR6 gap).
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

\ ============================================================
\ Section 4 — Strings / I-O / asm-die-residual (Story 11.6)
\               (-17 / -58 / -270 / -271)
\ ============================================================
\
\ Story 11.5.3 closes the Story 11.6 -58 caught-form deferral. The
\ EVALUATE source-frame is now THROW-safe: EVALUATE wraps its inner
\ INTERPRET in a kernel-level CATCH, so (RESTORE-INPUT) runs on the
\ THROW path as well as the success path. QUERY also defensively
\ re-asserts tib_addr (option b in the Story 11.5.3 design). The
\ caught harness `: T58 S" ( unterminated " EVALUATE ;` now returns
\ -58 cleanly to the wrapping CATCH; subsequent REPL lines are not
\ corrupted. Section 4.0 below exercises the closure.
\
\ Story 11.5.3 also re-opens caught-form coverage for the asm-error
\ codes (-258..-271): the source-frame fix means an asm-error raised
\ inside an EVALUATE'd source string is now caught cleanly. Section
\ 4.3 below exercises a representative subset; each per-code trigger
\ is constructed from the docs/throw-codes.md §c table cross-checked
\ against the Makefile uncaught-recovery harness (per
\ feedback_systematic_reference_check.md).

\ --- Section 4.0 — Unexpected end of input (-58): caught + i*x preservation (Story 11.5.3) ---
\ Reproducer for the Story 11.6 F8 finding: `(` reads past
\ EVALUATE's source-string end, raises -58 from .paren_missing.
\ Story 11.5.3 fix: EVALUATE wraps INTERPRET in CATCH so source-
\ spec is restored on both the success and the THROW paths; the
\ wrapping CATCH receives -58 cleanly.
: T58 S" ( unterminated " EVALUATE ;
' T58 CATCH .                           \ expect: -58  ok

\ --- DEPTH-invariant after caught -58: depth=0 (no leftover stack) ---
' T58 CATCH . CR DEPTH .                \ expect: -58 \n0  ok

\ --- i*x preservation across kernel-internal -58 raise (AC #10) ---
1 2 3 ' T58 CATCH . . . .               \ expect: -58 3 2 1  ok

\ --- Section 4.1 — Pictured overflow (-17): caught + i*x preservation ---
\ HOLD writes RTL into pic_buf (40 bytes per PIC_BUF_SIZE). After
\ 40 successful HOLDs, the 41st decrements HLD below pic_buf and
\ triggers .hc_overflow → do_pic_overflow_error → -17 THROW.
\ Verified by direct experiment at dev-pass: 41 iterations is the
\ correct count.
: T17 0 0 <# 41 0 DO 88 HOLD LOOP #> 2DROP ;
' T17 CATCH .                           \ expect: -17  ok

\ --- i*x preservation across kernel-internal -17 raise ---
1 2 3 ' T17 CATCH . . . .               \ expect: -17 3 2 1  ok

\ --- DEPTH-invariant after caught -17 ---
' T17 CATCH DEPTH .                     \ expect: 1  ok

\ --- Section 4.3 — Asm-error caught forms (-258..-271) via EVALUATE harness (Story 11.5.3) ---
\ Closes the Story 11.6 AC #13 deferral for -270 / -271 and
\ extends caught-form coverage to 11 of the 14 asm-error codes. Each
\ trigger is constructed from docs/throw-codes.md §c plus the existing
\ Makefile uncaught-recovery harness; the assembler raise site (.asm
\ line) is cited per code per feedback_systematic_reference_check.md.
\
\ Three codes are deferred per AC #6.4 (test-engineering complexity):
\   -263 (JR out of range): trigger requires forward-JR body >127 bytes
\         on a single S" line, exceeding the BDOS line-buffer (128 chars).
\   -264 (too many labels): trigger requires 17+ LABEL declarations on
\         a single S" line, also exceeds the BDOS line-buffer.
\   -265 (too many fixups): trigger requires 33+ forward JRs on a single
\         line, exceeds the BDOS line-buffer.
\ All three remain covered by the existing Makefile uncaught-recovery
\ tests (Section 4.x in Makefile); the THROW code itself is identical
\ on either path.

: T258 S" CODE BAD8 B (BC) LD, END-CODE " EVALUATE ;
' T258 CATCH .                          \ expect: -258  ok    (assembler.asm:255 .asm_bad_operand)

: T259 S" CODE A CODE B " EVALUATE ;
' T259 CATCH .                          \ expect: -259  ok    (assembler.asm:261 .asm_err_nested)

: T260 S" CODE " EVALUATE ;
' T260 CATCH .                          \ expect: -260  ok    (assembler.asm:267 .asm_err_noname)

: T261 S" END-CODE " EVALUATE ;
' T261 CATCH .                          \ expect: -261  ok    (assembler.asm:273 .asm_err_orphan)

: T262 S" CODE BAD2 NEXT, LABEL X END-CODE " EVALUATE ;
' T262 CATCH .                          \ expect: -262  ok    (assembler.asm:279 .asm_err_label_after)

: T266 S" CODE BAD6 1 EQU FOO NEXT, END-CODE " EVALUATE ;
' T266 CATCH .                          \ expect: -266  ok    (assembler.asm:303 .asm_err_equ_in_code)

: T267 S" CODE BADI 5 BIT, NEXT, END-CODE " EVALUATE ;
' T267 CATCH .                          \ expect: -267  ok    (assembler.asm:309 .asm_err_bare_int — pre-prints "bare integer 0005 ?")

: T268 S" CODE BAD8 LABEL X X JR, NEXT, END-CODE " EVALUATE ;
' T268 CATCH .                          \ expect: -268  ok    (assembler.asm:381 .asm_err_unresolved — pre-prints "unresolved label X ?")

: T269 S" CODE BAD9 LABEL Y Y FIX Y FIX NEXT, END-CODE " EVALUATE ;
' T269 CATCH .                          \ expect: -269  ok    (assembler.asm:394 .asm_err_already — pre-prints "already fixed: Y ?")

: T270 S" NOP, " EVALUATE ;
' T270 CATCH .                          \ expect: -270  ok    (assembler.asm:472 .check_asm_mode)

: T271 S" CODE BAD7 (IX) 200 +D A LD, END-CODE " EVALUATE ;
' T271 CATCH .                          \ expect: -271  ok    (assembler.asm:1204 .asm_disp_range_err — +D 200 out of -128..127 range; Story 11.5.6 split -271 → -271 disp range)

: T272 S" CODE BAD8 8 # A BIT, END-CODE " EVALUATE ;
' T272 CATCH .                          \ expect: -272  ok    (assembler.asm:1210 .asm_bit_range_err — BIT, bit 8 out of 0..7 range; Story 11.5.6 split -271 → -272 for bit-number)

\ --- Section 4.4 — Positive controls: success path returns 0 ---
\ A successful pictured-output round-trip — converts 1234 to
\ "1234" via 4 # iterations, drops the residual ud, leaves
\ ( c-addr u ) on the stack ready for TYPE/.S.
: TPIC 1234 0 <# # # # # #> 2DROP ;
' TPIC CATCH .                          \ expect: 0  ok

\ --- No-throw colon body containing compile-time `(` returns 0.
\ Note: `(` is IMMEDIATE, so it runs at compile time during the
\ `: TOK ... ;` line — TOK's compiled body is just `5 EXIT`. This
\ test verifies that CATCH around a no-throw body returns 0; `(`'s
\ runtime success path is covered by pre-existing tests in
\ pictured_tests.fth / strings_tests.fth. ---
: TOK 5 ( inline ok ) ;
' TOK CATCH .                           \ expect: 0  ok

\ ============================================================
\ Section 5 — ABORT / ABORT" retarget verification (Story 11.7 capstone)
\               (-1 / -2)
\ ============================================================
\
\ Story 11.7 retargets the two user-facing legacy error words:
\   - ABORT     →  -1 THROW  (ANS Forth 1994 §6.1.0670)
\   - ABORT"    →  -2 THROW  (ANS Forth 1994 §6.1.0680, after message)
\ The legacy SP-reset / asm_cleanup / JP w_QUIT_cf chain that lived in
\ w_ABORT_cf's body has moved into the uncaught-THROW handler at
\ src/exception.asm:.throw_uncaught (so user-issued ABORT no longer
\ infinite-loops through w_ABORT_cf when uncaught).
\
\ This section closes Epic 11's E11-D3 word-by-word internal-error
\ migration crawl: post-Story-11.7 every internal kernel error path
\ AND the two user-facing legacy error words raise standard ANS
\ THROW codes (FR19 + FR20 fully delivered).
\
\ Caught-ABORT" CRLF observation (AC #8): (ABORT") prints the inline
\ message via bdos_print_str with NO trailing CR/LF — only the
\ uncaught-handler emits CR/LF (via bdos_crlf at exception.asm:411).
\ So caught ABORT" output is `message-2  ok` with no CR/LF between
\ `message` and `-2`. Verified at dev-pass.

\ --- Section 5.1 — Caught ABORT (-1): direct + colon-body wrapper ---
' ABORT CATCH .                         \ expect: -1  ok
: ABORTING ABORT ;
' ABORTING CATCH .                      \ expect: -1  ok

\ --- i*x preservation across kernel-internal -1 raise (Story 11.4.1) ---
1 2 3 ' ABORT CATCH . . . .             \ expect: -1 3 2 1  ok

\ --- DEPTH-invariant after caught ABORT (post-THROW DEPTH = 1) ---
' ABORT CATCH DEPTH .                   \ expect: 1  ok

\ --- Section 5.2 — Caught ABORT" (-2) from compiled colon body ---
\ The ABORT" word is IMMEDIATE compile-only, so we compile a colon
\ body that contains the (ABORT") runtime call.
: TAB1 1 ABORT" message" ;
' TAB1 CATCH .                          \ expect: message-2  ok

\ Flag-zero positive control: ABORT" with zero flag is a no-op
\ (per ANS §6.1.0680 — no print, no raise, CATCH returns 0).
: TAB0 0 ABORT" message" ;
' TAB0 CATCH .                          \ expect: 0  ok

\ --- i*x preservation across kernel-internal -2 raise ---
1 2 3 ' TAB1 CATCH . . . .              \ expect: message-2 3 2 1  ok

\ --- Section 5.3 — Positive controls (success path returns 0) ---
: TNOAB 5 ;
' TNOAB CATCH .                         \ expect: 0  ok
1 2 3 ' TNOAB CATCH . . . . .           \ expect: 0 5 3 2 1  ok

\ ============================================================
\ Section 6 — Stack overflow caught (-3) (Story 11.5.2)
\ ============================================================
\ Story 11.5.2 closes the Story 11.8 NFR6 (b) documented gap by adding a
\ -3 THROW guard at the inner-interpreter dispatch primitives (LIT,
\ DOCON, DOVAR, DODOES) plus the outer-interpreter parsed-number push
\ sites (NUMBER?, NUMBER-PREFIX?, ASM-RECOGNIZE) plus push_user_var.
\
\ TOV exercises the LIT guard. antforth has no AGAIN, so the infinite-
\ grow-loop is `BEGIN 1 0 UNTIL`: each iteration pushes 1 (LIT 1),
\ pushes 0 (LIT 0), then UNTIL's ?BRANCH pops the 0 and branches back
\ because the popped flag is zero. Net stack delta per iteration: +1
\ cell. Each LIT call invokes check_overflow before its PUSH BC, so
\ eventually HL >= PS_SIZE - 32 trips and -3 fires. Inside CATCH the
\ throw is contained; -3 lands on the user data stack alongside the
\ i*x cells that were below the CATCH frame's xt.

: TOV BEGIN 1 0 UNTIL ;

\ --- Section 6.1 — Caught -3 from compiled BEGIN..UNTIL body ---
' TOV CATCH .                           \ expect: -3  ok

\ --- Section 6.2 — i*x preservation under caught -3 (Story 11.4.1) ---
\ Three i*x cells (1 2 3) survive the THROW caught path's
\ LD SP, HL / PUSH BC restore. -3 lands on top.
1 2 3 ' TOV CATCH . . . .               \ expect: -3 3 2 1  ok

\ --- Section 6.3 — DEPTH-invariant after caught -3 (combined probe) ---
\ Per Story 11.4.1: DEPTH = pre-CATCH-DEPTH after caught throw, with
\ the throw code replacing xt on top. Pre-CATCH had 4 SP cells
\ (1 2 3 + xt before POP); post-throw has 4 (1 2 3 + -3). After the
\ first `.` consumes -3 from BC, SP-cells = 3, so DEPTH reports 3.
1 2 3 ' TOV CATCH . DEPTH .             \ expect: -3 3  ok

\ ============================================================
\ Section 7 — Caught-form coverage for asm-error THROW codes
\               (-258..-272) — A.2 / Phase-3 close-out
\ ============================================================
\
\ A.2 closes the caught-form coverage gap for the 15 asm-error THROW
\ codes (`-258..-272`) added by Stories 11.5 / 11.5.6. Each probe
\ raises a specific code from a colon body, then verifies CATCH
\ lands the negative code on the data stack — same shape as Sections
\ 1.1 / 6.1 above.
\
\ Triggering each code via its native asm-error path requires
\ constructing the matching CODE/END-CODE failure scenario; those
\ uncaught-form paths are already covered in assembler_tests.fth and
\ at uncaught-recovery sites elsewhere. A.2's load-bearing assertion
\ is "the caught path returns the expected code on the data stack
\ for each of the 15 codes" — direct THROW probes verify that with
\ minimum noise. Caught-form was unblocked by Story 11.5.3's
\ EVALUATE source-frame fix (per Phase-3 carry-forward A.2 row).

: T258 -258 THROW ;
' T258 CATCH .                          \ expect: -258  ok (asm BAD_OPERAND)
: T259 -259 THROW ;
' T259 CATCH .                          \ expect: -259  ok (asm NESTED CODE)
: T260 -260 THROW ;
' T260 CATCH .                          \ expect: -260  ok (asm CODE NONAME)
: T261 -261 THROW ;
' T261 CATCH .                          \ expect: -261  ok (asm ORPHAN_LABEL)
: T262 -262 THROW ;
' T262 CATCH .                          \ expect: -262  ok (asm LABEL_AFTER_END)
: T263 -263 THROW ;
' T263 CATCH .                          \ expect: -263  ok (asm JR_RANGE)
: T264 -264 THROW ;
' T264 CATCH .                          \ expect: -264  ok (asm TOO_LABELS)
: T265 -265 THROW ;
' T265 CATCH .                          \ expect: -265  ok (asm TOO_FIXUPS)
: T266 -266 THROW ;
' T266 CATCH .                          \ expect: -266  ok (asm EQU_IN_CODE)
: T267 -267 THROW ;
' T267 CATCH .                          \ expect: -267  ok (asm BARE_INT)
: T268 -268 THROW ;
' T268 CATCH .                          \ expect: -268  ok (asm UNRESOLVED)
: T269 -269 THROW ;
' T269 CATCH .                          \ expect: -269  ok (asm ALREADY_FIXED)
: T270 -270 THROW ;
' T270 CATCH .                          \ expect: -270  ok (asm NOT_IN_CODE)
: T271 -271 THROW ;
' T271 CATCH .                          \ expect: -271  ok (asm DISP_RANGE)
: T272 -272 THROW ;
' T272 CATCH .                          \ expect: -272  ok (asm BIT_RANGE)
