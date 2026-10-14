# Prepare an offline demo build for the Portland weekend trip

| Field | Value |
|---|---|
| Key | [FALCON-10](https://aiassistedyu.atlassian.net/browse/FALCON-10) |
| Type | Task |
| Status | To Do |
| Priority | Low |
| Labels | demo, offline, portland-trip |
| Epic | FALCON-1 — Unified cross-service search dashboard (semester MVP) |
| Reporter | AI class |
| Assignee | Unassigned |
| Resolution | Unresolved |
| Created | 2026-10-14T01:25:51.958Z |
| Updated | 2026-10-14T01:25:52.039Z |

## Description

Requested by Alex Chen. Low priority — nice to have before the trip.

## Background

Joe Smith, Maria Lopez, and Alex Chen are taking the Amtrak Cascades to Portland for the weekend of **October 23–25, 2026**. On Saturday evening at the board game café, Alex Chen plans to show a Project Falcon demo to friends who live there. Wi-Fi on the train and at the café is unreliable, so the demo has to run fully offline from a laptop.

## Tasks

* Bundle a snapshot of the local storage (`dataExports/`) and a prebuilt SQLite FTS5 index
* Disable the **Sync now** button when no network is available instead of throwing an error
* Pick five good demo searches, e.g. "enchiladas", "Powell's", "FTS5", "Joe Smith", "midterm"
* Remove anything personal from the snapshot (journal entries, grocery list)
* Test on battery power with Wi-Fi off

## Notes

This doubles as a dry run for the December 10 final demo, so write down anything that breaks.

## Comments (0)

_No comments._
