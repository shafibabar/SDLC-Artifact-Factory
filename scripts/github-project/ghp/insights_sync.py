"""Read/diff/write plumbing for the Insights fields (#1266).

Shared by backfill_insights.py (every board item) and the plan/exec tooling.
sync() handles only the items a command just touched, plus the context their
rules need: the parent chain for campaign inheritance, and the owning issue
for a PR. A failing sync() prints a warning and never fails the calling
command, because the board fields are reporting data, not workflow state.
"""

import json
import sys
import time

from . import config, gh, insights, project

BATCH = 20
PAUSE = 1.0
TRIAGE_PROTECTED = ("Priority", "Severity", "Complexity", "Effort-Points", "Data-Source")

CONTENT = """
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
"""

FIELD_VALUES = """
  fieldValues(first: 30) {
    nodes {
      ... on ProjectV2ItemFieldSingleSelectValue { name field { ... on ProjectV2FieldCommon { name } } }
      ... on ProjectV2ItemFieldNumberValue { number field { ... on ProjectV2FieldCommon { name } } }
      ... on ProjectV2ItemFieldIterationValue { title field { ... on ProjectV2FieldCommon { name } } }
    }
  }
"""

ITEM_QUERY = (
    """query($c: String) { node(id: "%s") { ... on ProjectV2 {
  items(first: 50, after: $c) { pageInfo { hasNextPage endCursor }
    nodes { id type %s content { %s } } } } } }"""
    % (config.PROJECT_ID, FIELD_VALUES, CONTENT)
)


def fetch_items():
    """Every item on the board, as ProjectV2 item nodes."""
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


def fetch_numbers(numbers):
    """The board items for these issue/PR numbers, in the same node shape as
    fetch_items(). Numbers not on the board are skipped."""
    numbers = sorted(set(numbers))
    if not numbers:
        return []
    body = "\n".join(
        f"""n{n}: issueOrPullRequest(number: {int(n)}) {{
              __typename {CONTENT}
              ... on Issue {{ projectItems(first: 10) {{ nodes {{ id project {{ id }} {FIELD_VALUES} }} }} }}
              ... on PullRequest {{ projectItems(first: 10) {{ nodes {{ id project {{ id }} {FIELD_VALUES} }} }} }}
            }}"""
        for n in numbers
    )
    data = gh.graphql(
        f'query {{ repository(owner: "{config.REPO_OWNER}", name: "{config.REPO_NAME}") {{ {body} }} }}'
    )["repository"]
    nodes = []
    for n in numbers:
        c = data.get(f"n{n}")
        if not c:
            continue
        for item in c["projectItems"]["nodes"]:
            if item["project"]["id"] == config.PROJECT_ID:
                nodes.append({
                    "id": item["id"],
                    "type": "PULL_REQUEST" if c["__typename"] == "PullRequest" else "ISSUE",
                    "fieldValues": item["fieldValues"],
                    "content": c,
                })
    return nodes


def current_values(node):
    out = {}
    for v in node["fieldValues"]["nodes"]:
        name = (v.get("field") or {}).get("name")
        if name:
            out[name] = v.get("name") or v.get("title") or v.get("number")
    return out


def plan_writes(nodes, only=None, triaged=None):
    """Derive values for every node, then return (derived, writes), where writes
    lists (item_id, field, value) for values that differ from the board.
    only: restrict writes to these issue/PR numbers. triaged: {number: {field:
    value}} set deliberately by a person; these win and mark Data-Source=Triaged."""
    facts = [insights.normalize(n) for n in nodes]
    derived = insights.derive_all(facts)
    by_id = {n["id"]: n for n in nodes}
    numbers = {f["item_id"]: f["number"] for f in facts}
    triaged = triaged or {}
    writes = []
    for item_id, values in derived.items():
        number = numbers[item_id]
        if only and number not in only:
            continue
        have = current_values(by_id[item_id])
        chosen = {k: v for k, v in (triaged.get(number) or {}).items() if v}
        if chosen:
            values.update(chosen)
            if "Complexity" in chosen:
                values["Effort-Points"] = float(insights.EFFORT_POINTS[chosen["Complexity"]])
            values["Data-Source"] = "Triaged"
        protect = have.get("Data-Source") == "Triaged" and not chosen
        for field, value in values.items():
            if value is None or have.get(field) == value:
                continue
            if protect and field in TRIAGE_PROTECTED:
                continue
            writes.append((item_id, field, value))
    return derived, writes


def _value_literal(fields, field, value):
    meta = fields[field]
    if field in config.INSIGHTS_NUMBER:
        return f"{{ number: {float(value)} }}"
    if field == config.SPRINT_FIELD_NAME:
        return f'{{ iterationId: "{meta["options"][value]}" }}'
    return f'{{ singleSelectOptionId: "{meta["options"][value]}" }}'


def apply_writes(writes, fields, progress=False):
    done = 0
    for start in range(0, len(writes), BATCH):
        chunk = writes[start:start + BATCH]
        body = "\n".join(
            f"""w{i}: updateProjectV2ItemFieldValue(input: {{
                  projectId: "{config.PROJECT_ID}" itemId: "{item_id}"
                  fieldId: "{fields[field]['id']}" value: {_value_literal(fields, field, value)}
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
        if progress and done % 500 < BATCH:
            print(f"  {done}/{len(writes)} written", flush=True)
        if len(writes) > BATCH:
            time.sleep(PAUSE)
    return done


def sync(numbers, triaged=None):
    """Derive and write the Insights fields for these issue/PR numbers.
    Context items are fetched so the rules see the whole picture, but only the
    targets are written. Returns the number of values written (0 on failure)."""
    targets = {int(n) for n in numbers if n}
    try:
        nodes, seen, frontier = [], set(), set(targets)
        while frontier:
            batch = fetch_numbers(frontier - seen)
            seen |= frontier
            nodes += batch
            frontier = set()
            for node in batch:
                f = insights.normalize(node)
                if f["parent"]:
                    frontier.add(f["parent"])
                m = insights._ISSUE_HEAD.match(f["head"])
                if m:
                    frontier.add(int(m.group(1)))
                frontier |= set(f["closes"])
            frontier -= seen
        _, writes = plan_writes(nodes, only=targets, triaged=triaged)
        return apply_writes(writes, project.ensure_insights_fields())
    except (gh.GhError, KeyError) as e:
        print(f"warning: Insights fields not updated for {sorted(targets)}: {e}", file=sys.stderr)
        return 0
