\ Story 19.2 — bank-N hardware-smoke probes (Q4-γ isolated fixture)
\ INCLUDED P192BKN.FTH at the MicroBeast REPL after a fresh boot.
\ Default CL gives 12 banks ($22 + $35-$3F) so bank 5 is available.
\ Verdict encoding: each probe prints `result=-1 ` (= PASS) or `result=0 `
\ (= FAIL) between matching ---probe-19.2-X-start--- / -end--- sentinels.
\ Suite-end sentinel ---probe-19.2-suite-end--- confirms no mid-suite halt.

DECIMAL
." ---probe-19.2-d-start---" CR
5 BANK!
HERE $9000 SWAP - ALLOT           \ bump bank-5 HERE into slot-2 (H5 deferred to Story 19.5)
: _p192d-tgt 7 ;
LATEST @
DUP $D400 U< 0=
SWAP BANK-OF 5 =
AND
0 BANK!
." result=" . CR
." ---probe-19.2-d-end---" CR

." ---probe-19.2-f-start---" CR
5 BANK!
: _p192f-tgt 7 ;
LATEST @
EXECUTE
7 =
0 BANK!
." result=" . CR
." ---probe-19.2-f-end---" CR

." ---probe-19.2-g-start---" CR
5 BANK!
: _p192g-tgt 7 ;
LATEST @
0 BANK!
EXECUTE
BANK@
0 = SWAP 7 = AND
." result=" . CR
." ---probe-19.2-g-end---" CR

." ---probe-19.2-suite-end---" CR
