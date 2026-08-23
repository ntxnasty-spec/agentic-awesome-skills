#!/usr/bin/env python3
"""Disposable fixture: does a consumer follow a mutable label past approval?

Reproduces the approve-then-execute handoff for an agent plan and applies a
post-approval mutation, then dispatches the plan through two consumers:

  * ``LabelResolvingConsumer``  - resolves the plan by its mutable label and
    trusts the ``approved`` flag it finds there.
  * ``DigestVerifyingConsumer`` - dereferences the label, recomputes the digest
    over the bytes it actually holds, and compares against the binding receipt
    before dispatching anything.

Everything here is synthetic and inert. Steps name fake tools, no tool is
invoked, no network or filesystem effect occurs, and the store is rebuilt from
scratch on every run, so the fixture is deterministic and self-rolling-back.

Run:  python3 toctou_fixture.py
Exit: 0 when the fixture reproduces the expected split (label consumer
      dispatches unbound content, digest consumer refuses), 1 otherwise.
"""

from __future__ import annotations

import hashlib
import json
from copy import deepcopy
from dataclasses import dataclass, field
from typing import Any


# --------------------------------------------------------------------------
# Canonical form and digest
# --------------------------------------------------------------------------

# Fields that change what a step actually does. Anything outside this set is
# presentation only and is excluded from the canonical form on purpose.
BOUND_FIELDS = ("step_id", "tool", "arguments", "resources")


def canonical_bytes(plan: dict[str, Any]) -> bytes:
    """Serialize the behavior-bearing content of a plan, stably.

    Key order is fixed, separators are tight, and non-binding metadata (labels,
    timestamps, review notes) is dropped so that equal behavior always yields
    equal bytes.
    """
    core = {
        "plan_kind": plan["plan_kind"],
        "steps": [
            {k: step[k] for k in BOUND_FIELDS}
            for step in plan["steps"]
        ],
    }
    return json.dumps(core, sort_keys=True, separators=(",", ":")).encode("utf-8")


def plan_digest(plan: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(canonical_bytes(plan)).hexdigest()


# --------------------------------------------------------------------------
# Store, receipt, and event capture
# --------------------------------------------------------------------------


@dataclass
class BindingReceipt:
    """What approval actually attests to: a digest, not a name."""

    label: str
    approved_digest: str
    principal: str


@dataclass
class PlanStore:
    """A mutable store. Labels are stable; the content under them is not."""

    plans: dict[str, dict[str, Any]] = field(default_factory=dict)
    events: list[str] = field(default_factory=list)

    def put(self, label: str, plan: dict[str, Any]) -> None:
        self.plans[label] = deepcopy(plan)

    def resolve(self, label: str) -> dict[str, Any]:
        self.events.append(f"store.resolve({label})")
        return deepcopy(self.plans[label])


# --------------------------------------------------------------------------
# Consumers
# --------------------------------------------------------------------------


class LabelResolvingConsumer:
    """Resolves by label, trusts the flag it finds. The vulnerable pattern."""

    name = "LabelResolvingConsumer"

    def dispatch(self, store: PlanStore, receipt: BindingReceipt) -> dict[str, Any]:
        plan = store.resolve(receipt.label)
        # The only gate: an attribute carried *on the object itself*.
        if not plan.get("approved"):
            return {"consumer": self.name, "outcome": "refused", "reason": "not approved"}
        fired = [f"{s['tool']}({s['resources']})" for s in plan["steps"]]
        return {
            "consumer": self.name,
            "outcome": "dispatched",
            "dispatched_digest": plan_digest(plan),
            "steps_fired": fired,
        }


class DigestVerifyingConsumer:
    """Dereferences, recomputes, compares at the dispatch boundary."""

    name = "DigestVerifyingConsumer"

    def dispatch(self, store: PlanStore, receipt: BindingReceipt) -> dict[str, Any]:
        plan = store.resolve(receipt.label)
        observed = plan_digest(plan)
        if observed != receipt.approved_digest:
            return {
                "consumer": self.name,
                "outcome": "refused",
                "reason": "digest mismatch",
                "approved_digest": receipt.approved_digest,
                "observed_digest": observed,
                "diff": diff_steps(receipt, plan),
            }
        fired = [f"{s['tool']}({s['resources']})" for s in plan["steps"]]
        return {
            "consumer": self.name,
            "outcome": "dispatched",
            "dispatched_digest": observed,
            "steps_fired": fired,
        }


def diff_steps(receipt: BindingReceipt, plan: dict[str, Any]) -> list[str]:
    """Name what changed, per step, rather than failing generically."""
    approved = APPROVED_SNAPSHOT.get(receipt.approved_digest, {"steps": []})["steps"]
    current = plan["steps"]
    out: list[str] = []
    by_id_old = {s["step_id"]: s for s in approved}
    by_id_new = {s["step_id"]: s for s in current}
    for sid in sorted(set(by_id_old) | set(by_id_new)):
        old, new = by_id_old.get(sid), by_id_new.get(sid)
        if old is None:
            out.append(f"{sid}: step inserted (tool={new['tool']})")
        elif new is None:
            out.append(f"{sid}: step removed")
        else:
            for f in BOUND_FIELDS:
                if old[f] != new[f]:
                    out.append(f"{sid}.{f}: {old[f]!r} -> {new[f]!r}")
    old_order = [s["step_id"] for s in approved]
    new_order = [s["step_id"] for s in current]
    if old_order != new_order and sorted(old_order) == sorted(new_order):
        out.append(f"order: {old_order} -> {new_order}")
    return out


# Snapshot of approved content, keyed by digest, so the fixture can render a
# field-level diff. A real system stores this in content-addressed storage.
APPROVED_SNAPSHOT: dict[str, dict[str, Any]] = {}


# --------------------------------------------------------------------------
# Fixture
# --------------------------------------------------------------------------


def build_plan() -> dict[str, Any]:
    return {
        "plan_kind": "synthetic-fixture-plan",
        "label": "plan/demo-001",
        "approved": False,
        "steps": [
            {
                "step_id": "s1",
                "tool": "fixture.read",
                "arguments": {"mode": "list"},
                "resources": ["fixture://records/alpha"],
            },
            {
                "step_id": "s2",
                "tool": "fixture.summarize",
                "arguments": {"length": "short"},
                "resources": ["fixture://records/alpha"],
            },
        ],
    }


def mutate_after_approval(plan: dict[str, Any]) -> dict[str, Any]:
    """The pending change: broaden a step's scope and insert a new one."""
    plan = deepcopy(plan)
    # Broaden: one record -> the whole collection.
    plan["steps"][0]["resources"] = ["fixture://records/*"]
    # Insert: a step that never went through review.
    plan["steps"].append(
        {
            "step_id": "s3",
            "tool": "fixture.export",
            "arguments": {"destination": "fixture://outbox"},
            "resources": ["fixture://records/*"],
        }
    )
    return plan


def main() -> int:
    store = PlanStore()

    # 1. Author the plan and compute what review would bind to.
    plan = build_plan()
    approved_digest = plan_digest(plan)
    APPROVED_SNAPSHOT[approved_digest] = deepcopy(plan)

    # 2. Synthetic approval. This stands in for a review decision; it is a
    #    fixture value, not a record that any person approved anything.
    plan["approved"] = True
    receipt = BindingReceipt(
        label=plan["label"],
        approved_digest=approved_digest,
        principal="synthetic-reviewer@fixture.invalid",
    )
    store.put(receipt.label, plan)

    # 3. The post-approval mutation lands under the same label. Note that the
    #    `approved` flag rides along untouched — that is the whole problem.
    mutated = mutate_after_approval(store.resolve(receipt.label))
    assert mutated["approved"] is True
    store.put(receipt.label, mutated)
    live_digest = plan_digest(mutated)

    # 4. Dispatch through both consumers.
    results = [
        LabelResolvingConsumer().dispatch(store, receipt),
        DigestVerifyingConsumer().dispatch(store, receipt),
    ]

    report = {
        "approved_digest": approved_digest,
        "live_digest": live_digest,
        "digests_equal": approved_digest == live_digest,
        "principal": receipt.principal,
        "results": results,
        "store_events": store.events,
    }
    print(json.dumps(report, indent=2, sort_keys=True))

    label_res, digest_res = results
    ok = (
        label_res["outcome"] == "dispatched"
        and label_res["dispatched_digest"] != approved_digest
        and digest_res["outcome"] == "refused"
    )
    print()
    print(
        "FIXTURE RESULT: "
        + (
            "reproduced - label resolver dispatched unbound content; "
            "digest resolver refused."
            if ok
            else "NOT reproduced - check the fixture."
        )
    )
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
