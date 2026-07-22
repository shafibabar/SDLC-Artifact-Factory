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


def create_issue(title, body, parent_issue_id=None):
    """Create an issue in the tracked repo. If parent_issue_id is given,
    creates it as a native GitHub sub-issue of that parent in the same call."""
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
    return data["createIssue"]["issue"]


def add_item_to_project(content_id):
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
