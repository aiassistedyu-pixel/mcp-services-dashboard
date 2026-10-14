# Writes Jira issues from saved Atlassian MCP responses into <ExportDir>/<folder>/{content.md,metadata.json}.
# Format: see localStorageFormats.md ("Common pattern" and "Jira"). Does not touch index.json; run
# scripts/build-index.ps1 afterwards.
#
# -ResponseFile: one or more files, each the JSON returned by searchJiraIssuesUsingJql ({ issues: { nodes: [...] } })
#                or by getJiraIssue (a single issue { id, key, fields }). Requested with responseContentFormat "markdown".
# -RequestFile:  one per response file, same order. JSON describing the call that produced it:
#                { mcp_server, mcp_server_url, tool, arguments, supporting_requests: [ { purpose, tool, arguments } ] }
# If the same issue appears in several responses, the last one wins.
#
# Usage (from the repo root):
#   powershell -NoProfile -ExecutionPolicy Bypass -File .claude/skills/download-jira/write-issues.ps1 `
#     -ResponseFile <response.json> -RequestFile <request.json> [-ExportDir dataExports/jira]
param(
    [Parameter(Mandatory = $true)][string[]]$ResponseFile,
    [Parameter(Mandatory = $true)][string[]]$RequestFile,
    [string]$ExportDir = "dataExports/jira"
)

$ErrorActionPreference = "Stop"
$inv = [Globalization.CultureInfo]::InvariantCulture
$utf8 = New-Object System.Text.UTF8Encoding($false)
if ($ResponseFile.Count -ne $RequestFile.Count) { throw "Pass one -RequestFile per -ResponseFile" }
if (-not (Test-Path -LiteralPath $ExportDir)) { New-Item -ItemType Directory -Path $ExportDir | Out-Null }
$dir = (Resolve-Path $ExportDir).Path

function Esc([string]$s) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $s.ToCharArray()) {
        switch ($c) {
            '"'  { [void]$sb.Append('\"') }
            '\'  { [void]$sb.Append('\\') }
            "`n" { [void]$sb.Append('\n') }
            "`r" { [void]$sb.Append('\r') }
            "`t" { [void]$sb.Append('\t') }
            default {
                if ([int]$c -lt 0x20) { [void]$sb.AppendFormat('\u{0:x4}', [int]$c) } else { [void]$sb.Append($c) }
            }
        }
    }
    return '"' + $sb.ToString() + '"'
}

# Serializes ordered dictionaries, PSCustomObjects, arrays and scalars as JSON indented with 2 spaces.
function ToJson($v, [string]$ind = "") {
    if ($null -eq $v) { return "null" }
    if ($v -is [bool]) { if ($v) { return "true" } else { return "false" } }
    if ($v -is [string]) { return Esc $v }
    if ($v -is [int] -or $v -is [long] -or $v -is [double] -or $v -is [decimal]) { return ([string]::Format($inv, "{0}", $v)) }
    $next = $ind + "  "
    if ($v -is [System.Collections.IDictionary] -or $v -is [System.Management.Automation.PSCustomObject]) {
        $pairs = if ($v -is [System.Collections.IDictionary]) { @($v.Keys | ForEach-Object { ,@($_, $v[$_]) }) }
                 else { @($v.PSObject.Properties | ForEach-Object { ,@($_.Name, $_.Value) }) }
        if ($pairs.Count -eq 0) { return "{}" }
        $items = foreach ($p in $pairs) { "$next$(Esc $p[0]): $(ToJson $p[1] $next)" }
        return "{`n" + ($items -join ",`n") + "`n$ind}"
    }
    if ($v -is [System.Collections.IEnumerable]) {
        $arr = @($v)
        if ($arr.Count -eq 0) { return "[]" }
        $items = foreach ($x in $arr) { "$next$(ToJson $x $next)" }
        return "[`n" + ($items -join ",`n") + "`n$ind]"
    }
    throw "Cannot serialize value of type $($v.GetType().FullName)"
}

# Jira returns "2026-10-13T21:25:42.875-0400"; store UTC "2026-10-14T01:25:42.875Z".
function ToUtc($s) {
    if ([string]::IsNullOrEmpty($s)) { return $null }
    $t = $s -replace '([+-]\d{2})(\d{2})$', '$1:$2'
    return [DateTimeOffset]::Parse($t, $inv).UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ", $inv)
}

function Slug([string]$s) {
    $s = $s.Normalize([Text.NormalizationForm]::FormD) -replace '[^\x00-\x7F]', ''
    $s = $s.ToLowerInvariant() -replace "['$([char]0x2019)]", '' -replace '[^a-z0-9]+', '-'
    $s = $s.Trim('-')
    if ($s.Length -gt 60) { $s = $s.Substring(0, 60).TrimEnd('-') }
    if ($s -eq "") { return "untitled" }
    return $s
}

function User($u) {
    if ($null -eq $u) { return $null }
    return [ordered]@{ id = [string]$u.accountId; name = [string]$u.displayName }
}

function Cell($s) { return ([string]$s -replace '\r?\n', ' ' -replace '\|', '\|') }

function Body($s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return $null }
    return (([string]$s -replace "`r`n", "`n").TrimEnd())
}

# Existing folders by issue id, so re-downloads update in place instead of duplicating.
$existing = @{}
foreach ($d in Get-ChildItem -LiteralPath $dir -Directory) {
    $mp = Join-Path $d.FullName "metadata.json"
    if (Test-Path -LiteralPath $mp) {
        $m = [IO.File]::ReadAllText($mp, $utf8) | ConvertFrom-Json
        if ($m.id) { $existing[[string]$m.id] = $d.Name }
    }
}

# Collect issues; later responses override earlier ones.
$issues = [ordered]@{}
for ($i = 0; $i -lt $ResponseFile.Count; $i++) {
    $resp = [IO.File]::ReadAllText((Resolve-Path $ResponseFile[$i]).Path, $utf8) | ConvertFrom-Json
    $req = [IO.File]::ReadAllText((Resolve-Path $RequestFile[$i]).Path, $utf8) | ConvertFrom-Json
    $nodes = if ($resp.issues) { @($resp.issues.nodes) } else { @($resp) }
    if ($resp.issues -and $resp.issues.pageInfo.hasNextPage) { Write-Warning "$($ResponseFile[$i]) has more pages; fetch them with nextPageToken" }
    foreach ($n in $nodes) { $issues[[string]$n.id] = @{ node = $n; req = $req } }
}

$now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ", $inv)
foreach ($entry in $issues.Values) {
    $n = $entry.node; $req = $entry.req; $f = $n.fields
    if (-not $n.key -or -not $f.created) { throw "Issue $($n.id) is missing key or created; request the fields listed in SKILL.md" }
    $comments = @($f.comment.comments | Where-Object { $_ })
    $commentTotal = if ($null -ne $f.comment.total) { [int]$f.comment.total } else { $comments.Count }
    if ($commentTotal -gt $comments.Count) {
        Write-Warning "$($n.key): response has $($comments.Count) of $commentTotal comments; refetch it with getJiraIssue"
    }

    $url = if ($n.webUrl) { [string]$n.webUrl } else { $null }
    $site = if ($url) { ([Uri]$url).Host } else { $null }
    $created = ToUtc $f.created
    $parent = $null; $epicKey = $null
    if ($f.parent) {
        $parent = [ordered]@{
            id = [string]$f.parent.id; key = [string]$f.parent.key
            title = [string]$f.parent.fields.summary; issue_type = [string]$f.parent.fields.issuetype.name
        }
        if ($f.parent.fields.issuetype.name -eq "Epic") { $epicKey = [string]$f.parent.key }
    }
    [string[]]$labels = @($f.labels | Where-Object { $_ })
    [string[]]$components = @($f.components | ForEach-Object { $_.name } | Where-Object { $_ })

    $meta = [ordered]@{
        schema_version = 1
        service = "jira"
        id = [string]$n.id
        key = [string]$n.key
        title = [string]$f.summary
        url = $url
        site = $site
        cloud_id = [string]$req.arguments.cloudId
        project = if ($f.project) { [ordered]@{ id = [string]$f.project.id; key = [string]$f.project.key; name = [string]$f.project.name } } else { $null }
        issue_type = [string]$f.issuetype.name
        status = [string]$f.status.name
        status_category = if ($f.status.statusCategory) { [string]$f.status.statusCategory.name } else { $null }
        priority = if ($f.priority) { [string]$f.priority.name } else { $null }
        labels = $labels
        components = $components
        parent = $parent
        epic_key = $epicKey
        reporter = User $f.reporter
        assignee = User $f.assignee
        resolution = if ($f.resolution) { [string]$f.resolution.name } else { $null }
        resolved_time = ToUtc $f.resolutiondate
        comment_count = $commentTotal
        created_time = $created
        created_time_precision = "exact"
        last_edited_time = ToUtc $f.updated
        created_by = User $f.creator
        downloaded_at = $now
        content_file = "content.md"
        download_request = [ordered]@{
            mcp_server = [string]$req.mcp_server
            mcp_server_url = [string]$req.mcp_server_url
            tool = [string]$req.tool
            arguments = $req.arguments
        }
        supporting_requests = @($req.supporting_requests | Where-Object { $_ })
    }

    # content.md
    $none = "None"; $dash = [char]0x2014
    $epicCell = if ($epicKey) { "$epicKey $dash $(Cell $parent.title)" } else { $none }
    $md = New-Object System.Collections.Generic.List[string]
    $md.Add("# $($f.summary)"); $md.Add("")
    $md.Add("| Field | Value |"); $md.Add("|---|---|")
    $md.Add("| Key | [$($n.key)]($url) |")
    $md.Add("| Type | $(Cell $meta.issue_type) |")
    $md.Add("| Status | $(Cell $meta.status) |")
    $md.Add("| Priority | $(if ($meta.priority) { Cell $meta.priority } else { $none }) |")
    $md.Add("| Labels | $(if ($labels.Count) { Cell ($labels -join ', ') } else { $none }) |")
    $md.Add("| Epic | $epicCell |")
    if ($parent -and -not $epicKey) { $md.Add("| Parent | $($parent.key) $dash $(Cell $parent.title) |") }
    if ($components.Count) { $md.Add("| Components | $(Cell ($components -join ', ')) |") }
    $md.Add("| Reporter | $(if ($meta.reporter) { Cell $meta.reporter.name } else { $none }) |")
    $md.Add("| Assignee | $(if ($meta.assignee) { Cell $meta.assignee.name } else { 'Unassigned' }) |")
    $md.Add("| Resolution | $(if ($meta.resolution) { Cell $meta.resolution } else { 'Unresolved' }) |")
    $md.Add("| Created | $created |")
    $md.Add("| Updated | $($meta.last_edited_time) |")
    $md.Add(""); $md.Add("## Description"); $md.Add("")
    $desc = Body $f.description
    $md.Add($(if ($desc) { $desc } else { "_No description._" }))
    $md.Add(""); $md.Add("## Comments ($commentTotal)"); $md.Add("")
    if ($comments.Count -eq 0) { $md.Add("_No comments._"); $md.Add("") }
    foreach ($c in $comments) {
        $who = if ($c.author) { $c.author.displayName } else { "Unknown" }
        $md.Add("### $who $dash $(ToUtc $c.created)"); $md.Add("")
        $b = Body $c.body
        $md.Add($(if ($b) { $b } else { "_Empty comment._" })); $md.Add("")
    }

    # Folder: <created date>_<key slug>_<title slug>_<last 8 chars of issue id>
    $idPart = ([string]$n.id) -replace '-', ''
    if ($idPart.Length -gt 8) { $idPart = $idPart.Substring($idPart.Length - 8) }
    $folder = "$($created.Substring(0, 10))_$(Slug $n.key)_$(Slug $f.summary)_$idPart"
    $target = Join-Path $dir $folder
    $action = "created"
    if ($existing.ContainsKey($meta.id)) {
        $old = $existing[$meta.id]
        if ($old -ne $folder) { Move-Item -LiteralPath (Join-Path $dir $old) -Destination $target; $action = "renamed from $old" }
        else { $action = "updated" }
    } else { New-Item -ItemType Directory -Path $target | Out-Null }
    $existing[$meta.id] = $folder

    [IO.File]::WriteAllText((Join-Path $target "content.md"), (($md -join "`n").TrimEnd() + "`n"), $utf8)
    [IO.File]::WriteAllText((Join-Path $target "metadata.json"), (ToJson $meta) + "`n", $utf8)
    Write-Output "$($n.key): $action -> $folder"
}
