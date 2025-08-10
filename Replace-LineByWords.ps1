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

Additionally supports a profile-driven mode using a local JSON file
(default ./config.json). Provide -Profile to load key/value pairs from
config and replace lines that start with each key, writing them using a
template (default "{key}={value}"). Global and profile blocks are applied.

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

.PARAMETER Profile
Apply settings from the named profile in the JSON config.

.PARAMETER ConfigPath
Path to the JSON config file. Default: ./config.json

.PARAMETER Template
Output format for each key/value pair when using -Profile. Use {key} and {value} placeholders. Default: {key}={value}

.PARAMETER SkipGlobal
Skip applying the "global" entries from the profile block.

.EXAMPLE
PS> ./Replace-LineByWords.ps1 -Path ./app.config -Words "server", "port" -Replacement "server=example;port=443"
Replaces the first line that contains both "server" and "port" (case-insensitive).

.EXAMPLE
PS> ./Replace-LineByWords.ps1 -Path ./notes.txt -Words "todo" -AnyWord -ReplaceAll -Replacement "TODO: handled"
Replaces all lines that contain the word "todo" (case-insensitive).

.EXAMPLE
PS> ./Replace-LineByWords.ps1 -Path ./file.txt -Words "Exact", "Case" -CaseSensitive -Backup -WhatIf -Replacement "Exact Case Line"
Shows what would change (no write) with case-sensitive matching and creates a backup when run without -WhatIf.

.EXAMPLE
PS> ./Replace-LineByWords.ps1 -Path ./app.config -Profile 240hz_vrr
Reads ./config.json and applies both global and 240hz_vrr entries, replacing lines that start with each key using "{key}={value}" formatting.

.EXAMPLE
PS> ./Replace-LineByWords.ps1 -Path ./app.config -Profile 120hz_stream -Template '{key}: {value}' -ConfigPath './config.json'
Uses a custom output template and explicit config path.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [Parameter(Mandatory = $false, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Words,

    [Parameter(Mandatory = $false, Position = 2)]
    [string]$Replacement,

    [switch]$AnyWord,
    [switch]$ReplaceAll,
    [switch]$CaseSensitive,
    [switch]$Backup,
    [string]$BackupSuffix = '.bak',
    [ValidateSet('utf8','utf8BOM','ascii','unicode','bigendianunicode','utf7','utf32','default','oem')]
    [string]$Encoding = 'utf8',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Profile,

    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = './config.json',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Template = '{key}={value}',

    [switch]$SkipGlobal
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

    # Validate parameter combination
    $usingProfile = $PSBoundParameters.ContainsKey('Profile') -and $null -ne $Profile -and $Profile -ne ''
    $usingWords = $PSBoundParameters.ContainsKey('Words') -and $PSBoundParameters.ContainsKey('Replacement')

    if (-not $usingProfile -and -not $usingWords) {
        throw 'Provide either -Profile or both -Words and -Replacement.'
    }

    if ($usingProfile -and $usingWords) {
        Write-Warning 'Both -Profile and -Words/-Replacement were provided. The script will use -Profile mode and ignore -Words/-Replacement.'
    }
}

process {
    $lines = Get-Content -LiteralPath $Path

    if ($lines.Count -eq 0 -and -not (Get-Item -LiteralPath $Path).Length) {
        Write-Verbose "File is empty: $Path"
    }

    if ($usingProfile) {
        if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
            throw "Config file not found: $ConfigPath"
        }

        $rawJson = Get-Content -LiteralPath $ConfigPath -Raw
        try { $config = $rawJson | ConvertFrom-Json } catch { throw "Failed to parse JSON from $ConfigPath: $($_.Exception.Message)" }

        $profileBlock = $config.PSObject.Properties[$Profile].Value
        if ($null -eq $profileBlock) {
            throw "Profile '$Profile' not found in $ConfigPath"
        }

        $entries = @()
        if (-not $SkipGlobal -and $profileBlock.PSObject.Properties.Name -contains 'global' -and $profileBlock.global) {
            $entries += $profileBlock.global
        }
        if ($profileBlock.PSObject.Properties.Name -contains 'profile' -and $profileBlock.profile) {
            $entries += $profileBlock.profile
        }

        if (-not $entries -or $entries.Count -eq 0) {
            Write-Verbose "No entries to apply for profile '$Profile'"
            return
        }

        $caseFlag = if ($CaseSensitive) { '' } else { '(?i)' }
        $replaced = 0
        $indices = New-Object System.Collections.Generic.List[int]

        foreach ($e in $entries) {
            $k = [regex]::Escape([string]$e.key)
            $v = [string]$e.value
            $pattern = "^$caseFlag\s*$k\b.*$"

            $idx = -1
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ([regex]::IsMatch($lines[$i], $pattern)) { $idx = $i; break }
            }

            if ($idx -ge 0) {
                $rendered = $Template.Replace('{key}', [string]$e.key).Replace('{value}', $v)
                $lines[$idx] = $rendered
                $replaced++
                $indices.Add($idx) | Out-Null
            } else {
                Write-Verbose "No line found starting with key '$($e.key)'"
            }
        }

        if ($replaced -eq 0) {
            Write-Verbose "No matching lines replaced for profile '$Profile'"
            return
        }

        $targetDesc = "apply profile '$Profile' ($replaced replacement(s))"
        if ($PSCmdlet.ShouldProcess($Path, $targetDesc)) {
            if ($Backup) {
                $backupPath = "$Path$BackupSuffix"
                Copy-Item -LiteralPath $Path -Destination $backupPath -Force
                Write-Verbose "Backup written to: $backupPath"
            }

            Set-Content -LiteralPath $Path -Value $lines -Encoding $Encoding

            [pscustomobject]@{
                Path          = (Resolve-Path -LiteralPath $Path).Path
                Profile       = $Profile
                ReplacedCount = $replaced
                Indices       = @($indices)
                CaseSensitive = [bool]$CaseSensitive
            }
        }
    }
    else {
        # Find matching line indices (Words/Replacement mode)
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
}

end {}
