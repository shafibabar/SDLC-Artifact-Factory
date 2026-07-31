#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/-only fact: the SKILL.md body says operation ids must be
# "pinned" but never names the FastAPI mechanism. The exact API for overriding
# FastAPI's auto-derived operation ids app-wide lives only in
# references/fastapi-schema-generation.md ("Pinning Metadata" section).
smoke_test_skill "python-openapi-codegen" \
  "In FastAPI, what app-level constructor argument overrides the ugly auto-derived operation ids so the exported OpenAPI schema uses short stable ids matching a hand-authored contract?" \
  "generate_unique_id_function"

smoke_test_summary
