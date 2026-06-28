\ === Story 21.1 — MARKER/FORGET per-bank tail + stub-allocator reclamation ===
\
\ Isolated fixture: `make test-repl-banking-isolated-21-1`. Fresh antforth
\ under iz-cpm-banking with NO prior test-file accumulation. Verdicts read
\ two ways by the Makefile recipe:
\   - content probes (a)/(c): an undefined word after FORGET prints the plain
\     `<word> ?` line (QUIT catches the -13 and resumes) — grep for it.
\   - computed probe (b): a Forth-side `result=-1` (TRUE = stub region reused).
\
\ Mechanism (shipped this story): MARKER (w_MARKER_cf) snapshots the full
\ 29-entry bank-table[] region (every bank's here/latest/wordlist_head triple)
\ AND the descriptor-stub allocator tail into its body; FORGET (DOMARKER)
\ restores both, so words defined in ANY bank since the MARKER are unreachable
\ and their stubs are reclaimed. Refs: docs/antforth-banking-redesign.md §5.4;
\ architecture.md §"Gap Analysis" :1027 ("MARKER stores both tails, FORGET
\ reverts both").
\
\ Lookups are driven from bank 0 (the only workable behavioural pattern — a
\ foreign-bank-mapped token lookup would strand at -13, ADR 19.5 DR-1
\ aliasing). A banked MARKER is invoked from its OWN home bank (probe c): it
\ has no real dispatch stub (xt = CFA in its bank window), so cross-bank
\ invocation from bank 0 is unsupported.

DECIMAL

\ --- Probe-21.1-a (AC6a): FORGET across banks ----------------------------
\ MARKER in bank 0; define _w5a in bank 5 and _w7a in bank 7 AFTER it; back to
\ bank 0 and FORGET. Both bank-N words must be gone: `' name` raises -13 and
\ QUIT prints the plain `<name> ?`. Recipe greps for `_w5a ?` and `_w7a ?`.
MARKER ZA
5 BANK! : _w5a ; 7 BANK! : _w7a ; 0 BANK!
ZA
." ---probe-21.1-a-start---" CR
' _w5a
' _w7a
." ---probe-21.1-a-end---" CR

\ --- Probe-21.1-b (AC6b): stub-allocator tail reclamation ----------------
\ The xt of a bank-N word IS its descriptor-stub address (allocated 4-byte
\ stride). Capture _p2's stub xt, FORGET, define _p3 in the same bank: its
\ stub xt must EQUAL _p2's, proving the allocator tail rolled back and the
\ region was reused (not leaked). verdict result=-1.
5 BANK! : _p1 ; 0 BANK!
MARKER ZB
5 BANK! : _p2 ; 0 BANK!
' _p2
ZB
5 BANK! : _p3 ; 0 BANK!
' _p3
." ---probe-21.1-b-start---" CR
= ." result=" . CR
." ---probe-21.1-b-end---" CR

\ --- Probe-21.1-c (AC6c): cross-bank-MARKER survival ---------------------
\ MARKER set while in bank 5; a word added in bank 7; FORGET via the
\ bank-5-set marker (invoked from its home bank 5) must reclaim bank 7's tail.
\ Back in bank 0, `' _wc7` raises -13 -> plain `_wc7 ?`.
5 BANK! MARKER ZC5
7 BANK! : _wc7 ; 5 BANK!
ZC5
0 BANK!
." ---probe-21.1-c-start---" CR
' _wc7
." ---probe-21.1-c-end---" CR

\ --- Probe-21.1-d (AC6b'): per-bank dictionary HERE rollback ----------------
\ ISOLATES the new bank-table[] restore (probes a/c only prove FIND-reachability,
\ which the pre-existing 192-byte bucket restore already reverts; this one proves
\ the per-bank HERE tail actually rolls back). Capture bank-5 HERE before the
\ MARKER (P), define a word in bank 5 after it so bank-5 HERE advances (Q>P),
\ FORGET, then re-read bank-5 HERE (R). With the bank-table[] restore, R==P
\ (rolled back); without it R would stay at Q. verdict result=-1 iff R==P AND Q<>P.
\ Verdict in a colon word so >R/R> stay balanced (interpret-level R-stack is the
\ text interpreter's). Defined in bank 0 BEFORE the MARKER, so FORGET keeps it.
: _vd  ROT DUP >R = SWAP R> = 0= AND ;   \ ( P Q R -- (R==P)AND(Q<>P) )
5 BANK! HERE 0 BANK!            \ ( P )  pre-MARKER bank-5 HERE
MARKER ZD
5 BANK! : _qd ; HERE 0 BANK!    \ ( P Q )  Q = post-_qd bank-5 HERE (Q > P)
ZD                             \ FORGET: bank-table[5].here must roll back to P
5 BANK! HERE 0 BANK!            \ ( P Q R )  R = bank-5 HERE after FORGET
." ---probe-21.1-d-start---" CR
_vd ." result=" . CR
." ---probe-21.1-d-end---" CR

." ---probe-21.1-suite-end---" CR
BYE
