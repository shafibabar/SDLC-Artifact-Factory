# Toxiproxy in the Throwaway Cluster

Self-contained. Use when a fault must sit on the wire between the deployed product and a dependency. Toxiproxy v2.13.0 (MIT, Shopify) runs as a release of the run's throwaway cluster, between the product and each dependency named in its values; its API is published on loopback only, for the run. Run on 2026-11-28 with kind v0.33.0, Helm v4.3.2 and the image below pulled by the node from its registry (not preloaded, per D048 end-to-end).

The image is pinned by the digest of its multi-platform index (read with `docker buildx imagetools inspect ghcr.io/shopify/toxiproxy:2.13.0` on 2026-11-28). The API is unauthenticated by default; in the throwaway cluster it is reachable only from this machine through the published port.

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

## Point the product at the proxy

In the chaos run only, the product's values send the dependency's traffic through Toxiproxy. Without a toxic the proxy is transparent.

### `tests/chaos/values/harbour.yaml`

```yaml
mode: product
replicas: 2
nodePort: 30080
env:
  TIDES_URL: http://toxiproxy:8666
```

### `tests/chaos/values/tides.yaml`

The stand-in dependency (in the lab, the same image in its other mode). A real third party is always a stand-in here.
```yaml
mode: tides
```

## A deployed experiment in Go

### `tests/chaos/degrade_toxiproxy_chaos_test.go`

It drives the deployed product through `E2E_ADDR_API` and adds the toxic through `chaostest.AddToxic` (every error checked, removal verified); after removing the toxic it waits for fresh answers. The same hypothesis as a runner experiment, with the probe and abort done by the runner, is `degrade-on-tides-latency` in `./experiment-definition.md`; both were run.
```go
//go:build chaos

// Deployed experiment: Toxiproxy sits between the product and the tide-tables
// service inside the run's throwaway cluster. Addresses come only from the
// environment run (E2E_ADDR_API, E2E_ADDR_TOXIPROXY on 127.0.0.1).
package chaos_test

import (
	"net/http"
	"os"
	"testing"
	"time"

	toxiproxy "github.com/Shopify/toxiproxy/v2/client"

	"example.com/harbourpilot/internal/test/chaostest"
)

// SLO-TIDE-01: the share of tide-window requests answered 200 in under 800 ms.
const sliUnder = 800 * time.Millisecond

func ask(t *testing.T, client *http.Client) (int, string, time.Duration) {
	t.Helper()
	start := time.Now()
	resp, err := client.Get("http://" + os.Getenv("E2E_ADDR_API") + "/v1/tide-window?berth=B1")
	if err != nil {
		return 0, "", time.Since(start)
	}
	defer resp.Body.Close()
	return resp.StatusCode, resp.Header.Get("X-Degraded"), time.Since(start)
}

// EXPERIMENT  degrade-on-tides-latency
// HYPOTHESIS  With 2 s of latency on every reply from the tide tables, users still get a tide
//
//	window: each answer is 200 under 800 ms, marked X-Degraded: stale; after the
//	toxic is removed, answers are fresh again.
func TestChaos_DegradesWhenTideTablesAreSlow(t *testing.T) {
	toxi := chaostest.Toxiproxy(t)
	client := &http.Client{Timeout: 5 * time.Second}
	for i := 0; i < 5; i++ {
		if code, degraded, took := ask(t, client); code != http.StatusOK || degraded != "" || took >= sliUnder {
			chaostest.Invalid(t, "steady state did not hold before the fault: %d %q in %v", code, degraded, took)
		}
	}

	remove := chaostest.AddToxic(t, toxi, "tides", "tides-latency", "latency", "downstream", toxiproxy.Attributes{"latency": 2000})
	for i := 0; i < 20; i++ {
		code, degraded, took := ask(t, client)
		if code != http.StatusOK || took >= sliUnder {
			t.Fatalf("request %d under the fault: %d in %v, which the SLI counts as bad", i, code, took)
		}
		if degraded != "stale" {
			chaostest.Invalid(t, "request %d was answered fresh: the toxic did not slow the tide tables", i)
		}
	}

	remove() // removal verified: the proxy no longer lists the toxic

	deadline := time.Now().Add(15 * time.Second) // the breaker's reset, then one good probe
	for {
		code, degraded, took := ask(t, client)
		if code == http.StatusOK && degraded == "" && took < sliUnder {
			return
		}
		if time.Now().After(deadline) {
			t.Fatalf("not recovered 15 s after the toxic was removed: %d %q in %v", code, degraded, took)
		}
		time.Sleep(200 * time.Millisecond) // poll interval inside a deadline
	}
}
```

Seen (2026-11-28): passed against the correct product (8 s); against a product with no fallback it failed at once (`request 0 under the fault: 503 in 602ms, which the SLI counts as bad`) and the toxic list was empty afterwards; without a run id it was refused (`CHAOS-REFUSED`).
