# SK Config Helper 🎮⚙️

A tiny PowerShell script that updates Special K INI settings from a JSON profile. Point it at a profile name and it will write matching key/value pairs into your Global `osd.ini` and any `SpecialK.ini` it finds under your Profiles folder.

## ✨ What It Does
- Reads `config.json` and selects a profile by name.
- Updates or appends matching INI lines by key (exact or partial match).
- Targets:
  - `%LOCALAPPDATA%\\Programs\\Special K\\Global\\osd.ini`
  - `%LOCALAPPDATA%\\Programs\\Special K\\Profiles\\**\\SpecialK.ini`

## 📦 Requirements
- Windows with Special K installed
- PowerShell 7+ (`pwsh`) recommended

## 🚀 Quick Start
1) Copy the example and edit values:
   `cp config.example.json config.json`
2) Dry-run first (no changes):
   `pwsh -File sk_config.ps1 240hz_vrr -WhatIf -Verbose`
3) Apply changes:
   `pwsh -File sk_config.ps1 240hz_vrr`

Use a custom config path with `-ConfigPath`:
`pwsh -File sk_config.ps1 144hz_vrr -ConfigPath .\\myconfig.json -Verbose`

## 🧰 Config Format
See `config.example.json` for a full example. Each top-level property is a profile name. Profiles contain two arrays of key/value pairs:

```json
{
  "240hz_vrr": {
    "global": [
      { "key": "FontScale", "value": "1.0" }
    ],
    "profile": [
      { "key": "TargetFPS", "value": "222.872238" },
      { "key": "LimitEnforcementPolicy", "value": "4" }
    ]
  },
  "144hz_vrr": {
    "global": [
      { "key": "FontScale", "value": "1.5" }
    ],
    "profile": [
      { "key": "TargetFPS", "value": "137.000000" },
      { "key": "LimitEnforcementPolicy", "value": "4" }
    ]
  }
}
```

## 🔑 Key Explanations
- FontScale: UI font scale for Special K OSD; stringified float (e.g., "1.0", "1.5").
- TargetFPS: Desired frame cap for the profile; stringified float (e.g., "137.000000").
- LimitEnforcementPolicy: How strictly the limiter is enforced; integer-like string (e.g., "2", "4").

Values are written exactly as strings into INI lines like `Key=Value`.

## 🛡️ Tips & Troubleshooting
- Always start with `-WhatIf` to preview changes.
- If you see "Profile '<name>' not found": check your `config.json` profile names.
- If you see "No 'SpecialK.ini' files found": confirm your Special K install path and profiles.
- Backup your INIs before large changes.

Enjoy smoother profiles! 🕹️💨

