# Bank opening taint: verified path and remaining scope

On 2026-10-10, the user confirmed that opening bags manually before the bank left `BankPanel.bankType` secure, whereas letting the bank open bags tainted that field with `!dev_MyBags`. The local taint log identified the read in `BankPanelMixin:GetActiveBankType` immediately before the blocked `UseContainerItem` call. The bank-type mapping and tab IDs remained secure; tab `isSelected` fields became tainted after opening/switching.

Blizzard source at `/mnt/c/Program Files (x86)/World of Warcraft/_retail_/BlizzardInterfaceCode/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/BankFrame.lua` registers the original BankFrame_Open function for Banker, CharacterBanker, and AccountBanker. Its OnShow opens bags before selecting the default bank type. `Blizzard_UIPanels_Game/Shared/PlayerInteractionFrameManager.lua` stores that function in frameInfo and invokes it directly; replacing the global later does not replace the captured callback.

Decision: preserve the existing MyBags bank-opening workaround and search handling, register it for those three interaction types, and invoke the original Blizzard opener through securecallfunction after bags have opened. No other taint suspects or existing workarounds were removed. The unsuccessful earlier button-lifecycle secure-call experiment remains removed, outside the darkening commit.

Validation: all 17 Lua test files passed. `tests/bank_open_sequence_test.lua` models the captured original callback, bags initially open and closed, search clearing/restoration, and execution-context isolation for all three interactions. It fails against the previous implementation. The simulation verifies ordering and contracts; WoW supplies the actual security behavior.

The user then reported `issecurevariable(BankPanel, "bankType")` returning true and confirmed switching tabs followed by item use works. This validates the reported reproduction, not every possible taint source. Portable account-only bank access and broader addon combinations were not separately reconfirmed in this final trial. Keep the taint fix separate from the confirmed darkening commit dd0a2bc; it is currently uncommitted.

Earlier backlog observations implicated synthetic all-tab item buttons, and an earlier mitigation was dated 2026-04-06. Those observations are historical hypotheses, not evidence that the synthetic buttons must be removed. The all-tabs view is preserved.

Release-note review: consolidated the earlier tentative bank-taint claim into one confirmed item-use fix. The latest release cutoff was checked from git tags: 12.1.0-3.38-alpha points to 0b1edf7 (2026-09-20).
