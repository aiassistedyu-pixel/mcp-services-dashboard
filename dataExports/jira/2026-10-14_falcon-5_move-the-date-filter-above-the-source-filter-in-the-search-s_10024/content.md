# Move the date filter above the source filter in the search sidebar

| Field | Value |
|---|---|
| Key | [FALCON-5](https://aiassistedyu.atlassian.net/browse/FALCON-5) |
| Type | Story |
| Status | To Do |
| Priority | Medium |
| Labels | filters, search, ui, usability-feedback |
| Epic | FALCON-1 — Unified cross-service search dashboard (semester MVP) |
| Reporter | AI class |
| Assignee | Unassigned |
| Resolution | Unresolved |
| Created | 2026-10-14T01:25:46.370Z |
| Updated | 2026-10-14T01:25:46.446Z |

## Description

Decided at the follow-up meeting with Joe Smith on October 12, 2026. Requested by Maria Lopez based on usability findings.

## Background

During hallway testing, Maria Lopez found that people expect to narrow results by **date** before they narrow by **source**. The current sidebar shows the source filter first, which caused hesitation in three of four sessions.

## User story

As a student looking for something I wrote recently, I want to filter by date first, so that I can quickly find "that thing from last week" without caring which app it's in.

## Acceptance criteria

* Date filter appears above the source filter in the sidebar
* Date presets: Today, Last 7 days, Last 30 days, This semester, Custom range
* Custom range uses a date picker that works with keyboard only
* Filter is applied against the `updated_at` column in the FTS5 index
* Selected filters persist in the URL query string so a search can be shared or bookmarked
* Combining date + source filters returns results in under one second for 1,000 documents

## Notes

Must land before the week 8 feature freeze.

## Comments (0)

_No comments._
