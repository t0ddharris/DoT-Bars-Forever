$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$addonPath = Join-Path $projectRoot 'DoTBarsForever'
$outputPath = Join-Path $projectRoot 'releases'
$toc = Get-Content -LiteralPath (Join-Path $addonPath 'DoTBarsForever.toc')
$versionLine = $toc | Where-Object { $_ -match '^## Version:\s*(\S+)\s*$' } | Select-Object -First 1
if (-not $versionLine) { throw 'DoTBarsForever.toc has no "## Version:" line.' }
$version = ($versionLine -replace '^## Version:\s*', '').Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "Unexpected TOC version '$version'." }
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
$archivePath = Join-Path $outputPath "DoTBarsForever-$version.zip"
if (Test-Path -LiteralPath $archivePath) { Remove-Item -LiteralPath $archivePath }
# Write entries with forward slashes; Compress-Archive in Windows PowerShell 5.1 uses backslashes.
$zip = [System.IO.Compression.ZipFile]::Open($archivePath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    $root = (Resolve-Path -LiteralPath $addonPath).Path.TrimEnd('\')
    Get-ChildItem -LiteralPath $root -Recurse -File | Sort-Object FullName | ForEach-Object {
        $entry = 'DoTBarsForever/' + $_.FullName.Substring($root.Length + 1).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $entry, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally { $zip.Dispose() }
Write-Output $archivePath
