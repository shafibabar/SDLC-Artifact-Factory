#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/testcontainers-setup.md-only fact: the exact Postgres log
# line the session-scoped container fixture waits for, and that it must be seen
# TWICE (initdb's throwaway first boot, then the real server after restart)
# before yielding -- the Python analog of Go's "a port-only wait races initdb's
# restart". The SKILL.md body names "wait past initdb's first-boot restart" and
# "two sightings" in prose but carries the literal log string nowhere (verified
# absent from the body); only references/testcontainers-setup.md gives the
# verbatim "database system is ready to accept connections". A pass proves the
# progressive-disclosure split loaded the reference, not just the body.
smoke_test_skill "python-integration-test" \
  "What exact Postgres log line does the session-scoped testcontainer fixture wait for, and how many times must it appear before the fixture yields?" \
  "database system is ready to accept connections"

smoke_test_summary
