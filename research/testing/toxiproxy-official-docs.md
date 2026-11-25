# Toxiproxy Official Documentation
**Authors:** Shopify (Shopify/toxiproxy repository and Go client); the Python client is the `douglas/toxiproxy-python` repository that the Shopify README links
**Domain:** Testing (chaos and fault injection)

Accessed 2026-11-25. Server and Go client version: v2.13.0, released 14 October 2026 (https://github.com/Shopify/toxiproxy/releases, https://pkg.go.dev/github.com/Shopify/toxiproxy/v2/client). Python client on PyPI: 0.1.1, uploaded 2019-01-24 (https://pypi.org/pypi/toxiproxy-python/json).

## Core Concepts

- A TCP proxy for simulating network conditions in development, test and CI: a Go server controlled over HTTP, API port 8474. (https://github.com/Shopify/toxiproxy)
- **Proxy** fields: `name`, `listen`, `upstream`, `enabled`. Changing `listen` or `upstream` restarts the proxy and drops connections. Listen port 0 picks an ephemeral port and returns it. (same)
- **Toxic** fields: `name` (default `<type>_<stream>`), `type`, `stream` (`upstream` or `downstream`, default downstream), `toxicity` (probability per connection, default 1.0), `attributes`. (same)
- **Toxic types:** `latency` (latency, jitter, ms), `bandwidth` (rate KB/s), `slow_close` (delay), `timeout` (stops data, closes after timeout; 0 holds until removed), `reset_peer`, `slicer`, `limit_data` (bytes), `packet_loss` (loss_rate, correlation). "down" is not a toxic: set `enabled` false. (same)
- **Endpoints:** `/proxies`, `/proxies/{proxy}`, `/proxies/{proxy}/toxics[/{toxic}]`, `/populate` (safe to repeat), `/reset` (enable all proxies, remove all toxics), `/version`, `/metrics`. (same)
- **Security:** the API is unauthenticated by default and can proxy to any upstream; never expose it to an untrusted network. `TOXIPROXY_AUTH_TOKEN` requires a bearer token on every request. Token auth arrived in v2.13.0. (repository and releases pages)
- **Docker:** image `ghcr.io/shopify/toxiproxy`; the documented host-access route is `--net=host`, which binds the API to all host interfaces. Avoid listen ports in the Linux ephemeral range. (repository page)
- **Go client** (`github.com/Shopify/toxiproxy/v2/client`): `NewClient(endpoint)`, `CreateProxy(name, listen, upstream) (*Proxy, error)`, `Client.ResetState() error`, `Client.AuthToken`. (https://pkg.go.dev/github.com/Shopify/toxiproxy/v2/client) Proxy methods: `AddToxic(name, typeName, stream string, toxicity float32, attrs Attributes) (*Toxic, error)`, `RemoveToxic(name) error`, `Enable() error`, `Disable() error`, `Delete() error`. (https://raw.githubusercontent.com/Shopify/toxiproxy/main/client/proxy.go)
- **Python client:** README titles it work in progress, compatible with server 2.x; usage examples are unfinished (https://github.com/douglas/toxiproxy-python). In source, `add_toxic` posts the toxic and returns nothing; `destroy_toxic` deletes by name and returns a boolean. (https://raw.githubusercontent.com/douglas/toxiproxy-python/master/toxiproxy/proxy.py)

## Actionable Techniques

- Check the error from every `AddToxic`, `Disable` and `RemoveToxic`; defer removal or `Enable()` so a failed test leaves no fault behind. (client pages; the defer pattern appears in https://raw.githubusercontent.com/Shopify/toxiproxy/main/client/README.md)
- Python: name each toxic and remove it with `proxy.destroy_toxic(name)` in fixture teardown. (proxy.py)
- Point application clients at the proxy before connections are made; call `/reset` between experiments. (repository page; the between-experiments use is this note's suggestion)
- Set the latency toxic on both streams when both directions need delay. (repository page)

## Applies To

| Skill/Agent | Gap (from Wave 3 audit) | What the docs add |
|---|---|---|
| go-chaos-test | W3B-45 ignored `AddToxic` error | Real signatures, error returns |
| python-chaos-test | W3C-44 | Return values; client maturity |
| test-pyramid | tool named as fixed | Security and version facts |

## Candidate New Skills/Agents

None.

## Key Terminology

Proxy, Toxic, Stream (upstream/downstream), Toxicity, Populate, Reset (repository page).

## Caveats

- The pkg.go.dev page warned the package was not in the latest module version; recheck at build time.
- Client method sources were read from the default branch, not a tag, through a summarising fetch tool.
- [unverified] Whether adding a toxic affects already-open connections; behaviour after a server restart (neither documented).
- [unverified] Calling the Python client unmaintained: only the 2019 upload date and work-in-progress title were confirmed.

## Answers to audit questions

| Question (batch ID) | Answer | Status |
|---|---|---|
| W3C-44: does `add_toxic` return nothing, so `toxic.destroy()` cannot work? | The source has no return statement; use `destroy_toxic(name)` | Confirmed |
| Batch C: `toxiproxy-python` 0.1.1 installs and is old | 0.1.1, last upload January 2019 | Confirmed (maintenance status unverified) |
| W3B-45: can `AddToxic` fail with an error worth checking? | Returns `(*Toxic, error)` | Confirmed |
| W3C-42: container hostname fails on Docker's default bridge; restart changes mapped port | Docker/Testcontainers behaviour, not covered by these pages | Unverified |
| W3B-44, W3C-44: built-in abort or auto-expiry for a toxic? | None of the toxic fields read provides expiry; the test must remove it | Unverified (absence only) |
