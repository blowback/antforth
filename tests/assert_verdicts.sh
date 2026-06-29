#!/bin/sh
# tests/assert_verdicts.sh — shared REPL-probe verdict asserter (Story 24.4).
#
# Reads emulator OUTPUT on stdin and asserts a set of verdicts against it. On any
# miss it prints a "FAIL: <label> — ..." line plus an xxd dump of the output and
# exits 1; on full success it prints the per-verdict "PASS: <label> — ..." lines
# and exits 0. Encapsulates the four things 6+ Makefile recipes used to re-derive
# by hand:
#   - column-0 anchoring of PASS verdicts (the 23.2 echoed-source false-green
#     defense: the REPL echoes piped source, so an unanchored match on a
#     ." PASS: x" source line false-greens regardless of which branch ran);
#   - grep -a NUL-byte safety (the 23.3 lesson);
#   - \r / CRLF stripping (done once here, so callers need no `| tr -d '\r'`);
#   - the xxd-dump-on-failure diagnostic.
#
# Usage:
#   ... | sh tests/assert_verdicts.sh --label LBL [--mode anchored|strip-source] \
#           [--fail-line REGEX] \
#           [--count N REGEX LABEL]... [--present REGEX LABEL]... \
#           PASS_PATTERN...
#
# Config flags (--label/--mode/--fail-line) MUST precede the assertions.
#
#   --mode anchored      (default) each PASS_PATTERN P is asserted as /^P/ — i.e.
#                        the verdict must start at column 0. The caller supplies
#                        any trailing `$` it wants (e.g. 'PASS: env-excep$').
#   --mode strip-source  echoed source lines (/^[[:space:]]*."/) are filtered out
#                        first, then each PASS_PATTERN is matched UNanchored — for
#                        probes whose verdict can sit mid-line (e.g. after a
#                        caught-abort 'bank?') or is not PASS:-prefixed
#                        (e.g. 'mbl-count: 2').
#   --fail-line REGEX    tripwire: FAIL if any line matches REGEX (e.g. '^FAIL:').
#   --count N REGEX LBL  assert at least N lines match REGEX (unanchored unless
#                        REGEX itself anchors); reports under LBL.
#   --present REGEX LBL  assert at least one line matches REGEX; reports under LBL.
#                        (--count/--present are never source-stripped — they target
#                        runtime error text that cannot appear in echoed source.)
set -u

label="verdict"
mode="anchored"
failed=0

# Read all of stdin once; strip CR so column-0 / trailing-$ anchors are clean.
OUT=$(cat | tr -d '\r')

note_fail() {            # $1 = message
	echo "FAIL: $label — $1"
	failed=1
}

assert_pass() {          # $1 = pattern
	if [ "$mode" = "strip-source" ]; then
		if printf '%s\n' "$OUT" | grep -vE '^[[:space:]]*\."' | grep -aq "$1"; then
			echo "PASS: $label — $1"
		else
			note_fail "expected '$1' in output"
		fi
	else
		if printf '%s\n' "$OUT" | grep -aqE "^$1"; then
			echo "PASS: $label — $1"
		else
			note_fail "expected '$1' at column 0 in output"
		fi
	fi
}

while [ $# -gt 0 ]; do
	case "$1" in
		--label)     label="$2"; shift 2 ;;
		--mode)      mode="$2";  shift 2 ;;
		--fail-line)
			if printf '%s\n' "$OUT" | grep -aqE "$2"; then
				note_fail "a runtime '$2' verdict was printed"
			fi
			shift 2 ;;
		--count)     # $2=N $3=REGEX $4=LBL
			_c=$(printf '%s\n' "$OUT" | grep -acE "$3")
			if [ "$_c" -ge "$2" ]; then
				echo "PASS: $label — $4"
			else
				note_fail "$4 (expected >=$2 lines matching /$3/, got $_c)"
			fi
			shift 4 ;;
		--present)   # $2=REGEX $3=LBL
			if printf '%s\n' "$OUT" | grep -aqE "$2"; then
				echo "PASS: $label — $3"
			else
				note_fail "$3 (expected /$2/ in output)"
			fi
			shift 3 ;;
		*)           assert_pass "$1"; shift ;;
	esac
done

if [ "$failed" -ne 0 ]; then
	echo "  Got: $(printf '%s' "$OUT" | xxd)"
	exit 1
fi
exit 0
