## Configuration

## Onboarding & Wizard

- My brother is testing the addon for me. When he installed it, it did not show him the wizard automatically, i had to have him use /tui wizard reset. It should show the first time a person logs into any character (so if he has two characters, it will show once for character 1 and once for character 2). It should also show when I determine players need to re-run the wizard via some override when I update the addon.
- The placement of elements via the layout worked great, except the chat sizing was a little strange. it was too large for him. can we more aggressively scale the chat sizing on different resolutions than my own which created the layout?
- I would like a nice panel to display when players update the addon if i have news or new features to inform them of. This panel should only show once and only when the addon has been updated and only if i provide it information to display to the player. Make it simple for me to add sections to display that information (such as bugs, new features, breaking changes, etc.). This panel should be dismissable by the player, permenantly disableable somewhere in the configuration. Additionally, if its the players first time installing and setting up the addon, this panel will not display until after they complete the wizard process and the final reload finishes.
- Alright so we are going to be adding unit frames to our wizard and layout.
- We need to detect if ElvUI is installed, and if so, have the player choose between TwichUI and ElvUI unit frames. If they choose TwichUI, we need to disable ElvUI unit frames and reload before continuing.
- After they choose a layout, I want them to be provided with some extra customization options:
  - Show a frame for myself in party
  - Show cast bars for party members

### Layouts

- Durability in default Layout
- Muted versions; Fantasy/blizzard versions
- When I change specializations, the chat frame moves

## Chat

- The vertical sizing of non-real chats in dungeons and raids is still not working properly. So for chats by players the vertical hieght of the message frame around each message works perfectly. However, when NPCs speak, or emote, or some addons write to chat, that overflow to a new line, it wont resize the height of the messaage frame, making them overflow over to the next message.

## Notifications

## Datatext

- For the durability text, make the word "Durability" the normal text color, the percentage can be colored by durability remaining still.

## Mythic+

## Apperance

## Other

## Chores

## Errors

- Our error logger is not catching any errors at all

## Fantasy-ification

- I have prepared some texture files that are designed to go around the top left corner of the player's unit frame to decorate it.

## Unit Frames

### General

### Texts

### Auras

- The aura filtering to remove nonsense buffs from myself is not working in raids still. Devotion aura shows on others, and weekly auras and skyriding auras appear on my frame.w

## Bugs for tomorrow

# Mythic+ Minion Checkpoint

- I would like to expand upon our Mythic+ Tools. We currently have a Mythic+ Timer that shows a lot of the information we need for the run. I would like to enhance that tracker by adding minion checkpoints. What this allows is a new section in the configuration that pulls a list of the current season's dungeons. The player can select a dungeon. They will be provided with an interface to configure custom checkpoints. By default, we will provide a checkpoint for each boss. The player can also add additional checkpoints with a name they provide. For each checkpoint, the player can enter a percentage of minions expected to be cleared by the checkpoint. The last boss will always be 100%. Now on the timer, when in that dungeon, the timer updates to have tick marks in the minion bars at each checkpoint. The "Bosses" area becomes "Checkpoints". The Boss function remains the same with the boss name and the time completed/pending, but we will add an extra data point for the minion percentage configured. For custom checkpoints, we will add them to the timer in Checkpoints, in the order of percentage. so if a custom checkpoint is 15%, and boss 1 is 10%, boss 2 is 20%, it will be between boss 1 and boss 2. It will complete with the same animation, coloring, etc as a boss when the percentage is complete. If a boss is killed before the percentage is reached, that percentage is colored red. This is to assist in the amount of trash killed throughout the dungeon. Make a way to test how it works for the player. so on the dungeon configuration for example, add an attached frame with the tracker rendered within in with that dungeons data loaded so they understand what theyre doing. Make it like the other attached panels. Make the configuration within Mythic+ Tools, Add a new subsection called "Minion Checkpoints" within the Mythic+ Timer section, and put the current Mythic+ Timer section in another tab next to it called configuration or something. Also, add checkpoint notifications to the notification system and add the ability to enable or disable it for each checkpoint in the checkpoint configuration.
