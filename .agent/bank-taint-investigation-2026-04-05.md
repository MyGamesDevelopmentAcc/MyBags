# Bank Taint Investigation Notes

Date: 2026-04-05

These notes capture findings from an investigation session into bank/warband-bank taint that later blocks `UseContainerItem()` for normal bag items.

## Confirmed Reproduction Shape

- Repro path:
  1. Open bank.
  2. Switch between character bank and warband bank.
  3. Close bank.
  4. Try to use a bag item with `Use:` text.
- Observed blocked action:
  - `ADDON_ACTION_FORBIDDEN` for `UseContainerItem()`.
- Important behavior detail:
  - The block happens later on bag item use, but the taint is introduced earlier during bank UI work.

## What The Trace Proved

- The taint was introduced during bank open/tab-switch handling, not during later bag use.
- Deferring bank refresh with `QueueRefresh()` reduced churn but did not remove the taint.
- Removing extra non-search mutations during bank refresh did not remove the taint:
  - extra `itemButton:Refresh()`
  - extra `itemButton:SetMatchesSearch(true)` while search was inactive
- Removing MyBags bank item-button hooks did not remove the taint.
- Moving MyBags metadata off Blizzard bank item buttons did not remove the taint.
- The taint disappeared only when MyBags stopped generating its all-tabs bank item-button set and instead reused Blizzard's currently selected-tab buttons only.

## Strongest Current Finding

- The main taint trigger is the all-tabs bank item-button generation path in `bankView.lua`.
- Specifically, the dangerous path is the custom all-tabs use of Blizzard bank item buttons via pool/object lifecycle operations such as:
  - `ReleaseAll`
  - `Acquire`
  - `Init`
- This means the issue is not explained by simple refresh timing alone.

## What Did Not Explain The Problem

- Shared `RunNextFrame` scheduling by itself does not explain the taint.
- Separate bag/bank queue instances may still be a cleanup improvement, but the investigation did not support them as the primary fix.
- The taint persisted even after refresh timing was made more conservative.

## Working Diagnostic Mode

- A temporary diagnostic mode that reused only Blizzard-selected-tab bank buttons removed the taint.
- That mode reduced feature coverage, but it proved the all-tabs synthetic bank-button generation path is the culprit class.

## Architectural Implication

- If all bank tabs need to be shown together safely, avoid manufacturing extra Blizzard bank item buttons for off-tab items.
- The likely safe direction is to use MyBags-owned visual item frames for the synthetic all-tabs bank view and leave Blizzard bank item buttons in their intended selected-tab lifecycle only.

## Important Caution

- Some suspicious-looking code paths have worked safely for a long time.
- Do not broaden this finding into a generic "touching buttons taints" rule.
- The evidence from this session is narrower:
  - the problematic area is the bank all-tabs synthetic use of Blizzard bank item buttons in `bankView.lua`
  - not bag handling in general

## Temporary Regression Seen During Investigation

- While testing a metadata-isolation experiment, `C_NewItems.IsNewItem(containerIndex, slotIndex)` started receiving bad arguments.
- Cause:
  - some categorizers still assumed bank item buttons expose `GetBagID()` / `GetID()`.
- Conclusion:
  - if future experiments remove direct method assumptions on bank buttons, update categorizer/query code consistently or provide a shared bag/slot resolver contract.
