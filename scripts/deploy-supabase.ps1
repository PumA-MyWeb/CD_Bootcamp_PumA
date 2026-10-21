<#
.SYNOPSIS
    Sync the Pumatographer static site into Supabase Storage (public bucket).

.DESCRIPTION
    Uploads the built site files from the repo root into the public Supabase
    Storage bucket "pumatographer" so they are served from:

      https://<PROJECT_REF>.supabase.co/storage/v1/object/public/pumatographer/index.html

    NOTE: On *.supabase.co the platform rewrites text/html -> text/plain and
    injects `Content-Security-Policy: default-src 'none'; sandbox`, so the page
    will NOT render in a browser until the project has a custom domain
    (paid plan required). The bytes served are still correct.

.PARAMETER ProjectRef
    Supabase project ref. Defaults to $env:SUPABASE_PROJECT_REF.

.PARAMETER Key
    Supabase publishable/anon key. Defaults to $env:SUPABASE_KEY, then reads
    .env in the repo root if present.

.EXAMPLE
    .\scripts\deploy-supabase.ps1
    .\scripts\deploy-supabase.ps1 -ProjectRef abcdefghijklmnopqrst -Key sb_publishable_xxx
#>
[CmdletBinding()]
param(
    [string]$ProjectRef = $env:SUPABASE_PROJECT_REF,
    [string]$Key = $env:SUPABASE_KEY,
    [string]$Bucket = 'pumatographer',
    [string[]]$Files = @('index.html', 'pumatographer.html')
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

if (-not $ProjectRef) {
    $envFile = Join-Path $repoRoot '.env'
    if (Test-Path $envFile) {
        foreach ($line in Get-Content $envFile) {
            if ($line -match '^\s*SUPABASE_PROJECT_REF\s*=\s*(.+)$') { $ProjectRef = $matches[1].Trim() }
            elseif ($line -match '^\s*SUPABASE_KEY\s*=\s*(.+)$') { $Key = $matches[1].Trim() }
        }
    }
}

if (-not $ProjectRef) { throw 'PROJECT_REF is required. Pass -ProjectRef or set $env:SUPABASE_PROJECT_REF.' }
if (-not $Key) { throw 'Key is required. Pass -Key or set $env:SUPABASE_KEY.' }

$headers = @{
    apikey         = $Key
    Authorization  = "Bearer $Key"
    'x-upsert'     = 'true'
}

foreach ($name in $Files) {
    $path = Join-Path $repoRoot $name
    if (-not (Test-Path $path)) { throw "Missing file: $path" }

    $uri = "https://$ProjectRef.supabase.co/storage/v1/object/$Bucket/$name"
    Write-Host "Uploading $name ..." -NoNewline

    $resp = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -InFile $path `
        -ContentType 'text/html; charset=utf-8' -UseBasicParsing -TimeoutSec 120

    Write-Host "OK ($($resp.StatusCode)) $($resp.Content)"
}

Write-Host ''
Write-Host "Site URL: https://$ProjectRef.supabase.co/storage/v1/object/public/$Bucket/index.html"
