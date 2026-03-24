# Feature Ideas

- error and debugging console
  A central frame that can be used to debug issues with module. it appears with /tui debug. it is Skinned to be styled like the chores frame. Any module can write to it to display output.
- remove the debugging from the gather module and the mythic plus module, move to this new generic debugger.
- ensure each module debug can be enabled or disabled somehow.

- Gathering HUD
  - FarmHUD style map
  - loot notifications
  - gold per hour

- Settings clean up/prettification
  - My addon has grown to include quite a few features, each with their own set of configurations. I like this, as i like to allow people to customize everything to their liking. However the configuration cen be hard to navigate and find specific things. Please take a look at my configuration and create a new version. I would like to maintain all the configuration options, however I would like it to be more intuitive to navigate, prettier to look at, and modern. Please create a new version of it, keeping these ideals in mind. It does not need to be attached to ElvUI. Be inspiried by the Chores tracker frame for styling. I want it to be interactive, informative, reactive, etc. Perhaps even include in-configuration previews of elements, such as when configuring notifications or frames. Dont be afraid to use colors, icons, animations and layer frames to give it that premium-eye candy feel.

# Minor Changes

- UnitFrame Tweaks: Custom spark color, make the number of sparks customizable, make the spark height and width customizable.
- On the Chores frame, make the close X icon visible on mouseover when locked.
- On the chores frame, when i click a specific Delve, set a waypoint. add a tooltip to show this functionality.
- For the chores tracker, add an option to only count bountiful delves if i have a key

# Bugs

1x TwichUI_Redux/Configuration/Module.lua:242: Usage: SaveBindings(1||2)
[tail call]: ?
[C]: in function 'SaveBindings'
[TwichUI_Redux/Configuration/Module.lua]:242: in function 'SetChoresTrackerConfigKeybinding'
[TwichUI_Redux/Configuration/Module.lua]:83: in function <TwichUI_Redux/Configuration/Module.lua:61>
[C]: ?
[Masque/Libs/AceAddon-3.0/AceAddon-3.0.lua]:66: in function <...aceMasque/Libs/AceAddon-3.0/AceAddon-3.0.lua:61>
[Masque/Libs/AceAddon-3.0/AceAddon-3.0.lua]:494: in function 'InitializeAddon'
[Masque/Libs/AceAddon-3.0/AceAddon-3.0.lua]:619: in function <...aceMasque/Libs/AceAddon-3.0/AceAddon-3.0.lua:611>

Locals:
