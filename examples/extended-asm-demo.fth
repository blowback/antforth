CODE >UPPER A C LD, 5 # A RES, C A LD, B 0 # LD, NEXT, END-CODE
CODE >LOWER A C LD, 5 # A SET, C A LD, B 0 # LD, NEXT, END-CODE
CODE ROL A C LD, A RLC, C A LD, B 0 # LD, NEXT, END-CODE
CODE ROR A C LD, A RRC, C A LD, B 0 # LD, NEXT, END-CODE

CODE POPCNT LABEL LP LABEL SK
  A C LD, C 0 # LD, H 8 # LD,
  LP FIX
    A RRC, NC SK JR, C INC, SK FIX
    H DEC, NZ LP JR,
  B 0 # LD, NEXT,
END-CODE

CODE 1+FAST BC INC, NEXT, END-CODE
CODE BSWAP A B LD, B C LD, C A LD, NEXT, END-CODE

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
