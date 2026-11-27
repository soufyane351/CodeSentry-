# Testing Guide and Verification Status

## Run the Luau suite in Roblox Studio

1. Sync/open the project in Studio.
2. Press **Play** so the game DataModel is running.
3. Open the Studio Command Bar.
4. Execute:

```lua
local tests = require(game:GetService("ReplicatedStorage").CodeSentry.Tests.TestRunner)
local report = tests.run()
print(report.passed, report.failed, report.total)
```

The runner emits a line per case with the test name, expected result, actual result, and `PASS` or `FAIL`. It returns a report table suitable for inspection.

## Test coverage

The suite contains 50 named cases. It covers:

- Three-word and four-digit valid codes.
- Auto format selection and leading-zero preservation.
- Lowercase, uppercase, and mixed-case prefixes.
- Extra whitespace and markdown code wrappers.
- Empty, nil, and non-string input.
- Invalid word counts, digit counts, and token characters.
- Apostrophe and hyphen rules.
- Missing and unknown prefixes; custom prefix configuration.
- Multiple/ambiguous announcements and malformed announcements.
- Invalid modes/configuration and input-size limits.
- Bare-code opt-in behavior.
- Duplicate protection, timestamp/format metadata, newest-first order, search, format filter, clear, validation, entry caps, and defensive copies.
- Processor status mapping, different formats, invalid inputs, missing history, and ambiguous text.

## Static audit

From the project root run:

```bash
python tools/audit_bundle.py
```

This verifies the project JSON, required source/documentation files, non-empty scripts, forbidden executor/filesystem patterns, presence of the test cases, and absence of unfinished markers. GitHub Actions runs the same static check. These checks do not parse or execute Luau bytecode.

## Verification performed for this delivery

| Check | Status | Evidence / boundary |
|---|---|---|
| Source tree and required files | Checked | Static package audit script. |
| Rojo JSON syntax | Checked | Python JSON parser. |
| Luau unit-test suite | Not run here | Requires Roblox Studio/Luau runtime. |
| Luau syntax compilation | Not verified here | No Luau compiler/runtime available in the build environment. |
| Roblox Studio project loading | Not performed | Studio unavailable in the build environment. |
| Playtest / UI interactions | Not performed | Must be done in Roblox Studio. |
| Mobile emulator layout | Not performed | Responsive scaling is implemented, but device emulation remains unverified. |
| Output-window errors | Not inspected | Requires an actual Studio play session. |

Do not interpret static checks as proof that the Roblox UI has been playtested. The Studio suite is included so the runtime behavior can be verified after importing the project.

## Manual regression checklist

- [ ] Sync the Rojo project or import the built place.
- [ ] Start Play and confirm the CodeSentry window appears.
- [ ] Paste a valid three-word code and detect it.
- [ ] Paste a four-digit code such as `0042` and confirm the leading zeros remain.
- [ ] Detect the same code again and confirm `DUPLICATE`.
- [ ] Try missing, unknown, and multiple prefixes.
- [ ] Change mode and verify the mode buttons update.
- [ ] Search history and switch each format filter.
- [ ] Clear history and detect a previous code again.
- [ ] Change prefixes, prefix requirement, and theme; save and reset settings.
- [ ] Resize the viewport or use Studio's device emulator and inspect scrolling/tap targets.
- [ ] Inspect Output for errors and warnings.
- [ ] Run `TestRunner.run()` and save its report.
