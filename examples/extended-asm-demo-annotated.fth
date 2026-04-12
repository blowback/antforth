\ === AntForth Extended Z80 Assembler Demo ===
\ Showcasing CB-prefix bit ops, rotates, INC/DEC, and labels

\ --- BIT OPERATIONS (CB prefix) ---

\ Clear bit 5 to force ASCII uppercase
\ Assembles: LD A,C / RES 5,A / LD C,A / LD B,0
CODE >UPPER A C LD, 5 # A RES, C A LD, B 0 # LD, NEXT, END-CODE

\ Set bit 5 to force ASCII lowercase
\ Assembles: LD A,C / SET 5,A / LD C,A / LD B,0
CODE >LOWER A C LD, 5 # A SET, C A LD, B 0 # LD, NEXT, END-CODE

\ --- ROTATES (CB prefix) ---

\ Rotate byte left circular
\ Assembles: LD A,C / RLC A / LD C,A / LD B,0
CODE ROL A C LD, A RLC, C A LD, B 0 # LD, NEXT, END-CODE

\ Rotate byte right circular
CODE ROR A C LD, A RRC, C A LD, B 0 # LD, NEXT, END-CODE

\ --- POPCOUNT: a real algorithm in assembler ---

\ Count set bits in a byte using rotate-through-carry loop.
\ Labels declared up front (LABEL LP LABEL SK), then
\ LP FIX marks the loop top, SK FIX resolves the forward skip.
\
\ Assembles to 12 bytes:
\   LD A,C / LD C,0 / LD H,8
\   RRC A / JR NC,+1 / INC C      <- loop body
\   DEC H / JR NZ,-5              <- loop control
\   LD B,0
CODE POPCNT LABEL LP LABEL SK
  A C LD, C 0 # LD, H 8 # LD,
  LP FIX
    A RRC, NC SK JR, C INC, SK FIX
    H DEC, NZ LP JR,
  B 0 # LD, NEXT,
END-CODE

\ --- 16-BIT INC (new in story 4.4) ---

\ INC BC is a single-byte 16-bit increment.
\ BC holds TOS in AntForth's register contract,
\ so this is a one-instruction 1+.
CODE 1+FAST BC INC, NEXT, END-CODE

\ --- BYTE SWAP ---

\ Swap high and low bytes of a 16-bit cell.
\ Just register moves — BC is TOS, so B=high, C=low.
CODE BSWAP A B LD, B C LD, C A LD, NEXT, END-CODE

\ --- DEMO OUTPUT ---

: SHOUT 0 DO DUP I + C@ >UPPER EMIT LOOP DROP ;
: WHISPER 0 DO DUP I + C@ >LOWER EMIT LOOP DROP ;

CR
CR ." === Extended Z80 Assembler Demo ==="
CR
CR ." RES 5,A clears bit 5 -> uppercase:"
CR ."   >UPPER: " S" Hello World" SHOUT
CR ." SET 5,A sets bit 5 -> lowercase:"
CR ."   >LOWER: " S" Hello World" WHISPER
CR
CR ." RLC A rotates byte left circular:"
CR ."   ROL   1 = " 1 ROL .
CR ."   ROL  65 = " 65 ROL .
CR ."   ROL 128 = " 128 ROL .
CR
CR ." POPCNT counts set bits via RRC + INC:"
CR ."   POPCNT   0 = " 0 POPCNT .
CR ."   POPCNT  15 = " 15 POPCNT .
CR ."   POPCNT  42 = " 42 POPCNT .
CR ."   POPCNT 255 = " 255 POPCNT .
CR
CR ." INC BC is a one-byte 16-bit increment:"
CR ."   1+FAST 999 = " 999 1+FAST .
CR ."   1+FAST 65535 = " 65535 1+FAST .
CR
CR ." Byte swap via register juggling:"
CR ."   BSWAP 258 = " 258 BSWAP .
HEX
CR ."   BSWAP 1234h = " 1234 BSWAP .
DECIMAL
CR
