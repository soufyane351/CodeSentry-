# Installation Guide

## Recommended: Rojo

1. Download this repository to your computer.
2. Install Rojo CLI and the Rojo Studio plugin by following the official Rojo installation instructions.
3. Open a terminal in the `CodeSentry-Roblox` project directory.
4. Run `rojo serve`.
5. Open Roblox Studio and open a place.
6. Open the Rojo plugin, connect to the local server, and sync.
7. Press **Play**. `Main.client.lua` creates the CodeSentry ScreenGui for the local player.

To generate a place file without a live sync session:

```bash
rojo build default.project.json --output CodeSentry.rbxlx
```

Then open `CodeSentry.rbxlx` in Roblox Studio.

## Manual installation

Follow the exact instance tree in the main README. ModuleScript names must match their source filenames, and `Main.client.lua` must be a LocalScript named `Main` under `StarterPlayerScripts/CodeSentry`.

## GitHub upload

Upload the complete extracted `CodeSentry-Roblox` directory, including `default.project.json`, `src`, `docs`, `.github`, `tools`, and the root documentation files. Do not upload only the `src` folder: the Rojo mapping, tests, QA workflow, and installation documentation are part of the project.

## Verify the tree

After syncing, the Explorer should contain:

- `ReplicatedStorage/CodeSentry/Shared`
- `ReplicatedStorage/CodeSentry/Tests`
- `StarterPlayer/StarterPlayerScripts/CodeSentry/Main`
- `StarterPlayer/StarterPlayerScripts/CodeSentry/UIController`
- `StarterPlayer/StarterPlayerScripts/CodeSentry/ThemeController`
- `StarterPlayer/StarterPlayerScripts/CodeSentry/NotificationController`

The runtime entry point is the `Main` LocalScript.
