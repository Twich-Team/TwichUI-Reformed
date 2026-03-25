# Feature Ideas

1x TwichUI_Redux/Modules/Toasts/ToastsModule.lua:1042: attempt to index local 'widget' (a nil value)
[TwichUI_Redux/Modules/Toasts/ToastsModule.lua]:1042: in function 'CreatePreyNotificationWidget'
[TwichUI_Redux/Modules/Toasts/ToastsModule.lua]:1054: in function 'SendPreyNotification'
[TwichUI_Redux/Modules/Toasts/ToastsModule.lua]:1451: in function 'TestPreyNotification'
[TwichUI_Redux/Configuration/Options/NotificationPanelOptions.lua]:370: in function '?'
[TwichUI_Redux/Configuration/ModernUI.lua]:2205: in function <...faceTwichUI_Redux/Configuration/ModernUI.lua:2196>

Locals:
self = <table> {
greatVaultState = <table> {
}
wasGrouped = false
modules = <table> {
}
baseName = "TwichUI_Redux"
hasGreatVaultSnapshot = true
hasKeystoneSnapshot = true
defaultModuleState = true
hasFriendSnapshot = true
blizzardFriendToastCVarState = <table> {
}
friendStates = <table> {
}
defaultModuleLibraries = <table> {
}
enabledState = true
name = "TwichUI_Redux_ToastsModule"
orderedModules = <table> {
}
dailyResetTimer = <table> {
}
moduleName = "ToastsModule"
}
preyInfo = <table> {
mapID = 2395
y = 0.500000
x = 0.500000
buttonText = "Set Waypoint"
detailText = "FINAL prey active at 100%. Use the button to place a sample waypoint."
statusText = "PREY READY"
atlasName = "ui-prey-targeticon-final"
titleText = "Nightmare Prey Hunt"
}
widget = nil
(*temporary) = 0.500000
(*temporary) = nil
(*temporary) = nil
(*temporary) = nil
(*temporary) = nil
(*temporary) = nil
(*temporary) = nil
(*temporary) = "attempt to index local 'widget' (a nil value)"
AceGUI = <table> {
objPools = <table> {
}
WidgetBase = <table> {
}
counts = <table> {
}
\_\_MN_PatchedCheckBox = true
LayoutRegistry = <table> {
}
tooltip = AceGUITooltip {
}
WidgetRegistry = <table> {
}
WidgetVersions = <table> {
}
WidgetContainerBase = <table> {
}
}

- Please do another eye-candy refinement pass on teh configuration. Make sure its pretty, clean, modern, and reactive. add hover effects or tooltips where necessary to make it feel alive and well polished.

- error and debugging console
  A central frame that can be used to debug issues with module. it appears with /tui debug. it is Skinned to be styled like the chores frame. Any module can write to it to display output.
- remove the debugging from the gather module and the mythic plus module, move to this new generic debugger.
- ensure each module debug can be enabled or disabled somehow.

- Gathering HUD
  - FarmHUD style map
  - loot notifications
  - gold per hour

- Settings clean up/prettification
  - My addon has grown to include quite a few features, each with their own set of configurations. I like this, as i like to allow people to customize everything to their liking. However the configuration cen be hard to navigate and find specific things. Please take a look at my configuration and create a new version. I would like to maintain all the configuration options, however I would like it to be more intuitive to navigate, prettier to look at, and modern. Please create a new version of it, keeping these ideals in mind. It does not need to be attached to ElvUI. Be inspiried by the Chores tracker frame for styling. I want it to be interactive, informative, reactive, etc. Perhaps even include in-configuration previews of elements, such as when configuring notifications or frames. Dont be afraid to use colors, icons, animations and layer frames to give it that premium-eye candy feel. When this configuraiton frame is not open, ensure that is not degrading performance.

# Minor Changes

- The chore tracker preview is not cloesely showing how the real frame would look. This should be like the interrupt tracker, showing a live preview of the frame and what it would look like with the settings changes. Additionally, the tracker preview does not always appear when i view the tracker frame settings.

- The dispellable glow preview does not work and overflows off the edge of the frame. same as the other previews, it should mimic real.

for the sections within a section, some are aligned so teh left side is at the same location as th left side of its parent, but theres a gap at the right. can we make it so theres a little space at the left adn the right? for example, in weekly and utility, then quest automation, theres a functions section. each section within there, like accept quests, is aligned to the left so the left border of accept quests is aligned with the left border of functions. can we add padding there.

- Make the configuration draggable.
- some sections with sliders (for example, Display Duration in Death Notifications), have numbers above and below the slider which slightly overflow the top and bottom of the "section border"
- for texture selectors, show the actual texture as the background for the row, and the name of the textdure instead of the path
- navigating doesnt seem to be cleanly changing display. for example if i click toa different section, it seems to layer it ontop of whats currently there

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
