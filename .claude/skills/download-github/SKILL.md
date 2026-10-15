---
name: download-github
description: Download GitHub issues through the GitHub MCP server (read only) and save them under dataExports/github/ in the project's local format (content.md + metadata.json per issue, plus index.json). Use for requests like "download the issues in mcp-services-dashboard", "download GitHub issues that mention search", "download issues updated this week", "refresh my GitHub export", or "save issue #7 locally".
---

# Download GitHub issues

Save GitHub issues to `dataExports/github/` in the format defined in **`localStorageFormats.md`** (repo root, sections "Common pattern" and "GitHub"). Read that file first; it is the source of truth for folder names, files and every field. This skill covers *how* to produce that format.

## Hard rules

- **Read only.** Use only `get_me`, `search_repositories`, `search_issues`, `list_issues` and `issue_read` (methods `get` and `get_comments`). Never call a tool that creates, edits, comments on, closes, labels, merges or deletes anything (`issue_write`, `add_issue_comment`, `create_*`, `update_*`, `merge_pull_request`, `push_files`, `delete_*`, …).
- **Issues only.** Pull requests and repository files are not supported yet. The script skips any pull request it is given and says so.
- **No duplicates.** An issue is identified by `<owner>/<repo>#<number>`, never by folder name. `write-issues.ps1` finds existing folders by `id` and updates or renames them.
- **Never guess metadata.** Every value comes from the MCP response; missing values become `null`.
- **Don't hand-write issue files.** Save the raw MCP response to a file and convert it with `write-issues.ps1` (step 4). It handles UTC conversion, slugs, folder names and JSON escaping.

## 1. Find the repository

Call `get_me` to get the login. If the user doesn't name a repository, run `search_repositories` with `query: "user:<login>"` and `minimal_output: false`, then use the repository already in `dataExports/github/*/metadata.json` (`repo`), or ask. Private repositories are fine: the token in `.mcp.json` can read them.

## 2. Turn the request into a search

`search_issues` takes `owner` and `repo` separately and is already limited to issues. Put only search terms in `query`; sorting goes in `sort` / `order`.

| Request | `search_issues` arguments |
|---|---|
| "all issues in X" | `query: "is:issue"`, `sort: "created"`, `order: "asc"` |
| "issues that mention <term>" | `query: "<term>"`. Matching is loose (semantic). After downloading, Grep the new `content.md` files for the term (case-insensitive), report loose matches and ask whether to keep them. |
| "open" / "closed issues" | add `is:open` / `is:closed` to `query` |
| "issues updated this week" | `query: "is:issue updated:>=<YYYY-MM-DD>"` with the date of this week's Monday (say which day you used) |
| "issues by me" / "assigned to me" | `query: "author:<login>"` / `"assignee:<login>"` |
| a single issue, "#7" | `issue_read` with `method: "get"`, `issue_number: 7` |
| "refresh" / "update my export" | every `repo` + `number` in `dataExports/github/*/metadata.json`: one `query: "is:issue"` search per repository. Report issues that no longer exist; don't delete their folders unless asked. |

Always pass `perPage: 50` (max 100). If more than ~50 issues match, show `total_count` and confirm before downloading.

## 3. Download

Call `search_issues` with the arguments from step 2, plus `owner`, `repo` and `perPage`. **Don't pass `fields`**: the script needs `html_url`, `user`, `comments`, `labels`, `assignees`, `state_reason` and `closed_at`.

- Prefer `search_issues` over `list_issues`: `list_issues` leaves out the issue URL, the author's ID and the comment count, so those would be `null`.
- **Saving responses:** small responses come back inline. Save the exact JSON text to a file in the scratchpad (Write tool), unchanged. Large responses are saved to a file by the tool; use that path.
- **Pagination:** if `total_count` is larger than the number of `items`, call again with `page: 2`, and so on. Each page is its own response and request file in step 4.
- **Comments:** for every issue whose `comments` is above 0, call `issue_read` with `method: "get_comments"`, `perPage: 100`, and save each response to its own file.

## 4. Write the issue folders

For each response file, write a request file to the scratchpad describing the call that produced it:

```json
{
  "mcp_server": "github",
  "mcp_server_url": "https://api.githubcopilot.com/mcp/",
  "tool": "search_issues",
  "arguments": { "...": "exactly the arguments sent in step 3, including owner and repo" },
  "supporting_requests": [
    { "purpose": "resolve the authenticated user", "tool": "get_me", "arguments": {} },
    { "purpose": "find the user's repositories", "tool": "search_repositories", "arguments": { "query": "user:<login>", "minimal_output": false } }
  ]
}
```

`arguments.owner` and `arguments.repo` are required. Check that `mcp_server_url` still matches `.mcp.json`. Then run, from the repo root (comma-separate several files, with Windows paths):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .claude/skills/download-github/write-issues.ps1 `
  -ResponseFile <response1>,<response2> -RequestFile <request1>,<request2> `
  [-CommentsFile <comments7.json>,<comments9.json> -CommentsIssue owner/repo#7,owner/repo#9] `
  -ExportDir dataExports/github
```

The script adds each `get_comments` call to that issue's `supporting_requests` itself. It prints `created`, `updated` or `renamed from …` for each issue. It warns about pull requests it skipped, missing pages, and issues whose comments weren't passed; fix each warning and rerun.

## 5. Rebuild `index.json`

Never hand-edit `index.json`. Rebuild it from every `metadata.json` in the folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-index.ps1 -ExportDir dataExports/github
```

If it reports a duplicate `id`, merge the two folders (keep the newer `downloaded_at`) and run it again. Then refresh the dashboard with `scripts/build-dashboard-data.ps1`.

## 6. Check the result

- Every `*.json` in `dataExports/github/` parses (PowerShell: `Get-Content -Raw -Encoding UTF8 <f> | ConvertFrom-Json`).
- `count` in `index.json` equals the number of `pages` entries and the number of issue folders, and every `folder` in the index exists.
- No duplicate `id`s.
- Each folder name matches `^\d{4}-\d{2}-\d{2}_<slug(repo)>-<number>_[a-z0-9-]+_<number>$`, and its date is the UTC date of `created_time`.
- `git check-ignore -v dataExports/github/*/*` prints nothing. `.gitignore` ignores `*secret*`, so an issue whose title contains "secret" won't be committed. Tell the user if that happens.

## 7. Report back

Give a short summary: the repository and search used; issues created, updated, renamed or skipped (and why); any loose text matches; and the folder tree of what changed. Do not commit unless the user asks.
