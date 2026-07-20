---
description: Look up, list, or regenerate a specific artifact outside the normal phase sequence
argument-hint: "[list|show|create] [artifact-type]"
allowed-tools: Read, Glob, Agent
disable-model-invocation: true
---

A utility for working with a single artifact outside the normal phase-driver flow.

1. Parse `$ARGUMENTS` as an action (`list`, `show`, or `create`) and an artifact type. If unclear, ask the user.
2. Read `skills/artifact-manifest/SKILL.md` for the master artifact-type catalog and, once it exists, the product's own `artifacts/[product]/_manifest.json`.
3. **`list`** — show every artifact type in the catalog, or every instance of one type actually produced for this product.
4. **`show`** — read and display the specific artifact (or its manifest entry: status, version, what it traces back to).
5. **`create`** — identify which agent and skill own this artifact type from the catalog, then invoke that agent via the Agent tool with enough context to produce it. Confirm with the user before regenerating an artifact that already exists and is approved.
