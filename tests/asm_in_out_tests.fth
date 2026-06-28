\ asm_in_out_tests.fth — Story 23.1: IN, / OUT, Zilog dst-src operand order.
\ Asserts the emitted opcode bytes for all four IN,/OUT, addressing forms,
\ plus one deliberate bad-operand round. The inline assembler is MMU-agnostic
\ (these words run during ASM-mode parsing), so this probe runs under plain
\ iz-cpm via `make test-repl-asm`. It self-prints PASS:/FAIL: lines; the
\ harness strips echoed source (lines beginning with `."`) before matching.

DECIMAL

\ One minimal CODE word per addressing form. The body is just the I/O
\ instruction, so the first two bytes at the xt are the emitted opcode.
CODE _AIO-INC    A (C) IN,     NEXT, END-CODE
CODE _AIO-INN    A $74 # IN,   NEXT, END-CODE
CODE _AIO-OUTC   (C) A OUT,    NEXT, END-CODE
CODE _AIO-OUTN   $74 # A OUT,  NEXT, END-CODE

\ ( xt b0 b1 -- f )  true when the xt's first two emitted bytes equal b0 b1
: _aio2 ( xt b0 b1 -- f )  >R >R DUP C@ R> = SWAP 1+ C@ R> = AND ;

: _aio-run ( -- )
  ['] _AIO-INC 237 120 _aio2 IF
    ." PASS: asm-in-indirect (A (C) IN, = ED 78)"
  ELSE
    ." FAIL: asm-in-indirect"
  THEN CR
  ['] _AIO-INN 219 116 _aio2 IF
    ." PASS: asm-in-imm (A $74 # IN, = DB 74)"
  ELSE
    ." FAIL: asm-in-imm"
  THEN CR
  ['] _AIO-OUTC 237 121 _aio2 IF
    ." PASS: asm-out-indirect ((C) A OUT, = ED 79)"
  ELSE
    ." FAIL: asm-out-indirect"
  THEN CR
  ['] _AIO-OUTN 211 116 _aio2 IF
    ." PASS: asm-out-imm ($74 # A OUT, = D3 74)"
  ELSE
    ." FAIL: asm-out-imm"
  THEN CR
;
_aio-run

\ Deliberate bad operand: a non-A register with an immediate port is illegal
\ (only IN A,(n) / OUT (n),A exist). This must THROW -258 (asm_bad_operand).
\ Left UNCAUGHT so the REPL handler runs asm_cleanup and clears asm_mode; a
\ CATCH here would leave asm_mode set (Story 23.1 dev note). The harness
\ asserts the resulting `error -258: bad operand` line.
CODE _AIO-BAD  B $74 # IN,  NEXT, END-CODE
