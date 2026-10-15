# Add a download skill so exports are repeatable

| Field | Value |
|---|---|
| Issue | [aiassistedyu-pixel/mcp-services-dashboard#4](https://github.com/aiassistedyu-pixel/mcp-services-dashboard/issues/4) |
| Kind | Issue |
| State | Open |
| Labels | None |
| Assignees | Unassigned |
| Author | aiassistedyu-pixel |
| Created | 2026-10-15T02:52:28.000Z |
| Updated | 2026-10-15T20:56:56.000Z |

## Description

Right now each download is a one-off conversation with Claude, and the files come out slightly different every time.

We should add a project skill under `.claude/skills/` for each service that:
- says exactly which MCP tools to call (read only)
- writes files in the format from `localStorageFormats.md`
- updates `index.json` at the end

Then "download new issues" in a fresh conversation should produce the same layout as the first run.

## Comments (0)

_No comments._
