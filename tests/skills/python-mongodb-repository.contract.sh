#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes references/-only content: the SKILL.md body names the cursor-decode
# step only in prose ("decodes the cursor") and never the concrete motor
# method. The `cursor.to_list(length=None)` call that materializes a find()
# or aggregate() cursor lives exclusively in references/ (motor-repository.md
# and aggregation-transactions-indexes.md) — grep-verified absent from the
# body. Answering requires the reference layer to have loaded.
smoke_test_skill "python-mongodb-repository" \
  "In the motor repository adapter, after find() or aggregate() returns a cursor, which cursor method materializes it into a list of documents in one round-trip?" \
  "to_list"

smoke_test_summary
