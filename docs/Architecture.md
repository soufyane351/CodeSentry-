# Architecture

## Runtime tree

`default.project.json` maps the source tree into Roblox services:

```text
ReplicatedStorage
└── CodeSentry
    ├── Shared
    │   ├── Config
    │   ├── Detector
    │   ├── Formatter
    │   ├── History
    │   ├── Processor
    │   └── Types
    └── Tests
        ├── DetectorTests
        ├── HistoryTests
        ├── IntegrationTests
        └── TestRunner

StarterPlayer
└── StarterPlayerScripts
    └── CodeSentry
        ├── Main (LocalScript)
        ├── UIController
        ├── ThemeController
        └── NotificationController
```

## Responsibility boundaries

- **Config:** defaults, defensive copies, and settings validation.
- **Detector:** pure text parsing; no Roblox game-state, network, UI, persistence, or history dependencies.
- **History:** bounded in-memory session entries, duplicate index, search, format filtering, and clear.
- **Processor:** joins detector and history outcomes and maps them to `NEW`, `DUPLICATE`, `IGNORED`, or `ERROR`.
- **Formatter:** presentation-only timestamp and label formatting.
- **Types:** Luau type aliases shared by modules and Studio autocomplete.
- **Main.client:** creates the UI controller for the local player and owns cleanup on script destruction.
- **UIController:** owns UI construction, user input, navigation, history rendering, settings, and viewport scaling.
- **ThemeController:** applies palette roles declared by UI instances.
- **NotificationController:** displays transient success/warning/info notifications and destroys each toast after use.
- **Tests:** Studio-runnable unit and integration test modules.

## Data flow

```text
TextBox + selected mode
        │
        ▼
    Processor
        │
        ▼
    Detector ── invalid ──► IGNORED / ERROR result
        │ valid
        ▼
     History ── existing ──► DUPLICATE
        │ added
        ▼
       NEW
        │
        ▼
UI result panel + history list + notification
```

The detector has no side effects. History is only mutated after a code has passed detection. The UI wraps processing in `pcall` so an unexpected module exception becomes an error result instead of terminating the LocalScript.

## Duplicate key

History keys are `format .. NUL .. code`. This keeps format metadata distinct and prevents accidental cross-format key collisions. Each entry stores `code`, `format`, its first-detection timestamp, last-seen timestamp, last status, and duplicate count. `list()` and `search()` return copies, not references to the internal entries.

## Resource lifecycle

UIController stores event connections and disconnects them in `Destroy()`. The ScreenGui is destroyed at the same time. History is capped at the configured maximum. Toasts self-destroy after their close tween. No polling loop is used.

## Persistence boundary

The current project deliberately uses no persistent storage. A LocalScript should not write arbitrary device files, and DataStoreService access belongs on the server. Persistent history would require a separately designed server-side API, server validation, and data-store budget/error handling; it is outside this local text-detector implementation.
