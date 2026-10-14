---
name: download-jira
description: Download Jira issues through the Atlassian MCP server (read only) and save them under dataExports/jira/ in the project's local format (content.md + metadata.json per issue, plus index.json). Use for requests like "download all FALCON issues", "download Jira issues that mention Joe Smith", "download issues updated this week", "refresh my Jira export", or "save FALCON-2 locally".
---

# Download Jira issues

Save Jira issues to `dataExports/jira/` in the format defined in **`localStorageFormats.md`** (repo root, sections "Common pattern" and "Jira"). Read that file first; it is the source of truth for folder names, files and every field. This skill covers *how* to produce that format.

## Hard rules

- **Read only.** Use only `getAccessibleAtlassianResources`, `getVisibleJiraProjects`, `searchJiraIssuesUsingJql`, `getJiraIssue` and `lookupJiraAccountId`. Never call a tool that creates, edits, transitions, comments on, links or logs work on anything (`createJiraIssue`, `editJiraIssue`, `transitionJiraIssue`, `addCommentToJiraIssue`, `createIssueLink`, `addWorklogToJiraIssue`, …).
- **No duplicates.** An issue is identified by its issue `id`, never by key or folder name. `write-issues.ps1` finds existing folders by `id` and updates or renames them.
- **Never guess metadata.** Every value comes from the MCP response; missing values become `null`.
- **Don't hand-write issue files.** Save the raw MCP response to a file and convert it with `write-issues.ps1` (step 4). It handles UTC conversion, slugs, folder names, and JSON escaping.
- **One site.** `dataExports/jira/` holds one Atlassian site. If the request is for a different site, stop and ask (see the "One site per export" note in `localStorageFormats.md`).

## 1. Find the site

Call `getAccessibleAtlassianResources`. Use the `id` of the Jira site as `cloudId`. If there are several sites, use the one already in `dataExports/jira/*/metadata.json` (`site`), or ask.

## 2. Turn the request into JQL

| Request | JQL |
|---|---|
| "all issues in FALCON" | `project = FALCON ORDER BY key ASC` |
| "issues that mention Joe Smith" | `text ~ "\"Joe Smith\"" ORDER BY key ASC`. `text` searches summary, description, comments and environment. Add `project = X AND` if the user names a project. |
| …and Joe Smith is a Jira user | Also run `lookupJiraAccountId` with `searchString: "Joe Smith"`. If it finds exactly one account, add `OR assignee = "<accountId>" OR reporter = "<accountId>" OR creator = "<accountId>"` (in parentheses with the text clause). If it finds none, use the text search alone (the name may appear only in text, as in the FALCON test data). If it finds several, ask which one. |
| "issues updated this week" | `updated >= startOfWeek() ORDER BY updated DESC`. Jira weeks start on Sunday by default. Say so in the report, and use `startOfWeek("+1d")` if the user wants Monday. "today" → `startOfDay()`, "last 7 days" → `-7d`. |
| "issues created by me" / "assigned to me" | `creator = currentUser()` / `assignee = currentUser()` |
| a key such as "FALCON-2" | `key = FALCON-2`, or `getJiraIssue` with `issueIdOrKey` (same fields, see step 3). |
| "refresh" / "update my export" | `key in (<every key in dataExports/jira/*/metadata.json>)`. Then also search `id in (…)` for any IDs that came back missing; their keys may have changed. Report issues that no longer exist; don't delete their folders unless asked. |

Text search matches word stems and is loose. After downloading, check that each result really contains the term in its summary, description or comments (case-insensitive, Grep over the new `content.md` files). Report any loose matches and ask whether to keep them.

If the user's wording is ambiguous ("mention" = text only, or also assignee?) and the two readings give different results, show both counts and ask.

## 3. Download

Call `searchJiraIssuesUsingJql` with exactly these arguments (fill in `cloudId` and `jql`):

```json
{
  "cloudId": "<cloudId>",
  "jql": "<jql>",
  "maxResults": 100,
  "fields": ["summary", "description", "issuetype", "status", "priority", "labels", "components", "parent", "project", "reporter", "assignee", "creator", "created", "updated", "resolution", "resolutiondate", "comment"],
  "responseContentFormat": "markdown"
}
```

- **Count first if the scope is unclear:** for open-ended requests, run the same JQL with `searchResultMode: "count"`. If more than ~50 issues match, show the count and confirm before downloading.
- **Large responses:** the tool saves big results to a file and returns its path. Use that path directly in step 4.
- **Small responses** come back inline. Save the exact JSON text to a file in the scratchpad (Write tool), unchanged, and use that path.
- **Pagination:** if `issues.pageInfo.hasNextPage` is true, call again with `nextPageToken: <endCursor>`. Each page is its own response file and request file in step 4.
- **Comments:** the converter warns if an issue's `comment.total` is larger than the number of comments returned. For each such issue, call `getJiraIssue` with `issueIdOrKey`, the same `fields` and `responseContentFormat`, and pass that response *after* the search response (the last response wins).

## 4. Write the issue folders

For each response file, write a request file to the scratchpad describing the call that produced it:

```json
{
  "mcp_server": "atlassian",
  "mcp_server_url": "https://mcp.atlassian.com/v1/mcp/authv2",
  "tool": "searchJiraIssuesUsingJql",
  "arguments": { "...": "exactly the arguments sent in step 3" },
  "supporting_requests": [
    { "purpose": "resolve the cloudId of the Jira site", "tool": "getAccessibleAtlassianResources", "arguments": {} }
  ]
}
```

Add each `lookupJiraAccountId` call used to build the JQL to `supporting_requests`. Check that `mcp_server_url` still matches `.mcp.json`. Then run, from the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .claude/skills/download-jira/write-issues.ps1 `
  -ResponseFile <response1>,<response2> -RequestFile <request1>,<request2> -ExportDir dataExports/jira
```

It prints `created`, `updated` or `renamed from …` for each issue. Renames are plain moves; git detects them when the files are staged.

## 5. Rebuild `index.json`

Never hand-edit `index.json`. Rebuild it from every `metadata.json` in the folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-index.ps1 -ExportDir dataExports/jira
```

If it reports a duplicate `id`, merge the two folders (keep the newer `downloaded_at`) and run it again.

## 6. Check the result

- Every `*.json` in `dataExports/jira/` parses (PowerShell: `Get-Content -Raw -Encoding UTF8 <f> | ConvertFrom-Json`).
- `count` in `index.json` equals the number of `pages` entries and the number of issue folders, and every `folder` in the index exists.
- No duplicate `id`s.
- Each folder name matches `^\d{4}-\d{2}-\d{2}_<slug(key)>_[a-z0-9-]+_<last 8 chars of id>$`, and its date is the UTC date of `created_time`.

## 7. Report back

Give a short summary: the JQL used; issues created, updated, renamed or skipped (and why); any loose text matches or incomplete comments; and the folder tree of what changed. Do not commit unless the user asks.
