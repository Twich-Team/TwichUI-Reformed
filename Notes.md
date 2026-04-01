## Configuration

## Onboarding & Wizard

### Layouts

## Chat

- (Patch Attempted) The vertical sizing of non-real chats in dungeons and raids is still not working properly. So for chats by players the vertical hieght of the message frame around each message works perfectly. However, when NPCs speak, or emote, or some addons write to chat, that overflow to a new line, it wont resize the height of the messaage frame, making them overflow over to the next message.

## Notifications

## Datatext

## Mythic+

- Can we make the notches on the forces bar in the Mythic+ timer slightly less prominent? perhaps take away the top square and make slighly thinner.

## Apperance

## Action Bars

- Can we add a way to disable the border on action bars
- I can still see a housing button from the default microbar.
- I have a trinket on my bar. It's icon is plain until i hover over it. when i hover over it, theres a green border around it. Id rather not have that green part.

## World Quest

## Other

## Chores

## Errors

## Fantasy-ification

- Possibly adding a subtle particle effect to player mana bar
- I added an addon, ProcGlow to the addonreferences. that addon lets you customize the glow with colors, and different glow types. can we do that too.

## Unit Frames

- The party colors i have set to class, however they are using the themes accent color
- THe party and raid frames need to fade out if the the player cannot cast on them. for example in this fight, half the raid gets moved to a different phase, and they cannot be healed. they should be faded. elvui does this.,

- We need to do a performance pass. Please inspect the addon, especially unit frames, auras, and action bars, but not exclusively those, for performance optimizations. we are hitting very high memory usage in combat (over 100mb) and fairly high out of combat (around 22mb, but climbs to around 40). I am also seeing slight lag/glitches/stuttering occasionally.

### General

- Need an indicator for offline and ressurrected players.

### Texts

### Auras

## Bugs for tomorrow

# Mythic+ Minion Checkpoint

# Keybinding

- I have added an addon, Clicked, to the AddOnResources. This addon allows you to essentially create custom keybinds by utilzing macros. I want this functionality in TwichUI. It should be in its own configuration section in the configuration. Please examine Clicked, and recreate the logic natively in TwichUI. Ensure performance and ease of use while maintaining a clean interface.
