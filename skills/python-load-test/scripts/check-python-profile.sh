#!/bin/bash
# check-python-profile.sh <tests/load/profile.json> [--subjects <n>]
#
# The Python additions to a load profile, checked before any run. The shared
# runner reads the profile's limiter as one figure per subject; a Python
# service's in-memory rate limiter counts per process (each uvicorn worker of
# each replica has its own buckets), so this script checks that the figure was
# derived from the server's real shape:
#   server   workers, replicas, runtime, limit_concurrency (null or a number) and
#            where they are configured; Gunicorn with --limit-concurrency, which
#            uvicorn does not support there, fails; the deprecated
#            uvicorn.workers module is a warning
#   limiter  per_process_per_second and per_process_burst; per_subject_per_second
#            and burst must equal them times workers times replicas
#   steady   every rate is spread so that one subject stays within ONE process's
#            limit, because a subject's requests can land on one process; with
#            --subjects <n> (LOAD_SUBJECT_COUNT) too few subjects fail
#   overload one subject must exceed workers x replicas x the per-process rate,
#            or no 429 is ever returned
#   connections  k6 keeps one connection per virtual user, and uvicorn counts
#            open connections, idle ones too, against --limit-concurrency: a
#            warning where the virtual users reach the limit
# It runs nothing and sends nothing. Exit 0 = no FAIL (judge each WARN);
# 1 = at least one FAIL; 2 = usage or an unreadable profile.
set -uo pipefail
if [ "$#" -lt 1 ]; then
  echo "usage: check-python-profile.sh <tests/load/profile.json> [--subjects <n>]" >&2
  exit 2
fi
exec python3 -I - "$@" << 'PY'
import json, math, re, sys

args = sys.argv[1:]
path, subjects = args[0], None
if len(args) == 3 and args[1] == "--subjects" and args[2].isdigit() and int(args[2]) > 0:
    subjects = int(args[2])
elif len(args) != 1:
    print("usage: check-python-profile.sh <tests/load/profile.json> [--subjects <n>]", file=sys.stderr)
    sys.exit(2)
try:
    profile = json.load(open(path, encoding="utf-8"))
    assert isinstance(profile, dict)
except (OSError, ValueError, AssertionError) as exc:
    print(f"ERROR: cannot read {path} as a JSON object ({exc})", file=sys.stderr)
    sys.exit(2)

fails = warns = 0


def report(level, message):
    global fails, warns
    fails += level == "FAIL"
    warns += level == "WARN"
    print(f"{level} {message}")


number = lambda v: isinstance(v, (int, float)) and not isinstance(v, bool) and v > 0
whole = lambda v: isinstance(v, int) and not isinstance(v, bool) and v >= 1
text = lambda v: isinstance(v, str) and v.strip() and not re.search(r"<[^>]*>|\bTBD\b|\bTODO\b", v)
server = profile.get("server") if isinstance(profile.get("server"), dict) else {}
limiter = profile.get("limiter") if isinstance(profile.get("limiter"), dict) else {}

if not server:
    report("FAIL", "server: missing. State workers, replicas, runtime, limit_concurrency and source: the limiter counts per process")
for key, test, what in (("workers", whole, "uvicorn worker processes per replica (python-dockerfile runs one)"),
                        ("replicas", whole, "replicas in the environment under test"),
                        ("runtime", text, "the server and its version, for example uvicorn 0.54.0"),
                        ("source", text, "where workers, replicas and the limit are configured")):
    if server and not test(server.get(key)):
        report("FAIL", f"server.{key}: {what}")
if server and "limit_concurrency" not in server:
    report("FAIL", "server.limit_concurrency: null when uvicorn runs without --limit-concurrency, else its value per process")
limit = server.get("limit_concurrency")
if limit is not None and not whole(limit):
    report("FAIL", "server.limit_concurrency: null or a whole number")
runtime = str(server.get("runtime", "")).lower()
if "gunicorn" in runtime and whole(limit):
    report("FAIL", "server: --limit-concurrency is not supported when uvicorn runs under Gunicorn (uvicorn's deployment documentation)")
if "uvicorn.workers" in runtime:
    report("WARN", "server.runtime: the uvicorn.workers module is deprecated; the separate uvicorn-worker package replaces it")

processes = server.get("workers", 0) * server.get("replicas", 0) if whole(server.get("workers")) and whole(server.get("replicas")) else None
per_rate, per_burst = limiter.get("per_process_per_second"), limiter.get("per_process_burst")
if not number(per_rate) or not number(per_burst):
    report("FAIL", "limiter.per_process_per_second and limiter.per_process_burst: the limit one process enforces (python-middleware's limiter is in memory)")
elif processes:
    for key, per in (("per_subject_per_second", per_rate), ("burst", per_burst)):
        want = per * processes
        if not number(limiter.get(key)) or abs(limiter[key] - want) > 1e-9:
            report("FAIL", f"limiter.{key} is {limiter.get(key)}, but {per} per process x {server['workers']} worker(s) x "
                           f"{server['replicas']} replica(s) is {want:g}: a subject's requests are spread over every process")

rows = []
most_users = 0
for tier in ("indicative", "verdict"):
    for kind, entry in sorted((profile.get(tier) or {}).items()):
        if not isinstance(entry, dict):
            continue
        if number(entry.get("virtual_users")):
            most_users = max(most_users, entry["virtual_users"])
        rate = entry.get("rate_per_second")
        if not number(rate) or not number(per_rate):
            continue
        if kind == "overload":
            effective = limiter.get("per_subject_per_second")
            if number(effective) and rate <= effective:
                report("FAIL", f"{tier}.overload: {rate}/s on one subject does not exceed {effective:g}/s, the per-process rate times "
                               "workers times replicas; no 429 would be returned")
            continue
        need = math.ceil(rate / per_rate)
        rows.append((tier, kind, rate, need))
        if subjects is not None and subjects < need:
            report("FAIL", f"{tier}.{kind}: {rate}/s over {subjects} subject(s) is {rate / subjects:.2f}/s each, above one process's "
                           f"{per_rate:g}/s; use at least {need} subjects (LOAD_SUBJECT_COUNT)")
if whole(limit) and most_users >= limit:
    report("WARN", f"k6 may hold {most_users:g} connections (one per virtual user) and uvicorn counts open connections, idle ones too, "
                   f"against --limit-concurrency {limit} per process: its own 503 can arrive before the rate limiter answers")

if processes:
    print(f"server: {server['workers']} worker(s) x {server['replicas']} replica(s) = {processes} process(es)")
if number(per_rate) and processes:
    print(f"one subject is answered 429 only above about {per_rate * processes:g}/s (burst {per_burst * processes:g})")
for tier, kind, rate, need in rows:
    print(f"{tier}.{kind}: {rate}/s needs at least {need} subject(s) to stay within one process's limit")
print(f"check-python-profile: {fails} FAIL, {warns} WARN")
sys.exit(1 if fails else 0)
PY
