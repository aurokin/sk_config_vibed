Param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$ProfileName,

  [Parameter(Mandatory = $false, Position = 1)]
  [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'

function Get-NotePropertiesHashtable {
  param(
    [Parameter(Mandatory = $false)] $Object
  )
  $result = @{}
  if ($null -eq $Object) { return $result }
  if ($Object -is [hashtable]) { return $Object }
  foreach ($p in $Object.PSObject.Properties) {
    if ($p.MemberType -eq 'NoteProperty') {
      $result[$p.Name] = if ($null -eq $p.Value) { '' } else { [string]$p.Value }
    }
  }
  return $result
}

function Update-IniFileLines {
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

    $exactPattern = '^[\s;#]*' + [regex]::Escape($key) + '\s*='
    $partialPattern = [regex]::Escape($key)

    $index = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match $exactPattern) { $index = $i; break }
    }

    if ($index -eq -1) {
      for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $partialPattern) { $index = $i; break }
      }
    }

    if ($index -ge 0) {
      if ($lines[$index] -ne $newLine) {
        $lines[$index] = $newLine
        $changed = $true
      }
    } else {
      $lines += $newLine
      $changed = $true
    }
  }

  if ($changed) {
    Set-Content -Path $Path -Value $lines -Encoding UTF8
    Write-Host "Updated: $Path"
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
  $json = $jsonRaw | ConvertFrom-Json

  $profileData = $null
  if ($null -ne $json.PSObject.Properties['profiles']) {
    $profileData = $json.profiles.PSObject.Properties[$ProfileName].Value
  } elseif ($null -ne $json.PSObject.Properties[$ProfileName]) {
    $profileData = $json.PSObject.Properties[$ProfileName].Value
  }

  if ($null -eq $profileData) {
    throw "Profile '$ProfileName' not found in $ConfigPath"
  }

  $basePath = Join-Path $env:LOCALAPPDATA 'Programs\Special K'
  $globalIni = Join-Path $basePath 'Global\osd.ini'
  $profilesRoot = Join-Path $basePath 'Profiles'

  $globalSection = $null
  if ($null -ne $profileData.PSObject.Properties['global']) { $globalSection = $profileData.global }
  $profileSection = $null
  if ($null -ne $profileData.PSObject.Properties['profile']) { $profileSection = $profileData.profile }

  $globalPairs = Get-NotePropertiesHashtable -Object $globalSection
  if ($globalPairs.Count -gt 0) {
    Update-IniFileLines -Path $globalIni -KeyValues $globalPairs
  }

  $profilePairs = Get-NotePropertiesHashtable -Object $profileSection
  $profileFolder = $null
  if ($null -ne $profileData.PSObject.Properties['profileFolder']) {
    $profileFolder = [string]$profileData.profileFolder
  } elseif ($null -ne $profileSection -and $null -ne $profileSection.PSObject.Properties['folder']) {
    $profileFolder = [string]$profileSection.folder
    if ($profilePairs.ContainsKey('folder')) { $profilePairs.Remove('folder') }
  } else {
    $profileFolder = $ProfileName
  }

  if ($profilePairs.Count -gt 0) {
    $profileIni = Join-Path (Join-Path $profilesRoot $profileFolder) 'SpecialK.ini'
    Update-IniFileLines -Path $profileIni -KeyValues $profilePairs
  }

  Write-Host "Done."
} catch {
  Write-Error $_
  exit 1
}
