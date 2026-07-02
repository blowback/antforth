\ multitasker_bank_tests.fth — Story 25.5: conditional MBB_SET_PAGE re-page in
\ PAUSE's resume tail. Self-printing PASS:/FAIL: probe; the harness verdict-greps
\ are COLUMN-0-ANCHORED (^PASS:/^FAIL:), so echoed source holding the same
\ literals (indented in colon bodies / mid-line at top level) cannot false-green
\ (the 23.2 lesson). Runs under iz-cpm-banking (make test-repl-multitasker-bank);
\ the default CL tail brings up 12 banks, so a real cross-bank task is establishable.
\
\ WHAT THE EMULATOR PROVES = STRUCTURE (project-lead resolution, story OQ#1): a
\ task activated in bank 1 round-robins with the bank-0 operator across explicit
\ PAUSEs with no corruption, and the operator's own BANK@ reads 0 afterward. A
\ re-page that WEDGES the BIOS call or corrupts IY/sp_base breaks the round-robin
\ or the liveness gate -> FAIL. It does NOT discriminate the *physical* slot-2 map:
\ the accumulator lives below $8000 (always mapped), step 5 reloads DE/BC/IX/SP
\ wholesale, and QUIT re-asserts the operator's saved bank between lines — so true
\ cross-bank WINDOW CONTENTS + wall-clock "no visible lag" ride S9 hardware
\ (NFR-P6-14). The emulator asserts the switch happens and survives, not the map.

DECIMAL

\ --- Word-existence pre-flight: the switch needs PAUSE + the banking words ---
' PAUSE DROP  ' BANK! DROP  ' BANK@ DROP  ' ACTIVATE DROP  ." PASS: bank-words-resolve" CR

\ --- >1 bank active (the default CL tail populates 12) so bank 1 exists ---
: _multi ( -- ) BANKS 1 > IF ." PASS: bank-multi-active" ELSE ." FAIL: bank-multi-active" THEN CR ;
_multi

\ --- Cross-bank round-robin witness (mirrors the 25.1 TAPE proof) ------------
\ TAPE is a shared bank-0 accumulator each task appends its digit to on its turn
\ (operator->1, background->2). Strict alternation builds a fixed value = the
\ deterministic round-robin proof; here every operator<->BG switch crosses a bank
\ boundary (BG owns bank 1, operator bank 0) so each PAUSE re-pages slot 2.
VARIABLE TAPE
: APP ( d -- ) TAPE @ 10 * + TAPE ! ;
: BG ( -- ) 2 APP PAUSE 2 APP ;             \ 2 turns, then EXIT -> task_exit (ASLEEP+PAUSE)
: DRV ( -- ) 1 APP PAUSE 1 APP PAUSE 1 APP ;

0 TAPE !
' BG TASK            \ ( xt task ) — carve the TCB while the operator is in bank 0
1 BANK!              \ operator -> bank 1 (BANK! consumes the 1)
ACTIVATE             \ task inherits current_bank = 1 from the operator ( xt task -- )
0 BANK!              \ operator -> bank 0; the TASK now owns bank 1
DRV                  \ interleave: each PAUSE crosses banks -> conditional re-page fires
: _rr ( -- ) TAPE @ 12121 = IF ." PASS: bank-task-advances" ELSE ." FAIL: bank-task-advances" THEN CR ;
_rr

\ --- Operator's own bank restored after driving the cross-bank switches ------
\ The last switch back to the operator re-paged slot 2 to bank 0 AND restored the
\ current_bank cell; BANK@ = 0 confirms the operator window survived the round.
: _opbank ( -- ) BANK@ 0 = IF ." PASS: operator-bank-restored" ELSE ." FAIL: operator-bank-restored" THEN CR ;
_opbank

\ --- Same-bank control: a bank-0 task must round-robin with the re-page ELIDED
\ (CP B -> JR Z taken), proving the added compare doesn't break the common case.
VARIABLE TAPE2
: APP2 ( d -- ) TAPE2 @ 10 * + TAPE2 ! ;
: BG2 ( -- ) 2 APP2 PAUSE 2 APP2 ;
: DRV2 ( -- ) 1 APP2 PAUSE 1 APP2 PAUSE 1 APP2 ;
0 TAPE2 !
' BG2 TASK ACTIVATE  \ activated while operator is in bank 0 -> every switch same-bank
DRV2
: _same ( -- ) TAPE2 @ 12121 = IF ." PASS: bank-same-control" ELSE ." FAIL: bank-same-control" THEN CR ;
_same

\ --- Interpreter healthy after the whole interleave (runtime-computed token) --
: _alive ( -- ) DEPTH 0= 6 7 * 42 = AND IF ." PASS: bank-alive" ELSE ." FAIL: bank-alive" THEN CR ;
_alive
