# Slack results show a different date in the title than in the result list

| Field | Value |
|---|---|
| Issue | [aiassistedyu-pixel/mcp-services-dashboard#11](https://github.com/aiassistedyu-pixel/mcp-services-dashboard/issues/11) |
| Kind | Issue |
| State | Open |
| Labels | None |
| Assignees | Unassigned |
| Author | aiassistedyu-pixel |
| Created | 2026-10-15T20:50:49.000Z |
| Updated | 2026-10-15T20:50:49.000Z |

## Description

Slack items are titled with the UTC day they were saved under (e.g. `#social · Oct 15, 2026`), but the date on the right of the result card uses the browser's local time. For anyone west of UTC, messages sent in the evening show **Oct 14** next to a title that says **Oct 15**.

**Steps to reproduce**
1. Set your computer to US Eastern time.
2. Open the dashboard and pick the Slack filter.
3. Compare the date in a result's title with the date on the right of the card.

**Expected:** both dates match.

Probably simplest to show the UTC day in both places for Slack, since the export is grouped by UTC day anyway.

## Comments (0)

_No comments._
