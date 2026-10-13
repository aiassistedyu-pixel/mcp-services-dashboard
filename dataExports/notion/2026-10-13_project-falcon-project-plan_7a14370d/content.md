# Project Falcon — Project Plan

## Overview

Project Falcon is a unified search dashboard for personal cloud content. It downloads pages and files from connected services, indexes them locally, and offers fast full-text search with filters by source, date, and author.

## Goals

- Connect at least three services (Notion, Google Drive, GitHub)
- Search results in under one second for 1,000 documents
- Clean, accessible interface that works on mobile
- Demo-ready by December 10, 2026

## Team and responsibilities

- **Joe Smith** — project manager, documentation, final presentation
- **Maria Lopez** — UX research, visual design, usability testing
- **Alex Chen** — connectors, indexing pipeline, search API

## Milestones

1. **Week 1–2:** Repository setup, Notion connector prototype
2. **Week 3–4:** Local index using SQLite full-text search
3. **Week 5–6:** Google Drive and GitHub connectors
4. **Week 7–8:** Dashboard UI and filters
5. **Week 9:** Usability testing with five classmates
6. **Week 10:** Bug fixing, polish, and final presentation

## Risks

- API rate limits may slow the initial download. Mitigation: cache results and sync incrementally.
- Authentication tokens could leak if committed. Mitigation: keep secrets in a local env file that is git-ignored.
- Scope creep. Mitigation: freeze features after week 8.

## Open tasks

- [x] Choose a project codename (Project Falcon)
- [x] Create the GitHub repository
- [ ] Finalize the database schema for the search index
- [ ] Book a room for the final demo
- [ ] Draft the usability test script
