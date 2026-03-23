Please create a new Gathering module for me. I have included the addons Farmer and HorizonSuite in the AddOnReferences folder. I am using HorizonSuite for my Minimap. I've also included TSM.

For this module, I would like:

- Farming "hud" radar, where it moves the minimap into the center of the screen, makes it large, adds a circle around it, and makes the terrain transparent. This is liek teh FarmHud addon. The circle's color should be configurable in the module configuration. Ensure you deeply inspect Horizon's Minimap, as it does somethings differently.
- Datatext to view and control this module. It will allow you to toggle the hud on and off, and manage "sessions"
- A session is automatically started when the hud mode is enabled, and paused when disabled.
- A session can be reset, paused or started via a menu on the datatext and click shortcuts (ctl click to reset, shift click to pause)
- A session tracks items looted.
- When a session is active, notifications of gathered items will be sent through the notification system. The notification should appear like the other notifications we have, and the sound and duration should be configurable.
- Use the TSM API to price items looted. Allow the player to configure the price source in configuraiton, using price sources retreived from TSM.
- The notification should show an item link with the item looted, the quantity looted, and the value of the items lootedd. It should also show the total number of the item in your bags and the value of item in your bags (item value \* quantity). On the right side of the frame, show the price source.
- During a session, we also calculate total gold earned and gold per hour. Gold per hour should be updated when new items are looted and every five seconds. Show this value on the datatext during a session.
- Create a gathered item tracking frame. it should be styled similar to the weekly chore frame, so the style matches. it should show the number of items gathered, the total value of each item, the total value of items looted, and the gold per hour. use item links so quality can be seen. make it look nice. this frame should be accessible through the datatext.
- make the datatext configurable as well so it aligns with the rest of the addons configuration.
