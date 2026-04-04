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
SRCS     = $(wildcard $(SRCDIR)/*.asm)

# Docker
DOCKER_IMAGE = antforth-toolchain
DOCKER_RUN   = docker run --rm -v $(CURDIR):/workspace $(DOCKER_IMAGE)

.PHONY: all asm disk test test_key clean docker-build docker docker-test docker-disk

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

test: $(TARGET)
	@echo "Running antforth under iz-cpm..."
	@OUTPUT=$$($(IZCPM) $(TARGET)) && \
	EXPECTED=$$(printf 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstu\r\nv w  xyz{|') && \
	if [ "$$OUTPUT" = "$$EXPECTED" ]; then \
		echo "PASS: Output matches expected"; \
	else \
		echo "FAIL:"; \
		echo "  Expected: $$(echo -n "$$EXPECTED" | xxd)"; \
		echo "  Got:      $$(echo -n "$$OUTPUT" | xxd)"; \
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
