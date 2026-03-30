## Configuration

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

## Notifications

- For the satchel watch notification, we have icons for dps, heal, and tank. can we add a selector to allow to choose between blizzard and the twichui variants? Like we have in the unit frame role icons.

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

notes

- remove overheal from player plate
- make threat glow less
- tank frames are covered by boss timers
- the filter for uselss buffs went away in combat (devotion aura shows on everyone, i get all the nonsense)

### Texts

### Auras

## Bugs for tomorrow

- Alright so we are going to be adding unit frames to our wizard and layout.
- We need to detect if ElvUI is installed, and if so, have the player choose between TwichUI and ElvUI unit frames. If they choose TwichUI, we need to disable ElvUI unit frames and reload before continuing.
- After they choose a layout, I want them to be provided with some extra customization options:
  - Show a frame for myself in party
  - Show cast bars for party members

# Mythic+ Minion Checkpoint

- I would like to expand upon our Mythic+ Tools. We currently have a Mythic+ Timer that shows a lot of the information we need for the run. I would like to enhance that tracker by adding minion checkpoints. What this allows is a new section in the configuration that pulls a list of the current season's dungeons. The player can select a dungeon. They will be provided with an interface to configure custom checkpoints. By default, we will provide a checkpoint for each boss. The player can also add additional checkpoints with a name they provide. For each checkpoint, the player can enter a percentage of minions expected to be cleared by the checkpoint. The last boss will always be 100%. Now on the timer, when in that dungeon, the timer updates to have tick marks in the minion bars at each checkpoint. The "Bosses" area becomes "Checkpoints". The Boss function remains the same with the boss name and the time completed/pending, but we will add an extra data point for the minion percentage configured. For custom checkpoints, we will add them to the timer in Checkpoints, in the order of percentage. so if a custom checkpoint is 15%, and boss 1 is 10%, boss 2 is 20%, it will be between boss 1 and boss 2. It will complete with the same animation, coloring, etc as a boss when the percentage is complete. If a boss is killed before the percentage is reached, that percentage is colored red. This is to assist in the amount of trash killed throughout the dungeon.
