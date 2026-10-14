# Build GitHub connector (README files and issues only)

| Field | Value |
|---|---|
| Key | [FALCON-8](https://aiassistedyu.atlassian.net/browse/FALCON-8) |
| Type | Task |
| Status | In Progress |
| Priority | High |
| Labels | behind-schedule, connector, github-connector, scope-cut |
| Epic | FALCON-1 — Unified cross-service search dashboard (semester MVP) |
| Reporter | AI class |
| Assignee | Unassigned |
| Resolution | Unresolved |
| Created | 2026-10-14T01:25:49.644Z |
| Updated | 2026-10-14T01:26:22.231Z |

## Description

Owner: Alex Chen. Scope reduced at the October 12 follow-up meeting.

## Background

Joe Smith pointed out that the GitHub connector had not been started and the team was about one week behind the milestone schedule. Alex Chen suggested indexing only README files and issues instead of full repositories, which cuts the work roughly in half. Everyone agreed.

## Scope

* Repositories under the team organization only
* Download each repository's `README.md` (default branch)
* Download open and closed issues with title, body, labels, and comments
* Save in the shared local storage format (`content.md` + `metadata.json`)

## Out of scope

* Source code files, pull requests, wikis, and discussions

## Checklist

* \[ \] Personal access token read from the git-ignored local env file (never committed)
* \[ \] Respect API rate limits; cache and sync incrementally using `since`
* \[ \] Map issue state to the `status` field in metadata
* \[ \] Add "github" to the source filter and give it a purple source badge

## Comments (1)

### AI class — 2026-10-14T01:26:22.231Z

Alex Chen: started today. README download works for the team organization's repositories. Issues next — planning to use the `since` parameter so re-syncs only pull changed issues. Joe Smith, I'll update the milestone tracker once issues are downloading; still aiming to catch up the one-week slip before the week 8 freeze.
