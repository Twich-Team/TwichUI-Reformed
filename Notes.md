## BUGS

- our tooltips flash when im looking at items in the auction house

- the status bars we show on the objective tracker should use the status texture chosen in the global appearances section
- the sizing of our tooltips is odd. it doesnt always fit contents properly, especially when quickly hovering over different players. It will add too much horizontal or vertical space, or too little.

## NOTES

- I currently want to focus on decoupling from ElvUI. Please review our addon to ensure there are no longer any links to ElvUI code. If so, please implement our own version of it.

# Tweaks

## IDEAS/FUTURE

- I have added Horizon Suite to the AddOn references. Horizon, among other things, includes a very nice looking minimap module. We will now implement our own minimap module. Please look at Horizon to create comparable features.Ensure I can configure it from the Configuration UI and the interface designer. Ensure that our implementation is performant and adheres to the newest Midnight changes.

- I have added Horizon Suite to the AddOn references. Horizon provides a really nice cimenatic text frame at the top of the screen that animates in and out when you change zones, compelte objectives, etc. I would like the same thing in our addon. As usual, ensure it adheres to our philosophies and can be configured in our interface designer.

- Enhanced junk selling
- Blizzard Damage meter skinning
- BigWigs skin
- Advanced keybinding system
- Transmog collection system
- "Loadable on demand" configuration

We are missing a lot of features in our objective tracker. please look at horizon. For example, filtering by zone, tooltips, right click to untrack, context menus to untrack
