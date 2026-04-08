#

- Leave vehicle
- ✅ The text "Right click for frame settings" is still on the tooltip. Get rid of the tooltip text for the unit frames. keep the right click functionality

## Configuration

- Enhanced search: Can we refactor our configuration UI search function to intelligently search the entire configuration for the keyword instead of just the section title. For example, If i were to search for "power" it might offer me power bar options for player, target, etc. It should clearly group the search results so the player understands what that configuration is for. For example, they should be able to tell that when they searched for power, the first result was for player power, not target power.

## Wizard

- Test wizard process
- Wizard is not properly disabling the primary ElvUI chat background
- Wizard should also disable the right side ElvUI chat background

## Mythic+

## Fantasy-ification

- Allow the option of using class icon as the resting and/or combat indicator on the player frame
- Highlight friend in raid groups

- In our attempts to fix issues with the interface designer, we made the background of our shared secure menu 100% opaque, can we please bring back slight transparency so the menus look nice.

## Unit Frames

- Player frame fantasy art: Show fantasy art for player's class, race. Allow selection of art to show based on specialization. Fade in/out when changing

## Action Bars

## Other

## Interface Designer

## Quality of Life

- Automatically vendor grays (and eventually smarter logic to vendor low ilvl, etc.)
- Automatically accept group invites from friends and/or guild mates
- Auto accept queue
- Horizon-esque quest, location headers
- Complete custom keybinding system (quick-binds, advanced binds, spec binds, etc.)
- Dynamic flight HUD
- Essential auction tools (quick post, grab all mail)
- Sanity tools
  - Suppress ping spam
  - Supresses noises (Calamatous Carrion, etc.)
- Group filtering tools
- Loot feed

## No More ElvUI

### MVP

- Minimap
- World map
- Quest Tracker skinning (more horizon styled) (Mythic+ Timer will be integrated into this
- Nameplates
- Blizzard skinning
- Bags (more Baganator styled with categories)
  I have added an addon to AddOnReferences called Baganator. Today we will implement our own bag system to replace ElvUI and Baganator. I very much like baganator's ability to categorize the items in your bags to show separate groups and keep it organized, as well as its feature to show new items. I would like to closely mimic this functionality, while making it customizable, more performant, and adhering to our eye-candy and twichui established styling. Please analyze baganator for its features andd methods of implementation, and implement our own bag system. It should have its own configuration section in our configuration UI, be draggable, etc. We should also have optional masque support for item icons in the bags
- Buffs/Debuffs
- Tooltips (more horizon styled)

### Completion

- Data bars (reputation, experience)

## PERFORMANCE WED APR 8

- Keybinding not working

- Can we make it so that i can resize the columns in the profiler results

- Please add an experience datatext, showing the players experience required to achieve the next level. make the display configurable in the datatext options

- I can see the default blizzard artwork for i think action bars, like the extra action button or vehicle artwork or something flash on and off occasionally.

1x [ADDON_ACTION_BLOCKED] AddOn 'TwichUI_Reformed' tried to call the protected function 'Frame:SetParent()'.
[!BugGrabber/BugGrabber.lua]:540: in function '?'
[!BugGrabber/BugGrabber.lua]:524: in function <!BugGrabber/BugGrabber.lua:524>
[C]: in function 'SetParent'
[TwichUI_Reformed/Modules/ChatEnhancements/ChatRenderer.lua]:2236: in function 'RefreshFrame'
[TwichUI_Reformed/Modules/ChatEnhancements/ChatStyling.lua]:2875: in function 'ApplyChatFonts'
[TwichUI_Reformed/Modules/ChatEnhancements/ChatStyling.lua]:2972: in function 'RefreshAllVisuals'
[TwichUI_Reformed/Modules/ChatEnhancements/ChatStyling.lua]:3030: in function 'HandleLifecycleRefresh'
[TwichUI_Reformed/Modules/ChatEnhancements/ChatStyling.lua]:3049: in function '?'
[!!AddonProfiler/libs/CallbackHandler-1.0/CallbackHandler-1.0.lua]:109: in function <...ler/libs/CallbackHandler-1.0/CallbackHandler-1.0.lua:109>
[C]: ?
[!!AddonProfiler/libs/CallbackHandler-1.0/CallbackHandler-1.0.lua]:19: in function <...ler/libs/CallbackHandler-1.0/CallbackHandler-1.0.lua:15>
[!!AddonProfiler/libs/CallbackHandler-1.0/CallbackHandler-1.0.lua]:54: in function 'Fire'
[ElvUI_Libraries/Game/Shared/Ace3/AceEvent-3.0/AceEvent-3.0.lua]:120: in function <...aries/Game/Shared/Ace3/AceEvent-3.0/AceEvent-3.0.lua:119>

Locals:
self = <table> {
}
event = "ADDON_ACTION_BLOCKED"
addonName = "TwichUI_Reformed"
addonFunc = "Frame:SetParent()"
name = "TwichUI_Reformed"
badAddons = <table> {
TwichUI_Reformed = true
}
L = <table> {
NO_DISPLAY_2 = "|cffffff00The standard display is called BugSack, and can probably be found on the same site where you found !BugGrabber.|r"
ERROR_DETECTED = "%s |cffffff00captured, click the link for more information.|r"
BUGGRABBER_STOPPED = "|cffffff00There are too many errors in your UI. As a result, your game experience may be degraded. Disable or update the failing addons if you don't want to see this message again.|r"
USAGE = "|cffffff00Usage: /buggrabber <1-%d>.|r"
STOP_NAG = "|cffffff00!BugGrabber will not nag about missing a display addon again until next patch.|r"
NO_DISPLAY_STOP = "|cffffff00If you don't want to be reminded about this again, run /stopnag.|r"
NO_DISPLAY_1 = "|cffffff00You seem to be running !BugGrabber with no display addon to go along with it. Although a slash command is provided for accessing error reports, a display can help you manage these errors in a more convenient way.|r"
ERROR_UNABLE = "|cffffff00!BugGrabber is unable to retrieve errors from other players by itself. Please install BugSack or a similar display addon that might give you this functionality.|r"
ADDON_CALL_PROTECTED = "[%s] AddOn '%s' tried to call the protected function '%s'."
}

w
