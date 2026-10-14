# Search returns duplicate results after syncing Notion more than once

| Field | Value |
|---|---|
| Key | [FALCON-2](https://aiassistedyu.atlassian.net/browse/FALCON-2) |
| Type | Bug |
| Status | In Progress |
| Priority | High |
| Labels | indexer, notion-connector, regression-test, search, sqlite-fts5 |
| Epic | FALCON-1 — Unified cross-service search dashboard (semester MVP) |
| Reporter | AI class |
| Assignee | Unassigned |
| Resolution | Unresolved |
| Created | 2026-10-14T01:25:42.875Z |
| Updated | 2026-10-14T01:26:21.213Z |

## Description

Reported by Maria Lopez on October 6, 2026. Originally tracked on the team's Notion page as **FALCON-42** ("Bug Report: Search Returns Duplicate Results"); this Jira issue now replaces it.

## Summary

When searching the dashboard for a term that appears in a Notion page, the same page shows up two or three times in the results list. Each extra sync adds another copy.

## Steps to reproduce

1. Connect a Notion workspace in the dashboard settings.
2. Click **Sync now** and wait for it to finish.
3. Click **Sync now** a second time.
4. Search for "enchiladas" (matches the "Recipe: Maria's Black Bean Enchiladas" page).

## Expected result

Exactly one result for the recipe page.

## Actual result

Two identical results, each linking to the same Notion URL. After a third sync, three results appear.

## Environment

* Windows 11, Chrome 141
* Dashboard build 0.3.1
* SQLite FTS5 index (\~400 test documents)

## Root cause (per Alex Chen)

The sync job inserts rows into the FTS5 table without checking whether the page ID already exists. FTS5 virtual tables don't enforce uniqueness, so every re-sync appends a new row.

## Proposed fix

* Change the insert to an upsert keyed on `(source, page_id)` — delete the existing FTS row then insert, inside one transaction
* Add a migration that removes existing duplicates, keeping the newest `last_edited_time`
* Regression test that syncs twice and asserts the result count is 1 (requested by Joe Smith before merge)
* Verify on Maria Lopez's machine

## Comments (1)

### AI class — 2026-10-14T01:26:21.213Z

Update from Alex Chen: reproduced locally — three syncs give three identical rows for the enchiladas recipe page. Switching the indexer to delete-then-insert on `(source, page_id)` inside a single transaction. Regression test `test_resync_does_not_duplicate` syncs the Notion fixture twice and asserts one hit for "enchiladas". Per Joe Smith, this won't merge until the test is green. Maria Lopez, can you verify on your machine once the migration is in?
