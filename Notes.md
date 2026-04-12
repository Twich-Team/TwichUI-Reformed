## BUGS

## NOTES

- Please look at plater and their large selection of advanced configurations. we need some more of that. Particularly, at minimum I need to configure colors for when im tanking and have or do not have aggro, if im not tanking and have aggro, stacking settings, screen clamping, etc.

- For our loot feed, we currently support a moving anchor. First, please add configuration options to the interface designer for this. Second, I would like to add alternative methods for positioning of the loot feed. These will operate almost exactly like the notification anchor options, where they can be docked to the top or lower right of the chat frame, in addition to keeping the current option of a custom placed mover.

- Our automatic remove transform isnt functioning, at least for crafting profession transforms. please look at leatrix plus and determine what we are doing wrong and fix.

- In our nameplates configuration, we provide an arrow selector frame. that frame either needs to set its height to fit all options, or be scrollable. it also should not have a transparent background. preferably, it would appear on a frame anchored to the right of the configuration UI like we have in other places.

- Our notifications background and borders should use the same colors from the global appearance section in our configuration interface
- Our data text menus should use the background and border settings from the global appearance section in our configuration interface

for our loot feed, please use the background and border settings from the global appearance section in our configuration interface. Additionally, can we fade the rows out, with the strongest opacity on the left and transparent on the right?

# Tweaks

## IDEAS/FUTURE

- ElvUI provides skins for almost all standard blizzard interfaces. Please inspect how ElvUI does this, and implement our own skinning system for the blizzard interfaces. It should resemble our current styling, and be reminescent of our goals: performance, clean, modern, eye candy. To start, lets focus on the character panel. Please inspect the character panel skin and tweaks provided by ElvUI and implement our own.

- I have added Horizon Suite to the AddOn references. Horizon, among other things, includes a very nice looking tooltip module. We will now implement our own Tooltip module. I have also included ElvUI which has tooltis as well, however I do perfer Horizon in general. Keep with our typical style, eye candy, performance. Ensure I can configure it from the Configuration UI and the interface designer. Please look at Horizon and create comparable features in our own implementation. Ensure that our implementation is performant and adheres to the newest Midnight changes.

- I have added Horizon Suite to the AddOn references. Horizon, among other things, includes a very nice looking minimap module. We will now implement our own minimap module. Please look at Horizon to create comparable features.Ensure I can configure it from the Configuration UI and the interface designer. Ensure that our implementation is performant and adheres to the newest Midnight changes.

- I have added Horizon Suite to the AddOn references. Horizon, among other things, includes a very nice looking quest objective module. We will now implement our own quest objective module. Please look at Horizon to create comparable features .Ensure I can configure it from the Configuration UI and the interface designer. Ensure that our implementation is performant and adheres to the newest Midnight changes.

- I have added Horizon Suite to the AddOn references. Horizon provides a really nice cimenatic text frame at the top of the screen that animates in and out when you change zones, compelte objectives, etc. I would like the same thing in our addon. As usual, ensure it adheres to our philosophies and can be configured in our interface designer.
