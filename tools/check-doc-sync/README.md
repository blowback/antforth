# `tools/check-doc-sync/` — PRD↔architecture transcription-drift checker

Project-local Bash script that detects PRD-vs-architecture transcription
drift across the four canonical Phase-3 planning artefacts. Invocable
directly (`bash tools/check-doc-sync/check-doc-sync.sh`) or via the
Makefile target (`make check-doc-sync`).

Closes carry-forward item **B.5 / PD-3** (Epic 13 retro #2 — "PRD-vs-
architecture transcription drift, doc-build sync step"), originally
identified at `_bmad-output/implementation-artifacts/epic-13-retro-2026-05-05.md`
and catalogued at `docs/PHASE-3-CARRY-FORWARD.md:36`. Authored by
Story 14.5 (the close-out of Epic 14's Phase-3 process-foundation
lead-in cluster).

## Drift checks

The script runs four independent checks against:

- `_bmad-output/planning-artifacts/prd.md`
- `_bmad-output/planning-artifacts/architecture.md`
- `_bmad-output/planning-artifacts/epics.md` (+ `epics-phase1-epics-1-8.md`,
  `epics-phase2-epics-9-13.5.md` for historical citations)
- `docs/ans-forth-core-compliance.md`

### (a) FR-P3-N / NFR-P3-N label parity — strict mode

Bidirectional set difference. Every `FR-P3-N` / `NFR-P3-N` token cited
in `architecture.md` (singletons or inclusive ranges like `FR-P3-22..25`,
which the script expands) must exist as a labelled definition in
`prd.md` of the form `- **FR-P3-N:** ...` or `- **NFR-P3-N (...):** ...`,
and every label defined in `prd.md` must be cited at least once in
`architecture.md`. Orphans in either direction emit `[fr-label]` or
`[nfr-label]` drift items.

### (b) `Story X.Y` citation resolution — strict mode

Every `Story X.Y` citation in `architecture.md` (with one or more
trailing dot-separated components — `Story 14.5`, `Story 11.5.1`,
`Story 11.5.1.2` all match) must resolve to a story header line of
the form `### <cite>:` in one of the three epics files. Unresolved
citations emit `[story-cite]` drift items.

The check matches singular `Story ` only — plural `Stories` (e.g.,
"Stories 14.1 / 14.2 / 14.3") are conventionally human prose, not
citations the reader follows individually, so they are excluded by
design.

### (c) `§X.Y.Z` reference parity — advisory pre-A.1 / strict post-A.1

Every `§N.M…` reference (one or more trailing dot-separated
components — `§6.1`, `§6.2.1342`, `§3.1.4.1` all match) in
`architecture.md` should have a matching row in
`docs/ans-forth-core-compliance.md`. Until Story 15.1 closes the
A.1 §-level structural-rule audit, the compliance doc is incomplete
by design (word-counted, not §-counted), so this check runs in
**advisory mode** by default — items emit as `[advisory-§]` and do
not contribute to the exit code.

The script-internal flag `STRICT_SECTIONS` gates the mode: default
`STRICT_SECTIONS=0` (advisory). Flip to `STRICT_SECTIONS=1` once
Story 15.1 closes A.1 and the compliance doc grows to §-level
coverage; mismatches then become genuine drift.

Scope note: AC3(c) qualifies the check to "compliance-related sections"
of `architecture.md`. The implementation scans the entire document
because all current §-refs in `architecture.md` are in compliance
contexts (the document does not use § notation outside ANS Forth
section citations); the qualifier is satisfied vacuously. If a future
architecture revision introduces non-compliance §-refs, this check
should be tightened.

### (d) Top-level section-name parity — advisory mode (empty allowlist)

Both PRD and architecture have `^## ` (Markdown level-2) section
headers, but the docs serve different roles, so divergence is by
itself not drift. Items emit as `[advisory-section]` until an
allowlist of agreed-on shared section pairs is populated in the
script's `SECTION_ALLOWLIST` variable. The initial allowlist is
empty by design (PRD and architecture currently share no level-2
section names — see Story 14.5 first-run verdict).

## Exit codes

| Exit | Meaning | Output |
|---|---|---|
| `0` | Clean — no drift, no advisory items | stdout: `[ok] doc-sync: 0 drift` |
| `0` | Advisory-only — strict checks clean, advisory items present | stdout: `[advisory] doc-sync: <N> advisory item(s); 0 drift`; stderr: one line per advisory item |
| `1` | Drift — at least one strict-mode check produced a drift item | stderr: one line per drift item plus `[drift] doc-sync: <D> drift item(s); <A> advisory item(s)` |
| `1` | Fatal — required input file missing or unreadable | stderr: `[fatal] required input file missing or unreadable: <path>` |

No other exit codes are produced. The script does not use `set -e`
globally — drift in one check does not abort subsequent checks, so
each invocation produces a complete report.

## Cadence

Run `make check-doc-sync` before any antforth 2.x tag close-out
(S11 sibling — version-surface audit reads cleanly only when doc-sync
also reads cleanly); advisory at any other time.

The target is **advisory-only on `make test-repl`** (does not block
test runs); a clean-pass becomes a documented pre-condition for
tag-applicable close-outs only — see architecture §"Doc-sync (NEW,
opt-in)" at `_bmad-output/planning-artifacts/architecture.md:733`.

## Extending the drift-check surface

To add a new drift check:

1. Read the architecture-pinned spec at
   `_bmad-output/planning-artifacts/architecture.md:272..282`
   (§"B.5-D1: PRD-vs-architecture transcription-drift sync") for the
   contract this tool honours, and §"Tooling boundary" at `:663..667`
   for the language and dependency boundary (Bash + POSIX text-
   processing primitives — no `jq`, no Python, no Node).
2. Pre-extract any new token sets in the "Pre-extract token sets"
   block of `check-doc-sync.sh` (AC2: each input file is read at
   most once per invocation).
3. Add a new check block following the `Check (a)` / `Check (b)` /
   ... pattern. Choose strict (drift contributes to exit code) or
   advisory (counted but does not affect exit) per the architectural
   contract for the new check.
4. Update this README with a new sub-section under "Drift checks"
   documenting the new check and its mode.

The current four checks were pinned by `architecture.md:276..280`
verbatim; new checks beyond those are out-of-scope for Story 14.5
but welcome as future enrichment (the carry-forward catalogue's
B.5-followup row is the right home for a deferred idea — see
`docs/PHASE-3-CARRY-FORWARD.md` §"Status Tracking").

## See also

- **Pinning spec:** `_bmad-output/planning-artifacts/architecture.md:272..282`
  (§"B.5-D1: PRD-vs-architecture transcription-drift sync") +
  `:663..667` (§"Tooling boundary") + `:733` (§"Doc-sync (NEW, opt-in)")
- **PRD requirement:** `_bmad-output/planning-artifacts/prd.md:530`
  (FR-P3-16) + `:587` (NFR-P3-18 — story-template discipline)
- **Carry-forward catalogue:** `docs/PHASE-3-CARRY-FORWARD.md:36`
  (B.5 row) + §"Status Tracking" (closure-tracking shape)
- **Motivating retro item:** `_bmad-output/implementation-artifacts/epic-13-retro-2026-05-05.md`
  PD-3 row in §"Documented Follow-Up Opportunities"
- **Tool-subtree precedent:** `tools/bdos_probe/` (Story 11.5.1.2
  firmware reproducer; first instance of `tools/<name>/` in the
  project — self-contained subdirectory keeps tool logic separable
  from the kernel build).
