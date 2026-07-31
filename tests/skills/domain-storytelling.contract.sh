#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "domain-storytelling" \
  "What is the maximum recommended total number of participants in a Domain Storytelling session, and why should you not exceed it?" \
  "6 participants"
smoke_test_summary
