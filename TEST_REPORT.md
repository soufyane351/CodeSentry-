# CodeSentry-Roblox — Verification report

**Version:** 1.0.0  
**Build date:** 2026-11-27  
**Scope:** separate Roblox Studio/Luau implementation of the original CodeSentry text detector.

## Deliverable inventory

- 14 Luau source and test files.
- 50 named Studio test cases across detector, history, and integration suites.
- Rojo project mapping, manual installation guide, architecture notes, code audit, original-source review, and testing guide.
- GitHub Actions static package-quality workflow.
- SHA-256 manifest for the packaged project files.

## Original repository inspected

The connected GitHub file reader was used to inspect these eight original files: `README.md`, `LICENSE`, `config.lua`, `detector.lua`, `history.lua`, `main.lua`, `tests/run.lua`, and `.github/workflows/lua-tests.yml`. The original repository was not changed. A direct clone could not be completed because outbound DNS/network access was unavailable; the review used the repository file reader instead.

## Source findings and design decisions

- The original Lua 5.4 CLI uses filesystem, process/CLI, and module-path facilities unsuitable for a Roblox LocalScript. The new version uses ModuleScripts, a LocalScript, Roblox UI instances, and in-memory history.
- The original Mode 4 parser searches forward for a numeric token after the prefix; the Roblox parser requires the first candidate token to be numeric to avoid mistaking later incidental numbers for codes.
- The original Mode 3 word pattern permits separator placements that are not clearly internal. The Roblox version permits apostrophes and hyphens only between ASCII letters and rejects adjacent or edge separators.
- Multiple recognized prefixes are rejected as ambiguous.
- History is bounded and session-only; duplicate detections update the entry's last-seen timestamp/status/count and move it to the top without creating another row.
- Settings are session-only. No unsupported filesystem API or client-side DataStore persistence is used.

## Checks executed in this build environment

| Check | Result | Details |
|---|---|---|
| Static package/source audit | **Passed** | `python tools/audit_bundle.py`; all 42 static checks passed. |
| Rojo project JSON validation | **Passed** | Parsed using Python's standard JSON parser. |
| Forbidden API/source-pattern scan | **Passed** | The static audit scans all 14 Luau files for executor APIs, remote invocation, dynamic source execution, external code downloads, and arbitrary filesystem I/O. |
| Luau block/delimiter structure scan | **Passed** | A lexical sanity scan found balanced brackets and block terminators in all 14 Luau files; this is not a Luau parser or compiler. |
| Unfinished-marker scan | **Passed** | The static audit found no TODO/FIXME/placeholder implementation markers in Luau source. |
| Test-case inventory | **Passed** | The static audit found 50 named Studio cases. This is an inventory check, not test execution. |
| ZIP CRC/integrity | **Passed** | Verified with Python `zipfile.testzip()` after packaging. |
| ZIP contents and SHA-256 manifest | **Passed** | Archive members were compared with the project tree and every manifest digest was recomputed from the archived bytes. |

## Automated tests included but not executed here

**50 named Luau tests are included.** They cover valid/invalid three-word and four-digit codes, auto mode, leading zeroes, prefix capitalization, whitespace normalization, invalid inputs/tokens, prefix requirements, ambiguity, custom/invalid configuration, large inputs, duplicate protection, timestamps/formats, newest-first ordering, search/filter/clear, defensive copies, history capacity, and processor status/error mapping.

| Measure | Result |
|---|---|
| Studio test cases included | 50 |
| Studio test cases executed in this environment | 0 |
| Studio test cases passed | Not measured — not executed |
| Studio test cases failed | Not measured — not executed |

## Roblox Studio checks not performed

No Roblox Studio client, Luau compiler/runtime, Rojo executable, device emulator, or Studio Output window was available in the build environment. Therefore these checks remain **not verified**:

- Luau syntax/type compilation and ModuleScript loading.
- Playtest and UI construction.
- Button, TextBox, navigation, settings, history, and notification interactions in Studio.
- Mobile viewport/device-emulator layout.
- Runtime warning/error inspection.
- Original Lua 5.4 test execution.

No Roblox Studio pass is claimed. Run the supplied `TestRunner.run()` command and the manual regression checklist in `docs/Testing.md` after importing the project.

## Final audit statement

The deliverable is a complete source/package bundle with the 50-case Studio suite included. Static package checks and archive integrity checks passed. Runtime compatibility and actual Studio behavior are explicitly unverified until executed in Roblox Studio.
