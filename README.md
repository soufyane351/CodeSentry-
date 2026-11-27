# CodeSentry for Roblox Studio

**Version:** 1.0.0  
**Runtime:** Roblox Studio / Luau  
**Purpose:** Detect supported SAB-style announcement codes from text pasted by the user.

CodeSentry is a standalone Roblox Studio interface and text-processing utility. It detects code-shaped text; it does not connect to *Steal a Brainrot*, inspect game state, redeem codes, or automate gameplay.

## Features

- **Mode 3:** exactly three ASCII words, normalized to uppercase. Internal apostrophes and hyphens are supported (`O'NEIL`, `ICE-CREAM`). Leading, trailing, or repeated separators are rejected.
- **Mode 4:** exactly four digits, preserved as a string (`0042` stays `0042`).
- **Auto mode:** attempts both supported parsers. A valid four-digit result takes priority; otherwise a valid three-word result is returned, or the most specific rejection reason.
- **Prefix matching:** case-insensitive configurable prefixes. A prefix is required by default.
- **Ambiguity protection:** messages containing multiple recognized prefixes are rejected instead of guessing which announcement was intended.
- **Session history:** duplicates are detected, format and timestamp are recorded, newest entries appear first, and search/format filters are available.
- **Dashboard:** input validation, mode selection, status and rejection details, animated notifications, and history/settings pages.
- **Themes and responsive layout:** dark/light themes and a UI that scales for narrow/mobile viewports.
- **Roblox-native implementation:** ModuleScripts and a LocalScript; no filesystem functions, remote calls, `loadstring`, dynamically downloaded code, or executor-only APIs.
- **Studio test runner:** detector, history, and integration tests with per-test expected/actual/PASS/FAIL records.

## Requirements

- Roblox Studio to run and playtest the UI.
- Rojo CLI is recommended for syncing/building the project from this source tree. A manual Studio installation route is also documented.
- No third-party runtime package is required by the Luau scripts.

## Install with Rojo

1. Download or clone this repository and keep the folder structure intact.
2. Install the Rojo CLI and the Rojo Studio plugin using the official Rojo setup instructions.
3. From this project directory, run:

   ```bash
   rojo serve
   ```

4. Open a place in Roblox Studio, connect the Rojo plugin to the local server, and sync the project.
5. Start **Play**. The CodeSentry window is created for the local player.

To build an importable place file instead, run:

```bash
rojo build default.project.json --output CodeSentry.rbxlx
```

Open the generated `.rbxlx` file in Roblox Studio.

## Manual Studio installation

Create the following instances and paste the matching source files into them:

- `ReplicatedStorage` → Folder `CodeSentry`.
  - Folder `Shared`: create a ModuleScript for each file in `src/Shared` (`Config`, `Detector`, `Formatter`, `History`, `Processor`, `Types`).
  - Folder `Tests`: create a ModuleScript for each file in `src/Tests` (`DetectorTests`, `HistoryTests`, `IntegrationTests`, `TestRunner`).
- `StarterPlayer` → `StarterPlayerScripts` → Folder `CodeSentry`.
  - Create a **LocalScript** from `src/Client/Main.client.lua` named `Main`.
  - Create ModuleScripts from `src/Client/UIController.lua`, `ThemeController.lua`, and `NotificationController.lua`.

The paths and names above are significant because the scripts use `WaitForChild` and `script.Parent` module paths.

## Use

1. Open the game/place in Play mode.
2. Paste an announcement into the dashboard text box, for example `New code: ALPHA BETA GAMMA` or `Code: 0042`.
3. Choose **Mode 3**, **Mode 4**, or **Auto**.
4. Press **Detect Announcement**.
5. Read the result status and rejection explanation. Open **History** to search/filter previous detections or clear the session list.
6. Open **Settings** to edit prefixes, toggle the prefix requirement, change theme, save, or reset settings.

### Result statuses

| Status | Meaning |
|---|---|
| `NEW` | A valid code not yet recorded in the current session. |
| `DUPLICATE` | The same code and format were already detected in this session. |
| `IGNORED` | Text was not a valid supported announcement; a reason is displayed. |
| `ERROR` | Invalid mode/configuration or an internal history/processing error. |

## Detection rules

### Mode 3 — three words

The text after the recognized prefix must contain exactly three tokens. Each token must start and end with an ASCII letter. Straight apostrophes (`'`) and hyphens (`-`) are allowed only between letters; they cannot lead/trail a word or be adjacent to another separator. Multiple internal separators are allowed when each one is separated by a letter. Examples:

```text
New code: ALPHA BETA GAMMA
Redeem code: O'NEIL ICE-CREAM TOP
```

### Mode 4 — four digits

The first token after the prefix must consist of exactly four decimal digits. The result is always a string, so leading zeroes are retained.

```text
Code: 0042
Use code: 0007 before it expires
```

### Auto

Auto attempts both parsers on the same token sequence. A valid four-digit result takes priority; otherwise a valid three-word result is returned. If both reject the input, a specific numeric-format error is preferred when the candidate contains malformed digits. The parser does not search later words for a number when the first token is ordinary text.

### Default prefixes

- `new code:`
- `new codes:`
- `code:`
- `codes:`
- `redeem code:`
- `redeem:`
- `use code:`

Prefix matching ignores case and normalizes whitespace. If more than one recognized prefix is found in a pasted message, CodeSentry returns `ambiguous_announcement`; paste/process one announcement at a time.

## Configuration

Defaults are in `src/Shared/Config.lua`. The UI lets you edit the prefix list (one per line), toggle `requirePrefix`, and choose a theme. The selected detection mode is saved as the default mode when settings are saved.

Important settings:

| Setting | Default | Purpose |
|---|---|---|
| `defaultMode` | `auto` | Mode selected when the interface starts. |
| `requirePrefix` | `true` | Rejects announcements without a configured prefix. |
| `prefixes` | Seven defaults above | Prefix strings matched without case sensitivity. |
| `maxInputLength` | `12000` | Input guard against unusually large pasted text (measured in UTF-8 bytes by Luau string length). |
| `maxHistoryEntries` | `200` | Maximum number of session entries retained. |
| `theme` | `dark` | `dark` or `light`. |

## Project structure

```text
CodeSentry-Roblox/
├── README.md
├── TEST_REPORT.md
├── MANIFEST.sha256
├── LICENSE
├── default.project.json
├── .gitignore
├── .github/workflows/quality.yml
├── src/
│   ├── Shared/
│   │   ├── Config.lua
│   │   ├── Detector.lua
│   │   ├── Formatter.lua
│   │   ├── History.lua
│   │   ├── Processor.lua
│   │   └── Types.lua
│   ├── Client/
│   │   ├── Main.client.lua
│   │   ├── UIController.lua
│   │   ├── ThemeController.lua
│   │   └── NotificationController.lua
│   └── Tests/
│       ├── DetectorTests.lua
│       ├── HistoryTests.lua
│       ├── IntegrationTests.lua
│       └── TestRunner.lua
├── docs/
│   ├── Architecture.md
│   ├── Installation.md
│   ├── OriginalProjectReview.md
│   ├── CodeAudit.md
│   └── Testing.md
└── tools/
    └── audit_bundle.py
```

## Testing

The project includes 50 named Studio-executable detector, history, and integration cases. In Play mode, open the Studio Command Bar and run:

```lua
local tests = require(game:GetService("ReplicatedStorage").CodeSentry.Tests.TestRunner)
local report = tests.run()
print(report.passed, report.failed, report.total)
```

Every case prints a name, expected result, actual result, and `PASS` or `FAIL`. See [docs/Testing.md](docs/Testing.md) for details.

A separate static package audit can be run on a computer with Python 3:

```bash
python tools/audit_bundle.py
```

`MANIFEST.sha256` contains checksums for every other project file and can be checked from the project root with `sha256sum -c MANIFEST.sha256` on systems that provide `sha256sum`.

The GitHub Actions workflow runs that static audit and validates the Rojo project JSON. It does **not** compile or execute Luau. This delivery was statically audited in the generation environment, but Roblox Studio/Luau playtesting was not available there; see `docs/Testing.md` and `docs/CodeAudit.md` for the exact verification boundary.

## Security and privacy boundaries

- The app only processes text the user pastes into its own UI.
- It does not read game chat, inspect another experience, invoke remotes, redeem codes, or modify game state.
- It does not execute downloaded or dynamically compiled source.
- No local filesystem API is used.
- No persistent DataStore is used. History is kept in memory for the lifetime of the running client session. Client-only scripts cannot safely write arbitrary files or access server-only DataStore APIs. A future server-backed persistence feature would require a server script, appropriate validation, and DataStore access on the server.

## Known limitations

- This utility checks text shape only. It cannot verify whether a code is active or accepted by SAB.
- It does not automatically retrieve announcements from Roblox or any external service.
- Multiple recognized prefixes in one input are intentionally treated as ambiguous.
- Three-word codes are ASCII-only; accented and non-Latin letters are not accepted.
- A Mode 3 code must be exactly three tokens after the prefix. Additional explanatory words on the same sentence make it invalid; separate the code from extra text with punctuation or paste only the announcement line.
- Session history and UI settings are not persisted beyond the client session, even after pressing Save Settings.
- Actual Roblox Studio Playtest, mobile device emulation, and Output-window inspection must still be performed in Studio; they are not represented as completed by the local static audit.

## Version history

### 1.0.0

- First separate Roblox Studio/Luau implementation.
- Added text detector, in-memory history, responsive dashboard, settings, notifications, test modules, and static QA workflow.
