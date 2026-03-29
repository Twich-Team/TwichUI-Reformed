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

## Mythic+

## Apperance

## Other

## Chores

## Errors

- Our error logger is not catching any errors at all

## Unit Frames

### General

- In the configuraiton for unit frames, we say "standalone ouf..." can we make this simpler to understand for new players? SOmething that explains that this is where you configure your health bars and party and raid frames

- Can we add more options to customize the highlights? Especially target highlight. Its very thick and odd, maybe a highlight width, or the option to make it a nice glow instead of a border.
- Make a toggle in the class bar configuration to make the width of the classbar the same width as the player frame

- I am in a group, and the party frames are not displaying.

- Can we add exact positioning configuration for the detached player power bar (for example if i want it at x=0 y=200)
- I need to be able to set the background color for the power (mana) bars, it looks like they currently dont have a background at all.

### Texts

### Auras

- MVP: Start with basic filters for getting going
- MVP+: Customize auras with advanced filtering and determine if the aura should show an icon, change the color, show a border, a glow, etc.
