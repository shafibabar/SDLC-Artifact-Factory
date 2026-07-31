#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/-only fact: the body names "verifiable / cryptographic
# deletion" and points to references/deletion-mechanics.md, but the actual
# technique for making personal data in an immutable backup unrecoverable —
# crypto-shredding: destroying the encryption key rather than the ciphertext —
# lives only in references/deletion-mechanics.md. "crypto-shred" does NOT
# appear in SKILL.md.
smoke_test_skill "data-retention-policy" \
  "An immutable backup snapshot cannot be edited row-by-row, yet it still contains a person's personal data that must be erased under GDPR. What technique makes that data permanently unrecoverable, and what exactly is destroyed?" \
  "crypto-shred"

smoke_test_summary
