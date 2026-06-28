\ Story 19.3 — bank-N hardware-smoke probes (Q4-γ isolated fixture)
\ INCLUDED P193BKN.FTH at the MicroBeast REPL after a fresh boot.
\ Default CL gives 12 banks ($22 + $35-$3F) so bank 5 is available.
\ Verdict encoding: each probe prints `result=-1 ` (= PASS) or `result=0 `
\ (= FAIL) between matching ---probe-19.3-X-start--- / -end--- sentinels.
\ Suite-end sentinel ---probe-19.3-suite-end--- confirms no mid-suite halt.
\
\ Probes D/E: testable on hardware (intra-bank stub allocation + dispatch).
\ Probes F/G: defer-sentinel only (cross-bank EXECUTE on DOVAR target +
\ bank-N CREATE/DOES> hit the kernel-side architectural-debt items
\ inherited from Story 19.2 + discovered at Story 19.3 dev-pass —
\ "NEXT-via-EXECUTE chokepoint" rework forward work). The kernel-side
\ defects affect hardware identically to the emulator; F and G stay
\ deferred on both surfaces.

\ Bank setup: P193IRON.FTH leaves BANKS=0 (its body ends with BANKS-CLEAR
\ per Story 17.6 hygiene). Re-establish the default 12-bank active list
\ before bank-N probes can run; mirrors what the CL-tail parser does on
\ fresh `antforth 22 35-3F` boot.
DECIMAL
$22 +BANK $35 +BANK $36 +BANK $37 +BANK $38 +BANK $39 +BANK
$3A +BANK $3B +BANK $3C +BANK $3D +BANK $3E +BANK $3F +BANK

\ === Probe-19.3-D — bank-5 CREATE allocates stub; LATEST = stub-xt; BANK-OF = 5
." ---probe-19.3-d-start---" CR
5 BANK!
HERE $9000 SWAP - ALLOT           \ bump bank-5 HERE into slot-2
CREATE _p193d-tgt 42 ,
LATEST @
DUP $D400 U< 0=
SWAP BANK-OF 5 =
AND
0 BANK!
." result=" . CR
." ---probe-19.3-d-end---" CR

\ === Probe-19.3-E — intra-bank EXECUTE-explicit on bank-5 CREATE'd word
." ---probe-19.3-e-start---" CR
5 BANK!
CREATE _p193e-tgt 42 ,
LATEST @
EXECUTE
@
42 =
0 BANK!
." result=" . CR
." ---probe-19.3-e-end---" CR

\ === Probe-19.3-F — cross-bank EXECUTE-explicit on CREATE'd word (DEFERRED)
\ Hangs the kernel because DOVAR-target cross-bank dispatch doesn't
\ fire sentinel-trampoline. Architectural-debt item.
." ---probe-19.3-f-start---" CR
." probe-19.3-f-deferred-on-cross-bank-dovar-sentinel-defect" CR
." ---probe-19.3-f-end---" CR

\ === Probe-19.3-G — bank-5 CREATE/DOES> (DEFERRED)
\ DOES> body in bank-N>0 hits DTC threading-through-stub-xt defect.
." ---probe-19.3-g-start---" CR
." probe-19.3-g-deferred-on-cross-bank-thread-defect" CR
." ---probe-19.3-g-end---" CR

." ---probe-19.3-suite-end---" CR
