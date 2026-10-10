# Test changes

2026-10-10: Replaced the pending overlay test "reapply on never-applied button treats it as excluded". Reapply is now installed by Apply on initialized managed buttons; treating missing initialization as an excluded item was a silent fallback. Coverage now checks direct Blizzard button context refresh, query match preservation, and one-hook initialization with changing inclusion state. All other pending tests are retained.
