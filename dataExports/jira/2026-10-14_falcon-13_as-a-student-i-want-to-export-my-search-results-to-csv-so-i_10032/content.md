# As a student, I want to export my search results to CSV so I can use them in a spreadsheet

| Field | Value |
|---|---|
| Key | [FALCON-13](https://aiassistedyu.atlassian.net/browse/FALCON-13) |
| Type | Story |
| Status | To Do |
| Priority | Low |
| Labels | csv, export, search-results, ui |
| Epic | FALCON-1 — Unified cross-service search dashboard (semester MVP) |
| Reporter | AI class |
| Assignee | Unassigned |
| Resolution | Unresolved |
| Created | 2026-10-14T01:39:19.837Z |
| Updated | 2026-10-14T01:39:19.922Z |

## Description

Requested by Maria Lopez based on feedback from usability session 3 (October 9, 2026).

## Background

Two of four participants wanted to take a set of search results somewhere else, e.g. pulling every Jira issue and Notion page that mentions "midterm" into a spreadsheet to build a study checklist. Today they have to copy results one at a time.

## User story

As a student searching my own content, I want to export the current search results to a CSV file, so that I can sort, filter, and annotate them in Excel or Google Sheets.

## Acceptance criteria

* An **Export CSV** button appears above the results list whenever there is at least one result
* The export includes **all** matching results, not only the visible page, and respects active date and source filters
* Columns: `source`, `title`, `url`, `snippet`, `last_edited_time`, `score`
* File is UTF-8 with BOM so Excel opens accented characters correctly (e.g. "Powell's", "Lopez")
* Fields containing commas, quotes, or newlines are escaped per RFC 4180
* Snippet highlight markup (`<b>…</b>`) is stripped
* Filename format: `falcon-search_<query>_<YYYY-MM-DD>.csv`, with the query slugified
* Button is disabled (not hidden) with a tooltip while a search is loading

## Out of scope

* Excel (.xlsx) export
* Exporting full document contents

## Notes

Alex Chen: can be done entirely on the server with the existing FTS5 query plus a streaming CSV writer; estimated at one day.

## Comments (0)

_No comments._
