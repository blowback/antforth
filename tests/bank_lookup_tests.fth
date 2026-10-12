\ bank_lookup_tests.fth — +BANK duplicate refusal, the banked ceiling, and
\ cross-bank lookup of kernel words. Runs under iz-cpm-banking via
\ `make test-repl-bank-lookup`.
\
\ Two logical banks on one physical page share RAM, so one bank's WORD parse
\ at HERE overwrote the other's headers and broke the bucket chains: `_by` hid
\ BANK!, `_qk` and B0 hid CR. +BANK now refuses a page already listed. A bank
\ near $C000 also let WORD/PAD run into $C000+, which is fixed RAM holding
\ bank 0's dictionary; the banked ceiling is now $BF58 ($C000 less 168), and
WORD refuses tokens longer than 128 chars so EVALUATE can't exceed it either.
\
\ Results print on tagged lines (`blA=...`) that the Makefile asserts at
\ column 0; the echoed source starts with `."` or a word, so it can't match.
\ Bank-0 colon words are defined first, while bank-0 HERE is below $8000.
DECIMAL
: _dup2 ( -- ) $35 +BANK ;

\ --- Duplicate page refused, list unchanged; accepted after BANKS-CLEAR ---
0 BANK!  BANKS-CLEAR $22 +BANK $35 +BANK
." blA=" ' _dup2 CATCH . BANKS . CR
BANKS-CLEAR $22 +BANK $22 +BANK $22 +BANK $22 +BANK
." blB=" BANKS . CR
BANKS-CLEAR ." blC=" BANKS . $22 +BANK BANKS . CR

\ --- The three lookup repros, on distinct pages ---
BANKS-CLEAR $22 +BANK $35 +BANK $36 +BANK $37 +BANK $38 +BANK $39 +BANK $3A +BANK
2 BANK!  : _by 1 ;
3 BANK!
0 BANK!
." blD=" BANK@ . CR
1 BANK!  : _qk 1 ;
2 BANK!
CR
." blE=" 1 2 + . CR
0 BANK!

\ --- Ceiling: one-past-end $BF58 accepted, one byte over -8 ---
4 BANK!  $BF58 HERE - ALLOT  ." blF=" HERE U. CR
5 BANK!  $BF58 HERE - 1- ALLOT
2 ALLOT
." blG=" HERE U. CR
0 BANK!

\ --- Bank 0 has no ceiling: the same growth is accepted ---
$BF58 HERE - 1+ ALLOT  ." blH=" HERE U. CR

\ --- B0 straddles $C000 in bank 0. Bank 6 first tries the old brink $BFFE
\ (-8 now; a kernel without the ceiling accepts it, and the next token parsed
\ there overwrites B0), then goes to its ceiling, parses a 31-char token and a
\ TIB-length one and fills PAD. B0 must survive ---
$C000 HERE - 3 - ALLOT  42 VALUE B0
6 BANK!  $C000 HERE - 2 - ALLOT
$BF58 HERE - ALLOT
ABCDEFGHIJKLMNOPQRSTUVWXYZ01234
ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOP
PAD 84 66 FILL  ." blI=" PAD C@ . PAD 83 + C@ . CR
." blJ=" 1 2 + . CR
0 BANK!  ." blK=" B0 . CR

\ --- WORD caps tokens at 128 chars (-18 past that). From bank 6's ceiling a
\ 220-char EVALUATE token would otherwise reach $C034 and overwrite B0 ---
CREATE _LT 220 ALLOT  _LT 220 65 FILL
6 BANK!
_LT 128 ' EVALUATE CATCH  ." blL=" . 2DROP CR
_LT 220 ' EVALUATE CATCH  ." blM=" . 2DROP CR
0 BANK!  ." blN=" B0 . CR

\ --- Computed witness: only real execution prints 42 ---
." bl-alive=" 6 7 * . CR
