# Changelog

This file tracks completed user-facing work.

- [Tweak] 2026-10-11 - Matched the MyBags settings entry colours to the addon title while preserving alphabetical sorting.

- [New] 2026-10-11 - Added a maximum-scale option to limit bag, bank, and Warbank growth while preserving automatic shrinking.

## 12.1.0-4.2-alpha - 2026-10-11

- [New] 2026-10-11 - Added item insertion markers with matching before/after and category-end placement in bags, bank, and Warbank; gaps between icons also accept item drops.

## 12.1.0-4.1-alpha - 2026-10-11

- [Bugfix] 2026-10-11 - Leaving bank edit mode now prompts to save or discard unsaved category edits.
- [Tweak] 2026-10-11 - Made category drop targeting over category item areas consistent across bags, bank, and Warbank.

## 12.1.0-4.0 - 2026-10-10

- 2026-10-10 [Bugfix] Fixed bank opening and tab switching causing item use to be blocked.
- 2026-10-10 [Bugfix] Restored bank eligibility darkening when opening or switching banks with bags already open.

## 12.1.0-3.38-alpha - 2026-09-20

- 2026-09-20 [Bugfix] Fixed the bank "all tabs" view enumerating one item button twice, which could misplace an item or report a wrong category slot count.
- 2026-04-06 [Bugfix] Fixed tainting when switching tabs in bank - hopefully without too many new bugs :)
- 2026-04-05 [Bugfix] Fixed duplicate dynamic category layout entries corrupting bag and bank column assignments; cleanup now keeps the furthest duplicate entry.
- 2026-04-05 [Bugfix] Fixed a first-load bag-opening regression where categorized items could fail to receive icon positions and trigger an opening error.
- 2026-04-05 [Tweak] Added a settings toggle to disable the built-in `New Items` categorizer so new items no longer match that category when turned off.

## 12.0.1-3.34-alpha - 2026-03-13

- 2026-03-17 [Bugfix] Fixed filtered bag and bank relayouts pushing the inventory or bank frame partially off-screen while search was active.

## 12.0.1-3.33 - 2026-03-14

- 2026-03-13 [Tweak] The query reference and in-game query help now document the built-in starter groups, and the README now points to those definitions and explains how deleting all custom groups resets them on reload.

## 12.0.1-3.33-alpha - 2026-03-13

- 2026-03-13 [New] Query-based categories now support `onUseDescription`, allowing matches against the localized text from an item's `Use:` tooltip line.
