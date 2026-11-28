# The Designation Record, the Marker and the Test Subjects

Self-contained. Copy when a product gets a designated performance environment, when its designation is renewed, or when the test subjects are set up. Without all three parts the verdict tier refuses to start. Each refusal below was run on 2026-11-28 against a lab service; the service received no request of the test in any of them.

## 1. The record, signed by the product owner

### `tests/load/designation.json`

```json
{
  "designation_id": "perf-parcel-lockers-2026-11",
  "product": "parcel-lockers",
  "base_url": "http://127.0.0.1:18080",
  "approved_by": "Product owner",
  "approved_on": "2026-11-28",
  "expires_on": "2026-12-28",
  "sizing": "3 replicas of 1 CPU and 512 Mi, PostgreSQL 2 CPU and 8 Gi: the sizing NFR-PERF-01 is stated for",
  "data": "200,000 open parcels, loaded by the environment's seed job; no copy of customer data",
  "generator": "one runner of 4 CPU inside the environment's network",
  "test_types": [
    "smoke",
    "average-load",
    "stress",
    "soak",
    "spike",
    "breakpoint",
    "overload"
  ],
  "token_max_minutes": 180
}
```

| Field | Rule |
|---|---|
| `designation_id` | A name for this designation. The environment must serve the same value (part 2) |
| `base_url` | The exact address: scheme, host and port, nothing after it. `https`, except on loopback. The runner sends load nowhere else |
| `approved_by`, `approved_on` | The product owner's sign-off and its date. Empty, a placeholder or a future date is refused |
| `expires_on` | The day after which the runner refuses. The product owner chooses it and renews the record by changing it in a reviewed commit |
| `sizing`, `data` | What the environment has, in the terms of the NFR's Environment cell. They are printed in every report: a verdict holds for this sizing and data only |
| `generator` | Where the load generator runs and how large it is |
| `test_types` | The test types the product owner allows here. A breakpoint or soak test not listed is refused |
| `token_max_minutes` | The longest life a test token may have. It must outlast the longest run and nothing more |

The file is committed. It holds no secret.

## 2. The marker the environment serves

The designated environment answers `GET /.well-known/load-test-designation` with `{"designation_id": "<the same id>"}`, without credentials. `platform-engineer` adds the route in that environment's values only (a fixed response at the ingress, or a small static service). No other environment serves it.

The record alone proves someone approved an address. The marker proves the thing at that address is the environment that was approved: an address that now points elsewhere, a record copied into another product, or a staging or production host written into the record all fail here.

| The runner refuses when | Seen |
|---|---|
| No `--designation` | `REFUSED: the verdict tier needs --designation <record>` |
| No sign-off | `the designation record has no approved_by: it carries no product-owner sign-off` |
| Expired | `the designation expired on 2026-11-27; the product owner has to renew it` |
| A host named like staging or production | `"api.staging.example.com" is named like a shared staging or production environment (staging); load never goes there, whatever the record says` |
| The address serves no marker | `does not serve a designation marker (HTTP Error 404: Not Found); it is not the designated environment` |
| The address serves another id | `serves designation "some-other-environment", the record says "perf-lab-1"` |
| The test type is not listed | `the designation does not allow the average-load test (allowed: smoke)` |

Every refusal exits 3. The name check stops an honest mistake only; it is not what makes staging safe. The marker is.

## 3. The test subjects

Steady load is spread over enough subjects that each stays inside the rate limit, so the run needs one identity per subject.

### `tests/load/issue-subjects.sh`

```bash
#!/bin/bash
# tests/load/issue-subjects.sh: called by run-load-test.sh. Writes the test subjects of one run to
# LOAD_SUBJECTS_FILE as [{"id","token","expires_at"}]. Nothing it writes is kept: the runner deletes the file.
#   indicative  test-only identities that exist only in the throwaway cluster (its values file accepts them)
#   verdict     one short-lived token per subject from LOAD_TOKEN_CMD "<subject> <minutes>", the command that
#               asks the designated environment's identity provider; never a token kept in a file or a secret
set -uo pipefail
SUBJECTS="${LOAD_SUBJECT_COUNT:-4}"
MINUTES="${LOAD_TOKEN_MINUTES:-150}"
if [ "$LOAD_TIER" = "verdict" ] && [ -z "${LOAD_TOKEN_CMD:-}" ]; then
  echo "ERROR: LOAD_TOKEN_CMD is not set: it must print a short-lived token for the subject it is given" >&2
  exit 1
fi
python3 -I - "$LOAD_TIER" "$SUBJECTS" "$MINUTES" "${LOAD_TOKEN_CMD:-}" > "$LOAD_SUBJECTS_FILE" << 'PY'
import datetime, json, shlex, subprocess, sys
tier, count, minutes, command = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
expires = (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(minutes=minutes)).isoformat()
subjects = []
for n in range(count):
    name = f"load-subject-{n}"
    if tier == "indicative":
        token = f"e2e-only-{name}"
    else:
        token = subprocess.run(shlex.split(command) + [name, str(minutes)], capture_output=True, text=True, check=True).stdout.strip()
    subjects.append({"id": name, "token": token, "expires_at": expires})
print(json.dumps(subjects))
PY
```

- **Indicative tier: nothing stored.** The identities exist only in the throwaway cluster, whose values file makes the product accept them (`environment-config` allows test-only identities to differ). They are not secrets and work nowhere else.
- **Verdict tier: short-lived tokens the product owner approved, never a standing one.** `LOAD_TOKEN_CMD` names the product's command that asks the designated environment's identity provider for a token for one subject. The runner refuses a token with no `expires_at`, one already expired, and one that lives longer than `token_max_minutes` (run: a token valid until 2027 was refused), and deletes the file after the run.
- How the command authenticates is the product's choice among mechanisms that store no credential: a person running `make load-verdict` after signing in, or a workflow's OpenID Connect identity, are two. A token in a repository secret is not one.

The shipped script was run in both tiers with a stand-in for `LOAD_TOKEN_CMD`. No real identity provider was used: that part is unverified.
