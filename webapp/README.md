# Services Dashboard (webapp)

A local website that searches everything downloaded into `dataExports/` (Notion pages, Jira issues, and any service added later) in one place. It reads **only** the local files. It never contacts Notion, Jira or any other online service, and it works fully offline.

Plain HTML, CSS and JavaScript. No build step, nothing to install.

## Files

| File | What it is |
|---|---|
| `index.html` | The page. Open this. |
| `app.js` | Search, results list and detail view. |
| `markdown.js` | Small built-in Markdown renderer (no internet needed). |
| `styles.css` | Styles (light and dark mode). |
| `data.js` | **Generated.** All services, metadata and content bundled into one file. Do not edit by hand. |
| `serve.ps1` | Optional local web server for Windows (uses built-in PowerShell). |

## Open the dashboard

### Option A: just open the file (Windows or Mac, nothing to install)

1. Open the `webapp` folder of this repo in File Explorer (Windows) or Finder (Mac).
2. Double-click `index.html`. It opens in your default browser (Edge, Chrome, Firefox and Safari all work).

This works from `file://` because the data is loaded with a normal `<script>` tag (`data.js`) instead of `fetch()`, which browsers block for local files.

### Option B: local web server (Windows, nothing to install)

1. Open PowerShell in the repo folder (in File Explorer, open the repo folder, then type `powershell` in the address bar and press Enter).
2. Run:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File webapp/serve.ps1
   ```

3. Your browser opens `http://localhost:8000/webapp/`. If port 8000 is busy, the script picks the next free port and prints the address.
4. Press `Ctrl+C` in the PowerShell window to stop the server.

The server first rebuilds `data.js` (see below), so it always shows the latest downloads. It only accepts connections from this computer and only serves the `webapp/` and `dataExports/` folders. Options: `-Port 9000`, `-NoBrowser`, `-NoRebuild`.

On a Mac, use Option A. (If you prefer a server and have Python 3: run `python3 -m http.server 8000` in the repo folder, then open `http://localhost:8000/webapp/`. This serves whatever `data.js` is already there; it does not rebuild it.)

## Using it

- **Search all services:** type in the search box, e.g. `Joe Smith`. Results from every service appear together.
- **Search one service:** click a service button (`Jira`, `Notion`, …) under the search box. `All services` goes back to searching everything. Each button shows how many results that service has for the current search.
- **How matching works:** case-insensitive. It searches the title, the full content, and the item's key metadata (people such as reporter, assignee and creator, labels, status, priority, issue type, project, parent page…). With several words, **every** word must appear somewhere in the item (in any order). Put words in double quotes to match an exact phrase, e.g. `"Joe Smith"`.
- **Each result shows:** a colored badge with the service name, the title (matches highlighted), the date created, a snippet around the first match, any metadata fields that matched (e.g. `Assignee: Joe Smith`), and an **Open in …** link to the original item online.
- **Click a result** to read the full `content.md` rendered as formatted text, plus its key metadata, with your search words highlighted. Press `Esc` to close it, `/` to jump to the search box.
- With an empty search box, the page lists every item, newest first.
- The search, service and open item are kept in the address bar (e.g. `index.html#q=Joe%20Smith&service=jira`), so you can bookmark or reload a search.

## Updating the data: rerun after every download

The dashboard reads `webapp/data.js`, not `dataExports/` directly. **After every download** (Notion, Jira, or any new service), rebuild it from the repo folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-dashboard-data.ps1
```

Then reload the page. (Option B does this for you each time the server starts.) The script prints how many items it found per service.

On a Mac this needs PowerShell (`brew install powershell`), then `pwsh scripts/build-dashboard-data.ps1`. This is only needed to update the data; viewing works without it.

## Adding a new service (GitHub, a partner's service, …)

No dashboard code changes are needed. A service appears automatically when its folder follows the shared format in `localStorageFormats.md`:

```
dataExports/<service>/index.json                 ← lists the item folders ("pages" array)
dataExports/<service>/<folder>/metadata.json     ← title, url, created_time, people, labels, status…
dataExports/<service>/<folder>/content.md        ← the item's text, starting with "# <title>"
```

1. Download the data into `dataExports/<service>/`.
2. Rebuild that service's index: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-index.ps1 -ExportDir dataExports/<service>`
3. Rebuild the dashboard data: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-dashboard-data.ps1`

How a new service is handled:

- It is shown only if its `index.json` lists at least one item. Empty folders (like `dataExports/github/` today) are skipped.
- Services with a known name (`github`, `slack`, `gdrive`, `gmail`, `notion`, `jira`) get their usual name and color. Any other folder name is shown as-is in title case (`partner-wiki` becomes "Partner Wiki") with its own color. To pick a name and color, add one line to `SERVICES` at the top of `app.js` (optional).
- Every metadata field is searched and shown, except the download bookkeeping fields (`download_request`, `supporting_requests`, `downloaded_at`, ids…). People are shown by `name`, linked items by `key` and `title`, lists comma-separated.
- If an item's content file is not text (e.g. `content.pdf`), the detail view links to the local file instead of rendering it.

## Troubleshooting

- **"No data found. Run scripts/build-dashboard-data.ps1…"**: `data.js` is missing. Run the rebuild command above.
- **New downloads don't show up:** rerun `scripts/build-dashboard-data.ps1` (and `build-index.ps1` for that service first), then reload the page.
- **"running scripts is disabled on this system":** use the exact commands above; `-ExecutionPolicy Bypass` allows them for that one run only.
- **"Open in …" links don't load:** they point to the online originals and need internet access. Everything else works offline.
