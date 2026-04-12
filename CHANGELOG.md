### Version 0.0.14 [ April 12 2026 ]

This is a massive release!!

This release focuses primarily on performance, with a massive CPU performance increase. Additionally, we now have nameplates! some small bugfixes and minor missing items are included.

Development is currently turning towards completing the MVP of the "UI Overhaul" goal, and will soon enough no longer require ElvUI. The next major feature will be tooltips, followed by minimap, objective tracking, and blizzard frame skinning.

However the short-term plan is to continue with performance increases, more pointed towards memory usage, while continuing bugfixes as bugs are found and adding missing features as they are discovered.

### BREAKING CHANGES

- This update introduces an entirely new action bar system, allowing more control and customization. However, it is possible the placement of your spells and keybdings may not remain the same after this update and will require setting up again.

#### BugFixes

- Fixed an issue where the profession frame would not open when toggled from the gold data panel text.

#### New

- Nameplates are now available. Pre-configured to make your priority targets obvious, and with settings layed our to make configuring nice nameplates quick and easy.
- Rewritten action bar system uses fully in house action bars instead of utilizing Blizzard bars
- Loot feed: an expanding feed of recently acquired loot!
- Action bars now have a simple paging system where you can configure via options the paging instead of cryptic codes.
- Added the extra player power bar (mana for balance druids, ebon might for evokers)
- A multitude of gameplay tweaks have been added to the new section, "World & Gameplay" in the configuration UI
- Added a new experience data panel text to show for leveling, includes a timer to see how long you were at each level
- Added the option of using the Dracthyr Soar ability as the flying mount in Smart mount

#### Other

- Profiling system added to make it simpler to target inefficient code
- Temporarily disabled the Mythic+ Interrupt tracker as it is not currently reliable
