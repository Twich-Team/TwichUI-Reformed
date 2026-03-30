## Configuration

## Onboarding & Wizard

- My brother is testing the addon for me. When he installed it, it did not show him the wizard automatically, i had to have him use /tui wizard reset. It should show the first time a person logs into any character (so if he has two characters, it will show once for character 1 and once for character 2). It should also show when I determine players need to re-run the wizard via some override when I update the addon.
- The placement of elements via the layout worked great, except the chat sizing was a little strange. it was too large for him. can we more aggressively scale the chat sizing on different resolutions than my own which created the layout?
- Alright so we are going to be adding unit frames to our wizard and layout.
- We need to detect if ElvUI is installed, and if so, have the player choose between TwichUI and ElvUI unit frames. If they choose TwichUI, we need to disable ElvUI unit frames and reload before continuing.
- After they choose a layout, I want them to be provided with some extra customization options:
  - Show a frame for myself in party
  - Show cast bars for party members
- Make sure the wizard capture does not capture chat history.

### Layouts

- Durability in default Layout
- Muted versions; Fantasy/blizzard versions
- When I change specializations, the chat frame moves

## Chat

- The vertical sizing of non-real chats in dungeons and raids is still not working properly. So for chats by players the vertical hieght of the message frame around each message works perfectly. However, when NPCs speak, or emote, or some addons write to chat, that overflow to a new line, it wont resize the height of the messaage frame, making them overflow over to the next message.

## Notifications

## Datatext

## Mythic+

## Apperance

## Other

## Chores

## Errors

- Our error logger is not catching any errors at all

## Fantasy-ification

- I have prepared some texture files that are designed to go around the top left corner of the player's unit frame to decorate it. There will be a graphic for each class, but for now im developing with just paladin. In the unit frames configuration, add a toggle to enable this artwork. The texture is called Paladin.tga, and measures 250x233 pixels. Im not sure how we will determine how to anchor it due to it needing to align directly with the corner, so i might need a developer tool to print the location after i drag/align it.

- I have added an addon called OpulentCastBars to the addon references folder. This addon is somehow able to make extremely nice looking animations on their cast bar. I want you to add this as a feature to our addon suite. Call it Fantasy Cast Bar. allow players to choose. I want the animation effeccts and colors, however i dont need or want the large texture around the bar, mostly just the nice animations on the cast itself. Lets see what you can do.

## Unit Frames

### General

### Texts

### Auras

- The aura filtering to remove nonsense buffs from myself is not working in raids still. Devotion aura shows on others, and weekly auras and skyriding auras appear on my frame.w

## Bugs for tomorrow

# Mythic+ Minion Checkpoint
