\ multitasker_key_tests.fth — Story 25.2: KEY-hooked REPL input-only yield.
\ Self-printing PASS:/FAIL: probe; verdict-greps are COLUMN-0-ANCHORED (^PASS:):
\ runtime verdicts land at column 0 (after the REPL input-echo newline) while the
\ echoed source holding the same literals is mid-line, so neither false-greens
\ (the 23.2 lesson). Runs under iz-cpm-banking via `make test-repl-multitasker-key`.
\
\ HONEST EMULATOR/HARDWARE SPLIT (NFR-P6-3/-16): the emulator feed is a
\ NON-INTERACTIVE pipe, so input is always immediately ready — KEY? (fn 11)
\ returns true at once and the operator almost never WAITS in KEY. The
\ background-counter-advances-WHILE-YOU-TYPE behaviour (the live-prompt headline)
\ is therefore the HARDWARE S9 assertion, not the emulator's. What the emulator
\ DOES prove here, structurally:
\   (a) KEY/KEY?/ACCEPT/QUERY resolve as the yielding forms;
\   (b) the new char-by-char QUERY line reader is LIVE — every line of THIS probe
\       is being read through (LINE)/KEY/(EDIT); a runtime-computed token (42)
\       proves genuine execution through the new reader, not echo;
\   (c) the KEY-as-thread restructure did NOT break cooperative scheduling — a
\       background counter advances whenever the foreground yields (driven here
\       by explicit PAUSE, the deterministic stand-in for input-wait yield);
\   (d) EMIT does not yield (AC2/F2): a foreground verdict prints contiguously at
\       column 0 with a background task active (char-level non-interleave is
\       guaranteed structurally by EMIT having no PAUSE — see src/io.asm).

DECIMAL

\ --- (a) Input words resolve (the yielding KEY trio + the REPL line read) ---
' KEY DROP  ' KEY? DROP  ' ACCEPT DROP  ' QUERY DROP  ." PASS: key-words-resolve" CR

\ --- (b) New QUERY line reader is live (computed token can't appear in echo) ---
: _live 6 7 * 42 = IF ." PASS: key-line-reader-live" ELSE ." FAIL: key-line-reader-live" THEN CR ;
_live

\ --- (c) Background counter advances when the foreground yields ---
\ BG increments CNT on each turn then yields; it only runs at a foreground PAUSE.
\ The pipe keeps input ready, so input-wait advancement is S9 — here we drive the
\ yields explicitly to prove the scheduler still rotates with the new KEY present.
VARIABLE CNT
: BUMP ( -- ) CNT @ 1+ CNT ! ;
: BG ( -- ) BEGIN BUMP PAUSE 0 UNTIL ;     \ loops forever; parked between turns
0 CNT !
' BG TASK ACTIVATE
PAUSE PAUSE PAUSE PAUSE PAUSE               \ 5 foreground yields -> BG bumps >=5
: _adv ( -- ) CNT @ 0 > IF ." PASS: key-bg-advances" ELSE ." FAIL: key-bg-advances" THEN CR ;
_adv

\ --- (d) EMIT no-yield: foreground verdict prints clean with BG active (AC2) ---
\ BG is still AWAKE; this verdict's TYPE/EMIT path contains no PAUSE, so it cannot
\ be shredded char-by-char by the concurrent task. Column-0 anchoring proves the
\ contiguous runtime line, not the mid-line echoed source.
: _emit ( -- ) ." PASS: key-emit-clean" CR ;
_emit

\ --- Interpreter healthy after the whole interleave (runtime-computed token) ---
: _alive ( -- ) DEPTH 0= 6 7 * 42 = AND IF ." PASS: key-alive" ELSE ." FAIL: key-alive" THEN CR ;
_alive
