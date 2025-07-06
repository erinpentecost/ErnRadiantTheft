# ErnRadiantTheft
Unlimited theft jobs from the Thieves Guild.

Just ask Aengoth the Jeweler, Big Helende, or Sugar-Lips Habasi for any *tip*s.

## Quest Layout

The `ernradianttheft_quest` journal controls the quest status.
- 10: Quest started through dialogue. Give the player a note. This sets persistent state so we'll create the item when the target cell is loaded.
- 20: The item was stolen and the player wasn't caught. Set through script.
- 30: The item was stolen and the player was caught. Set through script.
- 40: The quest expired. Set through script. This exists so jobs can be cycled if they can't be completed.
- 50: Quest completed, goods returned.

One of the issues here is that the MacGuffin might not actually be in the player's inventory when they return it. Set a script on the MacGuffin so if it's inactivated I set the quest to expired (if current status is 20 or 30)?

I'll have to delete the MacGuffin once the quest status hits 40 or 50 via a script.

I'll have to spawn the Note when quest status hits 10.

I'll have to spawn the MacGuffin when the target cell is entered. This can be done by placing the item in an owned container or doing interesting things with chained race traces.

Placing the MacGuffin on NPCs who sell items of that type should be avoided, or the player can just buy the thing. This will bypass the OnTheft handler.

