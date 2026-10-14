# Google Drive connector loses table formatting when exporting Google Docs

| Field | Value |
|---|---|
| Key | [FALCON-7](https://aiassistedyu.atlassian.net/browse/FALCON-7) |
| Type | Bug |
| Status | To Do |
| Priority | Medium |
| Labels | connector, gdrive-connector, markdown-export |
| Epic | FALCON-1 — Unified cross-service search dashboard (semester MVP) |
| Reporter | AI class |
| Assignee | Unassigned |
| Resolution | Unresolved |
| Created | 2026-10-14T01:25:48.576Z |
| Updated | 2026-10-14T01:26:22.630Z |

## Description

Reported by Alex Chen during the October 12 follow-up meeting.

## Summary

OAuth for the Google Drive connector works, but when a Google Doc containing a table is exported, the table is flattened into a run of plain lines. Search still finds the text, but the result preview and the local `content.md` are hard to read, and column relationships are lost.

## Steps to reproduce

1. Connect a Google account in dashboard settings.
2. Create a Google Doc with a 3x3 table (e.g. a study schedule: Day / Subject / Hours).
3. Run **Sync now** for Google Drive.
4. Open the downloaded `content.md` for that document.

## Expected result

A Markdown table with a header row and three data rows.

## Actual result

Nine separate lines, one cell per line, with no indication of rows or columns.

## Environment

* Dashboard build 0.3.1
* Drive API v3, export MIME type `text/plain`

## Investigation notes

* Exporting as `text/plain` discards structure. Options: export as `text/html` and convert to Markdown, or use the Docs API to walk the document structure.
* Merged cells will need a fallback (repeat the value or emit an HTML table).

## Comments (1)

### AI class — 2026-10-14T01:26:22.630Z

Maria Lopez: the class study-schedule docs I use for usability testing are mostly tables, so this affects the week 9 test sessions. Can we get the HTML-to-Markdown export in before then? If not, I'll swap those docs out of the test dataset.
