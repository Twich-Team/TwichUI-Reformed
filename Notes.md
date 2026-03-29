## Configuration

"Signature"
"The original TwichUI layout, optimized for any role and class."

## Onboarding & Wizard

### Layouts

- Durability in default Layout
- Muted versions

## Chat

- Battle net whispers are colored the same color as normal whispers, can we make them the battle net tell color
- Not seeing incoming messages during boss fights

## Notifications

## Datatext

## Mythic+

## Apperance

## Other

## Chores

## Errors

- Our error logger is not catching any errors at all

## Unit Frames

- I need to be able to filter auras
- I would like an option to show bars for auras instead of the icons on a unit frame type basis.
- I need to be able to configure the target and boss cast bars
- I need to be able to set the frame textures
- I do not see the smoothing options in config and the cast bar does not look smooth, so how do i enable it
- I am in a party and i do not see party frames

---

- I need to be able to position texts in different places on the frame (for example anchor point, offset, etc.).
- Need to be able to set a font for each frame type
- I think instead of the "text" "colors" "health colors" options outside, they need to be inside each single unit and each group unit. so they can be customized
- Need castbar for bosses, target, party
- I need to be able to configure the frame width and height separate of the cast or class bar
- I need class bars
- I need to be able to detach class bar, power bar, cast bar for custom positioning and sizing.
- Again, look at ElvUI for all the configuration options, we need at minimum the capability of elvui.
- The player cast bar does not have configuration options and is not smooth
- The class color selector only shows all the frames as my class color, not the color of the class they represent.

Overall, this implementation is severely lacking and needs to be rethought. Ensure performance is top priority and customization is dramatically improved.

- a lot of things just arent working
- power color isnt working, its always black
- class bar isnt very customizable
- the cast bar is not smooth
- the texts on the party frames are all abbreviated
- I need to be able to set the font outline/shadow for each frame set
- Class colors are still not representing the class of the player the bar is representing
- a lot of things dont live update when i change them
- i dont see the aura bars, or how to setup aura filters
- how do i setup party and raid frames as a healer to show debuffs i can dispell or need to watch for
- this is still just missing a lot that elvui has, which i have asked several times to have at least the same features,if not more. We want to be better than ElvUI. I should be able to configure this to look amazing, but it already has sensible defaults.
- i should be able to set custom texts
- theres no way to test castbars of say bosses

- Each unit frame group has a lot of settings, please separate these logically by creating sub groups/tabs/lists so its easier to find settings.
- The moves always say enabled and i cannot move the bars
- The cast bar is still not smooth.
- can you create an oUF tag string reference panel and have it appear to the right of the configuration frame when editing the unit frames settings. In a similar fashion to how we do the previews, but this will be a reference of the avialable tags and what they do.

- The test frames are always bright green regardless of my color settings; the test mode should mimic what they will actually look like. look at how elvui does it.
- Add a show power bar for healers only option for each type
- Add an option to show an extra/info bar for each type (like elvui, just a section that can hold texts and be themed)
