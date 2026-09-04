---
date: 2026-09-04
topic: Agent-to-agent handoff rules and the ADR scaffold
area: cross
tags: [docs, adr, agents-md, devsolo]
---

## What went badly
- A new hand-off channel ("copy the session's lessons into every sub-agent brief") was
  written into the workflow before anyone priced it. The user caught it: ten lines copied
  once costs ~150 tokens, the same list fetched by three executors costs ~900 — the
  "optimisation" was twice the price of the thing it replaced, and the rule had to be
  rewritten mid-plan.
- Two scripted edits failed on their anchors: one matched `первопричину` where the file
  said `первопричина`, another looked for the `phase` values table in `SKILL.md` when it
  lives in `references/beads.md`. Both anchors were typed from memory instead of copied
  out of the file, and both aborted the whole patch run.
- The new setup catalogue promised readers that did not exist: it listed "lessons journal
  — read by the refiner", "ADR — read by the evaluator", "design system — read by
  executors", while none of those agents' prompts mentioned those files. A second pass was
  needed to wire the readers — right after writing the rule "a file is only created when it
  has a reader".

## Root cause
- A hand-off rule was judged by how clean it looked, not by who pays for it and how many
  times; the cost was never written down, so the trade-off was invisible until someone
  else did the arithmetic.
- Anchors for exact-match edits were reconstructed from memory across a context boundary,
  where inflection and line wrapping differ from the file by one character.
- The catalogue was written from the point of view of the document ("what should exist")
  instead of the point of view of the consumer ("who opens this, and when") — so the
  producer side was specified and the consumer side silently assumed.

## Rule — do this next time
- Before adding any channel that moves data between agents, write down who pays and how
  often: copy short and fixed payloads into the brief, pass an address only when the
  payload is long or grows — and say in the same line what to read from it.
- Copy exact-match anchors straight out of the file (`grep -n` / `sed -n`), never retype
  them; verify the anchor exists before running a multi-file patch, so one miss does not
  abort the batch.
- When a document requires an artefact, wire its reader in the same session — name the
  agent or step that opens it, and add the instruction there; a required file with no
  reader is documentation that rots while being trusted.
