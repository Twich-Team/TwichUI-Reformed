## Configuration

- When I open the Debugger or Error Log from within the configuration, please place it so that it is on the left or right side of the configuration, whichever has more space so it looks clean and is easy to get to without having to drag the window off the top of the configuration interface.
- When I drag the configuration window, it can snap around. For example if i click and drag it might work fine. Then I click and drag again and it feels "offset" from where my mouse is.

## Onboarding & Wizard

- My brother is testing the addon for me. When he installed it, it did not show him the wizard automatically, i had to have him use /tui wizard reset. It should show the first time a person logs into any character (so if he has two characters, it will show once for character 1 and once for character 2). It should also show when I determine players need to re-run the wizard via some override when I update the addon.
- The placement of elements via the layout worked great, except the chat sizing was a little strange. it was too large for him. can we more aggressively scale the chat sizing on different resolutions than my own which created the layout?
- I would like a nice panel to display when players update the addon if i have news or new features to inform them of. This panel should only show once and only when the addon has been updated and only if i provide it information to display to the player. Make it simple for me to add sections to display that information (such as bugs, new features, breaking changes, etc.). This panel should be dismissable by the player, permenantly disableable somewhere in the configuration. Additionally, if its the players first time installing and setting up the addon, this panel will not display until after they complete the wizard process and the final reload finishes.
- The wizard now needs to disable the ElvUI unit frames module, and we probably need to do this towards the begining of the wizard process

### Layouts

- Durability in default Layout
- Muted versions; Fantasy/blizzard versions
- When I change specializations, the chat frame moves

## Chat

- Battle net whispers are colored the same color as normal whispers, can we make them the battle net tell color

## Notifications

## Datatext

- Increase the maximum allowed texts to six per panel
- In the configuration, we try to be simple with naming the slots, "Left Slot", "Middle Slot", but then we lose consistency after "Right Slot". Lets lose this and just go with "Slot 1", "Slot 2", where slot one starts on the left.
- Friends is not showing my friends that are online in the game
- The currencies datatext capped logic isnt working very well. So there is a season maximum for a currency, say 500. you can collect upt o 500 at that point. but you can also spend them, which doesnt increase the amount you can spend. so say i have 500/500 collected as the max. If i spendd 50, i have 450 on hand, but i have still collected 500/500 and cannot collect more.

## Mythic+

## Apperance

## Other

## Chores

## Errors

- Our error logger is not catching any errors at all

## Unit Frames

### General

- In the configuraiton for unit frames, we say "standalone ouf..." can we make this simpler to understand for new players? SOmething that explains that this is where you configure your health bars and party and raid frames

- I am in a group, and the party frames are not displaying.

- My cast bar is displaying the background while casting, but not the bar itself.

- Can we add a way to copy settings from one frame type to another? for example if i design my player frame, and i want to mimic its design for the target as a starting point. Should work across all single unit frames. Similarly with Group UNits. if i design a party frame, and want to mimic it in raid to start with.,

### Texts

### Auras

- MVP: Start with basic filters for getting going
- MVP+: Customize auras with advanced filtering and determine if the aura should show an icon, change the color, show a border, a glow, etc.

* DandersFrames (inlcuded in addon references), while doesnt use oUF, they provide a nice aura designer. It allows you to specify which auras you want toa ppear on the frame, how you want it to be displayed (as an icon, a square colored block, or a bar). It lets you anchor them to different parts of the frame, as well as apply frame level effects such as border, alpha, glow, color change, etc. It shows the auras you can apply to the frame and lets you drag and drop where you want them, has sizing, alpha, offsets, etc. It even lets you specify exactly which auras you want to show and group them up, beyond just "dispellable" or "boss". We need something similar. Look into Danders, and see what we can do in our configuration to replicate.
