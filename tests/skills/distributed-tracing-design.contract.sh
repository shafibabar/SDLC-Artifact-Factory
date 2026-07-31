#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Probes the OTLP gRPC exporter port from references/instrumentation-go.md.
# The SKILL.md body says spans export "over OTLP to Tempo" and points to the
# reference for exporter wiring, but the concrete port (4317 for OTLP gRPC, 4318
# for OTLP/HTTP) exists ONLY in references/instrumentation-go.md — not in the body.
# A passing test proves the progressive-disclosure split is functional: the
# reference file is loaded and consulted when the exporter detail is needed.
smoke_test_skill \
  "distributed-tracing-design" \
  "According to this skill's Go instrumentation reference, which network port does the OTLP gRPC exporter target on the OpenTelemetry Collector to ship spans toward Tempo?" \
  "4317"

smoke_test_summary
