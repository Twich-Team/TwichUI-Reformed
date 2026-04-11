## BUGS

- The gold data text does not open the profession frame when i click on an entry anymore.

## NOTES

- Lets temporarily disable the interrupt tracker module in mythic+ tools, dont remove the code, just ensure its off and not effecting performance and hide the configuration.

- Our error log is handy, especially for players who are not developers, however it does not often catch lua errors we cause. is there a way we can do that? I added buggrabber and bugsack to the addon references.

- Our current implementation of action bars is insufficient. I want our implementation to be like ElvUI, where its a totally TwichUI owned action bar system. It does not utilize the Blizzard system. ALl action bars should be built with this. we should support all the options we support now, and also add paging, with smart and simple options for configuring paging using the configuration interface instead of the only option being a text box to enter the code to handle paging.

- ElvUI provides skins for almost all standard blizzard interfaces. Please inspect how ElvUI does this, and implement our own skinning system for the blizzard interfaces. It should resemble our current styling, and be reminescent of our goals: performance, clean, modern, eye candy.

# Tweaks

The following newly added tweaks are not needed by our addon:

- Class Colors tab
- Loss of control tab
- We can remove the overview tab from both the gameplay and map tweaks tabs, just keep this module enabled
- System behavior tab
- Widget top

LEatrix Plus has a set of predefined transform cancels for you to choose, can we add those to the Transforms tabs as checkboxes, similar to how we did the mount adn toy presets.
