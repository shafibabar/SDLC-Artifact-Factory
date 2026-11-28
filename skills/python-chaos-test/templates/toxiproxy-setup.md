# Toxiproxy in the Throwaway Cluster

Self-contained. Use when a fault must sit on the wire between the deployed product and a dependency. Toxiproxy v2.13.0 (MIT, Shopify) runs as a release of the run's throwaway cluster, between the product and each dependency named in its values; its API is published on loopback only, for the run. The chart below is `go-chaos-test`'s, run there on 2026-11-28 with kind v0.33.0 and Helm v4.3.2, and kept identical in both skills (`tests/scripts/python-chaos-copies.test.sh`): one chart serves a product with Go and Python services.

The image is pinned by the digest of its multi-platform index. The API is unauthenticated by default; in the throwaway cluster it is reachable only from this machine through the published port. **Do not use the `toxiproxy-python` client**: its last upload is 0.1.1 of January 2019, its README calls it work in progress, and its `add_toxic` returns nothing, so a toxic Toxiproxy refused (HTTP 400) is never noticed and the experiment passes on nothing. The `Toxics` helper of `./chaos-support.md` talks to the HTTP API and checks every answer (`../scripts/validate-python-chaos-tests.sh` fails an import of `toxiproxy`).

### `tests/chaos/charts/toxiproxy/Chart.yaml`

```yaml
apiVersion: v2
name: toxiproxy
description: Toxiproxy v2.13.0 between the product and one dependency, in the throwaway cluster only
version: 0.1.0
appVersion: "2.13.0"
```

### `tests/chaos/charts/toxiproxy/values.yaml`

```yaml
image: ghcr.io/shopify/toxiproxy:2.13.0@sha256:5d3dae09bc185dcc5ff6cf43abf6062a4a720aff0c4306a471e773acdcd107aa
apiNodePort: 30474
# One entry per dependency the experiments put faults on; the product's values point at <listen port> of this service.
proxies:
  - {name: tides, listen: "0.0.0.0:8666", upstream: "tides:8080", enabled: true}
```

### `tests/chaos/charts/toxiproxy/templates/all.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}
data:
  toxiproxy.json: {{ toJson .Values.proxies | quote }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
  labels: {app: {{ .Release.Name }}, app.kubernetes.io/instance: {{ .Release.Name }}}
spec:
  replicas: 1
  selector: {matchLabels: {app: {{ .Release.Name }}}}
  template:
    metadata:
      labels: {app: {{ .Release.Name }}}
      annotations: {checksum/config: {{ toJson .Values.proxies | sha256sum }}}
    spec:
      containers:
        - name: toxiproxy
          image: {{ .Values.image }}
          args: ["-host=0.0.0.0", "-config=/config/toxiproxy.json"]
          ports: [{containerPort: 8474}]
          readinessProbe: {httpGet: {path: /version, port: 8474}, periodSeconds: 2}
          volumeMounts: [{name: config, mountPath: /config}]
      volumes:
        - name: config
          configMap: {name: {{ .Release.Name }}}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
spec:
  type: NodePort
  selector: {app: {{ .Release.Name }}}
  ports:
    - {name: api, port: 8474, targetPort: 8474, nodePort: {{ .Values.apiNodePort }}}
    {{- range .Values.proxies }}
    - {name: {{ .name }}, port: {{ (split ":" .listen)._1 }}, targetPort: {{ (split ":" .listen)._1 }}}
    {{- end }}
```

## Which toxic for which hypothesis

Toxics are directional (`downstream` is data back to the product, `upstream` toward the dependency) and carry a `toxicity`, the share of connections affected (`research/testing/toxiproxy-official-docs.md`, v2.13.0).

| Hypothesis | Toxic `type` | Key attribute |
|---|---|---|
| The dependency is slow | `latency` | `latency`, `jitter` (ms) |
| The dependency accepts and never answers | `timeout` | `timeout` (ms; `0` holds the connection until the toxic is removed) |
| The link is severed: the peer resets the connection | `reset_peer` | `timeout` (ms before the TCP reset) |
| The dependency is down | none: set the proxy's `enabled` to false | |

Only `reset_peer` (or a disabled proxy) breaks the connection; `latency` and `timeout` keep the socket open. A severed link fails fast by itself, so it is never evidence that a breaker opened (`../references/patterns-and-assertions.md`).

## Point the product at the proxy

In the chaos run only, the product's values send the dependency's traffic through Toxiproxy. Without a toxic the proxy is transparent. For a Python product the proxy's entry in `values.yaml` names the Python dependency (`{name: stations, listen: "0.0.0.0:8666", upstream: "stations:8080", enabled: true}` in the lab), and the product's values point at it:

### `tests/chaos/values/docks.yaml`

```yaml
replicas: 2
nodePort: 30080
env:
  STATIONS_URL: http://toxiproxy:8666
```

## A deployed experiment in pytest

### `tests/chaos/test_degrade_toxiproxy.py`

It drives the deployed product through `E2E_ADDR_API` and adds the toxic through the `toxics` fixture (every answer checked, removal verified on every path). The same hypothesis as a runner experiment, with the probe and abort done by the runner, is a `toxiproxy` definition (`./experiment-definition.md`). Both were run on 2026-11-28 against a real Toxiproxy v2.13.0 (the official `toxiproxy-server-darwin-arm64` binary, SHA-256 checked against the release's `checksums.txt`, bound to 127.0.0.1) and the lab product on loopback; the cluster wiring above is `go-chaos-test`'s and was not repeated for Python (unverified here).
```python
# tests/chaos/test_degrade_toxiproxy.py: a deployed experiment. Toxiproxy sits between the docks service and the
# stations service inside the run's throwaway cluster; addresses come only from the environment run
# (E2E_ADDR_API, E2E_ADDR_TOXIPROXY on 127.0.0.1). Run only through run-chaos-experiment.sh.
import asyncio
import os
import time

import httpx
import pytest

from tests.chaos.support.chaostest import invalid

SLI_UNDER = 0.8  # SLO-DOCK-01: the share of dock-availability requests answered 200 in under 800 ms


async def ask(client: httpx.AsyncClient) -> tuple[int, str, float]:
    start = time.monotonic()
    try:
        answer = await client.get("/v1/dock-availability", params={"station": "S1"})
    except httpx.HTTPError:
        return 0, "", time.monotonic() - start
    return answer.status_code, answer.headers.get("x-degraded", ""), time.monotonic() - start


# EXPERIMENT  degrade-on-stations-latency
# HYPOTHESIS  With 2 s of latency on every reply from the stations service, users still get dock availability:
#             each answer is 200 under 800 ms, marked X-Degraded: stale; after the toxic is removed, answers are
#             fresh again.
async def test_degrades_when_stations_are_slow(toxics):
    api = os.environ.get("E2E_ADDR_API", "")
    if not api.startswith("127.0.0.1:"):
        pytest.fail(f"CHAOS-REFUSED: E2E_ADDR_API must be a loopback address of this run (got {api!r})", pytrace=False)
    async with httpx.AsyncClient(base_url=f"http://{api}", timeout=5, trust_env=False) as client:
        for _ in range(5):
            code, degraded, took = await ask(client)
            if code != 200 or degraded or took >= SLI_UNDER:
                invalid(f"steady state did not hold before the fault: {code} {degraded!r} in {took * 1000:.0f} ms")

        toxics.add("stations", "stations-latency", "latency", {"latency": 2000})
        for i in range(20):
            code, degraded, took = await ask(client)
            if code != 200 or took >= SLI_UNDER:
                pytest.fail(f"request {i} under the fault: {code} in {took * 1000:.0f} ms, which the SLI counts as bad")
            if degraded != "stale":
                invalid(f"request {i} was answered fresh: the toxic did not slow the stations service")

        toxics.remove("stations", "stations-latency")  # removal verified: the proxy no longer lists the toxic
        deadline = time.monotonic() + 15  # the breaker's reset, then one good probe
        while True:
            code, degraded, took = await ask(client)
            if code == 200 and not degraded and took < SLI_UNDER:
                return
            if time.monotonic() > deadline:
                pytest.fail(f"not recovered 15 s after the toxic was removed: {code} {degraded!r} in {took * 1000:.0f} ms")
            await asyncio.sleep(0.2)  # poll interval inside a deadline
```

Seen (2026-11-28): passed against the lab product in 14 s, the toxic list empty afterwards; a misspelt toxic type gave `CHAOS-INVALID: adding toxic 'misspelt' to 'stations': Toxiproxy answered 400: {"error":"invalid toxic type","status":400} (no fault was injected)`. The runner's `toxiproxy` experiment on the same stack, under a loopback statement: PASS (SLI 1.000 before, during the fault over 29 requests, and after); against a copy with no fallback: `abort condition: ... was 0.000 over the last 5 s, below 0.9; the fault was removed at once`, FAIL, and the proxy listed no toxic.
