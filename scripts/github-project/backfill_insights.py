#!/usr/bin/env python3
"""Backfill the SKILL GEN Project's Insights fields on every board item (#1266).

Usage:
  backfill_insights.py            dry run: per-field distribution + pending write count
  backfill_insights.py --apply    write the values (batched, throttled, resumable)
  backfill_insights.py --only N   restrict writes to issue/PR number N (repeatable)

Values come from ghp/insights.derive_all(), which is the same rule set the
plan/exec tooling uses going forward. The run is idempotent: a value that
already matches is skipped. An item whose Data-Source is "Triaged" keeps its
Priority, Severity and Complexity, because a person set them on purpose.
"""

import argparse
import collections
import json
import sys
import time

from ghp import config, gh, insights, project

BATCH = 20
PAUSE = 1.0
TRIAGE_PROTECTED = ("Priority", "Severity", "Complexity", "Effort-Points", "Data-Source")

ITEM_QUERY = """
query($c: String) {
  node(id: "%s") {
    ... on ProjectV2 {
      items(first: 50, after: $c) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id type
          fieldValues(first: 30) {
            nodes {
              __typename
              ... on ProjectV2ItemFieldSingleSelectValue { name field { ... on ProjectV2FieldCommon { name } } }
              ... on ProjectV2ItemFieldNumberValue { number field { ... on ProjectV2FieldCommon { name } } }
              ... on ProjectV2ItemFieldIterationValue { title field { ... on ProjectV2FieldCommon { name } } }
            }
          }
          content {
            ... on Issue {
              number title createdAt closedAt
              labels(first: 10) { nodes { name } }
              parent { number }
              subIssues(first: 1) { totalCount }
              issueDependenciesSummary { totalBlockedBy totalBlocking }
            }
            ... on PullRequest {
              number title createdAt closedAt headRefName baseRefName additions deletions changedFiles
              labels(first: 10) { nodes { name } }
              closingIssuesReferences(first: 5) { nodes { number } }
            }
          }
        }
      }
    }
  }
}
""" % config.PROJECT_ID


def fetch_items():
    items, cursor = [], None
    while True:
        args = ["api", "graphql", "-f", f"query={ITEM_QUERY}"]
        if cursor:
            args += ["-f", f"c={cursor}"]
        data = json.loads(gh._run(args))
        if "errors" in data:
            raise gh.GhError("GitHub API error: " + json.dumps(data["errors"], indent=2))
        page = data["data"]["node"]["items"]
        items += [n for n in page["nodes"] if n.get("content")]
        if not page["pageInfo"]["hasNextPage"]:
            return items
        cursor = page["pageInfo"]["endCursor"]


def current_values(node):
    out = {}
    for v in node["fieldValues"]["nodes"]:
        name = (v.get("field") or {}).get("name")
        if name:
            out[name] = v.get("name") or v.get("title") or v.get("number")
    return out


def plan_writes(nodes, only=None):
    facts = [insights.normalize(n) for n in nodes]
    derived = insights.derive_all(facts)
    by_id = {n["id"]: n for n in nodes}
    numbers = {f["item_id"]: f["number"] for f in facts}
    writes = []
    for item_id, values in derived.items():
        if only and numbers[item_id] not in only:
            continue
        have = current_values(by_id[item_id])
        triaged = have.get("Data-Source") == "Triaged"
        for field, value in values.items():
            if value is None:
                continue
            if triaged and field in TRIAGE_PROTECTED:
                continue
            if have.get(field) == value:
                continue
            writes.append((item_id, field, value))
    return derived, writes


def value_literal(fields, field, value):
    meta = fields[field]
    if field in config.INSIGHTS_NUMBER:
        return f"{{ number: {float(value)} }}"
    if field == config.SPRINT_FIELD_NAME:
        return f'{{ iterationId: "{meta["options"][value]}" }}'
    return f'{{ singleSelectOptionId: "{meta["options"][value]}" }}'


def apply_writes(writes, fields):
    done = 0
    for start in range(0, len(writes), BATCH):
        chunk = writes[start:start + BATCH]
        body = "\n".join(
            f"""w{i}: updateProjectV2ItemFieldValue(input: {{
                  projectId: "{config.PROJECT_ID}" itemId: "{item_id}"
                  fieldId: "{fields[field]['id']}" value: {value_literal(fields, field, value)}
                }}) {{ clientMutationId }}"""
            for i, (item_id, field, value) in enumerate(chunk)
        )
        for attempt in range(6):
            try:
                gh.graphql(f"mutation {{ {body} }}")
                break
            except gh.GhError as e:
                if attempt == 5:
                    raise
                wait = 60 if "rate limit" in str(e).lower() else 5 * (attempt + 1)
                print(f"  retry in {wait}s: {str(e).splitlines()[0][:120]}", flush=True)
                time.sleep(wait)
        done += len(chunk)
        if done % 500 < BATCH:
            print(f"  {done}/{len(writes)} written", flush=True)
        time.sleep(PAUSE)
    return done


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--only", type=int, action="append")
    args = ap.parse_args()

    gh.check_auth()
    fields = project.ensure_insights_fields()
    nodes = fetch_items()
    derived, writes = plan_writes(nodes, set(args.only) if args.only else None)

    print(f"{len(nodes)} board items.\n")
    for field in list(config.INSIGHTS_SINGLE_SELECT) + [config.SPRINT_FIELD_NAME]:
        dist = collections.Counter(v[field] for v in derived.values())
        print(f"{field:13} " + "  ".join(f"{k}={n}" for k, n in sorted(dist.items(), key=lambda kv: -kv[1])))
    print(f"\n{len(writes)} field value(s) to write.")
    if not args.apply:
        print("Dry run. Re-run with --apply to write them.")
        return
    n = apply_writes(writes, fields)
    print(f"Done: {n} value(s) written.")


if __name__ == "__main__":
    try:
        main()
    except gh.GhError as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)
