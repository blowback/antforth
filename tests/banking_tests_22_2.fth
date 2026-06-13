\ === Story 22.2 — REPL prompt bank-indicator probe (isolated) ============
\
\ Isolated fixture: `make test-repl-banking-isolated-22-2`. Kept out of the
\ main suite because every probe switches into a non-zero bank, which can
\ straddle the portal-window dictionary
\ (feedback_phase4_probe_bank_switch_limitation / ADR 19.5 DR-1). This probe
\ defines NO words in a banked context, so only kernel-word lookups happen
\ after the switch (safe, like 22.1's .BANKS / BANK!).
\
\ The indicator is emitted by the QUIT prompt, which interleaves with echoed
\ input in a piped session, so the robust observation is to call the named
\ kernel word (BANK-PROMPT) DIRECTLY and anchor its output between literals:
\   ." P=" (BANK-PROMPT) ." =" CR   ->   "P=[5]=" (shown) or "P==" (nothing).
\ (BANK-PROMPT) prints "[N]" iff prompt_show_bank is set AND current bank > 0;
\ otherwise it prints nothing. Refs: docs/banking-pointer-hazards.md (F4).

DECIMAL

\ --- Probe-22.2-a: flag ON + bank 5 -> indicator emits [5] ----------------
-1 PROMPT-SHOW-BANK
5 BANK!
." ---probe-22.2-a-start---" CR
." P=" (BANK-PROMPT) ." =" CR
." ---probe-22.2-a-end---" CR

\ --- Probe-22.2-b: bank 0 -> no bracket even with the flag still ON --------
0 BANK!
." ---probe-22.2-b-start---" CR
." P=" (BANK-PROMPT) ." =" CR
." ---probe-22.2-b-end---" CR

\ --- Probe-22.2-c: flag OFF + bank 5 -> no bracket ------------------------
0 PROMPT-SHOW-BANK
5 BANK!
." ---probe-22.2-c-start---" CR
." P=" (BANK-PROMPT) ." =" CR
." ---probe-22.2-c-end---" CR

0 BANK!
." ---probe-22.2-suite-end---" CR
BYE
