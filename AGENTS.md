# Repository Guidelines

## Project Structure & Module Organization
- Root script: `sk_config.ps1` (PowerShell).
- Local config (ignored): `config.json` alongside the script.
- No external assets or test suite. Git tracks only the script and `.gitignore`.

## Build, Test, and Development Commands
- Run (PowerShell 7+): `pwsh -File sk_config.ps1 <ProfileName> [-ConfigPath <path>] [-apollo]`
- Dry run: add `-WhatIf` to preview writes; add `-Verbose` for detailed logs.
- Windows example: `pwsh -File sk_config.ps1 240hz_vrr -ConfigPath .\\config.json -WhatIf -Verbose`
- Default config path: `./config.json` if `-ConfigPath` not provided.

## Coding Style & Naming Conventions
- Language: PowerShell. Indentation: 4 spaces; UTF-8 encoding.
- Functions: Verb-Noun PascalCase (e.g., `Update-IniFileByPartialKey`).
- Parameters/variables: camelCase where practical; avoid abbreviations.
- Prefer explicit typing (e.g., `[string]`, `[hashtable]`) and `CmdletBinding`.
- Optional tooling: PSScriptAnalyzer (`Invoke-ScriptAnalyzer .`) for linting.

## Testing Guidelines
- No unit tests. Validate changes with `-WhatIf` and `-Verbose`.
- Create a minimal `config.json` locally (not committed):
  `{ "240hz_vrr": { "global": [{"key":"FontScale","value":"1.0"}], "profile": [{"key":"TargetFPS","value":"222.872238"},{"key":"LimitEnforcementPolicy","value":"4"}] } }`
- Verify expected targets exist:
  `%LOCALAPPDATA%\\Programs\\Special K\\Global\\osd.ini` and `...\\Profiles\\**\\SpecialK.ini`.

## Commit & Pull Request Guidelines
- Commits: concise, imperative mood (e.g., "Update INI write logic").
- Scope prefixes optional; keep one change per commit when possible.
- PRs must include:
  - Summary of changes and rationale.
  - Reproduction/validation steps (commands used, sample config).
  - Screenshots or `-Verbose` output when helpful.
  - Linked issues (e.g., `Fixes #12`) if applicable.

## Security & Configuration Tips
- Do not commit `config.json` (ignored by `.gitignore`). Consider attaching a redacted snippet in PRs when needed.
- Use `-WhatIf` before running on real profiles to prevent accidental edits.
- The script edits INI files under `%LOCALAPPDATA%\\Programs\\Special K`; ensure you have backups or versioned copies.

## Apollo Environment Overrides
- Purpose: Allow external orchestration to dynamically override `TargetFPS` without changing `config.json`.
- Gating: Apollo behavior is opt-in via the `-apollo` switch.
- Variables:
  - `$apolloFPS` (from env `APOLLO_CLIENT_FPS`): When set, replaces any `TargetFPS` value being written.
  - `$apolloStatus` (from env `APOLLO_APP_STATUS`): Guards overrides; when status is `TERMINATING` (case-insensitive), the override is skipped.
- Behavior:
  - When `-apollo` is supplied and `APOLLO_CLIENT_FPS` is set and status is not `TERMINATING`, the script writes `$apolloFPS` for `TargetFPS`.
  - Applies to both Global `osd.ini` and per-profile `SpecialK.ini` writes.
- Examples:
  - Windows (PowerShell): ``$env:APOLLO_CLIENT_FPS='240'; $env:APOLLO_APP_STATUS='RUNNING'; pwsh -File sk_config.ps1 240hz_vrr -apollo -Verbose``
  - Cross-platform (pwsh): ``APOLLO_CLIENT_FPS=144 APOLLO_APP_STATUS=RUNNING pwsh -File sk_config.ps1 144hz_vrr -apollo``
- Notes:
  - Overrides do not occur unless `-apollo` is used.
  - If `APOLLO_CLIENT_FPS` is unset or empty, no override occurs.
  - If `APOLLO_APP_STATUS` is `TERMINATING`, no override occurs even if `APOLLO_CLIENT_FPS` is set.
  - `-Verbose` will show the processed value for `TargetFPS` after any override.

## Apollo Dynamic Profile
- Purpose: Allow per-device profile selection using a UUID supplied by Apollo without changing invocation.
- Gating: Requires the `-apollo` switch.
- Variables:
  - `$apolloUUID` (from env `APOLLO_CLIENT_UUID`): Device identifier appended to `apollo_`.
- Behavior:
  - When `-apollo` is supplied and `$apolloUUID` is set, the script prefers a matching `apollo_<UUID>` profile from `config.json`; if present, it overrides the provided `ProfileName`.
  - Users must define matching keys in `config.json` (e.g., `"apollo_<UUID>"`).
- Examples:
  - Windows (PowerShell): ``$env:APOLLO_CLIENT_UUID='5A900E30-EDB2-6C28-770D-BB4AEE67B196'; pwsh -File sk_config.ps1 240hz_vrr -apollo -Verbose``
  - Cross-platform (pwsh): ``APOLLO_CLIENT_UUID=5A900E30-EDB2-6C28-770D-BB4AEE67B196 pwsh -File sk_config.ps1 144hz_vrr -apollo``
- Notes:
  - If `APOLLO_CLIENT_UUID` is unset or no matching profile exists, the provided `ProfileName` is used as-is.
  - Pair with the FPS override variables to drive both selection and `TargetFPS` at runtime.
