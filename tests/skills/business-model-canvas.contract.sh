#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
# Probes a references/canvas-blocks.md-only fact: the Lean Canvas Problem block
# lists "existing alternatives" alongside the top problems. The SKILL.md body
# names the four Lean Canvas blocks but never mentions this companion element —
# so a correct answer requires the references/ content, proving the split works.
smoke_test_skill "business-model-canvas" \
  "In the Lean Canvas, the Problem block asks you to list the top problems plus one companion element — how customers solve or work around the problem today, without your product. What is that companion element called?" \
  "existing alternatives"
smoke_test_summary
