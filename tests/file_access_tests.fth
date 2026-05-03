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
\ Forward-pointers — Stories 13.3 / 13.4 / 13.5 add more probes
\ ============================================================
\ Story 13.3 (file-positioning) extends this file with FILE-POSITION,
\ REPOSITION-FILE, FILE-SIZE probes — they inherit the same FID-
\ validation discipline (-70 on stale FID) and fam encoding.
\ Story 13.4 (INCLUDE-top chain) extends with source-input nesting.
\ Story 13.5 (FS stress + BDOS audit) is the Epic 13 close-out gate.
