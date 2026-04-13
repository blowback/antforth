# Story 6.7: Misc Dedup

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a system maintainer,
I want duplicated sign-negation code extracted to a shared helper and stray tail-call patterns optimized,
so that the binary shrinks by ~8-10 bytes to close out Epic 6 with all mechanical dedup addressed.

## Acceptance Criteria

1. **Given** the duplicated sign-negation pattern in `src/formatting.asm` (lines 112-125 and 352-365) **When** it is extracted to a shared `print_neg_prefix` helper **Then** both call sites use `CALL print_neg_prefix` and the helper body exists exactly once.

2. **Given** two tail-call sites in `src/formatting.asm` **When** `CALL xxx / RET` is replaced with `JP xxx` **Then** 2 bytes are saved (1 byte per site).

3. **Given** all changes land **When** `make test && make test-repl` is run **Then** all regression tests pass with zero failures.

4. **Given** all changes land **When** `wc -c build/antforth.com` is measured **Then** the binary is at least 6 bytes smaller than the pre-story baseline (14,498 bytes).

## Tasks / Subtasks

- [x] Task 0: Record baseline (AC: #4)
  - [x] 0.1 `make asm && wc -c build/antforth.com` — confirm 14,498 bytes
  - [x] 0.2 `make test && make test-repl` — confirm all tests pass

- [x] Task 1: Extract sign-negation helper in `src/formatting.asm` (AC: #1, #3)
  - [x] 1.1 Create `print_neg_prefix` subroutine: BIT 7,B / RET Z / PUSH BC / LD E,'-' / CALL bdos_putchar / POP BC / negate BC / RET
  - [x] 1.2 Replace `w_DOT` inline sign-negation (lines 112-125) with `CALL print_neg_prefix`
  - [x] 1.3 Replace `.dots_print_signed` inline sign-negation (lines 352-365) with `CALL print_neg_prefix`
  - [x] 1.4 Adjust local labels: `.dot_positive` removed (CALL returns inline); `.dps_positive` removed (tail-call to emit_unsigned)
  - [x] 1.5 `make asm && make test && make test-repl` — all tests pass

- [x] Task 2: Tail-call optimizations in `src/formatting.asm` (AC: #2, #3)
  - [x] 2.1 Replace `CALL emit_unsigned / RET` at `.dps_positive` with `JP emit_unsigned` (done in Task 1.3)
  - [x] 2.2 Replace `CALL bdos_putchar / RET` at `emit_unsigned` exit with `JP bdos_putchar`
  - [x] 2.3 `make asm && make test && make test-repl` — all tests pass

- [x] Task 3: Final verification (AC: #3, #4)
  - [x] 3.1 `make test && make test-repl` — all 265 REPL + assembly tests green
  - [x] 3.2 `wc -c build/antforth.com` — 14,485 bytes (13 bytes saved from 14,498 baseline, exceeds 6-byte minimum)
  - [x] 3.3 Report savings breakdown: sign-negation dedup 11 bytes + tail-call opts 2 bytes = 13 bytes

## Dev Notes

### Sign-Negation Helper Design

The duplicated pattern (14 bytes each) in `w_DOT` and `.dots_print_signed`:

```asm
        BIT     7, B
        JR      Z, .positive
        PUSH    BC              ; Save number
        LD      E, '-'
        CALL    bdos_putchar
        POP     BC              ; Restore number
        ; Negate BC: BC = 0 - BC
        XOR     A
        SUB     C
        LD      C, A
        SBC     A, A
        SUB     B
        LD      B, A
.positive:
```

Extract to a shared subroutine `print_neg_prefix` (14 bytes + 1 RET = 15 bytes). Each call site becomes `CALL print_neg_prefix` (3 bytes). Two sites x 14 bytes = 28 bytes removed, 15 + 6 = 21 bytes added. **Net: ~7 bytes saved.**

**Important**: The helper must return with BC negated if negative, unchanged if positive. The caller then proceeds directly to emit_unsigned. The conditional JR Z branch must be inside the helper (jumps over the negate-and-emit to the RET).

### Tail-Call Optimization

Two sites where `CALL xxx / RET` → `JP xxx`:

1. **`.dps_positive`** (formatting.asm ~line 367): `CALL emit_unsigned / RET` → `JP emit_unsigned` (saves 1 byte)
2. **`u_to_str` exit** (formatting.asm ~line 98): `CALL bdos_putchar / RET` → `JP bdos_putchar` (saves 1 byte, verify this is actually CALL/RET pair)

### What Was NOT Done (And Why)

- **Negate-BC in arithmetic.asm**: The two instances in `sdivmod` (lines 160-167 and 174-182) use `PUSH AF / POP AF` around the negate and operate on HL not just BC. Different enough that a shared helper would not save bytes after the CALL overhead.
- **JP→JR conversions**: No unconditional JP instructions targeting local labels were found. All branches already use JR.
- **DEC HL x3 pattern in assembler.asm**: Would cost more bytes (CALL overhead) than it saves. Not worth it.
- **Negate-BC standalone helper**: A generic `negate_bc` callable from arithmetic.asm too was considered, but the AF save/restore and HL variant make it not worth the CALL overhead for only 2 additional sites.

### Byte Budget

| Change | Savings |
|--------|---------|
| Sign-negation dedup (2 sites → 1 helper) | 11 bytes |
| Tail-call: `.dots_print_signed` CALL→JP | 1 byte |
| Tail-call: `emit_unsigned` CALL→JP | 1 byte |
| **Total** | **13 bytes** |

### Build/Test Commands

```bash
make asm                    # Assemble with sjasmplus
make test                   # Run assembly-level regression tests
make test-repl              # Run REPL-piped Forth regression tests
wc -c build/antforth.com    # Check binary size
```

### Previous Story Learnings (6.6)

- DE clobber bug: recognizer used DE as scratch, corrupting threaded IP. Be careful with register usage in subroutines.
- Build-test-verify after each task catches issues early.
- Record baseline size before any changes.
- sjasmplus local label scoping: `.label` is scoped per parent label.
- All 265 REPL tests + assembly tests should pass at each checkpoint.

### Project Structure Notes

- `src/formatting.asm` — only file modified: extract sign-negation helper, two tail-call optimizations
- No other files need modification
- Alignment with existing helpers (`bdos_putchar`, `rpush_de`, etc.) already established in Epic 6

### References

- [Source: src/formatting.asm:112-125] — w_DOT sign-negation code (first instance)
- [Source: src/formatting.asm:352-365] — .dots_print_signed sign-negation code (second instance)
- [Source: src/formatting.asm:367-368] — .dps_positive tail-call candidate (CALL emit_unsigned / RET)
- [Source: src/formatting.asm:98-99] — emit_unsigned tail-call candidate (CALL bdos_putchar / RET)
- [Source: _bmad-output/planning-artifacts/epic6-code-size-optimization.md#Story 6.7] — Epic specification

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None — clean implementation with no issues.

### Completion Notes List

- Created `print_neg_prefix` helper in `src/formatting.asm` using `RET Z` for compact conditional return
- Replaced inline sign-negation in `w_DOT` (CALL print_neg_prefix) and `.dots_print_signed` (CALL + tail-call JP)
- Applied tail-call optimization to `emit_unsigned` exit (`JP bdos_putchar` replacing `CALL/RET`)
- Applied tail-call optimization to `.dots_print_signed` (`JP emit_unsigned` replacing `CALL/RET`)
- Binary reduced from 14,498 to 14,485 bytes (13 bytes saved, exceeding 6-byte AC threshold)
- All 265 REPL tests + assembly regression tests pass with zero failures

### Change Log

- 2026-04-13: Story 6.7 implementation — sign-negation dedup + tail-call optimizations (13 bytes saved)

### File List

- src/formatting.asm (modified) — extracted print_neg_prefix helper, replaced 2 inline sign-negation blocks, 2 tail-call optimizations
