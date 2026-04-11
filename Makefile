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
