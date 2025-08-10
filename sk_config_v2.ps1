[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
Param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$ProfileName,

  [Parameter(Mandatory = $false, Position = 1)]
  [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'

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
      $map[$k] = $v
    }
  }
  return $map
}

[CmdletBinding(SupportsShouldProcess = $true)]
function Update-IniFileByPartialKey {
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
        Write-Verbose "Replacing line $index: '$($lines[$index])' -> '$newLine'"
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
    $ConfigPath = Join-Path -Path (Get-Location) -ChildPath 'config.json'
  }
  if (-not (Test-Path -Path $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
  }

  $jsonRaw = Get-Content -Path $ConfigPath -Raw
  $config = $jsonRaw | ConvertFrom-Json

  $profileNode = $config.PSObject.Properties[$ProfileName].Value
  if ($null -eq $profileNode) {
    throw "Profile '$ProfileName' not found in $ConfigPath"
  }

  $globalPairs = Convert-ToHashtableFromArray -Array $profileNode.global
  $profilePairs = Convert-ToHashtableFromArray -Array $profileNode.profile

  $basePath = Join-Path $env:LOCALAPPDATA 'Programs\Special K'
  $globalIni = Join-Path $basePath 'Global\osd.ini'
  $profilesRoot = Join-Path $basePath 'Profiles'
  $profileIni = Join-Path (Join-Path $profilesRoot $ProfileName) 'SpecialK.ini'

  Write-Verbose "Base path: $basePath"
  Write-Verbose "Global INI: $globalIni"
  Write-Verbose "Profile INI: $profileIni"

  if ($globalPairs.Count -gt 0) {
    Update-IniFileByPartialKey -Path $globalIni -KeyValues $globalPairs -Verbose:$VerbosePreference -WhatIf:$WhatIfPreference
  } else {
    Write-Host "No global settings for '$ProfileName'"
  }

  if ($profilePairs.Count -gt 0) {
    Update-IniFileByPartialKey -Path $profileIni -KeyValues $profilePairs -Verbose:$VerbosePreference -WhatIf:$WhatIfPreference
  } else {
    Write-Host "No profile settings for '$ProfileName'"
  }

  Write-Host "Done."
} catch {
  Write-Error $_
  exit 1
}
