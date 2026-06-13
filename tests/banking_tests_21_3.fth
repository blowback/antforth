\ === Story 21.3 — Epic-21 close-out integration probe (north-star) ===
\
\ Isolated fixture: `make test-repl-banking-isolated-21-3`. Fresh antforth
\ under iz-cpm-banking with NO prior test-file accumulation (the main suite
\ straddles $8000 and would strand a non-zero-bank lookup — ADR 19.5 DR-1 /
\ feedback_phase4_probe_bank_switch_limitation, so this lives on its own).
\
\ NORTH-STAR: the Epic-21 bank-aware LIFECYCLE surface, observed end-to-end in
\ one breath — MARKER/FORGET revert each active bank's dictionary tail AND
\ reclaim the descriptor-stub allocator tail (reuse, not leak); QUIT re-asserts
\ the user's last interactive bank on an ABORT/THROW unwind, so a crash never
\ strands you in the bank the aborted thread happened to be in.
\
\ Re-specced from the epics-file probe (`MARKER ZZZ 5 BANK! : W5 ; 7 BANK!
\ : W7 ; 7 BANK! W5 ABORT`) per three dev-pass findings:
\   - ZZZ is created in bank 0, so FORGET runs from its HOME bank 0 — a banked
\     MARKER has no real dispatch stub; cross-bank invoke HANGS
\     (project_banked_marker_no_stub).
\   - W5 is a `:` word (descriptor stub, Epic 19.2), so `7 BANK! W5` IS a sound
\     cross-bank call from bank 7.
\   - every BANK! is typed interactively, so the last (`7 BANK!`) sets
\     saved_bank=7; after ABORT, QUIT re-asserts it -> BANK@ -> 7.
\ saved_bank has no exposing word; it is read indirectly via BANK@ post-recovery.
\ FORGET-reachability is read via `' name` (-> plain `<name> ?`), NOT explicit
\ FIND (which still resolves a forgotten word — project_banked_marker_no_stub).

DECIMAL

\ Self-contained slot-2 shadow reader (MBB_GET_PAGE, logical page 2) — the
\ blessed BIOS accessor; both surfaces model $FDDC correctly.
CODE MBB-GET-2 ( -- page )
  BC PUSH,          \ save old TOS to the data stack
  C 2 # LD,         \ C = logical page 2 (slot 2)
  $FDDC CALL,       \ MBB_GET_PAGE -> A = physical page
  C A LD,           \ C <- A (low byte)
  B 0 # LD,         \ B <- 0  (zero-extend to a cell)
  NEXT,
END-CODE

\ Setup: MARKER in home bank 0; throwaway `:` words across banks 5 and 7.
\ W5 leaves a sentinel 42 so the cross-bank call can be witnessed.
0 BANK!
MARKER ZZZ
5 BANK! : W5 42 ;
7 BANK! : W7 ;

\ --- Probe-21.3-a: cross-bank call W5 (bank 5) from bank 7, then ABORT -----
\ Dispatched via W5's descriptor stub; prints x5=42 (body ran, value survived
\ the data stack which is fixed memory). Then ABORT (-1 THROW) in bank 7.
7 BANK!
." ---probe-21.3-a-start---" CR
W5 ." x5=" . CR
." ---probe-21.3-a-end---" CR
ABORT

\ --- Probe-21.3-b: recovery — QUIT re-asserts saved_bank=7 ----------------
\ Runs only because QUIT looped past the ABORT and re-asserted the last
\ interactive bank. BANK@ -> 7 (the user's choice, never the stranded thread's).
." ---probe-21.3-b-start---" CR
." bank=" BANK@ . CR
." ---probe-21.3-b-end---" CR

\ --- Probe-21.3-c: stub-allocator-tail reclamation across FORGET ----------
\ From home bank 0: capture W5's stub xt (S1); FORGET via ZZZ; redefine in
\ bank 5; the fresh stub xt (S2) must EQUAL S1 — the allocator tail rolled back
\ and the region was reused. ZZZ (DOMARKER) preserves the data stack. result=-1.
0 BANK!
' W5
ZZZ
5 BANK! : Wr ; 0 BANK!
' Wr
." ---probe-21.3-c-start---" CR
= ." recl=" . CR
." ---probe-21.3-c-end---" CR

\ --- Probe-21.3-d: W5/W7 forgotten — ' name -> -13 -> plain `<name> ?` -----
\ Both bank-N words are unreachable after FORGET; QUIT catches each -13 and
\ resumes line-by-line. Recipe greps for `W5 ?` and `W7 ?`.
." ---probe-21.3-d-start---" CR
' W5
' W7
." ---probe-21.3-d-end---" CR

\ --- Probe-21.3-e: bank + slot-2 restored; defining resumes cleanly --------
\ After all the cross-bank traffic + FORGET we are cleanly back in bank 0 with
\ slot 2 mapping bank 0; a fresh definition compiles and runs. result=-1 iff
\ bank AND slot-2 page both unchanged across the verification.
." ---probe-21.3-e-start---" CR
BANK@ MBB-GET-2                      \ ( b0 s0 )
: Wok 1234 ;
Wok DROP
MBB-GET-2 BANK@                      \ ( b0 s0 s1 b1 )
>R ROT R> = >R = R> AND             \ ( verdict: b0==b1 AND s0==s1 )
." result=" . CR
." ---probe-21.3-e-end---" CR

." ---probe-21.3-suite-end---" CR
BYE
