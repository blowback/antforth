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
	if echo "$$OUTPUT" | grep -q '? Stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 10 — stack underflow on + shows error and recovers"; \
	else \
		echo "FAIL: REPL test 10 — expected '? Stack underflow' and 'ok' in output"; \
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
	if echo "$$OUTPUT" | grep -q '? Stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 13 — stack underflow on DROP shows error and recovers"; \
	else \
		echo "FAIL: REPL test 13 — expected '? Stack underflow' and 'ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '.\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '? Stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 14 — stack underflow on . shows error and recovers"; \
	else \
		echo "FAIL: REPL test 14 — expected '? Stack underflow' and 'ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'AND\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '? Stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 15 — stack underflow on AND shows error and recovers"; \
	else \
		echo "FAIL: REPL test 15 — expected '? Stack underflow' and 'ok' in output"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '1 +\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '? Stack underflow' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 16 — stack underflow on '1 +' (only 1 arg for binary op)"; \
	else \
		echo "FAIL: REPL test 16 — expected '? Stack underflow' and 'ok' in output"; \
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
	if echo "$$OUTPUT" | grep -q '? compile only' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 43 — compile-only guard: IF in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 43 — expected '? compile only' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'THEN\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '? compile only' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 44 — compile-only guard: THEN in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 44 — expected '? compile only' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'BEGIN\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '? compile only' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 45 — compile-only guard: BEGIN in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 45 — expected '? compile only' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'ELSE\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '? compile only' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 46 — compile-only guard: ELSE in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 46 — expected '? compile only' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'WHILE\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '? compile only' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 47 — compile-only guard: WHILE in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 47 — expected '? compile only' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'REPEAT\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '? compile only' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 48 — compile-only guard: REPEAT in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 48 — expected '? compile only' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'UNTIL\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '? compile only' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 49 — compile-only guard: UNTIL in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 49 — expected '? compile only' and recovery"; \
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
	if echo "$$OUTPUT" | grep -q '? compile only' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 57 — compile-only guard: DO in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 57 — expected '? compile only' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'LOOP\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '? compile only' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 58 — compile-only guard: LOOP in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 58 — expected '? compile only' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '+LOOP\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '? compile only' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 59 — compile-only guard: +LOOP in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 59 — expected '? compile only' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'LEAVE\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '? compile only' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 60 — compile-only guard: LEAVE in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 60 — expected '? compile only' and recovery"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'RECURSE\r\n2 3 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q '? compile only' && echo "$$OUTPUT" | tr -d '\r\n' | grep -q '5 '; then \
		echo "PASS: REPL test 61 — compile-only guard: RECURSE in interpret mode shows error and recovers"; \
	else \
		echo "FAIL: REPL test 61 — expected '? compile only' and recovery"; \
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
	if echo "$$OUTPUT" | grep -q '? compile only' && echo "$$OUTPUT" | grep -q 'ok'; then \
		echo "PASS: REPL test 73 — POSTPONE in interpret mode shows compile-only error and recovers"; \
	else \
		echo "FAIL: REPL test 73 — expected '? compile only' and recovery"; \
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
	if echo "$$OUTPUT" | grep -q 'AntForth v1.00'; then \
		echo "PASS: REPL test 80 — Banner version string: output contains 'AntForth v1.00'"; \
	else \
		echo "FAIL: REPL test 80 — expected 'AntForth v1.00' in output"; \
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
	if echo "$$OUTPUT" | grep -q 'LABEL must precede opcodes ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 ' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^BAD3$$' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^ZED$$'; then \
		echo "PASS: REPL test 97 — LABEL after opcodes: error, recovery, BAD3 and ZED not leaked"; \
	else \
		echo "FAIL: REPL test 97 — expected 'LABEL must precede opcodes ?', '3', BAD3/ZED absent"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD4 LABEL TGT TGT FIX 130 DS, TGT JR, NEXT, END-CODE\r\n1 2 + .\r\nWORDS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	WORDS_LINE=$$(echo "$$OUTPUT" | tr -d '\r' | grep -E '^@ ' || true) && \
	if echo "$$OUTPUT" | grep -q 'JR out of range ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 ' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^BAD4$$' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^TGT$$'; then \
		echo "PASS: REPL test 98 — out-of-range JR: error, recovery, BAD4 and TGT not leaked"; \
	else \
		echo "FAIL: REPL test 98 — expected 'JR out of range ?', '3', BAD4/TGT absent"; \
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
	NCOUNT=$$(echo "$$OUTPUT" | grep -c 'not in CODE ?') && \
	NREC=$$(echo "$$OUTPUT" | tr -d '\r\n' | grep -oE '3 ' | wc -l) && \
	if [ "$$NCOUNT" -ge 5 ] && [ "$$NREC" -ge 5 ]; then \
		echo "PASS: REPL test 100 — LABEL/FIX/DB,/DW,/DS, outside CODE: 5 errors, 5 clean recoveries"; \
	else \
		echo "FAIL: REPL test 100 — expected 5x 'not in CODE ?' and 5x recovery (got $$NCOUNT errors, $$NREC '3 ')"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD6 1 EQU FOO NEXT, END-CODE\r\n1 2 + .\r\nWORDS\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	WORDS_LINE=$$(echo "$$OUTPUT" | tr -d '\r' | grep -E '^@ ' || true) && \
	if echo "$$OUTPUT" | grep -q 'EQU outside CODE only ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 ' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^BAD6$$' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^FOO$$'; then \
		echo "PASS: REPL test 101 — EQU inside CODE: error, recovery, BAD6 and FOO not leaked"; \
	else \
		echo "FAIL: REPL test 101 — expected 'EQU outside CODE only ?', '3', BAD6/FOO absent"; \
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
	if echo "$$OUTPUT" | grep -q 'too many labels ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 ' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^BIG$$' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^L1$$' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^L16$$'; then \
		echo "PASS: REPL test 103 — label-pool overflow: error, recovery, BIG and L1..L16 not leaked"; \
	else \
		echo "FAIL: REPL test 103 — expected 'too many labels ?', '3', BIG/L1/L16 absent"; \
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
	if echo "$$OUTPUT" | grep -q 'too many fixups ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 ' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^FXOF$$' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^F$$'; then \
		echo "PASS: REPL test 105 — fixup-pool overflow: 33 forward JRs hit 'too many fixups ?'"; \
	else \
		echo "FAIL: REPL test 105 — expected 'too many fixups ?', '3', FXOF/F absent from WORDS"; \
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
	if echo "$$OUTPUT" | grep -q 'bad operand ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 ' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^BADAF$$'; then \
		echo "PASS: REPL test 109 — LD rr,nn rejects AF: error, recovery, BADAF not leaked"; \
	else \
		echo "FAIL: REPL test 109 — expected 'bad operand ?' and BADAF absent"; \
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
	if echo "$$OUTPUT" | grep -q 'bad operand ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 ' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^BADHH$$'; then \
		echo "PASS: REPL test 112 — (HL),(HL) LD, rejected: error, recovery, BADHH not leaked"; \
	else \
		echo "FAIL: REPL test 112 — expected 'bad operand ?' and BADHH absent"; \
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
	if echo "$$OUTPUT" | grep -q 'bad operand ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 ' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^BADJR$$' && \
	   ! echo "$$WORDS_LINE" | tr ' ' '\n' | grep -qE '^T$$'; then \
		echo "PASS: REPL test 122 — conditional JR rejects PO: error, BADJR/T not leaked"; \
	else \
		echo "FAIL: REPL test 122 — expected 'bad operand ?' and BADJR/T absent"; \
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
	if echo "$$OUTPUT" | grep -q 'not in CODE ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 127 — # outside CODE rejected, clean recovery"; \
	else \
		echo "FAIL: REPL test 127 — expected 'not in CODE ?' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf '(HL)\r\n1 2 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'not in CODE ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 128 — (HL) outside CODE rejected, clean recovery"; \
	else \
		echo "FAIL: REPL test 128 — expected 'not in CODE ?' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'NZ\r\nZ\r\nNC\r\nCS\r\nPO\r\nPE\r\nP\r\nM\r\nHEX\r\nCC .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	ERRCOUNT=$$(echo "$$OUTPUT" | grep -c 'not in CODE ?') && \
	if [ "$$ERRCOUNT" -ge 8 ] && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE 'CC '; then \
		echo "PASS: REPL test 129 — conditions outside CODE rejected; CC literal still parses in HEX"; \
	else \
		echo "FAIL: REPL test 129 — expected 8x 'not in CODE ?' and 'CC ' literal"; \
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
	if echo "$$OUTPUT" | grep -q 'range ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 150 — bit 8 raises range ?, clean recovery"; \
	else \
		echo "FAIL: REPL test 150 — expected 'range ?' and '3 '"; \
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
	if echo "$$OUTPUT" | grep -q 'bad operand ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 154 — immediate-port IN with B: bad operand, clean recovery"; \
	else \
		echo "FAIL: REPL test 154 — expected 'bad operand ?' and '3 '"; \
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
	if echo "$$OUTPUT" | grep -q 'bad operand ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 170 — +D with non-(IX)/(IY): bad operand, clean recovery"; \
	else \
		echo "FAIL: REPL test 170 — expected 'bad operand ?' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD171 (IX) 200 +D A LD, END-CODE\r\n1 2 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'range ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 171 — displacement 200 out of range, clean recovery"; \
	else \
		echo "FAIL: REPL test 171 — expected 'range ?' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD172 AF INC, END-CODE\r\n1 2 + .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'bad operand ?' && echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '3 '; then \
		echo "PASS: REPL test 172 — AF INC,: bad operand, clean recovery"; \
	else \
		echo "FAIL: REPL test 172 — expected 'bad operand ?' and '3 '"; \
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
	if echo "$$OUTPUT" | grep -q 'bad operand ?' && echo "$$OUTPUT" | grep -q '3 '; then \
		echo "PASS: REPL test 202 — RST, with invalid vector: bad operand, clean recovery"; \
	else \
		echo "FAIL: REPL test 202 — expected 'bad operand ?' and '3 '"; \
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
	if echo "$$OUTPUT" | grep -q 'not in CODE ?' && echo "$$OUTPUT" | grep -q '3 '; then \
		echo "PASS: REPL test 207 — NOP, outside CODE: not in CODE ?, clean recovery"; \
	else \
		echo "FAIL: REPL test 207 — expected 'not in CODE ?' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD208 B (BC) LD, END-CODE\r\n3 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'bad operand ?' && echo "$$OUTPUT" | grep -q '3 '; then \
		echo "PASS: REPL test 208 — B (BC) LD, rejects non-A: bad operand, clean recovery"; \
	else \
		echo "FAIL: REPL test 208 — expected 'bad operand ?' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD209 B (DE) LD, END-CODE\r\n3 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'bad operand ?' && echo "$$OUTPUT" | grep -q '3 '; then \
		echo "PASS: REPL test 209 — B (DE) LD, rejects non-A: bad operand, clean recovery"; \
	else \
		echo "FAIL: REPL test 209 — expected 'bad operand ?' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD210 B IREG LD, END-CODE\r\n3 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'bad operand ?' && echo "$$OUTPUT" | grep -q '3 '; then \
		echo "PASS: REPL test 210 — B IREG LD, rejects non-A: bad operand, clean recovery"; \
	else \
		echo "FAIL: REPL test 210 — expected 'bad operand ?' and '3 '"; \
		echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
		exit 1; \
	fi
	@OUTPUT=$$(printf 'CODE BAD211 IREG B LD, END-CODE\r\n3 .\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
	if echo "$$OUTPUT" | grep -q 'bad operand ?' && echo "$$OUTPUT" | grep -q '3 '; then \
		echo "PASS: REPL test 211 — IREG B LD, rejects non-A dest: bad operand, clean recovery"; \
	else \
		echo "FAIL: REPL test 211 — expected 'bad operand ?' and '3 '"; \
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
	if echo "$$OUTPUT" | grep -q 'bad operand ?' && echo "$$OUTPUT" | grep -q '3 '; then \
		echo "PASS: REPL test 214 — IX IY ADD, cross-index rejected: bad operand"; \
	else \
		echo "FAIL: REPL test 214 — expected 'bad operand ?' and '3 '"; \
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
	if echo "$$OUTPUT" | grep -q '? missing )' && echo "$$OUTPUT" | grep -q '42 '; then \
		echo "PASS: REPL test 222 — missing ) raises error and recovers"; \
	else \
		echo "FAIL: REPL test 222 — expected '? missing )' and '42 ' in output"; \
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
