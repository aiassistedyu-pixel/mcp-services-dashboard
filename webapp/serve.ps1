# Optional local web server for the dashboard. Uses only Windows' built-in PowerShell (nothing to install).
# You don't need a server at all: double-clicking webapp/index.html works too. Use this if you prefer
# http://localhost, or if your browser blocks local files.
# It first rebuilds webapp/data.js from dataExports/, so the page always shows the latest download.
# Usage (from the repo root): powershell -NoProfile -ExecutionPolicy Bypass -File webapp/serve.ps1
# Stop it with Ctrl+C. Only this computer can connect (it listens on localhost only).
param([int]$Port = 8000, [switch]$NoBrowser, [switch]$NoRebuild)

$ErrorActionPreference = "Stop"
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
# Only these folders are served. Everything else in the repo (e.g. .mcp.json) is not.
$allowed = @("webapp", "dataExports")

if (-not $NoRebuild) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts/build-dashboard-data.ps1")
    if ($LASTEXITCODE -ne 0) { throw "Rebuilding webapp/data.js failed (see the error above)." }
}

$types = @{
    ".html" = "text/html; charset=utf-8"; ".js" = "text/javascript; charset=utf-8"; ".css" = "text/css; charset=utf-8"
    ".json" = "application/json; charset=utf-8"; ".md" = "text/markdown; charset=utf-8"; ".txt" = "text/plain; charset=utf-8"
    ".png" = "image/png"; ".jpg" = "image/jpeg"; ".jpeg" = "image/jpeg"; ".gif" = "image/gif"; ".svg" = "image/svg+xml"
    ".pdf" = "application/pdf"; ".ico" = "image/x-icon"
}

# Find a free port, starting at $Port.
$listener = $null
for ($p = $Port; $p -lt $Port + 20; $p++) {
    $l = New-Object System.Net.HttpListener
    $l.Prefixes.Add("http://localhost:$p/")
    try { $l.Start(); $listener = $l; $Port = $p; break } catch { $l.Close() }
}
if (-not $listener) { throw "No free port between $Port and $($Port + 19)." }

$url = "http://localhost:$Port/webapp/"
Write-Host ""
Write-Host "Dashboard running at $url"
Write-Host "Press Ctrl+C to stop."
if (-not $NoBrowser) { Start-Process $url }

function Send($ctx, [int]$status, [byte[]]$body, [string]$type) {
    $ctx.Response.StatusCode = $status
    $ctx.Response.ContentType = $type
    $ctx.Response.Headers.Add("Cache-Control", "no-store")
    $ctx.Response.ContentLength64 = $body.Length
    $ctx.Response.OutputStream.Write($body, 0, $body.Length)
    $ctx.Response.Close()
}

try {
    while ($listener.IsListening) {
        $task = $listener.GetContextAsync()
        while (-not $task.AsyncWaitHandle.WaitOne(500)) { }   # short waits so Ctrl+C works
        $ctx = $task.GetAwaiter().GetResult()
        try {
            $path = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)
            if ($path -eq "/" -or $path -eq "/webapp") {
                $ctx.Response.Redirect("/webapp/"); $ctx.Response.Close(); continue
            }
            if ($path.EndsWith("/")) { $path += "index.html" }
            $rel = $path.TrimStart("/")
            $full = [System.IO.Path]::GetFullPath((Join-Path $root $rel))
            $top = ($rel -split "/")[0]
            $inside = $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
            if (-not $inside -or $allowed -notcontains $top -or -not (Test-Path -LiteralPath $full -PathType Leaf)) {
                Send $ctx 404 ([System.Text.Encoding]::UTF8.GetBytes("Not found")) "text/plain; charset=utf-8"
                Write-Host "404 $path"
                continue
            }
            $ext = [System.IO.Path]::GetExtension($full).ToLowerInvariant()
            $type = if ($types.ContainsKey($ext)) { $types[$ext] } else { "application/octet-stream" }
            Send $ctx 200 ([System.IO.File]::ReadAllBytes($full)) $type
        } catch {
            Write-Warning $_
            try { $ctx.Response.Abort() } catch { }
        }
    }
} finally {
    $listener.Stop()
    $listener.Close()
    Write-Host "Server stopped."
}
