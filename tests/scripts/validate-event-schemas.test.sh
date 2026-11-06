#!/bin/bash
# Tests skills/event-schema-design/scripts/validate-event-schemas.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/event-schema-design/scripts/validate-event-schemas.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <file> <exit> [substring that must appear]
  local out code
  out="$("$VALIDATE" "$2" 2>&1)"; code=$?
  if [ "$code" -eq "$3" ] && { [ -z "${4:-}" ] || echo "$out" | grep -qF -- "$4"; }; then
    _pass "validate-event-schemas: $1"
  else
    _fail "validate-event-schemas: $1" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

cat > good.md <<'EOF'
---
name: event-schema
product: hivewatch
version: 1.0.0
phase: design
owner: data-architect
created: 2026-03-02
summary: Hivewatch's hive-weight events use CloudEvents JSON with a registry in BACKWARD mode.
profile: standard
traces-to: [design/apiary/domain-event-catalog.md]
---

# Event Schemas: Hivewatch

## Conventions

| Convention | Value |
|---|---|
| **Envelope** | CloudEvents 1.0 — spec-required: specversion, id, source, type; house-required: datacontenttype, dataschema, subject, time |
| **Extensions** | correlationid, causationid — set by the producer |
| **Type naming** | org.hivewatch.<context>.<aggregate>.<verb>, lower-case |
| **Source** | /apiary |
| **Format** | JSON with tolerant readers — readable |
| **Content mode** | structured — simple |
| **Registry** | Apicurio Registry — four teams |
| **Default compatibility** | BACKWARD — consumers upgrade first |
| **CI gate** | registration fails the build on an incompatible version |

## Event: org.hivewatch.apiary.hive.weighed

| Field | Value |
|---|---|
| **Domain Event** | HiveWeighed — design/apiary/domain-event-catalog.md |
| **Kind** | published |
| **source** | /apiary |
| **subject** | hiveId |
| **dataschema** | https://schemas.hivewatch.example/hive-weighed/2 |
| **Compatibility** | BACKWARD |
| **Consumers** | Honey Forecast |

### Payload (data)

| Field | Type | Required | Default for old events | Why included |
|---|---|---|---|---|
| hiveId | string | yes | — | the hive |
| grams | integer | yes | — | the weight |
| scaleModel | string | no | absent = model not recorded | calibration |

### Change log

| Date | Change | Class | Action |
|---|---|---|---|
| 2026-03-01 | add optional scaleModel | additive | in place |
EOF
expect "a complete document passes and counts types" good.md 0 "INFO: 1 event type(s)"

sed 's/^## Event: org.hivewatch.apiary.hive.weighed$/## Event: org.hivewatch.apiary.hive.weighed.v2/' good.md > vsuffix.md
expect "a version suffix in the type fails" vsuffix.md 1 "FAIL: org.hivewatch.apiary.hive.weighed.v2: no version suffix in the type"

sed 's/^## Event: org.hivewatch.apiary.hive.weighed$/## Event: HiveWeighed/' good.md > camel.md
expect "a CamelCase type fails" camel.md 1 "FAIL: HiveWeighed: type is lower-case reverse-DNS"

sed 's/spec-required: specversion, id, source, type;/spec-required: specversion, id, source, type, datacontenttype;/' good.md > five.md
expect "listing datacontenttype as spec-required fails" five.md 1 "FAIL: conventions: the spec-required attributes are exactly specversion, id, source, type"

sed 's/| \*\*Extensions\*\* | correlationid, causationid — set by the producer |/| **Extensions** | correlationId, causation_id — set by the producer |/' good.md > extcase.md
expect "camelCase or underscored extension names fail" extcase.md 1 "FAIL: conventions: extension names use lower-case letters and digits only"

sed 's/| \*\*Extensions\*\* | correlationid, causationid — set by the producer |/| **Extensions** | causationid — set by the producer |/' good.md > noext.md
expect "a missing correlationid extension fails" noext.md 1 "FAIL: conventions: the 'correlationid' extension is declared"

sed 's#| \*\*source\*\* | /apiary |#| **source** | /apiary/v1.4.0 |#' good.md > srcver.md
expect "a deploy version in source fails" srcver.md 1 "FAIL: org.hivewatch.apiary.hive.weighed: source is stable"

sed 's/| \*\*Compatibility\*\* | BACKWARD |/| **Compatibility** | NONE |/' good.md > none.md
expect "NONE compatibility fails" none.md 1 "FAIL: org.hivewatch.apiary.hive.weighed: compatibility is not NONE"

sed 's/| hiveId | string | yes | — | the hive |/| hiveId | string | yes | — | the hive |\n| eventId | string | yes | — | dedup |/' good.md > envfield.md
expect "an envelope attribute in the payload fails" envfield.md 1 "FAIL: org.hivewatch.apiary.hive.weighed: payload field 'eventId' is not an envelope attribute"

sed 's/| scaleModel | string | no | absent = model not recorded | calibration |/| scaleModel | string | no | | calibration |/' good.md > nodefault.md
expect "an optional field with no default fails" nodefault.md 1 "FAIL: org.hivewatch.apiary.hive.weighed: optional field 'scaleModel' states its default"

sed 's/| 2026-03-01 | add optional scaleModel | additive | in place |/| 2026-03-01 | rename grams to weightGrams | additive | in place |/' good.md > renameadd.md
expect "a rename classed additive fails" renameadd.md 1 "is classed breaking, not additive"

sed 's/| 2026-03-01 | add optional scaleModel | additive | in place |/| 2026-03-01 | rename grams to weightGrams | breaking | edit in place |/' good.md > breakinplace.md
expect "a breaking change made in place fails" breakinplace.md 1 "takes a new type with dual publishing"

sed 's/| 2026-03-01 | add optional scaleModel | additive | in place |/| 2026-03-01 | rename grams to weightGrams | breaking | new type org.hivewatch.apiary.hive.weighed-in-grams, dual publish until 2026-05-01 |/' good.md > breakok.md
expect "a breaking change with a new type and a window passes" breakok.md 0

sed 's/| 2026-03-01 | add optional scaleModel | additive | in place |/| 2026-03-01 | rename grams to weightGrams | breaking | upcaster v1→v2 |/' good.md > upcastpub.md
expect "upcasting a published event fails" upcastpub.md 1 "FAIL: org.hivewatch.apiary.hive.weighed: upcasting is used only for stored events"

sed 's/| \*\*Kind\*\* | published |/| **Kind** | stored (event-sourced, internal) |/' upcastpub.md > upcaststored.md
expect "upcasting a stored event passes" upcaststored.md 0

sed '/^traces-to:/d' good.md > notrace.md
expect "missing traces-to fails" notrace.md 1 "FAIL: frontmatter has"

{ cat good.md; printf '\n```go\ntype HiveWeighed struct{}\n```\n'; } > code.md
expect "code in the design fails (D047-10)" code.md 1 "FAIL: no code in the design"

out="$("$VALIDATE" 2>&1)"; code=$?
[ "$code" -eq 2 ] && _pass "validate-event-schemas: no argument exits 2" || _fail "validate-event-schemas: no argument exits 2" "exit $code"
"$VALIDATE" /no/such/file.md >/dev/null 2>&1; code=$?
[ "$code" -eq 2 ] && _pass "validate-event-schemas: a missing file exits 2" || _fail "validate-event-schemas: a missing file exits 2" "exit $code"

smoke_test_summary
