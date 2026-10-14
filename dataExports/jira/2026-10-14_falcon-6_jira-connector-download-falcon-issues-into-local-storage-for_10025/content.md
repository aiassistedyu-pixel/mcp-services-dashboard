# Jira connector: download FALCON issues into local storage for indexing

| Field | Value |
|---|---|
| Key | [FALCON-6](https://aiassistedyu.atlassian.net/browse/FALCON-6) |
| Type | Story |
| Status | In Progress |
| Priority | High |
| Labels | connector, jira-connector, local-storage, mcp |
| Epic | FALCON-1 — Unified cross-service search dashboard (semester MVP) |
| Reporter | AI class |
| Assignee | Unassigned |
| Resolution | Unresolved |
| Created | 2026-10-14T01:25:47.499Z |
| Updated | 2026-10-14T01:26:17.931Z |

## Description

Owner: Alex Chen. Requested by Joe Smith so the team's own project tracking is searchable from the dashboard.

## Background

The Notion connector already downloads pages as Markdown with metadata (`content.md` + `metadata.json` per page, plus an `index.json`). The Jira connector should follow the same local storage format so the indexer can treat both sources identically.

## User story

As a team member, I want our Jira issues downloaded and indexed alongside our Notion notes, so that searching for "duplicate results" finds both the original Notion bug report and the Jira issue that replaced it.

## Acceptance criteria

* Connector uses the Atlassian MCP server (read-only) and JQL to fetch issues by project
* Each issue is saved as `dataExports/jira/<date>_<key>_<slug>/content.md` with summary, description, and comments rendered as Markdown
* `metadata.json` includes key, issue type, status, priority, labels, reporter, created, and updated
* Re-running the download updates existing folders instead of creating duplicates (learned from the Notion duplicate bug)
* Never touches projects other than the ones explicitly configured (KAN and SAM1 must be excluded)
* Handles pagination for projects with more than 100 issues

## Comments (0)

_No comments._
