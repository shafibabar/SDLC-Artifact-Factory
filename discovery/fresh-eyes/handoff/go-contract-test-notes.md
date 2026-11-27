# Handoff: go-contract-test rebuild (#1489)

Written 2026-11-27. Branch `issue-1489-wave-3-skill-go-contract-test-research-grounded-re`.
**State: research and tool experiments partly done. No file of the skill, any test, agent or catalog has been changed.** This note is the only repository change. The scratch lab, containers and pulled images were removed; the lab code is inline at the end.

Marks: **ran** = observed in a run here; **read** = from repository or tool source; **design** = proposed, not built; **unverified** = not run.

## 1. Task rules (from the brief)

- No git commit/push/checkout, no gh, no evals or LLM-backed tests, no background process or container left. Do not create or read anything under `evals/` for this skill or other suites' results. Do not edit `CHANGELOG.md`, `CLAUDE.md`, `.sdlc-memory`.
- Real toolchain (D048.8): official Go with SHA-256 check, only well-known pinned modules/tools/images the skill names; remove containers and volumes with `docker rm -v`; never touch others; no `--privileged`; no host mounts of repo or home; ports on 127.0.0.1; remove pulled images (never pre-existing `hello-world`, `postgres:17-alpine`); nothing published to any external broker; nothing personal in requests.
- Recipe: carry forward what is right, nothing deleted unread; folder spec (SKILL.md under 200 lines, numbered procedure, `## Gotchas`; `references/`, `templates/`, `resources/checklist.md`, scripts with tests in `tests/scripts/` that need neither Go nor Docker or skip clearly; `examples/` lean, standard, enterprise on three different products); `./` pointers; `sources:`; no unsupported claims; never cite `agile-ux-storytelling-baker.md`, `art-of-crafting-user-stories-lee.md`, `learn-product-management-with-stories.md`; description "Use when..."; MAJOR bump (2.0.2 -> 3.0.0); align owning agents; `ci-pipeline`/`cd-pipeline` read-only except direct conflicts.
- Eval lessons (replies are judged on what they SAY; long replies hurt): near the top, fixed rules and "What every answer states", starting with "keep the answer as short as asked; state each rule that bears on the question in words": what is replaced or refused by name and why; what stays default when one case differs, in the same breath; what a tool silently passes and whether its exit status is enough; how the check fails CI; every product size gets it; decisions for the product owner; never offer to switch a fixed rule. Where several mechanisms satisfy the source, do not present one as the only way. Invent no rules beyond sources and decisions.
- Final checks: `bash scripts/validate-skill-structure.sh skills/go-contract-test/SKILL.md`; `python3 scripts/lint-skill-layout.py --skill go-contract-test`; script tests; `python3 scripts/arch/build-catalog.py`; `bash scripts/lint-all.sh`; `bash tests/run-smoke-tests.sh scripts schemas arch`.
- Final report under 350 words: file inventory, check counts, versions and results, cleanup, limitations needing a product-owner decision, changes outside the skill, choices to confirm, unverified items.

## 2. What was read

CLAUDE.md; `skill-authoring-standards/SKILL.md` (templates folder only listed: `skill-template.md`, `eval-author-brief.md` not opened); all five files of `skills/go-contract-test` and its `.contract.sh`; `wave-3-findings.md` (lines 1-121, 178-213, 214-403) and `batch-b-go.md` (all); D048; research `contract-testing-in-action-cruz-prescott`, `pact-go-official-docs`, `oasdiff-official-docs`, `go-toolchain-official-docs`, `testing-web-apis-winteringham` (preview only), `go test-pyramid`, `go-integration-test` (SKILL, harness template, containers-and-ci, checklist, validator script), `api-contract-design` (SKILL, versioning reference), `event-schema-design` (SKILL, registry reference, lean example), `grpc-contract-design` (SKILL, protobuf reference), `ci-pipeline` SKILL, `cd-pipeline` (part), test-pyramid `flaky-and-suite-selection`, parts of `agents/test-strategist.md`.

**Not yet read:** `go-unit-test`, `mock-generation`, `test-fixture-design` bodies; `building-microservices-newman.md` (not shown); `jsonschema-official-docs.md`; `github-actions-official-docs.md`; go-makefile references beyond grep; `skill-template.md`; rest of agents.

## 3. Rules that bind the design (read)

- W3-D22: HTTP = standard spec-diff tool plus conformance; events = the mode set by the event design, replacing hand-written checkers; web app uses types generated from the same spec for its mocks; Pact only on the escalation trigger.
- W3-D10 / B-2: slow suites kept out of the fast check by build tags (`e2e`, `chaos`, `pact`); test-pyramid says contract tests run on every PR in the fast check with default selection.
- W3-D16: shell-to-remote contract tests belong to `react-component-testing` (not this skill). W3-D23: behaviour checks (idempotency, 429, deprecation, error branches) are in `go-integration-test`. W3-D17: one owner per method.
- D048.2: every product size gets contract testing. D048.5: reports approved by the product owner. Coverage rules are `go-unit-test`'s.
- api-contract-design: OpenAPI 3.1; `design/<service>/openapi.yaml`, copied into the service repo (`api/openapi.yaml` in go-openapi-codegen); breaking = remove/rename field, type change, remove endpoint, optional request field made required -> new major version run beside the old, `/v1/` never changed in place; retire only after sunset and no remaining caller; every documented status, response header and error branch gets a contract test.
- event-schema-design: add-only; additive in place as a new schema version; rename/type/unit/removal/required = new event type (never `.v2`); enum add = additive with notice; BACKWARD default, FORWARD, FULL, `_TRANSITIVE` for retained topics, never NONE; lean = schema files in repo + consumer contract tests + CI schema diff, no registry; keep `additionalProperties` open; a mode checks shape not meaning; never delete a registered schema; CI fails on incompatible.
- grpc-contract-design: REST default; gRPC only internal; breaking-change check against main in CI (Buf is the example); strict category is the safe default; breaking redesign = `.v2` package.
- integration-design: Consumer-Driven Contract on every integration; never abbreviate "CDC" (that is Change Data Capture). context-map-patterns: required for Customer/Supplier (downstream writes, runs in upstream pipeline); OHS only for named consumers who agreed.

## 4. Environment and tools (ran)

Machine: Linux x86_64, gcc 15.2.0, Docker 29.9.3, node/npm present, no Go, 7 GB RAM.

| Tool | Version | Verification |
|---|---|---|
| Go | 1.27.4 linux/amd64 | archive SHA-256 `7226736c2339719cda28fbf3a54d71aa63bcefe376e98cef00034268dab24840` matched go.dev JSON |
| oasdiff | v1.39.0 (`go install github.com/oasdiff/oasdiff@v1.39.0`). v1.41.0 (2026-11-25) exists; pinned to the researched version | |
| buf | v1.75.0 installed, version printed only; **no breaking check run** | |
| kin-openapi | v0.153.0 | |
| santhosh-tekuri/jsonschema/v6 | v6.0.3 | |
| pact-go | v2.9.1; `go install github.com/pact-foundation/pact-go/v2@v2.9.1` yields binary `v2` (renamed `pact-go`); `pact-go -l DEBUG install -d <dir>` | FFI pact_ffi 0.5.12 tar.xz SHA-256 `254c76435c290dd74fc16505c3f3aaafd5bb5cf1aeb6104e8f47b32b73d2e881` = GitHub asset digest; extracted `libpact_ffi.so` `1e2d020037bce88a259e79d589986f208ccd070e49626a26288482804ba7e69a` = installed |
| Latest, not installed | libopenapi-validator v0.16.5, testcontainers-go v0.45.0, franz-go v1.22.3, oapi-codegen v2.9.0 | |
| Images pulled then removed | `redpandadata/redpanda:v26.2.7` (harness pin), `pactfoundation/pact-broker:3.2.0-pactbroker2.124.0`, `pactfoundation/pact-cli:1.5.0.5` (never run) | |

Side effect: `pact-go install` writes `~/.pact/pact-go.yml` even with `-d`; it did not exist before and was removed. Env used: `GOROOT`, `GOPATH`, `GOCACHE`, `GOBIN` in scratch, `GOTOOLCHAIN=local`, `GOFLAGS=-modcacherw`, `GOTELEMETRY=off`. Go + oasdiff + buf caches used about 1.7 GB.

Containers:
```bash
docker run -d --name gc-lab-rp -p 127.0.0.1:18081:8081 redpandadata/redpanda:v26.2.7 redpanda start \
  --overprovisioned --smp 1 --memory 1G --reserve-memory 0M --node-id 0 --check=false --schema-registry-addr 0.0.0.0:8081
# creates one anonymous volume: remove with docker rm -v
docker network create gc-lab-net
docker run -d --name gc-lab-pg --network gc-lab-net -e POSTGRES_USER=pact -e POSTGRES_PASSWORD=pact -e POSTGRES_DB=pact postgres:17-alpine
docker run -d --name gc-lab-broker --network gc-lab-net -p 127.0.0.1:19292:9292 \
  -e PACT_BROKER_DATABASE_URL=postgres://pact:pact@gc-lab-pg/pact -e PACT_BROKER_ALLOW_PUBLIC_READ=false \
  -e PACT_BROKER_BASIC_AUTH_USERNAME=lab -e PACT_BROKER_BASIC_AUTH_PASSWORD=lab -e PACT_DO_NOT_TRACK=true \
  pactfoundation/pact-broker:3.2.0-pactbroker2.124.0
```
**Failure:** the broker exited (status 0) with `PG::ConnectionBad ... Connection refused` because it started before Postgres was ready. Wait for `pg_isready` first. Note exit status 0 despite failure. Heartbeat URL tried: `/diagnostic/status/heartbeat` (never answered; unverified). **No Pact test, broker call or can-i-deploy was ever run.**

## 5. oasdiff results (ran; spec OpenAPI 3.1, code in 9.1 and 9.2)

`oasdiff breaking BASE REV` **exits 0 even with breaking changes** unless `--fail-on` is given.

| Change | `--fail-on ERR` | `--fail-on WARN` | id (level 3=ERR, 2=WARN, 1=INFO) |
|---|---|---|---|
| remove required response property; response type change; enum value added to response; response enum dropped (free string); response format removed; response becomes nullable; response required -> optional; remove endpoint; remove required response header; new required request property; request optional -> required; request enum value removed | 1 | 1 | ERR |
| remove request property; remove query parameter | 0 | 1 | WARN |
| **remove optional response property; rename optional response property** | **0** | **0** | `response-optional-property-removed` (INFO) |
| **remove documented 404** | 0 | 0 | `response-non-success-status-removed` (INFO) |
| meaning change (description only) | 0 | 0 | none |
| add optional response property; add status; add `/v2` path; add `additionalProperties:false` to a response | 0 | 0 | INFO/none |
| success status removed; media type removed; response schema removed (success or error); property schema emptied; error required property removed; security added; request maxLength added; change inside `components.pathItems` (3.1; research note said silently dropped, but a type change there WAS caught) | 1 | 1 | ERR |
| endpoint deprecated with past `x-sunset`, then removed | 0 | 0 | sanctioned (INFO). Does not know whether callers remain |
| optional property marked deprecated, then removed | 0 | 0 plain; 1 with the severity file | INFO |

- Severity file line `response-optional-property-removed err` with `--severity-levels f` makes optional removal and rename exit 1. Unknown id or missing file: exit 106.
- `--fail-on MISSING-VERSION-BUMP` exits **0** for a type change when `info.version` major is bumped. Refuse this mode (contradicts "never change /v1 in place").
- **Silent passes (exit 0):** empty baseline file; baseline with `paths: {}`; a non-OpenAPI YAML (`hello: 1`) as baseline. Missing file or HTML: exit 102. Bad git ref: exit 102 (message says fetch the commit).
- Git revision syntax works: `oasdiff breaking --fail-on WARN deployed:api/openapi.json api/openapi.json` -> 1.
- **`.oasdiff.yaml` in the working directory is loaded silently**: `match-path`/`unmatch-path` there made a breaking change exit 0. `--config <file.yaml containing {} or blank>` overrides both it and `OASDIFF_CONFIG` (exit 1 restored). `--config /dev/null` or a non-.yaml name: exit 107. `OASDIFF_MATCH_PATH` env var had no effect.
- `--warn-ignore FILE`: a line `GET /v1/classes/{id} deleted the \`query\` request parameter \`lang\`` (with or without leading `in API`) ignored it (exit 0); a non-matching line leaves exit 1.
- Contradicts research note "[unverified] exit status without --fail-on": it is 0.

## 6. kin-openapi v0.153.0 response validation (ran + read, 3.1 spec, `gorillamux` router)

Fails correctly: wrong type, missing required, bad enum, null on non-nullable, wrong value for `["string","null"]`, wrong Content-Type, empty body, missing required header, bad error body, `const`, `unevaluatedProperties` (3.1), `date-time` format (3.0 and 3.1). Unknown route: `FindRoute` errors.

Silent passes:
- undocumented status unless `Options.IncludeResponseStatus: true` (ran); a `default` response still covers it (read);
- statuses 301, 304, 307, 308 and every HEAD request are never validated (read `validate_response.go`);
- operation with no responses; response with no `content` or no schema: body not checked (read);
- `uuid` format unless `openapi3.WithStringFormatValidator("uuid", openapi3.NewRegexpFormatValidator(openapi3.FormatOfStringForUUIDOfRFC4122))` in `Options.SchemaValidationOptions` (ran, works in 3.1);
- undeclared extra response field (ran).
3.1 specs enable JSON Schema 2020 mode automatically in ValidateResponse (read).

## 7. jsonschema v6.0.3 (ran)

Without `compiler.AssertFormat()`, bad `uuid` and `date-time` pass; with it they fail. A renamed optional field passes an open schema either way. Passing a Go struct to `Validate` errors (`invalid jsonType`): use `jsonschema.UnmarshalJSON` on the real bytes.

## 8. Redpanda v26.2.7 schema registry, JSON Schema (ran; code 9.5, 9.6)

Open schema (no `additionalProperties`):

| Change | BACKWARD | FORWARD | FULL |
|---|---|---|---|
| remove optional | **pass** | pass | **pass** |
| remove required | **pass** | fail | fail |
| rename optional | **pass** | **pass** | **pass** |
| rename required / type change | fail | fail | fail |
| add required | fail | pass | fail |
| optional->required | fail | pass | fail |
| required->optional | pass | fail | fail |
| enum add | **pass** | fail | fail |
| enum remove | fail | pass | fail |
| enum->free string | fail | fail | fail |
| meaning (description) | pass | pass | pass |

Closed (`additionalProperties:false`): BACKWARD fails removals and renames, passes add-optional, required->optional, enum add; FORWARD and FULL **reject add-optional**.

Key result: the declared mode alone passes removals and renames that event-schema-design calls always breaking. A **second pass** that submits copies with `additionalProperties:false` injected into every object having `properties`, under `BACKWARD_TRANSITIVE`, fails removal and rename (top level, nested, array items, `$defs` ref, `type:["object","null"]`, property named "properties", inside allOf/anyOf) and passes same/add (no false positive in any shape tested). It reports `PROPERTY_REMOVED_FROM_CLOSED_CONTENT_MODEL` or `COMBINED_TYPE_SUBSCHEMAS_CHANGED`.

Other: `format` date->date-time passes BACKWARD and FULL; default change passes; integer->number and nullable pass BACKWARD, fail FULL; minLength added fails. `BACKWARD_TRANSITIVE` on `/versions/latest` does check older versions (`/versions` without `latest` is 404). Mode NONE reports compatible for anything. Unknown subject: 404 (40401). Malformed schema: 422. 2020-12 `$schema` accepted. API: `PUT /config/{subject} {"compatibility":M}`, `POST /subjects/{s}/versions {"schemaType":"JSON","schema":str}`, `POST /compatibility/subjects/{s}/versions/latest?verbose=true`, content type `application/vnd.schemaregistry.v1+json`. Behaviour of Confluent/Apicurio: unverified.

## 9. Lab code

### 9.1 `mk.py` (oasdiff base spec and variants)
```python
import copy, json
base = {"openapi":"3.1.0","info":{"title":"t","version":"1.0.0"},"paths":{"/v1/classes/{id}":{"get":{"operationId":"getClass",
 "parameters":[{"name":"id","in":"path","required":True,"schema":{"type":"string"}},{"name":"lang","in":"query","required":False,"schema":{"type":"string"}}],
 "responses":{"200":{"description":"ok","headers":{"ETag":{"required":True,"schema":{"type":"string"}}},"content":{"application/json":{"schema":{"$ref":"#/components/schemas/Class"}}}},
 "404":{"description":"nf","content":{"application/json":{"schema":{"$ref":"#/components/schemas/Error"}}}}}}},
 "/v1/bookings":{"post":{"operationId":"book","requestBody":{"required":True,"content":{"application/json":{"schema":{"$ref":"#/components/schemas/NewBooking"}}}},"responses":{"201":{"description":"c","content":{"application/json":{"schema":{"$ref":"#/components/schemas/Class"}}}}}}}},
 "components":{"schemas":{"Class":{"type":"object","required":["id","status","seats"],"properties":{"id":{"type":"string","format":"uuid"},"status":{"type":"string","enum":["open","full","cancelled"]},"seats":{"type":"integer"},"note":{"type":"string"},"room":{"type":["string","null"]}}},
 "NewBooking":{"type":"object","required":["classId"],"properties":{"classId":{"type":"string"},"comment":{"type":"string"},"kind":{"type":"string","enum":["adult","child"]}}},
 "Error":{"type":"object","required":["code"],"properties":{"code":{"type":"string"}}}}}}
json.dump(base,open("base.json","w"),indent=1)
def v(name,f):
    s=copy.deepcopy(base); f(s); json.dump(s,open(name+".json","w"),indent=1)
C=lambda s:s["components"]["schemas"]["Class"]
N=lambda s:s["components"]["schemas"]["NewBooking"]
G=lambda s:s["paths"]["/v1/classes/{id}"]["get"]
v("same",lambda s:None)
v("rm-required-resp",lambda s:(C(s)["properties"].pop("seats"),C(s)["required"].remove("seats")))
v("rm-optional-resp",lambda s:C(s)["properties"].pop("note"))
v("rename-optional-resp",lambda s:C(s)["properties"].__setitem__("remark",C(s)["properties"].pop("note")))
v("resp-required-to-optional",lambda s:C(s)["required"].remove("seats"))
v("resp-type",lambda s:C(s)["properties"]["seats"].__setitem__("type","string"))
v("resp-enum-add",lambda s:C(s)["properties"]["status"]["enum"].append("waitlist"))
v("resp-enum-to-free",lambda s:C(s)["properties"]["status"].pop("enum"))
v("resp-format-removed",lambda s:C(s)["properties"]["id"].pop("format"))
v("resp-nullable",lambda s:C(s)["properties"]["seats"].__setitem__("type",["integer","null"]))
v("meaning-only",lambda s:C(s)["properties"]["seats"].__setitem__("description","now seats TAKEN, not free"))
v("rm-endpoint",lambda s:s["paths"].pop("/v1/bookings"))
v("rm-404",lambda s:G(s)["responses"].pop("404"))
v("add-status",lambda s:G(s)["responses"].__setitem__("429",{"description":"x"}))
v("rm-header",lambda s:G(s)["responses"]["200"].pop("headers"))
v("req-new-required",lambda s:(N(s)["properties"].__setitem__("phone",{"type":"string"}),N(s)["required"].append("phone")))
v("req-opt-to-required",lambda s:N(s)["required"].append("comment"))
v("req-enum-removed",lambda s:N(s)["properties"]["kind"]["enum"].remove("child"))
v("req-rm-field",lambda s:N(s)["properties"].pop("comment"))
v("rm-query-param",lambda s:G(s)["parameters"].pop(1))
v("add-optional-resp",lambda s:C(s)["properties"].__setitem__("extra",{"type":"string"}))
def v2(s):
    p=copy.deepcopy(G(s)); p["operationId"]="getClassV2"; s["paths"]["/v2/classes/{id}"]={"get":p}
v("add-v2-path",v2)
```

### 9.2 `mk2.py` and the runner
```python
import copy, json
base=json.load(open("base.json"))
def v(name,f,b=base):
    s=copy.deepcopy(b); f(s); json.dump(s,open(name+".json","w"),indent=1)
C=lambda s:s["components"]["schemas"]["Class"]
G=lambda s:s["paths"]["/v1/classes/{id}"]["get"]
v("x-rm-success-status",lambda s:G(s)["responses"].__setitem__("203",G(s)["responses"].pop("200")))
v("x-rm-mediatype",lambda s:G(s)["responses"]["200"]["content"].__setitem__("text/plain",G(s)["responses"]["200"]["content"].pop("application/json")))
v("x-rm-resp-schema",lambda s:G(s)["responses"]["200"]["content"]["application/json"].pop("schema"))
v("x-prop-schema-emptied",lambda s:C(s)["properties"].__setitem__("note",{}))
v("x-rm-error-body-schema",lambda s:G(s)["responses"]["404"]["content"]["application/json"].pop("schema"))
v("x-error-required-removed",lambda s:s["components"]["schemas"]["Error"].__setitem__("properties",{"message":{"type":"string"}}) or s["components"]["schemas"]["Error"].__setitem__("required",[]))
v("x-addl-false-to-open",lambda s:C(s).__setitem__("additionalProperties",False))
v("x-security-added",lambda s:(s["components"].__setitem__("securitySchemes",{"b":{"type":"http","scheme":"bearer"}}),G(s).__setitem__("security",[{"b":[]}])))
v("x-maxlen",lambda s:s["components"]["schemas"]["NewBooking"]["properties"]["comment"].__setitem__("maxLength",5))
dep=copy.deepcopy(base); C(dep)["properties"]["note"]["deprecated"]=True; json.dump(dep,open("dep-base.json","w"))
v("d-rm-deprecated-prop",lambda s:C(s)["properties"].pop("note"),dep)
dep2=copy.deepcopy(base); G(dep2)["deprecated"]=True; G(dep2)["x-sunset"]="2020-01-01"; json.dump(dep2,open("dep2-base.json","w"))
v("e-rm-deprecated-endpoint",lambda s:s["paths"].pop("/v1/classes/{id}"),dep2)
pi=copy.deepcopy(base); pi["components"]["pathItems"]={"P":copy.deepcopy(base["paths"]["/v1/classes/{id}"])}; pi["paths"]["/v1/classes/{id}"]={"$ref":"#/components/pathItems/P"}; json.dump(pi,open("pi-base.json","w"))
v("p-pathitems-type-change",lambda s:s["components"]["pathItems"]["P"]["get"]["responses"]["200"]["content"]["application/json"].__setitem__("schema",{"type":"string"}),pi)
v("bump-major",lambda s:(s["info"].__setitem__("version","2.0.0"),C(s)["properties"]["seats"].__setitem__("type","string")))
```
```bash
python3 -I mk.py; python3 -I mk2.py; echo 'response-optional-property-removed err' > sev.txt
for f in *.json; do n=${f%.json}
  oasdiff breaking base.json $f >/dev/null 2>&1; a=$?
  oasdiff breaking --fail-on ERR base.json $f >/dev/null 2>&1; b=$?
  oasdiff breaking --fail-on WARN base.json $f >/dev/null 2>&1; c=$?
  oasdiff changelog -f json base.json $f   # ids and levels
  echo "$n none=$a ERR=$b WARN=$c"
done   # d-, e-, p- variants compare against dep-base, dep2-base, pi-base
```

### 9.3 `k_test.go` (kin-openapi; module lab/kin, base.json copied in)
```go
doc, err := openapi3.NewLoader().LoadFromFile("base.json")
_ = doc.Validate(context.Background())
r, err := gorillamux.NewRouter(doc)
route, params, err := r.FindRoute(req) // req: GET /v1/classes/<uuid>
in := &openapi3filter.ResponseValidationInput{
	RequestValidationInput: &openapi3filter.RequestValidationInput{Request: req, PathParams: params, Route: route},
	Status: status, Header: h, Body: io.NopCloser(bytes.NewReader(body)),
	Options: &openapi3filter.Options{IncludeResponseStatus: include, MultiError: true},
}
err = openapi3filter.ValidateResponse(context.Background(), in)
// imports: openapi3, openapi3filter, routers/gorillamux
// cases: ok, wrong-type, missing-required, bad-enum, bad-uuid, extra-field, null-nonnullable,
// room as number, undocumented 500 text/plain, text/html, empty body, missing ETag, 404 ok, 404 wrong body
```
Formats: `s.VisitJSON("zzz", openapi3.EnableJSONSchema2020(), openapi3.WithStringFormatValidator("uuid", openapi3.NewRegexpFormatValidator(openapi3.FormatOfStringForUUIDOfRFC4122)))`.

### 9.4 jsonschema
```go
c := jsonschema.NewCompiler(); c.AssertFormat()
doc, _ := jsonschema.UnmarshalJSON(strings.NewReader(schemaJSON))
_ = c.AddResource("s.json", doc); s, _ := c.Compile("s.json")
v, _ := jsonschema.UnmarshalJSON(strings.NewReader(eventJSON)); err := s.Validate(v)
```

### 9.5 `m.py` (registry matrix)
```python
import json, urllib.request, copy, urllib.error
U="http://127.0.0.1:18081"
def call(m,p,body=None):
    r=urllib.request.Request(U+p,method=m,data=None if body is None else json.dumps(body).encode(),headers={"Content-Type":"application/vnd.schemaregistry.v1+json"})
    try:
        with urllib.request.urlopen(r) as f: return f.status,json.loads(f.read())
    except urllib.error.HTTPError as e: return e.code,json.loads(e.read() or b"{}")
def S(props,req,addl=None):
    s={"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":props,"required":req}
    if addl is not None: s["additionalProperties"]=addl
    return s
st={"type":"string"}
base_p={"bookingId":st,"seats":{"type":"integer"},"note":st,"kind":{"type":"string","enum":["adult","child"]}}
def v(f,addl=None):
    p=copy.deepcopy(base_p); req=["bookingId","seats"]; f(p,req); return S(p,req,addl)
cases={
 "same":lambda p,r:None,
 "add-optional":lambda p,r:p.__setitem__("x",st),
 "add-required":lambda p,r:(p.__setitem__("x",st),r.append("x")),
 "remove-optional":lambda p,r:p.pop("note"),
 "remove-required":lambda p,r:(p.pop("seats"),r.remove("seats")),
 "rename-optional":lambda p,r:p.__setitem__("remark",p.pop("note")),
 "rename-required":lambda p,r:(p.__setitem__("places",p.pop("seats")),r.remove("seats"),r.append("places")),
 "type-change":lambda p,r:p.__setitem__("seats",st),
 "opt-to-required":lambda p,r:r.append("note"),
 "required-to-opt":lambda p,r:r.remove("seats"),
 "enum-add":lambda p,r:p["kind"]["enum"].append("senior"),
 "enum-remove":lambda p,r:p["kind"]["enum"].remove("child"),
 "enum-to-free":lambda p,r:p.__setitem__("kind",st),
 "meaning":lambda p,r:p.__setitem__("seats",{"type":"integer","description":"now seats remaining"}),
}
for addl in (None,False):
  for mode in ("BACKWARD","FORWARD","FULL"):
    for name,f in cases.items():
        sub=f"{name}-{mode}-{addl}"
        call("PUT",f"/config/{sub}",{"compatibility":mode})
        call("POST",f"/subjects/{sub}/versions",{"schemaType":"JSON","schema":json.dumps(v(lambda p,r:None,addl))})
        c,b=call("POST",f"/compatibility/subjects/{sub}/versions/latest?verbose=true",{"schemaType":"JSON","schema":json.dumps(v(f,addl))})
        print(addl,mode,name,c,b.get("is_compatible"),str(b.get("messages"))[:100])
```

### 9.6 Closed-copy projection (add-only pass)
```python
def close(s):
    if isinstance(s,dict):
        o={k:close(v) for k,v in s.items()}
        if "properties" in s: o["additionalProperties"]=False
        return o
    if isinstance(s,list): return [close(x) for x in s]
    return s
# register close(old...) under BACKWARD_TRANSITIVE on its own subject, check close(new).
```
Note: `close` keys on a literal "properties" key, so a property map that itself holds a property named `properties` also gets the flag injected into the map (harmless in the test run; make the script walk schema keywords properly).

## 10. Audit claims

| Claim | Verdict |
|---|---|
| W3B-39 weak default check (field exists only) | Confirmed by reading |
| W3B-41 hardcoded BACKWARD | Confirmed by reading |
| W3B-36 `t` undefined in provider states | Confirmed by reading (package-level map uses `t`, `testPool`) |
| W3B-37 `{Latest: true}` is not main-branch latest; pending/WIP flags and record-deployment needed | Confirmed by research note (v2.9.1 source); **not run** |
| W3B-38 enum widened to free text passes replay | **Unverified by run**. But oasdiff catches enum->free (ERR) and the registry catches it (all modes) |
| Cruz and Prescott: schema validator passes enum->free | True for validating one payload (unverified run), false for a spec/schema diff (ran). State what each check does |
| Batch "Pact's own no-handler-registered error" for unknown provider state (old reference) | **Unverified, suspect**: test what pact-go 2.9.1 does |
| oasdiff gate catches OpenAPI breaking changes (research "Confirmed") | Only partly: see section 5 silent passes |

## 11. Design settled on (design, nothing built)

1. **HTTP**: (a) diff gate against the **deployed** spec (the git ref recorded at deploy; a missing or unresolvable baseline is a failure, a first release is stated explicitly) using `oasdiff breaking --fail-on WARN --severity-levels <shipped file: response-optional-property-removed err> --config <temp {} yaml>`; WARN because ERR passes request field and query parameter removal; severity override because api-contract-design calls removing any response field breaking. Owner-approved ignore file only, printed on every run. Never MISSING-VERSION-BUMP, `--dry-run`-like bypass, `|| true`, `continue-on-error`. (b) Provider conformance: real router, middleware and handlers; kin-openapi with `IncludeResponseStatus`, uuid validator; harness additionally fails on a status not explicitly documented (covers `default`, redirects, HEAD), on a body where none is documented, and keeps a ledger that fails for any documented operation+status never exercised (no skip list). Data from the integration harness or a fake at a port (say both; behaviour is go-integration-test's). Keep libopenapi-validator as an acceptable alternative (unverified).
2. **Consumers**: consumer's real client against a double whose fixtures are validated against the provider spec; assert values (Go decoding of a missing field gives zero value silently); tolerate unknown fields (no `DisallowUnknownFields`). Front end: types generated from the same spec for mocks (frontend-engineer / react skills own the tool; make no tool claim, nothing run). Shell-to-remote: `react-component-testing`.
3. **Events**: producer test validates real emitted bytes with jsonschema v6 + `AssertFormat()` against the schema named by `dataschema`, plus a test-side closed-copy check (every emitted property declared); consumer test decodes producer sample events incl. every old version and unknown fields/enum values with the real handler. Compatibility: script against a throwaway registry (the mode **read from the event design**, per subject) plus the add-only closed pass; a product's own registry is an equally valid engine. Fail on NONE, missing mode entry, removed subject or version file, in-place edit of a baseline version file; baseline = files at the deployed ref. State: enum addition (notice), format/unit/meaning changes pass.
4. **Pact only on escalation**: keep existing trigger (consumer that does not build from the same spec source: another team or repository, independent deployment), recorded as ADR; the other party must agree to run it (OHS rule). Independent deploys inside one repo are covered by the deployed-spec diff, so file-pinning of expectation files is replaced. Flow: publish (`--branch`, version = git SHA) -> verify with selectors MainBranch, MatchingBranch, DeployedOrReleased, EnablePending, IncludeWIPPactsSince, ProviderBranch, FailIfNoPactsFound, publish results only from CI -> can-i-deploy --to-environment -> deploy -> record-deployment (record-release for libraries). Provider states built by a function taking `t`, real commits with scoped data (`test-fixture-design`). Message pacts via V4. Pact tests tagged `//go:build pact`, run as their own job on every PR (reconciles W3-D10 with test-pyramid; FFI and broker are not in `make ci`). Self-hosted open-source broker; PactFlow refused without approval (state once).
5. **gRPC**: `buf breaking` against the deployed ref, strict category; status-code tests against the real server. Unverified.
6. **Every size** runs it; lean = fewer boundaries, no broker or registry to operate.

### Planned layout
- `SKILL.md` (3.0.0; fixed rules; "What every answer states"; boundary table; numbered procedure; Gotchas; pointer table; `sources:` cruz-prescott, pact-go, oasdiff, go-toolchain, testing-web-apis-winteringham, building-microservices-newman, jsonschema)
- `references/`: `http-contracts.md`, `event-contracts.md`, `pact.md`, `provider-states.md`, `grpc-contracts.md` (replace the four old files after carrying content: schema-vs-contract distinction, consumer-driven rule, boundary with integration test, pending/WIP reasoning, bi-directional/PactFlow, output paths)
- `templates/`: HTTP conformance harness + consumer test, event producer/consumer tests, Pact consumer/provider/states/message, CI workflow, `contract-report.md` (artifact frontmatter; `artifacts/<product>/quality/test-reports/`)
- `resources/checklist.md`, `resources/oasdiff-severity.txt`
- `scripts/`: `check-openapi-breaking.sh` (refuse empty/no-paths/non-OpenAPI baseline, own config, pinned version check, exit 0/1/2), `check-event-compatibility.sh` (loopback registry only; `schemas/events/<context>/<name>/<n>.json` + a mode list), `validate-go-contract-tests.sh` (text checks: missing IncludeResponseStatus, no AssertFormat, no FailIfNoPactsFound, `Latest: true`, `--dry-run`, SoftFail, oasdiff without --fail-on, `|| true`); tests in `tests/scripts/` using a fake oasdiff and a fake registry HTTP server
- `examples/`: three new products (ideas: lean dance-class sign-up with React client; standard three services in one repo with events; enterprise ferry ticketing with a travel-agency partner on Pact)
- Delete `tests/skills/go-contract-test.contract.sh` only after evals pass (leave it now).

### Outside the skill (check)
`agents/test-strategist.md` directive 9 ("Schema-based contracts over a Pact broker") and Methodology row; `go-openapi-codegen` line ~158 (consumer tests from generated client: compatible); `go-makefile` (`make ci`, no pact tag mentioned); `sdlc-context.json` lists the skill; run catalog rebuild. python-contract-test must stay consistent later.

## 12. Product-owner decisions to raise

1. oasdiff gate strictness: WARN plus raising optional response-property removal to error.
2. Removed documented error status passes oasdiff (INFO); api-contract-design does not classify it. Raise it or not?
3. Response enum value added fails oasdiff (ERR) while event design treats enum addition as "additive with notice" and the API table is silent: approval route via the ignore file?
4. Event add-only closed-copy pass in addition to the declared mode (is this acceptable under "replacing hand-written checkers"?).
5. Pact trigger wording; Pact job separate from `make ci`.
6. Endpoint removed after sunset passes the tool; "no remaining caller" needs a separate check.

## 13. Remaining work

1. Pact end to end on a local broker (wait for Postgres first): consumer, provider verify, pending/WIP behaviour and exit status, unknown provider state, zero pacts without FailIfNoPactsFound, auth RequestFilter, message pact, publish, can-i-deploy (including nothing recorded as deployed, unverified pair, `--dry-run`), record-deployment, breaking change fails. pact-cli image entry points unverified.
2. buf breaking: renumber/rename per category, breaking case fails.
3. Enum-widening replay experiment (W3B-38); consumer decoding experiments.
4. Build scripts and tests; templates and three examples compiled and run (with failing breaking cases); coverage-gate interaction with `pact`-tagged test files (go-unit-test: build-tagged production files give "no result"; effect of tagged test files unverified).
5. Write SKILL.md, references, checklist; read the unread files in section 2; align agents; run the final checks.
