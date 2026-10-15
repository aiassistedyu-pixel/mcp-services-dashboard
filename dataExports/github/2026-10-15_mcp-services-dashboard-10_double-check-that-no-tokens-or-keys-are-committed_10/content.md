# Double-check that no tokens or keys are committed

| Field | Value |
|---|---|
| Issue | [aiassistedyu-pixel/mcp-services-dashboard#10](https://github.com/aiassistedyu-pixel/mcp-services-dashboard/issues/10) |
| Kind | Issue |
| State | Open |
| Labels | None |
| Assignees | Unassigned |
| Author | aiassistedyu-pixel |
| Created | 2026-10-15T02:52:31.000Z |
| Updated | 2026-10-15T20:57:01.000Z |

## Description

The repo is public, so before we submit let's go through it once more:

- `.mcp.json` should only reference `${GITHUB_PAT}`, never the actual token
- nothing in `dataExports/` should contain API keys or OAuth secrets
- `.claude/settings.local.json` stays out of git

Worth running GitHub's secret scanning on the repo too.

## Comments (0)

_No comments._
