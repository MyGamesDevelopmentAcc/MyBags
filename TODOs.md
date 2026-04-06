# TODOs

This file is the live backlog for MyBags. Keep it concise and outcome-focused.

## Planned

### Improtant



### Normal

- Add toy category. Prefer `C_ToyBox.GetToyInfo(itemID) ~= nil` or `TooltipInfo.GetToyByItemID(itemID) ~= nil` to detect toys.
- Observation: dragging an item from vendor, inventory, or another container shows category highlight even when background drop does not actually assign the item; the highlight/assignment expectation should match the real behavior.
- Observation: changing tabs between bank and warband bank while search is active freezes resize behavior.
- Observation: dragging an item from bags to bank into a different category first changes the bag category, and only the next drag moves it to the bank; this should happen in one action.
- Expectation: creating a new category should place it in the last column consistently across bags, bank, and warband bank.
- 🛠️ Observation: query help window triggers and UI logic are still mixed into `categoriesGUI.lua` and should be moved to a dedicated file.
- 🛠️ Observation: internal silent-guard patterns still exist and should be replaced with fail-fast preconditions where contracts are strict.
- 🛠️ Observation: some flows rely on direct cross-module reactions where clearer event-driven boundaries would better separate responsibilities.
- 🛠️ Expectation: naming conventions across the codebase should be normalized to match repository rules.
- 🛠️ Observation: bag-search anchor-lock behavior is still spread across existing files and should live behind a dedicated module interface.
- 🛠️ Observation: `CustomCategorizer:Categorize` still looks like the next profiling/performance hotspot.
- 🛠️ Observation: internal runtime still has places where category ids/names are used instead of passing category objects directly.

### Low priority

- 🛠️ Expectation: collapsed-state and column-assignment persistence should be stored per container scope instead of sharing one bag-oriented shape.
- 🛠️ Observation: drag/drop cursor checks still rely on `pickedItemButton`; `C_Cursor.GetCursorItem()` may be the cleaner source if behavior matches.
- 🛠️ Observation: the release workflow still publishes more than the addon zip; this should be reduced only if it does not break downstream consumers such as WoWUpHub.

### Doubtful

- 🛠️ Observation: some state-change flows may be better expressed as container/layout events instead of direct state mutations, but this needs validation before turning into implementation work.

## In Progress

- Simplify TODO tracking: keep this file as a curated backlog, archive the historical diary, and require dated concise entries for tracked completions.
- 🛠️ Add a curated user-facing changelog workflow with one `RELEASE_NOTES.md` draft per stable cycle and `CHANGELOG.md` as the stable archive.

## Done

- 2026-03-07 - Re-scoped `TODOs.md` to a concise live backlog and moved the historical log to `.agent/todo-history.md`.
- 2026-03-13 - Removed leftover runtime debug logs and profiling helpers from release code paths.
- 2026-03-13 - Added `onUseDescription` query support using localized `Use:` tooltip text for custom-category matching.
- 2026-03-17 - Fixed filtered bag and bank relayout so active search no longer shoves frames off-screen during item use or bank filtering.
- 2026-04-05 - Fixed dynamic-category layout corruption by deduplicating per-scope layout ids with last-occurrence cleanup and stabilizing bag placement by category id on refresh/first load.
- 2026-04-06 - Hopefully fixed without introducing too many new bugs ;) 🐞 There is some kind of tainting during bank usage. `--TODO: BANK_TAINT` marks suspicious spots in `bankView.lua`. Current strongest finding: the taint disappears when MyBags stops generating its synthetic all-tabs Blizzard bank item-button set and reuses only Blizzard's selected-tab buttons. See `.agent/bank-taint-investigation-2026-04-05.md`.

   ```lua
   -- in bankView.lua  --TODO: BANK_TAINT marks lines which when commented out remove the taint that is currently caused by them, when in bank switiching between warband bank and normal bank ui. This leads to inability to use items in bags which have "Use:" in their tooltip. Weirdly opening the bank, without switching tabs, removes the taint and reenables the ability to easily use those items. Secondly the taint happens only after 2nd tab switch. Regardless if we have or have not closed the bank in the meantime. Why is it so?
   ```

## Rejected

- Hide categories and their items entirely.
- Add an authenticator button to the custom bag layout.
- Disable categories in a way that removes them from matching while keeping their prior assignments as a separate feature.
