"""High-level GitHub Project v2 + Issues operations used by the plan/execute
CLI commands. Every mutation here is check-before-create / safe to re-run.
"""

from . import config, gh

_sequence_field_id_cache = None


def ensure_sequence_field():
    """Return the Sequence field's id, creating it (as TEXT) if missing."""
    global _sequence_field_id_cache
    if _sequence_field_id_cache:
        return _sequence_field_id_cache

    data = gh.graphql(
        f"""
        query {{
          node(id: "{config.PROJECT_ID}") {{
            ... on ProjectV2 {{
              fields(first: 50) {{
                nodes {{
                  ... on ProjectV2FieldCommon {{ id name }}
                }}
              }}
            }}
          }}
        }}
        """
    )
    for field in data["node"]["fields"]["nodes"]:
        if field.get("name") == config.SEQUENCE_FIELD_NAME:
            _sequence_field_id_cache = field["id"]
            return _sequence_field_id_cache

    data = gh.graphql(
        f"""
        mutation {{
          createProjectV2Field(input: {{
            projectId: "{config.PROJECT_ID}"
            dataType: TEXT
            name: {gh.gql_string(config.SEQUENCE_FIELD_NAME)}
          }}) {{
            projectV2Field {{
              ... on ProjectV2FieldCommon {{ id }}
            }}
          }}
        }}
        """
    )
    _sequence_field_id_cache = data["createProjectV2Field"]["projectV2Field"]["id"]
    return _sequence_field_id_cache


def create_issue(title, body, parent_issue_id=None, labels=None):
    """Create an issue in the tracked repo. If parent_issue_id is given,
    creates it as a native GitHub sub-issue of that parent in the same call.
    labels is required (Shafi's decision, 2026-07-24) -- validated before
    the mutation runs so a bad label set never creates an orphaned issue."""
    gh.validate_labels(labels)
    parent_clause = (
        f"parentIssueId: {gh.gql_string(parent_issue_id)}" if parent_issue_id else ""
    )
    data = gh.graphql(
        f"""
        mutation {{
          createIssue(input: {{
            repositoryId: "{config.REPO_ID}"
            title: {gh.gql_string(title)}
            body: {gh.gql_string(body)}
            {parent_clause}
          }}) {{
            issue {{ id number url title }}
          }}
        }}
        """
    )
    issue = data["createIssue"]["issue"]
    gh.add_labels(issue["number"], labels)
    return issue


def add_item_to_project(content_id):
    """Add an issue to the tracked Project and return its item id. If the
    Project's auto-add workflow already added it ("Content already exists"),
    return the existing item instead of failing: failing here left a created
    issue untracked, so a plan-exit retry created it again."""
    try:
        data = gh.graphql(
            f"""
            mutation {{
              addProjectV2ItemById(input: {{
                projectId: "{config.PROJECT_ID}"
                contentId: "{content_id}"
              }}) {{
                item {{ id }}
              }}
            }}
            """
        )
        return data["addProjectV2ItemById"]["item"]["id"]
    except gh.GhError as e:
        if "Content already exists" not in str(e):
            raise
    data = gh.graphql(
        f"""
        query {{
          node(id: "{content_id}") {{
            ... on Issue {{ projectItems(first: 20) {{ nodes {{ id project {{ id }} }} }} }}
          }}
        }}
        """
    )
    for node in data["node"]["projectItems"]["nodes"]:
        if node["project"]["id"] == config.PROJECT_ID:
            return node["id"]
    raise gh.GhError(f"{content_id} is reported as already on the Project but no item was found")


def set_status(item_id, status_key):
    option_id = config.STATUS_OPTION_IDS[status_key]
    gh.graphql(
        f"""
        mutation {{
          updateProjectV2ItemFieldValue(input: {{
            projectId: "{config.PROJECT_ID}"
            itemId: "{item_id}"
            fieldId: "{config.STATUS_FIELD_ID}"
            value: {{ singleSelectOptionId: "{option_id}" }}
          }}) {{
            projectV2Item {{ id }}
          }}
        }}
        """
    )


def set_sequence(item_id, value):
    field_id = ensure_sequence_field()
    gh.graphql(
        f"""
        mutation {{
          updateProjectV2ItemFieldValue(input: {{
            projectId: "{config.PROJECT_ID}"
            itemId: "{item_id}"
            fieldId: "{field_id}"
            value: {{ text: {gh.gql_string(value)} }}
          }}) {{
            projectV2Item {{ id }}
          }}
        }}
        """
    )


def find_item(issue_number):
    """Look up (issue_id, item_id) for an issue already on the tracked Project.
    Used when local state doesn't have it cached (e.g. a fresh session)."""
    data = gh.graphql(
        f"""
        query {{
          repository(owner: "{config.REPO_OWNER}", name: "{config.REPO_NAME}") {{
            issue(number: {int(issue_number)}) {{
              id
              title
              projectItems(first: 20) {{
                nodes {{ id project {{ id }} }}
              }}
            }}
          }}
        }}
        """
    )
    issue = data["repository"]["issue"]
    if not issue:
        raise gh.GhError(f"No issue #{issue_number} found in {config.REPO_OWNER}/{config.REPO_NAME}")
    for node in issue["projectItems"]["nodes"]:
        if node["project"]["id"] == config.PROJECT_ID:
            return issue["id"], node["id"], issue["title"]
    raise gh.GhError(
        f"Issue #{issue_number} exists but isn't on the tracked Project "
        f"(#{config.PROJECT_NUMBER}). Add it first."
    )


def add_blocked_by(issue_id, blocking_issue_id):
    """issue_id is blocked by blocking_issue_id (native issue Relationships)."""
    gh.graphql(
        f"""
        mutation {{
          addBlockedBy(input: {{
            issueId: "{issue_id}"
            blockingIssueId: "{blocking_issue_id}"
          }}) {{
            issue {{ id }}
          }}
        }}
        """
    )


_insights_cache = None


def _project_fields():
    data = gh.graphql(
        f"""
        query {{
          node(id: "{config.PROJECT_ID}") {{
            ... on ProjectV2 {{
              fields(first: 50) {{
                nodes {{
                  ... on ProjectV2FieldCommon {{ id name dataType }}
                  ... on ProjectV2SingleSelectField {{ options {{ id name }} }}
                  ... on ProjectV2IterationField {{
                    configuration {{
                      iterations {{ id title startDate duration }}
                      completedIterations {{ id title startDate duration }}
                    }}
                  }}
                }}
              }}
            }}
          }}
        }}
        """
    )
    return {f["name"]: f for f in data["node"]["fields"]["nodes"] if f.get("name")}


def ensure_insights_fields():
    """Create any missing Insights field (check-before-create) and return
    {field name: {"id", "options": {option name: option id}}} for every
    Insights field plus the Sprint iteration field ("options" = iterations
    keyed by title). Existing fields are never altered, so re-running is safe."""
    global _insights_cache
    if _insights_cache:
        return _insights_cache
    fields = _project_fields()
    created = False
    for name, options in config.INSIGHTS_SINGLE_SELECT.items():
        if name in fields:
            continue
        opts = ", ".join(
            f"{{name: {gh.gql_string(o)}, color: {c}, description: {gh.gql_string(d)}}}"
            for o, c, d in options
        )
        gh.graphql(
            f"""
            mutation {{
              createProjectV2Field(input: {{
                projectId: "{config.PROJECT_ID}"
                dataType: SINGLE_SELECT
                name: {gh.gql_string(name)}
                singleSelectOptions: [{opts}]
              }}) {{ projectV2Field {{ ... on ProjectV2FieldCommon {{ id }} }} }}
            }}
            """
        )
        created = True
    for name in config.INSIGHTS_NUMBER:
        if name in fields:
            continue
        gh.graphql(
            f"""
            mutation {{
              createProjectV2Field(input: {{
                projectId: "{config.PROJECT_ID}"
                dataType: NUMBER
                name: {gh.gql_string(name)}
              }}) {{ projectV2Field {{ ... on ProjectV2FieldCommon {{ id }} }} }}
            }}
            """
        )
        created = True
    if created:
        fields = _project_fields()
    out = {}
    for name in list(config.INSIGHTS_SINGLE_SELECT) + list(config.INSIGHTS_NUMBER):
        f = fields[name]
        out[name] = {"id": f["id"], "options": {o["name"]: o["id"] for o in f.get("options", [])}}
    sprint = fields[config.SPRINT_FIELD_NAME]
    conf = sprint["configuration"]
    out[config.SPRINT_FIELD_NAME] = {
        "id": sprint["id"],
        "options": {i["title"]: i["id"] for i in conf["iterations"] + conf["completedIterations"]},
        "iterations": conf["iterations"] + conf["completedIterations"],
    }
    _insights_cache = out
    return out


def sprint_plan():
    """The (title, startDate) list the Sprint field should hold."""
    import datetime as _dt

    start = _dt.date.fromisoformat(config.SPRINT_START)
    return [
        (f"Sprint 2026 {n + 1:02d}", (start + _dt.timedelta(days=n * config.SPRINT_DAYS)).isoformat())
        for n in range(config.SPRINT_COUNT)
    ]


def ensure_sprints():
    """Make the Sprint iteration field hold exactly sprint_plan(). A no-op when it
    already does. Replacing iterations clears item values on removed ones; the
    backfill reassigns every item, so that is safe here."""
    global _insights_cache
    current = ensure_insights_fields()[config.SPRINT_FIELD_NAME]["iterations"]
    have = sorted((i["title"], i["startDate"], i["duration"]) for i in current)
    want = sorted((t, s, config.SPRINT_DAYS) for t, s in sprint_plan())
    if have == want:
        return False
    its = ", ".join(
        f"{{title: {gh.gql_string(t)}, startDate: \"{s}\", duration: {config.SPRINT_DAYS}}}"
        for t, s in sprint_plan()
    )
    field_id = ensure_insights_fields()[config.SPRINT_FIELD_NAME]["id"]
    gh.graphql(
        f"""
        mutation {{
          updateProjectV2Field(input: {{
            fieldId: "{field_id}"
            iterationConfiguration: {{
              startDate: "{config.SPRINT_START}"
              duration: {config.SPRINT_DAYS}
              iterations: [{its}]
            }}
          }}) {{ projectV2Field {{ ... on ProjectV2FieldCommon {{ id }} }} }}
        }}
        """
    )
    _insights_cache = None
    return True
