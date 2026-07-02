#!/bin/sh
# tests/assert_verdicts_selftest.sh — proves assert_verdicts.sh fails AND passes
# on the right inputs (Story 24.4 AC3). A verdict asserter that cannot fail is
# not a guard. Run: sh tests/assert_verdicts_selftest.sh
set -u
H="sh $(dirname "$0")/assert_verdicts.sh"
rc=0
ok()   { echo "PASS: selftest — $1"; }
bad()  { echo "FAIL: selftest — $1"; rc=1; }

# Helper: run $H with given stdin + args, capture exit code.
run() { printf '%s' "$1" | eval "$H $2" >/dev/null 2>&1; echo $?; }

# 1. anchored: all patterns at column 0 -> exit 0
e=$(run 'PASS: a
PASS: b
' "--label t 'PASS: a' 'PASS: b'")
[ "$e" = 0 ] && ok "anchored all-present -> 0" || bad "anchored all-present expected 0, got $e"

# 2. anchored: a missing pattern -> exit 1
e=$(run 'PASS: a
' "--label t 'PASS: a' 'PASS: b'")
[ "$e" = 1 ] && ok "anchored missing -> 1" || bad "anchored missing expected 1, got $e"

# 3. false-green defense: an INDENTED echoed-source line carrying the literal
#    must NOT satisfy a column-0 anchor -> exit 1 (the 23.2 lesson).
e=$(run '  ." PASS: b" CR
PASS: a
' "--label t 'PASS: a' 'PASS: b'")
[ "$e" = 1 ] && ok "anchored ignores indented source-echo -> 1" || bad "false-green: indented source-echo wrongly passed, got $e"

# 4. fail-line tripwire fires even when all PASS patterns are present -> exit 1
e=$(run 'PASS: a
FAIL: something blew up
' "--label t --fail-line '^FAIL:' 'PASS: a'")
[ "$e" = 1 ] && ok "fail-line tripwire -> 1" || bad "fail-line tripwire expected 1, got $e"

# 5. strip-source: verdict mid-line passes; matching text only in echoed source fails
e=$(run 'bank? PASS: x happened after a caught abort
' "--label t --mode strip-source 'PASS: x'")
[ "$e" = 0 ] && ok "strip-source mid-line verdict -> 0" || bad "strip-source mid-line expected 0, got $e"
e=$(run '  ." PASS: x" CR
' "--label t --mode strip-source 'PASS: x'")
[ "$e" = 1 ] && ok "strip-source filters source-echo -> 1" || bad "strip-source source-only expected 1, got $e"

# 6. --count: needs >= N matching lines
e=$(run 'error -32: bad
error -32: bad
' "--label t --count 2 'error -32:' 'two -32 lines'")
[ "$e" = 0 ] && ok "count >=2 satisfied -> 0" || bad "count satisfied expected 0, got $e"
e=$(run 'error -32: bad
' "--label t --count 2 'error -32:' 'two -32 lines'")
[ "$e" = 1 ] && ok "count >=2 unmet -> 1" || bad "count unmet expected 1, got $e"

# 7. --present: unanchored single-line presence
e=$(run 'blah error -13: undefined word blah
' "--label t --present 'error -13: undefined word' 'minus-13 present'")
[ "$e" = 0 ] && ok "present found -> 0" || bad "present found expected 0, got $e"

# 8. CRLF: a CR-terminated verdict still anchors and matches a trailing-\$ pattern
e=$(run "$(printf 'PASS: env-excep\r\n')" "--label t 'PASS: env-excep\$'")
[ "$e" = 0 ] && ok "CRLF stripped, trailing-\$ anchor matches -> 0" || bad "CRLF/trailing-\$ expected 0, got $e"

if [ "$rc" = 0 ]; then echo "PASS: assert_verdicts selftest — all cases"; else echo "FAIL: assert_verdicts selftest"; fi
exit $rc
