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
- Allow particle effects to be used in aura designer (say regrowth shows leaves around unitframe, or BoP shows holy aura)

- Cast bar rules:
  - Define how the cast bar looks for each school of spell or by spell itself; I could have water-themed cast bar for healing spells while having fire for fire spells.

## Unit Frames

- Player frame fantasy art: Show fantasy art for player's class, race. Allow selection of art to show based on specialization. Fade in/out when changing

## Action Bars

- My brother is using my addon and as I was helping him setup his action bars, I noticed that one of his action bars seemed to have a blizzard artwork backdrop texture for each empty button space, while the other bars did not. We do not want that backdrop texture.

## Other

- Transmog Data Text: Provide quick access to your saved transmog outfits
- The TwichUI data text menu shows empty check boxes before the entries "[ ]". We don't need this as nothing is toggle-able, please just make it the available options.

## Interface Designer

I would like to attempt to implement a new level of simplicity to our addon when it comes to custimizing the interface. Currently, we have a nice mover system. I would like to implement what I'm calling the "Interface Designer". This is a mode similar to mover mode that perhaps takes the features of move mode and enhances it. I would like to create a nice simple way for players to customize the modules directly in this designer mode. Say for example if they click on an action bar, they not only get the option to move via nudging, precise placement, snapping and drag and drop, but it will also show most of the configuration for that action bar, allowing them to quickly customize the bar in designer mode. It should show most configuration options for just the bar clicked on, and in a pretty way that matches our theme, and succinctly, optimizing ease and space instead of having a bunch of tabs and scroll. This logic should be similar for unit frames, data panels, etc. There should be a way to toggle party frame test mode, raid frame test mode, as well as add/enable action bars. It would also be perfect if the player selects an action bar, they could choose something like "add bar above" or "add bar below" that would add an action bar snapped to the selected with the settings copied so they appear the same.

- When we select a mover to get its options, can we fade the other movers so they arent as prominent? Also, i would need to be able to see through the selected mover to configure the frame im looking at, say if i were chosing a color or something, that would be obscured by the color of the mover overlay. Maybe when we select the frame, if the mouse is not over the mover or the positioning frame, we change to an outline that adds padding within it and a label of what it is so we can see through?

- For number configurations in the docker, for example the action bar visibile buttons or button size, we currently have toggles to move it up or down, this is good however i would like to be able to click in the middle box where the number is to manually enter a number.

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

## No More ElvUI

### MVP

- Minimap
- Quest Tracker skinning (more horizon styled) (Mythic+ Timer will be integrated into this
- Nameplates
- Blizzard skinning
- Bags (more Baganator styled with categories)
- Buffs/Debuffs
- Tooltips (more horizon styled)

### Completion

- Data bars (reputation, experience)
