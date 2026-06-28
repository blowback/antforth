\ === Story 22.3 — CODE-words-into-fixed-memory redirect probe (isolated) ==
\
\ Isolated fixture: `make test-repl-banking-isolated-22-3`. Kept out of the
\ main suite because every probe switches into a non-zero bank
\ (feedback_phase4_probe_bank_switch_limitation). Disposition source:
\ architecture.md PD-P4-15 (§9.1 closure) — "CODE words live in fixed memory
\ only ... reachable directly from fixed memory like the existing kernel
\ words." The redirect (Story 22.3) makes that literally true: a CODE word
\ defined while a non-zero bank is live lands in the fixed-memory (bank-0)
\ dictionary, gets NO banked descriptor stub, and is findable + executable
\ from every bank.
\
\ FOO ( -- 42 ) and BAR ( -- 7 ) are minimal push-a-constant CODE words
\ (TOS lives in BC; PUSH old TOS, load the literal, NEXT). Output is anchored
\ between literal sentinels and read back with awk + grep -qF in the Makefile.

DECIMAL

\ --- Probe-22.3-a (AC7a): fixed-memory placement -------------------------
\ Define FOO via CODE while bank 5 is live; ' FOO BANK-OF must report -1
\ (fixed memory / legacy CFA xt), NOT bank 5 — proving the body did not land
\ in the bank-5 window.
5 BANK!
CODE FOO BC PUSH, C 42 # LD, B 0 # LD, NEXT, END-CODE
." ---probe-22.3-a-start---" CR
' FOO BANK-OF ." bankof=" . CR
." ---probe-22.3-a-end---" CR

\ --- Probe-22.3-b (AC7b): cross-bank execute, no stub-dispatch hang -------
\ The same FOO runs in bank 5 (home) AND after 0 BANK! (cross-bank), each
\ producing 42 — direct fixed-memory reachability from every bank.
." ---probe-22.3-b-start---" CR
FOO ." home=" . CR
0 BANK!
FOO ." cross=" . CR
." ---probe-22.3-b-end---" CR

\ --- Probe-22.3-c (AC7c / AC5 witness): bank-0 baseline ------------------
\ A CODE word defined in bank 0 behaves exactly as before the redirect:
\ runs (BAR -> 7) and BANK-OF reports -1 (fixed). Control witness that the
\ bank-0 path is byte-for-byte the legacy path (the redirect is a no-op here).
CODE BAR BC PUSH, C 7 # LD, B 0 # LD, NEXT, END-CODE
." ---probe-22.3-c-start---" CR
BAR ." baseline=" . CR
' BAR BANK-OF ." barbank=" . CR
." ---probe-22.3-c-end---" CR

\ --- Suite end-sentinel: proves no mid-suite kernel halt ------------------
." ---probe-22.3-suite-end---" CR
BYE
