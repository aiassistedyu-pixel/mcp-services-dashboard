# As a student, I want color-coded source badges on search results so I know where each result came from

| Field | Value |
|---|---|
| Key | [FALCON-4](https://aiassistedyu.atlassian.net/browse/FALCON-4) |
| Type | Story |
| Status | Done |
| Priority | Medium |
| Labels | accessibility, search-results, ui, ux |
| Epic | FALCON-1 — Unified cross-service search dashboard (semester MVP) |
| Reporter | AI class |
| Assignee | Unassigned |
| Resolution | Done |
| Created | 2026-10-14T01:25:45.248Z |
| Updated | 2026-10-14T01:26:20.377Z |

## Description

Requested by Maria Lopez (kickoff meeting, September 8, 2026).

## Background

Most students have files scattered across five or six apps. When a search returns results from Notion, Jira, Google Drive, and GitHub mixed together, people need to see at a glance which service each result came from. In Maria Lopez's hallway test with four classmates, everyone preferred the wireframe with source badges on the **left** of each result.

## User story

As a student searching my own content, I want each search result to show a colored badge for its source, so that I can tell a Notion page from a Jira issue or a Drive file without opening it.

## Acceptance criteria

* Each result row shows a badge on the left with the service name and icon
* Colors: Notion = black/gray, Jira = blue, Google Drive = green, GitHub = purple
* Badges meet WCAG AA contrast (4.5:1) in light mode
* Badge text is readable by screen readers (e.g. "Source: Jira")
* Badges stay visible on mobile widths down to 360 px
* Clicking a badge filters the results to that source

## Design reference

Wireframe B from Maria Lopez's three wireframes; clickable prototype in progress.

## Comments (0)

_No comments._
