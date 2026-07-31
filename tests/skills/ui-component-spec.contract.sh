#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "ui-component-spec" \
  "In the WCAG 2.1 AA accessibility baseline a component spec checks against, at what viewport width and zoom level must a component remain usable without two-dimensional scrolling, per the 1.4.10 Reflow success criterion?" \
  "320px"
smoke_test_summary
