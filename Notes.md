## Configuration

## Onboarding & Wizard

### Layouts

Can we add controls to help customize boss frame growth? For example, I'd like the frames centered on my screen. However, if there are more than two, id like for it to create a new column and recenter the frame.

- In raids, I still see my "nonsense" auras, such as devotion aura, or sign of the explorer on my own frame. I also cannot see my Beacon of Light, Beacon of Faith, buffs. I'm using the Helpful filter.

?? Boss frame growth is weird

- Durability in default Layout
- Muted versions; Fantasy/blizzard versions
- When I change specializations, the chat frame moves

- Can we scale the resting and combat icons on the unit frames when we scale the unit frames so theyre not too big? same with the cast bar icon size, and party and raid frames.
- The location of the player power bar was not correct in the wizard. Same with the boss health bars.

1x ...I_Reformed/Modules/QualityOfLife/MythicPlusTools.lua:1290: Usage: EJ_SelectTier(index) Invalid index 1
[tail call]: ?
[C]: in function 'selectTier'
[TwichUI_Reformed/Modules/QualityOfLife/MythicPlusTools.lua]:1290: in function <...I_Reformed/Modules/QualityOfLife/MythicPlusTools.lua:1251>
[TwichUI_Reformed/Modules/QualityOfLife/MythicPlusTools.lua]:1348: in function 'GetDefaultDungeonCheckpoints'
[TwichUI_Reformed/Modules/QualityOfLife/MythicPlusTools.lua]:1399: in function 'NormalizeDungeonCheckpointList'
[TwichUI_Reformed/Modules/QualityOfLife/MythicPlusTools.lua]:1511: in function 'GetDungeonCheckpointConfig'
[TwichUI_Reformed/Modules/QualityOfLife/MythicPlusTools.lua]:1516: in function <...I_Reformed/Modules/QualityOfLife/MythicPlusTools.lua:1515>
[tail call]: ?
[TwichUI_Reformed/Configuration/MythicPlusTools.lua]:42: in function <...s/TwichUI_Reformed/Configuration/MythicPlusTools.lua:40>
[TwichUI_Reformed/Configuration/MythicPlusTools.lua]:192: in function <...s/TwichUI_Reformed/Configuration/MythicPlusTools.lua:149>
[TwichUI_Reformed/Configuration/MythicPlusTools.lua]:520: in function 'func'
[TwichUI_Reformed/Configuration/Module.lua]:114: in function 'RebuildOptionsTableSections'
[TwichUI_Reformed/Configuration/Module.lua]:74: in function <...aceTwichUI_Reformed/Configuration/Module.lua:61>
[C]: ?
[Masque/Libs/AceAddon-3.0/AceAddon-3.0.lua]:66: in function <...aceMasque/Libs/AceAddon-3.0/AceAddon-3.0.lua:61>
[Masque/Libs/AceAddon-3.0/AceAddon-3.0.lua]:494: in function 'InitializeAddon'
[Masque/Libs/AceAddon-3.0/AceAddon-3.0.lua]:619: in function <...aceMasque/Libs/AceAddon-3.0/AceAddon-3.0.lua:611>

Locals:

1x .../TwichUI_Reformed/Libraries/oUF/elements/castbar.lua:116: bad argument #1 to '(for generator)' (table expected, got nil)
[TwichUI_Reformed/Libraries/oUF/elements/castbar.lua]:116: in function <.../TwichUI_Reformed/Libraries/oUF/elements/castbar.lua:111>
[TwichUI_Reformed/Libraries/oUF/elements/castbar.lua]:280: in function <.../TwichUI_Reformed/Libraries/oUF/elements/castbar.lua:188>
[tail call]: ?

Locals:
element = StatusBar {
BottomLeftCorner = Texture {
}
Time = FontString {
}
casting = true
TopLeftCorner = Texture {
}
RightEdge = Texture {
}
spellName = <no value>
castID = 12
Pips = <table> {
}
delay = 0
empowering = true
spellID = <no value>
PixelSnapDisabled = true
holdTime = 0
backdropInfo = <table> {
}
TopRightCorner = Texture {
}
\_\_owner = TwichUIUF_RaidHeaderUnitButton4 {
}
Icon = Texture {
}
smoothing = 1
\_forceHide = true
notInterruptible = <no value>
TopEdge = Texture {
}
Text = FontString {
}
Center = Texture {
}
BottomEdge = Texture {
}
LeftEdge = Texture {
}
BottomRightCorner = Texture {
}
}
stages = nil
isHoriz = true
elementSize = 125.000145
lastOffset = 0
(for state) = nil
(for control) = nil

## Chat

- The vertical sizing of non-real chats in dungeons and raids is still not working properly. So for chats by players the vertical hieght of the message frame around each message works perfectly. However, when NPCs speak, or emote, or some addons write to chat, that overflow to a new line, it wont resize the height of the messaage frame, making them overflow over to the next message.
  '

!!! Distrance fader

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
