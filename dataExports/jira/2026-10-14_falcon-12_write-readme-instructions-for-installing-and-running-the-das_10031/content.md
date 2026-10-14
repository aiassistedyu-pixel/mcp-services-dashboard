# Write README instructions for installing and running the dashboard locally

| Field | Value |
|---|---|
| Key | [FALCON-12](https://aiassistedyu.atlassian.net/browse/FALCON-12) |
| Type | Task |
| Status | To Do |
| Priority | Medium |
| Labels | deliverable, documentation, onboarding, readme |
| Epic | FALCON-1 — Unified cross-service search dashboard (semester MVP) |
| Reporter | AI class |
| Assignee | Unassigned |
| Resolution | Unresolved |
| Created | 2026-10-14T01:39:18.506Z |
| Updated | 2026-10-14T01:39:18.798Z |

## Description

Owner: Joe Smith (project manager). Technical review by Alex Chen. Requested by the professor as part of the final submission rubric.

## Background

Right now the only way to get the dashboard running is to ask Alex Chen. Joe Smith tried setting it up on a fresh laptop on October 12 and got stuck twice: once on missing MCP server credentials and once because the SQLite build on that machine didn't include FTS5. The grading rubric gives 10% of the project grade to "a classmate can run it from the README alone."

## Scope

Add a **Getting started** section to `README.md` covering:

* Prerequisites (Node.js version, Python version, SQLite with FTS5 enabled — include a one-line check: `sqlite3 :memory: "CREATE VIRTUAL TABLE t USING fts5(x);"`)
* Cloning the repo and installing dependencies
* Connecting each service (Notion, Jira, Google Drive, GitHub) through its MCP server, and where credentials go
* Running the first sync and building the search index
* Starting the dashboard and opening it in the browser
* Running the test suite
* Troubleshooting: FTS5 missing, expired MCP auth, duplicate results after re-sync (link FALCON-2)

## Acceptance criteria

- [ ] Joe Smith drafts the section
- [ ] Alex Chen reviews for technical accuracy
- [ ] Maria Lopez follows the README on her machine from a clean clone without asking anyone for help, and notes anything confusing
- [ ] Every command in the README is copy-pasteable and works on Windows 11 and macOS
- [ ] Merged before the week 10 code freeze

## Notes

Joe Smith will reuse the setup steps in the offline demo build checklist (FALCON-10).

## Comments (0)

_No comments._
