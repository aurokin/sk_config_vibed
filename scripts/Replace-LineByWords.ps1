<#!
.SYNOPSIS
Replaces a line in a text file when it matches one or more words.

.DESCRIPTION
Reads a file line-by-line, finds lines that contain the specified words
and replaces the entire line with the provided replacement text.

Defaults to requiring all words to be present in a line. Use -AnyWord to
match if any of the words are present. By default only the first matching
line is replaced; use -ReplaceAll to replace all matching lines.

Supports -WhatIf/-Confirm, optional backup creation, and configurable encoding.

.PARAMETER Path
Path to the text file to modify.

.PARAMETER Words
One or more words to search for in each line.

.PARAMETER Replacement
The full replacement text for matched line(s).

.PARAMETER AnyWord
Match a line if any one of the words is present. Default is all words.

.PARAMETER ReplaceAll
Replace all matching lines. Default replaces only the first match.

.PARAMETER CaseSensitive
Use case-sensitive matching. Default is case-insensitive.

.PARAMETER Backup
Create a backup copy of the file before modifying.

.PARAMETER BackupSuffix
Suffix appended to the original filename for the backup. Default: .bak

.PARAMETER Encoding
Text encoding used when writing the file. Default: utf8
Allowed: utf8, utf8BOM, ascii, unicode, bigendianunicode, utf7, utf32, default, oem

.EXAMPLE
PS> ./Replace-LineByWords.ps1 -Path ./app.config -Words "server", "port" -Replacement "server=example;port=443"
Replaces the first line that contains both "server" and "port" (case-insensitive).

.EXAMPLE
PS> ./Replace-LineByWords.ps1 -Path ./notes.txt -Words "todo" -AnyWord -ReplaceAll -Replacement "TODO: handled"
Replaces all lines that contain the word "todo" (case-insensitive).

.EXAMPLE
PS> ./Replace-LineByWords.ps1 -Path ./file.txt -Words "Exact", "Case" -CaseSensitive -Backup -WhatIf -Replacement "Exact Case Line"
Shows what would change (no write) with case-sensitive matching and creates a backup when run without -WhatIf.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Words,

    [Parameter(Mandatory = $true, Position = 2)]
    [string]$Replacement,

    [switch]$AnyWord,
    [switch]$ReplaceAll,
    [switch]$CaseSensitive,
    [switch]$Backup,
    [string]$BackupSuffix = '.bak',
    [ValidateSet('utf8','utf8BOM','ascii','unicode','bigendianunicode','utf7','utf32','default','oem')]
    [string]$Encoding = 'utf8'
)

begin {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "File not found: $Path"
    }

    # Choose string comparison mode (avoids wildcard pitfalls)
    $StringComparison = if ($CaseSensitive) {
        [System.StringComparison]::Ordinal
    } else {
        [System.StringComparison]::OrdinalIgnoreCase
    }
}

process {
    $lines = Get-Content -LiteralPath $Path

    if ($lines.Count -eq 0 -and -not (Get-Item -LiteralPath $Path).Length) {
        Write-Verbose "File is empty: $Path"
    }

    # Find matching line indices
    $matchIndices = New-Object System.Collections.Generic.List[int]
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # Determine matches for each word using .IndexOf with selected comparison
        $wordMatches = foreach ($w in $Words) {
            if ($null -eq $w) { $false } else { $line.IndexOf($w, $StringComparison) -ge 0 }
        }

        $isMatch = if ($AnyWord) {
            $wordMatches -contains $true
        } else {
            -not ($wordMatches -contains $false)
        }

        if ($isMatch) {
            $matchIndices.Add($i) | Out-Null
            if (-not $ReplaceAll) { break }
        }
    }

    if ($matchIndices.Count -eq 0) {
        Write-Verbose "No matching lines found in: $Path"
        return
    }

    $targetDesc = if ($ReplaceAll) { "replace $($matchIndices.Count) matching line(s)" } else { "replace line #$($matchIndices[0])" }
    if ($PSCmdlet.ShouldProcess($Path, $targetDesc)) {
        if ($Backup) {
            $backupPath = "$Path$BackupSuffix"
            Copy-Item -LiteralPath $Path -Destination $backupPath -Force
            Write-Verbose "Backup written to: $backupPath"
        }

        foreach ($idx in $matchIndices) {
            $lines[$idx] = $Replacement
        }

        Set-Content -LiteralPath $Path -Value $lines -Encoding $Encoding

        # Emit a small object with details
        [pscustomobject]@{
            Path          = (Resolve-Path -LiteralPath $Path).Path
            ReplacedCount = $matchIndices.Count
            Indices       = @($matchIndices)
            AnyWord       = [bool]$AnyWord
            CaseSensitive = [bool]$CaseSensitive
        }
    }
}

end {}

