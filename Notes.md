## BUGS

-

## NOTES

- our objective tracker is still showing all world quests in the current zone. It should not do this. it should only show a world quest if it is active meaning im in the direct quest spot in the zone. Additionally, world quests should be split into their own category in the objective tracker

- the objective tracker seems to not be showing newly obtained quests, or campaign quests. We could have a category dedicated to campaign quests and always show those, at the top.

- i dont think the objective tracker is showing quests that are ready to turn in. like the ones you can click on to turn in remotely. please inspect horizon closesly to ensure we have all the basic logic we need for typical gameplay at least.

# Tweaks

## IDEAS/FUTURE

- ElvUI provides skins for almost all standard blizzard interfaces. Please inspect how ElvUI does this, and implement our own skinning system for the blizzard interfaces. It should resemble our current styling, and be reminescent of our goals: performance, clean, modern, eye candy. To start, lets focus on the character panel. Please inspect the character panel skin and tweaks provided by ElvUI and implement our own.

- I have added Horizon Suite to the AddOn references. Horizon, among other things, includes a very nice looking minimap module. We will now implement our own minimap module. Please look at Horizon to create comparable features.Ensure I can configure it from the Configuration UI and the interface designer. Ensure that our implementation is performant and adheres to the newest Midnight changes.

- I have added Horizon Suite to the AddOn references. Horizon provides a really nice cimenatic text frame at the top of the screen that animates in and out when you change zones, compelte objectives, etc. I would like the same thing in our addon. As usual, ensure it adheres to our philosophies and can be configured in our interface designer.

- Enhanced junk selling
- Blizzard Damage meter skinning
- BigWigs skin
- Advanced keybinding system
- Transmog collection system
- "Loadable on demand" configuration

We are missing a lot of features in our objective tracker. please look at horizon. For example, filtering by zone, tooltips, right click to untrack, context menus to untrack
