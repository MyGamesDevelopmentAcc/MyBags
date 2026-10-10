# Preserve bank context darkening

This living ExecPlan follows `.agent/PLANS.md`.

## Purpose / Big Picture

Items that cannot enter the active bank should darken whether bags were already open, opened by a banker, or opened by the portable Warbank.

## Progress

- [x] (2026-10-10) Inspect pending overlay implementation and local Blizzard source.
- [x] (2026-10-10) Hook individual overlay updates and add direct context-event regression coverage.
- [x] (2026-10-10) All 16 Lua test files passed; review release documentation.
- [x] (2026-10-10) User confirmed darkening works in-game.

## Surprises & Discoveries

Blizzard ItemButtonMixin receives ItemContextChanged directly in PostOnShow, calls UpdateItemContextMatching, and then UpdateItemContextOverlay. The pending container hook misses that path. BankPanelMixin:Reset broadcasts that event after bank-type changes. MyBags alpha changes persist through Blizzard SetShown calls.

## Decision Log

- Decision: Reapply alpha after each managed button's UpdateItemContextOverlay, instead of enumerating the container after its context update. Rationale: cover all Blizzard refresh entry points without modifying Blizzard match fields. Date: 2026-10-10.

## Outcomes & Retrospective

The direct button context regression passes with the hook and fails without it: expected alpha 1, got 0. All 16 Lua test files pass. The user confirmed darkening works in-game. Unsuccessful taint mitigation was removed before committing this independent fix.

Reviewed release notes and added the darkening fix. Inserted the latest git-confirmed alpha cutoff (0b1edf7, 2026-09-20) in the changelog. Existing taint documentation is outside this change.

## Context and Orientation

`utils/itemButtonSearchOverlay.lua` applies MyBags search visibility while preserving Blizzard item-context mismatches. `main.lua` uses it for bags; `bankView.lua` uses it for selected-tab and addon-managed bank buttons. `tests/item_button_search_overlay_test.lua` tests alpha behavior.

The Blizzard source root is `/mnt/c/Program Files (x86)/World of Warcraft/_retail_/BlizzardInterfaceCode`. Relevant files below Interface/AddOns are `Blizzard_ItemButton/Shared/ItemButtonTemplate.lua`, `Blizzard_FrameXMLUtil/ItemUtil.lua`, and `Blizzard_UIPanels_Game/Mainline/BankFrame.lua`. ItemUtil reads BankFrame:GetActiveBankType to determine deposit eligibility; ContainerFrame.lua also reads it before UseContainerItem.

## Plan of Work

Install one secure post-hook per managed button on UpdateItemContextOverlay when Apply first initializes its MyBags search state. Reapply only reads the stored search boolean and Blizzard context result. Remove the pending container-wide hook.

## Concrete Steps

From the addon root, run each test file matching tests/**/*_test.lua with lua. Regression tests should model Blizzard overlay visibility and direct button context changes.

## Validation and Acceptance

All Lua test files must pass. In WoW after reload, test bags initially open and closed, banker character-to-account switching repeatedly, portable Warbank, and search changes while a bank is open. Ineligible items should darken and regain normal appearance on close. The user confirmed the darkening fix works.

## Idempotence and Recovery

Changes preserve pending user edits, do not change SavedVariables, and install each button hook once.

## Artifacts and Notes

The pending overlay tests exercise Reapply directly but do not simulate Blizzard's direct context callback. New regression coverage must reproduce that missing entry point.

## Interfaces and Dependencies

ItemButtonSearchOverlay:Apply(button, includeInSearch) stores a boolean and applies alpha; Reapply(button) uses that stored boolean. Managed buttons must expose ItemContextOverlay and UpdateItemContextOverlay. WoW supplies hooksecurefunc. Test doubles must model these boundaries explicitly.

Revision 2026-10-10: User confirmed darkening; removed unsuccessful taint mitigation and narrowed this plan and commit to the confirmed overlay fix.
