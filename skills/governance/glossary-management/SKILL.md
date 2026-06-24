---
name: glossary-management
description: >
  Maintains and enforces the canonical Ubiquitous Language for the SDLC Artifact Factory.
  Defines every domain term used across all agents, skills, commands, hooks, and artifacts.
  Provides the reference all agents consult to prevent terminology drift. When any agent
  is unsure whether a term is canonical, they check this skill first.
version: 1.0.0
phase: cross-cutting
owner: factory-governance
tags: [ddd, ubiquitous-language, glossary, governance, cross-cutting]
---

# Glossary Management

## Purpose

A single, authoritative vocabulary shared by every component in this plugin. Terminology that drifts between agents, skills, and artifacts creates ambiguity, breaks traceability, and violates DDD's Ubiquitous Language principle.

Every agent must consult this skill before introducing a term into an artifact. Every hook must reference this skill when checking for terminology drift.

## The Rule

**One term, one meaning, used consistently everywhere.**

If a term appears in the canonical glossary, use it exactly as defined. Do not substitute synonyms. Do not abbreviate. Do not redefine within a bounded context unless the redefinition is explicitly declared in that context's ubiquitous language glossary.

## How to Use This Skill

**When authoring an artifact:**
1. Identify all domain concepts mentioned.
2. Look each concept up in `references/ubiquitous-language.md`.
3. Use the canonical term exactly as listed.
4. If a concept is not in the glossary, propose a new entry (see Adding Terms below).

**When reviewing an artifact:**
1. Extract all domain terms.
2. Check each against `references/ubiquitous-language.md`.
3. Flag any term that differs from its canonical form — this is a terminology drift violation.
4. Terminology drift violations must be corrected before a phase gate can pass.

## Adding Terms

New terms may only be added when:
1. The concept does not already exist under a different canonical name.
2. The term is used in at least two artifacts, establishing it as genuinely shared vocabulary.
3. The definition is unambiguous and agreed upon.

To add a term: append it to `references/ubiquitous-language.md` in the appropriate category, with a definition of one to three sentences. Update the `last_updated` field at the top of that file.

## Removing or Redefining Terms

Terms may not be silently removed or redefined. Any change requires:
1. An Architecture Decision Record (ADR) documenting the reason.
2. All existing artifacts using the old term to be updated.
3. The `decisions` array in `sdlc-context.json` to record the change.

## Bounded Context Overrides

A Bounded Context may use a term with a meaning that differs from the canonical definition. When this happens:
1. The Bounded Context's own ubiquitous language glossary (produced by the `domain-modeler` agent) must document the override explicitly.
2. The override must reference the canonical term and explain why the meaning differs within this context.
3. The canonical glossary is updated with a note that the term has a context-specific meaning in that Bounded Context.

## Canonical Glossary

See `references/ubiquitous-language.md` for the full term list.

The glossary is organised into nine categories:
- Domain and DDD
- Design Principles
- Event-Driven and Distributed
- Data Lifecycle
- Reliability and Operations
- Security and Compliance
- Testing and Quality
- Delivery and Platform
- Product and Discovery
