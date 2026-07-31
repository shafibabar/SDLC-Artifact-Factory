#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/toxiproxy-fault-injection.md-only fact: the specific
# toxiproxy toxic TYPE that produces a true network partition -- a TCP RST that
# severs the link -- as opposed to the latency/timeout toxics that keep the
# socket alive. The SKILL.md body names the fault effect as "partition" and a
# "hard link sever" in prose but carries the literal toxic type "reset_peer"
# NOWHERE (verified absent from the body: grep -c reset_peer SKILL.md == 0);
# only references/toxiproxy-fault-injection.md gives the verbatim "reset_peer"
# (appears in the toxic-type table, the apply_toxic call, and the worked
# severed-DB experiment). A pass proves the progressive-disclosure split loaded
# the reference, not just the body.
smoke_test_skill "python-chaos-test" \
  "Which specific toxiproxy toxic type produces a true network partition by sending a TCP RST that severs the connection, rather than merely adding latency or a timeout?" \
  "reset_peer"

smoke_test_summary
