\ Story 19.3.1 D2 reproducer (ASCII-only).
\ Pre-fix: post-bank-cycle FIND on CR fails (-13). Post-fix: clean.
\ Bank setup mirrors default CL parser tail (12 banks).
DECIMAL
$22 +BANK $35 +BANK $36 +BANK $37 +BANK $38 +BANK $39 +BANK
$3A +BANK $3B +BANK $3C +BANK $3D +BANK $3E +BANK $3F +BANK

." ---p193bnk2-start---" CR
5 BANK!
HERE $9000 SWAP - ALLOT
CREATE _p193bnk2-tgt 42 ,
LATEST @
DUP $D400 U< 0=
SWAP BANK-OF 5 =
AND
0 BANK!
." result=" . CR
." ---p193bnk2-end---" CR
