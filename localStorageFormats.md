# Local Storage Formats

How data downloaded from each service is stored under `dataExports/`. The dashboard (`webapp/`) and any download skill must read and write exactly this layout.

- [Common pattern](#common-pattern) — rules every service follows
- [Notion](#notion) — implemented
- [Jira](#jira) — implemented
- [Gmail](#gmail) — not implemented (waived by instructor)
- [GitHub](#github) — implemented (issues)
- [Slack](#slack) — implemented
- [Google Drive](#google-drive) — not used

---

## Common pattern

Every service uses the same three-part layout: **one folder per item**, holding a **content file** and a **`metadata.json`**, plus one **`index.json`** per service.

```
dataExports/
  <service>/
    index.json                                  ← list of every item downloaded from this service
    <date>_<title-slug>_<id8>/                  ← one folder per item
      content.<ext>                             ← the item's body (Markdown when possible)
      metadata.json                             ← facts about the item and how it was downloaded
```

### Shared rules

| Rule | Detail |
|---|---|
| **Folder name** | `<YYYY-MM-DD>_<title-slug>_<id8>`. The date is the item's creation date (UTC). `id8` is the **last** 8 characters of the service's item ID, with any dashes removed first, or the whole ID if it is shorter than 8 characters. (The last characters are used because IDs often share a common prefix.) |
| **Folder name variants** | A service may insert one extra slug part between the date and the title when people search by a short human-readable key, for example `<YYYY-MM-DD>_<key-slug>_<title-slug>_<id8>` for Jira. The first part is still the date and the last part is still `id8`, so code can always read both. Each service section says if it uses a variant. |
| **Title slug** | Lowercase, ASCII only. Drop apostrophes (`Maria's` → `marias`), turn every other run of non `a-z0-9` characters into one `-`, trim `-` from both ends, and cut at 60 characters (then trim a trailing `-`). Empty result → `untitled`. |
| **Identity** | The service's item ID is the identity, never the folder name. Before writing, look for an existing `metadata.json` whose `id` matches. If one is found, **update that folder** (rename it if the title or date changed) instead of creating a second one. |
| **Content file** | `content.md` for text. Start it with `# <title>`, then the body. Use other extensions only for formats that can't become Markdown (for example `content.pdf`). |
| **Encoding** | UTF-8 without BOM, LF line endings, JSON indented with 2 spaces. |
| **Timestamps** | ISO 8601 UTC strings (`2026-10-13T23:13:45.770Z`). If only the date is known, store `YYYY-MM-DD` and set the matching `*_precision` field to `"day"`. |
| **Unknown values** | Use `null`. Never guess. |
| **Read only** | Downloads never change anything in the source service. |
| **`index.json`** | Rebuild it from the `metadata.json` files after every download run (never hand-edit it), so it lists **every** item folder for that service. Sort by `created_time`, then `title`, comparing strings by code point (ordinal), not by locale. |

### Shared `metadata.json` fields

Every service's `metadata.json` contains these fields. Service sections below add their own fields.

| Field | Type | Meaning |
|---|---|---|
| `schema_version` | integer | Format version, currently `1`. |
| `service` | string | `notion`, `jira`, `gmail`, `gdrive`, `github` or `slack`. |
| `id` | string | The service's own ID for the item. This is the identity used for updates. |
| `title` | string | Human-readable title (page title, email subject, file name, issue title…). |
| `url` | string \| null | Link to open the item in the service. |
| `created_time` | string | When the item was created (see Timestamps above). |
| `last_edited_time` | string \| null | When the item was last changed in the service. |
| `created_by` | object \| null | `{ "id": string, "name": string }` for the author. |
| `downloaded_at` | string | When this copy was saved locally. |
| `content_file` | string | Name of the content file in the folder, for example `content.md`. |
| `download_request` | object | The MCP call that returned the content: `mcp_server`, `mcp_server_url`, `tool`, `arguments`, plus any as-of time the response reported. |
| `supporting_requests` | array | Other MCP calls whose results went into this file, each `{ "purpose", "tool", "arguments" }`. |

### Shared `index.json` shape

```json
{
  "schema_version": 1,
  "service": "<service>",
  "updated_at": "<ISO timestamp of the last run>",
  "count": 0,
  "pages": [
    { "id": "…", "title": "…", "folder": "…", "created_time": "…", "last_edited_time": "…" }
  ]
}
```

| Field | Type | Meaning |
|---|---|---|
| `schema_version` | integer | `1`. |
| `service` | string | Same value as in each `metadata.json`. |
| `updated_at` | string | When the index was last rewritten. |
| `count` | integer | Number of entries in `pages`. Must equal the number of item folders. |
| `pages` | array | One entry per item folder. Each entry copies `id`, `title`, `created_time`, `last_edited_time` from that item's `metadata.json` and adds `folder` (the folder name, relative to the service directory). |

The array is called `pages` for every service, so the dashboard can read every index with the same code.

Every service rebuilds its index with the same shared script, run from the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-index.ps1 -ExportDir dataExports/<service>
```

It reads every `*/metadata.json`, stops with an error on duplicate `id`s, sorts the entries, and writes `index.json`. It reads only the shared fields, and takes the `service` value from the folder name.

---

## Notion

**Status:** implemented. Skill: `.claude/skills/download-notion/SKILL.md`.
**Source:** official Notion MCP server (`https://mcp.notion.com/mcp`). Content comes from `notion-fetch`.

### Layout

```
dataExports/notion/
  index.json
  2026-10-13_project-falcon-kickoff-meeting-notes_1b8a25e7/
    content.md
    metadata.json
  2026-10-13_recipe-marias-black-bean-enchiladas_d985a48a/
    content.md
    metadata.json
  …
```

### Folder name

`<created-date>_<title-slug>_<last-8-chars-of-page-id>`

| Part | Source | Example |
|---|---|---|
| `created-date` | `created_time`, date only | `2026-10-13` |
| `title-slug` | page title, slug rules above (emoji icon is not part of the title) | `recipe-marias-black-bean-enchiladas` |
| `id8` | last 8 hex characters of the page ID, dashes removed | `d985a48a` (from `3f848ed8-7a9c-81eb-91db-d956d985a48a`) |

> **Why the last 8:** pages in the same Notion workspace share their leading ID characters (every page in the test workspace starts with `3f848ed8`). The trailing characters differ between pages. Even so, the folder name is only for people to read: always match pages by the full `id` in `metadata.json`.

### `content.md`

- Line 1 is `# <page title>`, followed by a blank line.
- After that comes the page body: the text inside `<content>…</content>` from the `notion-fetch` response. It is already Markdown, so it is kept unchanged except that blank lines are added between blocks so it renders correctly.
- What is kept: headings (`##`), bulleted and numbered lists, to-dos (`- [ ]` / `- [x]`), bold, italic, inline code, quotes, and Notion's `\$` escapes.
- Child pages (`<page url="…">Title</page>` tags) are **not** copied into the parent's body. Each child page is downloaded on its own.
- Notion-specific tags that have no Markdown equivalent (callouts, columns, databases, mentions) are kept as written by the fetch response, so no information is lost.

### `metadata.json` fields

| Field | Type | Example | Notes |
|---|---|---|---|
| `schema_version` | integer | `1` | |
| `service` | string | `"notion"` | |
| `id` | string (UUID with dashes) | `"3f848ed8-7a9c-81eb-91db-d956d985a48a"` | Notion page ID. Identity key. |
| `title` | string | `"Recipe: Maria's Black Bean Enchiladas"` | From `properties.title`, without the icon. |
| `icon` | string \| null | `"🌯"` | Emoji icon, or `null`. |
| `url` | string | `"https://app.notion.com/p/3f848ed87a9c81eb91dbd956d985a48a"` | Page URL with the `?pvs=…` query removed. |
| `parent` | object \| null | see below | Direct parent page, from `<ancestor-path>`. `null` for top-level pages. |
| `parent.id` | string | `"3f848ed8-7a9c-810b-97e4-f9d94e08e8cd"` | |
| `parent.title` | string | `"Test Data"` | |
| `parent.url` | string | `"https://app.notion.com/p/3f848ed87a9c810b97e4f9d94e08e8cd"` | |
| `created_time` | string | `"2026-10-13"` | See "Where the dates come from" below. |
| `created_time_precision` | string | `"day"` | `"day"` or `"exact"`. |
| `last_edited_time` | string | `"2026-10-13T23:13:45.770Z"` | `page_last_edited_at` from `notion-fetch`. |
| `created_by` | object \| null | `{ "id": "3f8d872b-594c-811e-a0b0-0002261b832d", "name": "AI class" }` | See below. |
| `downloaded_at` | string | `"2026-10-13T23:21:11.134Z"` | |
| `content_file` | string | `"content.md"` | |
| `download_request` | object | see example | The `notion-fetch` call that returned the content. |
| `download_request.mcp_server` | string | `"notion"` | Server name in `.mcp.json`. |
| `download_request.mcp_server_url` | string | `"https://mcp.notion.com/mcp"` | |
| `download_request.tool` | string | `"notion-fetch"` | |
| `download_request.arguments` | object | `{ "id": "3f848ed87a9c81eb91dbd956d985a48a" }` | Exact arguments sent. |
| `download_request.response_as_of` | string | `"2026-10-13T23:13:45.813Z"` | The "as of" time in the fetch response. |
| `supporting_requests` | array | see example | How the page was found, plus the calls used for `created_time` and `created_by`. |

#### Where the dates and author come from

`notion-fetch` returns `page_last_edited_at` but **not** the created time or the creator. They are filled in like this:

- **`created_time`**: run `notion-search` with `filters.created_date_range` set to one day, scoped by `page_url` to the parent. If the page appears in the results, it was created that day. Store the date and set `created_time_precision: "day"`. Do not use the search result's `timestamp` field as the created time: it is the last-edited time cut to the minute.
- **`created_by`**: run `notion-search` with `filters.created_by_user_ids: ["me"]`, and call `notion-get-self` to get the `me` user's `id` and `name`. If a page doesn't show up for `me` and no other creator can be confirmed, use `null`.

If a later version of the Notion MCP returns exact created times, store them and set `created_time_precision: "exact"`.

### Example `metadata.json`

```json
{
  "schema_version": 1,
  "service": "notion",
  "id": "3f848ed8-7a9c-81eb-91db-d956d985a48a",
  "title": "Recipe: Maria's Black Bean Enchiladas",
  "icon": "🌯",
  "url": "https://app.notion.com/p/3f848ed87a9c81eb91dbd956d985a48a",
  "parent": {
    "id": "3f848ed8-7a9c-810b-97e4-f9d94e08e8cd",
    "title": "Test Data",
    "url": "https://app.notion.com/p/3f848ed87a9c810b97e4f9d94e08e8cd"
  },
  "created_time": "2026-10-13",
  "created_time_precision": "day",
  "last_edited_time": "2026-10-13T23:13:45.770Z",
  "created_by": { "id": "3f8d872b-594c-811e-a0b0-0002261b832d", "name": "AI class" },
  "downloaded_at": "2026-10-13T23:21:11.134Z",
  "content_file": "content.md",
  "download_request": {
    "mcp_server": "notion",
    "mcp_server_url": "https://mcp.notion.com/mcp",
    "tool": "notion-fetch",
    "arguments": { "id": "3f848ed87a9c81eb91dbd956d985a48a" },
    "response_as_of": "2026-10-13T23:13:45.813Z"
  },
  "supporting_requests": [
    { "purpose": "list child pages of the parent", "tool": "notion-fetch", "arguments": { "id": "3f848ed8-7a9c-810b-97e4-f9d94e08e8cd" } },
    { "purpose": "confirm created date and creator (fetch does not return them)", "tool": "notion-search", "arguments": { "query": "Project Falcon", "page_url": "3f848ed87a9c810b97e4f9d94e08e8cd", "filters": { "created_by_user_ids": ["me"], "created_date_range": { "start_date": "2026-10-13", "end_date": "2026-10-13" } } } },
    { "purpose": "resolve the 'me' user id and name", "tool": "notion-get-self", "arguments": {} }
  ]
}
```

### `index.json`

Uses the [shared shape](#shared-indexjson-shape) with `"service": "notion"`. Rebuild it with the shared script, passing `-ExportDir dataExports/notion`.

---

## Jira

**Status:** implemented. Skill: `.claude/skills/download-jira/SKILL.md`.
**Source:** Atlassian Rovo MCP server (`https://mcp.atlassian.com/v1/mcp/authv2`, server name `atlassian` in `.mcp.json`). Content comes from `searchJiraIssuesUsingJql` (or `getJiraIssue` for one issue) with `responseContentFormat: "markdown"`. The skill's `write-issues.ps1` turns the saved response into the files below.

### Layout

```
dataExports/jira/
  index.json
  2026-10-14_falcon-1_unified-cross-service-search-dashboard-semester-mvp_10020/
    content.md
    metadata.json
  2026-10-14_falcon-2_search-returns-duplicate-results-after-syncing-notion-more-t_10021/
    content.md
    metadata.json
  …
```

### Folder name (variant)

`<created-date>_<key-slug>_<title-slug>_<id8>`. This is the [key variant](#shared-rules) of the common rule, so you can find an issue by its key.

| Part | Source | Example |
|---|---|---|
| `created-date` | `created_time` converted to UTC, date only. Jira reports times in the user's offset, so an issue created at 21:25 New York time on Oct 13 is filed under `2026-10-14`. | `2026-10-14` |
| `key-slug` | issue key, slug rules (lowercase) | `falcon-2` |
| `title-slug` | issue summary, slug rules (max 60 characters) | `search-returns-duplicate-results-after-syncing-notion-more-t` |
| `id8` | last 8 characters of the numeric issue ID, or the whole ID when shorter | `10021` |

> **Why the ID and not the key:** keys change when an issue moves to another project; the issue ID does not. The key in the folder name is only there for people to read. Always match by `id` in `metadata.json`. If the key or summary changes, the folder is renamed.

### `content.md`

```
# <summary>

| Field | Value |
|---|---|
| Key | [FALCON-2](https://aiassistedyu.atlassian.net/browse/FALCON-2) |
| Type | Bug |
| Status | In Progress |
| Priority | High |
| Labels | indexer, notion-connector, … |
| Epic | FALCON-1 — Unified cross-service search dashboard (semester MVP) |
| Reporter | AI class |
| Assignee | Unassigned |
| Resolution | Unresolved |
| Created | 2026-10-14T01:25:42.875Z |
| Updated | 2026-10-14T01:26:21.213Z |

## Description

<full description, Markdown as returned by the MCP server>

## Comments (1)

### <author display name> — <comment created, UTC>

<comment body>
```

- Line 1 is `# <summary>`.
- The field table always has the rows shown above. `Parent` (when the parent is not an epic) and `Components` (when there are any) are added after `Epic`. Missing values are written as `None`, `Unassigned` or `Unresolved`.
- The description is copied unchanged, so its own `##` headings sit at the same level as `## Description`. If there is no description, the section says `_No description._`.
- All comments, oldest first. With no comments, the section says `_No comments._`.

### `metadata.json` fields

| Field | Type | Example | Notes |
|---|---|---|---|
| `schema_version` | integer | `1` | |
| `service` | string | `"jira"` | |
| `id` | string | `"10021"` | Jira issue ID (numeric, stored as a string). Identity key. Unique only within one site (see note below). |
| `key` | string | `"FALCON-2"` | Issue key. Can change if the issue moves. |
| `title` | string | `"Search returns duplicate results after syncing Notion more than once"` | Issue summary. |
| `url` | string | `"https://aiassistedyu.atlassian.net/browse/FALCON-2"` | `webUrl` from the response. |
| `site` | string | `"aiassistedyu.atlassian.net"` | Host of `url`. |
| `cloud_id` | string | `"248c3611-13ff-457c-8a82-d282b53025f2"` | Atlassian cloud ID used in the request. |
| `project` | object | `{ "id": "10002", "key": "FALCON", "name": "Project Falcon" }` | |
| `issue_type` | string | `"Bug"` | `Epic`, `Story`, `Task`, `Bug`, `Subtask`… |
| `status` | string | `"In Progress"` | Workflow status name. |
| `status_category` | string \| null | `"In Progress"` | `To Do`, `In Progress` or `Done`. Stable across custom workflows. |
| `priority` | string \| null | `"High"` | |
| `labels` | string[] | `["indexer", "search"]` | `[]` if none. |
| `components` | string[] | `[]` | Component names. |
| `parent` | object \| null | see below | Direct parent issue (the epic for stories/tasks/bugs, the story for subtasks). `null` for top-level issues. |
| `parent.id` | string | `"10020"` | |
| `parent.key` | string | `"FALCON-1"` | |
| `parent.title` | string | `"Unified cross-service search dashboard (semester MVP)"` | |
| `parent.issue_type` | string | `"Epic"` | |
| `epic_key` | string \| null | `"FALCON-1"` | Same as `parent.key` when the parent is an Epic, otherwise `null`. |
| `reporter` | object \| null | `{ "id": "712020:8044d6d6-…", "name": "AI class" }` | Atlassian account ID and display name. Email addresses are not stored. |
| `assignee` | object \| null | `null` | Same shape as `reporter`. `null` = unassigned. |
| `resolution` | string \| null | `"Done"` | `null` while unresolved. |
| `resolved_time` | string \| null | `"2026-10-14T01:26:19.528Z"` | `resolutiondate`, UTC. |
| `comment_count` | integer | `1` | Total comments on the issue (from `comment.total`). |
| `created_time` | string | `"2026-10-14T01:25:42.875Z"` | Jira `created`, converted to UTC. |
| `created_time_precision` | string | `"exact"` | Always `"exact"` for Jira. |
| `last_edited_time` | string | `"2026-10-14T01:26:21.213Z"` | Jira `updated`, converted to UTC. |
| `created_by` | object \| null | `{ "id": "712020:8044d6d6-…", "name": "AI class" }` | Jira `creator` (who created the issue; may differ from `reporter`). |
| `downloaded_at` | string | `"2026-10-14T01:33:34.488Z"` | |
| `content_file` | string | `"content.md"` | |
| `download_request` | object | see example | The `searchJiraIssuesUsingJql` (or `getJiraIssue`) call that returned the issue. The response has no as-of time, so none is stored. |
| `download_request.mcp_server` | string | `"atlassian"` | |
| `download_request.mcp_server_url` | string | `"https://mcp.atlassian.com/v1/mcp/authv2"` | |
| `download_request.tool` | string | `"searchJiraIssuesUsingJql"` | |
| `download_request.arguments` | object | `{ "cloudId": "…", "jql": "project = FALCON ORDER BY key ASC", … }` | Exact arguments sent. |
| `supporting_requests` | array | `[{ "purpose": "resolve the cloudId of the Jira site", "tool": "getAccessibleAtlassianResources", "arguments": {} }]` | Plus any user lookups used to build the JQL. |

> **One site per export:** Jira issue IDs are unique within a site, not across sites. `dataExports/jira/` currently holds one site (`aiassistedyu.atlassian.net`). Before downloading from a second site, change `id` to `"<site>:<issue id>"` for every issue so IDs stay unique.

### Example `metadata.json`

```json
{
  "schema_version": 1,
  "service": "jira",
  "id": "10021",
  "key": "FALCON-2",
  "title": "Search returns duplicate results after syncing Notion more than once",
  "url": "https://aiassistedyu.atlassian.net/browse/FALCON-2",
  "site": "aiassistedyu.atlassian.net",
  "cloud_id": "248c3611-13ff-457c-8a82-d282b53025f2",
  "project": { "id": "10002", "key": "FALCON", "name": "Project Falcon" },
  "issue_type": "Bug",
  "status": "In Progress",
  "status_category": "In Progress",
  "priority": "High",
  "labels": ["indexer", "notion-connector", "regression-test", "search", "sqlite-fts5"],
  "components": [],
  "parent": { "id": "10020", "key": "FALCON-1", "title": "Unified cross-service search dashboard (semester MVP)", "issue_type": "Epic" },
  "epic_key": "FALCON-1",
  "reporter": { "id": "712020:8044d6d6-4ee3-4f0d-a7ab-050bd213b19d", "name": "AI class" },
  "assignee": null,
  "resolution": null,
  "resolved_time": null,
  "comment_count": 1,
  "created_time": "2026-10-14T01:25:42.875Z",
  "created_time_precision": "exact",
  "last_edited_time": "2026-10-14T01:26:21.213Z",
  "created_by": { "id": "712020:8044d6d6-4ee3-4f0d-a7ab-050bd213b19d", "name": "AI class" },
  "downloaded_at": "2026-10-14T01:33:34.488Z",
  "content_file": "content.md",
  "download_request": {
    "mcp_server": "atlassian",
    "mcp_server_url": "https://mcp.atlassian.com/v1/mcp/authv2",
    "tool": "searchJiraIssuesUsingJql",
    "arguments": {
      "cloudId": "248c3611-13ff-457c-8a82-d282b53025f2",
      "jql": "project = FALCON ORDER BY key ASC",
      "maxResults": 100,
      "fields": ["summary", "description", "issuetype", "status", "priority", "labels", "components", "parent", "project", "reporter", "assignee", "creator", "created", "updated", "resolution", "resolutiondate", "comment"],
      "responseContentFormat": "markdown"
    }
  },
  "supporting_requests": [
    { "purpose": "resolve the cloudId of the Jira site", "tool": "getAccessibleAtlassianResources", "arguments": {} }
  ]
}
```

(The script writes every nested object and array on separate lines; it is shown compactly here.)

### `index.json`

Uses the [shared shape](#shared-indexjson-shape) with `"service": "jira"`. `title` is the summary; the key is in `folder`. Rebuild it with the shared script, passing `-ExportDir dataExports/jira`.

---

## Gmail

**Status:** not implemented (waived by instructor). Google's official Gmail MCP server rejects every tool call unless the Google Cloud project is enrolled in the Google Workspace Developer Preview Program. The notes below are kept in case Gmail is added later; they follow the [common pattern](#common-pattern).

- One folder per **message**. Date = sent date, title = subject, `id8` = Gmail message ID.
- `content.md`: subject as `# <subject>`, then the plain-text body. Attachments go in an `attachments/` subfolder.
- Likely extra `metadata.json` fields: `thread_id`, `from`, `to`, `cc`, `labels`, `attachments` (array of `{ filename, mime_type, size }`).

## Google Drive

**Status:** not used. The notes below are kept in case Google Drive is added later; they follow the [common pattern](#common-pattern).

- One folder per **file**. Date = created date, title = file name, `id8` = Drive file ID.
- Google Docs export to `content.md`. Other files keep their own format (`content.pdf`, `content.xlsx`…).
- Likely extra fields: `mime_type`, `parent_folder` (`{ id, name }`), `owners`, `size`.

## GitHub

**Status:** implemented (issues). Pull requests and files are not exported yet. Skill: `.claude/skills/download-github/SKILL.md`.
**Source:** official GitHub MCP server (`https://api.githubcopilot.com/mcp/`, server name `github` in `.mcp.json`). Content comes from `search_issues` scoped to one repository (`owner`, `repo`, `query: "is:issue"`). The skill's `write-issues.ps1` turns the saved response into the files below.

### Layout

```
dataExports/github/
  index.json
  2026-10-15_mcp-services-dashboard-7_test-7-bug-search-is-case-sensitive_7/
    content.md
    metadata.json
  …
```

### Folder name (variant)

`<created-date>_<repo-slug>-<number>_<title-slug>_<id8>`, the [key variant](#shared-rules) of the common rule.

| Part | Source | Example |
|---|---|---|
| `created-date` | `created_at`, UTC date | `2026-10-15` |
| `key-slug` | repository name + issue number, slug rules | `mcp-services-dashboard-7` |
| `title-slug` | issue title, slug rules | `test-7-bug-search-is-case-sensitive` |
| `id8` | the issue number (always shorter than 8 characters) | `7` |

> **Why not the node ID:** the GitHub MCP server does not return issue node IDs or numeric issue IDs (`issue_read`, `list_issues` and `search_issues` all omit them). The identity is therefore `<owner>/<repo>#<number>`, which is stable unless the repository is renamed or the issue is transferred.

### `content.md`

```
# <title>

| Field | Value |
|---|---|
| Issue | [owner/repo#7](https://github.com/owner/repo/issues/7) |
| Kind | Issue |
| State | Open |
| Labels | None |
| Assignees | Unassigned |
| Author | <login> |
| Created | 2026-10-15T02:52:29.000Z |
| Updated | 2026-10-15T02:52:29.000Z |

## Description

<issue body, unchanged>

## Comments (<n>)

### Comment by <login> — <created, UTC>

<comment body>
```

With no body, the description says `_No description._`; with no comments, `_No comments._`. Comments come from `issue_read` with `method: "get_comments"`, oldest first.

### `metadata.json` fields

| Field | Type | Example | Notes |
|---|---|---|---|
| `schema_version` | integer | `1` | |
| `service` | string | `"github"` | |
| `id` | string | `"aiassistedyu-pixel/mcp-services-dashboard#7"` | `<owner>/<repo>#<number>`. Identity key. |
| `title` | string | `"[Test 7] Bug: search is case-sensitive"` | |
| `url` | string | `"https://github.com/aiassistedyu-pixel/mcp-services-dashboard/issues/7"` | `html_url`. |
| `repo` | string | `"aiassistedyu-pixel/mcp-services-dashboard"` | |
| `kind` | string | `"issue"` | `issue` \| `pull_request` \| `file`. |
| `number` | integer | `7` | |
| `state` | string | `"open"` | `open` or `closed`. |
| `state_reason` | string \| null | `null` | `completed`, `not_planned`… when the response has it. |
| `labels` | string[] | `[]` | Label names. |
| `assignees` | string[] | `[]` | Logins. |
| `comment_count` | integer | `0` | `comments` from the response. |
| `closed_time` | string \| null | `null` | `closed_at`, UTC. |
| `created_time` | string | `"2026-10-15T02:52:29.000Z"` | `created_at`, normalized to milliseconds. |
| `created_time_precision` | string | `"exact"` | |
| `last_edited_time` | string | `"2026-10-15T02:52:29.000Z"` | `updated_at`. |
| `created_by` | object | `{ "id": "342214594", "name": "aiassistedyu-pixel" }` | Numeric user ID (as a string) and login. |
| `downloaded_at` | string | | |
| `content_file` | string | `"content.md"` | |
| `download_request` | object | | The `search_issues` call (`mcp_server: "github"`). The response has no as-of time. |
| `supporting_requests` | array | | `get_me`, `search_repositories`, `list_issues`, plus any `get_comments` calls. |

### `index.json`

Uses the [shared shape](#shared-indexjson-shape) with `"service": "github"`.

## Slack

**Status:** implemented. Skill: `.claude/skills/download-slack/SKILL.md`.
**Source:** official Slack MCP server (`https://mcp.slack.com/mcp`, server name `slack` in `.mcp.json`; it may also be available through the Claude Code Slack plugin). Content comes from `slack_read_channel` (and `slack_read_thread` for threads). The skill's `write-channels.ps1` turns the saved responses into the files below.

### Layout

```
dataExports/slack/
  index.json
  2026-10-15_new-channel_93N08NMA/
    content.md
    metadata.json
  …
```

### Folder name

One folder per **channel per UTC day** (a single message is too small to be useful on its own): `<day>_<channel-name-slug>_<last 8 chars of channel ID>`, for example `2026-10-15_social_91V71LGZ`. Days are UTC, so messages sent at 23:01 New York time on Oct 14 go in the `2026-10-15` folder.

### `content.md`

```
# <channel-name>

Channel: #<channel-name> (<channel ID>) · <day> (UTC) · <n> messages

**<user>** 2026-10-15T03:01:34.988Z
<message text>

**<user>** 2026-10-15T03:01:35.204Z
<message text>
```

Messages are oldest first. The text is kept as Slack returned it (Slack `*bold*`, `:emoji:` codes and `<@U…|name>` mentions are not converted). Thread replies go beneath their parent, each line indented by two spaces.

### `metadata.json` fields

| Field | Type | Example | Notes |
|---|---|---|---|
| `schema_version` | integer | `1` | |
| `service` | string | `"slack"` | |
| `id` | string | `"C0C93N08NMA:2026-10-15"` | `<channel ID>:<UTC day>`. Identity key. |
| `title` | string | `"new-channel"` | Channel name without `#`. |
| `url` | null | `null` | The MCP responses don't include the workspace URL. |
| `channel` | object | `{ "id": "C0C93N08NMA", "name": "new-channel" }` | |
| `date` | string | `"2026-10-15"` | The UTC day. |
| `message_count` | integer | `3` | Top-level messages that day. |
| `participants` | array | `[{ "id": "U0C8TQB4V5Z", "name": "AI class" }]` | Everyone who posted, in order of first message. |
| `messages` | array | `[{ "ts": "1792033294.988709", "user": {…}, "time": "…", "thread_reply_count": 0 }]` | One entry per message; `ts` identifies the message in Slack. |
| `created_time` | string | `"2026-10-15T03:01:34.988Z"` | Time of the first message that day (from its `ts`). |
| `created_time_precision` | string | `"exact"` | |
| `last_edited_time` | string | `"2026-10-15T03:01:35.373Z"` | Time of the last message that day. |
| `created_by` | null | `null` | A channel-day has no single author; see `participants`. |
| `downloaded_at` | string | | |
| `content_file` | string | `"content.md"` | |
| `download_request` | object | | The `slack_read_channel` call (`mcp_server: "slack"`, `arguments: { "channel_id": … }`). |
| `supporting_requests` | array | | `slack_list_user_channels`, `slack_read_user_profile`, plus any `slack_read_thread` calls. |

### `index.json`

Uses the [shared shape](#shared-indexjson-shape) with `"service": "slack"`.
