#!/usr/bin/env python3
"""FarmChore board tooling: manage the GitHub Projects board via GraphQL.

Why GraphQL: Projects v2 has no REST API; the gh CLI's piecemeal
REST+GraphQL calls are slow and error-prone. This script batches the whole
backlog into 3 GraphQL calls (create issues, add items, set fields) and
provides read-only views of the board.

Commands:
  bootstrap <backlog.tsv>  Create issues + board items from a TSV.
                           TSV columns: title \t body \t label \t sprint \t priority
                           (body may span lines; literal \\n in the last
                           tab-separated column group is not used)
  list                     Print board items: status, sprint, priority, title.
  ids                      Print project/field/option IDs (for debugging).

Config at the top of this file; all IDs are verified live before use.
"""

import json
import subprocess
import sys

REPO = "DrumFreeMoses/FarmChore"
REPO_ID = "R_kgDOTpfl-w"
PROJECT_ID = "PVT_kwHOCdxZSM4BfBdU"

FIELD_IDS = {
    "Status": "PVTSSF_lAHOCdxZSM4BfBdUzhZXaYc",
    "Sprint": "PVTSSF_lAHOCdxZSM4BfBdUzhZXanE",
    "Priority": "PVTSSF_lAHOCdxZSM4BfBdUzhZXaoA",
}

OPTION_IDS = {
    "Status": {"Todo": "f75ad846", "In Progress": "47fc9ee4", "Done": "98236657"},
    "Sprint": {"Sprint 1": "6530808a", "Sprint 2": "5c7609fb", "Sprint 3": "ae3755ad", "Sprint 4": "5549271c"},
    "Priority": {"P0": "e1ad8e71", "P1": "7c9c0c39", "P2": "6260e210", "P3": "33a8cfad"},
}

LABEL_IDS = {}


def gh(*args):
    r = subprocess.run(["gh", "api", "graphql", *args], capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"gh error: {r.stderr.strip()}")
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        sys.exit(f"bad JSON from gh: {r.stdout[:500]}")


def check(result):
    if result.get("errors"):
        sys.exit(f"GraphQL errors: {json.dumps(result['errors'], indent=2)}")


def graphql(query, **vars_):
    payload = json.dumps({"query": query, "variables": vars_ or None})
    r = subprocess.run(
        ["gh", "api", "graphql", "--input", "-"],
        input=payload,
        capture_output=True,
        text=True,
    )
    if r.returncode != 0:
        sys.exit(f"gh error: {r.stderr.strip()}")
    result = json.loads(r.stdout)
    check(result)
    return result["data"]


def fetch_label_ids():
    global LABEL_IDS
    data = graphql(
        "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { labels(first: 20) { nodes { name id } } } }",
        owner="DrumFreeMoses",
        name="FarmChore",
    )
    LABEL_IDS = {n["name"]: n["id"] for n in data["repository"]["labels"]["nodes"]}


def cmd_ids():
    data = graphql(
        """query($id: ID!) {
  node(id: $id) { ... on ProjectV2 {
    title
    fields(first: 20) { nodes {
      __typename
      ... on ProjectV2SingleSelectField { name id options { name id } }
    } }
  } }
}""",
        id=PROJECT_ID,
    )
    node = data["node"]
    print(node["title"])
    for f in node["fields"]["nodes"]:
        if f.get("name"):
            print(f"  {f['name']} = {f['id']}")
            for o in f["options"]:
                print(f"      {o['name']} = {o['id']}")


def cmd_list():
    data = graphql(
        """query($id: ID!) {
  node(id: $id) { ... on ProjectV2 {
    items(first: 100) { nodes {
      content { ... on Issue { number title } }
      fieldValues(first: 10) { nodes {
        __typename
        ... on ProjectV2ItemFieldSingleSelectValue { field { ... on ProjectV2SingleSelectField { name } } name }
      } }
    } } }
  }
}""",
        id=PROJECT_ID,
    )
    items = data["node"]["items"]["nodes"]
    rows = []
    for item in items:
        if not item["content"]:
            continue
        vals = {}
        for fv in item["fieldValues"]["nodes"]:
            if fv.get("field"):
                vals[fv["field"]["name"]] = fv["name"]
        rows.append((vals.get("Status", "-"), vals.get("Sprint", "-"), vals.get("Priority", "-"), item["content"]["title"]))
    width = max(len(r[3]) for r in rows) if rows else 0
    for status, sprint, pri, title in sorted(rows, key=lambda r: (r[1], r[2])):
        print(f"{status:<11} {sprint:<8} {pri:<2} {title}")


def cmd_bootstrap(tsv_path):
    fetch_label_ids()
    records = []
    current = None
    with open(tsv_path) as fh:
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if len(parts) == 2:
                current = [parts[0], parts[1]]
                records.append(current)
            elif len(parts) == 3:
                current += parts
            else:
                current[1] += "\n" + parts[0]
    bad = [r for r in records if len(r) != 5]
    if bad:
        sys.exit(f"malformed records: {bad}")

    fields = [f"a{i}: createIssue(input: {{repositoryId: \"{REPO_ID}\", title: \"$t{i}\", body: \"$b{i}\", labelIds: [$l{i}]}}) {{ issue {{ id }} }}" for i in range(len(records))]
    query = "mutation(" + ", ".join(f"$t{i}: String!, $b{i}: String!, $l{i}: ID!" for i in range(len(records))) + ") { " + " ".join(fields) + " }"
    vars_ = {}
    for i, (title, body, label, _, _) in enumerate(records):
        vars_[f"t{i}"] = title
        vars_[f"b{i}"] = body
        vars_[f"l{i}"] = LABEL_IDS[label]
    data = graphql(query, **vars_)

    issue_ids = [data[f"a{i}"]["issue"]["id"] for i in range(len(records))]
    fields = [f"a{i}: addProjectV2ItemById(input: {{projectId: \"{PROJECT_ID}\", contentId: \"{iid}\"}}) {{ item {{ id }} }}" for i, iid in enumerate(issue_ids)]
    query = "mutation(" + ", ".join(f"$i{i}: ID!" for i in range(len(records))) + ") { " + " ".join(fields) + " }"
    vars_ = {f"i{i}": iid for i, iid in enumerate(issue_ids)}
    data = graphql(query, **vars_)
    item_ids = [data[f"a{i}"]["item"]["id"] for i in range(len(records))]

    for i, (title, _, _, sprint, priority) in enumerate(records):
        sid = OPTION_IDS["Sprint"][sprint]
        pid = OPTION_IDS["Priority"][priority]
        todoid = OPTION_IDS["Status"]["Todo"]
        q = f"""mutation($p: ID!, $i: ID!, $s: String!, $sp: String!, $pr: String!) {{
          a: updateProjectV2ItemFieldValue(input: {{projectId: $p, itemId: $i, fieldId: "{FIELD_IDS['Status']}", value: {{singleSelectOptionId: $s}}}}) {{ projectV2Item {{ id }} }}
          b: updateProjectV2ItemFieldValue(input: {{projectId: $p, itemId: $i, fieldId: "{FIELD_IDS['Sprint']}", value: {{singleSelectOptionId: $sp}}}}) {{ projectV2Item {{ id }} }}
          c: updateProjectV2ItemFieldValue(input: {{projectId: $p, itemId: $i, fieldId: "{FIELD_IDS['Priority']}", value: {{singleSelectOptionId: $pr}}}}) {{ projectV2Item {{ id }} }}
        }}"""
        graphql(q, p=PROJECT_ID, i=item_ids[i], s=todoid, sp=sid, pr=pid)
        print(f"board: {title}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "list":
        cmd_list()
    elif cmd == "ids":
        cmd_ids()
    elif cmd == "bootstrap":
        if len(sys.argv) < 3:
            sys.exit("usage: board.py bootstrap <backlog.tsv>")
        cmd_bootstrap(sys.argv[2])
    else:
        sys.exit(f"unknown command: {cmd}")
