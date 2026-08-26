# Vendored third-party sources

This directory holds complete upstream repositories vendored into AAS. Code here is
**third-party**: it is not part of the AAS skill catalog, is not covered by the
repository's skill contracts, and is not published to npm (the root `package.json`
`files` allowlist excludes it).

## Boundary rules

- Nothing under `vendor/` is a skill. `skills/` remains the only source of skill IDs;
  every validator, catalog build, and security scan in this repository is scoped to
  `skills/` and ignores this tree.
- Do not edit vendored files to fix AAS-side problems. Changes belong upstream, or in
  an AAS-side wrapper outside `vendor/`.
- Local edits, if ever unavoidable, must be recorded in this file so the next update
  can re-apply them.
- Vendored `.github/workflows/` files are inert: GitHub only runs workflows from the
  repository root.

## Contents

| Path | Upstream | Pinned commit | License |
| --- | --- | --- | --- |
| `kit/` | [anayatkhan1/kit](https://github.com/anayatkhan1/kit) (AgentCN) | `59d7ebc6064f718fb320f005e017c12bc4bd80c6` | MIT **with an additional resale restriction** — see [`kit/LICENSE`](kit/LICENSE) |

### kit/ — AgentCN

An Nx + pnpm monorepo for installable AI agents, distributed through the `agentcn` CLI.

- `ai/agents/{web,extraction,ecommerce}/` — agent sources (Vercel AI SDK + Anthropic Claude)
- `packages/agentcn/cli/` — the `agentcn` npm package (`npx agentcn add <agent>`)
- `apps/web/` — Next.js docs site and registry host (agentcn.dev)
- `registry/` — registry declarations built into `apps/web/public/r/<agent>.json`
- `.agents/skills/` — the upstream repo's own agent skills (Nx-managed plus `build-agent`)

Flow: agent source in `ai/agents/` → registry build → `apps/web/public/r/<agent>.json` →
`npx agentcn add` installs into a consumer repo.

It uses its own toolchain (pnpm 9, Nx 22, Jest) which is **independent** of the AAS root
toolchain (npm, Python). Root `npm ci` does not install it; there are no npm workspaces
declared at the root. To work on it:

```bash
cd vendor/kit
pnpm install
pnpm test          # or: pnpm web, pnpm agentcn:registry:build
```

Running the agents requires API keys — at minimum `ANTHROPIC_API_KEY`, plus
`EXA_API_KEY` and `ANCHOR_API_KEY` (web agent) or `FIRECRAWL_API_KEY` (ecommerce agent).
See `kit/README.md`.

#### License notice

`vendor/kit/` is **not** plain MIT. On top of the MIT grant, its LICENSE forbids selling
unmodified or only minimally modified copies and requires the original version to stay
publicly available for free. That term travels with these files and is narrower than the
MIT license at the root of this repository. Keep `vendor/kit/LICENSE` intact and honor it
in anything derived from this tree.

## Updating

Vendored with `git subtree` (squashed), so upstream history stays out of the AAS log
while the exact source commit is recorded in the squash commit's `git-subtree-split`
trailer.

```bash
git remote add kit-upstream https://github.com/anayatkhan1/kit.git   # once
git subtree pull --prefix=vendor/kit kit-upstream main --squash
```

Then update the pinned commit in the table above in the same commit.
