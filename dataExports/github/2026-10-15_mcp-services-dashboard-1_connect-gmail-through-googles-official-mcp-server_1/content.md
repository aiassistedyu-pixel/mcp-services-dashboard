# Connect Gmail through Google's official MCP server

| Field | Value |
|---|---|
| Issue | [aiassistedyu-pixel/mcp-services-dashboard#1](https://github.com/aiassistedyu-pixel/mcp-services-dashboard/issues/1) |
| Kind | Issue |
| State | Open |
| Labels | None |
| Assignees | Unassigned |
| Author | aiassistedyu-pixel |
| Created | 2026-10-15T02:52:26.000Z |
| Updated | 2026-10-15T20:56:53.000Z |

## Description

We need Gmail hooked up so the dashboard can search email alongside everything else.

- Use Google's official Gmail MCP server, not a community one
- Sign in with the project's test Google account only
- Add the server to `.mcp.json` (no client secrets in the repo)

Once it connects, try pulling the last day of mail to make sure the tools actually return messages.

## Comments (0)

_No comments._
