\ === Story 19.4 — Epic-19 close-out integration probe (isolated fixture) ===
\
\ Surface: `make test-repl-banking-isolated-19-4` — fresh antforth process
\ under iz-cpm-banking with NO prior test-file accumulation (mirrors the
\ Story 19.2/19.3 isolated-fixture pattern).
\
\ AC5 (Story 19.4): a SINGLE probe exercises the *verified* Epic-19
\ bank-aware compiler mechanism end-to-end, in one breath, **via the
\ EXECUTE-explicit dispatch path ONLY**:
\   1. boot with defaults; `5 BANK!`;
\   2. `: _p194a-tgt 100 ;` defines a colon body into bank 5 (bank-aware
\      `:` lands the body in bank-5 RAM + auto-emits a descriptor stub
\      on `;` — Story 19.2 mechanism);
\   3. `LATEST @` captures the stub-xt;
\   4. `LATEST @ BANK-OF` returns 5 (descriptor-stub byte-0 read — Story
\      18.4 / 19.3 mechanism) AND the stub-xt sits in the $D400+ region;
\   5. `LATEST @ EXECUTE` (intra-bank, still in bank 5) dispatches the
\      body and returns 100 (src/inner_interpreter.asm intra_bank path);
\   6. `0 BANK!` then `<xt> EXECUTE` (cross-bank) dispatches via the
\      RST-$28 stub + xbank_thunk/xbank_restore (Story 19.5.2; the
\      Story 18.2/18.3 sentinel-trampoline this probe originally rode
\      is RETIRED) and returns 100 with the caller's bank restored to 0.
\
\ NORTH-STAR UX SCOPE NOTE: the compiled-body symbolic-invocation form
\ `0 BANK! _p194a-tgt .` (calling a banked word *by name* from a compiled
\ definition / the REPL) is **OUT OF SCOPE for Epic 19** and is NOT
\ exercised here. At Epic-19 close it was blocked by TWO root defects
\ anchored on the Epic 19.5 stabilization interlude — (a) the DTC
\ threading-through-stub-xt defect and (b) the cross-bank trampoline
\ assuming a DOCOL/EXIT pair. Story 19.5.2 retired both (RST-$28
\ self-dispatching stubs; trampoline replaced by xbank_thunk/
\ xbank_restore — see src/banking.asm stub_dispatch); behavioural
\ re-verification of the by-name UX is Story 19.5.3 scope. Epic 19
\ shipped the verified MECHANISM via EXECUTE-explicit, asserted here.
\
\ COLON-BODY (not CREATE) was deliberate at Epic-19 close: cross-bank
\ EXECUTE of a CREATE'd DOVAR target hung the then-live sentinel-
\ trampoline (Probe-19.3-F, root cause (b) above). Post-19.5.2 the
\ non-DOCOL shape is witnessed by probe-19.5.2-b
\ (tests/banking_tests_19_3.fth); this probe keeps the colon body as
\ the Epic-19 close-out signature.
\
\ Verdict: single integer printed via `.` — -1 (TRUE) = PASS, 0 = FAIL.
\ The Makefile recipe greps `result=-1` inside the sentinel window. Bank-N
\ HERE bump (`HERE $9000 SWAP - ALLOT`) per the Story 19.2/19.3 workaround
\ (H5 COLD-init fix anchored on Epic 19.5). Target name `_p194a-tgt` per
\ the disambiguated hash-collision-avoidance convention.

DECIMAL

\ === Probe-19.4-A — Epic-19 verified mechanism, end-to-end (EXECUTE-explicit)
." ---probe-19.4-a-start---" CR
5 BANK!
HERE $9000 SWAP - ALLOT           \ bump bank-5 HERE into slot-2 (H5 deferred to Epic 19.5)
: _p194a-tgt 100 ;                 \ bank-aware `:` lands body in bank 5 + stub on `;`
LATEST @                           \ ( xt )
DUP BANK-OF 5 =                    \ ( xt v1 )      BANK-OF = 5
OVER $D400 U< 0= AND               \ ( xt v12 )     stub-xt in $D400+ region
OVER EXECUTE 100 = AND             \ ( xt v123 )    intra-bank EXECUTE -> 100 (still bank 5)
SWAP                               \ ( v123 xt )
0 BANK!                            \ caller now bank 0; stub-xt portable (FR-P4-17)
EXECUTE                            \ ( v123 100 )   cross-bank EXECUTE via RST-$28 stub (19.5.2)
100 =                              \ ( v123 v4a )
BANK@ 0 = AND                      \ ( v123 v4 )    result=100 AND caller bank restored to 0
AND                                \ ( verdict-flag: -1=PASS iff all four legs pass )
." result=" . CR
." ---probe-19.4-a-end---" CR

." ---probe-19.4-suite-end---" CR
BYE
