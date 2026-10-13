# Project Falcon Follow-up Meeting with Joe Smith

**Date:** October 12, 2026 · **Location:** Library study room 3B
**Attendees:** Joe Smith, Maria Lopez, Alex Chen

## Purpose

Check progress against the project plan at the halfway point and decide what to cut or move before the week 8 feature freeze.

## Status updates

**Alex Chen:** The Notion connector is done and downloads pages as Markdown with metadata. The local SQLite full-text index works for about 400 test documents, and queries return in roughly 200 ms. The Google Drive connector is half finished. OAuth works, but Google Docs export still loses table formatting.

**Maria Lopez:** She finished three wireframes and ran a quick hallway test with four classmates. Everyone preferred the layout with source badges on the left of each result. She also found that people expect to filter by date before they filter by source.

**Joe Smith:** The project plan is shared and the professor approved the scope. He booked room 2.14 in the engineering building for the final demo on December 10.

## Discussion

Joe Smith pointed out that the GitHub connector has not been started and the team is about one week behind the milestone schedule. Alex Chen suggested indexing only README files and issues for GitHub, not full repositories, which would cut the work roughly in half. Everyone agreed.

The duplicate search results bug came up again. Alex Chen confirmed the cause is a missing upsert in the indexer and expects to fix it this week. Joe Smith asked for a regression test before the fix is merged.

Maria Lopez asked whether the dashboard needs a dark mode. Joe Smith said it is a nice-to-have and should wait until after usability testing.

## Decisions

- GitHub connector will index README files and issues only.
- Date filter moves above the source filter in the UI.
- Dark mode is deferred until after week 9.
- Feature freeze stays at the end of week 8.

## Action items

- [ ] Alex Chen: fix the duplicate results bug and add a regression test by Wednesday
- [ ] Alex Chen: start the GitHub connector (README and issues only)
- [ ] Maria Lopez: turn the chosen wireframe into a clickable prototype
- [ ] Maria Lopez: draft the usability test script and share it for review
- [ ] Joe Smith: update the milestone dates in the project plan
- [ ] Joe Smith: email the professor a short progress summary
- [x] Everyone: review the kickoff action items

## Next meeting

Monday, October 19 at 4 PM, regular standup.
