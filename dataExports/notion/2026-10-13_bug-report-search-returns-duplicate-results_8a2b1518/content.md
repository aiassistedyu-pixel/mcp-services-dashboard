# Bug Report: Search Returns Duplicate Results

**ID:** FALCON-42 · **Project:** Project Falcon · **Severity:** Medium · **Status:** Open
**Reported by:** Maria Lopez · **Assigned to:** Alex Chen · **Reported on:** October 6, 2026

## Summary

When searching the dashboard for a term that appears in a Notion page, the same page shows up two or three times in the results list.

## Steps to reproduce

1. Connect a Notion workspace in the dashboard settings.
2. Click **Sync now** and wait for it to finish.
3. Click **Sync now** a second time.
4. Search for "enchiladas".

## Expected result

One result for the recipe page.

## Actual result

Two identical results, each linking to the same Notion URL. After a third sync, three results appear.

## Environment

- Windows 11, Chrome 141
- Dashboard build 0.3.1
- SQLite FTS5 index

## Investigation notes

Alex Chen suspects the sync job inserts rows into the index without checking whether the page ID already exists. The fix is probably an upsert keyed on the source and page ID. Joe Smith asked for a regression test so the bug does not come back.

## Tasks

- [x] Reproduce the bug locally
- [ ] Change the insert to an upsert on (source, page_id)
- [ ] Add a migration that removes existing duplicates
- [ ] Write a regression test that syncs twice and counts results
- [ ] Verify on Maria's machine
