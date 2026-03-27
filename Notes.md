## Chat

- When a new message comes in to chat, make sure the new message is not faded out. ive had messages come in that i cannot see. new messages should have their own fade out timer.
- Our edit box used to change the color of its accent to represent the channel you are typing in. Can we please re-enable that.
- FOr the messages inside the chat frame, can we make sure they reach the bottom of the frame? theres a good maybe 10 pixels between the bottom of the bottom chat and the bottom of the frame. There's also what looks like a slightly different color in that area

## Notifications

- For the notifications config, can we separate the global configuration settings from the individual notification settings? perhaps a separate tab or group o r something for that

## Datatext

- The friends datatext has an option to only show friends that are online in wow. However its not working, when I have a friend online, it doesnt show any.
- The favorite mounts in the mounts datatext menu are not populating. It should be showing the mounts I have favorited in the mount journal like it used to.
- Add a theming option to the configuration for each datatext panel that will apply a transparent theme. sets all colors to transparent so its only the text, hover underline, and hover glow
- first time opening the hearthstone selector for portals, teh eharthstones dont populate
- make sure the datatexts are using the primary color for the "colored" texts (like the number of chores, or m+ score). Allow this to be overridden if desired.
- I have created a panel that is 3440x30, to stretch along the bottom of my screen. I placed it at 0, 0 for x and y offset. There is what looks like 1-2 pixel gap between the monitor and the bar. I can see the game in that area.
- IN the chores datatext tooltip, it says left click to open menu, right click to pin frame. That is backwords. Please reword it correctly.

## Mythic+

- Can we add a helper text panel attached to the right on the keystone frame that appears when you place a keystone explaining that the dungeon will start automatically at the end of a pull (if enabled), along with a button to start a ready check and a button to start a pull timer, as well as checkbox to auto-start when the timer ends.
- In the mythic plus config, theres a button that says open timer settings section. we dont need that.. its already in that section..

## Apperance

- I changed the status bar texture in global and the texture of the bars on the mythic+ tracker did not change.
- I want you to go through the entire configuration. Each thing that can be configured with an option from global should be effected by it, if the overrides are disabled. When I click Reset Overrides, I expect that for example, the status texture i choose in the global appearance section to be used everywhere in the addon that there is a status texture.

## Other

- We can remove the about section, it is not needed.
- Lets keep the left sections in the configuraiton in alpha order- except for overview, which would be at the top.
- In overview, add a way to toggle the wizard.
- Rename The Weekly and Utility section to Quality of Life
- Create a basic datatextd that says "TwichUI", and when clicked opens the configuration
- Update the overview to spotlight some of the quality of life features (smart mount, easy fish, etc.)
- In the configuration title, make it say TwichUI: Reloaded Configuration
- Remove the Fonts & Media section, we are going to always provide those. Keep them on all the time.

## Chores

- Please re-style chores to be more inline with our newer theming.

## Errors:

- I get the following error when i log into the game, but not when I reload:

1x ...aceTwichUI_Reformed/Configuration/Module.lua:302: Usage: SaveBindings(1||2)
[tail call]: ?
[C]: in function 'SaveBindings'
[TwichUI_Reformed/Configuration/Module.lua]:302: in function 'SetChoresTrackerConfigKeybinding'
[TwichUI_Reformed/Configuration/Module.lua]:87: in function <...aceTwichUI_Reformed/Configuration/Module.lua:66>
[C]: ?
[Masque/Libs/AceAddon-3.0/AceAddon-3.0.lua]:66: in function <...aceMasque/Libs/AceAddon-3.0/AceAddon-3.0.lua:61>
[Masque/Libs/AceAddon-3.0/AceAddon-3.0.lua]:494: in function 'InitializeAddon'
[Masque/Libs/AceAddon-3.0/AceAddon-3.0.lua]:619: in function <...aceMasque/Libs/AceAddon-3.0/AceAddon-3.0.lua:611>
