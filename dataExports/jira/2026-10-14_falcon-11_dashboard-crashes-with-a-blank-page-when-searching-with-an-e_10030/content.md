# Dashboard crashes with a blank page when searching with an empty query

| Field | Value |
|---|---|
| Key | [FALCON-11](https://aiassistedyu.atlassian.net/browse/FALCON-11) |
| Type | Bug |
| Status | To Do |
| Priority | High |
| Labels | crash, input-validation, search, sqlite-fts5 |
| Epic | FALCON-1 — Unified cross-service search dashboard (semester MVP) |
| Reporter | AI class |
| Assignee | Unassigned |
| Resolution | Unresolved |
| Created | 2026-10-14T01:39:17.288Z |
| Updated | 2026-10-14T01:39:17.393Z |

## Description

Reported by Maria Lopez during a hallway usability session on October 13, 2026.

## Summary

Pressing **Enter** in the search box with nothing typed (or only spaces) makes the whole dashboard go blank. The browser console shows an unhandled error from the search API, and the page has to be reloaded to recover.

## Steps to reproduce

1. Open the dashboard and make sure at least one service is synced.
2. Click into the search box without typing anything.
3. Press **Enter** (also reproduces with a query of only spaces, e.g. "   ").

## Expected result

Nothing happens, or a friendly hint appears: "Type something to search across Notion, Jira, Google Drive, and GitHub."

## Actual result

The results panel and sidebar disappear and the page goes white. Console output:

```
Uncaught (in promise) TypeError: Cannot read properties of undefined (reading 'map')
    at SearchResults (SearchResults.jsx:42)
```

Server log:

```
sqlite3.OperationalError: fts5: syntax error near ""
```

## Environment

* Windows 11, Chrome 141 and Firefox 131
* Dashboard build 0.3.2
* SQLite FTS5 index (\~400 test documents)

## Root cause (initial look by Alex Chen)

The `/api/search` endpoint passes the raw query straight into `MATCH ?`. FTS5 rejects an empty string as a syntax error, the endpoint returns a 500 with an HTML error page instead of JSON, and `SearchResults` calls `.map` on `undefined` because there is no error boundary.

## Proposed fix

* Trim the query on the client and skip the request if it is empty
* On the server, return `200 { "results": [] }` for empty/whitespace queries instead of hitting FTS5
* Also escape FTS5 special characters (`"`, `*`, `(`, `)`) so queries like `"` don't crash either
* Add a React error boundary around the results panel so one bad response can't blank the page
* Regression tests for `""`, `"   "`, and `"\""`

## Notes

Must be fixed before the Portland offline demo (FALCON-10) and the recorded demo video (FALCON-9) — it's an easy thing to trigger by accident live.

## Comments (0)

_No comments._
