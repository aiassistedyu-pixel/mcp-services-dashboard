# Design SQLite FTS5 schema for the local search index

| Field | Value |
|---|---|
| Key | [FALCON-3](https://aiassistedyu.atlassian.net/browse/FALCON-3) |
| Type | Task |
| Status | Done |
| Priority | High |
| Labels | backend, database, indexer, sqlite-fts5 |
| Epic | FALCON-1 — Unified cross-service search dashboard (semester MVP) |
| Reporter | AI class |
| Assignee | Unassigned |
| Resolution | Done |
| Created | 2026-10-14T01:25:44.117Z |
| Updated | 2026-10-14T01:26:21.751Z |

## Description

Owner: Alex Chen. Reviewed by Joe Smith.

Finalize the database schema for the local search index (open task from the project plan, milestone week 3–4). The index must support full-text search over every downloaded item regardless of source, plus filtering by source, date, and author.

## Proposed schema

* `documents` table: `id`, `source` (notion / jira / gdrive / github), `source_id`, `title`, `url`, `author`, `created_at`, `updated_at`, `local_path`
* Unique constraint on `(source, source_id)`
* `documents_fts` FTS5 virtual table over `title` and `body`, using `content='documents'` external-content mode and the `porter unicode61` tokenizer
* Triggers to keep `documents_fts` in sync on insert / update / delete

## Notes

* Use `bm25()` for ranking, weighting title matches 5x over body
* `snippet()` for result previews with highlighted terms
* Load from the local storage format (`content.md` + `metadata.json` per item, `index.json` at the root) so the indexer never calls the cloud APIs directly

## Done when

- [x] Schema committed with a migration script
- [x] Index builds for the \~400-document test set
- [x] Sample queries return in about 200 ms

## Comments (1)

### AI class — 2026-10-14T01:26:21.751Z

Joe Smith: reviewed the schema and migration — looks good. Benchmarked on the 400-document test set: average query time \~200 ms with bm25 ranking and snippets. Note the FTS5 table itself doesn't enforce uniqueness, which is the root cause of the duplicate-results bug (FALCON-2, formerly Notion FALCON-42). Closing this one.
