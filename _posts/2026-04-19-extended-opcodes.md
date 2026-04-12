---
layout: post
title: "Extended z80 opcodes"
date: 2026-04-19
---

In this sprint we'll be getting the remainder of the z80 opcodes. These are 
the "extended" opcodes prefixed by 0xcb, 0xdd , 0xed and 0xfd bytes. 

The 0xcb set gives us all of the bit set/clear/test instructions, as well as 
a few shifts and rotates.

The 0xdd set gives us the IX indexed addressing instructions.

The 0xed set gives us IN, OUT and all the block transfer operations like `LDIR`.

The 0xfd set gives us the IY indexed addressing instructions.


We `/bmad-bmm-create-story 4.4` to kick things off. Reviewing the spec I 
noticed that a fair fiew opcodes in the "Misc" category were absent, so 
I asked Claude to add them. When we do a retro at the end of this epic 
I will have the team check that our opcode coverage is 100%.

Development went without a hitch, and code review didn't reveal Anything
major.

## assembler.asm

Everything is going on in this file, once again. This is good, it means 
our implementation is clean.


Here we can see the IX/IY register implementations: 

![IX/IY registers](/antforth/assets/images/2026-04-19/ix_iy.png)


And here are some more tag words for indirect addressing:

![Indirect addressing](/antforth/assets/images/2026-04-19/indirect.png)

`+D` is an interesting new word: it's how you combine IX/IY with an 
immediate constant, for example `(IY) 3 +D SLA,` or `(IX) -5 +D A LD,`. 
The offset is a bare integer (it doesn't need to be tagged with `#`).

`INC` and `DEC` are now included, but their implementations are 
quite long, due to the large variety of input parameters they accept.

`BIT`, `RES` and `SET` words are included, they all use a shared 
helper routine `asm_bit_op_word`.

`IN,` has quite a tight implementation:

![IN implementation](/antforth/assets/images/2026-04-19/in.png)


As does `OUT,`:

![OUT implementation](/antforth/assets/images/2026-04-19/out.png)


All of the "ED" opcodes are represented, and are all implemented in the 
same way. Here's a small selection:

![ED opcodes](/antforth/assets/images/2026-04-19/ed_op.png)


`EX,` has quite a lot of work to do in register argument checking, but let's 
finished up with `EXX,` which is more simpler:


![EXX implementation](/antforth/assets/images/2026-04-19/exx.png)





## Testing

Let's try some of the new stuff out! We'll use our new words to write this
program:

```
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

: test
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
;
```


You can i[view the file on github](https://github.com/blowback/antforth/blob/21c8d05f8070bd25951bad8c7d7d294340ff4a7d/examples/extended-asm-demo-annotated.fth) if you prefer.


And here it is in action:

![z80 demo](/antforth/assets/images/2026-04-19/z80_demo.png)

There's both an annotated and an un-annotated version in the 'examples'
folder, because I just realised that we've come this far without 
implementing comments... it's not even in the plan! We'll address that 
in the next retro, which is coming up as we're now at the end of 
Epic 4.
