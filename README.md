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
1) Copy the example and edit values (the script reads `config.json` next to the script by default):
   `cp config.example.json config.json`
2) Dry-run first (no changes):
   `pwsh -File sk_config.ps1 240hz_vrr -WhatIf -Verbose`
3) Apply changes:
   `pwsh -File sk_config.ps1 240hz_vrr`

Use a custom config path with `-ConfigPath` (overrides the default script-directory lookup):
`pwsh -File sk_config.ps1 144hz_vrr -ConfigPath .\\myconfig.json -Verbose`

Enable Apollo integrations (env overrides and dynamic profile):
`pwsh -File sk_config.ps1 240hz_vrr -apollo -Verbose`

## 🧰 Config Format
See `config.example.json` for a full example. Each top-level property is a profile name. Profiles contain two arrays of key/value pairs:

```json
{
  "240hz_vrr": {
    "global": [{ "key": "FontScale", "value": "1.0" }],
    "profile": [
      { "key": "TargetFPS", "value": "222.872238" },
      { "key": "LimitEnforcementPolicy", "value": "4" }
    ]
  },
  "144hz_vrr": {
    "global": [{ "key": "FontScale", "value": "1.5" }],
    "profile": [
      { "key": "TargetFPS", "value": "137.000000" },
      { "key": "LimitEnforcementPolicy", "value": "4" }
    ]
  },
  "apollo_5A900E30-EDB2-6C28-770D-BB4AEE67B196": {
    "global": [{ "key": "FontScale", "value": "2.0" }],
    "profile": [
      { "key": "TargetFPS", "value": "120.000000" },
      { "key": "LimitEnforcementPolicy", "value": "2" }
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

## 🌐 Apollo Mode (Environment Overrides)
For runtime-controlled FPS caps, Apollo integrations are now opt-in and gated by the `-apollo` switch.

- `APOLLO_CLIENT_FPS` → `$apolloFPS`: When set, this value replaces any `TargetFPS` from `config.json`.
- `APOLLO_APP_STATUS` → `$apolloStatus`: When set to `TERMINATING` (case-insensitive), the override is disabled to avoid last‑minute changes.

Behavior
- When `-apollo` is supplied and `APOLLO_CLIENT_FPS` is set and `APOLLO_APP_STATUS` is not `TERMINATING`, `TargetFPS` is written using `APOLLO_CLIENT_FPS`.
- Applies to both Global `osd.ini` and all `SpecialK.ini` files under Profiles.

Examples
- Windows (PowerShell):
  - ``$env:APOLLO_CLIENT_FPS='240'; $env:APOLLO_APP_STATUS='RUNNING'; pwsh -File sk_config.ps1 240hz_vrr -apollo -Verbose``
- Cross-platform (pwsh/macOS/Linux):
  - ``APOLLO_CLIENT_FPS=144 APOLLO_APP_STATUS=RUNNING pwsh -File sk_config.ps1 144hz_vrr -apollo -Verbose``

Notes
- Apollo overrides do not occur unless `-apollo` is passed.
- If `APOLLO_CLIENT_FPS` is unset or empty, no override occurs.
- If `APOLLO_APP_STATUS` is `TERMINATING`, no override occurs even if `APOLLO_CLIENT_FPS` is set.
- `-Verbose` logs show the final value processed for `TargetFPS` after any override.
- You must pass a profile name even with device profiles. The positional `ProfileName` argument is required for the script to run and also serves as the default/fallback profile if an `apollo_<UUID>` profile is not found.

## 🔁 Dynamic Apollo Profile
Some orchestrations provide a per-device UUID. With `-apollo`, the script can automatically select a device-specific profile without changing your invocation.

- UUID variable: `APOLLO_CLIENT_UUID` → `$apolloUUID`

Behavior
- When `-apollo` is supplied and `APOLLO_CLIENT_UUID` is set, the script will prefer a profile named `apollo_<UUID>` if it exists in `config.json`. If found, it overrides the provided `ProfileName`.
- Example: if `APOLLO_CLIENT_UUID=5A900E30-EDB2-6C28-770D-BB4AEE67B196` and `config.json` contains `"apollo_5A900E30-EDB2-6C28-770D-BB4AEE67B196"`, that profile is selected even if you invoked `240hz_vrr`.

Usage Examples
- Windows (PowerShell):
  - ``$env:APOLLO_CLIENT_UUID='5A900E30-EDB2-6C28-770D-BB4AEE67B196'; pwsh -File sk_config.ps1 240hz_vrr -apollo -Verbose``
- Cross-platform (pwsh/macOS/Linux):
  - ``APOLLO_CLIENT_UUID=5A900E30-EDB2-6C28-770D-BB4AEE67B196 pwsh -File sk_config.ps1 144hz_vrr -apollo``

Notes
- Ensure your `config.json` contains a matching per-device profile key like `"apollo_<UUID>"`.
- If `APOLLO_CLIENT_UUID` is not set or no matching profile exists, the originally provided `ProfileName` is used.
- Default profile required: When using `-apollo`, keep at least one non-device default profile to fall back to. You will always need at minimum one more profile than the number of device-specific `apollo_<UUID>` profiles you have.
