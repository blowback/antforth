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
