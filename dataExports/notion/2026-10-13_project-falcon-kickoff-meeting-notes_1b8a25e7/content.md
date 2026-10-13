# Project Falcon Kickoff Meeting Notes

**Date:** September 8, 2026 · **Location:** Library study room 3B
**Attendees:** Joe Smith, Maria Lopez, Alex Chen

## Agenda

1. Introductions and roles
2. Scope of Project Falcon
3. Tools and services to integrate
4. Timeline and next steps

## Discussion

Joe Smith opened by explaining the goal of Project Falcon: a single dashboard that pulls documents from several cloud services (Notion, Google Drive, GitHub) and lets a user search across all of them from one search bar. The professor wants a working demo by the end of the semester.

Maria Lopez raised a concern about the user experience. Most students have files scattered across five or six apps, and search results need to show clearly which service each result came from. She proposed color-coded source badges.

Alex Chen walked through the technical approach. Each service will be wrapped as an MCP server, and the dashboard will call them through a shared client. He estimated the Notion connector is the easiest starting point because its API returns clean Markdown.

## Decisions

- Notion will be the first integration.
- Weekly standups every Monday at 4 PM.
- The repository will live on GitHub under the team organization.

## Action items

- [ ] Joe Smith: write the project plan and share it by Friday
- [ ] Maria Lopez: sketch three dashboard wireframes
- [ ] Alex Chen: set up the repository and a hello-world Notion connector
- [x] Everyone: join the team chat channel
