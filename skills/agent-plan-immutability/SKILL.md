---
name: agent-plan-immutability
description: "Use when a reviewed and approved agent plan (ordered steps, tools, arguments, resources, approvals, plan digest) must reach an executor unchanged, to stop a step being inserted, removed, reordered, or broadened after approval and before execution."
risk: safe
source: self
date_added: "2026-08-23"
---

# Agent Plan Immutability

## Overview

Human review approves one specific plan instance: its ordered steps, the tools and arguments each step invokes, the resources it touches, the approvals attached to it, and a digest that fingerprints all of that together. Between approval and execution there is a window where the plan object can be edited in place — a step inserted, removed, reordered, or broadened in scope — while the approval record and any "approved" label stay attached to it. If the executor trusts the label instead of the content, it runs a plan nobody actually reviewed. This is a time-of-check-to-time-of-use (TOCTOU) gap, and it applies to agent plans the same way it applies to file permissions or payment authorizations.

This skill designs and reviews the control that closes that gap: bind approval to a content digest, treat the plan as immutable once that digest is computed, and make the executor verify the digest of the exact instance it is about to run before it runs it. It does not perform the review itself and does not build the executor; it makes sure the reference connecting them cannot be reused for one plan while pointing at another.

## When to Use

- Designing or reviewing an approval-then-execution pipeline for agent plans, tool-call batches, or automation runbooks.
- An executor accepts a plan ID, ticket number, or mutable object reference rather than a content digest.
- Adding a "quick edit" path (fix an argument, reorder a step, widen a resource scope) after approval and before a run.
- Investigating an incident where an executed plan differs from what a reviewer approved.

Do not use it to design the review policy itself (who approves, what criteria justify approval) or to implement plan generation. It governs the handoff between an already-produced approval and an already-built executor.

## Identify the Object and Its Boundary

Name the exact object under control before writing any check:

- **The object**: one agent plan — ordered steps, the tool and arguments bound to each step, the resources and permissions each step needs, the approvals recorded against it, and a digest computed over all of the above.
- **The suitability property**: an instance is executable only if its current content digest equals the digest that was actually reviewed and approved — not merely if it carries an "approved" flag, status field, or foreign key to an approval record.
- **The destination**: the executor's dispatch boundary — the point where a step's tool call actually fires. This is the only place staleness matters; earlier reads (rendering a diff, queuing a job) are not the use boundary.
- **The result**: the executor either runs the reviewed instance and produces a run record that cites the approved digest, or it refuses to run and reports exactly which field changed.

Keep these four fixed for the rest of the design. A control that checks a different object than it enforces at the destination (e.g., approves a rendered summary but executes a live object) does not close the gap.

## Bind Approval to Content, Not to Identity

- Compute the digest over a canonical serialization of steps, tools, arguments, resources, and any approval metadata that changes step behavior (e.g., an approved argument override). Canonicalize first — stable key ordering, no floating timestamps, no server-generated fields — so equal content always hashes equal.
- Record the digest on the approval, not just a mutable plan ID or row identifier. An ID can be reused after edits; a digest cannot.
- Any insert, removal, reorder, or scope broadening produces a new digest and is, by definition, a different plan requiring its own approval. There is no such thing as a "minor edit" to an approved plan — only a new plan that may or may not clear the same bar quickly.
- Store the plan content itself as immutable once approved: write-once storage, a content-addressed object store keyed by the digest, or a frozen/read-only in-memory structure. If the storage layer allows in-place field updates on an approved row, the digest binding is cosmetic.

## Enforce the Check at the Use Boundary

- The executor recomputes the digest of the instance it is about to dispatch and compares it to the approved digest immediately before the first tool call fires — not at plan submission, not at queue time, not at UI render time. A check performed anywhere earlier leaves a window for exactly the mutation this control exists to catch.
- On mismatch, refuse execution and report the specific fields that changed (which step, which argument, which resource) rather than a generic "plan invalid." Silent re-approval or auto-repair defeats the control as surely as skipping the check.
- Treat resolution and dereferencing consistently: if the plan is passed by reference (a URL, object key, or handle), the executor must fetch the referenced content and hash *that*, not trust a digest field carried alongside the reference — a caller can supply a stale reference next to a fresh, false digest.
- Log the digest actually executed, alongside the approval it satisfied, in the run record. This is what lets a later audit answer "did the plan that ran match the plan that was reviewed?" without re-deriving it from partial traces.

## Handling Legitimate Post-Approval Changes

A real need to change an approved plan is common — a resource moved, an argument needs a fix, a step should be dropped. Route every such change through the same approval path the original plan used, producing a new digest and a new approval, rather than a privileged "patch" path that mutates the approved object. Fast-tracking a re-approval (e.g., delta review against the prior digest) is reasonable; skipping it because the change looks small is the exact failure this skill exists to prevent.

## Common Mistakes

- Approving a plan by its ID or object reference, then executing whatever content that ID currently resolves to.
- Computing the digest at approval time but never recomputing it at dispatch time, so the check exists but never actually gates use.
- Allowing broadening edits (added tool, wider resource scope, added step) through the same "already approved, just tweaking" path as cosmetic edits.
- Treating an approval-record lookup ("does an approval exist for this plan?") as equivalent to a content match ("does this plan's digest match the one that was approved?").
- Auto-repairing or silently re-approving on a digest mismatch instead of stopping and reporting the diff.
- Hashing a reference or pointer to the plan instead of hashing the dereferenced content it currently points to.

## Limitations

- This control proves the executed instance matches what was reviewed; it says nothing about whether the review itself was adequate.
- Canonicalization must be maintained as the plan schema evolves — a new field that is not included in the canonical form is a field that can be changed post-approval without detection.
- Immutability at the storage layer is only as strong as the access controls around it; a control with write access to "immutable" storage can still bypass this guarantee.
