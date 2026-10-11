# Settings menu colours and sorting

Blizzard Settings sorts addon categories directly by GetName() (Blizzard_Settings_Shared/Blizzard_CategoryList.lua:387), and initializes each row label from the same name (:94). Colour escapes in the category name therefore sort MyBags under the leading pipe character.

Register the category with plain MyBags. Use the public ScrollUtil.AddInitializedFrameCallback(SettingsPanel.CategoryList.ScrollBox, callback, category) API to colour only the initialized MyBags row label. This callback runs after initialization and also handles reused scroll rows; it avoids replacing secure category methods or changing Blizzard sorting. Reference: Blizzard_SharedXML/Shared/Scroll/ScrollUtil.lua:21, under the configured Blizzard source root.

Behavioral tests assert placement between Alpha and Zebra, the coloured menu label, and unchanged labels for other categories and section headers. The settings/frame-scale suite, Lua syntax check, and diff whitespace check pass. Reviewed the full release notes and consolidated the alphabetical correction into the existing settings-colour bullet. Latest tagged cutoff remains 12.1.0-4.2-alpha at db0e4e8. No TODO item added for this small follow-up. Live menu rendering requires a reload to inspect.
