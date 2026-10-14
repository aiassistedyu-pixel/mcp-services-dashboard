# Unified cross-service search dashboard (semester MVP)

| Field | Value |
|---|---|
| Key | [FALCON-1](https://aiassistedyu.atlassian.net/browse/FALCON-1) |
| Type | Epic |
| Status | To Do |
| Priority | High |
| Labels | dashboard, mvp, search, semester-project |
| Epic | None |
| Reporter | AI class |
| Assignee | Unassigned |
| Resolution | Unresolved |
| Created | 2026-10-14T01:24:47.535Z |
| Updated | 2026-10-14T01:24:47.656Z |

## Description

## Overview

Project Falcon is a single dashboard that pulls documents from several cloud services and lets a user search across all of them from one search bar. Content is downloaded through MCP-based connectors, stored locally, and indexed with SQLite FTS5 for fast full-text search with filters by source, date, and author.

Owner: Joe Smith (project manager). Technical lead: Alex Chen. UX lead: Maria Lopez.

## Goals

* Connect at least three services (Notion, Jira, Google Drive, GitHub — README and issues only)
* Return search results in under one second for 1,000 documents
* Clean, accessible interface that also works on mobile
* Demo-ready by **December 10, 2026** (engineering building, room 2.14)

## Scope

* Connectors: Notion (done), Jira, Google Drive, GitHub
* Local storage format: one folder per item with `content.md` + `metadata.json`, plus an `index.json`
* Local SQLite FTS5 index with upsert-on-sync semantics
* Search UI with color-coded source badges, date filter, and source filter
* Demo video and final presentation

## Out of scope (for now)

* Dark mode (deferred until after usability testing in week 9)
* Full-repository indexing for GitHub

## Milestones

1. Week 1–2: Repository setup, Notion connector prototype
2. Week 3–4: Local index using SQLite full-text search
3. Week 5–6: Google Drive, Jira, and GitHub connectors
4. Week 7–8: Dashboard UI and filters — **feature freeze at end of week 8**
5. Week 9: Usability testing with five classmates
6. Week 10: Bug fixing, polish, final presentation

## Comments (0)

_No comments._
