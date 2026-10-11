# Maximum bag and bank scale

## Purpose / Big Picture


Players can restrict automatic bag, character bank, and Warbank growth in Settings > AddOns > MyBags. A percentage slider caps scale while preserving automatic shrinking to fit the screen. The default 100% keeps existing behavior.

## Progress


- [x] (2026-10-11) Inspected shared scaling, search scale locks, persistence lifecycle, and Blizzard numeric slider registration.
- [x] (2026-10-11) Implemented lifecycle settings, shared calculation/search caps, and the percentage slider.
- [x] (2026-10-11) Added behavioral and persistence coverage, updated documentation, and passed all 26 test suites, 66 Lua syntax checks, and diff whitespace checks.

## Surprises & Discoveries


FrameParameters.lua computes scale in two passes: it first allocates shared screen width, then allows each frame to reclaim space from a height-limited neighbour. Apply the maximum in both passes so width reserved for the neighbour reflects its actual capped size. Search keeps a captured scale; cap that value as well so reducing the maximum works during search. Blizzard_SettingsDefinitions_Frame/Controls.lua:129 uses RegisterProxySetting with VarType.Number, CreateSliderOptions, and a right-label formatter.

## Decision Log


Use one maximum for all storage views because their scale computation is shared. Use 5%-100% in 5% steps, matching the current minimum and maximum. Hydrate one runtime number on initialization and save only a non-default value on PLAYER_LOGOUT; do not introduce a second persisted representation. Reapply scales directly when the UI setting changes without rebuilding categories. Date/Author: 2026-10-11, Codex.

Latest release cutoff was verified as 12.1.0-4.2-alpha at db0e4e8. Added its missing CHANGELOG.md heading before inserting this feature above it. Reviewed all release notes, placed the new size control before the insertion-marker feature in New, and retained existing Tweaks/Bug fixes. Date/Author: 2026-10-11, Codex.

## Outcomes & Retrospective


The 5%-100% maximum scale option is implemented for all container views, defaults to 100%, and reapplies scales when changed. Tests verify actual settings-driven frame scale updates, screen fitting below the maximum, captured search scale caps, and logout/reload persistence with default pruning. All 26 suites and 66 Lua syntax checks pass, with clean diff whitespace. Live WoW verification remains necessary for slider appearance and active-frame resizing.

## Context and Orientation


FrameParameters.lua owns screen-fitting calculations and overrides bag/bank SetScale. addonSettings.lua registers the MyBags options category. New scaleSettings.lua will own the runtime maximum and SavedVariables lifecycle, loaded before addonSettings.lua in !dev_MyBags.toc. init.lua creates AddonNS.db during OnDbLoaded. tests/integration/persistence/harness.lua loads domain modules and runs their initialization and logout hooks.

## Plan of Work


First implement ScaleSettings:GetMaximumScale and SetMaximumScale, initialization sanitization, and logout pruning. Next add the numeric percentage proxy and slider; its setter updates ScaleSettings and reapplies both frame scales. Update clampScale, initial allocation, and the search-locked scale path in FrameParameters.lua. Finally test maximum/default behavior, existing screen constraints, locked search, and persistence round trips, then document the new option.

## Milestones


The first milestone provides a usable slider and capped frame calculations. Unit tests must prove a 75% maximum caps bag and bank growth but allows smaller automatic scales. The second milestone validates logout/reload and updates release documentation, with all suites passing.

## Concrete Steps


Work from the addon root. Run lua tests/frame_parameters_scale_test.lua and lua tests/integration/persistence/savedvariable_test.lua. Run each tests/**/*_test.lua in its own lua process, luac -p on changed Lua files, and git diff --check. Expected result is zero failures. Inspect current local tags before updating CHANGELOG.md.

## Validation and Acceptance


In WoW, open Settings > AddOns > MyBags, set Maximum bag and bank scale to 75%, and observe open bags and banks shrink immediately and remain at most that size after resize, search, and reopen. At 100% existing screen-fit behavior returns. Reload must preserve 75%; resetting to 100% must prune that saved value. Invalid SavedVariables values load the default.

## Idempotence and Recovery


Tests run in isolated processes. This additive optional setting needs no migration and preserves existing configuration. Preserve unrelated user edits and prior documentation. Resetting the slider removes the override at logout.

## Artifacts and Notes


Blizzard reference is under /mnt/c/Program Files (x86)/World of Warcraft/_retail_/BlizzardInterfaceCode. No new libraries are needed.

## Interfaces and Dependencies


AddonNS.ScaleSettings owns MINIMUM_SCALE = 0.05, DEFAULT_MAXIMUM_SCALE = 1, GetMaximumScale(), and SetMaximumScale(scale). Internal setter inputs are numeric ratios within these bounds. addonSettings.lua alone converts UI percentages to ratios. FrameParameters.lua calls this mandatory shared interface directly.

Revision note (2026-10-11): Completed implementation and recorded passing validation and the verified alpha release cutoff.
