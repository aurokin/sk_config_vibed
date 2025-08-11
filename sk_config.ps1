[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
Param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$ProfileName,

  [Parameter(Mandatory = $false, Position = 1)]
  [string]$ConfigPath,

  [Parameter(Mandatory = $false)]
  [switch]$apollo
)

$ErrorActionPreference = 'Stop'

# Apollo Integration
$apolloFPS = $env:APOLLO_CLIENT_FPS
$apolloStatus = $env:APOLLO_APP_STATUS
$apolloUUID = $env:APOLLO_CLIENT_UUID

function Convert-ToHashtableFromArray {
  param(
    [Parameter(Mandatory = $true)] $Array
  )
  $map = @{}
  if ($null -eq $Array) { return $map }
  foreach ($item in $Array) {
    if ($null -ne $item -and $item.PSObject.Properties.Name -contains 'key') {
      $k = [string]$item.key
      $v = if ($item.PSObject.Properties.Name -contains 'value') { [string]$item.value } else { '' }
      if ($apollo -and $k -eq "TargetFPS" -and $apolloFPS -ne $null -and $apolloStatus -ne 'TERMINATING') {
        $v = $apolloFPS
      }
      $map[$k] = $v
    }
  }
  return $map
}

function Update-IniFileByPartialKey {
    [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][hashtable]$KeyValues
  )

  if (-not (Test-Path -Path $Path)) {
    Write-Error "File not found: $Path"
    return
  }

  $lines = Get-Content -Path $Path
  $changed = $false

  foreach ($key in $KeyValues.Keys) {
    $value = $KeyValues[$key]
    $newLine = "$key=$value"
    Write-Verbose "Processing key '$key' with value '$value' in '$Path'"
    $exactPattern = '^[\s;#]*' + [regex]::Escape($key) + '\s*='
    $partialPattern = [regex]::Escape($key)

    $index = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -imatch $exactPattern) { $index = $i; break }
    }

    if ($index -eq -1) {
      for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -imatch $partialPattern) { $index = $i; break }
      }
    }

    if ($index -ge 0) {
      if ($lines[$index] -ne $newLine) {
        Write-Verbose "Replacing line $index : '$($lines[$index])' -> '$newLine'"
        $lines[$index] = $newLine
        $changed = $true
      } else {
        Write-Verbose "Line $index already matches '$newLine'"
      }
    } else {
      Write-Verbose "Appending new line: '$newLine'"
      $lines += $newLine
      $changed = $true
    }
  }

  if ($changed) {
    if ($PSCmdlet.ShouldProcess($Path, "Write updated content")) {
      if ($WhatIfPreference) {
        Write-Host "What if: Would update: $Path"
      } else {
        Set-Content -Path $Path -Value $lines -Encoding UTF8
        Write-Host "Updated: $Path"
      }
    }
  } else {
    Write-Host "No changes needed: $Path"
  }
}

try {
  if (-not $PSBoundParameters.ContainsKey('ConfigPath') -or [string]::IsNullOrWhiteSpace($ConfigPath)) {
    # Resolve default config next to the script location, not the current directory
    $scriptDir = if ($PSScriptRoot) {
      $PSScriptRoot
    } elseif ($PSCommandPath) {
      Split-Path -Parent $PSCommandPath
    } else {
      Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    $ConfigPath = Join-Path -Path $scriptDir -ChildPath 'config.json'
  }
  if (-not (Test-Path -Path $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
  }

  $jsonRaw = Get-Content -Path $ConfigPath -Raw
  $config = $jsonRaw | ConvertFrom-Json

  if ($apollo -and $apolloUUID -ne $null) {
    $apolloProfileName = "apollo_$apolloUUID"
    $testNode = $config.PSObject.Properties[$apolloProfileName]
    if ($null -ne $testNode) { $ProfileName = $apolloProfileName }
  }

  $profileNode = $config.PSObject.Properties[$ProfileName].Value
  if ($null -eq $profileNode) {
    throw "Profile '$ProfileName' not found in $ConfigPath"
  }

  $globalPairs = Convert-ToHashtableFromArray -Array $profileNode.global
  $profilePairs = Convert-ToHashtableFromArray -Array $profileNode.profile

  $basePath = Join-Path $env:LOCALAPPDATA 'Programs\Special K'
  $globalIni = Join-Path $basePath 'Global\osd.ini'
  $profilesRoot = Join-Path $basePath 'Profiles'

  Write-Verbose "Base path: $basePath"
  Write-Verbose "Global INI: $globalIni"
  Write-Verbose "Profiles root: $profilesRoot"

  if ($globalPairs.Count -gt 0) {
    Update-IniFileByPartialKey -Path $globalIni -KeyValues $globalPairs -Verbose:$VerbosePreference -WhatIf:$WhatIfPreference
  } else {
    Write-Host "No global settings for '$ProfileName'"
  }

  if ($profilePairs.Count -gt 0) {
    $profileIniFiles = @()
    if (Test-Path -Path $profilesRoot) {
      $profileIniFiles = Get-ChildItem -Path $profilesRoot -Filter 'SpecialK.ini' -Recurse -File | Select-Object -ExpandProperty FullName
    }
    if ($profileIniFiles.Count -eq 0) {
      Write-Host "No 'SpecialK.ini' files found under: $profilesRoot"
    } else {
      foreach ($iniPath in $profileIniFiles) {
        Write-Verbose "Updating profile INI: $iniPath"
        Update-IniFileByPartialKey -Path $iniPath -KeyValues $profilePairs -Verbose:$VerbosePreference -WhatIf:$WhatIfPreference
      }
    }
  } else {
    Write-Host "No profile settings for '$ProfileName'"
  }

  Write-Host "Done."
} catch {
  Write-Error $_
  exit 1
}
