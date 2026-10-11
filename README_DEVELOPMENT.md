# Development Guide

This addon ships a lightweight Lua test suite that exercises both unit-level categorizer logic and SavedVariable persistence across simulated sessions. The tests run with the system `lua` interpreter; no additional dependencies are required.

## Test Commands

Run the commands from the addon's root directory (`Interface/AddOns/!dev_MyBags`).

- Categorizer query evaluation: `lua tests/Categorizers/query_test.lua`
- Base category registration helpers: `lua tests/categories_test.lua`
- SavedVariable integration scenarios (boot/load/logout flows): `lua tests/integration/persistence/savedvariable_test.lua`

The integration harness deliberately stubs UI libraries (`MyLibrary_GUI`, `WowList-1.5`) and `C_Container` calls so the tests focus on data persistence without loading Blizzard frames. If you add new persistence paths, extend `tests/integration/persistence/savedvariable_test.lua` and update the harness when additional APIs need stubbing.

## Bank Layout Notes

- MyBags bank view is scroll-free. The panel resizes to content and uses frame scaling to stay within screen bounds.
- Bank column resize uses the same drag thresholds/preview behavior as bags.
- Bank resize applies column-count changes to both bank scopes together (`bank-character` and `bank-account`).
- Bank scopes default to 4 columns only when no persisted value exists; saved values are not overwritten on initialization.
- While bank search text is non-empty, panel size is locked to the pre-filter dimensions to prevent resize jitter during filtering.

## Custom Query Priority Notes

- Query-based matching inside custom categories is ordered by explicit per-category priority (higher score first).
- If no explicit priority is stored for a custom category, runtime default priority is the numeric raw category id.
- Priority ties are resolved by alphabetical category name, then internal deterministic fallback.

## Category Editor Runtime Notes

- The custom category editor is a centered movable `DefaultPanelFlatTemplate` frame (not bag-anchored).
- Selection captures a per-category baseline snapshot (`name`, `query`, effective `priority`, `alwaysShow`, `scopeVisibility`) used by `Revert Changes`.
- Editor fields are staged in UI state; persistence updates only when `Save` is pressed.
- Scope visibility is stored per custom category for `bag`, `bank-character`, and `bank-account`; storage persists only disabled-scope overrides (`false`) and omits enabled defaults.
- In edit mode, each custom category header exposes a current-scope visibility toggle (Bags/Bank/Warbank depending on active container scope).
- Name field `Escape` discards in-field draft text and restores the baseline category name.
- Revert scope is per selected category at selection time (switching category resets baseline).
- Closing the editor with pending changes opens a two-action confirmation (`Save and Exit` / `Exit`).

## Import/Export Notes

- Import/export payloads are plain Lua table literals (no leading `return`).
- Import is create-only: each payload category creates a new custom category.
- Export includes rule + manual assignment data (`name`, `query`, `priority`, `alwaysVisible`, `items`).
- `externalId` matching was intentionally removed to avoid hidden duplicate-id/user-control pitfalls that could block imports.
- Layout data is intentionally excluded from import/export to keep the flow simple and avoid order/collapse mismatch pitfalls.

## Generated Query Help Docs

- Canonical source for query help content is `QUERY_ATTRIBUTES.md`.
- Runtime file consumed by UI is `generated/queryHelpDocs.lua`.
- Regenerate locally after query-doc changes: `lua tools/generate_query_help.lua`.
- Release workflow always regenerates and verifies this file is up to date before packaging.

## Item insertion previews

`itemInsertionPreview.lua` draws one mouse-disabled overlay using Blizzard's `CDM-vertical` atlas. It uses the existing shared category item arrays and background target lookup across all storage scopes. It does not change item anchors during hover. Protected and collapsed categories retain their category hints without showing a precise insertion gap.

`ITEM_MOVED` passes item ID, target item ID, source category, target category, source button, target button, and visual insertion side (`before`, `after`, or `end`). The side is mandatory. Cursor halves choose before/after; category targets use end. `itemsOrder.lua` translates visual placement into the existing global sequence, which the layout renders in reverse. Category drops append even within the source category. Ordering remains keyed by item ID, so stacks of the same item move together. No SavedVariables format changes are required.

Shared `DragAndDrop:HookItemButton` expands mouse hit rectangles by half of `ITEM_SPACING` on every side using negative `SetHitRectInsets`. Adjacent icons therefore cover their intervening gap without changing their visible geometry. Gap focus uses the same item preview and drop handlers as the icon itself; unused category space still appends.

## Maximum container scale

`ScaleSettings` hydrates the maximum ratio from `settings.maximumScale` at initialization and serializes non-default values on logout. The 100% default is omitted from SavedVariables. The MyBags options slider exposes percentages from 5 to 100. Shared frame scaling caps both allocation passes and captured bag search scales, so bags, character bank, and Warbank respect the same maximum. Changing the option reapplies both frame scales directly.
