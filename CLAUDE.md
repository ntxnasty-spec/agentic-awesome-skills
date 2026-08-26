# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Agentic Awesome Skills (AAS)** is a comprehensive catalog of 2,025+ reusable skills for AI coding agents (Claude Code, Cursor, Gemini CLI, Codex, Copilot, etc.).

**AAS Core** (current preview version v15.16.0) provides agent-first skill composition:
- Local MCP server for skill discovery and validation
- Agent-owned stack composition with verification
- Reproducible stack manifests (`aas-stack.json`)
- CLI-based validation and planning
- Workbench for visual review

**Key Value:**
- Skills are not ranked or recommended by AAS—agents choose exact skills they need
- Complete local catalog search (no external uploads)
- Durable artifacts (stack manifest + optional evidence) for review before any changes
- 2,025+ skills across development, testing, security, infrastructure, product, and marketing

## Repository Structure

```
├── skills/                          # 2,025+ individual skill definitions
│   ├── skill-name/
│   │   └── SKILL.md                # Skill playbook (instructions for agents/tools)
│   ├── loki-mode/                  # Example: multi-agent autonomous startup system
│   └── [1900+ more skills]
├── plugins/                         # Pre-curated skill collections
│   ├── agentic-awesome-skills-claude/    # Claude Code specific skills
│   ├── agentic-awesome-skills/           # General AAS plugin
│   ├── agentic-bundle-*-*/               # Domain-specific bundles (DevOps, ML, Security, etc.)
│   └── [50+ more bundles]
├── apps/
│   └── web-app/                    # React/Vite web app (skill workbench UI)
│       ├── src/
│       ├── package.json
│       └── vite.config.js
├── tools/
│   ├── bin/                        # CLI entry points
│   │   ├── aas.js                  # Main AAS CLI
│   │   ├── aas-mcp.js              # MCP server entry
│   │   └── install.js              # Npm install script
│   ├── lib/                        # Core logic
│   │   └── aas-v1/                 # AAS v1 catalog & CLI implementation
│   ├── scripts/                    # Build and validation scripts
│   │   ├── validate_skills.py      # Validate all skills against schema
│   │   ├── audit_skills.py         # Audit skill quality and completeness
│   │   ├── build-catalog.js        # Generate skills_index.json
│   │   ├── generate_index.py       # Index generation
│   │   ├── plugin_compatibility.py # Check plugin compatibility
│   │   ├── sync_editorial_bundles.py # Bundle sync
│   │   ├── sync_repo_metadata.py   # Metadata sync
│   │   ├── security_scanner.py     # Security checks
│   │   ├── detect_drift.py         # Detect skill changes
│   │   ├── tests/                  # Test suite
│   │   └── [20+ more scripts]
│   ├── schemas/                    # JSON schemas for validation
│   │   └── aas-v1/                 # AAS v1 schema definitions
│   ├── config/                     # Configuration files
│   ├── templates/                  # Templates for new skills
│   └── requirements.txt            # Python dependencies
├── data/                           # Generated data (don't edit manually)
│   ├── catalog.json                # Complete skill catalog metadata
│   ├── plugin-compatibility.json   # Plugin compatibility matrix
│   └── aas-v1/                     # AAS v1 offline catalog
├── docs/                           # User and contributor documentation
│   ├── users/                      # User guides (AAS Core, CLI, etc.)
│   └── contributors/               # Contributor guides
├── .github/
│   ├── workflows/                  # CI/CD workflows
│   │   ├── ci.yml                  # Main CI pipeline
│   │   ├── skill-review.yml        # Automated skill review
│   │   ├── publish-npm.yml         # NPM publication
│   │   ├── pages.yml               # GitHub Pages deployment
│   │   └── [more workflows]
│   ├── MAINTENANCE.md              # Maintenance procedures
│   └── pull_request_template.md
├── CONTRIBUTING.md                 # Contributor guide
├── README.md                        # Main documentation
├── CATALOG.md                       # Auto-generated skill catalog (for browsing)
├── CHANGELOG.md                     # Version history
├── package.json                     # Root dependencies + npm scripts
└── skills_index.json               # Generated skill index (used by web app)
```

## Essential Commands

### Validation & Auditing

```bash
# Validate all skills against schema (catches common errors)
npm run validate

# Strict validation with detailed warnings
npm run validate:strict

# Audit skill quality (completeness, metadata, patterns)
npm run audit:skills

# Strict audit with detailed findings
npm run audit:skills:strict

# Security scan (checks for dangerous patterns in skill guidance)
npm run security:scan
npm run security:scan:strict

# Validate skill references/links
npm run validate:references

# Detect drift in skill definitions
npm run drift:check
```

### Building & Syncing

```bash
# Full build pipeline (validates, indexes, syncs plugins, generates catalog)
npm run build
npm run sync:all    # Same as above

# Update generated files without running full pipeline
npm run index       # Generate skills_index.json
npm run catalog     # Generate CATALOG.md

# Sync plugin compatibility matrix
npm run plugin-compat:sync
npm run plugin-compat:check

# Sync editorial bundles
npm run bundles:sync
npm run bundles:check

# Update README with current stats
npm run sync-readme

# Sync repository metadata
npm run sync:metadata

# Generate AAS v1 offline catalog
npm run build:aas-v1-catalog
npm run check:aas-v1-catalog
```

### Testing

```bash
# Run complete test suite (local only)
npm run test
npm run test:local

# Run tests with network access
npm run test:network

# Test AAS v1 catalog functionality
npm run test:aas-v1
```

### Web App Development

```bash
# Setup web app (copy skills index, install dependencies)
npm run app:setup

# Install web app dependencies
npm run app:install

# Development server
npm run app:dev

# Build for production
npm run app:build

# Preview production build
npm run app:preview

# Run tests
npm run app:test

# Run tests with coverage
npm run app:test:coverage
```

### Release & Publishing

```bash
# Preflight checks before release
npm run release:preflight

# Prepare release (update version, changelog)
npm run release:prepare

# Publish to npm
npm run release:publish

# Generate npm package
npm run build:aas-v1-catalog
```

### PR & Review Helpers

```bash
# Run PR preflight checks
npm run pr:preflight

# Generate evidence for changed skills (for PR review)
npm run pr:evidence

# Create PR decision manifest
npm run pr:decision

# Batch merge helper
npm run merge:batch
```

### Maintenance

```bash
# Fix missing skill sections
npm run fix:missing-sections

# Fix missing skill metadata
npm run fix:missing-metadata

# Clean up synthetic sections
npm run cleanup:synthetic-sections

# Fix truncated descriptions
npm run fix:truncated-descriptions

# Sync Microsoft official skills
npm run sync:microsoft
npm run sync:all-official

# Sync contributor information
npm run sync:contributors
```

## Skill Development Workflow

### Understanding Skill Structure

A skill (SKILL.md) contains:
1. **Title & Overview** - What the skill does
2. **Trigger Conditions** - When an agent should use this
3. **Key Concepts** - Important context
4. **Step-by-Step Instructions** - Detailed workflow for agents
5. **Examples** - Real-world use cases
6. **Edge Cases & Guardrails** - What to watch out for
7. **Related Skills** - Links to complementary skills

### Creating a New Skill

```bash
# 1. Create skill directory
mkdir -p skills/my-awesome-skill

# 2. Copy canonical template
cp docs/contributors/skill-template.md skills/my-awesome-skill/SKILL.md

# 3. Edit with your skill content
# Follow the template structure

# 4. Validate your skill
npm run validate

# 5. For skills with shell/network guidance, also run:
npm run security:docs
```

### Key Skill Conventions

- **Filename**: SKILL.md (uppercase, in skill directory)
- **Naming**: Descriptive, lowercase-with-hyphens directory names
- **Format**: Markdown with structured sections
- **Length**: Aim for <500 lines (use references/ subdirectory for detailed docs)
- **No Generated Files**: Don't include CATALOG.md, skills_index.json, or data/*.json
- **Security**: Clearly mark shell operations, network calls, credentials, mutations
- **Versioning**: Include version in header if maintained; follow semver for updates

### Skill Validation

Automated checks verify:
- ✓ Proper markdown structure
- ✓ Required sections present
- ✓ Metadata completeness
- ✓ No dangerous patterns in guidance (without warnings)
- ✓ Reference validity
- ✓ Schema compliance

If validation fails:
```bash
# Check detailed errors
npm run validate:strict

# Try auto-fixes (use cautiously)
npm run fix:missing-sections
npm run fix:missing-metadata
```

## Architecture & Key Patterns

### AAS Core MCP Protocol

The local MCP server (`aas-mcp`) exposes read-only tools for agent skill discovery:

1. **`search_skills`** - Search catalog by keywords, tags, patterns
2. **`get_skill`** - Retrieve full skill definition
3. **`compose_stack`** - Validate agent-selected skills (in-memory, no writes)
4. **`inspect_stack`** - Review existing stack manifest
5. **`diff_stack`** - Compare stack versions
6. **`export_selection_evidence`** - Record selection rationale
7. **`inspect_selection_evidence`** - Review evidence trail

**Key Principle:** The MCP is read-only. Agents compose; humans (or CLI) persist.

### Catalog Structure

Skills are indexed in `skills_index.json` (auto-generated):

```json
{
  "skills": {
    "skill-id": {
      "id": "skill-id",
      "name": "Skill Name",
      "description": "Short description",
      "tags": ["tag1", "tag2"],
      "triggers": ["when X", "for Y"],
      "path": "skills/skill-id/SKILL.md"
    }
  }
}
```

### Plugin System

Plugins bundle skills for specific audiences:
- **Curated Sets**: Domain-specific bundles (e.g., DevOps, Security)
- **Tool-Specific**: Plugins for Claude Code, Cursor, Codex, etc.
- **Compatibility Matrix**: `data/plugin-compatibility.json` tracks plugin versions and AAS core compatibility

Plugins are in `plugins/` and contain their own manifests. Don't edit manually; use sync scripts.

### CI/CD Pipeline

Key workflows (`.github/workflows/`):

- **ci.yml** - Runs on every PR: validate, audit, test
- **skill-review.yml** - Automated skill review for PRs
- **publish-npm.yml** - Publish to npm on release
- **pages.yml** - Deploy documentation to GitHub Pages
- **aas-agent-first-preview.yml** - AAS Core specific checks
- **codeql.yml** - Security scanning

## Development Best Practices

### When Adding a New Skill

1. **Research existing skills** - Use `npm run validate` output to see what exists
2. **Follow the template** - `docs/contributors/skill-template.md` is canonical
3. **Use semantic versioning** if you're updating an existing skill
4. **Run full validation** - Both `validate` and `security:docs`
5. **Test on real agents** - Try with Claude Code, Cursor, etc. before PR
6. **Enable maintainer edits** - When opening PR, check "Allow edits from maintainers"

### When Modifying Skills

- Update the version number if it exists
- Update CHANGELOG.md
- Run `npm run drift:check` to detect unintended changes
- Only include SKILL.md; don't add generated artifacts

### Common Workflows

**Bulk Skill Updates:**
```bash
# Make changes to multiple SKILL.md files
# Then validate everything:
npm run validate:strict

# Check for problematic patterns:
npm run security:scan:strict

# Review evidence if needed:
npm run drift:check
```

**Before Opening a PR:**
```bash
# Run everything
npm run pr:preflight

# Generate evidence for review
npm run pr:evidence

# Check the decision manifest
npm run pr:decision
```

**For Release:**
```bash
# Verify readiness
npm run release:preflight

# Prepare release artifacts
npm run release:prepare

# Publish
npm run release:publish
```

## Important Files to Know

| File | Purpose | Edit? |
|------|---------|-------|
| `skills/*/SKILL.md` | Individual skill playbooks | ✓ Yes |
| `package.json` | Dependencies, scripts | ✓ Yes (carefully) |
| `tools/schemas/aas-v1/` | Validation schemas | ✓ Yes (rarely) |
| `data/catalog.json` | Generated skill index | ✗ No (auto-generated) |
| `CATALOG.md` | Generated skill browser | ✗ No (auto-generated) |
| `skills_index.json` | Generated index for web app | ✗ No (auto-generated) |
| `.github/workflows/` | CI/CD pipelines | ✓ Yes (with care) |

## Testing Strategy

### Test Coverage

- **Unit Tests** - Python/Node validation logic (`tools/scripts/tests/`)
- **Integration Tests** - Full pipeline tests
- **AAS v1 Tests** - Catalog functionality tests
- **Security Tests** - Dangerous pattern detection
- **Workflow Tests** - GitHub Actions validation (actionlint)

### Running Tests Locally

```bash
# All tests
npm run test

# Specific test suite
npm test tools/scripts/tests/aas_v1_catalog.test.js

# With detailed output
npm test -- --verbose
```

## Troubleshooting

### Validation Errors

```bash
# See detailed error messages
npm run validate:strict

# Some errors can be auto-fixed
npm run fix:missing-sections

# Check if it's a reference issue
npm run validate:references
```

### Build Failures

```bash
# Check if specific script is broken
npm run catalog          # Test catalog generation
npm run index            # Test indexing
npm run plugin-compat:check  # Test plugin sync

# Full pipeline dry-run
npm run sync:all
```

### CI Pipeline Issues

- Check `.github/workflows/ci.yml` for what runs on each event
- Use `npm run pr:preflight` to replicate CI checks locally
- GitHub Actions logs are available in PR "Checks" tab
- Actionlint validates workflow YAML: `npm run lint:workflows`

## Branch Strategy & PR Process

### Development Branch
Working branch: `claude/claude-md-docs-mg1gxb`

### PR Process
1. Create feature branch from `main`
2. Make changes (skills, docs, scripts)
3. Run `npm run pr:preflight` locally
4. Open PR with default template
5. **Enable "Allow edits from maintainers"**
6. Address CI feedback
7. Merge when all checks pass

### PR Template
Use `.github/pull_request_template.md`. Key sections:
- Summary of changes
- Type (feature/fix/docs)
- Related issues
- Testing performed
- Screenshots (if UI changes)

## Related Documentation

- **README.md** - User-facing overview, installation, FAQ
- **CONTRIBUTING.md** - Contributor guide (easy onboarding)
- **docs/users/aas-core.md** - AAS Core detailed guide
- **docs/contributors/skill-template.md** - Canonical skill template
- **CHANGELOG.md** - Version history and breaking changes
- **.github/MAINTENANCE.md** - Maintenance procedures for admins

## Key External Tools

- **Workbench** - Browser-local skill stack review (no installation)
- **AAS MCP** - Local stdio server for agent skill discovery
- **AAS CLI** - Command-line tool for stack validation, planning
- **npm Registry** - Official AAS package distribution

## Quick Reference: Common Tasks

```bash
# I want to...

# ...validate my skill changes
npm run validate:strict && npm run security:scan:strict

# ...see what changed
npm run drift:check

# ...test before PR
npm run pr:preflight && npm run pr:evidence

# ...review skill by ID
grep -r "skill-id-here" data/catalog.json

# ...update all generated files
npm run build

# ...run the web app locally
npm run app:dev

# ...check plugin compatibility
npm run plugin-compat:check

# ...see all test failures
npm run test:local

# ...release a new version
npm run release:preflight && npm run release:prepare && npm run release:publish
```

---

**Version**: v15.16.0 (agent-first-preview)
**Last Updated**: 2026-08-26
**Status**: Active development, contributions welcome
