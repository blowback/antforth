#!/usr/bin/env bash
#------------------------------------------------------------------------------
# tools/check-doc-sync/check-doc-sync.sh — PRD↔architecture transcription-drift
# sync target. Walks the four canonical Phase-3 planning artefacts and reports
# drift on stderr (one line per item) with a one-line stdout verdict.
#
# Story:  14.5 (B.5 / PD-3 — Epic 13 retro #2)
# Date:   2026-05-08
# Author: AntForth project (project-lead-attributed: Ant)
#
# Pinned by:
#   _bmad-output/planning-artifacts/architecture.md:272..282 (§"B.5-D1")
#   _bmad-output/planning-artifacts/prd.md:530 (FR-P3-16)
#   _bmad-output/planning-artifacts/epics-phase3-epics-14-15.md:394..414 (Story 14.5 ACs)
#   docs/PHASE-3-CARRY-FORWARD.md:36 (B.5 carry-forward row)
#
# Usage:  bash tools/check-doc-sync/check-doc-sync.sh
#         (or: make check-doc-sync, from the project root)
#
# Exit:   0 on clean-pass or advisory-only; 1 on any non-advisory drift item
#         (or fatal precondition such as a missing input file).
#
# Output: stdout — single one-liner verdict
#         stderr — one line per drift item ('[<check-id>] description')
#
# Drift checks (per architecture.md:276..280):
#   (a) FR-P3-N / NFR-P3-N label parity (bidirectional set difference) —
#       strict mode (drift items contribute to exit code).
#   (b) Story X.Y[.Z[.W…]] citation resolution into epics files — strict
#       mode. Citations with any number of trailing dot-separated
#       components are matched in full (no truncation).
#   (c) §X.Y.Z reference parity vs docs/ans-forth-core-compliance.md —
#       advisory mode pre-A.1 (Story 15.1); flip STRICT_SECTIONS=1 once
#       Story 15.1 closes A.1. References with any number of trailing
#       dot-separated components are matched in full.
#   (d) Top-level section-name parity (^## headers) — advisory mode by
#       design (PRD and architecture serve different roles; allowlist
#       starts empty and is populated as agreed-on shared sections are
#       confirmed).
#------------------------------------------------------------------------------

# Per AC4(d): the script does NOT use 'set -e' globally — drift detection
# in one check must not abort subsequent checks. Errors are handled per-
# check and accumulated into the verdict.

# Pre-flight: locate project root (the directory containing 'Makefile' and
# '_bmad-output/'). The script is intended to live two levels deep at
# tools/check-doc-sync/, so .. /.. resolves to the project root.
SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
cd "$PROJECT_ROOT" || { echo "[fatal] cannot cd to project root from $SCRIPT_DIR" >&2; exit 1; }

# Input files. The canonical 'epics.md' was split into per-phase files in
# commit 51bc6d6 (2026-05-10); the script walks every phase file in order
# Phase-1 → Phase-6 (Phase-5/6 added as the concurrency bundle landed).
PRD="_bmad-output/planning-artifacts/prd.md"
ARCH="_bmad-output/planning-artifacts/architecture.md"
EPICS_P1="_bmad-output/planning-artifacts/epics-phase1-epics-1-8.md"
EPICS_P2="_bmad-output/planning-artifacts/epics-phase2-epics-9-13.5.md"
EPICS_P3="_bmad-output/planning-artifacts/epics-phase3-epics-14-15.md"
EPICS_P4="_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md"
EPICS_P5="_bmad-output/planning-artifacts/epics-phase5-epic-23.md"
EPICS_P6="_bmad-output/planning-artifacts/epics-phase6-epics-24-26.md"
COMPLIANCE="docs/ans-forth-core-compliance.md"

# Verify inputs exist; emit fatal + exit 1 on any missing file.
fatal=0
for f in "$PRD" "$ARCH" "$EPICS_P1" "$EPICS_P2" "$EPICS_P3" "$EPICS_P4" "$EPICS_P5" "$EPICS_P6" "$COMPLIANCE"; do
    if [ ! -r "$f" ]; then
        printf '[fatal] required input file missing or unreadable: %s\n' "$f" >&2
        fatal=1
    fi
done
if [ "$fatal" -ne 0 ]; then
    exit 1
fi

# Configuration flags.
#
# STRICT_SECTIONS — gates check (c) §X.Y.Z reference parity. Default 0
# (advisory mode). Flip to 1 after Story 15.1 closes A.1 (the §-level
# structural-rule audit), at which point docs/ans-forth-core-compliance.md
# becomes the §-rule source-of-truth and any architecture-cited § without
# a compliance-doc row is genuine drift.
STRICT_SECTIONS=0

DRIFT=0
ADVISORY=0

# Read each input file ONCE (AC2: no per-check reload). Line-numbered
# variants are kept alongside raw content so per-orphan loc lookups do
# not re-open the file on disk.
ARCH_LINES="$(awk '{printf "%d:%s\n", NR, $0}' "$ARCH")"
PRD_LINES="$(awk '{printf "%d:%s\n", NR, $0}' "$PRD")"
COMP_LINES="$(awk '{printf "%d:%s\n", NR, $0}' "$COMPLIANCE")"
EPICS_HEADERS="$(awk 'FNR==1{f=FILENAME} /^### Story /{print f":"FNR":"$0}' \
    "$EPICS_P1" "$EPICS_P2" "$EPICS_P3" "$EPICS_P4" "$EPICS_P5" "$EPICS_P6")"

# Architecture references FR-P3-N / NFR-P3-N tokens both as singletons
# ("FR-P3-15") and as inclusive ranges ("FR-P3-22..25", "NFR-P3-22..33").
# Range forms are expanded so a label cited only in a range is treated
# as referenced (matches the reader's natural interpretation).
expand_ranges() {
    local r last base lo hi n
    while IFS= read -r r; do
        [ -z "$r" ] && continue
        last="${r##*-}"
        base="${r%-*}-"
        lo="${last%%..*}"
        hi="${last##*..}"
        n=$lo
        while [ "$n" -le "$hi" ]; do
            printf '%s%s\n' "$base" "$n"
            n=$((n+1))
        done
    done
}
arch_labels="$(
    {
        printf '%s\n' "$ARCH_LINES" | grep -oE 'FR-P3-[0-9]+|NFR-P3-[0-9]+'
        printf '%s\n' "$ARCH_LINES" | grep -oE '(FR|NFR)-P3-[0-9]+\.\.[0-9]+' | expand_ranges
    } | sort -u
)"
# PRD definitions appear as line-start bullets opening a bold block.
# FRs use the form  - **FR-P3-N:** ...   (colon directly after number)
# NFRs use the form - **NFR-P3-N (carries ...):** ...  (parenthetical
#                  between number and colon). Match both by anchoring
# on the bullet + bold-open + label, then extracting just the label.
prd_labels="$(printf '%s\n' "$PRD_LINES" | grep -oE '^[0-9]+:- \*\*(FR|NFR)-P3-[0-9]+' | grep -oE '(FR|NFR)-P3-[0-9]+' | sort -u)"
# Story / §-ref regexes match 1+ trailing dot-separated components so
# 4-component citations (e.g., "Story 11.5.1.2", "§3.1.4.1") survive
# extraction intact rather than truncating to the first 3 components.
arch_stories="$(printf '%s\n' "$ARCH_LINES" | grep -oE 'Story [0-9]+(\.[0-9]+)+' | sort -u)"
arch_secs="$(printf '%s\n' "$ARCH_LINES" | grep -oE '§[0-9]+(\.[0-9]+)+' | sort -u)"
comp_secs="$(printf '%s\n' "$COMP_LINES" | grep -oE '§[0-9]+(\.[0-9]+)+' | sort -u)"
prd_h2="$(printf '%s\n' "$PRD_LINES" | grep -E '^[0-9]+:## ' | sed -E 's/^[0-9]+:## //' | sort -u)"
arch_h2="$(printf '%s\n' "$ARCH_LINES" | grep -E '^[0-9]+:## ' | sed -E 's/^[0-9]+:## //' | sort -u)"

#------------------------------------------------------------------------------
# Check (a): FR-P3-N / NFR-P3-N label parity (bidirectional set difference)
#------------------------------------------------------------------------------

# Architecture cites label not defined in PRD.
if [ -n "$arch_labels" ]; then
    while IFS= read -r lbl; do
        [ -z "$lbl" ] && continue
        if ! printf '%s\n' "$prd_labels" | grep -qxF "$lbl"; then
            loc="$(printf '%s\n' "$ARCH_LINES" | grep -E "[^A-Z0-9-]${lbl}([^0-9]|$)" | head -1 | cut -d: -f1)"
            case "$lbl" in
                NFR-*) id="[nfr-label]" ;;
                *)     id="[fr-label]"  ;;
            esac
            printf '%s %s referenced in %s:%s but not labelled in %s\n' \
                "$id" "$lbl" "$ARCH" "${loc:-?}" "$PRD" >&2
            DRIFT=$((DRIFT+1))
        fi
    done <<< "$arch_labels"
fi

# PRD defines label not cited in architecture.
if [ -n "$prd_labels" ]; then
    while IFS= read -r lbl; do
        [ -z "$lbl" ] && continue
        if ! printf '%s\n' "$arch_labels" | grep -qxF "$lbl"; then
            loc="$(printf '%s\n' "$PRD_LINES" | grep -E "[^A-Z0-9-]${lbl}([^0-9]|$)" | head -1 | cut -d: -f1)"
            case "$lbl" in
                NFR-*) id="[nfr-label]" ;;
                *)     id="[fr-label]"  ;;
            esac
            printf '%s %s defined in %s:%s but not referenced in %s\n' \
                "$id" "$lbl" "$PRD" "${loc:-?}" "$ARCH" >&2
            DRIFT=$((DRIFT+1))
        fi
    done <<< "$prd_labels"
fi

#------------------------------------------------------------------------------
# Check (b): Story X.Y citation resolution
#------------------------------------------------------------------------------
# Resolution: a header line matching '^### Story X.Y' followed by ':' (the
# Phase-1..4/6 style, '### Story X.Y: Title') or a space (the Phase-5 style,
# '### Story X.Y — Title'), in any per-phase epics file (epics-phase1..6). The
# trailing [: ] guard still rejects prefix false-matches (X.Y won't match X.Y0).
# Regex matches singular "Story " only; plural "Stories" forms (e.g.,
# "Stories 14.1 / 14.2 / 14.3") are not extracted by this check — they
# are conventionally human prose, not citations the reader follows.

if [ -n "$arch_stories" ]; then
    while IFS= read -r cite; do
        [ -z "$cite" ] && continue
        # cite is "Story X.Y", "Story X.Y.Z", "Story X.Y.Z.W", ...
        # Header pattern: '### <cite>:' (anchored to a line whose
        # content begins '### ' after the awk-injected '<file>:<n>:'
        # prefix in $EPICS_HEADERS).
        if printf '%s\n' "$EPICS_HEADERS" | grep -qE ":### ${cite}[: ]"; then
            continue
        fi
        loc="$(printf '%s\n' "$ARCH_LINES" | grep -E "${cite}([^0-9]|$)" | head -1 | cut -d: -f1)"
        printf "[story-cite] '%s' cited in %s:%s not found as '### %s:' header in epics files\n" \
            "$cite" "$ARCH" "${loc:-?}" "$cite" >&2
        DRIFT=$((DRIFT+1))
    done <<< "$arch_stories"
fi

#------------------------------------------------------------------------------
# Check (c): §X.Y.Z reference parity (advisory pre-A.1; strict post-A.1)
#------------------------------------------------------------------------------
# Tokens cited in architecture.md but absent from compliance doc.
# AC3(c) text qualifies the scope to "compliance-related sections" of
# architecture.md. The implementation scans the entire document because
# all current §-refs in architecture.md are in compliance contexts (the
# document does not use § notation outside ANS Forth section citations);
# the qualifier is satisfied vacuously. If a future architecture revision
# introduces non-compliance §-refs, this check should be tightened.

if [ -n "$arch_secs" ]; then
    while IFS= read -r sec; do
        [ -z "$sec" ] && continue
        if ! printf '%s\n' "$comp_secs" | grep -qxF "$sec"; then
            loc="$(printf '%s\n' "$ARCH_LINES" | grep -F "$sec" | head -1 | cut -d: -f1)"
            if [ "$STRICT_SECTIONS" -eq 1 ]; then
                printf '[§-cite] %s cited in %s:%s but no row in %s\n' \
                    "$sec" "$ARCH" "${loc:-?}" "$COMPLIANCE" >&2
                DRIFT=$((DRIFT+1))
            else
                printf '[advisory-§] %s cited in %s:%s but no row in %s (advisory pre-A.1 / Story 15.1)\n' \
                    "$sec" "$ARCH" "${loc:-?}" "$COMPLIANCE" >&2
                ADVISORY=$((ADVISORY+1))
            fi
        fi
    done <<< "$arch_secs"
fi

#------------------------------------------------------------------------------
# Check (d): Top-level section-name parity (advisory; empty allowlist)
#------------------------------------------------------------------------------
# Both PRD and architecture have ## headers; the docs serve different
# roles, so divergence is not by-itself drift. Items emit as advisory
# until an allowlist of agreed-on shared section pairs is populated.
# Allowlist (one shared name per line; both docs use the same name):
SECTION_ALLOWLIST=""

# Sections in PRD not in architecture.
if [ -n "$prd_h2" ]; then
    while IFS= read -r s; do
        [ -z "$s" ] && continue
        if printf '%s\n' "$arch_h2" | grep -qxF "$s"; then
            continue
        fi
        if printf '%s\n' "$SECTION_ALLOWLIST" | grep -qxF "$s"; then
            continue
        fi
        printf "[advisory-section] '## %s' present in %s but not in %s (allowlist empty)\n" \
            "$s" "$PRD" "$ARCH" >&2
        ADVISORY=$((ADVISORY+1))
    done <<< "$prd_h2"
fi

# Sections in architecture not in PRD.
if [ -n "$arch_h2" ]; then
    while IFS= read -r s; do
        [ -z "$s" ] && continue
        if printf '%s\n' "$prd_h2" | grep -qxF "$s"; then
            continue
        fi
        if printf '%s\n' "$SECTION_ALLOWLIST" | grep -qxF "$s"; then
            continue
        fi
        printf "[advisory-section] '## %s' present in %s but not in %s (allowlist empty)\n" \
            "$s" "$ARCH" "$PRD" >&2
        ADVISORY=$((ADVISORY+1))
    done <<< "$arch_h2"
fi

#------------------------------------------------------------------------------
# Verdict (per AC4: clean / advisory-only / drift)
#------------------------------------------------------------------------------

if [ "$DRIFT" -eq 0 ] && [ "$ADVISORY" -eq 0 ]; then
    printf '[ok] doc-sync: 0 drift\n'
    exit 0
fi

if [ "$DRIFT" -eq 0 ]; then
    printf '[advisory] doc-sync: %d advisory item(s); 0 drift\n' "$ADVISORY"
    exit 0
fi

# DRIFT > 0
printf '[drift] doc-sync: %d drift item(s); %d advisory item(s)\n' "$DRIFT" "$ADVISORY" >&2
exit 1
