# Original CodeSentry repository review

**Source reviewed:** `https://github.com/soufyane351/CodeSentry`  
**Review scope:** the repository's Lua 5.4 README, license, configuration, detector, history store, CLI entry point, test runner, and GitHub Actions workflow.  
**Change boundary:** the original repository was not modified. This Roblox implementation is a separate project tree.

## Original architecture observed

- `config.lua` supplies the default mode, recognized prefixes, prefix requirement, history path, and display limit.
- `detector.lua` is the pure detection module and returns success or rejection results.
- `history.lua` stores deduplicated entries in memory and optionally appends them to a local text file.
- `main.lua` wires the modules into a command-line tool, including file/stdin processing and history administration.
- `tests/run.lua` exercises detector, history, integration, and CLI behavior.
- `.github/workflows/lua-tests.yml` installs Lua 5.4 and runs the test suite.
- `README.md` documents the standalone Lua 5.4 application and its file-based history.

## Compatibility decisions

The original command-line application uses APIs and patterns that are not appropriate for a LocalScript, including `io.open`, `os` file handling, `package.path`, CLI arguments, and `loadfile`. Those were not copied into Roblox scripts. The new implementation uses ModuleScripts, a LocalScript, in-memory history, and Roblox UI APIs.

The Roblox detector keeps the original three-word/four-digit intent and its default prefix vocabulary, while adding an explicit ambiguity rejection path and an input-size cap.

## Behavioral limitations found during source review

- The original Mode 4 parser scans forward for the first all-digit token after a prefix. As a result, a message such as `Code: reward 1234` can be interpreted as a code even though the first token after the prefix is ordinary text. The Roblox version deliberately requires the first candidate token to match the selected format.
- The original Mode 3 pattern requires an alphabetic first character but permits apostrophes or hyphens at the end of a word and allows adjacent separators. The Roblox version makes the documented rule stricter: separators must occur between letters and cannot be adjacent.

These are source-level observations, not executed test failures. The original Lua 5.4 suite was not run in this environment because no Lua 5.4 runtime was available.

## Files inspected

1. `README.md`
2. `LICENSE`
3. `config.lua`
4. `detector.lua`
5. `history.lua`
6. `main.lua`
7. `tests/run.lua`
8. `.github/workflows/lua-tests.yml`

## Original repository preservation

No create/update/delete actions were sent to the original GitHub repository. A direct local clone could not be completed in this environment because outbound DNS/network access was unavailable. Source review was performed through the connected GitHub repository file reader. The ZIP contains the new Roblox Studio project, not a byte-for-byte mirror of the separate Lua 5.4 repository.
