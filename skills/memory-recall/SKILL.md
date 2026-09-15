---
name: memory-recall
description: >
  How every agent in this plugin should consult the SDLC memory engine
  (.sdlc-memory/, scripts/memory/) before reading raw artifacts, research
  files, or sdlc-context.json — search first, read full content only for
  the specific URIs retrieval actually surfaces. Applies whenever an agent
  needs prior context: past decisions, open questions, related artifacts,
  research findings, or another agent's prior output. This is the
  self-contained, no-external-service replacement for what an
  OpenViking-integrated agent would do by calling its search MCP tool.
version: 1.0.0
phase: cross-cutting
owner: factory-governance
created: 2026-09-15
tags: [memory, retrieval, context, cross-cutting, efficiency]
produces: retrieval-digest
domain: governance
status: stable
---

# Memory Recall

## Purpose

Every agent in this plugin used to have exactly one way to get prior context: `Read` the whole 2,267-line `sdlc-context.json`, or `Glob`/`Read` through `research/`'s 100+ files by hand. That's expensive and gets worse as a product grows. The SDLC memory engine (`.sdlc-memory/`, built by `scripts/memory/`) replaces that with the same mechanism OpenViking uses — a hierarchical L0 (abstract) / L1 (overview) / L2 (detail) context tree, hybrid dense+sparse search, best-first tree-walk retrieval with score propagation and convergence, and hotness-based lifecycle scoring — reimplemented locally, with no MCP server, no network dependency, no dependency on the OpenViking repo. Local embeddings (`fastembed`) and a local cross-encoder reranker are installed per-repo by `scripts/memory/bootstrap.sh`; if that hasn't run yet or is offline, the same code degrades to dependency-free BM25 + lexical matching rather than failing.

## The rule

**Before reading a raw file for anything beyond a trivial, already-known path, search first:**

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/memory/run.sh" "${CLAUDE_PLUGIN_ROOT}/scripts/memory/retrieve.py" \
  --mode thinking "<a short, declarative, self-contained query>" --limit 8
```

This returns JSON: a list of `{uri, abstract, overview, content_path, score, hotness, final_score}` — abstracts and overviews only, never the raw embedding, never full file content. Read the `abstract`/`overview` fields to decide what's actually relevant. Only then, for the specific 1-3 URIs that matter, read the full file at `content_path` (or drill in with `--full` on a narrower query) — this is the entire point: never re-pay the token cost of the full corpus when a one-line abstract already answers the question.

Two modes, matching OpenViking's own QUICK/THINKING split:
- `--mode quick` — flat hybrid search, no tree walk, no rerank. Already run for you automatically every turn (see the `UserPromptSubmit` hook) and injected as context; you usually don't need to call this yourself.
- `--mode thinking` (default) — the full best-first tree walk with cross-encoder rerank and hotness blending. Use this explicitly whenever you're about to do real work: before writing a new artifact (check what already exists / what decisions constrain it), before answering "what did we decide about X," before starting a new phase.

## What's indexed

- **Product memory**: every artifact under `artifacts/<product>/<phase>/...`, indexed automatically on write (`post-artifact-created.sh` calls `ingest.py` on every `Write`). Its `summary` frontmatter field (required — see `scripts/validate-artifact-structure.sh`) becomes the L0 abstract.
- **This plugin's own project memory**: decisions, open questions, build checklist, and anti-patterns — migrated out of `sdlc-context.json` into `sdlc://self/...` nodes by `scripts/memory/migrate_context.py`. Query these instead of reading `sdlc-context.json` in full; `sdlc-context.json` now only holds the relatively static sections (methodology, tech stack, agent roster) plus a pointer note.
- **Research**: every file under `research/<topic>/...`.
- **Skills**: every `skills/<name>/SKILL.md`, indexed as-is (its `description` frontmatter is already a usable L1 overview).

If a search comes back empty or stale for something you know exists on disk, run a full reindex: `run.sh ingest.py --all`.

## Writing new memory

When you make a decision, resolve an open question, or complete a build-checklist item, don't append to `sdlc-context.json` — the memory engine no longer treats it as the growing log. Instead:
1. Write (or edit) the corresponding node under `.sdlc-memory/tree/self/decisions/<id>.md` (or `open_questions/`, `build_checklist/`) directly — plain markdown, no frontmatter required for these (they're not product artifacts).
2. Run `run.sh ingest.py .sdlc-memory/tree/self/decisions/<id>.md` (or the equivalent path) to re-embed and re-index it — or just re-run `migrate_context.py` if you've instead edited `sdlc-context.json` itself as the source of truth for a new entry.

## Directory abstracts

Every directory in the tree has its own `.abstract.md` / `.overview.md` sidecar under `.sdlc-memory/tree/`, mirroring OpenViking's directory-level vectors. These are auto-generated with a generic default the first time a file under that directory is ingested (e.g. `"strategy phase artifacts for product acme."`) — **edit them** to say something more specific once you know what actually lives there; retrieval quality for directory-level matches depends entirely on how good that one-liner is, since it's what candidate directories are scored and ranked against during the tree walk.

## Hotness

Every retrieved context's `active_count`/`updated_at` is bumped automatically whenever it's returned by a search — context that keeps getting retrieved stays "hot" (surfaces higher, all else equal) via the same `sigmoid(log1p(active_count)) * exp(-decay*age)` formula OpenViking uses (`scripts/memory/hotness.py`, 7-day half-life by default). You don't need to do anything for this to work; it's automatic.

## When NOT to use this

- A path you already know exactly (e.g. you just wrote the file this turn) — just `Read` it.
- Anything not yet ingested (a brand-new file written outside a `Write` tool call, e.g. by a shell script) — run `ingest.py <path>` first, or it won't be found.
- Don't treat a retrieval miss as proof something doesn't exist — bootstrap may not have finished installing real embeddings yet (falls back to BM25/lexical, which is weaker on paraphrased queries), or the file may genuinely not be indexed. If in doubt on something safety- or decision-critical, `Glob`/`Read` directly as a fallback.
