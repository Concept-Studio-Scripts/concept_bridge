<#
.SYNOPSIS
    Builds a complete Concept Bridge source/resource ZIP (PowerShell 7).
.PARAMETER OutFile
    ZIP destination. Defaults to release/concept_bridge-<version>.zip.
#>
[CmdletBinding()]
param(
    [string]$OutFile = ''
)

$ErrorActionPreference = 'Stop'
$ResourceRoot = Split-Path -Parent $PSScriptRoot

if (-not ('System.IO.Compression.ZipFile' -as [type])) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
}

$ManifestText = [IO.File]::ReadAllText((Join-Path $ResourceRoot 'fxmanifest.lua'))
$VersionMatch = [regex]::Match($ManifestText, "(?m)^version '([^']+)'(?: -- x-release-please-version)?$")
if (-not $VersionMatch.Success) { throw 'Manifest version missing.' }
$Version = $VersionMatch.Groups[1].Value
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Manifest version must have three numeric components.' }
if ($ManifestText -notmatch "(?m)^name 'concept_bridge'$") { throw 'Canonical resource name missing.' }

$SourceVersion = (Get-Content -LiteralPath (Join-Path $ResourceRoot 'version.txt') -Raw).Trim()
$ReleaseVersions = Get-Content -LiteralPath (Join-Path $ResourceRoot '.release-please-manifest.json') -Raw | ConvertFrom-Json -AsHashtable
$ReleaseConfig = Get-Content -LiteralPath (Join-Path $ResourceRoot 'release-please-config.json') -Raw | ConvertFrom-Json -AsHashtable
if ($ReleaseVersions.Count -eq 0) {
    if ($ReleaseConfig['packages']['.']['initial-version'] -ne $Version) { throw 'Empty release manifest requires the configured initial version.' }
} elseif ($ReleaseVersions['.'] -ne $Version) { throw 'Release manifest must match the resource version.' }
if ($SourceVersion -ne $Version) { throw 'version.txt must match the resource version.' }

$OriginalLicenseHash = '605e9047a563c5c8396ffb18232aa4304ec56586aee537c45064c6fb425e44ad'
$LicenseHash = (Get-FileHash -LiteralPath (Join-Path $ResourceRoot 'LICENSE') -Algorithm SHA256).Hash.ToLowerInvariant()
if ($LicenseHash -ne $OriginalLicenseHash) { throw 'Original license changed.' }

if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $OutFile = Join-Path $ResourceRoot ('release/concept_bridge-{0}.zip' -f $Version)
}
$ArchivePath = [IO.Path]::GetFullPath($OutFile)
New-Item -ItemType Directory -Path (Split-Path -Parent $ArchivePath) -Force | Out-Null

$TempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char[]]@('\', '/'))
$StagePath = Join-Path $TempRoot ('concept_bridge_release_' + [Guid]::NewGuid().ToString('N'))
$StagedResource = Join-Path $StagePath 'concept_bridge'
New-Item -ItemType Directory -Path $StagedResource | Out-Null

function Copy-ReleaseTree([string]$Source, [string]$Destination) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    foreach ($Item in Get-ChildItem -LiteralPath $Source -Force) {
        if ($Item.Name -in @('node_modules', '__pycache__', '.git', '.DS_Store')) { continue }
        if ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Unexpected source symlink: $($Item.FullName)" }
        $Target = Join-Path $Destination $Item.Name
        if ($Item.PSIsContainer) { Copy-ReleaseTree $Item.FullName $Target }
        elseif ($Item.Extension -notin @('.log', '.pyc')) { Copy-Item -LiteralPath $Item.FullName -Destination $Target }
    }
}

try {
    foreach ($Name in @('fxmanifest.lua', 'init.lua', 'LICENSE', 'ORIGIN.Md', 'README.md', 'CONTRIBUTING.md', 'CHANGELOG.md', 'version.txt', 'release-please-config.json', '.release-please-manifest.json')) {
        $InputPath = Join-Path $ResourceRoot $Name
        if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) { throw "Package input missing: $Name" }
        Copy-Item -LiteralPath $InputPath -Destination $StagedResource
    }
    # Include editable Lua source, packaging tooling and tests.
    # node_modules and local metadata/logs are excluded; GPL license/credits ship.
    foreach ($Name in @('lib', 'modules', 'locales', 'settings', 'tools', 'test')) {
        $InputPath = Join-Path $ResourceRoot $Name
        if (-not (Test-Path -LiteralPath $InputPath -PathType Container)) { throw "Package directory missing: $Name" }
        Copy-ReleaseTree $InputPath (Join-Path $StagedResource $Name)
    }

    if (Test-Path -LiteralPath $ArchivePath) { Remove-Item -LiteralPath $ArchivePath }
    $Archive = [IO.Compression.ZipFile]::Open($ArchivePath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($File in Get-ChildItem -LiteralPath $StagedResource -Recurse -File -Force) {
            $Relative = $File.FullName.Substring($StagePath.Length + 1).Replace('\', '/')
            $Entry = $Archive.CreateEntry($Relative, [IO.Compression.CompressionLevel]::Optimal)
            $EntryStream = $Entry.Open()
            try {
                $FileStream = [IO.File]::OpenRead($File.FullName)
                try { $FileStream.CopyTo($EntryStream) } finally { $FileStream.Dispose() }
            } finally { $EntryStream.Dispose() }
        }
    } finally { $Archive.Dispose() }

    $Archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        $Names = @($Archive.Entries.FullName)
        foreach ($Required in @('fxmanifest.lua', 'init.lua', 'LICENSE', 'ORIGIN.Md', 'CHANGELOG.md', 'tools/package-release.ps1', 'version.txt', 'release-please-config.json', '.release-please-manifest.json')) {
            if ($Names -notcontains ('concept_bridge/' + $Required)) { throw "Archive entry missing: $Required" }
        }
        foreach ($Name in $Names) {
            if (-not $Name.StartsWith('concept_bridge/') -or $Name.Contains('\') -or $Name -match '/(node_modules|__pycache__|\.git|review|web)/|/modules/dialogue/' -or $Name -cmatch '/(Attributions\.md|ORIGIN\.md|KNOWN_LIMITATIONS\.md|check_identity\.py|package_resource\.py)$') {
                throw "Unexpected archive entry: $Name"
            }
        }
        $LicenseStream = $Archive.GetEntry('concept_bridge/LICENSE').Open()
        try {
            $SHA = [Security.Cryptography.SHA256]::Create()
            try { $ArchivedHash = ([BitConverter]::ToString($SHA.ComputeHash($LicenseStream))).Replace('-', '').ToLowerInvariant() }
            finally { $SHA.Dispose() }
        } finally { $LicenseStream.Dispose() }
        if ($ArchivedHash -ne $LicenseHash) { throw 'Packaged license differs from source.' }
    } finally { $Archive.Dispose() }
} finally {
    $ResolvedStage = [IO.Path]::GetFullPath($StagePath)
    if ([IO.Path]::GetDirectoryName($ResolvedStage) -ne $TempRoot -or [IO.Path]::GetFileName($ResolvedStage) -notmatch '^concept_bridge_release_[a-f0-9]{32}$') {
        throw 'Unexpected temporary staging path; cleanup refused.'
    }
    Remove-Item -LiteralPath $ResolvedStage -Recurse -Force
}

Write-Output ('Release ZIP verified: {0} entries; {1}' -f $Names.Count, $ArchivePath)
Write-Output ('Version: {0}; root: concept_bridge/; complete source, original GPL license and credits included.' -f $Version)
