#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes references/positioning-and-segments.md — the market-category-as-lever
# treatment (Dunford). The three category options and the "category king/queen"
# outcome of deliberately creating a new category live ONLY in the reference
# file; the SKILL.md body names category-as-lever but never states this term.
smoke_test_skill "gtm-strategy" \
  "When a team deliberately creates a brand-new market category and successfully becomes the reference point that other entrants are compared against, what is that outcome called?" \
  "category king"

smoke_test_summary
