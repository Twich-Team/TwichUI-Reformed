## Configuration

- When I open the Debugger or Error Log from within the configuration, please place it so that it is on the left or right side of the configuration, whichever has more space so it looks clean and is easy to get to without having to drag the window off the top of the configuration interface.
- When I drag the configuration window, it can snap around. For example if i click and drag it might work fine. Then I click and drag again and it feels "offset" from where my mouse is.
- PLease remove the legacy Raid Frame Tweaks from the configuraiton UI and the functional code, make sure it doesnt effect our new unit frames and aura system.

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

- When I target myself to test target of target, there is a black bar at the bottom, im not sure what it is. I attached an image of it. I have power bar disabled for this frame.
- I need to be able to place the dungeon role icon on the frames (like tank, dps, healer). I'd also like to only show it based on role (like only show healers and tanks).
- Can we add an optional area like ElvUI's extra info bar, which basically extends the unitframe out vertically to include a new row at the bottom that we can put custom texts with custom textures and what not. defaults off. allow custom texts using ouf tags, allow choice of font, font size, font color (including class color).
- Add the ability to enable/disable masque support for the castbar icons, default it is disabled.

### Texts

### Auras
