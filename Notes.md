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

- Keybinding not workingb

- Can we make it so that i can resize the columns in the profiler results

- Please add an experience datatext, showing the players experience required to achieve the next level. make the display configurable in the datatext options

- I can see the default blizzard artwork for i think action bars, like the extra action button or vehicle artwork or something flash on and off occasionally.

- Can we add the option to use Dracthyr's Soar to our smart mount for the flying mount?

- I've added Speedy Auto Loot to addonreferences, lets implement our own version within our quality of life. Make it enableable. ensure tto research their implementation because they have TSM destroy workarounds and other things.

- Our experience time tracker seems to count time offline, it should only count time played for each level
