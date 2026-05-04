\ file_access_tests.fth — Story 13.2 — File-Access wordset regression
\ AntForth — A Forth for CP/M on Z80
\
\ Documents the eight REPL-piped probes (t1)-(t8) that regress the
\ Story 13.2 user-facing words: OPEN-FILE, CREATE-FILE, CLOSE-FILE,
\ DELETE-FILE, READ-FILE, WRITE-FILE, plus the fam-constants R/O,
\ R/W, W/O, BIN. Each probe is wired into Makefile `test-repl` as a
\ separately-numbered test (905..912); this file is the source-of-
\ truth narrative — keep it in sync with Makefile when probes evolve.
\
\ Test discipline (per project_memory feedback_repl_tests_preferred /
\ feedback_testing_rules):
\   * Each probe exercises actual user-facing Forth words; raw BDOS
\     calls inside probes are forbidden — the FILE_SANITY-wrapped
\     harness in src/file_access.asm covers the wrapper layer.
\   * Files live in disk/a/ (and disk/b/ for the t8 drive-routing
\     probe). .gitignore excludes *.TXT and *.BIN under both, so
\     transient test files don't pollute git status.
\   * Each probe ends with BYE so iz-cpm exits cleanly.
\
\ ============================================================
\ (t1) Round-trip integrity — Makefile test 905
\ ============================================================
\ CREATE-FILE → WRITE-FILE → CLOSE-FILE → re-OPEN R/O → READ-FILE →
\ CLOSE-FILE → DELETE-FILE; verify read-back == "Hello, antforth!".
VARIABLE FA  CREATE BFA 32 ALLOT
S" TESTRT.TXT" R/W CREATE-FILE DROP FA !
S" Hello, antforth!" FA @ WRITE-FILE DROP  FA @ CLOSE-FILE DROP
S" TESTRT.TXT" R/O OPEN-FILE DROP FA !
BFA 16 FA @ READ-FILE DROP DROP  FA @ CLOSE-FILE DROP
." T1=" BFA 16 TYPE CR
S" TESTRT.TXT" DELETE-FILE DROP
\ Expected output fragment: "T1=Hello, antforth!"

\ ============================================================
\ (t2) Cross-record read + EOF — Makefile test 906
\ ============================================================
\ Write 256 bytes (= 2 full CP/M records, no partial-record padding).
\ Read 256 back: u2=256 ior=0. Read 1 more byte: u2=0 ior=0 (EOF is
\ not an error per ANS §11.6.1.2080).
\
\ ⚠ DEVIATION from AC #13(t2) "200-byte / partial-record + EOF":
\   Story 13.1's byte-stream layer detects EOF only at record
\   boundaries (F_READ returns 1 when next record absent). It does
\   NOT track logical byte-EOF mid-record — CP/M's record-level
\   filesystem semantics make 0x1A padding indistinguishable from
\   data at the byte-stream layer. A logical-size-tracking rewrite
\   of file_byte_read sits behind Story 13.2 AC #19 escalation gate
\   (load-bearing structural change requires project lead approval).
\   Rather than rewrite, the probe uses a record-aligned 256-byte
\   payload so EOF lands at byte 257.
VARIABLE FA  CREATE BFA 256 ALLOT
: P256 256 0 DO BFA I + I 26 MOD 65 + SWAP C! LOOP ;
P256
S" TESTCR.TXT" R/W CREATE-FILE DROP FA !
BFA 256 FA @ WRITE-FILE DROP  FA @ CLOSE-FILE DROP
S" TESTCR.TXT" R/O OPEN-FILE DROP FA !
." T2A=" HERE 256 FA @ READ-FILE . . CR
." T2B=" HERE 1 FA @ READ-FILE . . CR
FA @ CLOSE-FILE DROP
S" TESTCR.TXT" DELETE-FILE DROP
\ Expected fragments: "T2A=0 256 " and "T2B=0 0 "

\ ============================================================
\ (t3) Delete-then-reopen — Makefile test 907
\ ============================================================
\ A deleted file's OPEN-FILE returns fileid=0, ior=2 (file-not-found
\ — antforth ior pick: 2 = F_OPEN returned 0xFF).
VARIABLE FA
S" TESTDR.TXT" R/W CREATE-FILE DROP FA !  FA @ CLOSE-FILE DROP
S" TESTDR.TXT" DELETE-FILE DROP
." T3=" S" TESTDR.TXT" R/O OPEN-FILE . . CR
\ Expected fragment: "T3=2 0 " (ior=2, fileid=0)

\ ============================================================
\ (t4) Pool exhaustion → -69 THROW — Makefile test 908
\ ============================================================
\ Open 8 files, attempt 9th via CATCH. pool_acquire exhaustion path
\ raises THROW_FCB_EXHAUSTED (-69) per Story 13.1 AC #4. Each
\ iz-cpm invocation pool-resets at cold_start, so per-test cleanup
\ of the 8 transient files is unnecessary; .gitignore excludes them.
S" P1.TXT" R/W CREATE-FILE DROP DROP
S" P2.TXT" R/W CREATE-FILE DROP DROP
S" P3.TXT" R/W CREATE-FILE DROP DROP
S" P4.TXT" R/W CREATE-FILE DROP DROP
S" P5.TXT" R/W CREATE-FILE DROP DROP
S" P6.TXT" R/W CREATE-FILE DROP DROP
S" P7.TXT" R/W CREATE-FILE DROP DROP
S" P8.TXT" R/W CREATE-FILE DROP DROP
." T4=" S" P9.TXT" R/W ' CREATE-FILE CATCH . CR
\ Expected fragment: "T4=-69 "

\ ============================================================
\ (t5) R/O write attempt → ior=1 — Makefile test 909
\ ============================================================
\ AC #6 R/O guard: WRITE-FILE on a R/O FID returns ior=1 without
\ touching DMA/FCB state (recoverable per ANS §11.3.5, no THROW).
VARIABLE FA
S" TESTRO.TXT" R/W CREATE-FILE DROP FA !
S" hi" FA @ WRITE-FILE DROP  FA @ CLOSE-FILE DROP
S" TESTRO.TXT" R/O OPEN-FILE DROP FA !
." T5=" S" overwrite" FA @ WRITE-FILE . CR
FA @ CLOSE-FILE DROP  S" TESTRO.TXT" DELETE-FILE DROP
\ Expected fragment: "T5=1 "

\ ============================================================
\ (t6) Closed-FID detection → -70 THROW — Makefile test 910
\ ============================================================
\ AC #8 fid_validate: READ-FILE on a stale (closed) FID raises
\ THROW_FILE_INVALID_FID (-70). Caught via CATCH.
VARIABLE FA
S" TESTCD.TXT" R/W CREATE-FILE DROP FA !
S" hi" FA @ WRITE-FILE DROP  FA @ CLOSE-FILE DROP
." T6=" HERE 1 FA @ ' READ-FILE CATCH . CR
S" TESTCD.TXT" DELETE-FILE DROP
\ Expected fragment: "T6=-70 "

\ ============================================================
\ (t7) Malformed filename → ior=1 — Makefile test 911
\ ============================================================
\ Five rejection cases per AC #9: empty, wildcard, embedded space,
\ two dots, Unix path. Each yields fileid=0 ior=1 (no THROW).
." T7E=" S" " R/O OPEN-FILE . . CR
." T7W=" S" hi*.txt" R/O OPEN-FILE . . CR
." T7S=" S" hi sp.txt" R/O OPEN-FILE . . CR
." T7D=" S" two..dot" R/O OPEN-FILE . . CR
." T7P=" S" /path/x" R/O OPEN-FILE . . CR
\ Expected fragments: "T7E=1 0 ", "T7W=1 0 ", "T7S=1 0 ", "T7D=1 0 ", "T7P=1 0 "

\ ============================================================
\ (t8) Drive prefix routing → A: vs B: — Makefile test 912
\ ============================================================
\ A:HELLO.TXT and B:HELLO.TXT must refer to disk/a/HELLO.TXT and
\ disk/b/HELLO.TXT respectively. Seed-staging pick (Task 14):
\ re-create at start (transient, .gitignore-d). Discriminator
\ content "Aside"/"Bside" lets a single TYPE oracle confirm the
\ A:/B: routes resolve to different files.
VARIABLE FA  CREATE BA 16 ALLOT  BA 16 0 FILL
S" A:HELLO.TXT" R/W CREATE-FILE DROP FA !
S" Aside" FA @ WRITE-FILE DROP  FA @ CLOSE-FILE DROP
S" B:HELLO.TXT" R/W CREATE-FILE DROP FA !
S" Bside" FA @ WRITE-FILE DROP  FA @ CLOSE-FILE DROP
S" A:HELLO.TXT" R/O OPEN-FILE DROP FA !
BA 5 FA @ READ-FILE DROP DROP  FA @ CLOSE-FILE DROP
." T8A=" BA 5 TYPE CR  BA 16 0 FILL
S" B:HELLO.TXT" R/O OPEN-FILE DROP FA !
BA 5 FA @ READ-FILE DROP DROP  FA @ CLOSE-FILE DROP
." T8B=" BA 5 TYPE CR
\ Expected fragments: "T8A=Aside" and "T8B=Bside"

\ ============================================================
\ (t9) Code-review H1 regression — OPEN W/O → WRITE-FILE — Makefile test 913
\ ============================================================
\ Pre-fix: OPEN-FILE always seeded fcb_byte_pos=128 (refill sentinel,
\ correct for read mode); a subsequent WRITE-FILE wrote the first
\ byte at DMA[128] (out-of-bounds, corrupted adjacent FCB's buffer)
\ and file_flush's `128 - pos` underflowed, scribbling up to 224
\ bytes of 0x1A past the end. Net: silent data loss + memory
\ corruption with ior=0 reported. Reproducer that surfaced it:
\   S" X" R/W CREATE-FILE DROP DROP
\   S" X" R/W OPEN-FILE DROP FA !
\   BUF 32 FA @ WRITE-FILE .   \ ior=0 (LIE — wrote nothing)
\ Post-fix (file_access.asm — OPEN-FILE success path): pos seeded
\ by fam — R/O → 128, R/W / W/O → 0. (t9) catches a regression by
\ writing through a freshly-OPEN-FILE'd W/O FID and verifying the
\ bytes round-trip via a separate R/O OPEN-FILE.
VARIABLE FA  CREATE BFA 8 ALLOT  BFA 8 0 FILL
S" T9WO.TXT" R/W CREATE-FILE DROP DROP
S" T9WO.TXT" W/O OPEN-FILE DROP FA !
S" Hello" FA @ WRITE-FILE DROP  FA @ CLOSE-FILE DROP
S" T9WO.TXT" R/O OPEN-FILE DROP FA !
BFA 5 FA @ READ-FILE DROP DROP  FA @ CLOSE-FILE DROP
." T9=" BFA 5 TYPE CR
S" T9WO.TXT" DELETE-FILE DROP
\ Expected fragment: "T9=Hello"

\ ============================================================
\ Story 13.3 — file-positioning probes (t10..t15) — Makefile tests 914..919
\ ============================================================
\ FILE-POSITION ( fileid -- ud ior )            ANS Forth 1994 §11.6.1.1520
\ REPOSITION-FILE ( ud fileid -- ior )          ANS Forth 1994 §11.6.1.2142
\ FILE-SIZE ( fileid -- ud ior )                ANS Forth 1994 §11.6.1.1522
\
\ Discard-discipline pick (Task 1.9 (ii) per AC #3): REPOSITION-FILE
\ does NOT auto-flush. After the (t13) round-trip surfaced a R/W mixed-
\ mode buffer-corruption hazard (post-read REPOSITION's auto-flush
\ wrote stale read bytes back to disk because Story 13.1's helper
\ layer doesn't track buffer-loaded-for-read vs buffer-loaded-for-
\ write state), Task 1.9 was flipped from (i) auto-flush to (ii)
\ silent discard. Documented; per-FCB dirty-flag infrastructure to
\ enable safe auto-flush is escalation-gated per AC #19, deferred to
\ Story 13.5. Users wanting write durability across REPOSITION must
\ CLOSE-FILE then re-OPEN-FILE.

\ ============================================================
\ (t10) FILE-POSITION on fresh OPEN — Makefile test 914
\ ============================================================
\ AC #2(a) anchor: a freshly-OPENed file has byte cursor at 0
\ regardless of fam. R/O seeds pos=128 (refill sentinel); R/W and W/O
\ seed pos=0 per Story 13.2 H1 fix. Both encodings collapse to logical
\ position 0 in FILE-POSITION's synthesis logic.
\
\ Probe: create empty file, close, reopen R/O, FILE-POSITION before
\ any READ. Expected: ud-low=0, ud-high=0, ior=0.
VARIABLE FA
S" T10.TXT" R/W CREATE-FILE DROP FA !  FA @ CLOSE-FILE DROP
S" T10.TXT" R/O OPEN-FILE DROP FA !
." T10=" FA @ FILE-POSITION . . . CR
FA @ CLOSE-FILE DROP  S" T10.TXT" DELETE-FILE DROP
\ Expected fragment: "T10=0 0 0 " (printed TOS-first: ior=0, ud-high=0, ud-low=0)

\ ============================================================
\ (t11) FILE-POSITION mid-read — Makefile test 915
\ ============================================================
\ AC #2(b) anchor: after reading 200 bytes of a 256-byte file (one
\ full record + 72 bytes into the next), FILE-POSITION returns
\ byte_position=200. CR=2, EX=0, S2=0, pos=72; synthesis formula for
\ R/O with pos<128 subtracts 1 from record_count (file_byte_read's
\ F_READ_SEQ has auto-advanced CR past the loaded record):
\   bp = (record_count - 1) * 128 + pos = 1*128 + 72 = 200.
VARIABLE FA  CREATE BFA 256 ALLOT
: P256 256 0 DO BFA I + I 26 MOD 65 + SWAP C! LOOP ;
P256
S" T11.TXT" R/W CREATE-FILE DROP FA !
BFA 256 FA @ WRITE-FILE DROP  FA @ CLOSE-FILE DROP
S" T11.TXT" R/O OPEN-FILE DROP FA !
BFA 200 FA @ READ-FILE DROP DROP
." T11=" FA @ FILE-POSITION . . . CR
FA @ CLOSE-FILE DROP  S" T11.TXT" DELETE-FILE DROP
\ Expected fragment: "T11=0 0 200 " (ior=0, ud-high=0, ud-low=200)

\ ============================================================
\ (t12) Closed-FID detection on the three new words — Makefile test 916
\ ============================================================
\ AC #5: fid_validate raises -70 THROW for a stale FID before any FCB
\ byte is touched. Probe extends Story 13.2 (t6) discipline to all
\ three new words. Three sub-cases under one Makefile test.
VARIABLE FA
S" T12.TXT" R/W CREATE-FILE DROP FA !  FA @ CLOSE-FILE DROP
." T12FP=" FA @ ' FILE-POSITION CATCH . CR
." T12RF=" 0 0 FA @ ' REPOSITION-FILE CATCH . CR
." T12FS=" FA @ ' FILE-SIZE CATCH . CR
S" T12.TXT" DELETE-FILE DROP
\ Expected fragments: "T12FP=-70 ", "T12RF=-70 ", "T12FS=-70 "

\ ============================================================
\ (t13) REPOSITION-FILE round-trip — Makefile test 917
\ ============================================================
\ Write 256 bytes (= 2 full records); close; reopen R/W; REPOSITION-
\ FILE to byte 0 / 100 / 200 / 256; READ-FILE 1 byte at each; verify
\ byte values match the (t2) P256 pattern A,B,...,Z,A,... (mod 26).
\ AC #9 expected values: byte 0 = 'A' (65); byte 100 = 'W' (87 = 65+22,
\ 100 mod 26 = 22); byte 200 = 'S' (83 = 65+18, 200 mod 26 = 18 — AC
\ #9 text says 'C' which is a math error in the spec); byte 256 → EOF.
\ Also boundary: bytes 127, 128, 129 (record-edge crossings).
VARIABLE FA  CREATE BFA 256 ALLOT
: P256 256 0 DO BFA I + I 26 MOD 65 + SWAP C! LOOP ;
P256
S" T13.TXT" R/W CREATE-FILE DROP FA !
BFA 256 FA @ WRITE-FILE DROP  FA @ CLOSE-FILE DROP
S" T13.TXT" R/W OPEN-FILE DROP FA !
." T13B0="   0 0 FA @ REPOSITION-FILE DROP BFA 1 FA @ READ-FILE DROP DROP BFA C@ . CR
." T13B100=" 100 0 FA @ REPOSITION-FILE DROP BFA 1 FA @ READ-FILE DROP DROP BFA C@ . CR
." T13B200=" 200 0 FA @ REPOSITION-FILE DROP BFA 1 FA @ READ-FILE DROP DROP BFA C@ . CR
." T13B127=" 127 0 FA @ REPOSITION-FILE DROP BFA 1 FA @ READ-FILE DROP DROP BFA C@ . CR
." T13B128=" 128 0 FA @ REPOSITION-FILE DROP BFA 1 FA @ READ-FILE DROP DROP BFA C@ . CR
." T13B129=" 129 0 FA @ REPOSITION-FILE DROP BFA 1 FA @ READ-FILE DROP DROP BFA C@ . CR
." T13EOF=" 256 0 FA @ REPOSITION-FILE DROP BFA 1 FA @ READ-FILE . . CR
FA @ CLOSE-FILE DROP  S" T13.TXT" DELETE-FILE DROP
\ Expected fragments:
\   T13B0=65   (byte 0   = 'A' = 65)
\   T13B100=87 (byte 100 = 'W' = 87, 100 mod 26 = 22)
\   T13B200=83 (byte 200 = 'S' = 83, 200 mod 26 = 18 — AC #9 'C' is a typo)
\   T13B127=88 (byte 127 = 'X' = 88, 127 mod 26 = 23)
\   T13B128=89 (byte 128 = 'Y' = 89, 128 mod 26 = 24)
\   T13B129=90 (byte 129 = 'Z' = 90, 129 mod 26 = 25)
\   T13EOF=0 0 (READ at EOF: u2=0, ior=0)

\ ============================================================
\ (t14) FILE-SIZE matches written byte count modulo record rounding — Makefile test 918
\ ============================================================
\ AC #4 caveat: CP/M 2.2 tracks size in 128-byte records, so a 64-byte
\ file reports as 128. Three probes: empty (0), 64-byte → 128, 256-
\ byte → 256. Each cleanup deletes the file.
VARIABLE FA  CREATE BFA 256 ALLOT
: P64 64 0 DO BFA I + I 26 MOD 65 + SWAP C! LOOP ;
: P256 256 0 DO BFA I + I 26 MOD 65 + SWAP C! LOOP ;
S" T14E.TXT" R/W CREATE-FILE DROP FA !  FA @ CLOSE-FILE DROP
S" T14E.TXT" R/O OPEN-FILE DROP FA !
." T14E=" FA @ FILE-SIZE . . . CR
FA @ CLOSE-FILE DROP  S" T14E.TXT" DELETE-FILE DROP
P64
S" T14P.TXT" R/W CREATE-FILE DROP FA !
BFA 64 FA @ WRITE-FILE DROP  FA @ CLOSE-FILE DROP
S" T14P.TXT" R/O OPEN-FILE DROP FA !
." T14P=" FA @ FILE-SIZE . . . CR
FA @ CLOSE-FILE DROP  S" T14P.TXT" DELETE-FILE DROP
P256
S" T14F.TXT" R/W CREATE-FILE DROP FA !
BFA 256 FA @ WRITE-FILE DROP  FA @ CLOSE-FILE DROP
S" T14F.TXT" R/O OPEN-FILE DROP FA !
." T14F=" FA @ FILE-SIZE . . . CR
FA @ CLOSE-FILE DROP  S" T14F.TXT" DELETE-FILE DROP
\ Expected fragments:
\   T14E=0 0 0   (empty file: 0 bytes)
\   T14P=0 0 128 (64-byte file: rounded up to 128 per AC #4 caveat)
\   T14F=0 0 256 (256-byte file: exactly 2 records)

\ ============================================================
\ (t15) REPOSITION-FILE 24-bit overflow → ior=5 — Makefile test 919
\ ============================================================
\ AC #15(e) audit + AC #3 overflow rule. Target ≥ 16 MB (ud-high upper
\ byte != 0) returns ior=5 without mutating any FCB state. The probe
\ uses ud-high = 0x0100 (= bit 24 set) which trips the upper-byte
\ check.
VARIABLE FA
S" T15.TXT" R/W CREATE-FILE DROP FA !
." T15=" 0 256 FA @ REPOSITION-FILE . CR
FA @ CLOSE-FILE DROP  S" T15.TXT" DELETE-FILE DROP
\ Expected fragment: "T15=5 " (ior=5; 256 = 0x0100 in ud-high triggers overflow)

\ ============================================================
\ (t16) REPOSITION → FILE-POSITION round-trip ≥ 512 KB — Makefile test 920
\ ============================================================
\ Code-review regression probe. The CR/EX/S2 mirror in REPOSITION-FILE
\ originally kept N1 in register E across an `LD DE, FCB_EX` which
\ silently overwrote E with the offset's low byte (= 12). The S2
\ computation then read 12 instead of N1, collapsing S2 to 0 whenever
\ N1 ≥ 16 (target byte ≥ 524288). Subsequent file_byte_read using
\ bdos_read_seq consults CR/EX/S2 and read the wrong record — silent
\ data corruption for files ≥ 512 KB.
\
\ Pin the fix: REPOSITION-FILE to ud = 0 0x0008 = 524288. FILE-POSITION
\ must round-trip to ud = 0 0x0008 (printed TOS-first as "0 8 0 ":
\ ior=0, ud-high=8, ud-low=0).
VARIABLE FA
S" T16.TXT" R/W CREATE-FILE DROP FA !
0 8 FA @ REPOSITION-FILE DROP
." T16=" FA @ FILE-POSITION . . . CR
FA @ CLOSE-FILE DROP  S" T16.TXT" DELETE-FILE DROP
\ Expected fragment: "T16=0 8 0 "

\ ============================================================
\ Story 13.5 audit anchor — R/O CLOSE-FILE destructive flush — Makefile test 938
\ ============================================================
\ Verdict-flipped 2026-05-04 at Story 13.5 close (per
\ feedback_verdict_only_audit.md): same probe sequence, opposite
\ verdict. Pre-flip the probe asserted SZ != 128 (bug-state); post-flip
\ asserts SZ = 128 (fix landed).
\
\ The latent (now fixed): `file_flush` (src/file_access.asm) was called
\ by `CLOSE-FILE` before F_CLOSE on every close path. After a partial-
\ record READ-FILE with `fcb_byte_pos` in 1..127, file_flush padded
\ DMA[pos..127] with 0x1A and unconditionally F_WRITE'd the record. On
\ R/O FCBs this extended the on-disk source file by one record per
\ open-partial-read-close cycle.
\
\ Story 13.4 v2 dodged this in `(close-current-fid)` by skipping the
\ flush entirely (INCLUDE always opens R/O). The user-facing
\ CLOSE-FILE inherited the latent until Story 13.5.
\
\ Story 13.5 fix: file_flush consults a per-FCB `fcb_has_written`
\ bit (set inside file_byte_write entry and bdos_write_seq A==0
\ success; cleared at pool_acquire / pool_release). R/O reads never
\ touch file_byte_write so the bit stays 0; close-time file_flush
\ skips the destructive pad-and-F_WRITE on R/O FCBs.
\
\ Probe sequence:
\   1. CREATE-FILE R/W RODEMO.TXT, write "Hello, world." (13 bytes),
\      CLOSE-FILE clean (the writeable close path is correct).
\   2. Reopen R/O, partial-read 5 bytes via HERE, CLOSE-FILE — was
\      the bug-trigger; post-fix is benign.
\   3. Reopen R/O, query FILE-SIZE.
\
\ Verdict on CP/M 2.2 (FILE-SIZE returns record-aligned bytes):
\   * Clean state (fix landed): 128 bytes (1 record from cycle 1).
\   * Bug state (latent fired pre-fix): 256 bytes (cycle 2 wrote one
\     extra padded record at the post-read FCB.CR position).
\
\ Probe-quality fixes that landed with the verdict-flip:
\   * `PAD` (undefined in antforth) → `HERE` (free dictionary space
\     used as a 5-byte scratch buffer for the partial read).
\   * `." SZ="` (clobbered BC across the print, garbling D.'s
\     subsequent FILE-SIZE output) → `S" SZ=" TYPE` (BC-preserving).
\
\ Story 13.5 owns the audit + structural fix; Story 13.6 (renumbered
\ from original 13.5 per party-mode session 2026-05-04) is the Epic
\ 13 release gate.

\ ============================================================
\ Forward-pointers — Story 13.6 closes the epic
\ ============================================================
\ Story 13.6 (FS stress + BDOS audit + antforth 2.0 release gate;
\   renumbered from 13.5 on 2026-05-04 to make room for the R/O
\   destructive-flush story) may add a per-FCB dirty-flag
\   infrastructure that enables safe auto-flush in REPOSITION-FILE
\   (the (t13) follow-up deferred from Story 13.3 per AC #11(b) and
\   AC #19), pending Story 13.5's investigation outcome — the
\   "has-written" bit Winston proposed in the party-mode discussion
\   may overlap or fully subsume that infrastructure.
