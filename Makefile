# Makefile — AntForth build system
# Assembles Z80 source into CP/M .COM binary
#
# Usage:
#   make              — build using local toolchain
#   make docker-build — build the Docker toolchain image
#   make docker       — build antforth.com inside Docker
#   make docker-test  — build and run under iz-cpm inside Docker

ASM      = sjasmplus
ASMFLAGS = --fullpath --nologo
IZCPM    = iz-cpm

SRCDIR   = src
BUILDDIR = build
DISKDIR  = disk

TARGET   = $(BUILDDIR)/antforth.com
TESTKEY  = $(BUILDDIR)/test_key.com
DISKIMG  = $(BUILDDIR)/antforth.img

# All .asm files — sjasmplus assembles fast, depend on all of them
SRCS     = $(wildcard $(SRCDIR)/*.asm) $(wildcard $(SRCDIR)/tests/*.asm)

# Docker
DOCKER_IMAGE = antforth-toolchain
DOCKER_RUN   = docker run --rm -v $(CURDIR):/workspace $(DOCKER_IMAGE)

.PHONY: all asm disk test test-repl test_key clean docker-build docker docker-test docker-disk

all: asm

asm: $(TARGET)

$(TARGET): $(SRCS) | $(BUILDDIR)
	cd $(SRCDIR) && $(ASM) $(ASMFLAGS) antforth.asm --raw=../$(TARGET)

$(BUILDDIR):
	mkdir -p $(BUILDDIR)

test_key: $(TESTKEY)

$(TESTKEY): $(SRCS) | $(BUILDDIR)
	cd $(SRCDIR) && $(ASM) $(ASMFLAGS) test_key.asm --raw=../$(TESTKEY)

disk: $(TARGET) $(TESTKEY)
	@echo "Building CP/M disk image..."
	mkfs.cpm -f ibm-3740 $(DISKIMG)
	cpmcp -f ibm-3740 $(DISKIMG) $(TARGET) 0:antforth.com
	cpmcp -f ibm-3740 $(DISKIMG) $(TESTKEY) 0:test_key.com

test: $(SRCS) | $(BUILDDIR)
	@echo "Running regression tests..."
	@cd $(SRCDIR) && $(ASM) $(ASMFLAGS) -DTEST_MODE antforth.asm --raw=../$(BUILDDIR)/antforth_test.com
	@# EXPECTED output by test group (note: \r\n = literal CR LF):
	@#   Group 1 (inner):      ABCDE
	@#   Group 2 (stack):      FGHIJKLMNOPQRSTUVWXYZ
	@#   Group 3 (arithmetic): 0123456789abcdefghijklmnopqr
	@#   Group 4 (io):         stu<CR><LF>v w  xyz{|
	@#   Group 5 (dictionary): }~#$$%%&
	@#   Group 6 (outer):      ()*42 0 -1 -32768 65535     42<3> 1 2 3 FF A
	@OUTPUT=$$($(IZCPM) $(BUILDDIR)/antforth_test.com) && \
	EXPECTED=$$(printf 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstu\r\nv w  xyz{|}~#$$%%&()*42 0 -1 -32768 65535     42<3> 1 2 3 FF A') && \
	if [ "$$OUTPUT" = "$$EXPECTED" ]; then \
		echo "PASS: Output matches expected"; \
	else \
		echo "FAIL:"; \
		echo "  Expected: $$(echo -n "$$EXPECTED" | xxd)"; \
		echo "  Got:      $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi

test-repl: $(TARGET)
	@echo "Running REPL tests..."
	@OUTPUT=$$(printf '65 EMIT\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'A'; then \
		echo "PASS: REPL test 1 — '65 EMIT' outputs 'A'"; \
	else \
		echo "FAIL: REPL test 1 — expected 'A' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '72 EMIT 73 EMIT\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'HI'; then \
		echo "PASS: REPL test 2 — '72 EMIT 73 EMIT' outputs 'HI'"; \
	else \
		echo "FAIL: REPL test 2 — expected 'HI' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'XYZZY\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'XYZZY ?'; then \
		echo "PASS: REPL test 3 — undefined word shows error and recovery"; \
	else \
		echo "FAIL: REPL test 3 — expected 'XYZZY ?' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '5 '; then \
		echo "PASS: REPL test 4 — '2 3 + .' outputs '5 '"; \
	else \
		echo "FAIL: REPL test 4 — expected '5 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'HEX FF . DECIMAL\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'FF '; then \
		echo "PASS: REPL test 5 — 'HEX FF .' outputs 'FF '"; \
	else \
		echo "FAIL: REPL test 5 — expected 'FF ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 2 3 .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<3> 1 2 3 '; then \
		echo "PASS: REPL test 6 — '1 2 3 .S' outputs '<3> 1 2 3 '"; \
	else \
		echo "FAIL: REPL test 6 — expected '<3> 1 2 3 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '.S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<0> '; then \
		echo "PASS: REPL test 7 — empty '.S' outputs '<0> '"; \
	else \
		echo "FAIL: REPL test 7 — expected '<0> ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'BYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'BYE'; then \
		echo "PASS: REPL test 8 — BYE exits cleanly"; \
	else \
		echo "FAIL: REPL test 8 — BYE did not execute"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'FOO\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'FOO ?' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 9 — undefined word 'FOO' shows 'FOO ?' and recovers to ok"; \
	else \
		echo "FAIL: REPL test 9 — expected 'FOO ?' and 'ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '+\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 10 — stack underflow on + shows error and recovers"; \
	else \
		echo "FAIL: REPL test 10 — expected 'error -4: stack underflow' and 'ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '2 3 + BADWORD\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'BADWORD ?'; then \
		echo "PASS: REPL test 11 — partial execution: '2 3 + BADWORD' reports error for BADWORD"; \
	else \
		echo "FAIL: REPL test 11 — expected 'BADWORD ?' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'FOO\r\nBAR\r\n42 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'FOO ?' && echo "$$OUTPUT" | grep -q 'BAR ?' && echo "$$OUTPUT" | grep -q '42 '; then \
		echo "PASS: REPL test 12 — multiple consecutive errors recover cleanly, then '42 .' works"; \
	else \
		echo "FAIL: REPL test 12 — expected 'FOO ?', 'BAR ?', and '42 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 13 — stack underflow on DROP shows error and recovers"; \
	else \
		echo "FAIL: REPL test 13 — expected 'error -4: stack underflow' and 'ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 14 — stack underflow on . shows error and recovers"; \
	else \
		echo "FAIL: REPL test 14 — expected 'error -4: stack underflow' and 'ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'AND\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 15 — stack underflow on AND shows error and recovers"; \
	else \
		echo "FAIL: REPL test 15 — expected 'error -4: stack underflow' and 'ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 +\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 16 — stack underflow on '1 +' (only 1 arg for binary op)"; \
	else \
		echo "FAIL: REPL test 16 — expected 'error -4: stack underflow' and 'ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': SQUARE DUP * ; 7 SQUARE .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '49 '; then \
		echo "PASS: REPL test 17 — colon definition: ': SQUARE DUP * ; 7 SQUARE .' outputs '49'"; \
	else \
		echo "FAIL: REPL test 17 — expected '49' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': SQUARE DUP * ; : CUBE DUP SQUARE * ; 3 CUBE .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '27 '; then \
		echo "PASS: REPL test 18 — nested definitions: '3 CUBE .' outputs '27'"; \
	else \
		echo "FAIL: REPL test 18 — expected '27' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '5 NEGATE .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '\-5 '; then \
		echo "PASS: REPL test 19 — NEGATE: '5 NEGATE .' outputs '-5'"; \
	else \
		echo "FAIL: REPL test 19 — expected '-5' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '%s\r\n%s\r\n' '-3 NEGATE .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '3 '; then \
		echo "PASS: REPL test 19b — NEGATE: '-3 NEGATE .' outputs '3'"; \
	else \
		echo "FAIL: REPL test 19b — expected '3' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': BAD XYZZY ;\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'XYZZY ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 20 — compilation error recovery: XYZZY ? then 2 3 + . outputs 5"; \
	else \
		echo "FAIL: REPL test 20 — expected 'XYZZY ?' and '5' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': ADD5 5 + ; 10 ADD5 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '15 '; then \
		echo "PASS: REPL test 21 — LIT compilation: ': ADD5 5 + ; 10 ADD5 .' outputs '15'"; \
	else \
		echo "FAIL: REPL test 21 — expected '15' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': MAGIC [ 2 3 + ] LITERAL * ; 10 MAGIC .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '50 '; then \
		echo "PASS: REPL test 22 — [ ] LITERAL: ': MAGIC [ 2 3 + ] LITERAL * ; 10 MAGIC .' outputs '50'"; \
	else \
		echo "FAIL: REPL test 22 — expected '50' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '%s\r\n%s\r\n%s\r\n' '-7 ABS .' '7 ABS .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '7 .*7 '; then \
		echo "PASS: REPL test 23 — ABS: '-7 ABS .' and '7 ABS .' both output '7'"; \
	else \
		echo "FAIL: REPL test 23 — expected '7' from both ABS calls"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '3 5 MIN .\r\n3 5 MAX .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '3 .*5 '; then \
		echo "PASS: REPL test 24 — MIN/MAX: '3 5 MIN .' outputs '3', '3 5 MAX .' outputs '5'"; \
	else \
		echo "FAIL: REPL test 24 — expected '3' and '5' from MIN/MAX"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'VARIABLE X  42 X !  X @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '42 '; then \
		echo "PASS: REPL test 25 — VARIABLE: 'VARIABLE X  42 X !  X @ .' outputs '42'"; \
	else \
		echo "FAIL: REPL test 25 — expected '42' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '99 CONSTANT LIMIT  LIMIT .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '99 '; then \
		echo "PASS: REPL test 26 — CONSTANT: '99 CONSTANT LIMIT  LIMIT .' outputs '99'"; \
	else \
		echo "FAIL: REPL test 26 — expected '99' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CREATE BUF 10 ALLOT  42 BUF !  BUF @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '42 '; then \
		echo "PASS: REPL test 27 — CREATE+ALLOT: 'CREATE BUF 10 ALLOT  42 BUF !  BUF @ .' outputs '42'"; \
	else \
		echo "FAIL: REPL test 27 — expected '42' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '5 CELLS .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '10 '; then \
		echo "PASS: REPL test 28 — CELLS: '5 CELLS .' outputs '10'"; \
	else \
		echo "FAIL: REPL test 28 — expected '10' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': ARRAY CREATE CELLS ALLOT DOES> SWAP CELLS + ; 10 ARRAY MD  42 3 MD !  3 MD @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '42 '; then \
		echo "PASS: REPL test 29 — CREATE/DOES> ARRAY: '42 3 MD !  3 MD @ .' outputs '42'"; \
	else \
		echo "FAIL: REPL test 29 — expected '42' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '99 CONSTANT LIM\r\n: CHKLIM LIM + ; 1 CHKLIM .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '100 '; then \
		echo "PASS: REPL test 30 — CONSTANT in colon def: '1 CHKLIM .' outputs '100'"; \
	else \
		echo "FAIL: REPL test 30 — expected '100' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'VARIABLE A VARIABLE B  10 A !  20 B !  A @ B @ + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '30 '; then \
		echo "PASS: REPL test 31 — multiple VARIABLEs: 'A @ B @ + .' outputs '30'"; \
	else \
		echo "FAIL: REPL test 31 — expected '30' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'VARIABLE X\r\n: SETX 42 X ! ; SETX X @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '42 '; then \
		echo "PASS: REPL test 32 — VARIABLE in colon def: 'SETX X @ .' outputs '42'"; \
	else \
		echo "FAIL: REPL test 32 — expected '42' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': ARRAY CREATE CELLS ALLOT DOES> SWAP CELLS + ;\r\n5 ARRAY AA 3 ARRAY BB  42 0 AA !  99 0 BB !  0 AA @ .  0 BB @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '42 .*99 '; then \
		echo "PASS: REPL test 33 — multiple DOES> children: AA and BB independent"; \
	else \
		echo "FAIL: REPL test 33 — expected '42' and '99' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'VARIABLE X  42 X !  99 X !  X @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '99 '; then \
		echo "PASS: REPL test 34 — VARIABLE overwrite: store 42 then 99, read back 99"; \
	else \
		echo "FAIL: REPL test 34 — expected '99' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': TPOS DUP 0 > IF NEGATE THEN ; 5 TPOS .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '\-5 '; then \
		echo "PASS: REPL test 35 — IF/THEN taken: '5 TPOS .' outputs '-5'"; \
	else \
		echo "FAIL: REPL test 35 — expected '-5' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': TPOS DUP 0 > IF NEGATE THEN ;\r\n-3 TPOS .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '\-3 '; then \
		echo "PASS: REPL test 36 — IF/THEN skipped: '-3 TPOS .' outputs '-3'"; \
	else \
		echo "FAIL: REPL test 36 — expected '-3' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': TSIGN 0< IF -1 ELSE 1 THEN ; -5 TSIGN .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '\-1 '; then \
		echo "PASS: REPL test 37 — IF/ELSE/THEN true: '-5 TSIGN .' outputs '-1'"; \
	else \
		echo "FAIL: REPL test 37 — expected '-1' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': TSIGN 0< IF -1 ELSE 1 THEN ;\r\n5 TSIGN .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '1 '; then \
		echo "PASS: REPL test 38 — IF/ELSE/THEN false: '5 TSIGN .' outputs '1'"; \
	else \
		echo "FAIL: REPL test 38 — expected '1' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': TNEST DUP 0 > IF DUP 10 > IF 2 ELSE 1 THEN ELSE 0 THEN ; 15 TNEST . 5 TNEST . -1 TNEST .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '2 .*1 .*0 '; then \
		echo "PASS: REPL test 39 — nested IF: '15 TNEST . 5 TNEST . -1 TNEST .' outputs '2 1 0'"; \
	else \
		echo "FAIL: REPL test 39 — expected '2 1 0' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': TCNT 0 BEGIN 1 + DUP 5 = UNTIL ; TCNT .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 40 — BEGIN/UNTIL: 'TCNT .' outputs '5'"; \
	else \
		echo "FAIL: REPL test 40 — expected '5' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': TSUM 0 5 BEGIN DUP 0 > WHILE SWAP OVER + SWAP 1 - REPEAT DROP ; TSUM .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '15 '; then \
		echo "PASS: REPL test 41 — BEGIN/WHILE/REPEAT: 'TSUM .' outputs '15'"; \
	else \
		echo "FAIL: REPL test 41 — expected '15' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': TWH BEGIN DUP 0 > WHILE 1 - REPEAT ; 3 TWH .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '0 '; then \
		echo "PASS: REPL test 42 — WHILE countdown: '3 TWH .' outputs '0'"; \
	else \
		echo "FAIL: REPL test 42 — expected '0' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'IF\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -14: interpreting a compile-only word' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 43 — compile-only guard: IF in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 43 — expected 'error -14: interpreting a compile-only word' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'THEN\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -14: interpreting a compile-only word' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 44 — compile-only guard: THEN in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 44 — expected 'error -14: interpreting a compile-only word' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'BEGIN\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -14: interpreting a compile-only word' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 45 — compile-only guard: BEGIN in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 45 — expected 'error -14: interpreting a compile-only word' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'ELSE\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -14: interpreting a compile-only word' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 46 — compile-only guard: ELSE in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 46 — expected 'error -14: interpreting a compile-only word' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'WHILE\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -14: interpreting a compile-only word' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 47 — compile-only guard: WHILE in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 47 — expected 'error -14: interpreting a compile-only word' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'REPEAT\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -14: interpreting a compile-only word' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 48 — compile-only guard: REPEAT in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 48 — expected 'error -14: interpreting a compile-only word' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'UNTIL\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -14: interpreting a compile-only word' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 49 — compile-only guard: UNTIL in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 49 — expected 'error -14: interpreting a compile-only word' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': TWH BEGIN DUP 0 > WHILE 1 - REPEAT ; 0 TWH .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '0 '; then \
		echo "PASS: REPL test 50 — WHILE false on entry: '0 TWH .' outputs '0'"; \
	else \
		echo "FAIL: REPL test 50 — expected '0' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': TENS 10 0 DO I . LOOP ; TENS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '0 1 2 3 4 5 6 7 8 9 '; then \
		echo "PASS: REPL test 51 — DO/LOOP: 'TENS' outputs '0 1 2 3 4 5 6 7 8 9'"; \
	else \
		echo "FAIL: REPL test 51 — expected '0 1 2 3 4 5 6 7 8 9' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': EVENS 10 0 DO I . 2 +LOOP ; EVENS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '0 2 4 6 8 '; then \
		echo "PASS: REPL test 52 — DO/+LOOP: 'EVENS' outputs '0 2 4 6 8'"; \
	else \
		echo "FAIL: REPL test 52 — expected '0 2 4 6 8' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': FIND5 10 0 DO I 5 = IF I . LEAVE THEN LOOP ; FIND5\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r' | grep -q '^5  ok$$' && ! echo "$$OUTPUT" | tr -d '\r' | grep -q '^5 6'; then \
		echo "PASS: REPL test 53 — DO/LOOP/LEAVE: 'FIND5' outputs '5' and exits early"; \
	else \
		echo "FAIL: REPL test 53 — expected '5' only (no subsequent iterations)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': NEST 3 0 DO 3 0 DO J . I . LOOP LOOP ; NEST\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '0 0 0 1 0 2 1 0 1 1 1 2 2 0 2 1 2 2 '; then \
		echo "PASS: REPL test 54 — nested DO/LOOP with I and J: 'NEST' outputs correct sequence"; \
	else \
		echo "FAIL: REPL test 54 — expected '0 0 0 1 0 2 1 0 1 1 1 2 2 0 2 1 2 2' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': FACT DUP 1 > IF DUP 1 - RECURSE * THEN ; 5 FACT .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r' | grep -q '^120  ok$$'; then \
		echo "PASS: REPL test 55 — RECURSE: '5 FACT .' outputs '120'"; \
	else \
		echo "FAIL: REPL test 55 — expected '120' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': FACT7 DUP 1 > IF DUP 1 - RECURSE * THEN ; 7 FACT7 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r' | grep -q '^5040  ok$$'; then \
		echo "PASS: REPL test 56 — RECURSE: '7 FACT7 .' outputs '5040'"; \
	else \
		echo "FAIL: REPL test 56 — expected '5040' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'DO\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -14: interpreting a compile-only word' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 57 — compile-only guard: DO in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 57 — expected 'error -14: interpreting a compile-only word' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'LOOP\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -14: interpreting a compile-only word' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 58 — compile-only guard: LOOP in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 58 — expected 'error -14: interpreting a compile-only word' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '+LOOP\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -14: interpreting a compile-only word' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 59 — compile-only guard: +LOOP in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 59 — expected 'error -14: interpreting a compile-only word' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'LEAVE\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -14: interpreting a compile-only word' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 60 — compile-only guard: LEAVE in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 60 — expected 'error -14: interpreting a compile-only word' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'RECURSE\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -14: interpreting a compile-only word' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 61 — compile-only guard: RECURSE in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 61 — expected 'error -14: interpreting a compile-only word' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': ONE 1 0 DO 42 . LOOP ; ONE\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '42 '; then \
		echo "PASS: REPL test 62 — single-iteration DO/LOOP: 'ONE' outputs '42'"; \
	else \
		echo "FAIL: REPL test 62 — expected '42' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': TWOL 10 0 DO I 3 = IF LEAVE THEN I 7 = IF LEAVE THEN LOOP 99 . ; TWOL\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '99 '; then \
		echo "PASS: REPL test 63 — multiple LEAVEs in one loop: 'TWOL' outputs '99'"; \
	else \
		echo "FAIL: REPL test 63 — expected '99' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': DN 0 10 DO I . -1 +LOOP ; DN\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '10 9 8 7 6 5 4 3 2 1 0 '; then \
		echo "PASS: REPL test 64 — countdown with -1 +LOOP: 'DN' outputs '10 9 8 7 6 5 4 3 2 1 0'"; \
	else \
		echo "FAIL: REPL test 64 — expected '10 9 8 7 6 5 4 3 2 1 0' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': FOO ; IMMEDIATE\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 65 — IMMEDIATE: define word and mark IMMEDIATE, no crash"; \
	else \
		echo "FAIL: REPL test 65 — expected 'ok' after IMMEDIATE"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': COMP-DUP POSTPONE DUP ; IMMEDIATE : DOUBLE COMP-DUP * ; 7 DOUBLE .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '49 '; then \
		echo "PASS: REPL test 66 — POSTPONE non-IMMEDIATE word: 7 DOUBLE outputs 49"; \
	else \
		echo "FAIL: REPL test 66 — expected '49' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': COMP-IF POSTPONE IF ; IMMEDIATE : TEST 1 COMP-IF 42 THEN . ; TEST\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '42 '; then \
		echo "PASS: REPL test 67 — POSTPONE IMMEDIATE word: TEST outputs 42"; \
	else \
		echo "FAIL: REPL test 67 — expected '42' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': GREET S" Hello" TYPE ; GREET\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q 'Hello'; then \
		echo "PASS: REPL test 68 — S\" in compile mode: GREET outputs Hello"; \
	else \
		echo "FAIL: REPL test 68 — expected 'Hello' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': HI ." Hello World" ; HI\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q 'Hello World'; then \
		echo "PASS: REPL test 69 — .\" in compile mode: HI outputs Hello World"; \
	else \
		echo "FAIL: REPL test 69 — expected 'Hello World' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'S" test" TYPE\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q 'test'; then \
		echo "PASS: REPL test 70 — S\" in interpret mode: outputs test"; \
	else \
		echo "FAIL: REPL test 70 — expected 'test' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': LEN S" abcde" SWAP DROP . ; LEN\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 71 — S\" string length: LEN outputs 5"; \
	else \
		echo "FAIL: REPL test 71 — expected '5' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'WORDS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'DUP' && echo "$$OUTPUT" | grep -q 'DROP' && echo "$$OUTPUT" | grep -q 'SWAP'; then \
		echo "PASS: REPL test 72 — WORDS lists known words (DUP, DROP, SWAP found)"; \
	else \
		echo "FAIL: REPL test 72 — expected DUP, DROP, SWAP in WORDS output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'POSTPONE\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -14: interpreting a compile-only word' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 73 — POSTPONE in interpret mode shows compile-only error and recovers"; \
	else \
		echo "FAIL: REPL test 73 — expected 'error -14: interpreting a compile-only word' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '." hello"\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q 'hello'; then \
		echo "PASS: REPL test 74 — .\" in interpret mode: prints hello"; \
	else \
		echo "FAIL: REPL test 74 — expected 'hello' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': GREET2 ." Hi " ." There" ; GREET2\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q 'Hi There'; then \
		echo "PASS: REPL test 75 — multiple .\" in one definition: GREET2 outputs Hi There"; \
	else \
		echo "FAIL: REPL test 75 — expected 'Hi There' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': EMPTY S" " SWAP DROP . ; EMPTY\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '0 '; then \
		echo "PASS: REPL test 76 — empty S\" string: SWAP DROP . outputs 0"; \
	else \
		echo "FAIL: REPL test 76 — expected '0' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': LONG S" ABCDEFGHIJKLMNOPQRSTUVWXYZ" TYPE ; LONG\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'; then \
		echo "PASS: REPL test 77 — long S\" string: outputs full alphabet"; \
	else \
		echo "FAIL: REPL test 77 — expected 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': BAD POSTPONE XYZZY ;\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'XYZZY ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 78 — POSTPONE undefined word: shows error and recovers"; \
	else \
		echo "FAIL: REPL test 78 — expected 'XYZZY ?' error and recovery to '5'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': COMP-SWAP POSTPONE SWAP ; IMMEDIATE : REV COMP-SWAP . . ; 1 2 REV\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '1 2 '; then \
		echo "PASS: REPL test 79 — COMPILE, via POSTPONE non-IMMEDIATE: 1 2 REV outputs 1 2"; \
	else \
		echo "FAIL: REPL test 79 — expected '1 2' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'BYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'AntForth v1.1.0'; then \
		echo "PASS: REPL test 80 — Banner version string: output contains 'AntForth v1.1.0'"; \
	else \
		echo "FAIL: REPL test 80 — expected 'AntForth v1.1.0' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi && \
	if echo "$$OUTPUT" | grep -qE '[0-9]+ bytes free'; then \
		echo "PASS: REPL test 81 — Banner free memory: output contains numeric value before 'bytes free'"; \
	else \
		echo "FAIL: REPL test 81 — expected '<number> bytes free' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi && \
	if echo "$$OUTPUT" | grep -q 'MicroBeast'; then \
		echo "PASS: REPL test 82 — Banner platform: output contains 'MicroBeast'"; \
	else \
		echo "FAIL: REPL test 82 — expected 'MicroBeast' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi && \
	if ! echo "$$OUTPUT" | grep -qE -- '-[0-9]+ bytes free'; then \
		echo "PASS: REPL test 83 — Banner free memory unsigned: no negative sign before 'bytes free'"; \
	else \
		echo "FAIL: REPL test 83 — free memory should be unsigned, got negative"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi && \
	if echo "$$OUTPUT" | grep -q 'Type BYE to exit'; then \
		echo "PASS: REPL test 84 — Banner exit hint: output contains 'Type BYE to exit'"; \
	else \
		echo "FAIL: REPL test 84 — expected 'Type BYE to exit' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE MYDUP BC PUSH, NEXT, END-CODE\r\n5 MYDUP . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 5 '; then \
		echo "PASS: REPL test 85 — CODE MYDUP: '5 MYDUP . .' outputs '5 5'"; \
	else \
		echo "FAIL: REPL test 85 — expected '5 5' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE TCA BC PUSH, A XOR, C A LD, NEXT, END-CODE\r\n99 TCA . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '0 99 '; then \
		echo "PASS: REPL test 86 — LD, r-r encoding: 'C A LD,' assembles LD C,A, '99 TCA . .' outputs '0 99'"; \
	else \
		echo "FAIL: REPL test 86 — expected '0 99' in output (wrong LD, encoding or reversed operand order)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE DBL BC PUSH, A XOR, C ADD, C ADD, C A LD, A XOR, B A LD, NEXT, END-CODE\r\n21 DBL . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '42 21 '; then \
		echo "PASS: REPL test 87 — multi-instruction CODE word DBL: '21 DBL . .' outputs '42 21'"; \
	else \
		echo "FAIL: REPL test 87 — expected '42 21' (DBL doubles low byte; wrong ADD,/LD, encoding or register clobber)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE ZORK BC PUSH, NEXT, END-CODE\r\nWORDS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'ZORK'; then \
		echo "PASS: REPL test 88 — WORDS lists newly-defined CODE word ZORK"; \
	else \
		echo "FAIL: REPL test 88 — expected 'ZORK' in WORDS output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE FOO NONEXISTENT,\r\n1 2 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'NONEXISTENT, ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 89 — error recovery: bad word inside CODE aborts cleanly, next input still works"; \
	else \
		echo "FAIL: REPL test 89 — expected 'NONEXISTENT, ?' error and '3' from '1 2 + .'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE BL1 LABEL TOP TOP FIX A A LD, TOP JR, NEXT, END-CODE\r\nXT BL1 2 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '253 '; then \
		echo "PASS: REPL test 90 — backward JR encoding: displacement byte = 0xFD = 253"; \
	else \
		echo "FAIL: REPL test 90 — expected '253 ' (0xFD displacement) in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE FW1 LABEL SKIP SKIP JR, 255 DB, SKIP FIX NEXT, END-CODE\r\nXT FW1 0 + C@ . XT FW1 1 + C@ . XT FW1 2 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '24 1 255 '; then \
		echo "PASS: REPL test 91 — forward JR encoding: opcode 24, disp +1, DB byte 255"; \
	else \
		echo "FAIL: REPL test 91 — expected '24 1 255 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE DATAW 170 DB, 4660 DW, 3 DS, NEXT, END-CODE\r\nXT DATAW 0 + C@ . XT DATAW 1 + C@ . XT DATAW 2 + C@ . XT DATAW 3 + C@ . XT DATAW 4 + C@ . XT DATAW 5 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '170 52 18 0 0 0 '; then \
		echo "PASS: REPL test 92 — DB,/DW,/DS, encoding: 170 52 18 0 0 0"; \
	else \
		echo "FAIL: REPL test 92 — expected '170 52 18 0 0 0 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\n66 EQU PORT-A\r\nPORT-A .\r\nCODE EUSE PORT-A DB, NEXT, END-CODE\r\nXT EUSE C@ .\r\nWORDS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	N66=$$(echo "$$OUTPUT" | grep -oE '66 ' | wc -l) && \
	if [ "$$N66" -ge 2 ] && echo "$$OUTPUT" | grep -q 'PORT-A' && echo "$$OUTPUT" | grep -q 'EUSE'; then \
		echo "PASS: REPL test 93 — EQU end-to-end: PORT-A prints 66, used in CODE, listed in WORDS"; \
	else \
		echo "FAIL: REPL test 93 — expected '66' twice and PORT-A/EUSE in WORDS"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE DW1 LABEL TGT TGT DW, TGT FIX NEXT, END-CODE\r\nXT DW1 @ XT DW1 2 + = .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-1 '; then \
		echo "PASS: REPL test 94 — DW, with label: stored value equals xt+2"; \
	else \
		echo "FAIL: REPL test 94 — expected '-1 ' (true) from address comparison"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD LABEL X X JR, NEXT, END-CODE\r\n1 2 + .\r\nWORDS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	WORDS_LINE=$$(echo "$$OUTPUT" | tr -d '\r' | grep -E '^@ ' || true) && \
	if echo "$$OUTPUT" | grep -q 'unresolved label X ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 ' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^BAD$$' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^X$$'; then \
		echo "PASS: REPL test 95 — unresolved fixup: error, clean recovery, BAD and X not leaked"; \
	else \
		echo "FAIL: REPL test 95 — expected 'unresolved label X ?', '3', and BAD/X absent from WORDS"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD2 LABEL Y Y FIX A A LD, Y FIX NEXT, END-CODE\r\n1 2 + .\r\nWORDS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	WORDS_LINE=$$(echo "$$OUTPUT" | tr -d '\r' | grep -E '^@ ' || true) && \
	if echo "$$OUTPUT" | grep -q 'already fixed: Y ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 ' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^BAD2$$' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^Y$$'; then \
		echo "PASS: REPL test 96 — FIX already fixed: error, recovery, BAD2 and Y not leaked"; \
	else \
		echo "FAIL: REPL test 96 — expected 'already fixed: Y ?', '3', BAD2/Y absent from WORDS"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD3 A A LD, LABEL ZED NEXT, END-CODE\r\n1 2 + .\r\nWORDS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	WORDS_LINE=$$(echo "$$OUTPUT" | tr -d '\r' | grep -E '^@ ' || true) && \
	if echo "$$OUTPUT" | grep -q 'error -262: LABEL must precede opcodes' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 ' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^BAD3$$' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^ZED$$'; then \
		echo "PASS: REPL test 97 — LABEL after opcodes: error, recovery, BAD3 and ZED not leaked"; \
	else \
		echo "FAIL: REPL test 97 — expected 'error -262: LABEL must precede opcodes', '3', BAD3/ZED absent"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD4 LABEL TGT TGT FIX 130 DS, TGT JR, NEXT, END-CODE\r\n1 2 + .\r\nWORDS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	WORDS_LINE=$$(echo "$$OUTPUT" | tr -d '\r' | grep -E '^@ ' || true) && \
	if echo "$$OUTPUT" | grep -q 'error -263: JR out of range' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 ' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^BAD4$$' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^TGT$$'; then \
		echo "PASS: REPL test 98 — out-of-range JR: error, recovery, BAD4 and TGT not leaked"; \
	else \
		echo "FAIL: REPL test 98 — expected 'error -263: JR out of range', '3', BAD4/TGT absent"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD5 LABEL OK PUHS, NEXT, END-CODE\r\n1 2 + .\r\nWORDS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	WORDS_LINE=$$(echo "$$OUTPUT" | tr -d '\r' | grep -E '^@ ' || true) && \
	if echo "$$OUTPUT" | grep -q 'PUHS, ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 ' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^BAD5$$' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^OK$$'; then \
		echo "PASS: REPL test 99 — typo guard: PUHS, error, recovery, BAD5 and OK not leaked"; \
	else \
		echo "FAIL: REPL test 99 — expected 'PUHS, ?', '3', BAD5/OK absent from WORDS"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'LABEL FOO\r\n1 2 + .\r\n0 FIX\r\n1 2 + .\r\n66 DB,\r\n1 2 + .\r\n4660 DW,\r\n1 2 + .\r\n1 DS,\r\n1 2 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	NCOUNT=$$(echo "$$OUTPUT" | grep -c 'error -270: not in CODE') && \
	NREC=$$(echo "$$OUTPUT" | tr -d '\r\n' | grep -oE '3 ' | wc -l) && \
	if [ "$$NCOUNT" -ge 5 ] && [ "$$NREC" -ge 5 ]; then \
		echo "PASS: REPL test 100 — LABEL/FIX/DB,/DW,/DS, outside CODE: 5 errors, 5 clean recoveries (Story 11.6: -270)"; \
	else \
		echo "FAIL: REPL test 100 — expected 5x 'error -270: not in CODE' and 5x recovery (got $$NCOUNT errors, $$NREC '3 ')"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD6 1 EQU FOO NEXT, END-CODE\r\n1 2 + .\r\nWORDS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	WORDS_LINE=$$(echo "$$OUTPUT" | tr -d '\r' | grep -E '^@ ' || true) && \
	if echo "$$OUTPUT" | grep -q 'error -266: EQU outside CODE only' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 ' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^BAD6$$' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^FOO$$'; then \
		echo "PASS: REPL test 101 — EQU inside CODE: error, recovery, BAD6 and FOO not leaked"; \
	else \
		echo "FAIL: REPL test 101 — expected 'error -266: EQU outside CODE only', '3', BAD6/FOO absent"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE A1 LABEL LBL LBL FIX A A LD, NEXT, END-CODE\r\nCODE A2 LABEL LBL LBL FIX B B LD, NEXT, END-CODE\r\nWORDS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	WORDS_LINE=$$(echo "$$OUTPUT" | tr -d '\r' | grep -E '^@ ' || true) && \
	if echo "$$OUTPUT" | grep -q 'A1' && echo "$$OUTPUT" | grep -q 'A2' && ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^LBL$$'; then \
		echo "PASS: REPL test 102 — label scoping across CODE words: A1, A2 in WORDS, LBL not"; \
	else \
		echo "FAIL: REPL test 102 — expected A1, A2 in WORDS but no LBL"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BIG LABEL L1 LABEL L2 LABEL L3 LABEL L4 LABEL L5 LABEL L6 LABEL L7 LABEL L8 LABEL L9 LABEL L10 LABEL L11 LABEL L12 LABEL L13 LABEL L14 LABEL L15 LABEL L16 LABEL L17 NEXT, END-CODE\r\n1 2 + .\r\nWORDS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	WORDS_LINE=$$(echo "$$OUTPUT" | tr -d '\r' | grep -E '^@ ' || true) && \
	if echo "$$OUTPUT" | grep -q 'error -264: too many labels' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 ' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^BIG$$' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^L1$$' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^L16$$'; then \
		echo "PASS: REPL test 103 — label-pool overflow: error, recovery, BIG and L1..L16 not leaked"; \
	else \
		echo "FAIL: REPL test 103 — expected 'error -264: too many labels', '3', BIG/L1/L16 absent"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE MYDUP BC PUSH, NEXT, END-CODE\r\n5 MYDUP . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '5 5 '; then \
		echo "PASS: REPL test 104 — Story 4.1 regression spot-check: '5 MYDUP . .' outputs '5 5'"; \
	else \
		echo "FAIL: REPL test 104 — Story 4.1 regression broken"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@JRS=$$(yes 'F JR,' | head -33 | tr '\n' ' '); \
	OUTPUT=$$(printf 'CODE FXOF LABEL F %sF FIX NEXT, END-CODE\r\n1 2 + .\r\nWORDS\r\nBYE\r\n' "$$JRS" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	WORDS_LINE=$$(echo "$$OUTPUT" | tr -d '\r' | grep -E '^@ ' || true) && \
	if echo "$$OUTPUT" | grep -q 'error -265: too many fixups' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 ' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^FXOF$$' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^F$$'; then \
		echo "PASS: REPL test 105 — fixup-pool overflow: 33 forward JRs hit 'too many fixups ?'"; \
	else \
		echo "FAIL: REPL test 105 — expected 'error -265: too many fixups', '3', FXOF/F absent from WORDS"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE LIT4 HERE 5 + JR, NEXT, END-CODE\r\nXT LIT4 C@ . XT LIT4 1 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '24 3 '; then \
		echo "PASS: REPL test 106 — literal-address JR,: opcode 24, disp +3 (HERE+5 - HERE-2)"; \
	else \
		echo "FAIL: REPL test 106 — expected '24 3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nHEX\r\nCODE I8 B 55 # LD, C 66 # LD, A 77 # LD, NEXT, END-CODE\r\nXT I8 0 + C@ . XT I8 1 + C@ . XT I8 2 + C@ . XT I8 3 + C@ . XT I8 4 + C@ . XT I8 5 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '6 55 E 66 3E 77 '; then \
		echo "PASS: REPL test 107 — LD r,n: 06 55 0E 66 3E 77"; \
	else \
		echo "FAIL: REPL test 107 — expected '6 55 E 66 3E 77 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nHEX\r\nCODE I16 BC 1234 # LD, DE 5678 # LD, HL ABCD # LD, SP FFFE # LD, NEXT, END-CODE\r\nXT I16 0 + C@ . XT I16 1 + C@ . XT I16 2 + C@ . XT I16 3 + C@ .\r\nXT I16 4 + C@ . XT I16 5 + C@ . XT I16 6 + C@ . XT I16 7 + C@ .\r\nXT I16 8 + C@ . XT I16 9 + C@ . XT I16 0A + C@ . XT I16 0B + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	JOINED=$$(echo "$$OUTPUT" | tr -d '\r\n') && \
	if echo "$$JOINED" | grep -q '1 34 12 11 ' && echo "$$JOINED" | grep -q '78 56 21 CD ' && echo "$$JOINED" | grep -q 'AB 31 FE FF '; then \
		echo "PASS: REPL test 108 — LD rr,nn: BC/DE/HL/SP immediate loads"; \
	else \
		echo "FAIL: REPL test 108 — expected '1 34 12 11 78 56 21 CD AB 31 FE FF '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'HEX\r\nCODE BADAF AF 1234 # LD, NEXT, END-CODE\r\nDECIMAL\r\n1 2 + .\r\nWORDS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	WORDS_LINE=$$(echo "$$OUTPUT" | tr -d '\r' | grep -E '^@ ' || true) && \
	if echo "$$OUTPUT" | grep -q 'error -258: bad operand' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 ' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^BADAF$$'; then \
		echo "PASS: REPL test 109 — LD rr,nn rejects AF: error, recovery, BADAF not leaked"; \
	else \
		echo "FAIL: REPL test 109 — expected 'error -258: bad operand' and BADAF absent"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nHEX\r\nCODE LDHL A (HL) LD, B (HL) LD, C (HL) LD, NEXT, END-CODE\r\nXT LDHL 0 + C@ . XT LDHL 1 + C@ . XT LDHL 2 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '7E 46 4E '; then \
		echo "PASS: REPL test 110 — LD r,(HL): 7E 46 4E"; \
	else \
		echo "FAIL: REPL test 110 — expected '7E 46 4E '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nHEX\r\nCODE STHL (HL) A LD, (HL) B LD, (HL) C LD, NEXT, END-CODE\r\nXT STHL 0 + C@ . XT STHL 1 + C@ . XT STHL 2 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '77 70 71 '; then \
		echo "PASS: REPL test 111 — LD (HL),r: 77 70 71"; \
	else \
		echo "FAIL: REPL test 111 — expected '77 70 71 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BADHH (HL) (HL) LD, NEXT, END-CODE\r\n1 2 + .\r\nWORDS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	WORDS_LINE=$$(echo "$$OUTPUT" | tr -d '\r' | grep -E '^@ ' || true) && \
	if echo "$$OUTPUT" | grep -q 'error -258: bad operand' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 ' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^BADHH$$'; then \
		echo "PASS: REPL test 112 — (HL),(HL) LD, rejected: error, recovery, BADHH not leaked"; \
	else \
		echo "FAIL: REPL test 112 — expected 'error -258: bad operand' and BADHH absent"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nHEX\r\nCODE RR B C LD, NEXT, END-CODE\r\nXT RR 0 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '41 '; then \
		echo "PASS: REPL test 113 — Story 4.1 r-r LD regression: B C LD, → LD B,C = 0x41"; \
	else \
		echo "FAIL: REPL test 113 — expected '41 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nHEX\r\nCODE JP1 1234 JP, END-CODE\r\nXT JP1 0 + C@ . XT JP1 1 + C@ . XT JP1 2 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE 'C3 34 12 '; then \
		echo "PASS: REPL test 114 — unconditional JP, nn: C3 34 12"; \
	else \
		echo "FAIL: REPL test 114 — expected 'C3 34 12 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nHEX\r\nCODE JP2 NZ 1234 JP, Z 5678 JP, NC 9ABC JP, CS DEF0 JP, END-CODE\r\nXT JP2 0 + C@ . XT JP2 3 + C@ . XT JP2 6 + C@ . XT JP2 9 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE 'C2 CA D2 DA '; then \
		echo "PASS: REPL test 115 — conditional JP cc,nn: C2 CA D2 DA"; \
	else \
		echo "FAIL: REPL test 115 — expected 'C2 CA D2 DA '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nHEX\r\nCODE JL LABEL TGT TGT JP, TGT FIX NEXT, END-CODE\r\nXT JL 1 + @ XT JL 3 + = .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-1 '; then \
		echo "PASS: REPL test 116 — JP, label tag: forward fixup patches absolute target"; \
	else \
		echo "FAIL: REPL test 116 — expected '-1 ' (truth flag)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nHEX\r\nCODE C1 1234 CALL, END-CODE\r\nXT C1 0 + C@ . XT C1 1 + C@ . XT C1 2 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE 'CD 34 12 '; then \
		echo "PASS: REPL test 117 — unconditional CALL, nn: CD 34 12"; \
	else \
		echo "FAIL: REPL test 117 — expected 'CD 34 12 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nHEX\r\nCODE C2 NZ 1111 CALL, Z 2222 CALL, NC 3333 CALL, CS 4444 CALL, PO 5555 CALL, PE 6666 CALL, P 7777 CALL, M 8888 CALL, END-CODE\r\nXT C2 0 + C@ . XT C2 3 + C@ . XT C2 6 + C@ . XT C2 9 + C@ .\r\nXT C2 0C + C@ . XT C2 0F + C@ . XT C2 12 + C@ . XT C2 15 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	JOINED=$$(echo "$$OUTPUT" | tr -d '\r\n') && \
	if echo "$$JOINED" | grep -q 'C4 CC D4 DC ' && echo "$$JOINED" | grep -q 'E4 EC F4 FC '; then \
		echo "PASS: REPL test 118 — conditional CALL cc,nn: all 8 conditions"; \
	else \
		echo "FAIL: REPL test 118 — expected 'C4 CC D4 DC E4 EC F4 FC '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nHEX\r\nCODE R1 RET, END-CODE\r\nDECIMAL\r\nXT R1 0 + C@ . .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '201 +<0> '; then \
		echo "PASS: REPL test 119 — unconditional RET, = 0xC9 (201), no spurious push"; \
	else \
		echo "FAIL: REPL test 119 — expected '201 ' then '<0> '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nHEX\r\nCODE R2 NZ RET, Z RET, NC RET, CS RET, PO RET, PE RET, P RET, M RET, NEXT, END-CODE\r\nXT R2 0 + C@ . XT R2 1 + C@ . XT R2 2 + C@ . XT R2 3 + C@ . XT R2 4 + C@ . XT R2 5 + C@ . XT R2 6 + C@ . XT R2 7 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE 'C0 C8 D0 D8 E0 E8 F0 F8 '; then \
		echo "PASS: REPL test 120 — conditional RET cc: all 8 conditions"; \
	else \
		echo "FAIL: REPL test 120 — expected 'C0 C8 D0 D8 E0 E8 F0 F8 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE JR1 LABEL TOP TOP FIX A OR, NZ TOP JR, NEXT, END-CODE\r\nXT JR1 0 + C@ . XT JR1 1 + C@ . XT JR1 2 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '183 32 253 '; then \
		echo "PASS: REPL test 121 — conditional JR cc,e: B7 20 FD"; \
	else \
		echo "FAIL: REPL test 121 — expected '183 32 253 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BADJR LABEL T T FIX PO T JR, NEXT, END-CODE\r\n1 2 + .\r\nWORDS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	WORDS_LINE=$$(echo "$$OUTPUT" | tr -d '\r' | grep -E '^@ ' || true) && \
	if echo "$$OUTPUT" | grep -q 'error -258: bad operand' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 ' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^BADJR$$' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^T$$'; then \
		echo "PASS: REPL test 122 — conditional JR rejects PO: error, BADJR/T not leaked"; \
	else \
		echo "FAIL: REPL test 122 — expected 'error -258: bad operand' and BADJR/T absent"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nHEX\r\nCODE AI 0F # AND, F0 # OR, AA # XOR, 10 # ADD, 20 # SUB, 30 # CP, NEXT, END-CODE\r\nXT AI 0 + C@ . XT AI 1 + C@ . XT AI 2 + C@ . XT AI 3 + C@ .\r\nXT AI 4 + C@ . XT AI 5 + C@ . XT AI 6 + C@ . XT AI 7 + C@ .\r\nXT AI 8 + C@ . XT AI 9 + C@ . XT AI 0A + C@ . XT AI 0B + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	JOINED=$$(echo "$$OUTPUT" | tr -d '\r\n') && \
	if echo "$$JOINED" | grep -q 'E6 F F6 F0 ' && echo "$$JOINED" | grep -q 'EE AA C6 10 ' && echo "$$JOINED" | grep -q 'D6 20 FE 30 '; then \
		echo "PASS: REPL test 123 — arith immediates: AND/OR/XOR/ADD/SUB/CP"; \
	else \
		echo "FAIL: REPL test 123 — expected 'E6 F F6 F0 EE AA C6 10 D6 20 FE 30 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nHEX\r\nCODE AR B AND, NEXT, END-CODE\r\nXT AR 0 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE 'A0 '; then \
		echo "PASS: REPL test 124 — arith register-form regression: AND B = A0"; \
	else \
		echo "FAIL: REPL test 124 — expected 'A0 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BADJP LABEL X X JP, NEXT, END-CODE\r\n1 2 + .\r\nWORDS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	WORDS_LINE=$$(echo "$$OUTPUT" | tr -d '\r' | grep -E '^@ ' || true) && \
	if echo "$$OUTPUT" | grep -q 'unresolved label X ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 ' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^BADJP$$' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^X$$'; then \
		echo "PASS: REPL test 125 — unresolved JP fixup: error, BADJP/X not leaked"; \
	else \
		echo "FAIL: REPL test 125 — expected 'unresolved label X ?' and BADJP/X absent"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BADCALL LABEL Y Y CALL, NEXT, END-CODE\r\n1 2 + .\r\nWORDS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	WORDS_LINE=$$(echo "$$OUTPUT" | tr -d '\r' | grep -E '^@ ' || true) && \
	if echo "$$OUTPUT" | grep -q 'unresolved label Y ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 ' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^BADCALL$$' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^Y$$'; then \
		echo "PASS: REPL test 126 — unresolved CALL fixup: error, BADCALL/Y not leaked"; \
	else \
		echo "FAIL: REPL test 126 — expected 'unresolved label Y ?' and BADCALL/Y absent"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '42 #\r\n1 2 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'stack underflow' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 127 — # outside CODE dispatches to pictured-output # (DEPTH=1 → underflow), clean recovery"; \
	else \
		echo "FAIL: REPL test 127 — expected 'stack underflow' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '(HL)\r\n1 2 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '\(HL\) \?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 128 — (HL) outside CODE rejected (recognizer miss), clean recovery"; \
	else \
		echo "FAIL: REPL test 128 — expected '(HL) ?' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'NZ\r\nZ\r\nNC\r\nCS\r\nPO\r\nPE\r\nP\r\nM\r\nHEX\r\nCC .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	ERRCOUNT=$$(echo "$$OUTPUT" | grep -cE '^[A-Z]{1,2} \?') && \
	if [ "$$ERRCOUNT" -ge 8 ] && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE 'CC '; then \
		echo "PASS: REPL test 129 — conditions outside CODE rejected (recognizer miss); CC literal still parses in HEX"; \
	else \
		echo "FAIL: REPL test 129 — expected 8x '<word> ?' and 'CC ' literal"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE BL1B LABEL TOP TOP FIX A A LD, TOP JR, NEXT, END-CODE\r\nXT BL1B 2 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '253 '; then \
		echo "PASS: REPL test 130 — Story 4.2 backward JR regression: disp = 253 (-3)"; \
	else \
		echo "FAIL: REPL test 130 — expected '253 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 2 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 131 — cold-start spot-check: '1 2 + .' = '3 '"; \
	else \
		echo "FAIL: REPL test 131 — expected '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD132 A 0 LD, END-CODE\r\n1 2 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'bare integer.*?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 132 — forgot-# in LD, src: bare integer detected, clean recovery"; \
	else \
		echo "FAIL: REPL test 132 — expected 'bare integer ...' error and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD133 0 A LD, END-CODE\r\n1 2 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'bare integer.*?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 133 — bare integer in dst: bare integer detected, clean recovery"; \
	else \
		echo "FAIL: REPL test 133 — expected 'bare integer ...' error and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK134 A 42 # LD, NEXT, END-CODE\r\nXT OK134 0 + C@ . XT OK134 1 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '62 42 '; then \
		echo "PASS: REPL test 134 — A 42 # LD, assembles 3E 2A (62 42)"; \
	else \
		echo "FAIL: REPL test 134 — expected '62 42 ' (0x3E 0x2A)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nHEX\r\nCODE OK135 BC 1234 # LD, NEXT, END-CODE\r\nDECIMAL\r\nXT OK135 0 + C@ . XT OK135 1 + C@ . XT OK135 2 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '1 52 18 '; then \
		echo "PASS: REPL test 135 — BC 1234h # LD, assembles 01 34 12"; \
	else \
		echo "FAIL: REPL test 135 — expected '1 52 18 ' (0x01 0x34 0x12)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD136 A 0 ADD, END-CODE\r\n1 2 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'bare integer.*?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 136 — forgot-# in ADD,: bare integer detected, clean recovery"; \
	else \
		echo "FAIL: REPL test 136 — expected 'bare integer ...' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK137 42 # ADD, NEXT, END-CODE\r\nXT OK137 0 + C@ . XT OK137 1 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '198 42 '; then \
		echo "PASS: REPL test 137 — 42 # ADD, assembles C6 2A (198 42)"; \
	else \
		echo "FAIL: REPL test 137 — expected '198 42 ' (0xC6 0x2A)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD138 0 PUSH, END-CODE\r\n1 2 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'bare integer.*?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 138 — bare integer in PUSH,: error detected, clean recovery"; \
	else \
		echo "FAIL: REPL test 138 — expected 'bare integer ...' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK139 B C LD, A B LD, NEXT, END-CODE\r\nXT OK139 0 + C@ . XT OK139 1 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '65 120 '; then \
		echo "PASS: REPL test 139 — existing r-r LD still works: B C LD,=0x41, A B LD,=0x78"; \
	else \
		echo "FAIL: REPL test 139 — expected '65 120 ' (0x41 0x78)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- Story 4.4 tests: Extended Z80 Opcodes ---
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK140 B INC, A DEC, (HL) INC, NEXT, END-CODE\r\nXT OK140 0 + C@ . XT OK140 1 + C@ . XT OK140 2 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '4 61 52 '; then \
		echo "PASS: REPL test 140 — B INC,=04, A DEC,=3D, (HL) INC,=34"; \
	else \
		echo "FAIL: REPL test 140 — expected '4 61 52 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK141 BC INC, SP DEC, NEXT, END-CODE\r\nXT OK141 0 + C@ . XT OK141 1 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 59 '; then \
		echo "PASS: REPL test 141 — BC INC,=03, SP DEC,=3B"; \
	else \
		echo "FAIL: REPL test 141 — expected '3 59 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK142 IX INC, IY DEC, NEXT, END-CODE\r\nXT OK142 0 + C@ . XT OK142 1 + C@ . XT OK142 2 + C@ . XT OK142 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '221 35 253 43 '; then \
		echo "PASS: REPL test 142 — IX INC,=DD23, IY DEC,=FD2B"; \
	else \
		echo "FAIL: REPL test 142 — expected '221 35 253 43 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK143 (IX) 5 +D INC, (IY) 3 +D DEC, NEXT, END-CODE\r\nXT OK143 0 + C@ . XT OK143 1 + C@ . XT OK143 2 + C@ . XT OK143 3 + C@ . XT OK143 4 + C@ . XT OK143 5 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '221 52 5 253 53 3 '; then \
		echo "PASS: REPL test 143 — (IX) 5 +D INC,=DD3405, (IY) 3 +D DEC,=FD3503"; \
	else \
		echo "FAIL: REPL test 143 — expected '221 52 5 253 53 3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK144 A RLC, B RRC, L SRL, NEXT, END-CODE\r\nXT OK144 0 + C@ . XT OK144 1 + C@ . XT OK144 2 + C@ . XT OK144 3 + C@ . XT OK144 4 + C@ . XT OK144 5 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '203 7 203 8 203 61 '; then \
		echo "PASS: REPL test 144 — A RLC,=CB07, B RRC,=CB08, L SRL,=CB3D"; \
	else \
		echo "FAIL: REPL test 144 — expected '203 7 203 8 203 61 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK145 (HL) RLC, (HL) SRA, NEXT, END-CODE\r\nXT OK145 0 + C@ . XT OK145 1 + C@ . XT OK145 2 + C@ . XT OK145 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '203 6 203 46 '; then \
		echo "PASS: REPL test 145 — (HL) RLC,=CB06, (HL) SRA,=CB2E"; \
	else \
		echo "FAIL: REPL test 145 — expected '203 6 203 46 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK146 (IX) 5 +D RLC, NEXT, END-CODE\r\nXT OK146 0 + C@ . XT OK146 1 + C@ . XT OK146 2 + C@ . XT OK146 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '221 203 5 6 '; then \
		echo "PASS: REPL test 146 — (IX) 5 +D RLC,=DDCB0506"; \
	else \
		echo "FAIL: REPL test 146 — expected '221 203 5 6 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK147 3 # A BIT, 5 # B SET, 7 # C RES, NEXT, END-CODE\r\nXT OK147 0 + C@ . XT OK147 1 + C@ . XT OK147 2 + C@ . XT OK147 3 + C@ . XT OK147 4 + C@ . XT OK147 5 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '203 95 203 232 203 185 '; then \
		echo "PASS: REPL test 147 — 3 # A BIT,=CB5F, 5 # B SET,=CBE8, 7 # C RES,=CBB9"; \
	else \
		echo "FAIL: REPL test 147 — expected '203 95 203 232 203 185 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK148 3 # (HL) BIT, NEXT, END-CODE\r\nXT OK148 0 + C@ . XT OK148 1 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '203 94 '; then \
		echo "PASS: REPL test 148 — 3 # (HL) BIT,=CB5E"; \
	else \
		echo "FAIL: REPL test 148 — expected '203 94 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK149 3 # (IX) 5 +D BIT, NEXT, END-CODE\r\nXT OK149 0 + C@ . XT OK149 1 + C@ . XT OK149 2 + C@ . XT OK149 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '221 203 5 94 '; then \
		echo "PASS: REPL test 149 — 3 # (IX) 5 +D BIT,=DDCB055E"; \
	else \
		echo "FAIL: REPL test 149 — expected '221 203 5 94 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD150 8 # A BIT, END-CODE\r\n1 2 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -271: range' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 150 — bit 8 raises error -271: range, clean recovery (Story 11.6)"; \
	else \
		echo "FAIL: REPL test 150 — expected 'error -271: range' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK151 (C) A IN, A (C) OUT, NEXT, END-CODE\r\nXT OK151 0 + C@ . XT OK151 1 + C@ . XT OK151 2 + C@ . XT OK151 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 120 237 121 '; then \
		echo "PASS: REPL test 151 — (C) A IN,=ED78, A (C) OUT,=ED79"; \
	else \
		echo "FAIL: REPL test 151 — expected '237 120 237 121 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nHEX\r\nCODE OK152 42 # A IN, A 42 # OUT, NEXT, END-CODE\r\nDECIMAL\r\nXT OK152 0 + C@ . XT OK152 1 + C@ . XT OK152 2 + C@ . XT OK152 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '219 66 211 66 '; then \
		echo "PASS: REPL test 152 — 42h # A IN,=DB42, A 42h # OUT,=D342"; \
	else \
		echo "FAIL: REPL test 152 — expected '219 66 211 66 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK153 (C) B IN, NEXT, END-CODE\r\nXT OK153 0 + C@ . XT OK153 1 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 64 '; then \
		echo "PASS: REPL test 153 — (C) B IN,=ED40"; \
	else \
		echo "FAIL: REPL test 153 — expected '237 64 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'HEX\r\nCODE BAD154 42 # B IN, END-CODE\r\nDECIMAL\r\n1 2 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -258: bad operand' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 154 — immediate-port IN with B: bad operand, clean recovery"; \
	else \
		echo "FAIL: REPL test 154 — expected 'error -258: bad operand' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK155 LDIR, LDDR, CPIR, CPDR, NEXT, END-CODE\r\nXT OK155 0 + C@ . XT OK155 1 + C@ . XT OK155 2 + C@ . XT OK155 3 + C@ .\r\nXT OK155 4 + C@ . XT OK155 5 + C@ . XT OK155 6 + C@ . XT OK155 7 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 176 237 184 ' && \
	   echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 177 237 185 '; then \
		echo "PASS: REPL test 155 — LDIR,=EDB0 LDDR,=EDB8 CPIR,=EDB1 CPDR,=EDB9"; \
	else \
		echo "FAIL: REPL test 155 — expected '237 176 237 184 ' and '237 177 237 185 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK156 LDI, LDD, CPI, CPD, NEXT, END-CODE\r\nXT OK156 0 + C@ . XT OK156 1 + C@ . XT OK156 2 + C@ . XT OK156 3 + C@ .\r\nXT OK156 4 + C@ . XT OK156 5 + C@ . XT OK156 6 + C@ . XT OK156 7 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 160 237 168 ' && \
	   echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 161 237 169 '; then \
		echo "PASS: REPL test 156 — LDI,=EDA0 LDD,=EDA8 CPI,=EDA1 CPD,=EDA9"; \
	else \
		echo "FAIL: REPL test 156 — expected '237 160 237 168 ' and '237 161 237 169 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK157 INI, INIR, IND, INDR, NEXT, END-CODE\r\nXT OK157 0 + C@ . XT OK157 1 + C@ . XT OK157 2 + C@ . XT OK157 3 + C@ .\r\nXT OK157 4 + C@ . XT OK157 5 + C@ . XT OK157 6 + C@ . XT OK157 7 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 162 237 178 ' && \
	   echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 170 237 186 '; then \
		echo "PASS: REPL test 157 — INI,=EDA2 INIR,=EDB2 IND,=EDAA INDR,=EDBA"; \
	else \
		echo "FAIL: REPL test 157 — expected '237 162 237 178 ' and '237 170 237 186 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK158 OUTI, OTIR, OUTD, OTDR, NEXT, END-CODE\r\nXT OK158 0 + C@ . XT OK158 1 + C@ . XT OK158 2 + C@ . XT OK158 3 + C@ .\r\nXT OK158 4 + C@ . XT OK158 5 + C@ . XT OK158 6 + C@ . XT OK158 7 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 163 237 179 ' && \
	   echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 171 237 187 '; then \
		echo "PASS: REPL test 158 — OUTI,=EDA3 OTIR,=EDB3 OUTD,=EDAB OTDR,=EDBB"; \
	else \
		echo "FAIL: REPL test 158 — expected '237 163 237 179 ' and '237 171 237 187 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK159 NEG, RETN, RETI, NEXT, END-CODE\r\nXT OK159 0 + C@ . XT OK159 1 + C@ . XT OK159 2 + C@ . XT OK159 3 + C@ . XT OK159 4 + C@ . XT OK159 5 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 68 237 69 237 77 '; then \
		echo "PASS: REPL test 159 — NEG,=ED44 RETN,=ED45 RETI,=ED4D"; \
	else \
		echo "FAIL: REPL test 159 — expected '237 68 237 69 237 77 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK160 IM0, IM1, IM2, NEXT, END-CODE\r\nXT OK160 0 + C@ . XT OK160 1 + C@ . XT OK160 2 + C@ . XT OK160 3 + C@ . XT OK160 4 + C@ . XT OK160 5 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 70 237 86 237 94 '; then \
		echo "PASS: REPL test 160 — IM0,=ED46 IM1,=ED56 IM2,=ED5E"; \
	else \
		echo "FAIL: REPL test 160 — expected '237 70 237 86 237 94 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK161 DE HL EX, EXX, NEXT, END-CODE\r\nXT OK161 0 + C@ . XT OK161 1 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '235 217 '; then \
		echo "PASS: REPL test 161 — DE HL EX,=EB, EXX,=D9"; \
	else \
		echo "FAIL: REPL test 161 — expected '235 217 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK162 (SP) HL EX, (SP) IX EX, NEXT, END-CODE\r\nXT OK162 0 + C@ . XT OK162 1 + C@ . XT OK162 2 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '227 221 227 '; then \
		echo "PASS: REPL test 162 — (SP) HL EX,=E3, (SP) IX EX,=DDE3"; \
	else \
		echo "FAIL: REPL test 162 — expected '227 221 227 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ": XT BL WORD FIND DROP ;\r\nCODE OK163 AF AF' EX, NEXT, END-CODE\r\nXT OK163 0 + C@ .\r\nBYE\r\n" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '8 '; then \
		echo "PASS: REPL test 163 — AF AF' EX,=08"; \
	else \
		echo "FAIL: REPL test 163 — expected '8 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK164 (IX) 5 +D A LD, A (IX) 5 +D LD, NEXT, END-CODE\r\nXT OK164 0 + C@ . XT OK164 1 + C@ . XT OK164 2 + C@ . XT OK164 3 + C@ . XT OK164 4 + C@ . XT OK164 5 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '221 126 5 221 119 5 '; then \
		echo "PASS: REPL test 164 — (IX) 5 +D A LD,=DD7E05, A (IX) 5 +D LD,=DD7705"; \
	else \
		echo "FAIL: REPL test 164 — expected '221 126 5 221 119 5 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nHEX\r\nCODE OK165 IX 1234 # LD, IY 5678 # LD, NEXT, END-CODE\r\nDECIMAL\r\nXT OK165 0 + C@ . XT OK165 1 + C@ . XT OK165 2 + C@ . XT OK165 3 + C@ .\r\nXT OK165 4 + C@ . XT OK165 5 + C@ . XT OK165 6 + C@ . XT OK165 7 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '221 33 52 18 ' && \
	   echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '253 33 120 86 '; then \
		echo "PASS: REPL test 165 — IX 1234h # LD,=DD213412, IY 5678h # LD,=FD217856"; \
	else \
		echo "FAIL: REPL test 165 — expected '221 33 52 18 ' and '253 33 120 86 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nHEX\r\nCODE OK166 (IX) 5 +D 2A # LD, NEXT, END-CODE\r\nDECIMAL\r\nXT OK166 0 + C@ . XT OK166 1 + C@ . XT OK166 2 + C@ . XT OK166 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '221 54 5 42 '; then \
		echo "PASS: REPL test 166 — (IX) 5 +D 2Ah # LD,=DD36052A"; \
	else \
		echo "FAIL: REPL test 166 — expected '221 54 5 42 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK167 IX PUSH, IY POP, NEXT, END-CODE\r\nXT OK167 0 + C@ . XT OK167 1 + C@ . XT OK167 2 + C@ . XT OK167 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '221 229 253 225 '; then \
		echo "PASS: REPL test 167 — IX PUSH,=DDE5, IY POP,=FDE1"; \
	else \
		echo "FAIL: REPL test 167 — expected '221 229 253 225 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK168 (IX) JP, (IY) JP, NEXT, END-CODE\r\nXT OK168 0 + C@ . XT OK168 1 + C@ . XT OK168 2 + C@ . XT OK168 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '221 233 253 233 '; then \
		echo "PASS: REPL test 168 — (IX) JP,=DDE9, (IY) JP,=FDE9"; \
	else \
		echo "FAIL: REPL test 168 — expected '221 233 253 233 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK169 (IX) 5 +D ADD, (IY) 3 +D CP, NEXT, END-CODE\r\nXT OK169 0 + C@ . XT OK169 1 + C@ . XT OK169 2 + C@ . XT OK169 3 + C@ . XT OK169 4 + C@ . XT OK169 5 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '221 134 5 253 190 3 '; then \
		echo "PASS: REPL test 169 — (IX) 5 +D ADD,=DD8605, (IY) 3 +D CP,=FDBE03"; \
	else \
		echo "FAIL: REPL test 169 — expected '221 134 5 253 190 3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD170 DE 5 +D A LD, END-CODE\r\n1 2 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -258: bad operand' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 170 — +D with non-(IX)/(IY): bad operand, clean recovery"; \
	else \
		echo "FAIL: REPL test 170 — expected 'error -258: bad operand' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD171 (IX) 200 +D A LD, END-CODE\r\n1 2 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -271: range' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 171 — displacement 200 out of range, clean recovery (Story 11.6: -271)"; \
	else \
		echo "FAIL: REPL test 171 — expected 'error -271: range' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD172 AF INC, END-CODE\r\n1 2 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -258: bad operand' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 172 — AF INC,: bad operand, clean recovery"; \
	else \
		echo "FAIL: REPL test 172 — expected 'error -258: bad operand' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK173 B C LD, A B LD, (HL) A LD, NEXT, END-CODE\r\nXT OK173 0 + C@ . XT OK173 1 + C@ . XT OK173 2 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '65 120 119 '; then \
		echo "PASS: REPL test 173 — regression: B C LD,=41, A B LD,=78, (HL) A LD,=77"; \
	else \
		echo "FAIL: REPL test 173 — expected '65 120 119 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK174 (IY) 3 +D SLA, NEXT, END-CODE\r\nXT OK174 0 + C@ . XT OK174 1 + C@ . XT OK174 2 + C@ . XT OK174 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '253 203 3 38 '; then \
		echo "PASS: REPL test 174 — (IY) 3 +D SLA,=FDCB0326 (FDCB shift)"; \
	else \
		echo "FAIL: REPL test 174 — expected '253 203 3 38 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK175 5 # (IY) 3 +D SET, NEXT, END-CODE\r\nXT OK175 0 + C@ . XT OK175 1 + C@ . XT OK175 2 + C@ . XT OK175 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '253 203 3 238 '; then \
		echo "PASS: REPL test 175 — 5 # (IY) 3 +D SET,=FDCB03EE (FDCB bit op)"; \
	else \
		echo "FAIL: REPL test 175 — expected '253 203 3 238 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK176 (IX) -5 +D A LD, NEXT, END-CODE\r\nXT OK176 0 + C@ . XT OK176 1 + C@ . XT OK176 2 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '221 126 251 '; then \
		echo "PASS: REPL test 176 — (IX) -5 +D A LD,=DD7EFB (negative displacement)"; \
	else \
		echo "FAIL: REPL test 176 — expected '221 126 251 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK177 (IX) -128 +D INC, (IX) 127 +D INC, NEXT, END-CODE\r\nXT OK177 0 + C@ . XT OK177 1 + C@ . XT OK177 2 + C@ . XT OK177 3 + C@ . XT OK177 4 + C@ . XT OK177 5 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '221 52 128 221 52 127 '; then \
		echo "PASS: REPL test 177 — boundary displacements: -128=DD3480, +127=DD347F"; \
	else \
		echo "FAIL: REPL test 177 — expected '221 52 128 221 52 127 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK178 42 # ADD, AF PUSH, HL POP, NZ 4660 JP, NEXT, END-CODE\r\nXT OK178 0 + C@ . XT OK178 1 + C@ . XT OK178 2 + C@ . XT OK178 3 + C@ . XT OK178 4 + C@ . XT OK178 5 + C@ . XT OK178 6 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '198 42 245 225 194 52 18 '; then \
		echo "PASS: REPL test 178 — regression: #ADD,=C62A, PUSH AF=F5, POP HL=E1, NZ JP,=C23412"; \
	else \
		echo "FAIL: REPL test 178 — expected '198 42 245 225 194 52 18 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@echo "--- Story 5.0.5 tests ---"
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK179 NOP, HALT, DI, EI, NEXT, END-CODE\r\nXT OK179 0 + C@ . XT OK179 1 + C@ . XT OK179 2 + C@ . XT OK179 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '0 118 243 251 '; then \
		echo "PASS: REPL test 179 — NOP,=00, HALT,=76, DI,=F3, EI,=FB"; \
	else \
		echo "FAIL: REPL test 179 — expected '0 118 243 251 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK180 DAA, CPL, SCF, CCF, NEXT, END-CODE\r\nXT OK180 0 + C@ . XT OK180 1 + C@ . XT OK180 2 + C@ . XT OK180 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '39 47 55 63 '; then \
		echo "PASS: REPL test 180 — DAA,=27, CPL,=2F, SCF,=37, CCF,=3F"; \
	else \
		echo "FAIL: REPL test 180 — expected '39 47 55 63 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK181 RLCA, RRCA, RLA, RRA, NEXT, END-CODE\r\nXT OK181 0 + C@ . XT OK181 1 + C@ . XT OK181 2 + C@ . XT OK181 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '7 15 23 31 '; then \
		echo "PASS: REPL test 181 — RLCA,=07, RRCA,=0F, RLA,=17, RRA,=1F"; \
	else \
		echo "FAIL: REPL test 181 — expected '7 15 23 31 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK182 B ADC, (HL) ADC, 66 # ADC, NEXT, END-CODE\r\nXT OK182 0 + C@ . XT OK182 1 + C@ . XT OK182 2 + C@ . XT OK182 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '136 142 206 66 '; then \
		echo "PASS: REPL test 182 — B ADC,=88, (HL) ADC,=8E, 66 # ADC,=CE42"; \
	else \
		echo "FAIL: REPL test 182 — expected '136 142 206 66 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK183 B SBC, (HL) SBC, 66 # SBC, NEXT, END-CODE\r\nXT OK183 0 + C@ . XT OK183 1 + C@ . XT OK183 2 + C@ . XT OK183 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '152 158 222 66 '; then \
		echo "PASS: REPL test 183 — B SBC,=98, (HL) SBC,=9E, 66 # SBC,=DE42"; \
	else \
		echo "FAIL: REPL test 183 — expected '152 158 222 66 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK184 (IX) 5 +D ADC, (IX) 5 +D SBC, NEXT, END-CODE\r\nXT OK184 0 + C@ . XT OK184 1 + C@ . XT OK184 2 + C@ . XT OK184 3 + C@ . XT OK184 4 + C@ . XT OK184 5 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '221 142 5 221 158 5 '; then \
		echo "PASS: REPL test 184 — (IX) 5 +D ADC,=DD8E05, (IX) 5 +D SBC,=DD9E05"; \
	else \
		echo "FAIL: REPL test 184 — expected '221 142 5 221 158 5 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK185 HL BC ADD, HL DE ADD, HL HL ADD, HL SP ADD, NEXT, END-CODE\r\nXT OK185 0 + C@ . XT OK185 1 + C@ . XT OK185 2 + C@ . XT OK185 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '9 25 41 57 '; then \
		echo "PASS: REPL test 185 — HL BC ADD,=09, HL DE ADD,=19, HL HL ADD,=29, HL SP ADD,=39"; \
	else \
		echo "FAIL: REPL test 185 — expected '9 25 41 57 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK186 HL BC ADC, HL DE ADC, HL SP ADC, NEXT, END-CODE\r\nXT OK186 0 + C@ . XT OK186 1 + C@ . XT OK186 2 + C@ . XT OK186 3 + C@ . XT OK186 4 + C@ . XT OK186 5 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 74 237 90 237 122 '; then \
		echo "PASS: REPL test 186 — HL BC ADC,=ED4A, HL DE ADC,=ED5A, HL SP ADC,=ED7A"; \
	else \
		echo "FAIL: REPL test 186 — expected '237 74 237 90 237 122 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK187 HL BC SBC, HL DE SBC, HL SP SBC, NEXT, END-CODE\r\nXT OK187 0 + C@ . XT OK187 1 + C@ . XT OK187 2 + C@ . XT OK187 3 + C@ . XT OK187 4 + C@ . XT OK187 5 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 66 237 82 237 114 '; then \
		echo "PASS: REPL test 187 — HL BC SBC,=ED42, HL DE SBC,=ED52, HL SP SBC,=ED72"; \
	else \
		echo "FAIL: REPL test 187 — expected '237 66 237 82 237 114 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK188 IX BC ADD, IY DE ADD, NEXT, END-CODE\r\nXT OK188 0 + C@ . XT OK188 1 + C@ . XT OK188 2 + C@ . XT OK188 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '221 9 253 25 '; then \
		echo "PASS: REPL test 188 — IX BC ADD,=DD09, IY DE ADD,=FD19"; \
	else \
		echo "FAIL: REPL test 188 — expected '221 9 253 25 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK189 A (BC) LD, A (DE) LD, NEXT, END-CODE\r\nXT OK189 0 + C@ . XT OK189 1 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '10 26 '; then \
		echo "PASS: REPL test 189 — A (BC) LD,=0A, A (DE) LD,=1A"; \
	else \
		echo "FAIL: REPL test 189 — expected '10 26 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK190 (BC) A LD, (DE) A LD, NEXT, END-CODE\r\nXT OK190 0 + C@ . XT OK190 1 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '2 18 '; then \
		echo "PASS: REPL test 190 — (BC) A LD,=02, (DE) A LD,=12"; \
	else \
		echo "FAIL: REPL test 190 — expected '2 18 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK191 A 4660 () LD, NEXT, END-CODE\r\nXT OK191 0 + C@ . XT OK191 1 + C@ . XT OK191 2 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '58 52 18 '; then \
		echo "PASS: REPL test 191 — A 4660 () LD,=3A3412 (LD A,(1234h))"; \
	else \
		echo "FAIL: REPL test 191 — expected '58 52 18 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK192 4660 () A LD, NEXT, END-CODE\r\nXT OK192 0 + C@ . XT OK192 1 + C@ . XT OK192 2 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '50 52 18 '; then \
		echo "PASS: REPL test 192 — 4660 () A LD,=323412 (LD (1234h),A)"; \
	else \
		echo "FAIL: REPL test 192 — expected '50 52 18 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK193 HL 4660 () LD, NEXT, END-CODE\r\nXT OK193 0 + C@ . XT OK193 1 + C@ . XT OK193 2 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '42 52 18 '; then \
		echo "PASS: REPL test 193 — HL 4660 () LD,=2A3412 (LD HL,(1234h))"; \
	else \
		echo "FAIL: REPL test 193 — expected '42 52 18 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK194 4660 () HL LD, NEXT, END-CODE\r\nXT OK194 0 + C@ . XT OK194 1 + C@ . XT OK194 2 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '34 52 18 '; then \
		echo "PASS: REPL test 194 — 4660 () HL LD,=223412 (LD (1234h),HL)"; \
	else \
		echo "FAIL: REPL test 194 — expected '34 52 18 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK195 BC 4660 () LD, NEXT, END-CODE\r\nXT OK195 0 + C@ . XT OK195 1 + C@ . XT OK195 2 + C@ . XT OK195 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 75 52 18 '; then \
		echo "PASS: REPL test 195 — BC 4660 () LD,=ED4B3412 (LD BC,(1234h))"; \
	else \
		echo "FAIL: REPL test 195 — expected '237 75 52 18 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK196 4660 () BC LD, NEXT, END-CODE\r\nXT OK196 0 + C@ . XT OK196 1 + C@ . XT OK196 2 + C@ . XT OK196 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 67 52 18 '; then \
		echo "PASS: REPL test 196 — 4660 () BC LD,=ED433412 (LD (1234h),BC)"; \
	else \
		echo "FAIL: REPL test 196 — expected '237 67 52 18 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK197 DE 4660 () LD, NEXT, END-CODE\r\nXT OK197 0 + C@ . XT OK197 1 + C@ . XT OK197 2 + C@ . XT OK197 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 91 52 18 '; then \
		echo "PASS: REPL test 197a — DE 4660 () LD,=ED5B3412"; \
	else \
		echo "FAIL: REPL test 197a — expected '237 91 52 18 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK197B SP 4660 () LD, NEXT, END-CODE\r\nXT OK197B 0 + C@ . XT OK197B 1 + C@ . XT OK197B 2 + C@ . XT OK197B 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 123 52 18 '; then \
		echo "PASS: REPL test 197b — SP 4660 () LD,=ED7B3412"; \
	else \
		echo "FAIL: REPL test 197b — expected '237 123 52 18 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK198 IX 4660 () LD, NEXT, END-CODE\r\nXT OK198 0 + C@ . XT OK198 1 + C@ . XT OK198 2 + C@ . XT OK198 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '221 42 52 18 '; then \
		echo "PASS: REPL test 198a — IX 4660 () LD,=DD2A3412"; \
	else \
		echo "FAIL: REPL test 198a — expected '221 42 52 18 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK198B IY 4660 () LD, NEXT, END-CODE\r\nXT OK198B 0 + C@ . XT OK198B 1 + C@ . XT OK198B 2 + C@ . XT OK198B 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '253 42 52 18 '; then \
		echo "PASS: REPL test 198b — IY 4660 () LD,=FD2A3412"; \
	else \
		echo "FAIL: REPL test 198b — expected '253 42 52 18 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK199 4660 () IX LD, NEXT, END-CODE\r\nXT OK199 0 + C@ . XT OK199 1 + C@ . XT OK199 2 + C@ . XT OK199 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '221 34 52 18 '; then \
		echo "PASS: REPL test 199a — 4660 () IX LD,=DD223412"; \
	else \
		echo "FAIL: REPL test 199a — expected '221 34 52 18 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK199B 4660 () IY LD, NEXT, END-CODE\r\nXT OK199B 0 + C@ . XT OK199B 1 + C@ . XT OK199B 2 + C@ . XT OK199B 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '253 34 52 18 '; then \
		echo "PASS: REPL test 199b — 4660 () IY LD,=FD223412"; \
	else \
		echo "FAIL: REPL test 199b — expected '253 34 52 18 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK200 A IREG LD, A RREG LD, NEXT, END-CODE\r\nXT OK200 0 + C@ . XT OK200 1 + C@ . XT OK200 2 + C@ . XT OK200 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 87 237 95 '; then \
		echo "PASS: REPL test 200a — A IREG LD,=ED57, A RREG LD,=ED5F"; \
	else \
		echo "FAIL: REPL test 200a — expected '237 87 237 95 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK200B IREG A LD, RREG A LD, NEXT, END-CODE\r\nXT OK200B 0 + C@ . XT OK200B 1 + C@ . XT OK200B 2 + C@ . XT OK200B 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 71 237 79 '; then \
		echo "PASS: REPL test 200b — IREG A LD,=ED47, RREG A LD,=ED4F"; \
	else \
		echo "FAIL: REPL test 200b — expected '237 71 237 79 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK201 0 RST, 8 RST, 16 RST, 24 RST, NEXT, END-CODE\r\nXT OK201 0 + C@ . XT OK201 1 + C@ . XT OK201 2 + C@ . XT OK201 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '199 207 215 223 '; then \
		echo "PASS: REPL test 201a — RST 0=C7, 8=CF, 16=D7, 24=DF"; \
	else \
		echo "FAIL: REPL test 201a — expected '199 207 215 223 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK201B 32 RST, 40 RST, 48 RST, 56 RST, NEXT, END-CODE\r\nXT OK201B 0 + C@ . XT OK201B 1 + C@ . XT OK201B 2 + C@ . XT OK201B 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '231 239 247 255 '; then \
		echo "PASS: REPL test 201b — RST 32=E7, 40=EF, 48=F7, 56=FF"; \
	else \
		echo "FAIL: REPL test 201b — expected '231 239 247 255 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD202 3 RST, END-CODE\r\n3 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -258: bad operand' && echo "$$OUTPUT" | grep -q '3 '; then \
		echo "PASS: REPL test 202 — RST, with invalid vector: bad operand, clean recovery"; \
	else \
		echo "FAIL: REPL test 202 — expected 'error -258: bad operand' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK203 RLD, RRD, NEXT, END-CODE\r\nXT OK203 0 + C@ . XT OK203 1 + C@ . XT OK203 2 + C@ . XT OK203 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 111 237 103 '; then \
		echo "PASS: REPL test 203 — RLD,=ED6F, RRD,=ED67"; \
	else \
		echo "FAIL: REPL test 203 — expected '237 111 237 103 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK204 LABEL FWD FWD DJNZ, FWD FIX NOP, NEXT, END-CODE\r\nXT OK204 0 + C@ . XT OK204 1 + C@ . XT OK204 2 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '16 0 0 '; then \
		echo "PASS: REPL test 204 — DJNZ, forward label (disp=0, target=next byte)"; \
	else \
		echo "FAIL: REPL test 204 — expected '16 0 0 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK205 LABEL BK BK FIX NOP, BK DJNZ, NEXT, END-CODE\r\nXT OK205 0 + C@ . XT OK205 1 + C@ . XT OK205 2 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '0 16 253 '; then \
		echo "PASS: REPL test 205 — DJNZ, backward label (disp=FD=-3)"; \
	else \
		echo "FAIL: REPL test 205 — expected '0 16 253 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK206 4660 () DE LD, NEXT, END-CODE\r\nXT OK206 0 + C@ . XT OK206 1 + C@ . XT OK206 2 + C@ . XT OK206 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 83 52 18 '; then \
		echo "PASS: REPL test 206a — 4660 () DE LD,=ED533412"; \
	else \
		echo "FAIL: REPL test 206a — expected '237 83 52 18 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK206B 4660 () SP LD, NEXT, END-CODE\r\nXT OK206B 0 + C@ . XT OK206B 1 + C@ . XT OK206B 2 + C@ . XT OK206B 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 115 52 18 '; then \
		echo "PASS: REPL test 206b — 4660 () SP LD,=ED733412"; \
	else \
		echo "FAIL: REPL test 206b — expected '237 115 52 18 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'NOP,\r\n3 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -270: not in CODE' && echo "$$OUTPUT" | grep -q '3 '; then \
		echo "PASS: REPL test 207 — NOP, outside CODE: error -270: not in CODE, clean recovery (Story 11.6)"; \
	else \
		echo "FAIL: REPL test 207 — expected 'error -270: not in CODE' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD208 B (BC) LD, END-CODE\r\n3 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -258: bad operand' && echo "$$OUTPUT" | grep -q '3 '; then \
		echo "PASS: REPL test 208 — B (BC) LD, rejects non-A: bad operand, clean recovery"; \
	else \
		echo "FAIL: REPL test 208 — expected 'error -258: bad operand' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD209 B (DE) LD, END-CODE\r\n3 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -258: bad operand' && echo "$$OUTPUT" | grep -q '3 '; then \
		echo "PASS: REPL test 209 — B (DE) LD, rejects non-A: bad operand, clean recovery"; \
	else \
		echo "FAIL: REPL test 209 — expected 'error -258: bad operand' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD210 B IREG LD, END-CODE\r\n3 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -258: bad operand' && echo "$$OUTPUT" | grep -q '3 '; then \
		echo "PASS: REPL test 210 — B IREG LD, rejects non-A: bad operand, clean recovery"; \
	else \
		echo "FAIL: REPL test 210 — expected 'error -258: bad operand' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD211 IREG B LD, END-CODE\r\n3 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -258: bad operand' && echo "$$OUTPUT" | grep -q '3 '; then \
		echo "PASS: REPL test 211 — IREG B LD, rejects non-A dest: bad operand, clean recovery"; \
	else \
		echo "FAIL: REPL test 211 — expected 'error -258: bad operand' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK212 HL HL ADC, HL HL SBC, NEXT, END-CODE\r\nXT OK212 0 + C@ . XT OK212 1 + C@ . XT OK212 2 + C@ . XT OK212 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '237 106 237 98 '; then \
		echo "PASS: REPL test 212 — HL HL ADC,=ED6A, HL HL SBC,=ED62"; \
	else \
		echo "FAIL: REPL test 212 — expected '237 106 237 98 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': XT BL WORD FIND DROP ;\r\nCODE OK213 IX IX ADD, IY IY ADD, NEXT, END-CODE\r\nXT OK213 0 + C@ . XT OK213 1 + C@ . XT OK213 2 + C@ . XT OK213 3 + C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '221 41 253 41 '; then \
		echo "PASS: REPL test 213 — IX IX ADD,=DD29, IY IY ADD,=FD29"; \
	else \
		echo "FAIL: REPL test 213 — expected '221 41 253 41 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD214 IX IY ADD, END-CODE\r\n3 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -258: bad operand' && echo "$$OUTPUT" | grep -q '3 '; then \
		echo "PASS: REPL test 214 — IX IY ADD, cross-index rejected: bad operand"; \
	else \
		echo "FAIL: REPL test 214 — expected 'error -258: bad operand' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '\\ this is ignored\r\n42 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '42 '; then \
		echo "PASS: REPL test 215 — backslash line comment ignores rest of line"; \
	else \
		echo "FAIL: REPL test 215 — expected '42 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '\\ \r\n42 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '42 '; then \
		echo "PASS: REPL test 216 — backslash at end of line (nothing after) no error"; \
	else \
		echo "FAIL: REPL test 216 — expected '42 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': COMMENTED \\ this is ignored\r\n3 + ; 10 COMMENTED .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '13 '; then \
		echo "PASS: REPL test 217 — backslash inside colon definition, compilation continues next line"; \
	else \
		echo "FAIL: REPL test 217 — expected '13 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE NOP218 \\ comment inside CODE body\r\nNOP, END-CODE\r\n77 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '77 '; then \
		echo "PASS: REPL test 218 — backslash inside CODE body, assembly continues next line"; \
	else \
		echo "FAIL: REPL test 218 — expected '77 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '( hello world ) 42 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '42 '; then \
		echo "PASS: REPL test 219 — paren comment consumed, code after ) executes"; \
	else \
		echo "FAIL: REPL test 219 — expected '42 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '( nested parens are not special ) 55 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '55 '; then \
		echo "PASS: REPL test 220 — literal ) ends paren comment (no nesting)"; \
	else \
		echo "FAIL: REPL test 220 — expected '55 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': COMMENTED2 5 ( add three ) 3 + ; 10 COMMENTED2 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '8 '; then \
		echo "PASS: REPL test 221 — paren comment inside colon definition, no effect on compiled code"; \
	else \
		echo "FAIL: REPL test 221 — expected '8 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '( missing paren\r\n42 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -58: unexpected end of input' && echo "$$OUTPUT" | grep -q '42 '; then \
		echo "PASS: REPL test 222 — missing ) raises error -58 and recovers (Story 11.6)"; \
	else \
		echo "FAIL: REPL test 222 — expected 'error -58: unexpected end of input' and '42 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '( ) 99 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '99 '; then \
		echo "PASS: REPL test 223 — empty paren comment works"; \
	else \
		echo "FAIL: REPL test 223 — expected '99 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE NOPTEST224 ( comment inside CODE ) NOP, END-CODE\r\n88 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '88 '; then \
		echo "PASS: REPL test 224 — paren comment inside CODE body, no interference with assembler"; \
	else \
		echo "FAIL: REPL test 224 — expected '88 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '5 ( comment ) .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '5 '; then \
		echo "PASS: REPL test 225 — paren comment preserves TOS (BC register)"; \
	else \
		echo "FAIL: REPL test 225 — expected '5 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'MARKER M1 : FOO 42 ; FOO .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '42 '; then \
		echo "PASS: REPL test 226 — basic MARKER creation and use"; \
	else \
		echo "FAIL: REPL test 226 — expected '42 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'MARKER M1 : FOO 42 ; M1 FOO\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'FOO ?'; then \
		echo "PASS: REPL test 227 — MARKER restore removes definitions"; \
	else \
		echo "FAIL: REPL test 227 — expected 'FOO ?' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'MARKER M1 : FOO 42 ; M1 : FOO 99 ; FOO .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '99 '; then \
		echo "PASS: REPL test 228 — redefine after restore"; \
	else \
		echo "FAIL: REPL test 228 — expected '99 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'MARKER M1 M1 M1\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'M1 ?'; then \
		echo "PASS: REPL test 229 — MARKER removes itself"; \
	else \
		echo "FAIL: REPL test 229 — expected 'M1 ?' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'MARKER M1 : AA1 1 ; MARKER M2 : BB2 2 ; M2 AA1 .\r\nBB2\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '1 ' && echo "$$OUTPUT" | grep -q 'BB2 ?'; then \
		echo "PASS: REPL test 230 — nested markers (M2 partial restore, BB2 removed)"; \
	else \
		echo "FAIL: REPL test 230 — expected '1 ' and 'BB2 ?' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'MARKER M1 : AA1 1 ; MARKER M2 : BB2 2 ; M1 AA1\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'AA1 ?'; then \
		echo "PASS: REPL test 231 — nested markers (M1 full restore)"; \
	else \
		echo "FAIL: REPL test 231 — expected 'AA1 ?' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'MARKER M1 VARIABLE X 42 X ! X @ .\r\nM1 X\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '42 ' && echo "$$OUTPUT" | grep -q 'X ?'; then \
		echo "PASS: REPL test 232 — VARIABLE removed by MARKER"; \
	else \
		echo "FAIL: REPL test 232 — expected '42 ' and 'X ?' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'MARKER M1 77 CONSTANT K K .\r\nM1 K\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '77 ' && echo "$$OUTPUT" | grep -q 'K ?'; then \
		echo "PASS: REPL test 233 — CONSTANT removed by MARKER"; \
	else \
		echo "FAIL: REPL test 233 — expected '77 ' and 'K ?' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'MARKER M1 HEX M1 BASE @ DECIMAL .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '16 '; then \
		echo "PASS: REPL test 234 — BASE not affected by MARKER"; \
	else \
		echo "FAIL: REPL test 234 — expected '16 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'HERE MARKER M1 : FOO ; M1 HERE = .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '\-1 '; then \
		echo "PASS: REPL test 235 — HERE restored correctly"; \
	else \
		echo "FAIL: REPL test 235 — expected '-1 ' (TRUE) in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '42 MARKER M1 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '42 '; then \
		echo "PASS: REPL test 236 — MARKER preserves TOS (BC register)"; \
	else \
		echo "FAIL: REPL test 236 — expected '42 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'MARKER\r\n1 2 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '3 '; then \
		echo "PASS: REPL test 237 — MARKER with no name aborts and recovers"; \
	else \
		echo "FAIL: REPL test 237 — expected '3 ' in output (recovery after no-name ABORT)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '5 1+ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
		if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '6 '; then \
			echo "PASS: REPL test 238 — 1+: '5 1+ .' outputs '6'"; \
		else \
			echo "FAIL: REPL test 238 — expected '6 ' in output"; \
			echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
			exit 1; \
		fi
	@OUTPUT=$$(printf '5 1- .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
		if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '4 '; then \
			echo "PASS: REPL test 239 — 1-: '5 1- .' outputs '4'"; \
		else \
			echo "FAIL: REPL test 239 — expected '4 ' in output"; \
			echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
			exit 1; \
		fi
	@OUTPUT=$$(printf '0 1- .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
		if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '\-1 '; then \
			echo "PASS: REPL test 240 — 1-: '0 1- .' outputs '-1' (edge case)"; \
		else \
			echo "FAIL: REPL test 240 — expected '-1 ' in output"; \
			echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
			exit 1; \
		fi
	@OUTPUT=$$(printf '%s\r\n%s\r\n' '-1 1+ .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
		if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '0 '; then \
			echo "PASS: REPL test 241 — 1+: '-1 1+ .' outputs '0' (edge case)"; \
		else \
			echo "FAIL: REPL test 241 — expected '0 ' in output"; \
			echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
			exit 1; \
		fi
	@OUTPUT=$$(printf '7 2* .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
		if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '14 '; then \
			echo "PASS: REPL test 242 — 2*: '7 2* .' outputs '14'"; \
		else \
			echo "FAIL: REPL test 242 — expected '14 ' in output"; \
			echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
			exit 1; \
		fi
	@OUTPUT=$$(printf '14 2/ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
		if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '7 '; then \
			echo "PASS: REPL test 243 — 2/: '14 2/ .' outputs '7'"; \
		else \
			echo "FAIL: REPL test 243 — expected '7 ' in output"; \
			echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
			exit 1; \
		fi
	@OUTPUT=$$(printf '%s\r\n%s\r\n' '-6 2/ .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
		if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '\-3 '; then \
			echo "PASS: REPL test 244 — 2/: '-6 2/ .' outputs '-3' (arithmetic shift)"; \
		else \
			echo "FAIL: REPL test 244 — expected '-3 ' in output"; \
			echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
			exit 1; \
		fi
	@OUTPUT=$$(printf '5 ?DUP . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
		if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 5 '; then \
			echo "PASS: REPL test 245 — ?DUP non-zero: '5 ?DUP . .' outputs '5 5'"; \
		else \
			echo "FAIL: REPL test 245 — expected '5 5 ' in output"; \
			echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
			exit 1; \
		fi
	@OUTPUT=$$(printf '0 ?DUP .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
		if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '0 '; then \
			echo "PASS: REPL test 246 — ?DUP zero: '0 ?DUP .' outputs '0'"; \
		else \
			echo "FAIL: REPL test 246 — expected '0 ' in output"; \
			echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
			exit 1; \
		fi
	@OUTPUT=$$(printf '1000 CELL+ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
		if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '1002 '; then \
			echo "PASS: REPL test 247 — CELL+: '1000 CELL+ .' outputs '1002'"; \
		else \
			echo "FAIL: REPL test 247 — expected '1002 ' in output"; \
			echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
			exit 1; \
		fi
	@OUTPUT=$$(printf '1000 CHAR+ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
		if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '1001 '; then \
			echo "PASS: REPL test 248 — CHAR+: '1000 CHAR+ .' outputs '1001'"; \
		else \
			echo "FAIL: REPL test 248 — expected '1001 ' in output"; \
			echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
			exit 1; \
		fi
	@OUTPUT=$$(printf '5 CHARS .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
		if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
			echo "PASS: REPL test 249 — CHARS: '5 CHARS .' outputs '5' (no-op on Z80)"; \
		else \
			echo "FAIL: REPL test 249 — expected '5 ' in output"; \
			echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
			exit 1; \
		fi
	@OUTPUT=$$(printf ': TEST-EXIT 1 EXIT 2 ; TEST-EXIT .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
		if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '1 '; then \
			echo "PASS: REPL test 250 — EXIT: ': TEST-EXIT 1 EXIT 2 ; TEST-EXIT .' outputs '1'"; \
		else \
			echo "FAIL: REPL test 250 — expected '1 ' in output"; \
			echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
			exit 1; \
		fi
	@OUTPUT=$$(printf 'CHAR A .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
		if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '65 '; then \
			echo "PASS: REPL test 251 — CHAR: 'CHAR A .' outputs '65'"; \
		else \
			echo "FAIL: REPL test 251 — expected '65 ' in output"; \
			echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
			exit 1; \
		fi
	@OUTPUT=$$(printf 'CHAR Z .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
		if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '90 '; then \
			echo "PASS: REPL test 252 — CHAR: 'CHAR Z .' outputs '90'"; \
		else \
			echo "FAIL: REPL test 252 — expected '90 ' in output"; \
			echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
			exit 1; \
		fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n" ": USE-TICK ['] DUP ; 7 USE-TICK EXECUTE . ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
		if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '7 7 '; then \
			echo "PASS: REPL test 253 — bracket-tick: compiles xt of DUP, EXECUTE duplicates 7"; \
		else \
			echo "FAIL: REPL test 253 — expected '7 7 ' in output"; \
			echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
			exit 1; \
		fi
	@OUTPUT=$$(printf ': GET-A [CHAR] A ; GET-A .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
		if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '65 '; then \
			echo "PASS: REPL test 254 — [CHAR]: ': GET-A [CHAR] A ; GET-A .' outputs '65'"; \
		else \
			echo "FAIL: REPL test 254 — expected '65 ' in output"; \
			echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
			exit 1; \
		fi
	@OUTPUT=$$(printf "CREATE FOO 42 ,\r\n' FOO >BODY @ .\r\nBYE\r\n" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
		if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '42 '; then \
			echo "PASS: REPL test 255 — >BODY: \"CREATE FOO 42 , ' FOO >BODY @ .\" outputs '42'"; \
		else \
			echo "FAIL: REPL test 255 — expected '42 ' in output"; \
			echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
			exit 1; \
		fi
	@OUTPUT=$$(printf "7 ' DUP EXECUTE .\r\nBYE\r\n" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
		if echo "$$OUTPUT" | tr -d '\r\n' | grep -q '7 '; then \
			echo "PASS: REPL test 256 — tick: \"7 ' DUP EXECUTE .\" outputs '7'"; \
		else \
			echo "FAIL: REPL test 256 — expected '7 ' in output"; \
			echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
			exit 1; \
		fi
	@OUTPUT=$$(printf ': CHK ABORT" nonzero" ; 0 CHK\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
		if echo "$$OUTPUT" | grep -q 'ok'; then \
			echo "PASS: REPL test 257 — ABORT\": '0 CHK' does not abort (flag=0)"; \
		else \
			echo "FAIL: REPL test 257 — expected 'ok' (no abort for zero flag)"; \
			echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
			exit 1; \
		fi
	@OUTPUT=$$(printf ': CHK ABORT" nonzero" ; 1 CHK\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
		NONZERO_COUNT=$$(echo "$$OUTPUT" | grep -c 'nonzero' || true) && \
		if [ "$$NONZERO_COUNT" -ge 2 ] && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
			echo "PASS: REPL test 258 — ABORT\": '1 CHK' aborts with message 'nonzero' and recovers"; \
		else \
			echo "FAIL: REPL test 258 — expected 'nonzero' abort message and recovery with '5'"; \
			echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
			exit 1; \
		fi
	@echo ""
	@echo "--- Story 6.6: Register word recognizer tests ---"
	@OUTPUT=$$(printf 'CODE T1 B A LD, NEXT, END-CODE\r\n: XT BL WORD FIND DROP ;\r\nXT T1 C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '71 '; then \
		echo "PASS: REPL test 259 — recognizer: B A LD, produces correct opcode (0x47 = 71)"; \
	else \
		echo "FAIL: REPL test 259 — expected '71 ' (LD B,A = 0x47)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE T2 HL PUSH, NEXT, END-CODE\r\n: XT BL WORD FIND DROP ;\r\nXT T2 C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '229 '; then \
		echo "PASS: REPL test 260 — recognizer: HL PUSH, produces 0xE5 (229)"; \
	else \
		echo "FAIL: REPL test 260 — expected '229 ' (PUSH HL = 0xE5)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE T3 b a LD, NEXT, END-CODE\r\n: XT BL WORD FIND DROP ;\r\nXT T3 C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '71 '; then \
		echo "PASS: REPL test 261 — recognizer case-insensitive: b a LD, same as B A LD,"; \
	else \
		echo "FAIL: REPL test 261 — expected '71 ' (same as test 259)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE T4 NZ RET, NEXT, END-CODE\r\n: XT BL WORD FIND DROP ;\r\nXT T4 C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '192 '; then \
		echo "PASS: REPL test 262 — recognizer: NZ RET, produces correct opcode (0xC0 = 192)"; \
	else \
		echo "FAIL: REPL test 262 — expected '192 ' (RET NZ = 0xC0)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'BC\r\n1 2 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE 'BC \?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 263 — register outside CODE: recognizer fast-fails, error, clean recovery"; \
	else \
		echo "FAIL: REPL test 263 — expected 'BC ?' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE T5 (HL) INC, NEXT, END-CODE\r\n: XT BL WORD FIND DROP ;\r\nXT T5 C@ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '52 '; then \
		echo "PASS: REPL test 264 — recognizer: (HL) INC, produces correct opcode (0x34 = 52)"; \
	else \
		echo "FAIL: REPL test 264 — expected '52 ' (INC (HL) = 0x34)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "CODE T6 AF AF' EX, NEXT, END-CODE\r\n: XT BL WORD FIND DROP ;\r\nXT T6 C@ .\r\nBYE\r\n" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '8 '; then \
		echo "PASS: REPL test 265 — recognizer: AF AF' EX, produces correct opcode (0x08 = 8)"; \
	else \
		echo "FAIL: REPL test 265 — expected '8 ' (EX AF,AF' = 0x08)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@echo ""
	@echo "--- Story 9.1: Numeric-literal # (decimal) prefix tests ---"
	@OUTPUT=$$(printf '#42 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '42 '; then \
		echo "PASS: REPL test 266 — '#42 .' outputs '42 ' (decimal prefix)"; \
	else \
		echo "FAIL: REPL test 266 — expected '42 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '#0 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '0 '; then \
		echo "PASS: REPL test 267 — '#0 .' outputs '0 '"; \
	else \
		echo "FAIL: REPL test 267 — expected '0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '#-5 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-5 '; then \
		echo "PASS: REPL test 268 — '#-5 .' outputs '-5 ' (sign in body, NUMBER? parity)"; \
	else \
		echo "FAIL: REPL test 268 — expected '-5 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'HEX #42 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '2A '; then \
		echo "PASS: REPL test 269 — 'HEX #42 .' outputs '2A ' (parse decimal 42, print in hex)"; \
	else \
		echo "FAIL: REPL test 269 — expected '2A ' in output (# is parse-time only per Forth 2014 §3.4.1.3)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'HEX #42 DROP BASE @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '10 '; then \
		echo "PASS: REPL test 270 — 'HEX #42 DROP BASE @ .' outputs '10 ' (BASE=16 preserved, printed in hex)"; \
	else \
		echo "FAIL: REPL test 270 — expected '10 ' in output (BASE must not be mutated by # prefix per FR9)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '#ABC\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '#ABC ?'; then \
		echo "PASS: REPL test 271 — '#ABC' falls through to undefined-word error"; \
	else \
		echo "FAIL: REPL test 271 — expected '#ABC ?' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '2 BASE ! #42 . DECIMAL\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '101010 '; then \
		echo "PASS: REPL test 272 — '2 BASE ! #42 .' outputs '101010 ' (decimal 42 printed in binary)"; \
	else \
		echo "FAIL: REPL test 272 — expected '101010 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': T42 #42 ; T42 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '42 '; then \
		echo "PASS: REPL test 273 — '#42' works inside a colon body (compile-time LIT)"; \
	else \
		echo "FAIL: REPL test 273 — expected '42 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@echo ""
	@echo "--- Story 9.2: Hex \$$ and 0x prefix tests ---"
	@echo "--- (see tests/number_prefixes_tests.fth for the authoritative source list) ---"
	@OUTPUT=$$(printf '$$0 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '0 '; then \
		echo "PASS: REPL test 274 — '\$$0 .' outputs '0 '"; \
	else \
		echo "FAIL: REPL test 274 — expected '0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '$$FF .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '255 '; then \
		echo "PASS: REPL test 275 — '\$$FF .' outputs '255 ' (upper-case hex, DECIMAL print)"; \
	else \
		echo "FAIL: REPL test 275 — expected '255 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '$$ff .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '255 '; then \
		echo "PASS: REPL test 276 — '\$$ff .' outputs '255 ' (lower-case hex, case-fold via OR 0x20)"; \
	else \
		echo "FAIL: REPL test 276 — expected '255 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '$$1234 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '4660 '; then \
		echo "PASS: REPL test 277 — '\$$1234 .' outputs '4660 ' (0x1234 in DECIMAL)"; \
	else \
		echo "FAIL: REPL test 277 — expected '4660 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '$$ffff U.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '65535 '; then \
		echo "PASS: REPL test 278 — '\$$ffff U.' outputs '65535 ' (max unsigned 16-bit)"; \
	else \
		echo "FAIL: REPL test 278 — expected '65535 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '$$aBcD U.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '43981 '; then \
		echo "PASS: REPL test 279 — '\$$aBcD U.' outputs '43981 ' (mixed-case hex = 0xABCD)"; \
	else \
		echo "FAIL: REPL test 279 — expected '43981 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0x0 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '0 '; then \
		echo "PASS: REPL test 280 — '0x0 .' outputs '0 '"; \
	else \
		echo "FAIL: REPL test 280 — expected '0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0xFF .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '255 '; then \
		echo "PASS: REPL test 281 — '0xFF .' outputs '255 ' (antforth extension)"; \
	else \
		echo "FAIL: REPL test 281 — expected '255 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0XFF .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '255 '; then \
		echo "PASS: REPL test 282 — '0XFF .' outputs '255 ' (upper-case X, case-fold)"; \
	else \
		echo "FAIL: REPL test 282 — expected '255 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0Xff .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '255 '; then \
		echo "PASS: REPL test 283 — '0Xff .' outputs '255 ' (mixed-case prefix and digits)"; \
	else \
		echo "FAIL: REPL test 283 — expected '255 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0xFFFF U.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '65535 '; then \
		echo "PASS: REPL test 284 — '0xFFFF U.' outputs '65535 '"; \
	else \
		echo "FAIL: REPL test 284 — expected '65535 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'HEX $$FF DROP BASE @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '10 '; then \
		echo "PASS: REPL test 285 — 'HEX \$$FF DROP BASE @ .' outputs '10 ' (BASE=16 preserved, hex print)"; \
	else \
		echo "FAIL: REPL test 285 — expected '10 ' in output (BASE must not be mutated by \$$ prefix)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'DECIMAL 0xFF DROP BASE @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '10 '; then \
		echo "PASS: REPL test 286 — 'DECIMAL 0xFF DROP BASE @ .' outputs '10 ' (BASE=10 preserved)"; \
	else \
		echo "FAIL: REPL test 286 — expected '10 ' in output (BASE must not be mutated by 0x prefix)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '0  ok' && \
	   ! echo "$$OUTPUT" | grep -q '0 ?'; then \
		echo "PASS: REPL test 287 — bare '0 .' still parses via NUMBER? (0-vs-0x ambiguity: FR52)"; \
	else \
		echo "FAIL: REPL test 287 — expected '. 0' to print '0  ok' AND no '0 ?' error — 0x prefix arm must not consume bare '0'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '00 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '0  ok' && \
	   ! echo "$$OUTPUT" | grep -q '00 ?'; then \
		echo "PASS: REPL test 288 — bare '00 .' still parses via NUMBER? (second-byte not x/X)"; \
	else \
		echo "FAIL: REPL test 288 — expected '. 00' to print '0  ok' AND no '00 ?' error — 00 must fall through to NUMBER?"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'HEX 0A .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE 'A  ok' && \
	   ! echo "$$OUTPUT" | grep -q '0A ?'; then \
		echo "PASS: REPL test 289 — 'HEX 0A .' outputs 'A  ok' (0A parses as 10 via NUMBER?, printed in hex)"; \
	else \
		echo "FAIL: REPL test 289 — expected '. 0A' to print 'A  ok' AND no '0A ?' error — HEX 0A must still work via NUMBER?"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'DECIMAL 0A\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0A ?'; then \
		echo "PASS: REPL test 290 — 'DECIMAL 0A' falls through to undefined-word error '0A ?'"; \
	else \
		echo "FAIL: REPL test 290 — expected '0A ?' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '$$\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '\$$ ?'; then \
		echo "PASS: REPL test 291 — bare '\$$' falls through to undefined-word error '\$$ ?'"; \
	else \
		echo "FAIL: REPL test 291 — expected '\$$ ?' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0x\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0x ?'; then \
		echo "PASS: REPL test 292 — bare '0x' falls through to undefined-word error '0x ?'"; \
	else \
		echo "FAIL: REPL test 292 — expected '0x ?' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '$$XYZ\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '\$$XYZ ?'; then \
		echo "PASS: REPL test 293 — '\$$XYZ' (invalid hex body) falls through to '\$$XYZ ?'"; \
	else \
		echo "FAIL: REPL test 293 — expected '\$$XYZ ?' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '$$-FF .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-255 '; then \
		echo "PASS: REPL test 294 — '\$$-FF .' outputs '-255 ' (sign-in-body parity with #-5)"; \
	else \
		echo "FAIL: REPL test 294 — expected '-255 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0x-FF .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-255 '; then \
		echo "PASS: REPL test 295 — '0x-FF .' outputs '-255 ' (sign-in-body on the 0x arm)"; \
	else \
		echo "FAIL: REPL test 295 — expected '-255 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': GETFF $$FF ; GETFF .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '255 '; then \
		echo "PASS: REPL test 296 — '\$$FF' works inside a colon body (compile-time LIT)"; \
	else \
		echo "FAIL: REPL test 296 — expected '255 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': GETHEX 0x1234 ; GETHEX .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '4660 '; then \
		echo "PASS: REPL test 297 — '0x1234' works inside a colon body (compile-time LIT)"; \
	else \
		echo "FAIL: REPL test 297 — expected '4660 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0xff .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '255 '; then \
		echo "PASS: REPL test 298 — '0xff .' outputs '255 ' (all-lower-case: x and digits both fold)"; \
	else \
		echo "FAIL: REPL test 298 — expected '255 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '#42 $$-FF . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-255 42 '; then \
		echo "PASS: REPL test 299 — '#42 \$$-FF . .' outputs '-255 42 ' (.pref_negate reset across handlers)"; \
	else \
		echo "FAIL: REPL test 299 — expected '-255 42 ' (cross-handler sign-flag must not leak between consecutive prefixed tokens)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@echo ""
	@echo "--- Story 9.3: Binary %% and character 'c' prefix tests ---"
	@echo "--- (see tests/number_prefixes_tests.fth for the authoritative source list) ---"
	@OUTPUT=$$(printf '%%0 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '0  ok' && \
	   ! echo "$$OUTPUT" | grep -q '%0 ?'; then \
		echo "PASS: REPL test 300 — '%0 .' outputs '0  ok' (bare '%0' parses as binary 0)"; \
	else \
		echo "FAIL: REPL test 300 — expected '0  ok' AND no '%0 ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '%%1 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '1  ok' && \
	   ! echo "$$OUTPUT" | grep -q '%1 ?'; then \
		echo "PASS: REPL test 301 — '%1 .' outputs '1  ok' (binary 1 = decimal 1)"; \
	else \
		echo "FAIL: REPL test 301 — expected '1  ok' AND no '%1 ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '%%1010 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '10  ok' && \
	   ! echo "$$OUTPUT" | grep -q '%1010 ?'; then \
		echo "PASS: REPL test 302 — '%1010 .' outputs '10  ok' (binary 1010 = decimal 10)"; \
	else \
		echo "FAIL: REPL test 302 — expected '10  ok' AND no '%1010 ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '%%11111111 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '255  ok' && \
	   ! echo "$$OUTPUT" | grep -q '%11111111 ?'; then \
		echo "PASS: REPL test 303 — '%11111111 .' outputs '255  ok' (8-bit all-ones in DECIMAL)"; \
	else \
		echo "FAIL: REPL test 303 — expected '255  ok' AND no '%11111111 ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '%%1111111111111111 U.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '65535  ok' && \
	   ! echo "$$OUTPUT" | grep -q '%1111111111111111 ?'; then \
		echo "PASS: REPL test 304 — '%1111111111111111 U.' outputs '65535  ok' (max unsigned 16-bit)"; \
	else \
		echo "FAIL: REPL test 304 — expected '65535  ok' AND no '%1111111111111111 ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'HEX %%11111111 DROP BASE @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '10  ok' && \
	   ! echo "$$OUTPUT" | grep -q '%11111111 ?'; then \
		echo "PASS: REPL test 305 — 'HEX %11111111 DROP BASE @ .' outputs '10  ok' (BASE=16 preserved, printed in hex)"; \
	else \
		echo "FAIL: REPL test 305 — expected '10  ok' AND no '%11111111 ?' error (BASE must not be mutated by % prefix)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'DECIMAL %%1010 DROP BASE @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '10  ok' && \
	   ! echo "$$OUTPUT" | grep -q '%1010 ?'; then \
		echo "PASS: REPL test 306 — 'DECIMAL %1010 DROP BASE @ .' outputs '10  ok' (BASE=10 preserved)"; \
	else \
		echo "FAIL: REPL test 306 — expected '10  ok' AND no '%1010 ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '%%-1010 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-10  ok' && \
	   ! echo "$$OUTPUT" | grep -q '%-1010 ?'; then \
		echo "PASS: REPL test 307 — '%-1010 .' outputs '-10  ok' (sign-in-body, NUMBER? parity)"; \
	else \
		echo "FAIL: REPL test 307 — expected '-10  ok' AND no '%-1010 ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'HEX %%11111111 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE 'FF  ok' && \
	   ! echo "$$OUTPUT" | grep -q '%11111111 ?'; then \
		echo "PASS: REPL test 308 — 'HEX %11111111 .' outputs 'FF  ok' (decimal 255 printed in hex)"; \
	else \
		echo "FAIL: REPL test 308 — expected 'FF  ok' AND no '%11111111 ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '%%102\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '%102 ?' && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '[0-9]  ok'; then \
		echo "PASS: REPL test 309 — '%102' falls through to '%102 ?' (non-binary digit)"; \
	else \
		echo "FAIL: REPL test 309 — expected '%102 ?' error AND no bare numeric success"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '%%\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '% ?' && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '[0-9]  ok'; then \
		echo "PASS: REPL test 310 — bare '%' falls through to '% ?' (undefined word)"; \
	else \
		echo "FAIL: REPL test 310 — expected '% ?' error AND no bare numeric success"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '%%-\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '%- ?' && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '[0-9]  ok'; then \
		echo "PASS: REPL test 311 — '%-' falls through to '%- ?' (bare sign)"; \
	else \
		echo "FAIL: REPL test 311 — expected '%- ?' error AND no bare numeric success"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '\047A\047 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '65  ok' && \
	   ! echo "$$OUTPUT" | grep -q "'A' ?"; then \
		echo "PASS: REPL test 312 — \"'A' .\" outputs '65  ok' (ASCII 'A' = 65)"; \
	else \
		echo "FAIL: REPL test 312 — expected '65  ok' AND no \"'A' ?\" error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '\0470\047 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '48  ok' && \
	   ! echo "$$OUTPUT" | grep -q "'0' ?"; then \
		echo "PASS: REPL test 313 — \"'0' .\" outputs '48  ok' (digit char, ASCII 48)"; \
	else \
		echo "FAIL: REPL test 313 — expected '48  ok' AND no \"'0' ?\" error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '\047a\047 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '97  ok' && \
	   ! echo "$$OUTPUT" | grep -q "'a' ?"; then \
		echo "PASS: REPL test 314 — \"'a' .\" outputs '97  ok' (lower-case 'a' = 97)"; \
	else \
		echo "FAIL: REPL test 314 — expected '97  ok' AND no \"'a' ?\" error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '\0479\047 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '57  ok' && \
	   ! echo "$$OUTPUT" | grep -q "'9' ?"; then \
		echo "PASS: REPL test 315 — \"'9' .\" outputs '57  ok' (digit '9' = 57)"; \
	else \
		echo "FAIL: REPL test 315 — expected '57  ok' AND no \"'9' ?\" error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '\047+\047 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '43  ok' && \
	   ! echo "$$OUTPUT" | grep -q "'+' ?"; then \
		echo "PASS: REPL test 316 — \"'+' .\" outputs '43  ok' (non-alphanumeric byte)"; \
	else \
		echo "FAIL: REPL test 316 — expected '43  ok' AND no \"'+' ?\" error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '\047*\047 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '42  ok' && \
	   ! echo "$$OUTPUT" | grep -q "'\*' ?"; then \
		echo "PASS: REPL test 317 — \"'*' .\" outputs '42  ok' (non-alphanumeric byte)"; \
	else \
		echo "FAIL: REPL test 317 — expected '42  ok' AND no \"'*' ?\" error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'HEX \047A\047 DROP BASE @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '10  ok' && \
	   ! echo "$$OUTPUT" | grep -q "'A' ?"; then \
		echo "PASS: REPL test 318 — \"HEX 'A' DROP BASE @ .\" outputs '10  ok' (BASE=16 preserved)"; \
	else \
		echo "FAIL: REPL test 318 — expected '10  ok' AND no \"'A' ?\" error (BASE must not be mutated by 'c' prefix)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '\047ab\047\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q "'ab' ?" && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '[0-9]  ok'; then \
		echo "PASS: REPL test 319 — \"'ab'\" falls through to \"'ab' ?\" (too long)"; \
	else \
		echo "FAIL: REPL test 319 — expected \"'ab' ?\" error AND no bare numeric success"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '\047a\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q "'a ?" && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '[0-9]  ok'; then \
		echo "PASS: REPL test 320 — \"'a\" falls through to \"'a ?\" (no closing quote)"; \
	else \
		echo "FAIL: REPL test 320 — expected \"'a ?\" error AND no bare numeric success"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '\047\047\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q "'' ?" && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '[0-9]  ok'; then \
		echo "PASS: REPL test 321 — \"''\" falls through to \"'' ?\" (empty middle, count=2)"; \
	else \
		echo "FAIL: REPL test 321 — expected \"'' ?\" error AND no bare numeric success"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '\047abc\047\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q "'abc' ?" && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '[0-9]  ok'; then \
		echo "PASS: REPL test 322 — \"'abc'\" falls through to \"'abc' ?\" (count=5, too long)"; \
	else \
		echo "FAIL: REPL test 322 — expected \"'abc' ?\" error AND no bare numeric success"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '\047 DROP .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '[0-9]+  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'DROP ?'; then \
		echo "PASS: REPL test 323 — \"' DROP .\" still invokes TICK (xt printed, no undefined-word error)"; \
	else \
		echo "FAIL: REPL test 323 — expected xt address  ok AND no 'DROP ?' error (bare ' must still reach TICK via FIND)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': GETTEN %%1010 ; GETTEN .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '10  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'GETTEN ?'; then \
		echo "PASS: REPL test 324 — '%1010' works inside a colon body (compile-time LIT)"; \
	else \
		echo "FAIL: REPL test 324 — expected '10  ok' AND no 'GETTEN ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': GETA \047A\047 ; GETA .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '65  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'GETA ?'; then \
		echo "PASS: REPL test 325 — \"'A'\" works inside a colon body (compile-time LIT)"; \
	else \
		echo "FAIL: REPL test 325 — expected '65  ok' AND no 'GETA ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '#42 %%-1010 . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-10 42 '; then \
		echo "PASS: REPL test 326 — '#42 %-1010 . .' outputs '-10 42 ' (.pref_negate reset across #/% handlers)"; \
	else \
		echo "FAIL: REPL test 326 — expected '-10 42 ' (cross-handler sign-flag must not leak between # and %)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "\047\047\047 .\r\nBYE\r\n" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '39  ok' && \
	   ! echo "$$OUTPUT" | grep -q "''' ?"; then \
		echo "PASS: REPL test 327 — \"''' .\" outputs '39  ok' (apostrophe-as-char-literal, ASCII 39)"; \
	else \
		echo "FAIL: REPL test 327 — expected '39  ok' AND no \"''' ?\" error (''' is a legal char literal for ' itself)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "\047\047\047\047\r\nBYE\r\n" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q "'''' ?" && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '[0-9]  ok'; then \
		echo "PASS: REPL test 328 — \"''''\" falls through to \"'''' ?\" (count=4, CP 3 fails)"; \
	else \
		echo "FAIL: REPL test 328 — expected \"'''' ?\" error AND no bare numeric success"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-%%1010 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-10  ok' && \
	   ! echo "$$OUTPUT" | grep -q '%1010 ?'; then \
		echo "PASS: REPL test 329 — '-%1010 .' outputs '-10  ok' (9.4 sign-before-prefix now captures this; flipped from 9.3's fall-through)"; \
	else \
		echo "FAIL: REPL test 329 — expected '-10  ok' AND no '%1010 ?' error (9.4 sign-before-prefix should parse this)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@echo ""
	@echo "--- Story 9.4: leading '-' sign + case-insensitivity tests ---"
	@echo "--- (see tests/number_prefixes_tests.fth for the authoritative source list) ---"
	@OUTPUT=$$(printf -- '-#42 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-42  ok' && \
	   ! echo "$$OUTPUT" | grep -q '#42 ?'; then \
		echo "PASS: REPL test 330 — '-#42 .' outputs '-42  ok' (outer sign + '#' prefix)"; \
	else \
		echo "FAIL: REPL test 330 — expected '-42  ok' AND no '#42 ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-#0 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '^[^?]*\b0  ok' && \
	   ! echo "$$OUTPUT" | grep -q '#0 ?'; then \
		echo "PASS: REPL test 331 — '-#0 .' outputs '0  ok' (negative zero collapses)"; \
	else \
		echo "FAIL: REPL test 331 — expected '0  ok' AND no '#0 ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-$$FF .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-255  ok' && \
	   ! echo "$$OUTPUT" | grep -q '\$$FF ?'; then \
		echo "PASS: REPL test 332 — '-\$$FF .' outputs '-255  ok' (outer sign + '\$$' prefix)"; \
	else \
		echo "FAIL: REPL test 332 — expected '-255  ok' AND no '\$$FF ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-$$ff .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-255  ok' && \
	   ! echo "$$OUTPUT" | grep -q '\$$ff ?'; then \
		echo "PASS: REPL test 333 — '-\$$ff .' outputs '-255  ok' (sign + lower-case hex digits)"; \
	else \
		echo "FAIL: REPL test 333 — expected '-255  ok' AND no '\$$ff ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-0xFF .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-255  ok' && \
	   ! echo "$$OUTPUT" | grep -q '0xFF ?'; then \
		echo "PASS: REPL test 334 — '-0xFF .' outputs '-255  ok' (outer sign + '0x' prefix)"; \
	else \
		echo "FAIL: REPL test 334 — expected '-255  ok' AND no '0xFF ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-0XFF .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-255  ok' && \
	   ! echo "$$OUTPUT" | grep -q '0XFF ?'; then \
		echo "PASS: REPL test 335 — '-0XFF .' outputs '-255  ok' (upper-case X, sign applied)"; \
	else \
		echo "FAIL: REPL test 335 — expected '-255  ok' AND no '0XFF ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-0xff .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-255  ok' && \
	   ! echo "$$OUTPUT" | grep -q '0xff ?'; then \
		echo "PASS: REPL test 336 — '-0xff .' outputs '-255  ok' (sign + all-lower)"; \
	else \
		echo "FAIL: REPL test 336 — expected '-255  ok' AND no '0xff ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-%%11111111 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-255  ok' && \
	   ! echo "$$OUTPUT" | grep -q '%11111111 ?'; then \
		echo "PASS: REPL test 337 — '-%11111111 .' outputs '-255  ok' (outer sign + '%' prefix)"; \
	else \
		echo "FAIL: REPL test 337 — expected '-255  ok' AND no '%11111111 ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- "-\047A\047 .\r\nBYE\r\n" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-65  ok' && \
	   ! echo "$$OUTPUT" | grep -q "'A' ?"; then \
		echo "PASS: REPL test 338 — \"-'A' .\" outputs '-65  ok' (outer sign + ''c'' char literal)"; \
	else \
		echo "FAIL: REPL test 338 — expected '-65  ok' AND no \"'A' ?\" error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- "-\047a\047 .\r\nBYE\r\n" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-97  ok' && \
	   ! echo "$$OUTPUT" | grep -q "'a' ?"; then \
		echo "PASS: REPL test 339 — \"-'a' .\" outputs '-97  ok' (sign + lower-case char)"; \
	else \
		echo "FAIL: REPL test 339 — expected '-97  ok' AND no \"'a' ?\" error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- "-\0470\047 .\r\nBYE\r\n" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-48  ok' && \
	   ! echo "$$OUTPUT" | grep -q "'0' ?"; then \
		echo "PASS: REPL test 340 — \"-'0' .\" outputs '-48  ok' (sign + digit char)"; \
	else \
		echo "FAIL: REPL test 340 — expected '-48  ok' AND no \"'0' ?\" error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- "-\047+\047 .\r\nBYE\r\n" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-43  ok' && \
	   ! echo "$$OUTPUT" | grep -q "'+' ?"; then \
		echo "PASS: REPL test 341 — \"-'+' .\" outputs '-43  ok' (sign + non-alphanum char)"; \
	else \
		echo "FAIL: REPL test 341 — expected '-43  ok' AND no \"'+' ?\" error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-#-5 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\b5  ok' && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-5  ok' && \
	   ! echo "$$OUTPUT" | grep -q '#-5 ?'; then \
		echo "PASS: REPL test 342 — '-#-5 .' outputs '5  ok' (double-sign XOR composition)"; \
	else \
		echo "FAIL: REPL test 342 — expected '5  ok' AND neither '-5  ok' nor '#-5 ?' (outer + in-body sign must XOR)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-$$-FF .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\b255  ok' && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-255  ok' && \
	   ! echo "$$OUTPUT" | grep -q '\$$-FF ?'; then \
		echo "PASS: REPL test 343 — '-\$$-FF .' outputs '255  ok' (double-sign XOR)"; \
	else \
		echo "FAIL: REPL test 343 — expected '255  ok' AND no '-255  ok' and no '\$$-FF ?'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-0x-FF .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\b255  ok' && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-255  ok' && \
	   ! echo "$$OUTPUT" | grep -q '0x-FF ?'; then \
		echo "PASS: REPL test 344 — '-0x-FF .' outputs '255  ok' (double-sign XOR)"; \
	else \
		echo "FAIL: REPL test 344 — expected '255  ok' AND no '-255  ok' and no '0x-FF ?'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-%%-1010 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\b10  ok' && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-10  ok' && \
	   ! echo "$$OUTPUT" | grep -q '%-1010 ?'; then \
		echo "PASS: REPL test 345 — '-%-1010 .' outputs '10  ok' (double-sign XOR)"; \
	else \
		echo "FAIL: REPL test 345 — expected '10  ok' AND no '-10  ok' and no '%-1010 ?'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- 'HEX -#42 DROP BASE @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\b10  ok' && \
	   ! echo "$$OUTPUT" | grep -q '#42 ?'; then \
		echo "PASS: REPL test 346 — 'HEX -#42 DROP BASE @ .' outputs '10  ok' (BASE=16 preserved under outer sign)"; \
	else \
		echo "FAIL: REPL test 346 — expected '10  ok' AND no '#42 ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- 'DECIMAL -$$FF DROP BASE @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\b10  ok' && \
	   ! echo "$$OUTPUT" | grep -q '\$$FF ?'; then \
		echo "PASS: REPL test 347 — 'DECIMAL -\$$FF DROP BASE @ .' outputs '10  ok' (BASE=10 preserved)"; \
	else \
		echo "FAIL: REPL test 347 — expected '10  ok' AND no '\$$FF ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '$$ABCD U.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '43981  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'ABCD ?'; then \
		echo "PASS: REPL test 348 — '\$$ABCD U.' outputs '43981  ok' (hex digits, all upper-case)"; \
	else \
		echo "FAIL: REPL test 348 — expected '43981  ok' AND no 'ABCD ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '$$abcd U.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '43981  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'abcd ?'; then \
		echo "PASS: REPL test 349 — '\$$abcd U.' outputs '43981  ok' (hex digits, all lower-case)"; \
	else \
		echo "FAIL: REPL test 349 — expected '43981  ok' AND no 'abcd ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '0xABCD U.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '43981  ok' && \
	   ! echo "$$OUTPUT" | grep -q '0xABCD ?'; then \
		echo "PASS: REPL test 350 — '0xABCD U.' outputs '43981  ok' (0x + upper-case hex)"; \
	else \
		echo "FAIL: REPL test 350 — expected '43981  ok' AND no '0xABCD ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '0xabcd U.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '43981  ok' && \
	   ! echo "$$OUTPUT" | grep -q '0xabcd ?'; then \
		echo "PASS: REPL test 351 — '0xabcd U.' outputs '43981  ok' (0x + lower-case hex)"; \
	else \
		echo "FAIL: REPL test 351 — expected '43981  ok' AND no '0xabcd ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '0xAbCd U.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '43981  ok' && \
	   ! echo "$$OUTPUT" | grep -q '0xAbCd ?'; then \
		echo "PASS: REPL test 352 — '0xAbCd U.' outputs '43981  ok' (0x + mixed-case hex)"; \
	else \
		echo "FAIL: REPL test 352 — expected '43981  ok' AND no '0xAbCd ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-42 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-42  ok' && \
	   ! echo "$$OUTPUT" | grep -q '\-42 ?'; then \
		echo "PASS: REPL test 353 — '-42 .' (DECIMAL) outputs '-42  ok' (FR47 regression: NUMBER? owns '-42', not the pre-pass)"; \
	else \
		echo "FAIL: REPL test 353 — expected '-42  ok' AND no '-42 ?' error (FR47 regression — pre-pass MUST fall through)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- 'HEX -2A . DECIMAL\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-2A  ok' && \
	   ! echo "$$OUTPUT" | grep -q '\-2A ?'; then \
		echo "PASS: REPL test 354 — 'HEX -2A .' outputs '-2A  ok' (FR47 regression: NUMBER? parses hex literal)"; \
	else \
		echo "FAIL: REPL test 354 — expected '-2A  ok' AND no '-2A ?' error (HEX NUMBER? must still own '-2A')"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-foo\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '\-foo ?' && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '[0-9]  ok'; then \
		echo "PASS: REPL test 355 — '-foo' falls through to '-foo ?' (not a number, not a prefix)"; \
	else \
		echo "FAIL: REPL test 355 — expected '-foo ?' error AND no bare numeric success"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-ABC\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '\-ABC ?' && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '[0-9]  ok'; then \
		echo "PASS: REPL test 356 — '-ABC' (DECIMAL) falls through to '-ABC ?' (DECIMAL doesn't take A-F)"; \
	else \
		echo "FAIL: REPL test 356 — expected '-ABC ?' error AND no bare numeric success"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-#\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '\-# ?' && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '[0-9]  ok'; then \
		echo "PASS: REPL test 357 — '-#' falls through to '-# ?' (outer sign + bare prefix)"; \
	else \
		echo "FAIL: REPL test 357 — expected '-# ?' error AND no bare numeric success"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-$$\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '\-\$$ ?' && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '[0-9]  ok'; then \
		echo "PASS: REPL test 358 — '-\$$' falls through to '-\$$ ?' (outer sign + bare prefix)"; \
	else \
		echo "FAIL: REPL test 358 — expected '-\$$ ?' error AND no bare numeric success"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-%%\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '\-% ?' && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '[0-9]  ok'; then \
		echo "PASS: REPL test 359 — '-%' falls through to '-% ?' (outer sign + bare prefix)"; \
	else \
		echo "FAIL: REPL test 359 — expected '-% ?' error AND no bare numeric success"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-0x\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '\-0x ?' && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '[0-9]  ok'; then \
		echo "PASS: REPL test 360 — '-0x' falls through to '-0x ?' (bare 0x after sign)"; \
	else \
		echo "FAIL: REPL test 360 — expected '-0x ?' error AND no bare numeric success"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- "-\047\047\r\nBYE\r\n" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q "\-'' ?" && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '[0-9]  ok'; then \
		echo "PASS: REPL test 361 — \"-''\" falls through to \"-'' ?\" (outer sign + empty char literal, count=3)"; \
	else \
		echo "FAIL: REPL test 361 — expected \"-'' ?\" error AND no bare numeric success"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- "-\047ab\047\r\nBYE\r\n" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q "\-'ab' ?" && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '[0-9]  ok'; then \
		echo "PASS: REPL test 362 — \"-'ab'\" falls through to \"-'ab' ?\" (outer sign + long char literal, count=5)"; \
	else \
		echo "FAIL: REPL test 362 — expected \"-'ab' ?\" error AND no bare numeric success"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-#42 -$$-FF . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '255 \-42 '; then \
		echo "PASS: REPL test 363 — '-#42 -\$$-FF . .' outputs '255 -42 ' (dispatch-level one-time reset: token 1 sign doesn't leak to token 2)"; \
	else \
		echo "FAIL: REPL test 363 — expected '255 -42 ' (cross-handler carry-over check: .pref_negate must reset per token)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- Story 9.5 colon-body tests (364..378) ---
	@# Verifies prefix + sign recognition inside ':' definitions via the
	@# single shared INTERPRET thread (src/outer_interpreter.asm:.try_number).
	@OUTPUT=$$(printf ': F_CH #42 ; F_CH .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '42  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'F_CH ?'; then \
		echo "PASS: REPL test 364 — ': F_CH #42 ; F_CH .' outputs '42  ok' (# prefix in colon body)"; \
	else \
		echo "FAIL: REPL test 364 — expected '42  ok' AND no 'F_CH ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': F_CHN -#42 ; F_CHN .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-42  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'F_CHN ?'; then \
		echo "PASS: REPL test 365 — ': F_CHN -#42 ; F_CHN .' outputs '-42  ok' (outer-sign + # in colon body)"; \
	else \
		echo "FAIL: REPL test 365 — expected '-42  ok' AND no 'F_CHN ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf ': F_CHS $$-FF ; F_CHS .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-255  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'F_CHS ?'; then \
		echo "PASS: REPL test 366 — ': F_CHS \$$-FF ; F_CHS .' outputs '-255  ok' (inner sign on \$$ arm, colon body)"; \
	else \
		echo "FAIL: REPL test 366 — expected '-255  ok' AND no 'F_CHS ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- ': F_CDS -$$FF ; F_CDS .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-255  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'F_CDS ?'; then \
		echo "PASS: REPL test 367 — ': F_CDS -\$$FF ; F_CDS .' outputs '-255  ok' (outer sign + \$$ in colon body)"; \
	else \
		echo "FAIL: REPL test 367 — expected '-255  ok' AND no 'F_CDS ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- ': F_CX -0xFF ; F_CX .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-255  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'F_CX ?'; then \
		echo "PASS: REPL test 368 — ': F_CX -0xFF ; F_CX .' outputs '-255  ok' (outer sign + 0x in colon body)"; \
	else \
		echo "FAIL: REPL test 368 — expected '-255  ok' AND no 'F_CX ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- ': F_CBN -%%1010 ; F_CBN .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-10  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'F_CBN ?'; then \
		echo "PASS: REPL test 369 — ': F_CBN -%%1010 ; F_CBN .' outputs '-10  ok' (outer sign + %% in colon body)"; \
	else \
		echo "FAIL: REPL test 369 — expected '-10  ok' AND no 'F_CBN ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- ': F_CQN -\047A\047 ; F_CQN .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-65  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'F_CQN ?'; then \
		echo "PASS: REPL test 370 — \": F_CQN -'A' ; F_CQN .\" outputs '-65  ok' (outer sign + 'c' in colon body)"; \
	else \
		echo "FAIL: REPL test 370 — expected '-65  ok' AND no 'F_CQN ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- Colon body: BASE-cross (prefix parse is BASE-independent) ---
	@OUTPUT=$$(printf 'HEX : F_DH #100 . ; F_DH DECIMAL\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '64  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'F_DH ?'; then \
		echo "PASS: REPL test 371 — 'HEX : F_DH #100 . ; F_DH DECIMAL' prints '64  ok' (100 decimal printed in HEX)"; \
	else \
		echo "FAIL: REPL test 371 — expected '64  ok' AND no 'F_DH ?' error (# prefix parses decimal regardless of HEX)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'DECIMAL : F_HD $$ff . ; F_HD\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '255  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'F_HD ?'; then \
		echo "PASS: REPL test 372 — 'DECIMAL : F_HD \$$ff . ; F_HD' prints '255  ok' (\$$ff parses hex regardless of DECIMAL)"; \
	else \
		echo "FAIL: REPL test 372 — expected '255  ok' AND no 'F_HD ?' error (\$$ prefix parses hex regardless of DECIMAL)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- Colon body: BASE integrity across define + invoke (4 snapshots) ---
	@# Snapshot pattern: before-define, after-define, computed-value, after-invoke.
	@# In DECIMAL, BASE @ prints as '10' (= 10 in decimal).
	@OUTPUT=$$(printf 'BASE @ . : F_BH #42 ; BASE @ . F_BH . BASE @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '10 10 42 10  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'F_BH ?'; then \
		echo "PASS: REPL test 373 — '# colon-body BASE integrity' 4-snapshot outputs '10 10 42 10  ok'"; \
	else \
		echo "FAIL: REPL test 373 — expected '10 10 42 10  ok' AND no 'F_BH ?' (BASE must be unchanged before/after define/invoke)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'BASE @ . : F_BD $$FF ; BASE @ . F_BD . BASE @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '10 10 255 10  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'F_BD ?'; then \
		echo "PASS: REPL test 374 — '\$$ colon-body BASE integrity' 4-snapshot outputs '10 10 255 10  ok'"; \
	else \
		echo "FAIL: REPL test 374 — expected '10 10 255 10  ok' AND no 'F_BD ?' (BASE must be unchanged before/after define/invoke)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'BASE @ . : F_BX 0xFF ; BASE @ . F_BX . BASE @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '10 10 255 10  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'F_BX ?'; then \
		echo "PASS: REPL test 375 — '0x colon-body BASE integrity' 4-snapshot outputs '10 10 255 10  ok'"; \
	else \
		echo "FAIL: REPL test 375 — expected '10 10 255 10  ok' AND no 'F_BX ?' (BASE must be unchanged before/after define/invoke)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'BASE @ . : F_BB %%1010 ; BASE @ . F_BB . BASE @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '10 10 10 10  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'F_BB ?'; then \
		echo "PASS: REPL test 376 — '%% colon-body BASE integrity' 4-snapshot outputs '10 10 10 10  ok'"; \
	else \
		echo "FAIL: REPL test 376 — expected '10 10 10 10  ok' AND no 'F_BB ?' (BASE must be unchanged before/after define/invoke)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'BASE @ . : F_BQ \047A\047 ; BASE @ . F_BQ . BASE @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '10 10 65 10  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'F_BQ ?'; then \
		echo "PASS: REPL test 377 — \"'c' colon-body BASE integrity\" 4-snapshot outputs '10 10 65 10  ok'"; \
	else \
		echo "FAIL: REPL test 377 — expected '10 10 65 10  ok' AND no 'F_BQ ?' (BASE must be unchanged before/after define/invoke)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- Colon body: compile-error on malformed prefix + no survivor (AC #6) ---
	@# Two-line REPL: ': F_BAD #ABC ;' triggers COMP_ERROR -> ABORT, unlinks F_BAD.
	@# Subsequent 'F_BAD .' must ALSO error as undefined word — no survivor.
	@OUTPUT=$$(printf ': F_BAD #ABC ;\r\nF_BAD .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '#ABC ?' && \
	   echo "$$OUTPUT" | grep -q 'F_BAD ?' && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '[0-9]  ok'; then \
		echo "PASS: REPL test 378 — malformed prefix in colon body errors '#ABC ?', F_BAD unlinked (follow-on 'F_BAD ?')"; \
	else \
		echo "FAIL: REPL test 378 — expected '#ABC ?' AND 'F_BAD ?' AND no spurious numeric ok (compile error unlink)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- Story 9.5 CODE-block tests (379..393) ---
	@# Verifies prefix + sign recognition inside CODE..END-CODE blocks.
	@# Immediate LD, operand order is Zilog dst-first: 'C 0xFF # LD,' = LD C, 0xFF.
	@OUTPUT=$$(printf 'CODE MK_FF BC PUSH, C 0xFF # LD, B 0 # LD, NEXT, END-CODE\r\nMK_FF .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '255  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'MK_FF ?'; then \
		echo "PASS: REPL test 379 — CODE MK_FF with 0xFF prefix: MK_FF . outputs '255  ok'"; \
	else \
		echo "FAIL: REPL test 379 — expected '255  ok' AND no 'MK_FF ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE MK_FFu BC PUSH, C 0XFF # LD, B 0 # LD, NEXT, END-CODE\r\nMK_FFu .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '255  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'MK_FFu ?'; then \
		echo "PASS: REPL test 380 — CODE MK_FFu with 0XFF (upper-X): MK_FFu . outputs '255  ok'"; \
	else \
		echo "FAIL: REPL test 380 — expected '255  ok' AND no 'MK_FFu ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE MK_D100 BC PUSH, C #100 # LD, B 0 # LD, NEXT, END-CODE\r\nMK_D100 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '100  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'MK_D100 ?'; then \
		echo "PASS: REPL test 381 — CODE MK_D100 with #100 prefix: MK_D100 . outputs '100  ok'"; \
	else \
		echo "FAIL: REPL test 381 — expected '100  ok' AND no 'MK_D100 ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE MK_NEG BC PUSH, C -#5 # LD, B 0xFF # LD, NEXT, END-CODE\r\nMK_NEG .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-5  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'MK_NEG ?'; then \
		echo "PASS: REPL test 382 — CODE MK_NEG with -#5 prefix (sign-extended): MK_NEG . outputs '-5  ok'"; \
	else \
		echo "FAIL: REPL test 382 — expected '-5  ok' AND no 'MK_NEG ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE MK_DS BC PUSH, C $$FF # LD, B 0 # LD, NEXT, END-CODE\r\nMK_DS .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '255  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'MK_DS ?'; then \
		echo "PASS: REPL test 383 — CODE MK_DS with \$$FF prefix: MK_DS . outputs '255  ok'"; \
	else \
		echo "FAIL: REPL test 383 — expected '255  ok' AND no 'MK_DS ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE MK_DSN BC PUSH, C $$-FF # LD, B 0xFF # LD, NEXT, END-CODE\r\nMK_DSN .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-255  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'MK_DSN ?'; then \
		echo "PASS: REPL test 384 — CODE MK_DSN with \$$-FF prefix (inner sign): MK_DSN . outputs '-255  ok'"; \
	else \
		echo "FAIL: REPL test 384 — expected '-255  ok' AND no 'MK_DSN ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- 'CODE MK_DSO BC PUSH, C -$$FF # LD, B 0xFF # LD, NEXT, END-CODE\r\nMK_DSO .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-255  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'MK_DSO ?'; then \
		echo "PASS: REPL test 384a — CODE MK_DSO with -\$$FF prefix (outer sign on \$$ arm): MK_DSO . outputs '-255  ok'"; \
	else \
		echo "FAIL: REPL test 384a — expected '-255  ok' AND no 'MK_DSO ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE MK_X BC PUSH, C -0xFF # LD, B 0xFF # LD, NEXT, END-CODE\r\nMK_X .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-255  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'MK_X ?'; then \
		echo "PASS: REPL test 385 — CODE MK_X with -0xFF prefix (outer sign + 0x): MK_X . outputs '-255  ok'"; \
	else \
		echo "FAIL: REPL test 385 — expected '-255  ok' AND no 'MK_X ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE MK_B BC PUSH, C %%1010 # LD, B 0 # LD, NEXT, END-CODE\r\nMK_B .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '10  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'MK_B ?'; then \
		echo "PASS: REPL test 386 — CODE MK_B with %%1010 prefix: MK_B . outputs '10  ok'"; \
	else \
		echo "FAIL: REPL test 386 — expected '10  ok' AND no 'MK_B ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- 'CODE MK_BN BC PUSH, C -%%1010 # LD, B 0xFF # LD, NEXT, END-CODE\r\nMK_BN .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-10  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'MK_BN ?'; then \
		echo "PASS: REPL test 386a — CODE MK_BN with -%%1010 prefix (outer sign on %% arm): MK_BN . outputs '-10  ok'"; \
	else \
		echo "FAIL: REPL test 386a — expected '-10  ok' AND no 'MK_BN ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE MK_Q BC PUSH, C \047A\047 # LD, B 0 # LD, NEXT, END-CODE\r\nMK_Q .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '65  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'MK_Q ?'; then \
		echo "PASS: REPL test 387 — CODE MK_Q with 'A' prefix: MK_Q . outputs '65  ok'"; \
	else \
		echo "FAIL: REPL test 387 — expected '65  ok' AND no 'MK_Q ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- 'CODE MK_QN BC PUSH, C -\047A\047 # LD, B 0xFF # LD, NEXT, END-CODE\r\nMK_QN .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-65  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'MK_QN ?'; then \
		echo "PASS: REPL test 388 — CODE MK_QN with -'A' prefix (outer sign + 'c'): MK_QN . outputs '-65  ok'"; \
	else \
		echo "FAIL: REPL test 388 — expected '-65  ok' AND no 'MK_QN ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- CODE block: 16-bit BC immediate load with 0x1234 prefix ---
	@OUTPUT=$$(printf 'CODE MK_1234 BC PUSH, BC 0x1234 # LD, NEXT, END-CODE\r\nMK_1234 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '4660  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'MK_1234 ?'; then \
		echo "PASS: REPL test 389 — CODE MK_1234 with 16-bit 0x1234 prefix: MK_1234 . outputs '4660  ok'"; \
	else \
		echo "FAIL: REPL test 389 — expected '4660  ok' AND no 'MK_1234 ?' error"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- CODE block: BASE-cross tests (prefix parse is BASE-independent) ---
	@OUTPUT=$$(printf 'HEX CODE MK_CDEC BC PUSH, C #100 # LD, B 0 # LD, NEXT, END-CODE MK_CDEC . DECIMAL\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '64  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'MK_CDEC ?'; then \
		echo "PASS: REPL test 390 — CODE MK_CDEC in HEX with #100: MK_CDEC . outputs '64  ok' (100 decimal printed in HEX)"; \
	else \
		echo "FAIL: REPL test 390 — expected '64  ok' AND no 'MK_CDEC ?' error (# prefix parses decimal regardless of HEX)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'DECIMAL CODE MK_CHEX BC PUSH, C $$ff # LD, B 0 # LD, NEXT, END-CODE MK_CHEX .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '255  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'MK_CHEX ?'; then \
		echo "PASS: REPL test 391 — CODE MK_CHEX in DECIMAL with \$$ff: MK_CHEX . outputs '255  ok'"; \
	else \
		echo "FAIL: REPL test 391 — expected '255  ok' AND no 'MK_CHEX ?' error (\$$ prefix parses hex regardless of DECIMAL)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- CODE block: BASE integrity snapshots (before CODE, after END-CODE, after invoke) ---
	@OUTPUT=$$(printf 'BASE @ . CODE MK_BS BC PUSH, C 0xFF # LD, B 0 # LD, NEXT, END-CODE BASE @ . MK_BS . BASE @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '10 10 255 10  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'MK_BS ?'; then \
		echo "PASS: REPL test 392 — CODE-block BASE integrity 4-snapshot outputs '10 10 255 10  ok'"; \
	else \
		echo "FAIL: REPL test 392 — expected '10 10 255 10  ok' AND no 'MK_BS ?' (BASE must be unchanged before CODE / after END-CODE / after invoke)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- CODE block: ABORT on malformed prefix (asm_cleanup rollback, no survivor) ---
	@OUTPUT=$$(printf 'CODE C_BAD #ABC BC PUSH, NEXT, END-CODE\r\nC_BAD .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '#ABC ?' && \
	   echo "$$OUTPUT" | grep -q 'C_BAD ?' && \
	   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '[0-9]  ok'; then \
		echo "PASS: REPL test 393 — malformed prefix in CODE block errors '#ABC ?', C_BAD unlinked via asm_cleanup"; \
	else \
		echo "FAIL: REPL test 393 — expected '#ABC ?' AND 'C_BAD ?' AND no spurious numeric ok (asm_cleanup rollback)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- Story 9.5 cross-context + FR47 regression guards (394..396) ---
	@# Mixed-context single session: REPL prefix, colon-body prefix, CODE-block prefix.
	@# Verifies asm_mode and .pref_negate do not leak across context boundaries.
	@OUTPUT=$$(printf '#42 . : F_MIX $$FF ; F_MIX . CODE C_MIX BC PUSH, C 0xFF # LD, B 0 # LD, NEXT, END-CODE C_MIX .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '42 255 255  ok' && \
	   ! echo "$$OUTPUT" | grep -qE '(F_MIX|C_MIX) \?'; then \
		echo "PASS: REPL test 394 — mixed-context (REPL + colon + CODE) outputs '42 255 255  ok' (no state leakage)"; \
	else \
		echo "FAIL: REPL test 394 — expected '42 255 255  ok' AND no F_MIX/C_MIX error markers (asm_mode / .pref_negate leak)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# FR47 regression: bare '-42' in colon body must reach NUMBER?, not the sign pre-pass.
	@OUTPUT=$$(printf ': F42N -42 ; F42N .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '\-42  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'F42N ?'; then \
		echo "PASS: REPL test 395 — FR47 colon-body: ': F42N -42 ; F42N .' outputs '-42  ok' (bare signed literal via NUMBER?)"; \
	else \
		echo "FAIL: REPL test 395 — expected '-42  ok' AND no 'F42N ?' error (FR47: sign pre-pass must not capture '-42')"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# FR47 regression: bare unprefixed '42' in CODE block via NUMBER? fallthrough.
	@OUTPUT=$$(printf 'CODE MK_42 BC PUSH, C 42 # LD, B 0 # LD, NEXT, END-CODE\r\nMK_42 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '42  ok' && \
	   ! echo "$$OUTPUT" | grep -q 'MK_42 ?'; then \
		echo "PASS: REPL test 396 — FR47 CODE-block: unprefixed '42' via NUMBER? fallthrough: MK_42 . outputs '42  ok'"; \
	else \
		echo "FAIL: REPL test 396 — expected '42  ok' AND no 'MK_42 ?' error (FR47: NUMBER? fallthrough inside CODE)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- Story 10.2 double-cell stack foundation (397..421) ---
	@# 2DUP value/depth checks
	@OUTPUT=$$(printf '1 2 2DUP .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<4> 1 2 1 2 '; then \
		echo "PASS: REPL test 397 — '1 2 2DUP .S' outputs '<4> 1 2 1 2 '"; \
	else \
		echo "FAIL: REPL test 397 — expected '<4> 1 2 1 2 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 0 2DUP .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<4> 0 0 0 0 '; then \
		echo "PASS: REPL test 398 — '0 0 2DUP .S' outputs '<4> 0 0 0 0 '"; \
	else \
		echo "FAIL: REPL test 398 — expected '<4> 0 0 0 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '%s\r\n%s\r\n' '-1 -2 2DUP .S' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<4> -1 -2 -1 -2 '; then \
		echo "PASS: REPL test 399 — '-1 -2 2DUP .S' outputs '<4> -1 -2 -1 -2 '"; \
	else \
		echo "FAIL: REPL test 399 — expected '<4> -1 -2 -1 -2 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# 2DROP depth/residual checks
	@OUTPUT=$$(printf '1 2 3 4 2DROP .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 1 2 '; then \
		echo "PASS: REPL test 400 — '1 2 3 4 2DROP .S' outputs '<2> 1 2 '"; \
	else \
		echo "FAIL: REPL test 400 — expected '<2> 1 2 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '100 200 2DROP .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<0> '; then \
		echo "PASS: REPL test 401 — '100 200 2DROP .S' outputs '<0> '"; \
	else \
		echo "FAIL: REPL test 401 — expected '<0> ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# 2SWAP pair-order checks
	@OUTPUT=$$(printf '1 2 3 4 2SWAP .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<4> 3 4 1 2 '; then \
		echo "PASS: REPL test 402 — '1 2 3 4 2SWAP .S' outputs '<4> 3 4 1 2 '"; \
	else \
		echo "FAIL: REPL test 402 — expected '<4> 3 4 1 2 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '10 20 30 40 2SWAP .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<4> 30 40 10 20 '; then \
		echo "PASS: REPL test 403 — '10 20 30 40 2SWAP .S' outputs '<4> 30 40 10 20 '"; \
	else \
		echo "FAIL: REPL test 403 — expected '<4> 30 40 10 20 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# 2OVER copy-second-pair checks
	@OUTPUT=$$(printf '1 2 3 4 2OVER .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<6> 1 2 3 4 1 2 '; then \
		echo "PASS: REPL test 404 — '1 2 3 4 2OVER .S' outputs '<6> 1 2 3 4 1 2 '"; \
	else \
		echo "FAIL: REPL test 404 — expected '<6> 1 2 3 4 1 2 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '10 20 30 40 2OVER .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<6> 10 20 30 40 10 20 '; then \
		echo "PASS: REPL test 405 — '10 20 30 40 2OVER .S' outputs '<6> 10 20 30 40 10 20 '"; \
	else \
		echo "FAIL: REPL test 405 — expected '<6> 10 20 30 40 10 20 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# 2@ byte-order anchor (E10-D1): low cell on TOS after fetch
	@OUTPUT=$$(printf 'HEX CREATE D1 BEEF , DEAD , D1 2@ .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -2153 -4111 '; then \
		echo "PASS: REPL test 406 — '2@' byte-order anchor: low cell (BEEF) on TOS, high (DEAD) below"; \
	else \
		echo "FAIL: REPL test 406 — expected '<2> -2153 -4111 ' (signed-hex DEAD BEEF) in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# 2! / 2@ round-trip
	@OUTPUT=$$(printf 'HEX CREATE D2 0 , 0 , BEEF DEAD D2 2! D2 2@ .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -4111 -2153 '; then \
		echo "PASS: REPL test 407 — '2! / 2@' round-trip returns the input pair in order (BEEF x1, DEAD x2)"; \
	else \
		echo "FAIL: REPL test 407 — expected '<2> -4111 -2153 ' after 2!/2@ round-trip (BEEF x1, DEAD x2)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# 2! / 2@ boundary values: 0 / FFFF / 8000
	@OUTPUT=$$(printf 'HEX CREATE D3 0 , 0 , 0 0 D3 2! D3 2@ .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 0 '; then \
		echo "PASS: REPL test 408 — '2! / 2@' round-trip at boundary 0 0"; \
	else \
		echo "FAIL: REPL test 408 — expected '<2> 0 0 ' at boundary 0 0"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'HEX CREATE D4 0 , 0 , FFFF FFFF D4 2! D4 2@ .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -1 -1 '; then \
		echo "PASS: REPL test 409 — '2! / 2@' round-trip at boundary FFFF FFFF"; \
	else \
		echo "FAIL: REPL test 409 — expected '<2> -1 -1 ' at boundary FFFF FFFF (signed interpretation)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'HEX CREATE D5 0 , 0 , 8000 8000 D5 2! D5 2@ .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -8000 -8000 '; then \
		echo "PASS: REPL test 410 — '2! / 2@' round-trip at boundary 8000 8000 (sign-bit set)"; \
	else \
		echo "FAIL: REPL test 410 — expected '<2> -8000 -8000 ' at boundary 8000 8000"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Stack-underflow recovery on empty stack for each new word
	@OUTPUT=$$(printf '2@\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 411 — '2@' on empty stack shows underflow and recovers"; \
	else \
		echo "FAIL: REPL test 411 — expected 'error -4: stack underflow' and 'ok' for '2@' on empty stack"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '2!\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 412 — '2!' on empty stack shows underflow and recovers"; \
	else \
		echo "FAIL: REPL test 412 — expected 'error -4: stack underflow' and 'ok' for '2!' on empty stack"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '2DUP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 413 — '2DUP' on empty stack shows underflow and recovers"; \
	else \
		echo "FAIL: REPL test 413 — expected 'error -4: stack underflow' and 'ok' for '2DUP' on empty stack"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 414 — '2DROP' on empty stack shows underflow and recovers"; \
	else \
		echo "FAIL: REPL test 414 — expected 'error -4: stack underflow' and 'ok' for '2DROP' on empty stack"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '2SWAP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 415 — '2SWAP' on empty stack shows underflow and recovers"; \
	else \
		echo "FAIL: REPL test 415 — expected 'error -4: stack underflow' and 'ok' for '2SWAP' on empty stack"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '2OVER\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 416 — '2OVER' on empty stack shows underflow and recovers"; \
	else \
		echo "FAIL: REPL test 416 — expected 'error -4: stack underflow' and 'ok' for '2OVER' on empty stack"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Near-threshold underflow (one cell short of minimum DEPTH)
	@OUTPUT=$$(printf '1 2DUP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 417 — '1 2DUP' (DEPTH 1, needs 2) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 417 — expected 'error -4: stack underflow' and 'ok' for '1 2DUP'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 418 — '1 2DROP' (DEPTH 1, needs 2) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 418 — expected 'error -4: stack underflow' and 'ok' for '1 2DROP'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 2 2!\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 419 — '1 2 2!' (DEPTH 2, needs 3) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 419 — expected 'error -4: stack underflow' and 'ok' for '1 2 2!'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 2 3 2SWAP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 420 — '1 2 3 2SWAP' (DEPTH 3, needs 4) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 420 — expected 'error -4: stack underflow' and 'ok' for '1 2 3 2SWAP'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 2 3 2OVER\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 421 — '1 2 3 2OVER' (DEPTH 3, needs 4) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 421 — expected 'error -4: stack underflow' and 'ok' for '1 2 3 2OVER'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- Story 10.2 code-review follow-up: @ now guards DEPTH>=1 (M2 fix) ---
	@OUTPUT=$$(printf '@\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 422 — '@' on empty stack shows underflow and recovers"; \
	else \
		echo "FAIL: REPL test 422 — expected 'error -4: stack underflow' and 'ok' for '@' on empty stack"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- Story 10.3 single<->double conversions (423..445) ---
	@# S>D value/boundary checks: TOS = low = n; second = high = 0 or -1.
	@OUTPUT=$$(printf '5 S>D .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 5 '; then \
		echo "PASS: REPL test 423 — '5 S>D .S' outputs '<2> 0 5 '"; \
	else \
		echo "FAIL: REPL test 423 — expected '<2> 0 5 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 S>D .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 0 '; then \
		echo "PASS: REPL test 424 — '0 S>D .S' outputs '<2> 0 0 '"; \
	else \
		echo "FAIL: REPL test 424 — expected '<2> 0 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '%s\r\n%s\r\n' '-5 S>D .S' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -1 -5 '; then \
		echo "PASS: REPL test 425 — '-5 S>D .S' outputs '<2> -1 -5 '"; \
	else \
		echo "FAIL: REPL test 425 — expected '<2> -1 -5 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '32767 S>D .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 32767 '; then \
		echo "PASS: REPL test 426 — '32767 S>D .S' outputs '<2> 0 32767 '"; \
	else \
		echo "FAIL: REPL test 426 — expected '<2> 0 32767 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '%s\r\n%s\r\n' '-32768 S>D .S' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -1 -32768 '; then \
		echo "PASS: REPL test 427 — '-32768 S>D .S' outputs '<2> -1 -32768 '"; \
	else \
		echo "FAIL: REPL test 427 — expected '<2> -1 -32768 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '%s\r\n%s\r\n' '-1 S>D .S' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -1 -1 '; then \
		echo "PASS: REPL test 428 — '-1 S>D .S' outputs '<2> -1 -1 '"; \
	else \
		echo "FAIL: REPL test 428 — expected '<2> -1 -1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# D>S pure-sign-extended doubles → single cell (round-trip preserving).
	@OUTPUT=$$(printf '0 5 D>S .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<1> 5 '; then \
		echo "PASS: REPL test 429 — '0 5 D>S .S' outputs '<1> 5 '"; \
	else \
		echo "FAIL: REPL test 429 — expected '<1> 5 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '%s\r\n%s\r\n' '-1 -5 D>S .S' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<1> -5 '; then \
		echo "PASS: REPL test 430 — '-1 -5 D>S .S' outputs '<1> -5 '"; \
	else \
		echo "FAIL: REPL test 430 — expected '<1> -5 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# D>S truncation: non-sign-extended double silently drops high cell (AC#2).
	@OUTPUT=$$(printf '1 5 D>S .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<1> 5 '; then \
		echo "PASS: REPL test 431 — '1 5 D>S .S' (truncates high=1) outputs '<1> 5 '"; \
	else \
		echo "FAIL: REPL test 431 — expected '<1> 5 ' (high cell 1 discarded) in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# S>D D>S round-trip preserves the value across the signed-16 range.
	@OUTPUT=$$(printf '0 S>D D>S .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '^0 '; then \
		echo "PASS: REPL test 432 — '0 S>D D>S .' outputs '0 '"; \
	else \
		echo "FAIL: REPL test 432 — expected '0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 S>D D>S .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '^1 '; then \
		echo "PASS: REPL test 433 — '1 S>D D>S .' outputs '1 '"; \
	else \
		echo "FAIL: REPL test 433 — expected '1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '%s\r\n%s\r\n' '-1 S>D D>S .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '^-1 '; then \
		echo "PASS: REPL test 434 — '-1 S>D D>S .' outputs '-1 '"; \
	else \
		echo "FAIL: REPL test 434 — expected '-1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '32767 S>D D>S .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '^32767 '; then \
		echo "PASS: REPL test 435 — '32767 S>D D>S .' outputs '32767 '"; \
	else \
		echo "FAIL: REPL test 435 — expected '32767 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '%s\r\n%s\r\n' '-32768 S>D D>S .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '^-32768 '; then \
		echo "PASS: REPL test 436 — '-32768 S>D D>S .' outputs '-32768 '"; \
	else \
		echo "FAIL: REPL test 436 — expected '-32768 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '100 S>D D>S .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '^100 '; then \
		echo "PASS: REPL test 437 — '100 S>D D>S .' outputs '100 '"; \
	else \
		echo "FAIL: REPL test 437 — expected '100 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '%s\r\n%s\r\n' '-100 S>D D>S .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '^-100 '; then \
		echo "PASS: REPL test 438 — '-100 S>D D>S .' outputs '-100 '"; \
	else \
		echo "FAIL: REPL test 438 — expected '-100 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# >NUMBER single-cell accumulation (baseline, pre-existing semantics).
	@# Stack after: <4> ud2-high=0 ud2-low=42 c-addr2 u2=0 (TOS). Check ud2-low=42 and u2=0.
	@OUTPUT=$$(printf '0 0 S" 42" DROP 2 >NUMBER 2DROP .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 42 '; then \
		echo "PASS: REPL test 439 — '0 0 S\" 42\" DROP 2 >NUMBER 2DROP .S' outputs '<2> 0 42 '"; \
	else \
		echo "FAIL: REPL test 439 — expected '<2> 0 42 ' (ud2 = 42) in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# >NUMBER double-cell accumulation across the 16-bit boundary.
	@# "65536" decimal = high:1 low:0. 2DROP trims c-addr2/u2 so .S surfaces ud2.
	@OUTPUT=$$(printf '0 0 S" 65536" DROP 5 >NUMBER 2DROP .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 1 0 '; then \
		echo "PASS: REPL test 440 — '0 0 S\" 65536\" DROP 5 >NUMBER 2DROP .S' outputs '<2> 1 0 ' (ud2 = 65536)"; \
	else \
		echo "FAIL: REPL test 440 — expected '<2> 1 0 ' (ud2-high=1, ud2-low=0, ie 65536) in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# >NUMBER well above the 16-bit boundary: 1_000_000 = 15*65536 + 16960.
	@OUTPUT=$$(printf '0 0 S" 1000000" DROP 7 >NUMBER 2DROP .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 15 16960 '; then \
		echo "PASS: REPL test 441 — '0 0 S\" 1000000\" DROP 7 >NUMBER 2DROP .S' outputs '<2> 15 16960 ' (ud2 = 1000000)"; \
	else \
		echo "FAIL: REPL test 441 — expected '<2> 15 16960 ' (ud2 = 1_000_000) in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Underflow recovery: S>D needs 1, D>S needs 2, >NUMBER needs 3.
	@OUTPUT=$$(printf 'S>D\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 442 — 'S>D' on empty stack shows underflow and recovers"; \
	else \
		echo "FAIL: REPL test 442 — expected 'error -4: stack underflow' and 'ok' for 'S>D' on empty stack"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'D>S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 443 — 'D>S' on empty stack shows underflow and recovers"; \
	else \
		echo "FAIL: REPL test 443 — expected 'error -4: stack underflow' and 'ok' for 'D>S' on empty stack"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 D>S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 444 — '1 D>S' (DEPTH 1, needs 2) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 444 — expected 'error -4: stack underflow' and 'ok' for '1 D>S'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '>NUMBER\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 445 — '>NUMBER' on empty stack shows underflow and recovers"; \
	else \
		echo "FAIL: REPL test 445 — expected 'error -4: stack underflow' and 'ok' for '>NUMBER' on empty stack"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# >NUMBER needs 4 inputs (ud1 c-addr1 u1) — DEPTH=1/2/3 must all underflow.
	@OUTPUT=$$(printf '1 >NUMBER\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 446 — '1 >NUMBER' (DEPTH 1, needs 4) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 446 — expected 'error -4: stack underflow' and 'ok' for '1 >NUMBER'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 2 >NUMBER\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 447 — '1 2 >NUMBER' (DEPTH 2, needs 4) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 447 — expected 'error -4: stack underflow' and 'ok' for '1 2 >NUMBER'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 2 3 >NUMBER\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 448 — '1 2 3 >NUMBER' (DEPTH 3, needs 4) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 448 — expected 'error -4: stack underflow' and 'ok' for '1 2 3 >NUMBER'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# >NUMBER BASE=2: 17-bit binary string "10000000000000000" parses to 65536 (ud2-high=1, ud2-low=0).
	@# Numeric literals are decimal on entry; BASE is flipped to 2 only for >NUMBER itself, then restored.
	@OUTPUT=$$(printf '0 0 S" 10000000000000000" DROP 17 2 BASE ! >NUMBER DECIMAL 2DROP .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 1 0 '; then \
		echo "PASS: REPL test 449 — BASE=2 '>NUMBER' on 17-bit string outputs '<2> 1 0 ' (ud2 = 65536)"; \
	else \
		echo "FAIL: REPL test 449 — expected '<2> 1 0 ' (ud2 = 65536) in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- Story 10.4 double-cell arithmetic (450..501) — DPANS94 §8.6 {1040,1050,1110,1120,1160,1210,1220,1230,1830} ---
	@# D+ (§8.6.1040): double-cell add with 32-bit carry propagation.
	@OUTPUT=$$(printf '0 0 0 0 D+ .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 0 '; then \
		echo "PASS: REPL test 450 — '0 0 0 0 D+ .S 2DROP' outputs '<2> 0 0 ' (zero + zero)"; \
	else \
		echo "FAIL: REPL test 450 — expected '<2> 0 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 5 0 7 D+ .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 12 '; then \
		echo "PASS: REPL test 451 — '0 5 0 7 D+ .S 2DROP' outputs '<2> 0 12 ' (5 + 7 = 12)"; \
	else \
		echo "FAIL: REPL test 451 — expected '<2> 0 12 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 -1 0 1 D+ .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 1 0 '; then \
		echo "PASS: REPL test 452 — '0 -1 0 1 D+ .S 2DROP' outputs '<2> 1 0 ' (low-cell carry ripples)"; \
	else \
		echo "FAIL: REPL test 452 — expected '<2> 1 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 -1 0 1 D+ .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 0 '; then \
		echo "PASS: REPL test 453 — '-1 -1 0 1 D+ .S 2DROP' outputs '<2> 0 0 ' (full 32-bit wrap)"; \
	else \
		echo "FAIL: REPL test 453 — expected '<2> 0 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '32767 -1 0 1 D+ .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -32768 0 '; then \
		echo "PASS: REPL test 454 — '32767 -1 0 1 D+ .S 2DROP' outputs '<2> -32768 0 ' (32-bit signed overflow silently wraps)"; \
	else \
		echo "FAIL: REPL test 454 — expected '<2> -32768 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# D- (§8.6.1050): double-cell subtract with 32-bit borrow propagation.
	@OUTPUT=$$(printf '0 10 0 4 D- .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 6 '; then \
		echo "PASS: REPL test 455 — '0 10 0 4 D- .S 2DROP' outputs '<2> 0 6 '"; \
	else \
		echo "FAIL: REPL test 455 — expected '<2> 0 6 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 4 0 10 D- .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -1 -6 '; then \
		echo "PASS: REPL test 456 — '0 4 0 10 D- .S 2DROP' outputs '<2> -1 -6 ' (borrow ripples into high cell)"; \
	else \
		echo "FAIL: REPL test 456 — expected '<2> -1 -6 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 0 0 1 D- .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -1 -1 '; then \
		echo "PASS: REPL test 457 — '0 0 0 1 D- .S 2DROP' outputs '<2> -1 -1 ' (0 - 1 = -1 as signed double)"; \
	else \
		echo "FAIL: REPL test 457 — expected '<2> -1 -1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 0 0 1 D- .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 -1 '; then \
		echo 'PASS: REPL test 458 — '\''1 0 0 1 D- .S 2DROP'\'' outputs '\''<2> 0 -1 '\'' ($$10000 - 1)'; \
	else \
		echo "FAIL: REPL test 458 — expected '<2> 0 -1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 -1 0 1 D- .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -1 -2 '; then \
		echo "PASS: REPL test 459 — '-1 -1 0 1 D- .S 2DROP' outputs '<2> -1 -2 '"; \
	else \
		echo "FAIL: REPL test 459 — expected '<2> -1 -2 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# DNEGATE (§8.6.1230): double-cell two's-complement negate.
	@OUTPUT=$$(printf '0 0 DNEGATE .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 0 '; then \
		echo "PASS: REPL test 460 — '0 0 DNEGATE .S 2DROP' outputs '<2> 0 0 '"; \
	else \
		echo "FAIL: REPL test 460 — expected '<2> 0 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 1 DNEGATE .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -1 -1 '; then \
		echo "PASS: REPL test 461 — '0 1 DNEGATE .S 2DROP' outputs '<2> -1 -1 ' (=-1 as signed double)"; \
	else \
		echo "FAIL: REPL test 461 — expected '<2> -1 -1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 -1 DNEGATE .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 1 '; then \
		echo "PASS: REPL test 462 — '-1 -1 DNEGATE .S 2DROP' outputs '<2> 0 1 '"; \
	else \
		echo "FAIL: REPL test 462 — expected '<2> 0 1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 -32768 DNEGATE .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -1 -32768 '; then \
		echo 'PASS: REPL test 463 — '\''0 -32768 DNEGATE .S 2DROP'\'' outputs '\''<2> -1 -32768 '\'' (0:$$8000 → -(32768) = $$FFFF8000)'; \
	else \
		echo "FAIL: REPL test 463 — expected '<2> -1 -32768 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# DABS (§8.6.1160): double-cell absolute value.
	@OUTPUT=$$(printf '0 0 DABS .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 0 '; then \
		echo "PASS: REPL test 464 — '0 0 DABS .S 2DROP' outputs '<2> 0 0 '"; \
	else \
		echo "FAIL: REPL test 464 — expected '<2> 0 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 5 DABS .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 5 '; then \
		echo "PASS: REPL test 465 — '0 5 DABS .S 2DROP' outputs '<2> 0 5 ' (positive unchanged)"; \
	else \
		echo "FAIL: REPL test 465 — expected '<2> 0 5 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 -5 DABS .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 5 '; then \
		echo "PASS: REPL test 466 — '-1 -5 DABS .S 2DROP' outputs '<2> 0 5 ' (negates)"; \
	else \
		echo "FAIL: REPL test 466 — expected '<2> 0 5 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 0 DABS .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 1 0 '; then \
		echo 'PASS: REPL test 467 — '\''-1 0 DABS .S 2DROP'\'' outputs '\''<2> 1 0 '\'' ($$FFFF0000 → $$00010000)'; \
	else \
		echo "FAIL: REPL test 467 — expected '<2> 1 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# D= (§8.6.1120): double-cell equality → flag.
	@OUTPUT=$$(printf '0 0 0 0 D= .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-1 '; then \
		echo "PASS: REPL test 468 — '0 0 0 0 D= .' outputs '-1 ' (equal zeros)"; \
	else \
		echo "FAIL: REPL test 468 — expected '-1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 5 0 5 D= .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-1 '; then \
		echo "PASS: REPL test 469 — '0 5 0 5 D= .' outputs '-1 ' (equal non-zero)"; \
	else \
		echo "FAIL: REPL test 469 — expected '-1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 5 0 6 D= .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0  ok'; then \
		echo "PASS: REPL test 470 — '0 5 0 6 D= .' outputs '0 ' (low cells differ)"; \
	else \
		echo "FAIL: REPL test 470 — expected '0  ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 5 2 5 D= .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0  ok'; then \
		echo "PASS: REPL test 471 — '1 5 2 5 D= .' outputs '0 ' (high cells differ)"; \
	else \
		echo "FAIL: REPL test 471 — expected '0  ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 -1 -1 -1 D= .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-1 '; then \
		echo "PASS: REPL test 472 — '-1 -1 -1 -1 D= .' outputs '-1 ' (all-bits-set equality)"; \
	else \
		echo "FAIL: REPL test 472 — expected '-1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# D< (§8.6.1110): signed high / unsigned low double-cell less-than.
	@OUTPUT=$$(printf '0 0 0 1 D< .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-1 '; then \
		echo "PASS: REPL test 473 — '0 0 0 1 D< .' outputs '-1 ' (0 < 1)"; \
	else \
		echo "FAIL: REPL test 473 — expected '-1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 1 0 0 D< .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0  ok'; then \
		echo "PASS: REPL test 474 — '0 1 0 0 D< .' outputs '0 ' (1 < 0 is false)"; \
	else \
		echo "FAIL: REPL test 474 — expected '0  ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 -1 0 0 D< .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-1 '; then \
		echo "PASS: REPL test 475 — '-1 -1 0 0 D< .' outputs '-1 ' (signed -1 < 0 — trap case)"; \
	else \
		echo "FAIL: REPL test 475 — expected '-1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 0 -1 -1 D< .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0  ok'; then \
		echo "PASS: REPL test 476 — '0 0 -1 -1 D< .' outputs '0 ' (0 < -1 is false)"; \
	else \
		echo "FAIL: REPL test 476 — expected '0  ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 -1 1 0 D< .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-1 '; then \
		echo 'PASS: REPL test 477 — '\''0 -1 1 0 D< .'\'' outputs '\''-1 '\'' ($$FFFF < $$10000, high cells differ)'; \
	else \
		echo "FAIL: REPL test 477 — expected '-1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 0 1 0 D< .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0  ok'; then \
		echo "PASS: REPL test 478 — '1 0 1 0 D< .' outputs '0 ' (equal, not less-than)"; \
	else \
		echo "FAIL: REPL test 478 — expected '0  ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 0 -1 1 D< .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-1 '; then \
		echo "PASS: REPL test 479 — '-1 0 -1 1 D< .' outputs '-1 ' (high cells equal; low cells compared unsigned 0 < 1)"; \
	else \
		echo "FAIL: REPL test 479 — expected '-1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# DMAX (§8.6.1210): double-cell max (signed ordering).
	@OUTPUT=$$(printf '0 5 0 7 DMAX .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 7 '; then \
		echo "PASS: REPL test 480 — '0 5 0 7 DMAX .S 2DROP' outputs '<2> 0 7 '"; \
	else \
		echo "FAIL: REPL test 480 — expected '<2> 0 7 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 -1 0 0 DMAX .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 0 '; then \
		echo "PASS: REPL test 481 — '-1 -1 0 0 DMAX .S 2DROP' outputs '<2> 0 0 ' (0 > -1 signed)"; \
	else \
		echo "FAIL: REPL test 481 — expected '<2> 0 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 5 0 5 DMAX .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 5 '; then \
		echo "PASS: REPL test 482 — '0 5 0 5 DMAX .S 2DROP' outputs '<2> 0 5 ' (equal → either copy)"; \
	else \
		echo "FAIL: REPL test 482 — expected '<2> 0 5 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 -1 1 0 DMAX .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 1 0 '; then \
		echo 'PASS: REPL test 483 — '\''0 -1 1 0 DMAX .S 2DROP'\'' outputs '\''<2> 1 0 '\'' ($$10000 > $$FFFF)'; \
	else \
		echo "FAIL: REPL test 483 — expected '<2> 1 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# DMIN (§8.6.1220): double-cell min (signed ordering).
	@OUTPUT=$$(printf '0 5 0 7 DMIN .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 5 '; then \
		echo "PASS: REPL test 484 — '0 5 0 7 DMIN .S 2DROP' outputs '<2> 0 5 '"; \
	else \
		echo "FAIL: REPL test 484 — expected '<2> 0 5 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 -1 0 0 DMIN .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -1 -1 '; then \
		echo "PASS: REPL test 485 — '-1 -1 0 0 DMIN .S 2DROP' outputs '<2> -1 -1 ' (-1 < 0 signed)"; \
	else \
		echo "FAIL: REPL test 485 — expected '<2> -1 -1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 5 0 5 DMIN .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 5 '; then \
		echo "PASS: REPL test 486 — '0 5 0 5 DMIN .S 2DROP' outputs '<2> 0 5 ' (equal)"; \
	else \
		echo "FAIL: REPL test 486 — expected '<2> 0 5 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 -1 1 0 DMIN .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 -1 '; then \
		echo 'PASS: REPL test 487 — '\''0 -1 1 0 DMIN .S 2DROP'\'' outputs '\''<2> 0 -1 '\'' ($$FFFF < $$10000)'; \
	else \
		echo "FAIL: REPL test 487 — expected '<2> 0 -1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# M+ (§8.6.1830): mixed single+double add (sign-extended).
	@OUTPUT=$$(printf '0 0 1 M+ .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 1 '; then \
		echo "PASS: REPL test 488 — '0 0 1 M+ .S 2DROP' outputs '<2> 0 1 ' (0.0 + 1)"; \
	else \
		echo "FAIL: REPL test 488 — expected '<2> 0 1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 0 -1 M+ .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -1 -1 '; then \
		echo "PASS: REPL test 489 — '0 0 -1 M+ .S 2DROP' outputs '<2> -1 -1 ' (sign-extended negative rolls both cells)"; \
	else \
		echo "FAIL: REPL test 489 — expected '<2> -1 -1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 -1 1 M+ .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 1 0 '; then \
		echo "PASS: REPL test 490 — '0 -1 1 M+ .S 2DROP' outputs '<2> 1 0 ' (low-cell carry ripples)"; \
	else \
		echo "FAIL: REPL test 490 — expected '<2> 1 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 0 -5 M+ .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -1 -5 '; then \
		echo "PASS: REPL test 491 — '0 0 -5 M+ .S 2DROP' outputs '<2> -1 -5 '"; \
	else \
		echo "FAIL: REPL test 491 — expected '<2> -1 -5 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 -5 -1 M+ .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -1 -6 '; then \
		echo "PASS: REPL test 492 — '-1 -5 -1 M+ .S 2DROP' outputs '<2> -1 -6 ' (negative + negative stays negative, no low-cell carry)"; \
	else \
		echo "FAIL: REPL test 492 — expected '<2> -1 -6 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Story 10.4 underflow recovery: one per word at DEPTH = N-1.
	@OUTPUT=$$(printf '1 2 3 D+\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 493 — '1 2 3 D+' (DEPTH 3, needs 4) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 493 — expected 'error -4: stack underflow' and 'ok' for '1 2 3 D+'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 2 3 D-\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 494 — '1 2 3 D-' (DEPTH 3, needs 4) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 494 — expected 'error -4: stack underflow' and 'ok' for '1 2 3 D-'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 DNEGATE\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 495 — '1 DNEGATE' (DEPTH 1, needs 2) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 495 — expected 'error -4: stack underflow' and 'ok' for '1 DNEGATE'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 DABS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 496 — '1 DABS' (DEPTH 1, needs 2) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 496 — expected 'error -4: stack underflow' and 'ok' for '1 DABS'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 2 3 D=\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 497 — '1 2 3 D=' (DEPTH 3, needs 4) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 497 — expected 'error -4: stack underflow' and 'ok' for '1 2 3 D='"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 2 3 D<\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 498 — '1 2 3 D<' (DEPTH 3, needs 4) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 498 — expected 'error -4: stack underflow' and 'ok' for '1 2 3 D<'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 2 3 DMAX\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 499 — '1 2 3 DMAX' (DEPTH 3, needs 4) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 499 — expected 'error -4: stack underflow' and 'ok' for '1 2 3 DMAX'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 2 3 DMIN\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 500 — '1 2 3 DMIN' (DEPTH 3, needs 4) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 500 — expected 'error -4: stack underflow' and 'ok' for '1 2 3 DMIN'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 2 M+\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 501 — '1 2 M+' (DEPTH 2, needs 3) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 501 — expected 'error -4: stack underflow' and 'ok' for '1 2 M+'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- Story 10.5 double-cell multiplication (502..525) — DPANS94 §6.1.{1810,2360} + §8.6.1090 ---
	@# UM* (§6.1.2360): unsigned 16×16 → 32 mixed multiply.
	@OUTPUT=$$(printf '0 0 UM* .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 0 '; then \
		echo "PASS: REPL test 502 — '0 0 UM* .S 2DROP' outputs '<2> 0 0 ' (zero × zero)"; \
	else \
		echo "FAIL: REPL test 502 — expected '<2> 0 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 5 UM* .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 0 '; then \
		echo "PASS: REPL test 503 — '0 5 UM* .S 2DROP' outputs '<2> 0 0 ' (zero × nonzero)"; \
	else \
		echo "FAIL: REPL test 503 — expected '<2> 0 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 1 UM* .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 1 '; then \
		echo "PASS: REPL test 504 — '1 1 UM* .S 2DROP' outputs '<2> 0 1 ' (trivial product fits in low cell)"; \
	else \
		echo "FAIL: REPL test 504 — expected '<2> 0 1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '$$100 $$100 UM* .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 1 0 '; then \
		echo "PASS: REPL test 505 — '\$$100 \$$100 UM* .S 2DROP' outputs '<2> 1 0 ' (256×256=65536; clean carry into high cell)"; \
	else \
		echo "FAIL: REPL test 505 — expected '<2> 1 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '$$FFFF $$FFFF UM* .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -2 1 '; then \
		echo "PASS: REPL test 506 — '\$$FFFF \$$FFFF UM* .S 2DROP' outputs '<2> -2 1 ' (\$$FFFE0001; max unsigned squared)"; \
	else \
		echo "FAIL: REPL test 506 — expected '<2> -2 1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '$$FFFF 2 UM* .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 1 -2 '; then \
		echo "PASS: REPL test 507 — '\$$FFFF 2 UM* .S 2DROP' outputs '<2> 1 -2 ' (\$$1FFFE; low-cell wrap)"; \
	else \
		echo "FAIL: REPL test 507 — expected '<2> 1 -2 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# M* (§6.1.1810): signed 16×16 → 32 mixed multiply (UM* + sign tracking).
	@OUTPUT=$$(printf '0 0 M* .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 0 '; then \
		echo "PASS: REPL test 508 — '0 0 M* .S 2DROP' outputs '<2> 0 0 '"; \
	else \
		echo "FAIL: REPL test 508 — expected '<2> 0 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '5 3 M* .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 15 '; then \
		echo "PASS: REPL test 509 — '5 3 M* .S 2DROP' outputs '<2> 0 15 ' (positive × positive)"; \
	else \
		echo "FAIL: REPL test 509 — expected '<2> 0 15 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-5 3 M* .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -1 -15 '; then \
		echo "PASS: REPL test 510 — '-5 3 M* .S 2DROP' outputs '<2> -1 -15 ' (negative × positive → negative double)"; \
	else \
		echo "FAIL: REPL test 510 — expected '<2> -1 -15 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '5 -3 M* .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -1 -15 '; then \
		echo "PASS: REPL test 511 — '5 -3 M* .S 2DROP' outputs '<2> -1 -15 ' (positive × negative → negative)"; \
	else \
		echo "FAIL: REPL test 511 — expected '<2> -1 -15 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-5 -3 M* .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 15 '; then \
		echo "PASS: REPL test 512 — '-5 -3 M* .S 2DROP' outputs '<2> 0 15 ' (negative × negative → positive)"; \
	else \
		echo "FAIL: REPL test 512 — expected '<2> 0 15 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-32768 -32768 M* .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 16384 0 '; then \
		echo "PASS: REPL test 513 — '-32768 -32768 M* .S 2DROP' outputs '<2> 16384 0 ' (\$$40000000; ABS(\$$8000) trap collapses)"; \
	else \
		echo "FAIL: REPL test 513 — expected '<2> 16384 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '32767 32767 M* .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 16383 1 '; then \
		echo "PASS: REPL test 514 — '32767 32767 M* .S 2DROP' outputs '<2> 16383 1 ' (\$$3FFF0001; max positive squared)"; \
	else \
		echo "FAIL: REPL test 514 — expected '<2> 16383 1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-32768 32767 M* .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -16384 -32768 '; then \
		echo "PASS: REPL test 515 — '-32768 32767 M* .S 2DROP' outputs '<2> -16384 -32768 ' (-\$$3FFF8000; sign and magnitude)"; \
	else \
		echo "FAIL: REPL test 515 — expected '<2> -16384 -32768 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# D* (§8.6.1090): truncating double × double (low 32 bits).
	@OUTPUT=$$(printf '0 0 0 0 D* .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 0 '; then \
		echo "PASS: REPL test 516 — '0 0 0 0 D* .S 2DROP' outputs '<2> 0 0 '"; \
	else \
		echo "FAIL: REPL test 516 — expected '<2> 0 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 5 0 3 D* .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 15 '; then \
		echo "PASS: REPL test 517 — '0 5 0 3 D* .S 2DROP' outputs '<2> 0 15 ' (both fit in single cells)"; \
	else \
		echo "FAIL: REPL test 517 — expected '<2> 0 15 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 -1 0 1 D* .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 -1 '; then \
		echo "PASS: REPL test 518 — '0 -1 0 1 D* .S 2DROP' outputs '<2> 0 -1 ' (65535×1=\$$0000FFFF)"; \
	else \
		echo "FAIL: REPL test 518 — expected '<2> 0 -1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 -1 0 -1 D* .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -2 1 '; then \
		echo "PASS: REPL test 519 — '0 -1 0 -1 D* .S 2DROP' outputs '<2> -2 1 ' (65535×65535=\$$FFFE0001)"; \
	else \
		echo "FAIL: REPL test 519 — expected '<2> -2 1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 -1 0 1 D* .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -1 -1 '; then \
		echo "PASS: REPL test 520 — '-1 -1 0 1 D* .S 2DROP' outputs '<2> -1 -1 ' (-1 × 1 signed double)"; \
	else \
		echo "FAIL: REPL test 520 — expected '<2> -1 -1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 -1 -1 -1 D* .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 1 '; then \
		echo "PASS: REPL test 521 — '-1 -1 -1 -1 D* .S 2DROP' outputs '<2> 0 1 ' (two's-complement -1×-1=1)"; \
	else \
		echo "FAIL: REPL test 521 — expected '<2> 0 1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 1 -1 0 D* .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -1 0 '; then \
		echo "PASS: REPL test 522 — '0 1 -1 0 D* .S 2DROP' outputs '<2> -1 0 ' (cross-term carry: \$$FFFF0000)"; \
	else \
		echo "FAIL: REPL test 522 — expected '<2> -1 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Story 10.5 underflow recovery: one per word at DEPTH = N-1.
	@OUTPUT=$$(printf '1 UM*\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 523 — '1 UM*' (DEPTH 1, needs 2) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 523 — expected 'error -4: stack underflow' and 'ok' for '1 UM*'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 M*\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 524 — '1 M*' (DEPTH 1, needs 2) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 524 — expected 'error -4: stack underflow' and 'ok' for '1 M*'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 2 3 D*\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 525 — '1 2 3 D*' (DEPTH 3, needs 4) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 525 — expected 'error -4: stack underflow' and 'ok' for '1 2 3 D*'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- Story 10.6 double/mixed-precision division (526..549) — DPANS94 §6.1.{1561,2214,2370} ---
	@# UM/MOD — unsigned mixed divide (§6.1.2370)
	@OUTPUT=$$(printf '0 0 1 UM/MOD .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 0 '; then \
		echo "PASS: REPL test 526 — '0 0 1 UM/MOD .S 2DROP' outputs '<2> 0 0 ' (zero dividend)"; \
	else \
		echo "FAIL: REPL test 526 — expected '<2> 0 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 1 1 UM/MOD .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 1 '; then \
		echo "PASS: REPL test 527 — '0 1 1 UM/MOD .S 2DROP' outputs '<2> 0 1 ' (unity / unity)"; \
	else \
		echo "FAIL: REPL test 527 — expected '<2> 0 1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 10 3 UM/MOD .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 1 3 '; then \
		echo "PASS: REPL test 528 — '0 10 3 UM/MOD .S 2DROP' outputs '<2> 1 3 ' (10/3 = 3 rem 1)"; \
	else \
		echo "FAIL: REPL test 528 — expected '<2> 1 3 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '0 -1 1 UM/MOD .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 -1 '; then \
		echo "PASS: REPL test 529 — '0 -1 1 UM/MOD .S 2DROP' outputs '<2> 0 -1 ' (\$$FFFF / 1 = \$$FFFF rem 0)"; \
	else \
		echo "FAIL: REPL test 529 — expected '<2> 0 -1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 0 2 UM/MOD .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 -32768 '; then \
		echo "PASS: REPL test 530 — '1 0 2 UM/MOD .S 2DROP' outputs '<2> 0 -32768 ' (\$$10000 / 2 = \$$8000 rem 0)"; \
	else \
		echo "FAIL: REPL test 530 — expected '<2> 0 -32768 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '0 -1 -1 UM/MOD .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 1 '; then \
		echo "PASS: REPL test 531 — '0 -1 -1 UM/MOD .S 2DROP' outputs '<2> 0 1 ' (\$$FFFF / \$$FFFF = 1 rem 0)"; \
	else \
		echo "FAIL: REPL test 531 — expected '<2> 0 1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-2 -1 -1 UM/MOD .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -2 -1 '; then \
		echo "PASS: REPL test 532 — '-2 -1 -1 UM/MOD .S 2DROP' outputs '<2> -2 -1 ' (\$$FFFEFFFF / \$$FFFF = \$$FFFF rem \$$FFFE — max quot just-fits)"; \
	else \
		echo "FAIL: REPL test 532 — expected '<2> -2 -1 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# SM/REM — symmetric signed mixed divide (§6.1.2214); remainder sign matches dividend.
	@OUTPUT=$$(printf '0 10 3 SM/REM .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 1 3 '; then \
		echo "PASS: REPL test 533 — '0 10 3 SM/REM .S 2DROP' outputs '<2> 1 3 ' (+10 / +3 = +3 rem +1)"; \
	else \
		echo "FAIL: REPL test 533 — expected '<2> 1 3 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 -10 3 SM/REM .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -1 -3 '; then \
		echo "PASS: REPL test 534 — '-1 -10 3 SM/REM .S 2DROP' outputs '<2> -1 -3 ' (-10 / +3 = -3 rem -1; rem matches dividend sign)"; \
	else \
		echo "FAIL: REPL test 534 — expected '<2> -1 -3 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '0 10 -3 SM/REM .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 1 -3 '; then \
		echo "PASS: REPL test 535 — '0 10 -3 SM/REM .S 2DROP' outputs '<2> 1 -3 ' (+10 / -3 = -3 rem +1; rem matches dividend sign)"; \
	else \
		echo "FAIL: REPL test 535 — expected '<2> 1 -3 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 -10 -3 SM/REM .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -1 3 '; then \
		echo "PASS: REPL test 536 — '-1 -10 -3 SM/REM .S 2DROP' outputs '<2> -1 3 ' (-10 / -3 = +3 rem -1; rem matches dividend sign)"; \
	else \
		echo "FAIL: REPL test 536 — expected '<2> -1 3 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 0 7 SM/REM .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 0 '; then \
		echo "PASS: REPL test 537 — '0 0 7 SM/REM .S 2DROP' outputs '<2> 0 0 ' (zero dividend)"; \
	else \
		echo "FAIL: REPL test 537 — expected '<2> 0 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 -5 10 SM/REM .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -5 0 '; then \
		echo "PASS: REPL test 538 — '-1 -5 10 SM/REM .S 2DROP' outputs '<2> -5 0 ' (|-5|<10 → quot 0 rem -5)"; \
	else \
		echo "FAIL: REPL test 538 — expected '<2> -5 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 -32768 1 SM/REM .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 -32768 '; then \
		echo "PASS: REPL test 539 — '-1 -32768 1 SM/REM .S 2DROP' outputs '<2> 0 -32768 ' (\$$FFFF8000 / 1 = -32768 rem 0)"; \
	else \
		echo "FAIL: REPL test 539 — expected '<2> 0 -32768 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# FM/MOD — floored signed mixed divide (§6.1.1561); remainder sign matches divisor.
	@OUTPUT=$$(printf '0 10 3 FM/MOD .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 1 3 '; then \
		echo "PASS: REPL test 540 — '0 10 3 FM/MOD .S 2DROP' outputs '<2> 1 3 ' (same-sign — matches SM/REM)"; \
	else \
		echo "FAIL: REPL test 540 — expected '<2> 1 3 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 -10 3 FM/MOD .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 2 -4 '; then \
		echo "PASS: REPL test 541 — '-1 -10 3 FM/MOD .S 2DROP' outputs '<2> 2 -4 ' (-10 floored /3 = -4 rem 2 — discriminates from SM/REM's -1 -3)"; \
	else \
		echo "FAIL: REPL test 541 — expected '<2> 2 -4 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '0 10 -3 FM/MOD .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -2 -4 '; then \
		echo "PASS: REPL test 542 — '0 10 -3 FM/MOD .S 2DROP' outputs '<2> -2 -4 ' (+10 floored /-3 = -4 rem -2 — discriminates from SM/REM's 1 -3)"; \
	else \
		echo "FAIL: REPL test 542 — expected '<2> -2 -4 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 -10 -3 FM/MOD .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> -1 3 '; then \
		echo "PASS: REPL test 543 — '-1 -10 -3 FM/MOD .S 2DROP' outputs '<2> -1 3 ' (same-sign negative — matches SM/REM)"; \
	else \
		echo "FAIL: REPL test 543 — expected '<2> -1 3 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 0 7 FM/MOD .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 0 '; then \
		echo "PASS: REPL test 544 — '0 0 7 FM/MOD .S 2DROP' outputs '<2> 0 0 ' (zero dividend)"; \
	else \
		echo "FAIL: REPL test 544 — expected '<2> 0 0 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 9 3 FM/MOD .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 3 '; then \
		echo "PASS: REPL test 545 — '0 9 3 FM/MOD .S 2DROP' outputs '<2> 0 3 ' (exact — no correction applied)"; \
	else \
		echo "FAIL: REPL test 545 — expected '<2> 0 3 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 -9 3 FM/MOD .S 2DROP\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '<2> 0 -3 '; then \
		echo "PASS: REPL test 546 — '-1 -9 3 FM/MOD .S 2DROP' outputs '<2> 0 -3 ' (exact negative — no correction)"; \
	else \
		echo "FAIL: REPL test 546 — expected '<2> 0 -3 ' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Story 10.6 underflow recovery: one per word at DEPTH = N-1 = 2.
	@OUTPUT=$$(printf '1 2 UM/MOD\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 547 — '1 2 UM/MOD' (DEPTH 2, needs 3) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 547 — expected 'error -4: stack underflow' and 'ok' for '1 2 UM/MOD'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 2 SM/REM\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 548 — '1 2 SM/REM' (DEPTH 2, needs 3) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 548 — expected 'error -4: stack underflow' and 'ok' for '1 2 SM/REM'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 2 FM/MOD\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 549 — '1 2 FM/MOD' (DEPTH 2, needs 3) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 549 — expected 'error -4: stack underflow' and 'ok' for '1 2 FM/MOD'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- Story 10.7 pictured numeric output (550..571) — DPANS94 §6.1.{0030,0040,0050,0490,1670,2210} + §6.2.1675 ---
	@# Core primitives: decimal round-trip (<# #S #>, explicit # digit train, zero ud).
	@OUTPUT=$$(printf '0 123 <# #S #> TYPE\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '123 ok'; then \
		echo "PASS: REPL test 550 — '0 123 <# #S #> TYPE' outputs '123' (decimal round-trip)"; \
	else \
		echo "FAIL: REPL test 550 — expected '123 ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 12345 <# # # # # # #> TYPE\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '12345 ok'; then \
		echo "PASS: REPL test 551 — '0 12345 <# # # # # # #> TYPE' outputs '12345' (five explicit # digits)"; \
	else \
		echo "FAIL: REPL test 551 — expected '12345 ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 0 <# #S #> TYPE\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0 ok'; then \
		echo "PASS: REPL test 552 — '0 0 <# #S #> TYPE' outputs '0' (AC #4: #S emits >=1 digit for 0. 0.)"; \
	else \
		echo "FAIL: REPL test 552 — expected '0 ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Base-switching coverage: decimal / HEX / binary / octal / base-36.
	@OUTPUT=$$(printf 'DECIMAL 0 65535 <# #S #> TYPE\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '65535 ok'; then \
		echo "PASS: REPL test 553 — base 10: '0 65535 <# #S #> TYPE' outputs '65535'"; \
	else \
		echo "FAIL: REPL test 553 — expected '65535 ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Literals are parsed in DECIMAL then printed in the target base.
	@OUTPUT=$$(printf 'DECIMAL 0 65535 HEX <# #S #> TYPE DECIMAL\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'FFFF ok'; then \
		echo "PASS: REPL test 554 — base 16: '0 65535 <# #S #> TYPE' outputs 'FFFF'"; \
	else \
		echo "FAIL: REPL test 554 — expected 'FFFF ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'DECIMAL 0 255 2 BASE ! <# #S #> TYPE DECIMAL\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '11111111 ok'; then \
		echo "PASS: REPL test 555 — base 2: '0 255 <# #S #> TYPE' outputs '11111111'"; \
	else \
		echo "FAIL: REPL test 555 — expected '11111111 ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'DECIMAL 0 511 8 BASE ! <# #S #> TYPE DECIMAL\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '777 ok'; then \
		echo "PASS: REPL test 556 — base 8: '0 511 <# #S #> TYPE' outputs '777'"; \
	else \
		echo "FAIL: REPL test 556 — expected '777 ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'DECIMAL 0 35 36 BASE ! <# #S #> TYPE DECIMAL\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'Z ok'; then \
		echo "PASS: REPL test 557 — base 36: '0 35 <# #S #> TYPE' outputs 'Z' (verifies digit_to_char A-Z branch)"; \
	else \
		echo "FAIL: REPL test 557 — expected 'Z ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# SIGN via canonical signed-double recipe: SWAP OVER DABS <# #S ROT SIGN #> TYPE.
	@OUTPUT=$$(printf -- '-1 S>D SWAP OVER DABS <# #S ROT SIGN #> TYPE\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-1 ok'; then \
		echo "PASS: REPL test 558 — '-1 S>D ... SIGN #> TYPE' outputs '-1' (SIGN emits '-' for negative)"; \
	else \
		echo "FAIL: REPL test 558 — expected '-1 ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '5 S>D SWAP OVER DABS <# #S ROT SIGN #> TYPE\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '5 ok'; then \
		echo "PASS: REPL test 559 — '5 S>D ... SIGN #> TYPE' outputs '5' (SIGN emits nothing for non-negative)"; \
	else \
		echo "FAIL: REPL test 559 — expected '5 ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-12345 S>D SWAP OVER DABS <# #S ROT SIGN #> TYPE\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-12345 ok'; then \
		echo "PASS: REPL test 560 — '-12345 S>D ... SIGN #> TYPE' outputs '-12345'"; \
	else \
		echo "FAIL: REPL test 560 — expected '-12345 ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# HOLD explicit non-digit character: builds "1,23" right-to-left.
	@OUTPUT=$$(printf '0 123 <# # # 44 HOLD #S #> TYPE\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '1,23 ok'; then \
		echo "PASS: REPL test 561 — '0 123 <# # # 44 HOLD #S #> TYPE' outputs '1,23' (HOLD inserts non-digit ',' = 44)"; \
	else \
		echo "FAIL: REPL test 561 — expected '1,23 ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# HOLDS string insertion preserves left-to-right order.
	@OUTPUT=$$(printf ': PICT-ABC S" abc" HOLDS ;\r\n0 99 <# #S PICT-ABC #> TYPE\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'abc99 ok'; then \
		echo "PASS: REPL test 562 — HOLDS inserts 'abc' before '99' → 'abc99' (left-to-right order preserved)"; \
	else \
		echo "FAIL: REPL test 562 — expected 'abc99 ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Worst case: double \$$FFFFFFFF printed in base 10, HEX, binary (32-char output in 40-byte budget).
	@OUTPUT=$$(printf -- '-1 -1 <# #S #> TYPE\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '4294967295 ok'; then \
		echo "PASS: REPL test 563 — '-1 -1 <# #S #> TYPE' outputs '4294967295' (ud = \$$FFFFFFFF in base 10)"; \
	else \
		echo "FAIL: REPL test 563 — expected '4294967295 ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- 'DECIMAL -1 -1 HEX <# #S #> TYPE DECIMAL\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'FFFFFFFF ok'; then \
		echo "PASS: REPL test 564 — HEX '-1 -1 <# #S #> TYPE' outputs 'FFFFFFFF' (8-char worst case)"; \
	else \
		echo "FAIL: REPL test 564 — expected 'FFFFFFFF ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- 'DECIMAL -1 -1 2 BASE ! <# #S #> TYPE DECIMAL\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '11111111111111111111111111111111 ok'; then \
		echo "PASS: REPL test 565 — base 2 '-1 -1 <# #S #> TYPE' outputs 32 '1's (32-char worst case in 40-byte buffer)"; \
	else \
		echo "FAIL: REPL test 565 — expected 32 '1's and ok in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Buffer overflow diagnostic: 41 HOLDs exceed 40-byte buffer, fires -17 THROW (Story 11.6).
	@OUTPUT=$$(printf ': OV41 0 0 <# 41 0 DO 65 HOLD LOOP #> TYPE ;\r\nOV41\r\n1 2 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -17: pictured numeric output string overflow' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 566 — 41 HOLDs trigger error -17, REPL recovers cleanly (Story 11.6)"; \
	else \
		echo "FAIL: REPL test 566 — expected 'error -17: pictured numeric output string overflow' and '3 ' after recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Underflow recovery: one per primitive whose minimum depth > 0.
	@OUTPUT=$$(printf '1 #\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 567 — '1 #' (DEPTH 1, needs 2) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 567 — expected 'error -4: stack underflow' and 'ok' for '1 #'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 #S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 568 — '1 #S' (DEPTH 1, needs 2) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 568 — expected 'error -4: stack underflow' and 'ok' for '1 #S'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 #>\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 569 — '1 #>' (DEPTH 1, needs 2) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 569 — expected 'error -4: stack underflow' and 'ok' for '1 #>'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'HOLD\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 570 — 'HOLD' (DEPTH 0, needs 1) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 570 — expected 'error -4: stack underflow' and 'ok' for 'HOLD'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'SIGN\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 571 — 'SIGN' (DEPTH 0, needs 1) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 571 — expected 'error -4: stack underflow' and 'ok' for 'SIGN'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 HOLDS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 572 — '1 HOLDS' (DEPTH 1, needs 2) underflows and recovers"; \
	else \
		echo "FAIL: REPL test 572 — expected 'error -4: stack underflow' and 'ok' for '1 HOLDS'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- Story 10.7 review-pass additions (573..578): HLD smoke, HOLDS u=0/1, digit_to_char A-Z mid-range ---
	@# HLD user-variable smoke: <# is idempotent — two consecutive <# yield the same HLD.
	@# (Story 10.8 rewrote U./. on pictured foundation, so the startup banner's U. now
	@#  mutates HLD; the test's original 'cold-start init == <# reset' form no longer
	@#  holds. The <#-idempotent invariant it was really checking still does.)
	@OUTPUT=$$(printf '<# HLD @ <# HLD @ = .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '\-1[ ]+ok'; then \
		echo "PASS: REPL test 573 — HLD user-variable readable; <# is idempotent"; \
	else \
		echo "FAIL: REPL test 573 — expected '-1 ok' for '<# HLD @ <# HLD @ = .'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# HOLDS u=0: empty-string is a no-op; pictured output unchanged.
	@OUTPUT=$$(printf '0 99 <# #S HERE 0 HOLDS #> TYPE\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '99 ok'; then \
		echo "PASS: REPL test 574 — 'HERE 0 HOLDS' (u=0) is a no-op; output unchanged"; \
	else \
		echo "FAIL: REPL test 574 — expected '99 ok' for HOLDS u=0 path"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# HOLDS u=1: single iteration writes one char then exits.
	@OUTPUT=$$(printf ': PICT-X S" X" HOLDS ;\r\n0 99 <# #S PICT-X #> TYPE\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'X99 ok'; then \
		echo "PASS: REPL test 575 — HOLDS (u=1) inserts single char before '99' → 'X99'"; \
	else \
		echo "FAIL: REPL test 575 — expected 'X99 ok' for HOLDS u=1 path"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# digit_to_char A-Z mid-range: catches off-by-one in 'ADD A,"A"-10'.
	@OUTPUT=$$(printf 'DECIMAL 0 10 36 BASE ! <# #S #> TYPE DECIMAL\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'A ok'; then \
		echo "PASS: REPL test 576 — base 36 digit 10 → 'A' (digit_to_char A-Z lower bound)"; \
	else \
		echo "FAIL: REPL test 576 — expected 'A ok' for base-36 digit 10"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'DECIMAL 0 19 36 BASE ! <# #S #> TYPE DECIMAL\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'J ok'; then \
		echo "PASS: REPL test 577 — base 36 digit 19 → 'J' (digit_to_char A-Z mid-range)"; \
	else \
		echo "FAIL: REPL test 577 — expected 'J ok' for base-36 digit 19"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'DECIMAL 0 25 36 BASE ! <# #S #> TYPE DECIMAL\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'P ok'; then \
		echo "PASS: REPL test 578 — base 36 digit 25 → 'P' (digit_to_char A-Z mid-range)"; \
	else \
		echo "FAIL: REPL test 578 — expected 'P ok' for base-36 digit 25"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- Story 10.8 number-output on pictured foundation (579..614) ---
	@# `.` regression block (AC #1, #14a) — byte-for-byte parity with pre-10.8.
	@OUTPUT=$$(printf '0 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^0  ok'; then \
		echo "PASS: REPL test 579 — '0 .' → '0 ' (free-field signed, base 10)"; \
	else \
		echo "FAIL: REPL test 579 — expected '0  ok' for '0 .'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1234 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^1234  ok'; then \
		echo "PASS: REPL test 580 — '1234 .' → '1234 ' (free-field signed, base 10)"; \
	else \
		echo "FAIL: REPL test 580 — expected '1234  ok' for '1234 .'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-5 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^-5  ok'; then \
		echo "PASS: REPL test 581 — '-5 .' → '-5 ' (negative signed)"; \
	else \
		echo "FAIL: REPL test 581 — expected '-5  ok' for '-5 .'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '32767 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^32767  ok'; then \
		echo "PASS: REPL test 582 — '32767 .' → '32767 ' (INT16_MAX)"; \
	else \
		echo "FAIL: REPL test 582 — expected '32767  ok' for '32767 .'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-32768 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^-32768  ok'; then \
		echo "PASS: REPL test 583 — '-32768 .' → '-32768 ' (INT16_MIN single-cell corner)"; \
	else \
		echo "FAIL: REPL test 583 — expected '-32768  ok' for '-32768 .'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '255 HEX . DECIMAL\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^FF  ok'; then \
		echo "PASS: REPL test 584 — '255 HEX . DECIMAL' → 'FF ' (HEX discipline)"; \
	else \
		echo "FAIL: REPL test 584 — expected 'FF  ok' for '255 HEX . DECIMAL'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# `U.` regression block (AC #1, #14b).
	@OUTPUT=$$(printf '0 U.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^0  ok'; then \
		echo "PASS: REPL test 585 — '0 U.' → '0 '"; \
	else \
		echo "FAIL: REPL test 585 — expected '0  ok' for '0 U.'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1234 U.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^1234  ok'; then \
		echo "PASS: REPL test 586 — '1234 U.' → '1234 '"; \
	else \
		echo "FAIL: REPL test 586 — expected '1234  ok' for '1234 U.'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# U. with 65535 must print '65535 ' — if E10-D1 SWAP order is wrong it becomes '4294901760 '.
	@OUTPUT=$$(printf '65535 U.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^65535  ok'; then \
		echo "PASS: REPL test 587 — '65535 U.' → '65535 ' (UINT16_MAX; E10-D1 SWAP order sanity)"; \
	else \
		echo "FAIL: REPL test 587 — expected '65535  ok' for '65535 U.'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '65535 HEX U. DECIMAL\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^FFFF  ok'; then \
		echo "PASS: REPL test 588 — '65535 HEX U. DECIMAL' → 'FFFF '"; \
	else \
		echo "FAIL: REPL test 588 — expected 'FFFF  ok' for '65535 HEX U. DECIMAL'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# `.R` regression block incl. no-truncation (AC #3, #14c).
	@OUTPUT=$$(printf '42 10 .R\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^        42 ok'; then \
		echo "PASS: REPL test 589 — '42 10 .R' → 8 spaces + '42' (right-aligned)"; \
	else \
		echo "FAIL: REPL test 589 — expected '        42 ok' for '42 10 .R'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-5 10 .R\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^        -5 ok'; then \
		echo "PASS: REPL test 590 — '-5 10 .R' → 8 spaces + '-5'"; \
	else \
		echo "FAIL: REPL test 590 — expected '        -5 ok' for '-5 10 .R'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# .R no-truncation per §6.2.0210: when u > +n, emit all digits without leading pad.
	@OUTPUT=$$(printf '1234 3 .R\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^1234 ok'; then \
		echo "PASS: REPL test 591 — '1234 3 .R' → '1234' no-truncation (AC #3, §6.2.0210)"; \
	else \
		echo "FAIL: REPL test 591 — expected '1234 ok' for '1234 3 .R' (no truncation)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 0 .R\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^0 ok'; then \
		echo "PASS: REPL test 592 — '0 0 .R' → '0' (zero width, single digit)"; \
	else \
		echo "FAIL: REPL test 592 — expected '0 ok' for '0 0 .R'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# `D.` block incl. INT_MIN corner (AC #6, #14d, #15).
	@OUTPUT=$$(printf '0 0 D.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^0  ok'; then \
		echo "PASS: REPL test 593 — '0 0 D.' → '0 '"; \
	else \
		echo "FAIL: REPL test 593 — expected '0  ok' for '0 0 D.'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Worst-case signed double: -1 -1 represents signed -1 (d = $FFFFFFFF). SIGN must fire on hi.
	@OUTPUT=$$(printf -- '-1 -1 D.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^-1  ok'; then \
		echo "PASS: REPL test 594 — '-1 -1 D.' → '-1 ' (E10-D1 high-cell-drives-SIGN)"; \
	else \
		echo "FAIL: REPL test 594 — expected '-1  ok' for '-1 -1 D.'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# hi=0, lo=-1 → unsigned double = 65535. Catches E10-D1 confusion — hi NOT on TOS.
	@OUTPUT=$$(printf '0 -1 D.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^65535  ok'; then \
		echo "PASS: REPL test 595 — '0 -1 D.' → '65535 ' (hi=0, lo=-1; low-on-TOS sanity)"; \
	else \
		echo "FAIL: REPL test 595 — expected '65535  ok' for '0 -1 D.'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 -1 HEX D. DECIMAL\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^FFFF  ok'; then \
		echo "PASS: REPL test 596 — '0 -1 HEX D. DECIMAL' → 'FFFF '"; \
	else \
		echo "FAIL: REPL test 596 — expected 'FFFF  ok' for '0 -1 HEX D. DECIMAL'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# INT_MIN corner (AC #15): double $$80000000 = hi=32768 lo=0; DABS leaves it unchanged, SIGN still fires on hi.
	@OUTPUT=$$(printf '32768 0 D.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^-2147483648  ok'; then \
		echo "PASS: REPL test 597 — '32768 0 D.' → '-2147483648 ' (INT_MIN; DABS(\$$80000000) fixed-point)"; \
	else \
		echo "FAIL: REPL test 597 — expected '-2147483648  ok' for '32768 0 D.'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# `U.R` block (AC #14e).
	@OUTPUT=$$(printf '42 10 U.R\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^        42 ok'; then \
		echo "PASS: REPL test 598 — '42 10 U.R' → 8 spaces + '42'"; \
	else \
		echo "FAIL: REPL test 598 — expected '        42 ok' for '42 10 U.R'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '65535 10 U.R\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^     65535 ok'; then \
		echo "PASS: REPL test 599 — '65535 10 U.R' → 5 spaces + '65535' (E10-D1 sanity)"; \
	else \
		echo "FAIL: REPL test 599 — expected '     65535 ok' for '65535 10 U.R'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# `D.R` block (AC #14f).
	@OUTPUT=$$(printf '0 0 10 D.R\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^         0 ok'; then \
		echo "PASS: REPL test 600 — '0 0 10 D.R' → 9 spaces + '0'"; \
	else \
		echo "FAIL: REPL test 600 — expected '         0 ok' for '0 0 10 D.R'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 -1 10 D.R\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^        -1 ok'; then \
		echo "PASS: REPL test 601 — '-1 -1 10 D.R' → 8 spaces + '-1'"; \
	else \
		echo "FAIL: REPL test 601 — expected '        -1 ok' for '-1 -1 10 D.R'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# D.R no-truncation edge: +n=0, single-digit string.
	@OUTPUT=$$(printf -- '-1 -1 0 D.R\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^-1 ok'; then \
		echo "PASS: REPL test 602 — '-1 -1 0 D.R' → '-1' no-truncation"; \
	else \
		echo "FAIL: REPL test 602 — expected '-1 ok' for '-1 -1 0 D.R'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Pictured-path explicit (AC #14g) — proves `.`'s factoring reaches pictured output.
	@OUTPUT=$$(printf ': DOT-VIA-PICT S>D OVER >R DABS <# #S R> SIGN #> TYPE SPACE ;\r\n1234 DOT-VIA-PICT\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^1234  ok'; then \
		echo "PASS: REPL test 603 — DOT-VIA-PICT (user pictured recipe) yields byte-identical '1234 '"; \
	else \
		echo "FAIL: REPL test 603 — expected '1234  ok' for '1234 DOT-VIA-PICT'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Early-binding HOLD-redefinition (AC #8, #14h).
	@OUTPUT=$$(printf ': HOLD DROP ;\r\n42 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^42  ok'; then \
		echo "PASS: REPL test 604 — ': HOLD DROP ; 42 .' → '42 ' (early binding; user HOLD redef ignored)"; \
	else \
		echo "FAIL: REPL test 604 — expected '42  ok' for ': HOLD DROP ; 42 .'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# .S preservation smoke (AC #7, #14i) — u_to_str / num_buf / emit_unsigned kept alive.
	@OUTPUT=$$(printf '1 2 3 .S\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '<3> 1 2 3  ok'; then \
		echo "PASS: REPL test 605 — '1 2 3 .S' → '<3> 1 2 3 ' (.S preserved; helpers kept)"; \
	else \
		echo "FAIL: REPL test 605 — expected '<3> 1 2 3  ok' for '1 2 3 .S'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Underflow-parity block (AC #9, #14j) — factor chain guards trip before pictured state mutates.
	@OUTPUT=$$(printf '.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 606 — '.' (DEPTH 0) underflows and REPL recovers"; \
	else \
		echo "FAIL: REPL test 606 — expected 'error -4: stack underflow' and 'ok' for '.'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'U.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 607 — 'U.' (DEPTH 0) underflows and REPL recovers"; \
	else \
		echo "FAIL: REPL test 607 — expected 'error -4: stack underflow' and 'ok' for 'U.'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'D.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 608 — 'D.' (DEPTH 0, needs 2) underflows and REPL recovers"; \
	else \
		echo "FAIL: REPL test 608 — expected 'error -4: stack underflow' and 'ok' for 'D.'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 .R\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 609 — '1 .R' (DEPTH 1, needs 2) underflows and REPL recovers"; \
	else \
		echo "FAIL: REPL test 609 — expected 'error -4: stack underflow' and 'ok' for '1 .R'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 U.R\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 610 — '1 U.R' (DEPTH 1, needs 2) underflows and REPL recovers"; \
	else \
		echo "FAIL: REPL test 610 — expected 'error -4: stack underflow' and 'ok' for '1 U.R'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 1 D.R\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 611 — '1 1 D.R' (DEPTH 2, needs 3) underflows and REPL recovers"; \
	else \
		echo "FAIL: REPL test 611 — expected 'error -4: stack underflow' and 'ok' for '1 1 D.R'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Review follow-ups: D.R × INT_MIN, D. typical positive, .R negative-width.
	@# D.R INT_MIN corner (width=15): exercises DABS($$80000000) + SIGN + width-arith together.
	@OUTPUT=$$(printf '32768 0 15 D.R\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^    -2147483648 ok'; then \
		echo "PASS: REPL test 612 — '32768 0 15 D.R' → 4 spaces + '-2147483648' (INT_MIN × right-align)"; \
	else \
		echo "FAIL: REPL test 612 — expected '    -2147483648 ok' for '32768 0 15 D.R'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# D. typical positive value — complements the edge-heavy 593..597 block.
	@OUTPUT=$$(printf '0 12345 D.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^12345  ok'; then \
		echo "PASS: REPL test 613 — '0 12345 D.' → '12345 ' (typical positive double)"; \
	else \
		echo "FAIL: REPL test 613 — expected '12345  ok' for '0 12345 D.'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# .R with negative width: DPANS94 specifies +n; implementation no-ops via SPACES(-n),
	@# emitting digits with no padding and no truncation. Sanity gate on unspecified input.
	@OUTPUT=$$(printf -- '42 -5 .R\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^42 ok'; then \
		echo "PASS: REPL test 614 — '42 -5 .R' → '42' (negative width: SPACES no-ops, no truncation)"; \
	else \
		echo "FAIL: REPL test 614 — expected '42 ok' for '42 -5 .R'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- Story 10.9 remaining Core gap words (615..650) — DPANS94 §6.1.{0100,0110,1345,1360} ---
	@# `*/` block: signed pair, negative input, trunc-toward-zero, and the canonical
	@# 32767×32767/32767=32767 overflow-trap (would be 0 if implementation used single-cell *).
	@OUTPUT=$$(printf '10 20 5 */ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^40  ok'; then \
		echo "PASS: REPL test 615 — '10 20 5 */' → 40 (canonical signed)"; \
	else \
		echo "FAIL: REPL test 615 — expected '40  ok' for '10 20 5 */'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-10 20 5 */ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^-40  ok'; then \
		echo "PASS: REPL test 616 — '-10 20 5 */' → -40 (negative input, signed)"; \
	else \
		echo "FAIL: REPL test 616 — expected '-40  ok' for '-10 20 5 */'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '7 3 2 */ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^10  ok'; then \
		echo "PASS: REPL test 617 — '7 3 2 */' → 10 (21/2 truncated toward zero)"; \
	else \
		echo "FAIL: REPL test 617 — expected '10  ok' for '7 3 2 */'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Double-intermediate overflow trap: 32767*32767 = 1073676289 (32-bit), /32767 = 32767.
	@# Naive single-cell `*` would give 32767*32767 mod 65536 = 1, then 1/32767 = 0.
	@OUTPUT=$$(printf '32767 32767 32767 */ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^32767  ok'; then \
		echo "PASS: REPL test 618 — '32767 32767 32767 */' → 32767 (double-intermediate overflow trap)"; \
	else \
		echo "FAIL: REPL test 618 — expected '32767  ok' for '32767 32767 32767 */'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# `*/MOD` block: ( n1 n2 n3 -- rem quot ) with quot on TOS. Probe with `. .` →
	@# prints quot then rem (TOS-first).
	@OUTPUT=$$(printf '10 20 6 */MOD . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^33 2  ok'; then \
		echo "PASS: REPL test 619 — '10 20 6 */MOD' → ( 2 33 ) — rem 2, quot 33"; \
	else \
		echo "FAIL: REPL test 619 — expected '33 2  ok' for '10 20 6 */MOD . .'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '17 3 5 */MOD . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^10 1  ok'; then \
		echo "PASS: REPL test 620 — '17 3 5 */MOD' → ( 1 10 ) — rem 1, quot 10"; \
	else \
		echo "FAIL: REPL test 620 — expected '10 1  ok' for '17 3 5 */MOD . .'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Symmetric-remainder sign trap: -17*3/5 = -51/5; symmetric (truncated toward zero)
	@# gives quot=-10, rem=-1 (rem sign matches dividend). Floored would give 2,-11 — wrong.
	@OUTPUT=$$(printf -- '-17 3 5 */MOD . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^-10 -1  ok'; then \
		echo "PASS: REPL test 621 — '-17 3 5 */MOD' → ( -1 -10 ) — symmetric remainder sign = dividend"; \
	else \
		echo "FAIL: REPL test 621 — expected '-10 -1  ok' for '-17 3 5 */MOD . .'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# `EVALUATE` block: simplest, multi-word, TIB restoration, nested via colon, empty string.
	@OUTPUT=$$(printf 'S" 10 20 +" EVALUATE .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^30  ok'; then \
		echo "PASS: REPL test 622 — 'S\" 10 20 +\" EVALUATE' → 30"; \
	else \
		echo "FAIL: REPL test 622 — expected '30  ok' for 'S\" 10 20 +\" EVALUATE .'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'S" 2 3 * 4 +" EVALUATE .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^10  ok'; then \
		echo "PASS: REPL test 623 — 'S\" 2 3 * 4 +\" EVALUATE' → 10 (operator precedence inside string)"; \
	else \
		echo "FAIL: REPL test 623 — expected '10  ok' for 'S\" 2 3 * 4 +\" EVALUATE .'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# TIB-restoration smoke: post-EVALUATE, the rest of the line ('7 + .') must parse
	@# from the original REPL TIB, not from the evaluated string. 99 + 7 = 106.
	@OUTPUT=$$(printf 'S" 99" EVALUATE 7 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^106  ok'; then \
		echo "PASS: REPL test 624 — 'S\" 99\" EVALUATE 7 + .' → 106 (TIB restored after EVALUATE)"; \
	else \
		echo "FAIL: REPL test 624 — expected '106  ok' for TIB-restoration probe"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Nested EVALUATE via colon definition (antforth lacks Forth-2014 S\"). Exercises
	@# rstack save/restore under LIFO discipline.
	@OUTPUT=$$(printf ': __E910I S" 32" EVALUATE ;\r\nS" 10 __E910I +" EVALUATE .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^42  ok'; then \
		echo "PASS: REPL test 625 — nested EVALUATE → 42 (10 + 32; rstack LIFO save/restore)"; \
	else \
		echo "FAIL: REPL test 625 — expected '42  ok' for nested EVALUATE"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Empty string: INTERPRET's WORD/C@ loop returns via .interp_done without parse error.
	@OUTPUT=$$(printf 'S" " EVALUATE 99 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^99  ok'; then \
		echo "PASS: REPL test 626 — 'S\" \" EVALUATE 99 .' → 99 (empty string completes cleanly)"; \
	else \
		echo "FAIL: REPL test 626 — expected '99  ok' for empty-string EVALUATE"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# `ENVIRONMENT?` block: 14 standard keys per DPANS94 §3.2.6, plus unknown-key
	@# (returns single-cell false) and case-sensitivity (lowercase 'core' → false).
	@# Probe `. .` prints TOS-first → "-1 VALUE" (true flag, then value).
	@OUTPUT=$$(printf 'S" /COUNTED-STRING" ENVIRONMENT? . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^-1 255  ok'; then \
		echo "PASS: REPL test 627 — 'S\" /COUNTED-STRING\" ENVIRONMENT?' → ( 255 -1 )"; \
	else \
		echo "FAIL: REPL test 627 — expected '-1 255  ok' for /COUNTED-STRING"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'S" /HOLD" ENVIRONMENT? . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^-1 40  ok'; then \
		echo "PASS: REPL test 628 — 'S\" /HOLD\" ENVIRONMENT?' → ( 40 -1 ) — PIC_BUF_SIZE"; \
	else \
		echo "FAIL: REPL test 628 — expected '-1 40  ok' for /HOLD"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'S" /PAD" ENVIRONMENT? . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^-1 84  ok'; then \
		echo "PASS: REPL test 629 — 'S\" /PAD\" ENVIRONMENT?' → ( 84 -1 ) — PAD_OFFSET"; \
	else \
		echo "FAIL: REPL test 629 — expected '-1 84  ok' for /PAD"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'S" ADDRESS-UNIT-BITS" ENVIRONMENT? . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^-1 8  ok'; then \
		echo "PASS: REPL test 630 — 'S\" ADDRESS-UNIT-BITS\" ENVIRONMENT?' → ( 8 -1 )"; \
	else \
		echo "FAIL: REPL test 630 — expected '-1 8  ok' for ADDRESS-UNIT-BITS"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'S" CORE" ENVIRONMENT? . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^-1 -1  ok'; then \
		echo "PASS: REPL test 631 — 'S\" CORE\" ENVIRONMENT?' → ( true true ) — 133/133 §6.1 Core"; \
	else \
		echo "FAIL: REPL test 631 — expected '-1 -1  ok' for CORE"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'S" CORE-EXT" ENVIRONMENT? . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^-1 0  ok'; then \
		echo "PASS: REPL test 632 — 'S\" CORE-EXT\" ENVIRONMENT?' → ( false true ) — partial §6.2"; \
	else \
		echo "FAIL: REPL test 632 — expected '-1 0  ok' for CORE-EXT"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'S" FLOORED" ENVIRONMENT? . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^-1 0  ok'; then \
		echo "PASS: REPL test 633 — 'S\" FLOORED\" ENVIRONMENT?' → ( false true ) — symmetric / not floored"; \
	else \
		echo "FAIL: REPL test 633 — expected '-1 0  ok' for FLOORED"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'S" MAX-CHAR" ENVIRONMENT? . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^-1 255  ok'; then \
		echo "PASS: REPL test 634 — 'S\" MAX-CHAR\" ENVIRONMENT?' → ( 255 -1 )"; \
	else \
		echo "FAIL: REPL test 634 — expected '-1 255  ok' for MAX-CHAR"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# MAX-D: stack ( hi lo true ) per E10-D1 (lo on TOS, hi second, true newly on top).
	@# Probe '. . .' is TOS-first so it prints true, lo, hi → "-1 -1 32767" since
	@# lo=$$FFFF=-1, hi=$$7FFF=32767, flag=$$FFFF=-1.
	@OUTPUT=$$(printf 'S" MAX-D" ENVIRONMENT? . . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^-1 -1 32767  ok'; then \
		echo "PASS: REPL test 635 — 'S\" MAX-D\" ENVIRONMENT?' → ( 32767 -1 -1 ) — E10-D1 lo-on-TOS for double"; \
	else \
		echo "FAIL: REPL test 635 — expected '-1 -1 32767  ok' for MAX-D"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'S" MAX-N" ENVIRONMENT? . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^-1 32767  ok'; then \
		echo "PASS: REPL test 636 — 'S\" MAX-N\" ENVIRONMENT?' → ( 32767 -1 )"; \
	else \
		echo "FAIL: REPL test 636 — expected '-1 32767  ok' for MAX-N"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'S" MAX-U" ENVIRONMENT? . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^-1 -1  ok'; then \
		echo "PASS: REPL test 637 — 'S\" MAX-U\" ENVIRONMENT?' → ( -1 -1 ) — 65535 unsigned shows as -1 signed"; \
	else \
		echo "FAIL: REPL test 637 — expected '-1 -1  ok' for MAX-U"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'S" MAX-UD" ENVIRONMENT? . . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^-1 -1 -1  ok'; then \
		echo "PASS: REPL test 638 — 'S\" MAX-UD\" ENVIRONMENT?' → ( -1 -1 -1 ) — double 4294967295"; \
	else \
		echo "FAIL: REPL test 638 — expected '-1 -1 -1  ok' for MAX-UD"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'S" RETURN-STACK-CELLS" ENVIRONMENT? . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^-1 128  ok'; then \
		echo "PASS: REPL test 639 — 'S\" RETURN-STACK-CELLS\" ENVIRONMENT?' → ( 128 -1 ) — RS_SIZE/2"; \
	else \
		echo "FAIL: REPL test 639 — expected '-1 128  ok' for RETURN-STACK-CELLS"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'S" STACK-CELLS" ENVIRONMENT? . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^-1 128  ok'; then \
		echo "PASS: REPL test 640 — 'S\" STACK-CELLS\" ENVIRONMENT?' → ( 128 -1 ) — PS_SIZE/2"; \
	else \
		echo "FAIL: REPL test 640 — expected '-1 128  ok' for STACK-CELLS"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Unknown key returns single-cell false (no i*x). Probe `.` → "0 ".
	@OUTPUT=$$(printf 'S" XYZZY" ENVIRONMENT? .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^0  ok'; then \
		echo "PASS: REPL test 641 — 'S\" XYZZY\" ENVIRONMENT?' → ( 0 ) — unknown key returns single-cell false"; \
	else \
		echo "FAIL: REPL test 641 — expected '0  ok' for unknown key XYZZY"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Case-sensitivity per DPANS94 §3.2.6: 'core' ≠ 'CORE'.
	@OUTPUT=$$(printf 'S" core" ENVIRONMENT? .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^0  ok'; then \
		echo "PASS: REPL test 642 — 'S\" core\" ENVIRONMENT?' → ( 0 ) — case-sensitive (lowercase not found)"; \
	else \
		echo "FAIL: REPL test 642 — expected '0  ok' for lowercase 'core'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Underflow recovery (AC #10). All four words guard at entry; ABORT resets stacks
	@# and REPL re-prompts. For */ and */MOD the chain via M*'s 2DUP guard provides
	@# the effective 3-cell guard.
	@OUTPUT=$$(printf '*/\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 643 — '*/' (DEPTH 0, needs 3) underflows and REPL recovers"; \
	else \
		echo "FAIL: REPL test 643 — expected 'error -4: stack underflow' and 'ok' for '*/'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 2 */\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 644 — '1 2 */' (DEPTH 2, needs 3) underflows and REPL recovers"; \
	else \
		echo "FAIL: REPL test 644 — expected 'error -4: stack underflow' and 'ok' for '1 2 */'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '*/MOD\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 645 — '*/MOD' (DEPTH 0, needs 3) underflows and REPL recovers"; \
	else \
		echo "FAIL: REPL test 645 — expected 'error -4: stack underflow' and 'ok' for '*/MOD'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 2 */MOD\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 646 — '1 2 */MOD' (DEPTH 2, needs 3) underflows and REPL recovers"; \
	else \
		echo "FAIL: REPL test 646 — expected 'error -4: stack underflow' and 'ok' for '1 2 */MOD'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'EVALUATE\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 647 — 'EVALUATE' (DEPTH 0, needs 2) underflows and REPL recovers"; \
	else \
		echo "FAIL: REPL test 647 — expected 'error -4: stack underflow' and 'ok' for 'EVALUATE'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 EVALUATE\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 648 — '1 EVALUATE' (DEPTH 1, needs 2) underflows and REPL recovers"; \
	else \
		echo "FAIL: REPL test 648 — expected 'error -4: stack underflow' and 'ok' for '1 EVALUATE'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'ENVIRONMENT?\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 649 — 'ENVIRONMENT?' (DEPTH 0, needs 2) underflows and REPL recovers"; \
	else \
		echo "FAIL: REPL test 649 — expected 'error -4: stack underflow' and 'ok' for 'ENVIRONMENT?'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 ENVIRONMENT?\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'error -4: stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 650 — '1 ENVIRONMENT?' (DEPTH 1, needs 2) underflows and REPL recovers"; \
	else \
		echo "FAIL: REPL test 650 — expected 'error -4: stack underflow' and 'ok' for '1 ENVIRONMENT?'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- Story 11.4: div-by-zero migrated to THROW -10 (DPANS94 §6.1.0100/§6.1.0110) ---
	@# `*/` and `*/MOD` funnel through UM/MOD; Story 11.4's divisor-zero guard at
	@# UM/MOD raises -10 THROW for any zero divisor. Tests 651 / 652 (originally
	@# Story 10.9 review follow-ups documenting the silent-garbage baseline) are
	@# repurposed here to assert the post-migration uncaught-recovery diagnostic.
	@OUTPUT=$$(printf '1 1 0 */\r\nDEPTH .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -10: division by zero.*0  ok'; then \
		echo "PASS: REPL test 651 — '1 1 0 */' raises -10 THROW (Story 11.4 UM/MOD guard); REPL recovers, post-recovery DEPTH=0"; \
	else \
		echo "FAIL: REPL test 651 — expected 'error -10: division by zero' + post-recovery '0  ok' for '1 1 0 */'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 1 0 */MOD\r\nDEPTH .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -10: division by zero.*0  ok'; then \
		echo "PASS: REPL test 652 — '1 1 0 */MOD' raises -10 THROW (Story 11.4 UM/MOD guard); REPL recovers, post-recovery DEPTH=0"; \
	else \
		echo "FAIL: REPL test 652 — expected 'error -10: division by zero' + post-recovery '0  ok' for '1 1 0 */MOD'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- Story 11.2 — CATCH (normal-return) per Forth 2014 / ANS Forth 1994 §9.6.1.0875 ---
	@# Tests cover: pure / producing / consuming xts (AC #13/AC #14), CATCH-TOP
	@# preservation (AC #17), nested CATCH frames (AC #13), state-integrity
	@# invariants (AC #15), empty-stack ABORT path (AC #3 / AC #18). THROW-side
	@# tests land in Story 11.3.
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": NOOP ;" "' NOOP CATCH ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0  ok'; then \
		echo "PASS: REPL test 653 — \"' NOOP CATCH .\" returns success code 0"; \
	else \
		echo "FAIL: REPL test 653 — expected '0  ok' for \"' NOOP CATCH .\""; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": DUP-DROP DUP DROP ;" "5 ' DUP-DROP CATCH . ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0 5  ok'; then \
		echo "PASS: REPL test 654 — \"5 ' DUP-DROP CATCH . .\" preserves NOS, returns 0"; \
	else \
		echo "FAIL: REPL test 654 — expected '0 5  ok' for \"5 ' DUP-DROP CATCH . .\""; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": MAKE-42 42 ;" "' MAKE-42 CATCH . ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0 42  ok'; then \
		echo "PASS: REPL test 655 — \"' MAKE-42 CATCH . .\" producing xt + success code"; \
	else \
		echo "FAIL: REPL test 655 — expected '0 42  ok' for \"' MAKE-42 CATCH . .\""; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": MAKE-1-2 1 2 ;" "' MAKE-1-2 CATCH . . ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0 2 1  ok'; then \
		echo "PASS: REPL test 656 — \"' MAKE-1-2 CATCH . . .\" depth-2 producer + success code"; \
	else \
		echo "FAIL: REPL test 656 — expected '0 2 1  ok' for \"' MAKE-1-2 CATCH . . .\""; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": DROP-IT DROP ;" "5 ' DROP-IT CATCH ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0  ok'; then \
		echo "PASS: REPL test 657 — \"5 ' DROP-IT CATCH .\" consuming xt + success code"; \
	else \
		echo "FAIL: REPL test 657 — expected '0  ok' for \"5 ' DROP-IT CATCH .\""; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": ADD-IT + ;" "1 2 ' ADD-IT CATCH . ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0 3  ok'; then \
		echo "PASS: REPL test 658 — \"1 2 ' ADD-IT CATCH . .\" 2-cell consumer + 1 producer"; \
	else \
		echo "FAIL: REPL test 658 — expected '0 3  ok' for \"1 2 ' ADD-IT CATCH . .\""; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "' BL CATCH . ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0 32  ok'; then \
		echo "PASS: REPL test 659 — \"' BL CATCH . .\" DEFCODE xt (BL pushes 32)"; \
	else \
		echo "FAIL: REPL test 659 — expected '0 32  ok' for \"' BL CATCH . .\""; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": BL2 ['] BL EXECUTE ;" "' BL2 CATCH . ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0 32  ok'; then \
		echo "PASS: REPL test 660 — \"' BL2 CATCH . .\" xt that internally calls EXECUTE"; \
	else \
		echo "FAIL: REPL test 660 — expected '0 32  ok' for \"' BL2 CATCH . .\""; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": A 1 ; : B A A + ;" "' B CATCH . ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0 2  ok'; then \
		echo "PASS: REPL test 661 — \"' B CATCH . .\" DEFWORD that calls another DEFWORD"; \
	else \
		echo "FAIL: REPL test 661 — expected '0 2  ok' for \"' B CATCH . .\""; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "1 ' DUP CATCH . . ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0 1 1  ok'; then \
		echo "PASS: REPL test 662 — \"1 ' DUP CATCH . . .\" DEFCODE xt with stack effect"; \
	else \
		echo "FAIL: REPL test 662 — expected '0 1 1  ok' for \"1 ' DUP CATCH . . .\""; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CATCH-TOP @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0  ok'; then \
		echo "PASS: REPL test 663 — 'CATCH-TOP @ .' is 0 at fresh REPL (no enclosing CATCH)"; \
	else \
		echo "FAIL: REPL test 663 — expected '0  ok' for 'CATCH-TOP @ .' at fresh REPL"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": NOOP ;" "' NOOP CATCH . CATCH-TOP @ ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0 0  ok'; then \
		echo "PASS: REPL test 664 — CATCH-TOP restored to entry-time value (0) after CATCH normal return"; \
	else \
		echo "FAIL: REPL test 664 — expected '0 0  ok' for CATCH-TOP-restore test"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": MAKE-42 42 ;" "' MAKE-42 CATCH . . CATCH-TOP @ ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0 42 0  ok'; then \
		echo "PASS: REPL test 665 — CATCH-TOP restored to 0 after producing-xt CATCH"; \
	else \
		echo "FAIL: REPL test 665 — expected '0 42 0  ok' for producing-xt CATCH-TOP test"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": INNER ['] BL CATCH ;" "' INNER CATCH . . ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0 0 32  ok'; then \
		echo "PASS: REPL test 666 — nested CATCH (both normal-return) works correctly"; \
	else \
		echo "FAIL: REPL test 666 — expected '0 0 32  ok' for nested CATCH test"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": PROBE CATCH-TOP @ ;" "' PROBE CATCH . 0= 0= . CATCH-TOP @ ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0 -1 0  ok'; then \
		echo "PASS: REPL test 667 — CATCH-TOP non-zero inside CATCH, restored to 0 after"; \
	else \
		echo "FAIL: REPL test 667 — expected '0 -1 0  ok' for PROBE test"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": NOOP ;" "HEX ' NOOP CATCH DROP BASE @ DECIMAL ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE '\. 16  ok'; then \
		echo "PASS: REPL test 668 — BASE preserved across CATCH normal return (AC #15a)"; \
	else \
		echo "FAIL: REPL test 668 — expected '. 16  ok' (sole result) for BASE-integrity test"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": NOOP ;" "STATE @ ' NOOP CATCH DROP STATE @ = ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-1  ok'; then \
		echo "PASS: REPL test 669 — STATE preserved across CATCH normal return (AC #15b)"; \
	else \
		echo "FAIL: REPL test 669 — expected '-1  ok' for STATE-integrity test"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": NOOP ;" "HERE ' NOOP CATCH DROP HERE = ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-1  ok'; then \
		echo "PASS: REPL test 670 — HERE preserved across CATCH normal return (AC #15c)"; \
	else \
		echo "FAIL: REPL test 670 — expected '-1  ok' for HERE-integrity test"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": NOOP ;" "1 2 3 DEPTH . ' NOOP CATCH DROP DEPTH ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '3 3  ok'; then \
		echo "PASS: REPL test 671 — DEPTH invariant across CATCH normal return (AC #15d)"; \
	else \
		echo "FAIL: REPL test 671 — expected '3 3  ok' for DEPTH-integrity test"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CATCH\r\nCATCH-TOP @ .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -4: stack underflow.* ok.*CATCH-TOP @ \. 0  ok'; then \
		echo "PASS: REPL test 672 — empty-stack 'CATCH' aborts and CATCH-TOP is reset to 0 on recovery (AC #3 / AC #17 / AC #18)"; \
	else \
		echo "FAIL: REPL test 672 — expected 'error -4: stack underflow' + recovery + 'CATCH-TOP @ . 0  ok' (CCD-1 chain reset)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n%s\r\n" ": L1 ['] BL CATCH ;" ": L2 ['] L1 CATCH ;" "' L2 CATCH . . . ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0 0 0 32  ok'; then \
		echo "PASS: REPL test 673 — 3-level nested CATCH exercises non-zero prev-of-prev chain link (AC #13)"; \
	else \
		echo "FAIL: REPL test 673 — expected '0 0 0 32  ok' for 3-level nested CATCH"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 2 0 THROW . .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '2 1  ok'; then \
		echo "PASS: REPL test 674 — Story 11.3: THROW 0 is a no-op, only consumes the zero (AC #3)"; \
	else \
		echo "FAIL: REPL test 674 — expected '2 1  ok' for '1 2 0 THROW . .'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '0 0 THROW .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE '0 0 THROW \. 0  ok'; then \
		echo "PASS: REPL test 675 — Story 11.3: THROW 0 with BC=0 from below is a no-op (AC #3)"; \
	else \
		echo "FAIL: REPL test 675 — expected '0  ok' for '0 0 THROW .'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": T1 42 THROW ;" "' T1 CATCH ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '42  ok'; then \
		echo "PASS: REPL test 676 — Story 11.3: caught THROW round-trip with user code 42 (AC #1, AC #2)"; \
	else \
		echo "FAIL: REPL test 676 — expected '42  ok' for caught-THROW round-trip"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": T2 -13 THROW ;" "' T2 CATCH ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-13  ok'; then \
		echo "PASS: REPL test 677 — Story 11.3: caught THROW round-trip with std code -13 (AC #1)"; \
	else \
		echo "FAIL: REPL test 677 — expected '-13  ok' for caught -13 THROW round-trip"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": T1 42 THROW ;" "1 2 3 ' T1 CATCH . . . ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '42 3 2 1  ok'; then \
		echo "PASS: REPL test 678 — Story 11.3: i*x preservation across caught THROW (AC #2)"; \
	else \
		echo "FAIL: REPL test 678 — expected '42 3 2 1  ok' for i*x preservation"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": T1 42 THROW ;" "1 2 3 4 ' T1 CATCH DEPTH ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '5  ok'; then \
		echo "PASS: REPL test 679 — Story 11.3: post-THROW DEPTH = pre-CATCH-DEPTH + 1 (AC #8)"; \
	else \
		echo "FAIL: REPL test 679 — expected '5  ok' for post-THROW DEPTH check"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": T3 -5 THROW ;" ": N3 ['] T3 CATCH ;" "' N3 CATCH . ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '0 -5  ok'; then \
		echo "PASS: REPL test 680 — Story 11.3: nested CATCH, inner catches; outer normal-return (AC #1)"; \
	else \
		echo "FAIL: REPL test 680 — expected '0 -5  ok' for nested-inner-catches scenario"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": T4 -5 THROW ;" ": N4 T4 ;" "' N4 CATCH ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-5  ok'; then \
		echo "PASS: REPL test 681 — Story 11.3: nested CATCH, outer catches when inner has no CATCH (AC #1)"; \
	else \
		echo "FAIL: REPL test 681 — expected '-5  ok' for outer-catches-only scenario"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n%s\r\n" ": T5 -5 THROW ;" ": M5 T5 ;" ": N5 M5 ;" "' N5 CATCH ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-5  ok'; then \
		echo "PASS: REPL test 682 — Story 11.3: 3-deep nesting, only outermost CATCH catches (AC #1)"; \
	else \
		echo "FAIL: REPL test 682 — expected '-5  ok' for 3-deep outermost-catches scenario"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": T6 -5 THROW ;" ": M6 ['] T6 CATCH DROP -7 THROW ;" "' M6 CATCH ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-7  ok'; then \
		echo "PASS: REPL test 683 — Story 11.3: inner catches and re-THROWs a different code (AC #1)"; \
	else \
		echo "FAIL: REPL test 683 — expected '-7  ok' for catch-and-rethrow scenario"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n%s\r\n" ": T7 -5 THROW ;" ": M7 ['] T7 CATCH ;" ": N7 M7 ;" "' N7 CATCH . ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '0 -5  ok'; then \
		echo "PASS: REPL test 684 — Story 11.3: 3-deep nesting, middle CATCH catches; outer normal-return (AC #1)"; \
	else \
		echo "FAIL: REPL test 684 — expected '0 -5  ok' for 3-deep middle-catches scenario"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '42 THROW\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error 42  '; then \
		echo "PASS: REPL test 685 — Story 11.3: uncaught THROW with user code prints 'error <N>' (no description) (AC #4, AC #5)"; \
	else \
		echo "FAIL: REPL test 685 — expected 'error 42' (no ': <desc>') for uncaught user THROW"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-13 THROW\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -13: undefined word'; then \
		echo "PASS: REPL test 686 — Story 11.3: uncaught THROW with std code -13 prints diagnostic + description (AC #4, AC #5)"; \
	else \
		echo "FAIL: REPL test 686 — expected 'error -13: undefined word' for uncaught -13 THROW"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-1 THROW\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -1: ABORT'; then \
		echo "PASS: REPL test 687 — Story 11.3: uncaught -1 THROW prints 'error -1: ABORT' (Story 11.7 retargeted ABORT itself to -1 THROW) (AC #5)"; \
	else \
		echo "FAIL: REPL test 687 — expected 'error -1: ABORT' for uncaught -1 THROW"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n%s\r\n" ": HELLO 99 ;" "-13 THROW" "HELLO ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -13: undefined word.*99  ok'; then \
		echo "PASS: REPL test 688 — Story 11.3: dictionary intact across uncaught THROW + REPL recovery (AC #4)"; \
	else \
		echo "FAIL: REPL test 688 — expected diagnostic followed by '99  ok' (HELLO survives recovery)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" "HEX -1 THROW" "BASE @ DECIMAL ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -1: ABORT.*16  ok'; then \
		echo "PASS: REPL test 689 — Story 11.3: BASE preserved across uncaught THROW; diagnostic prints in decimal (AC #4, AC #13)"; \
	else \
		echo "FAIL: REPL test 689 — expected 'error -1: ABORT' (decimal) then '16  ok' (BASE still HEX)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n%s\r\n%s\r\n" "CODE BAD" "-13 THROW" "CODE GOOD" "NEXT, END-CODE" "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -13: undefined word.* ok.* ok.* ok'; then \
		echo "PASS: REPL test 690 — Story 11.3: asm_mode cleaned by uncaught THROW; subsequent CODE..END-CODE compiles (AC #4)"; \
	else \
		echo "FAIL: REPL test 690 — expected diagnostic + 3 'ok' (CODE BAD, recovery, CODE GOOD, END-CODE)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" "-13 THROW" "CATCH-TOP @ ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -13: undefined word.*CATCH-TOP @ \. 0  ok'; then \
		echo "PASS: REPL test 691 — Story 11.3: CATCH-TOP zeroed by QUIT after uncaught THROW (CCD-1 chain reset)"; \
	else \
		echo "FAIL: REPL test 691 — expected diagnostic followed by 'CATCH-TOP @ . 0  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": T8 -32768 THROW ;" "' T8 CATCH ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-32768  ok'; then \
		echo "PASS: REPL test 692 — Story 11.3 (review F2): caught -32768 (most-negative 16-bit) round-trips correctly"; \
	else \
		echo "FAIL: REPL test 692 — expected '-32768  ok' for caught most-negative THROW"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf -- '-32768 THROW\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -32768  '; then \
		echo "PASS: REPL test 693 — Story 11.3 (review F2): uncaught -32768 prints 'error -32768' via unsigned-aware print (no description suffix — code is not in throw_desc_table)"; \
	else \
		echo "FAIL: REPL test 693 — expected 'error -32768  ' (no ': <desc>') for uncaught most-negative THROW"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": DT 10 0 DO -5 THROW LOOP ;" "' DT CATCH ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-5  ok'; then \
		echo "PASS: REPL test 694 — Story 11.3 (review F3): THROW from inside DO-LOOP body; snap-back skips DO frame (E11-D2)"; \
	else \
		echo "FAIL: REPL test 694 — expected '-5  ok' for THROW from DO-LOOP"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": T9 -5 THROW ;" "' T9 ['] EXECUTE CATCH ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-5  ok'; then \
		echo "PASS: REPL test 695 — Story 11.3 (review F3): THROW mid-EXECUTE; snap-back skips EXECUTE return-addr frame"; \
	else \
		echo "FAIL: REPL test 695 — expected '-5  ok' for THROW mid-EXECUTE"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- Story 11.4 — internal-error migration: stack/arithmetic/memory primitives ---
	@# Section 1: stack underflow caught (-4 THROW via do_underflow_error
	@# → w_THROW_cf.kernel_entry). Section 2: divisor zero caught (-10
	@# THROW via udivmod / UM/MOD entry guards). Source spec:
	@# tests/throw_migration_tests.fth.
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "' DROP CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-4  ok'; then \
		echo "PASS: REPL test 696 — Story 11.4: caught DROP underflow returns -4 (AC #1, AC #9)"; \
	else \
		echo "FAIL: REPL test 696 — expected '-4  ok' for caught DROP underflow"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "' + CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-4  ok'; then \
		echo "PASS: REPL test 697 — Story 11.4: caught + underflow (depth-2 guard) returns -4 (AC #1, AC #9)"; \
	else \
		echo "FAIL: REPL test 697 — expected '-4  ok' for caught + underflow"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "' @ CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-4  ok'; then \
		echo "PASS: REPL test 698 — Story 11.4: caught @ underflow (memory primitive) returns -4 (AC #1, AC #9)"; \
	else \
		echo "FAIL: REPL test 698 — expected '-4  ok' for caught @ underflow"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "' ! CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-4  ok'; then \
		echo "PASS: REPL test 699 — Story 11.4: caught ! underflow (depth-2 guard) returns -4 (AC #1, AC #9)"; \
	else \
		echo "FAIL: REPL test 699 — expected '-4  ok' for caught ! underflow"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "' ROT CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-4  ok'; then \
		echo "PASS: REPL test 700 — Story 11.4: caught ROT underflow (depth-3 guard) returns -4 (AC #1, AC #9)"; \
	else \
		echo "FAIL: REPL test 700 — expected '-4  ok' for caught ROT underflow"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "' 2SWAP CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-4  ok'; then \
		echo "PASS: REPL test 701 — Story 11.4: caught 2SWAP underflow (depth-4 guard) returns -4 (AC #1, AC #9)"; \
	else \
		echo "FAIL: REPL test 701 — expected '-4  ok' for caught 2SWAP underflow"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "5 ' DROP CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^0  ok'; then \
		echo "PASS: REPL test 702 — Story 11.4: positive control — DROP at depth-1 succeeds; CATCH returns 0 (AC #9)"; \
	else \
		echo "FAIL: REPL test 702 — expected '0  ok' for positive-control DROP at depth 1"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "' DROP CATCH DEPTH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^1  ok'; then \
		echo "PASS: REPL test 703 — Story 11.4: post-caught-underflow DEPTH = 1 (THROW code is the lone TOS)"; \
	else \
		echo "FAIL: REPL test 703 — expected '1  ok' for DEPTH after caught underflow"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': TDOL 2 0 DO DROP LOOP ;' "1 ' TDOL CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-4  ok'; then \
		echo "PASS: REPL test 704 — Story 11.4 (review F3 analog): underflow inside DO-LOOP body caught; DO frame snap-back works (AC #18)"; \
	else \
		echo "FAIL: REPL test 704 — expected '-4  ok' for DROP-underflow inside DO-LOOP"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': T1 1 0 / ;' "' T1 CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-10  ok'; then \
		echo "PASS: REPL test 705 — Story 11.4: caught '/' divisor-zero returns -10 (AC #4, AC #9)"; \
	else \
		echo "FAIL: REPL test 705 — expected '-10  ok' for caught '/' divisor zero"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': T2 1 0 MOD ;' "' T2 CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-10  ok'; then \
		echo "PASS: REPL test 706 — Story 11.4: caught MOD divisor-zero returns -10 (AC #4, AC #9)"; \
	else \
		echo "FAIL: REPL test 706 — expected '-10  ok' for caught MOD divisor zero"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': T3 1 0 /MOD ;' "' T3 CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-10  ok'; then \
		echo "PASS: REPL test 707 — Story 11.4: caught /MOD divisor-zero returns -10 (AC #4, AC #9)"; \
	else \
		echo "FAIL: REPL test 707 — expected '-10  ok' for caught /MOD divisor zero"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': T4 1 1 0 */ ;' "' T4 CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-10  ok'; then \
		echo "PASS: REPL test 708 — Story 11.4: caught '*/' divisor-zero (UM/MOD funnel) returns -10 (AC #5, AC #9)"; \
	else \
		echo "FAIL: REPL test 708 — expected '-10  ok' for caught '*/' divisor zero"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': T5 1 1 0 */MOD ;' "' T5 CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-10  ok'; then \
		echo "PASS: REPL test 709 — Story 11.4: caught '*/MOD' divisor-zero (UM/MOD funnel) returns -10 (AC #5, AC #9)"; \
	else \
		echo "FAIL: REPL test 709 — expected '-10  ok' for caught '*/MOD' divisor zero"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': P1 100 5 / ;' "' P1 CATCH . ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^0 20  ok'; then \
		echo "PASS: REPL test 710 — Story 11.4: positive control — '100 5 /' inside CATCH returns success + correct quotient (AC #9)"; \
	else \
		echo "FAIL: REPL test 710 — expected '0 20  ok' for positive-control non-zero divisor"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': T6 1 0 0 UM/MOD ;' "' T6 CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-10  ok'; then \
		echo "PASS: REPL test 711 — Story 11.4: caught UM/MOD divisor-zero returns -10 (AC #5, AC #9)"; \
	else \
		echo "FAIL: REPL test 711 — expected '-10  ok' for caught UM/MOD divisor zero"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': T7 1 0 0 SM/REM ;' "' T7 CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-10  ok'; then \
		echo "PASS: REPL test 712 — Story 11.4: caught SM/REM divisor-zero (UM/MOD funnel) returns -10 (AC #5, AC #9)"; \
	else \
		echo "FAIL: REPL test 712 — expected '-10  ok' for caught SM/REM divisor zero"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': T8 1 0 0 FM/MOD ;' "' T8 CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q -- '-10  ok'; then \
		echo "PASS: REPL test 713 — Story 11.4: caught FM/MOD divisor-zero (UM/MOD funnel) returns -10 (AC #5, AC #9)"; \
	else \
		echo "FAIL: REPL test 713 — expected '-10  ok' for caught FM/MOD divisor zero"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': TD 1 0 / ;' "' TD CATCH DEPTH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^1  ok'; then \
		echo "PASS: REPL test 714 — Story 11.4: post-caught-divisor-zero DEPTH = 1 (THROW code is the lone TOS)"; \
	else \
		echo "FAIL: REPL test 714 — expected '1  ok' for DEPTH after caught divisor zero"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': PMN 1 -32768 / ;' "' PMN CATCH . ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '^0 0  ok'; then \
		echo "PASS: REPL test 715 — Story 11.4 (review F2 watch): most-negative divisor 0x8000 does NOT false-trip the divisor-zero guard"; \
	else \
		echo "FAIL: REPL test 715 — expected '0 0  ok' for most-negative divisor positive control"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" 'DROP' '42 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -4: stack underflow.*42  ok'; then \
		echo "PASS: REPL test 716 — Story 11.4: uncaught DROP underflow prints diagnostic + REPL recovers cleanly (AC #9, AC #20)"; \
	else \
		echo "FAIL: REPL test 716 — expected 'error -4: stack underflow' + recovery + '42  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" '1 0 /' '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -10: division by zero.*99  ok'; then \
		echo "PASS: REPL test 717 — Story 11.4: uncaught '1 0 /' divisor-zero prints diagnostic + REPL recovers cleanly (AC #9, AC #20)"; \
	else \
		echo "FAIL: REPL test 717 — expected 'error -10: division by zero' + recovery + '99  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "1 ' + CATCH . ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '\-4 1  ok'; then \
		echo "PASS: REPL test 718 — Story 11.4.1: smallest reproducer (1 ' + CATCH . .) restores i*x's TOS-cell (AC #1)"; \
	else \
		echo "FAIL: REPL test 718 — expected '-4 1  ok' (i*x's TOS-cell preserved across caught underflow THROW)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "1 2 3 ' 2OVER CATCH . . . ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '\-4 3 2 1  ok'; then \
		echo "PASS: REPL test 719 — Story 11.4.1: 3 i*x cells preserved underneath caught -4 THROW (AC #2 corrected; uses 2OVER instead of DROP)"; \
	else \
		echo "FAIL: REPL test 719 — expected '-4 3 2 1  ok' (3 i*x cells preserved across caught underflow)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "1 2 3 ' 2OVER CATCH . DEPTH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '\-4 3  ok'; then \
		echo "PASS: REPL test 720 — Story 11.4.1: DEPTH=3 after popping THROW code -4 (AC #3 corrected; review F6 — combined value+depth assertion)"; \
	else \
		echo "FAIL: REPL test 720 — expected '-4 3  ok' (drop THROW code -4, then 3 i*x cells remain)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "1 2 ' 2OVER CATCH . . ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '\-4 2 1  ok'; then \
		echo "PASS: REPL test 721 — Story 11.4.1: 2 i*x cells preserved underneath caught -4 THROW (2OVER needs 4 cells; depth=2 underflows via check_underflow_4)"; \
	else \
		echo "FAIL: REPL test 721 — expected '-4 2 1  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': T241 1 0 / ;' "5 6 7 ' T241 CATCH . DEPTH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '\-10 3  ok'; then \
		echo "PASS: REPL test 722 — Story 11.4.1: DEPTH=3 after popping THROW code -10 (AC #4; review F6 — combined value+depth assertion)"; \
	else \
		echo "FAIL: REPL test 722 — expected '-10 3  ok' (drop THROW code -10, then 3 i*x cells remain)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': T241 1 0 / ;' "5 6 7 ' T241 CATCH . . . ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '\-10 7 6 5  ok'; then \
		echo "PASS: REPL test 723 — Story 11.4.1: 3 i*x cells preserved underneath caught -10 THROW (divisor zero, AC #4)"; \
	else \
		echo "FAIL: REPL test 723 — expected '-10 7 6 5  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n%s\r\n" ": T84 -5 THROW ;" ": N84 ['] T84 CATCH ;" "1 2 ' N84 CATCH . . . ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '0 -5 2 1  ok'; then \
		echo "PASS: REPL test 724 — Story 11.4.1: nested CATCH preserves outer i*x = (1,2) when inner catches -5 (AC #12)"; \
	else \
		echo "FAIL: REPL test 724 — expected '0 -5 2 1  ok' (outer normal-return 0 + inner-caught -5 + outer i*x)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n%s\r\n" ": TI3 -5 THROW ;" ": MI3 ['] TI3 CATCH DROP -7 THROW ;" "11 22 ' MI3 CATCH . . ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '\-7 22 11  ok'; then \
		echo "PASS: REPL test 725 — Story 11.4.1 (review F4): 3-level nested CATCH with inner-rethrow preserves outer i*x = (11,22)"; \
	else \
		echo "FAIL: REPL test 725 — expected '-7 22 11  ok' (outer catches rethrown -7, outer i*x preserved)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": TDOL3 5 0 DO 2OVER LOOP ;" "1 2 3 ' TDOL3 CATCH . . . ." "BYE" | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '\-4 3 2 1  ok'; then \
		echo "PASS: REPL test 726 — Story 11.4.1 (review F2): DO-LOOP-frame snap-back + i*x preservation across underflow inside DO body"; \
	else \
		echo "FAIL: REPL test 726 — expected '-4 3 2 1  ok' (DO frame skipped + 3 i*x cells preserved)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "' ; CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '\-14  ok'; then \
		echo "PASS: REPL test 727 — Story 11.5: ' ; CATCH . returns -14 (compile-only guard caught from kernel-internal entry; AC #6, #15)"; \
	else \
		echo "FAIL: REPL test 727 — expected '-14  ok' for ' ; CATCH ."; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "' DOES> CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '\-14  ok'; then \
		echo "PASS: REPL test 728 — Story 11.5: ' DOES> CATCH . returns -14 (compile-only guard caught; AC #6, #15)"; \
	else \
		echo "FAIL: REPL test 728 — expected '-14  ok' for ' DOES> CATCH ."; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "' ?COMP CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '\-14  ok'; then \
		echo "PASS: REPL test 729 — Story 11.5: ' ?COMP CATCH . returns -14 (compile-only guard caught; AC #6, #15)"; \
	else \
		echo "FAIL: REPL test 729 — expected '-14  ok' for ' ?COMP CATCH ."; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "1 2 3 ' ; CATCH . . . ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '\-14 3 2 1  ok'; then \
		echo "PASS: REPL test 730 — Story 11.5: i*x preservation across kernel-internal -14 raise (1 2 3 ' ; CATCH; AC #15)"; \
	else \
		echo "FAIL: REPL test 730 — expected '-14 3 2 1  ok' (i*x cells preserved across compile-only THROW)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ": T3DOL 2 0 DO ?COMP LOOP ;" "' T3DOL CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '\-14  ok'; then \
		echo "PASS: REPL test 731 — Story 11.5: ?COMP from inside DO-LOOP body raises -14, snap-back skips DO frame on IX (review F3 analog; AC #20d)"; \
	else \
		echo "FAIL: REPL test 731 — expected '-14  ok' (?COMP-in-DO-LOOP)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "' DUP CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '0  ok'; then \
		echo "PASS: REPL test 732 — Story 11.5 positive control: ' DUP CATCH . returns 0 (CATCH framework still works; AC #15)"; \
	else \
		echo "FAIL: REPL test 732 — expected '0  ok' (positive control for CATCH framework)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "5 CONSTANT BAR BAR ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '5  ok'; then \
		echo "PASS: REPL test 733 — Story 11.5 positive control: CONSTANT with real name defines callable word (success path of the migrated CONSTANT site; AC #15)"; \
	else \
		echo "FAIL: REPL test 733 — expected '5  ok' (CONSTANT positive control); CONSTANT at top level (not inside colon) parses its name from REPL"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "' ; CATCH DEPTH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -qE '1  ok'; then \
		echo "PASS: REPL test 734 — Story 11.5: DEPTH=1 after popping THROW code -14 from caught compile-only (review F6 analog)"; \
	else \
		echo "FAIL: REPL test 734 — expected '1  ok' (DEPTH after caught -14)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" "' UNDEFINED" '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -13: undefined word.*99  ok'; then \
		echo "PASS: REPL test 735 — Story 11.5: uncaught ' UNDEFINED prints error -13 + REPL recovers cleanly (TICK at REPL; AC #19)"; \
	else \
		echo "FAIL: REPL test 735 — expected 'error -13: undefined word' + recovery + '99  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" 'UNDEFINED' '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -13: undefined word.*99  ok'; then \
		echo "PASS: REPL test 736 — Story 11.5: uncaught UNDEFINED token at top level prints error -13 + REPL recovers (INTERPRET; AC #19)"; \
	else \
		echo "FAIL: REPL test 736 — expected 'error -13: undefined word' + recovery + '99  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ';' '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -14: interpreting a compile-only word.*99  ok'; then \
		echo "PASS: REPL test 737 — Story 11.5: uncaught ; outside compile mode prints error -14 + REPL recovers (AC #19)"; \
	else \
		echo "FAIL: REPL test 737 — expected 'error -14: interpreting a compile-only word' + recovery + '99  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" 'DOES>' '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -14: interpreting a compile-only word.*99  ok'; then \
		echo "PASS: REPL test 738 — Story 11.5: uncaught DOES> outside compile mode prints error -14 + REPL recovers (AC #19)"; \
	else \
		echo "FAIL: REPL test 738 — expected 'error -14:' + recovery + '99  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': ' '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -16: attempt to use zero-length string as a name.*99  ok'; then \
		echo "PASS: REPL test 739 — Story 11.5: uncaught ':' (no name) prints error -16 + REPL recovers (AC #19)"; \
	else \
		echo "FAIL: REPL test 739 — expected 'error -16: attempt to use zero-length string as a name' + recovery + '99  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" 'CREATE ' '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -16: attempt to use zero-length string as a name.*99  ok'; then \
		echo "PASS: REPL test 740 — Story 11.5: uncaught CREATE (no name) prints error -16 + REPL recovers (AC #19)"; \
	else \
		echo "FAIL: REPL test 740 — expected 'error -16:' + recovery + '99  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" '5 CONSTANT ' '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -16: attempt to use zero-length string as a name.*99  ok'; then \
		echo "PASS: REPL test 741 — Story 11.5: uncaught 5 CONSTANT (no name) prints error -16 + REPL recovers (AC #19; CONSTANT POP-BC consumes value before THROW)"; \
	else \
		echo "FAIL: REPL test 741 — expected 'error -16:' + recovery + '99  ok' (CONSTANT no-name with value-on-stack)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" 'MARKER ' '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -16: attempt to use zero-length string as a name.*99  ok'; then \
		echo "PASS: REPL test 742 — Story 11.5: uncaught MARKER (no name) prints error -16 + REPL recovers (AC #19)"; \
	else \
		echo "FAIL: REPL test 742 — expected 'error -16:' + recovery + '99  ok' (MARKER no-name)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n%s\r\n" 'CODE' 'END-CODE' '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -260: CODE needs name.*99  ok'; then \
		echo "PASS: REPL test 743 — Story 11.5: uncaught CODE (no name) prints error -260 + REPL recovers (asm error via inline raise; AC #19)"; \
	else \
		echo "FAIL: REPL test 743 — expected 'error -260: CODE needs name' + recovery + '99  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" 'END-CODE' '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -261: END-CODE without CODE.*99  ok'; then \
		echo "PASS: REPL test 744 — Story 11.5: uncaught standalone END-CODE prints error -261 + REPL recovers (asm error via inline raise; AC #19)"; \
	else \
		echo "FAIL: REPL test 744 — expected 'error -261: END-CODE without CODE' + recovery + '99  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# --- Story 11.6 — strings/I-O/asm-die-residual migration tests ---
	@# Section 4.1: caught -17 (pictured overflow). HOLDs 41 chars from a
	@# 40-byte buffer; the 41st triggers .hc_overflow → -17 THROW; CATCH
	@# returns the code. Verifies the kernel-internal raise from
	@# do_pic_overflow_error.
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': T17 0 0 <# 41 0 DO 88 HOLD LOOP #> 2DROP ;' "' T17 CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '\-17  ok'; then \
		echo "PASS: REPL test 745 — Story 11.6: ' T17 CATCH . returns -17 (pictured overflow caught)"; \
	else \
		echo "FAIL: REPL test 745 — expected '-17  ok' for caught pictured overflow"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 4.1: i*x preservation across kernel-internal -17 raise.
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': T17 0 0 <# 41 0 DO 88 HOLD LOOP #> 2DROP ;' "1 2 3 ' T17 CATCH . . . ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '\-17 3 2 1  ok'; then \
		echo "PASS: REPL test 746 — Story 11.6: i*x preserved across caught -17 (3 cells under)"; \
	else \
		echo "FAIL: REPL test 746 — expected '-17 3 2 1  ok' for i*x preservation across pictured overflow"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 4.1: DEPTH = 1 after caught -17 (just the THROW code on top).
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': T17 0 0 <# 41 0 DO 88 HOLD LOOP #> 2DROP ;' "' T17 CATCH DEPTH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '1  ok'; then \
		echo "PASS: REPL test 747 — Story 11.6: DEPTH = 1 after caught -17"; \
	else \
		echo "FAIL: REPL test 747 — expected '1  ok' for DEPTH after caught -17"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 4.2: positive control — successful pictured-output round-trip.
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': TPIC 1234 0 <# # # # # #> 2DROP ;' "' TPIC CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0  ok'; then \
		echo "PASS: REPL test 748 — Story 11.6: ' TPIC CATCH . returns 0 (success path)"; \
	else \
		echo "FAIL: REPL test 748 — expected '0  ok' for successful pictured-output CATCH"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 4.2: positive control — properly-closed `(` returns 0.
	@OUTPUT=$$(printf '%s\r\n%s\r\n%s\r\n' ': TOK 5 ( inline ok ) ;' "' TOK CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0  ok'; then \
		echo "PASS: REPL test 749 — Story 11.6: no-throw colon body containing compile-time paren-comment returns 0"; \
	else \
		echo "FAIL: REPL test 749 — expected '0  ok' for closed-paren CATCH"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 4.3: uncaught -17 pictured overflow + REPL recovery.
	@# DO/LOOP are compile-only — wrap in a colon body to fire from
	@# execute time.
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n%s\r\n" ': T17X 0 0 <# 41 0 DO 88 HOLD LOOP #> 2DROP ;' 'T17X' '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -17: pictured numeric output string overflow.*99  ok'; then \
		echo "PASS: REPL test 750 — Story 11.6: uncaught -17 pictured overflow prints error + REPL recovers"; \
	else \
		echo "FAIL: REPL test 750 — expected 'error -17: pictured numeric output string overflow' + recovery + '99  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 4.3: uncaught -58 `(` missing `)` + REPL recovery.
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" '( unterminated' '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -58: unexpected end of input.*99  ok'; then \
		echo "PASS: REPL test 751 — Story 11.6: uncaught open-paren missing close-paren prints error -58 + REPL recovers"; \
	else \
		echo "FAIL: REPL test 751 — expected 'error -58: unexpected end of input' + recovery + '99  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 4.3: uncaught -270 (NOP, outside CODE) + REPL recovery.
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" 'NOP,' '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -270: not in CODE.*99  ok'; then \
		echo "PASS: REPL test 752 — Story 11.6: uncaught NOP, outside CODE prints error -270 + REPL recovers"; \
	else \
		echo "FAIL: REPL test 752 — expected 'error -270: not in CODE' + recovery + '99  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 4.3: uncaught -271 (BIT 8 — bit number out of 0..7 range)
	@# + REPL recovery. Triggers asm_range_err via .bop_reg8's range check.
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" 'CODE TRG271 8 # B BIT, END-CODE' '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -271: range.*99  ok'; then \
		echo "PASS: REPL test 753 — Story 11.6: uncaught BIT 8 prints error -271: range + REPL recovers"; \
	else \
		echo "FAIL: REPL test 753 — expected 'error -271: range' + recovery + '99  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# ============================================================
	@# Section 5 — ABORT / ABORT" retarget verification (Story 11.7)
	@# ============================================================
	@# Story 11.7 retargets ABORT → -1 THROW and ABORT" → -2 THROW
	@# (per ANS Forth 1994 §6.1.0670 / §6.1.0680). The legacy SP-reset
	@# / asm_cleanup / JP w_QUIT_cf chain moves into the uncaught-THROW
	@# handler at exception.asm:.throw_uncaught.
	@# Section 5.1: caught ABORT direct.
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "' ABORT CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '\-1  ok'; then \
		echo "PASS: REPL test 754 — Story 11.7: ' ABORT CATCH . returns -1 (caught ABORT direct, AC #7)"; \
	else \
		echo "FAIL: REPL test 754 — expected '-1  ok' for caught ABORT"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 5.1: caught ABORT via colon-body wrapper.
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': ABORTING ABORT ;' "' ABORTING CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '\-1  ok'; then \
		echo "PASS: REPL test 755 — Story 11.7: ' ABORTING CATCH . returns -1 (caught ABORT through colon wrapper, AC #7)"; \
	else \
		echo "FAIL: REPL test 755 — expected '-1  ok' for caught ABORT-wrapper"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 5.1: i*x preservation across caught -1 (Story 11.4.1 contract).
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "1 2 3 ' ABORT CATCH . . . ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '\-1 3 2 1  ok'; then \
		echo "PASS: REPL test 756 — Story 11.7: i*x preserved across caught -1 (3 cells under) (AC #7)"; \
	else \
		echo "FAIL: REPL test 756 — expected '-1 3 2 1  ok' for i*x preservation across caught ABORT"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 5.1: DEPTH = 1 after caught ABORT.
	@OUTPUT=$$(printf "%s\r\n%s\r\n" "' ABORT CATCH DEPTH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '1  ok'; then \
		echo "PASS: REPL test 757 — Story 11.7: DEPTH = 1 after caught ABORT (AC #7)"; \
	else \
		echo "FAIL: REPL test 757 — expected '1  ok' for DEPTH after caught ABORT"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 5.2: caught ABORT" from compiled colon body. The (ABORT")
	@# runtime prints the inline message then raises -2 THROW. Per AC #8
	@# (verified at dev-pass), (ABORT") emits NO trailing CR/LF after the
	@# message — observed output is `message-2  ok` with no break.
	@OUTPUT=$$(printf '%s\r\n%s\r\n%s\r\n' ': TAB1 1 ABORT" message" ;' "' TAB1 CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'message\-2  ok'; then \
		echo "PASS: REPL test 758 — Story 11.7: ' TAB1 CATCH . returns -2 with message print (caught ABORT\", AC #8)"; \
	else \
		echo "FAIL: REPL test 758 — expected 'message-2  ok' for caught ABORT\""; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 5.2: ABORT" flag-zero positive control — no print, no raise,
	@# CATCH returns 0 (per ANS §6.1.0680). Distinctive message marker
	@# `abz0msg` so absence of `abz0msg-` (which only appears when (ABORT")
	@# fires + prints + raises -2) is the smoking gun.
	@OUTPUT=$$(printf '%s\r\n%s\r\n%s\r\n' ': TAB0 0 ABORT" abz0msg" ;' "' TAB0 CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0  ok' && ! echo "$$OUTPUT" | grep -q 'abz0msg-'; then \
		echo "PASS: REPL test 759 — Story 11.7: ABORT\" flag-zero is no-op; CATCH returns 0 (AC #6)"; \
	else \
		echo "FAIL: REPL test 759 — expected '0  ok' AND no 'abz0msg-' for flag-zero ABORT\""; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 5.2: i*x preservation across caught -2 from ABORT".
	@OUTPUT=$$(printf '%s\r\n%s\r\n%s\r\n' ': TAB1 1 ABORT" message" ;' "1 2 3 ' TAB1 CATCH . . . ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'message\-2 3 2 1  ok'; then \
		echo "PASS: REPL test 760 — Story 11.7: i*x preserved across caught -2 (3 cells under) (AC #8)"; \
	else \
		echo "FAIL: REPL test 760 — expected 'message-2 3 2 1  ok' for i*x preservation across caught ABORT\""; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 5.3: positive control — no-abort colon body returns 0.
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': TNOAB 5 ;' "' TNOAB CATCH ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0  ok'; then \
		echo "PASS: REPL test 761 — Story 11.7: ' TNOAB CATCH . returns 0 (success path, no ABORT)"; \
	else \
		echo "FAIL: REPL test 761 — expected '0  ok' for no-ABORT body CATCH"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 5.4: uncaught ABORT word + REPL recovery (capstone).
	@# user-issued ABORT (now -1 THROW) flows through the uncaught-handler;
	@# Story 11.3 test 687 covered raw -1 THROW; this covers the ABORT
	@# word as the user-facing entry point.
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" 'ABORT' '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -1: ABORT.*99  ok'; then \
		echo "PASS: REPL test 762 — Story 11.7: uncaught ABORT prints error -1: ABORT + REPL recovers (AC #17)"; \
	else \
		echo "FAIL: REPL test 762 — expected 'error -1: ABORT' + recovery + '99  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 5.4: uncaught ABORT" + REPL recovery. The (ABORT") runtime
	@# prints the inline message before raising -2 THROW; the uncaught
	@# handler prints `error -2: ABORT"` then runs the recovery chain.
	@OUTPUT=$$(printf '%s\r\n%s\r\n%s\r\n%s\r\n' ': TUA1 1 ABORT" boom" ;' 'TUA1' '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'boom.*error -2: ABORT".*99  ok'; then \
		echo "PASS: REPL test 763 — Story 11.7: uncaught ABORT\" prints message + error -2 + REPL recovers (AC #17)"; \
	else \
		echo "FAIL: REPL test 763 — expected 'boom...error -2: ABORT\"...99  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 5.4: asm_cleanup integrity inside uncaught handler. An
	@# in-CODE error must (a) error + recover, (b) leave the partial
	@# CODE word unlinked from the dictionary. Mirror Makefile test 393.
	@# `TRYX117` appears once in stdin echo; if asm_cleanup unlinked it,
	@# it does NOT appear in the post-recovery WORDS output (one occurrence
	@# total). If asm_cleanup failed, WORDS lists it (two occurrences).
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" 'CODE TRYX117 UNDEFOPX117 END-CODE' 'WORDS' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -13.*ok' && \
	   [ "$$(echo "$$OUTPUT" | grep -c 'TRYX117')" = "1" ]; then \
		echo "PASS: REPL test 764 — Story 11.7: asm_cleanup integrity — in-CODE -13 + recovery; TRYX117 unlinked (AC #18a, capstone)"; \
	else \
		echo "FAIL: REPL test 764 — expected error -13 recovery AND TRYX117 only in stdin echo (not WORDS)"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 5.3 second positive control — i*x preservation through
	@# success path: cells underneath survive the CATCH frame round-trip.
	@OUTPUT=$$(printf "%s\r\n%s\r\n%s\r\n" ': TNOAB 5 ;' "1 2 3 ' TNOAB CATCH . . . . ." 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '0 5 3 2 1  ok'; then \
		echo "PASS: REPL test 765 — Story 11.7: i*x cells preserved through success path CATCH (positive control)"; \
	else \
		echo "FAIL: REPL test 765 — expected '0 5 3 2 1  ok' for success-path i*x preservation"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# === Story 11.8 — Section 10: Epic-11 closure REPL survivability stress + state-integrity invariants ===
	@# AC #3 stress recovery (NFR6): each uncaught error returns the REPL to a live
	@# prompt and a follow-up line parses cleanly. AC #3(b) stack-overflow OMITTED:
	@# Epic 11 wired no -3 guard (docs/throw-codes.md row -3 = "no | —"); documented
	@# in Story 11.8 Completion Notes as a known gap deferred to a post-2.0 hardening story.
	@# Section 10.1: stack-underflow stress recovery (NFR6 (a)).
	@OUTPUT=$$(printf '%s\r\n%s\r\n%s\r\n' 'DROP' '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -4: stack underflow.*99  ok'; then \
		echo "PASS: REPL test 766 — Story 11.8: stack underflow uncaught + REPL recovery (NFR6 a)"; \
	else \
		echo "FAIL: REPL test 766 — expected 'error -4: stack underflow' + recovery + '99  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 10.1: division-by-zero stress recovery (NFR6 (c)).
	@OUTPUT=$$(printf '%s\r\n%s\r\n%s\r\n' '1 0 /' '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -10: division by zero.*99  ok'; then \
		echo "PASS: REPL test 767 — Story 11.8: division by zero uncaught + REPL recovery (NFR6 c)"; \
	else \
		echo "FAIL: REPL test 767 — expected 'error -10: division by zero' + recovery + '99  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 10.1: undefined-word stress recovery (NFR6 (d)).
	@OUTPUT=$$(printf '%s\r\n%s\r\n%s\r\n' 'THIS-DOES-NOT-EXIST' '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -13: undefined word.*99  ok'; then \
		echo "PASS: REPL test 768 — Story 11.8: undefined word uncaught + REPL recovery (NFR6 d)"; \
	else \
		echo "FAIL: REPL test 768 — expected 'error -13: undefined word' + recovery + '99  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 10.1: orphan-`;` compile-state mismatch (NFR6 (e)).
	@# Verified at write time: kernel emits -14 ("interpreting a compile-only word"),
	@# not -22 as the story spec drafted; the story's spec said "verify exact code at
	@# write time" — adjusted regex to -14.
	@OUTPUT=$$(printf '%s\r\n%s\r\n%s\r\n' ';' '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -14: interpreting a compile-only word.*99  ok'; then \
		echo "PASS: REPL test 769 — Story 11.8: orphan-; compile-state mismatch uncaught + REPL recovery (NFR6 e)"; \
	else \
		echo "FAIL: REPL test 769 — expected 'error -14: interpreting a compile-only word' + recovery + '99  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 10.1: ABORT" truthy uncaught (NFR6 (f)). Re-frames Story 11.7 test 763
	@# as the closure-suite "every category in one place" entry; same scenario, fresh
	@# numbering so a future maintainer can grep test 770 for "Epic 11 closure suite".
	@OUTPUT=$$(printf '%s\r\n%s\r\n%s\r\n%s\r\n' ': T118F 1 ABORT" boom" ;' 'T118F' '99 .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'boom.*error -2: ABORT".*99  ok'; then \
		echo "PASS: REPL test 770 — Story 11.8: ABORT\" truthy uncaught + REPL recovery (NFR6 f)"; \
	else \
		echo "FAIL: REPL test 770 — expected 'boom...error -2: ABORT\"...99  ok'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# AC #4 state-integrity invariants (NFR7): post-error internal data structures
	@# remain consistent. Eight invariants — each gets one Makefile test.
	@# Section 10.2: invariant (i) input buffer reset — post-error line parses cleanly.
	@OUTPUT=$$(printf '%s\r\n%s\r\n%s\r\n' 'DROP' '1 2 + .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -4: stack underflow.*3  ok'; then \
		echo "PASS: REPL test 771 — Story 11.8: invariant (i) input buffer reset post-error (NFR7)"; \
	else \
		echo "FAIL: REPL test 771 — expected 'error -4...3  ok' for input-buffer reset"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 10.2: invariant (ii) HERE rolled back after mid-: error.
	@# H1 is a VARIABLE holding pre-: HERE; after the mid-: error, asm_cleanup unlinks
	@# the partial NEW and rolls HERE back. H1 @ HERE = . prints "-1  ok" (true).
	@OUTPUT=$$(printf '%s\r\n%s\r\n%s\r\n%s\r\n%s\r\n' 'VARIABLE H1' 'HERE H1 !' ': NEW THIS-DOES-NOT-EXIST ;' 'H1 @ HERE = .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -13: undefined word.*-1  ok'; then \
		echo "PASS: REPL test 772 — Story 11.8: invariant (ii) HERE rolled back after mid-: error (NFR7)"; \
	else \
		echo "FAIL: REPL test 772 — expected 'error -13...-1  ok' for HERE rollback"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 10.2: invariant (iii) parameter-stack DEPTH = 0 after recovery.
	@OUTPUT=$$(printf '%s\r\n%s\r\n%s\r\n' 'DROP' 'DEPTH .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -4: stack underflow.*0  ok'; then \
		echo "PASS: REPL test 773 — Story 11.8: invariant (iii) parameter-stack DEPTH = 0 post-recovery (NFR7)"; \
	else \
		echo "FAIL: REPL test 773 — expected 'error -4...0  ok' for DEPTH=0 invariant"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 10.2: invariant (iv) return stack reset — define + call colon post-error.
	@# A fresh : TT 1 ; TT . runs cleanly only if w_QUIT_cf re-init reset IX rstack.
	@OUTPUT=$$(printf '%s\r\n%s\r\n%s\r\n' 'DROP' ': TT 1 ; TT .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -4: stack underflow.*1  ok'; then \
		echo "PASS: REPL test 774 — Story 11.8: invariant (iv) return stack reset post-recovery (NFR7)"; \
	else \
		echo "FAIL: REPL test 774 — expected 'error -4...1  ok' for return-stack reset"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 10.2: invariant (v) CATCH-TOP @ . returns 0 after recovery.
	@OUTPUT=$$(printf '%s\r\n%s\r\n%s\r\n' 'DROP' 'CATCH-TOP @ .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -4: stack underflow.*0  ok'; then \
		echo "PASS: REPL test 775 — Story 11.8: invariant (v) CATCH-TOP = 0 post-recovery (NFR7)"; \
	else \
		echo "FAIL: REPL test 775 — expected 'error -4...0  ok' for CATCH-TOP=0 invariant"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 10.2: invariant (vi) BASE preserved across error.
	@# After HEX FE THIS-DOES-NOT-EXIST, BASE is still 16 (HEX) IF preserved.
	@# Probe with BASE @ DECIMAL . — reads BASE first (pushes current value),
	@# then switches print-base to DECIMAL, then prints the stacked value in
	@# decimal. BASE preserved (HEX) → BASE @ pushes 16 → "16  ok"; BASE
	@# reset to DECIMAL → BASE @ pushes 10 → "10  ok". Distinct outputs
	@# catch a regression that resets BASE on recovery. (The prior probe
	@# `BASE @ .` printed "10" in BOTH cases — HEX 16 and DECIMAL 10 both
	@# render to the string "10" in their respective bases — a HEX/DECIMAL
	@# coincidence false-PASS; Story 11.8 review M2.)
	@OUTPUT=$$(printf '%s\r\n%s\r\n%s\r\n' 'HEX FE THIS-DOES-NOT-EXIST' 'BASE @ DECIMAL .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -13: undefined word.*16  ok'; then \
		echo "PASS: REPL test 776 — Story 11.8: invariant (vi) BASE preserved across error (NFR7)"; \
	else \
		echo "FAIL: REPL test 776 — expected 'error -13...16  ok' for BASE-preserved invariant"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 10.2: invariant (vii) MARKER-saved state recoverable post-error.
	@# MARKER MK1 + : T 99 ; + DROP (errors) + MK1 (rolls back T) + T → "T ?" + -13.
	@# Confirms (a) MARKER survived recovery and (b) post-MK1 dictionary is at the marked state.
	@OUTPUT=$$(printf '%s\r\n%s\r\n%s\r\n%s\r\n%s\r\n%s\r\n' 'MARKER MK1' ': T 99 ;' 'DROP' 'MK1' 'T' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -4: stack underflow.*T \?.*error -13: undefined word'; then \
		echo "PASS: REPL test 777 — Story 11.8: invariant (vii) MARKER-saved state recoverable (NFR7)"; \
	else \
		echo "FAIL: REPL test 777 — expected '-4 stack underflow' then MK1 rolls back T then 'T ? error -13'"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@# Section 10.2: invariant (viii) user dictionary preserved (FR22).
	@OUTPUT=$$(printf '%s\r\n%s\r\n%s\r\n%s\r\n' ': USER-WORD 42 ;' 'THIS-DOES-NOT-EXIST' 'USER-WORD .' 'BYE' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | tr '\r\n' '  ' | grep -qE 'error -13: undefined word.*42  ok'; then \
		echo "PASS: REPL test 778 — Story 11.8: invariant (viii) user dictionary preserved across error (FR22)"; \
	else \
		echo "FAIL: REPL test 778 — expected 'error -13...42  ok' for user-dictionary preservation"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi

clean:
	rm -rf $(BUILDDIR)/*

# --- Docker targets ---

docker-build:
	docker build -t $(DOCKER_IMAGE) .

docker:
	$(DOCKER_RUN)

docker-test:
	$(DOCKER_RUN) test

docker-disk:
	$(DOCKER_RUN) disk
