# Release Notes

## Tweaks

- Added a setting to disable the built-in `New Items` categorizer when you do not want new items grouped separately.

## Bug fixes

- Fixed category-layout corruption caused by duplicate dynamic category entries, and now clean up duplicated layout ids by keeping the furthest entry.
- Fixed a first-load bag-opening regression where categorized items could fail to get icon positions and trigger a bag open error.
- Fixed filtered bag and bank relayouts pushing the inventory or bank frame partially off-screen while search was active.
