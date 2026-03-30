### Version 0.0.3 [ March ------- 2026 ]

#### BugFixes

- Fixed an issue where the Skyreach seasonal teleport was not available within any teleports menu
- Fixed an issue that caused tabs in the debugger to show as different colors
- Fixed an issue that caused Battle.Net tells to appear in the whisper color
- Fixed an issue that caused the accent on the chat edit box to not change to the channel color

#### New

- Made it more visually obvious when teleports are on a cooldown in any teleports menu
- TwichUI unit frames: oUF based unit frames provided by the addon with an initial set of customization options
  - Futher customization options will be released as the addon matures. Advanced and guided aura customization is planned
  - Added a section to the debugger specific to unit frames
  - Aura Watch Designer: Drag-and-drop auras and generic filters to one of six slots. Each slot can be individually configured with various effects to unit frames for which any of the auras or filters apply to.
  - Aura filtering: attempts to filter out nonsense auras (Events, Paladin Auras, etc.)
- New layout: Class Fantasy. This layout favors flair over simplicity, and adds several subtle (and a couple not-so-subtle) class fantasy additions to the interface, providing a more fantasy feel
- Added a button to access the debugger from the configuration interface
- Added logic to attempt to smartly place the newly opened Debugger or Error Log frames around the configuration UI
- Added chat history persistence across reloads

#### Other

- Tech Debt: Removed deprecated ElvUI configuration
- Tech Debt: Removed legacy Unit Frame tweaks section from the configuration.
