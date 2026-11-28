# HTTPX Guards and Deadline Polling: Official Documentation
**Authors:** The HTTPX project (encode/httpx); Python Software Foundation (docs.python.org); Kubernetes Python client authors (kubernetes-client/python)
**Domain:** Testing (end-to-end, client guards and waiting, Python)

Accessed 2026-11-28. httpx latest 0.29.0, 2026-11-26, BSD-3-Clause, Python >=3.10 (https://pypi.org/pypi/httpx/json); docs and source read at tag `0.29.0`. Python standard library pages read at https://docs.python.org/3/, which showed "Python 3.15.2 documentation" (PSF licence). `kubernetes` latest 37.0.3, 2026-11-18, Apache-2.0, Python >=3.10 (https://pypi.org/pypi/kubernetes/37.0.3/json); read at tag `v37.0.3`. This note adds to `respx-httpx-official-docs.md` (transports, `MockTransport`, timeout classes) and does not repeat it.

Sources:
- [EH] https://raw.githubusercontent.com/encode/httpx/0.29.0/docs/advanced/event-hooks.md
- [CL] https://raw.githubusercontent.com/encode/httpx/0.29.0/docs/advanced/clients.md
- [TR] https://raw.githubusercontent.com/encode/httpx/0.29.0/docs/advanced/transports.md
- [QS] https://raw.githubusercontent.com/encode/httpx/0.29.0/docs/quickstart.md
- [AS] https://raw.githubusercontent.com/encode/httpx/0.29.0/docs/async.md
- [API] https://raw.githubusercontent.com/encode/httpx/0.29.0/docs/api.md
- [src] https://raw.githubusercontent.com/encode/httpx/0.29.0/httpx/_client.py
- [url] https://raw.githubusercontent.com/encode/httpx/0.29.0/httpx/_urls.py
- [T] https://docs.python.org/3/library/time.html
- [A] https://docs.python.org/3/library/asyncio-task.html
- [IP] https://docs.python.org/3/library/ipaddress.html
- [K] https://raw.githubusercontent.com/kubernetes-client/python/v37.0.3/kubernetes/config/kube_config.py
- [KR] https://raw.githubusercontent.com/kubernetes-client/python/v37.0.3/README.md

## Core Concepts

**Event hooks**
- `httpx.Client(event_hooks={"request": [...], "response": [...]})`; hooks "must always be set as a **list of callables**" and each takes one argument, the request or the response [EH].
- The request hook is "called after the request is fully prepared, but before it is sent to the network"; the response hook "after the response has been fetched from the network, but before it is returned to the caller" [EH].
- On `httpx.AsyncClient` hooks "MUST be async functions, rather than plain functions" [EH].
- A response hook may raise: the documented example calls `response.raise_for_status()` [EH]. Whether a request hook may raise to abort is not stated in the official documentation. In source the hook is called as plain `hook(request)` before the send, with nothing catching an exception [src].
- Redirects are not mentioned on the hooks page [EH]. In source both hook lists run inside the redirect loop, once per hop, and again on each auth round trip [src].
- Hooks can modify the request; `client.event_hooks` can be read and changed after creation [EH].

**`base_url` and absolute URLs**
- "`base_url` allows you to prepend an URL to all outgoing requests": `Client(base_url='http://httpbin.org')` then `client.get('/headers')` [CL].
- What an absolute URL does is not stated in the documentation [CL]. In source `_merge_url` merges only when `is_relative_url`; an absolute URL is returned unchanged, so `base_url` is ignored and the request goes to the other host [src].
- Relative merge always appends: base `https://www.example.com/subpath` plus `/path` gives `https://www.example.com/subpath/path` (source comment) [src].
- `URL.is_absolute_url` is true for `http://example.com/path` and false for `/path` [url].

**Redirects**
- "By default, HTTPX will not follow redirects for all HTTP methods"; `follow_redirects=True` enables it, and `response.history` lists followed redirects [QS]. The constructor default is `follow_redirects: bool = False` [src].
- With redirects off, a 3xx is returned as the response and `response.next_request` holds the request that would follow [QS].

**Transports and mounts as a refusal point**
- Subclass `httpx.BaseTransport` and implement `handle_request(self, request)` returning `httpx.Response`; for async, `httpx.AsyncBaseTransport` with `handle_async_request`. The docs show a wrapper transport around `httpx.HTTPTransport` [TR].
- `mounts={pattern: transport}` routes by scheme, domain and port: `all://`, `https://`, `all://example.com`, `all://*example.com` (domain and subdomains), `all://*.example.com` (subdomains only), `https://example.com:1234`, `all://*:1234`; the most specific pattern wins [TR].
- Every request, redirect hops included, is sent through the transport chosen for its URL [src]. A transport that refuses is therefore the one place that also sees redirected requests; the docs do not present it as a guard.

**`httpx.URL` fields**
- `.host` is "Always normalized to lowercase, with IDNA hosts decoded into unicode"; IPv6 brackets are removed (`https://[::ffff:192.168.0.1]` gives `::ffff:192.168.0.1`) [url].
- `.port` is `None` for the default port of `http`, `https`, `ws`, `wss`, `ftp` (`http://www.example.com:80` has port `None`) [url]. A guard must compare scheme and port with that in mind.
- `.scheme` is lowercase; the API page lists `.scheme`, `.authority`, `.host`, `.port`, `.path`, `.query`, `.raw_path`, `.is_absolute_url`, `.is_relative_url` [url] [API].

**Timeouts and lifetime**
- "The default timeout for network inactivity is five seconds" [QS]; classes and exceptions are in the existing note.
- "The recommended way to use a `Client` is as a context manager", or call `.close()` [CL]. `async with httpx.AsyncClient()` or `await client.aclose()`; avoid "instantiating multiple client instances" in a hot loop [AS].

**Standard library: deadlines**
- `time.monotonic()`: "a clock that cannot go backwards. The clock is not affected by system clock updates"; "only the difference between the results of two calls is valid" [T].
- `time.time()` "can return a lower value than a previous call if the system clock has been set back" [T]. That is why a deadline uses `monotonic`.
- `time.sleep()` may suspend "longer than requested by an arbitrary amount" [T].
- `asyncio.timeout(delay)` returns an async context manager; on expiry it cancels the current task and turns the cancellation into `TimeoutError`, which "can only be caught _outside_ of the context manager". The `Timeout` class and `timeout_at()` carry "Added in version 3.11"; the `asyncio.timeout()` entry itself has no version line [A].
- `asyncio.wait_for(aw, timeout)`: "If a timeout occurs, it cancels _aw_ and raises `TimeoutError`"; since 3.11 it raises the builtin `TimeoutError`; since 3.12 it is implemented with `asyncio.timeout()` [A].
- `asyncio.sleep(delay)` "always suspends the current task, allowing other tasks to run" [A].

**Standard library: addresses**
- `ipaddress.ip_address(address)` returns an `IPv4Address` or `IPv6Address`; "A `ValueError` is raised if _address_ does not represent a valid IPv4 or IPv6 address" [IP]. A hostname such as `localhost` is not an address and raises.
- `.is_loopback` is "`True` if this is a loopback address" (RFC 3330 for IPv4, RFC 2373 for IPv6) [IP].

**Kubernetes client configuration**
- `load_kube_config(config_file=None, context=None, client_configuration=None, persist_config=True, temp_file_path=None)` "Loads authentication and cluster information from kube-config file and stores them in kubernetes.client.configuration" [K].
- With no arguments it reads the default location, `os.environ.get('KUBECONFIG', '~/.kube/config')`, and `context`: "If is set to None, current_context from config file will be used" [K] [KR]. So a bare call follows whatever cluster the caller's shell last selected.
- `persist_config=True` is the default: "config file will be updated when changed (e.g GCP token refresh)" [K].
- `new_client_from_config(config_file, context, persist_config, client_configuration)` returns an `ApiClient` instead of setting the global configuration [K].

## Actionable Techniques (design is this note's)

- Enforce the one-address rule in a wrapping transport that compares `request.url.scheme`, `.host` and `.port` with the allowed target and raises; add `follow_redirects=False`. A `base_url` alone does not confine the client.
- For a smoke client, refuse any method outside `GET`, `HEAD`, `OPTIONS` in the same transport (or a request hook), before the request is sent.
- Poll with a deadline: `deadline = time.monotonic() + budget`; loop, check, `time.sleep(interval)` or `await asyncio.sleep(interval)`; on expiry fail with the last observed state. In async code `async with asyncio.timeout(budget)` gives the same bound, with `TimeoutError` caught outside the block.
- Read the run's marker with `new_client_from_config(config_file=<the run's own file>, context=<its context>, persist_config=False)`, never a bare `load_kube_config()`.
- Treat `ipaddress` checks as applying to literal addresses only; resolve or special-case names explicitly.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| python-e2e-test | An HTTP client that reaches one address and refuses any other | Absolute URLs bypass `base_url`; transport or hook as the refusal point; `URL.host`/`.port` normalisation; redirects off by default |
| python-e2e-test | A smoke client that refuses every write | Request hook runs before the send; custom transport sees every request |
| python-e2e-test | Waiting for eventual consistency by polling with a deadline in sync and async tests | `time.monotonic`, `asyncio.timeout`, `asyncio.wait_for`, `asyncio.sleep` semantics |
| python-e2e-test | Reading the run's marker without touching the caller's Kubernetes context | Defaults of `load_kube_config` (default file, current context, global state, `persist_config=True`) and the explicit alternative |

## Candidate New Skills/Agents

None.

## Key Terminology

Event Hook, Base URL, Transport, Mount, Monotonic Clock, Deadline.

## Caveats

- Nothing was run. No package was installed; behaviour is read from documentation and from source at the tags above.
- Not stated in the official documentation: that a request hook may raise to abort a request; that hooks run for each redirect hop; how an absolute URL interacts with `base_url`. All three are read from `_client.py` and need a run to confirm.
- Not stated: whether a hook or transport exception is wrapped in an httpx exception type.
- Not stated: an "Added in" line for `asyncio.timeout()` itself; 3.11 is given for the `Timeout` class and `timeout_at()` beside it.
- Not stated: whether `ip_address` accepts bracketed IPv6 text, and how `is_loopback` treats IPv4-mapped IPv6 addresses.
- Not stated: whether `persist_config=False` guarantees the kubeconfig file is never written. No Kubernetes API call (reading a ConfigMap or namespace label) was researched.
