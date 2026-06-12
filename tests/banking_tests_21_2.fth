\ === Story 21.2 — saved-bank cell + interactive-BANK! recogniser + QUIT ===
\
\ Isolated fixture: `make test-repl-banking-isolated-21-2`. Fresh antforth
\ under iz-cpm-banking with NO prior test-file accumulation. Each probe sets
\ a bank, triggers ABORT/THROW, and reads the recovered bank with
\ `." bank=" BANK@ . CR` on a line AFTER the error — QUIT loops past the
\ THROW, re-asserts the saved interactive bank, and the next line runs.
\
\ Mechanism (shipped this story): the interpret loop's direct-execute path
\ recognises a TYPED `n BANK!` (token identity == BANK! AND include_top == 0)
\ and snapshots current_bank -> saved_bank; QUIT re-asserts saved_bank on
\ every REPL re-entry. A colon-internal BANK! or an INCLUDEd file's BANK!
\ does NOT update saved_bank (anti-stranding + F6). No Forth word exposes
\ saved_bank, so it is observed indirectly: after recovery BANK@ reports the
\ value QUIT restored. Refs: docs/antforth-banking-redesign.md §5.6;
\ architecture.md Findings F6 (interactive recogniser = STATE@ 0= AND depth=1).

DECIMAL

\ --- Probe-21.2-a (AC6a): interactive BANK! survives ABORT ----------------
\ Type `5 BANK!` (interactive -> saved_bank=5), then ABORT. QUIT recovers and
\ re-asserts; BANK@ -> 5. Recipe greps the block for `bank=5`.
0 BANK!
." ---probe-21.2-a-start---" CR
5 BANK!
ABORT
." bank=" BANK@ . CR
." ---probe-21.2-a-end---" CR

\ --- Probe-21.2-b (AC6b): colon-internal BANK! does NOT save -------------
\ _w7t is defined+executed in bank 0. Inside, `7 BANK!` runs nested (token at
\ the direct-execute path is _w7t, not BANK!) so saved_bank stays 0; `999
\ THROW` then strands current_bank=7. After recovery QUIT re-asserts saved=0
\ over the stranded 7, so BANK@ -> 0 (NOT 7). Core anti-stranding proof.
0 BANK!
: _w7t  7 BANK! 999 THROW ;
0 BANK!
." ---probe-21.2-b-start---" CR
_w7t
." bank=" BANK@ . CR
." ---probe-21.2-b-end---" CR

\ --- Probe-21.2-c (AC6c, F6): INCLUDEd BANK! must not pollute -------------
\ Interactive `3 BANK!` (saved=3), then INCLUDE a file whose body does
\ `5 BANK!` with include_top != 0 (so saved stays 3; current becomes 5).
\ ABORT; QUIT re-asserts saved=3, so BANK@ -> 3 (NOT 5). If the recogniser
\ wrongly counted the INCLUDEd BANK!, this would print 5.
0 BANK!
3 BANK!
." ---probe-21.2-c-start---" CR
INCLUDE P212INC.FTH
ABORT
." bank=" BANK@ . CR
." ---probe-21.2-c-end---" CR

." ---probe-21.2-suite-end---" CR
BYE
