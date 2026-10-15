# Decide how GitHub issues are saved under dataExports/github

| Field | Value |
|---|---|
| Issue | [aiassistedyu-pixel/mcp-services-dashboard#3](https://github.com/aiassistedyu-pixel/mcp-services-dashboard/issues/3) |
| Kind | Issue |
| State | Open |
| Labels | None |
| Assignees | Unassigned |
| Author | aiassistedyu-pixel |
| Created | 2026-10-15T02:52:27.000Z |
| Updated | 2026-10-15T20:56:55.000Z |

## Description

Before we download anything from GitHub we should agree on the folder layout so it matches Notion and Jira.

My suggestion: one folder per issue with `content.md` (title, description, comments) and `metadata.json` (number, state, labels, assignees, author, dates), plus an `index.json` for the whole service.

Whatever we pick, it needs to go in `localStorageFormats.md` so the dashboard and the download skill both follow it.

## Comments (0)

_No comments._
