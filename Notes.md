## BUGS

## NOTES

- Please look at plater and their large selection of advanced configurations. we need some more of that. Particularly, at minimum I need to configure colors for when im tanking and have or do not have aggro, if im not tanking and have aggro, stacking settings, screen clamping, etc.

- I do not see icons for elites or bosses when enabled
- The outline setting for the name doesnt seem to change anything. same with the other texts too.
- In the config, we have a text, textures, etc. sections. we should have those configuration options grouped with the part of the nameplate they are for. for example, instead of having a font section, those settings should be in the tabs that represent them like Health will have the font settings for health. same as texture. i dont want them separate like they are right now.
- Make the color of the target arrow mconfigurable.
- When i adjust the glow, it does not change until i reload, make sure all our nameplate settings take effect immediately and do not require a reload
- We are missing the power bar for the nameplates.

- so i have an addon WoWUnit (https://github.com/Jaliborc/WoWUnit). Can we write some unit tests for the nameplates so we can ensure this works well and find issues faster? make sure we can disable this for production use.

# Tweaks

## IDEAS/FUTURE

- ElvUI provides skins for almost all standard blizzard interfaces. Please inspect how ElvUI does this, and implement our own skinning system for the blizzard interfaces. It should resemble our current styling, and be reminescent of our goals: performance, clean, modern, eye candy. To start, lets focus on the character panel. Please inspect the character panel skin and tweaks provided by ElvUI and implement our own.

- I have added Horizon Suite to the AddOn references. Horizon, among other things, includes a very nice looking tooltip module. We will now implement our own Tooltip module. I have also included ElvUI which has tooltis as well, however I do perfer Horizon in general. Keep with our typical style, eye candy, performance. Ensure I can configure it from the Configuration UI and the interface designer. Please look at Horizon and create comparable features in our own implementation. Ensure that our implementation is performant and adheres to the newest Midnight changes.

- I have added Horizon Suite to the AddOn references. Horizon, among other things, includes a very nice looking minimap module. We will now implement our own minimap module. Please look at Horizon to create comparable features.Ensure I can configure it from the Configuration UI and the interface designer. Ensure that our implementation is performant and adheres to the newest Midnight changes.

- I have added Horizon Suite to the AddOn references. Horizon, among other things, includes a very nice looking quest objective module. We will now implement our own quest objective module. Please look at Horizon to create comparable features .Ensure I can configure it from the Configuration UI and the interface designer. Ensure that our implementation is performant and adheres to the newest Midnight changes.

- I have added Horizon Suite to the AddOn references. Horizon provides a really nice cimenatic text frame at the top of the screen that animates in and out when you change zones, compelte objectives, etc. I would like the same thing in our addon. As usual, ensure it adheres to our philosophies and can be configured in our interface designer.
