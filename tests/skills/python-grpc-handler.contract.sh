#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/-only fact: the SKILL.md body says to "prefer the community
# OpenTelemetry gRPC async instrumentation" but deliberately does NOT name the
# function. references/server-and-interceptors.md names it — aio_server_interceptor
# from opentelemetry-instrumentation-grpc — proving the progressive-disclosure split
# is functional (the exact API name lives only in the reference, not the body).
smoke_test_skill "python-grpc-handler" \
  "Which specific function from the opentelemetry-instrumentation-grpc package does the async grpc.aio DataAsset server use for trace propagation instead of hand-rolling a tracing interceptor?" \
  "aio_server_interceptor"

smoke_test_summary
