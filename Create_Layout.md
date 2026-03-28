/tui wizard — open wizard immediately
/tui wizard reset — force it to re-appear on next login
/tui wizard capture [id] [name] — snapshot all registered frame positions

Adding a layout:

Arrange your UI exactly how you want it
Run /tui wizard capture standard_wide "Standard Wide"
View output with /tui debug wizard — copy the Lua table
Paste into AVAILABLE_LAYOUTS in Layouts.lua:84
Bump WIZARD_VERSION
Positions are stored as fractions of screen dimensions (x / screenWidth) so a layout built on your 3440 monitor will scale correctly to any resolution.
