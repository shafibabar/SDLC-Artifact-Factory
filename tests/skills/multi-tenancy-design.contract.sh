#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "multi-tenancy-design" \
  "On an API request, the tenant identity must be resolved from the authenticated request context (the routing host and the verified JWT claim) and never from a client-supplied parameter. What is the classic multi-tenant attack that occurs when the server instead trusts a client-supplied tenant identifier for authorization? Name the vulnerability class." \
  "IDOR"
smoke_test_summary
