---
title: "Polishing the Edges: antforth Epic 23"
description: "A focused standards-and-I/O round that took antforth to v3.1.0 — named values, port words, honest environment queries, and a banking bug the review refused to let ship."
author: Ant (with Paige, tech-writer)
date: 2026-06-29
---

# Polishing the Edges: antforth Epic 23

Phase 4 taught our Z80 Forth to address half a megabyte through one banked window. That was the big, rocky climb. Epic 23 is the opposite kind of work: a single, focused epic that sands the edges of the wordset, closes a handful of ANS conformance gaps, and adds the small ergonomic words you reach for every day.

It ships as **antforth v3.1.0** — the first *minor* release since v3.0, and the close of Phase 5.

## What landed

Five feature stories, plus a release-gate close-out (23.5) that ran the regression suite and cut the tag — each a self-contained increment:

- **Named values (`VALUE` / `TO`).** You can now define a mutable named cell and assign to it by name — `42 VALUE LIVES`, then `LIVES .` prints 42, and `99 TO LIVES` updates it. This is the standard ergonomic middle ground between a `CONSTANT` (immutable) and a `VARIABLE` (you fetch and store through an address). It was the biggest single piece of the epic, because making it bank-aware meant a full resolve/map/unmap trio so a `VALUE` defined in any bank reads and writes correctly.
- **Port I/O (`IN` / `OUT`).** Direct Z80 port reads and writes, surfaced as Forth words for talking to hardware.
- **Honest environment queries (`UD.` and `ENVIRONMENT?` rows).** `UD.` prints an unsigned double. More interestingly, the new `ENVIRONMENT?` rows tell the *truth*: queries for wordsets antforth only partially implements answer `false` ("recognised but incomplete") rather than a flattering `true`. Honesty over a green checkmark.
- **An assembler operand-order fix.** The Z80 assembler's immediate-operand path was corrected to the Zilog destination-source convention. Byte-neutral, but a real correctness fix.
- **A banking guard the review caught (`23.6`).** More on this below — it's the story of the epic.

## The story of the epic: a bug that never shipped

The most valuable thing Epic 23 produced is a bug that *didn't* reach silicon.

antforth's code review runs adversarially, in a fresh context — the standing rule is that a review which finds nothing is suspect, not reassuring. On the named-values and port-words stories, that review surfaced a silent correctness defect: a banked colon definition whose body grew past `$C000` would have its runtime read through the *wrong* bank window. No crash, no error — just quietly wrong results, the worst kind of bug.

That finding became its own story (23.6): a window-top overflow guard. Its own review then caught a second one — a 16-bit wraparound in `ALLOT`. Both would have shipped silently. Neither did.

> **Why this matters.** The temptation in a "polish" epic is to relax the adversary — the work feels low-risk, the reviews feel like ceremony. Epic 23 is the counter-argument: the one story that mattered most for correctness existed *only* because the review refused to relax.

## The byte ledger

Every byte is measured from a clean rebuild and accepted at its story's close. The epic grew the kernel by **+563 bytes**, and free RAM measured on real hardware (24,954 B) independently corroborates that ledger.

| Story | What | Δ bytes |
|---|---|---|
| 23.1 | Assembler operand-order fix (Zilog dst-src) | 0 |
| 23.2 | `VALUE` / `TO` (bank-aware) | +317 |
| 23.3 | `IN` / `OUT` port words | +19 |
| 23.4 | `UD.` + honest `ENVIRONMENT?` rows | +112 |
| 23.6 | Banked window-top overflow guard | +115 |
| | **antforth v3.1.0 total** | **+563** |

The original estimate was ~300 B, so the epic ran about 1.9× over — squarely inside the ~2.4× "cross-bank plumbing always undershoots" multiplier we learned to budget for in Phase 4. The single biggest overrun (`VALUE`/`TO`) is exactly where the bank-aware machinery lives. The pattern keeps confirming itself.

## Process notes

Two habits from Phase 4 carried straight through and paid off again:

- **Hardware is a gate.** Every binary-delta story got a smoke test on a real MicroBeast running CP/M 2.2 before being marked done — zero deferred-smoke debt. Emulators have hidden divergences from silicon before; the habit keeps catching them.
- **The retro closes the loop.** Epic 23's retrospective checked the previous epic's action items and found one that *wasn't* honored: a predicted test-fixture fragility (the `$8000` straddle) recurred twice because it hadn't been pre-empted. That honesty spawned two follow-up stories (a probe-isolation interlude and a narrow banked-`MARKER` guard) — kept deliberately out of the v3.1.0 gate so they don't block the release. It also owned up to a planning miss: two of the four feature stories carried wrong ANS section citations in the epic doc (enumerated from memory rather than the standard), caught at dev time but logged as a process fix for future standards work.

## Where this leaves antforth

v3.1.0 is a tidier, more conformant Forth than v3.0.7: named mutable values, hardware port access, and environment queries that don't oversell themselves — all of it bank-aware, all of it verified on real hardware.

The big platform shifts — a cooperative multitasker, counting semaphores, full ANS locals — are recorded for a future phase, not this one. Epic 23 did the quieter, equally necessary work: making the foundation honest before building higher on it.

---

*antforth is a CP/M-hosted, ANS-leaning Forth for the Z80-based MicroBeast. Epic 23 (Phase 5) was developed with the BMAD method: spec-driven stories, adversarial code review, hardware-gated acceptance, and a closing retrospective.*
