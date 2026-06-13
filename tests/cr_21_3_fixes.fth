\ === CR 21.3 fix regressions — nested MARKER under the bounded snapshot ===
\
\ Isolated fixture: `make test-repl-cr-21-3`. Guards the CR-fix dev pass that
\ followed the Stories 21.1+21.2 code review (_bmad-output/implementation-
\ artifacts/21-3-code-review-findings.md):
\
\   #5  MARKER snapshots only the LIVE prefix of bank-table[] (snap_count =
\       max(bank_count, triple_owner+1) entries) instead of the full 174 B,
\       and DOMARKER reverts exactly that many. The snap_count count-field +
\       the owner+1 clause are the subtle parts: a NESTED MARKER must still
\       revert HERE to the pre-OUTER-marker value (the inner marker re-syncs
\       bank-table[owner] between the two, so the outer body must carry its own
\       owner-entry snapshot — which the bounded copy does because owner < snap_count).
\   #2  saved_here field dropped from the body — DOMARKER takes HERE from the
\       reloaded bank-table[owner] triple, so a correct HERE revert proves the
\       drop is sound.
\
\ Bank-0-only (the workable REPL pattern — feedback_phase4_probe_bank_switch_limitation):
\ all definitions land in bank 0, so no portal-window straddle. BANKS=12 at boot
\ here, so snap_count=12 and the snapshot spans banks 0..11 (bank 0 = the owner).

DECIMAL
0 BANK!

\ --- Probe-A: nested MARKER reverts HERE to the pre-outer-marker value -------
\ Capture HERE before the outer MARKER; nest a second MARKER + colon defs in
\ between; FORGET the outer marker; HERE must equal the captured value. The
\ inner marker re-syncs bank-table[0] between MA and MB, so a correct revert
\ proves the outer body snapshotted its OWN bank-0 owner entry (bounded copy
\ captures it because owner(0) < snap_count(12)). revert=-1 on success.
HERE                                \ ( h0 )
MARKER MA
: NW1 123 ;
MARKER MB
: NW2 456 ;
MA                                  \ FORGET to pre-MA state
HERE                                \ ( h0 h1 )
." ---probe-cr-a-start---" CR
= ." revert=" . CR                  \ -1 iff h1 == h0
." ---probe-cr-a-end---" CR

\ --- Probe-B: every nested-defined word forgotten after the outer FORGET -----
\ ' on a forgotten word raises -13; QUIT recovers line-by-line and the
\ interpret-error path prints `<name> ?`. NW1, NW2 (colon defs) and MB (the
\ inner marker) must all be gone.
." ---probe-cr-b-start---" CR
' NW1
' NW2
' MB
." ---probe-cr-b-end---" CR

\ --- Probe-C: dictionary still works after the bounded FORGET -----------------
\ A fresh definition compiles and runs cleanly post-revert — HERE/LATEST/
\ wordlist_head were reloaded coherently from the reverted owner triple.
: NWok 789 ;
." ---probe-cr-c-start---" CR
." ok=" NWok . CR                   \ ok=789 on success
." ---probe-cr-c-end---" CR

." ---probe-cr-suite-end---" CR
BYE
