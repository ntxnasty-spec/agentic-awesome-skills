# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

Agentic Awesome Skills (AAS) is a curated library of 2,000+ agent "skills" (`SKILL.md` playbooks) for coding
agents (Claude Code, Cursor, Codex CLI, Gemini CLI, Antigravity, Kiro, Copilot, etc.), plus:

- **AAS Core** — a local, read-only MCP server + CLI (`tools/lib/aas-v1/`) that lets an agent search the
  catalog, compose a validated `aas-stack.json` selection, and produce an immutable install plan. Core
  validates structure/identity only — never semantic fit, compatibility, or safety.
- **Generated registry artifacts** — `CATALOG.md`, `skills_index.json`, `data/*.json`, `plugins/**`,
  `apps/web-app/public/*` — all derived from `skills/**` by the `npm run chain` pipeline. Never hand-edit
  these; edit the source (`skills/<id>/SKILL.md`) and regenerate.
- **A hosted catalog app** (`apps/web-app/`, Vite + React) that browses the generated skills index.

## Commands

```bash
npm ci                      # install root deps
npm run validate            # validate SKILL.md frontmatter/sections/schema rules
npm run validate:strict     # same, strict mode (used for release gating)
npm run security:docs       # safety checks on command/install/credential/network guidance
npm run test                # run the full repo script test suite (Node + Python)
npm run build                # == npm run chain: regenerate all indexes/catalog
```

Standard pre-PR check: `npm run validate && npm run test && npm run security:docs`.

### Running a single test

The suite mixes Node (`*.test.js`, `node:test`) and Python (`test_*.py`, `unittest`) files under
`tools/scripts/tests/`. Run one directly rather than through the full suite runner:

```bash
node tools/scripts/tests/aas_v1_core.test.js          # single Node test file
python -m unittest tools/scripts/tests/test_audit_skills.py   # single Python test file
npm run test:aas-v1                                    # all aas_v1_*.test.js (node --test)
npm run test:local                                      # full suite, network tests skipped
npm run test:network                                     # includes live Microsoft-source network tests
```

Network tests (Microsoft-source sync checks) only run when `ENABLE_NETWORK_TESTS=1`; local runs skip them
by default.

### Web app (`apps/web-app/`)

```bash
npm run app:install     # cd apps/web-app && npm ci
npm run app:dev         # setup + start Vite dev server
npm run app:build       # setup + build + prerender
npm run app:test        # vitest --run
npm run app:test:coverage
```

### Regenerating derived state

`npm run chain` runs, in order: `validate` → `plugin-compat:sync` → `index` → `bundles:sync` →
`sync:metadata` → `catalog` → `build:aas-v1-catalog`. Broader release-prep variants
(`sync:release-state`, `sync:repo-state`, `sync:repo-state:full`) additionally sync web assets,
contributors, run `audit:consistency`, and check the validation warning budget. Run the narrowest command
that covers what you changed — don't run full release-state syncs for a single skill edit.

## Architecture

### Skill source of truth

Every skill lives at `skills/<skill-id>/SKILL.md` (lowercase-hyphenated ID matching the folder name),
optionally alongside `examples/`, `scripts/`, `templates/`, `references/`. Required frontmatter: `name`,
`description`, `category`, `risk` (`none|safe|critical|offensive|unknown`), `source`, `date_added`. Skills
importing external material must also set `source_repo` + `source_type` (`official|community|self`) — CI
checks that the repo is credited in `README.md` under the matching section, and blocks the PR if not.
`risk: offensive` skills must carry an "Authorized Use Only" warning. See
`docs/contributors/skill-anatomy.md` and `docs/contributors/skill-template.md` for the full content
contract, and `docs/contributors/quality-bar.md` / `docs/contributors/security-guardrails.md` for review
standards.

### Generated/mirrored layers (never hand-edit)

- `skills_index.json`, `data/catalog.json`, `data/*.json`, `CATALOG.md` — built from `skills/**` by
  `tools/scripts/generate_index.py` and `tools/scripts/build-catalog.js`.
- `plugins/agentic-awesome-skills/` and `plugins/agentic-awesome-skills-claude/` — mirrored distributions
  of canonical skill content, packaged as Claude Code plugins per `.claude-plugin/marketplace.json`. When
  canonical `skills/<id>/SKILL.md` content changes, check whether these mirrors need
  `plugin_compatibility.py` sync.
- `apps/web-app/public/skills.json*` — copied from `skills_index.json` via `update:skills`.

Community/source PRs must stay **source-only**: don't include `CATALOG.md`, `skills_index.json`, or
`data/*.json` diffs — CI enforces this. Regenerating and committing those is maintainer/release work done
through the scripted `chain`/`release:*` flow, not ad hoc edits.

### AAS Core (`tools/lib/aas-v1/`)

The MCP server/CLI implementation, organized by concern:
- `catalog.js`, `search.js`, `schema-validator.js` — read-only catalog access and validation against
  `schemas/aas-v1/*.schema.json`.
- `selection.js`, `stack/` — turns an agent's chosen skill IDs into a validated `aas-stack.json` (manifest
  + plan), capped at 128 skills.
- `evidence.js` — optional `aas-selection-evidence.json` sidecar recording selection process/rationale.
- `adapters/` — per-target output shaping (`claude.js`, `codex.js`, generic `values.js`).
- `transaction/` — durable journal/state machine for apply/rollback (experimental, opt-in; not part of the
  supported safety claim).
- `mcp/` — the stdio MCP server (`aas-mcp` bin) exposing `search_skills`, `get_skill`, `compose_stack`,
  `inspect_stack`, `diff_stack`, `export_selection_evidence`, `inspect_selection_evidence`.
- `cli/main.js` — the `aas` CLI (`aas stack validate`, `aas stack plan`, etc.), invoked via `tools/bin/aas.js`.

AAS Core is read-only/advisory: it validates structure and identity of an agent's own selection: it does
not rank, recommend, or certify semantic fit. Keep that distinction in mind when touching this code —
"validation passed" never means "safe to apply."

### Tooling layout

- `tools/scripts/*.py` — validation, audit, and sync scripts (Python), run via
  `tools/scripts/run-python.js` (a Node wrapper that locates the right `python`/`python3`).
- `tools/scripts/*.js` / `*.cjs` — Node build/catalog/release/PR-workflow scripts.
- `tools/scripts/tests/` — the combined Node + Python test suite (see "Running a single test" above).
- `tools/schemas/`, `schemas/` — JSON Schemas for skill scores, the skills index, and AAS Core artifacts
  (plan, manifest, journal, evidence, etc.), validated with `ajv`.

### Maintainer-only workflows

Repository maintenance sweeps, PR merge batches, canonical synchronization, and releases follow a scripted,
gated workflow described in `AGENTS.md` (see "Mandatory Maintainer Workflow") and the
`antigravity-maintainer-batch-release` skill (`skills/antigravity-maintainer-batch-release/SKILL.md`) — this
is a hard gate for that class of work, not a suggestion. `main` is pull-request-only; merges go through
`npm run merge:batch`; releases go through `release:preflight` / `release:prepare` / `release:publish`
(`tools/scripts/release_workflow.js`). Don't hand-push to `main` or hand-edit version/generated surfaces
for release work.

## Conventions

- Skill IDs and folders: lowercase-hyphenated, ID must equal folder name.
- Commit subjects follow conventional style: `feat: ...`, `fix: ...`, `docs: ...`, `chore: release ...`.
- New tests are named after the behavior under test (e.g. `installer_filters.test.js`,
  `test_validate_skills_strict.py`) and live in `tools/scripts/tests/`.
- Respect deeper `AGENTS.md` files inside skill subtrees if present — they take precedence locally.
- For a changed `SKILL.md`, a real Tessl `review` result and `manual-review-required` are not the same
  thing; the latter means Tessl didn't run and a maintainer must review against the exact head SHA before
  merge.
