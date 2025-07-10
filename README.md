# ErnRadiantTheft
Unlimited heists from the Thieves Guild.


## Quest Layout

The `ernradianttheft_quest` journal controls the quest status.
- 5: Run once, when the character is rank 1 or higher in the Thieves Guild. This makes sure they have access to the *tip* topic.
- 10: Quest started through dialogue. Give the player a note. This sets persistent state so we'll create the item when the target cell is loaded.
- 20: The item was stolen and the player wasn't caught. Set through script.
- 21: 20 moves to 21 if the player loses the MacGuffin. It moves back to 20 when they pick it up.
- 30: The item was stolen and the player was caught. Set through script.
- 31: 30 moves to 31 if the player loses the MacGuffin. It moves back to 30 when they pick it up.
- 40: The quest expired. Set through script. This exists so jobs can be cycled if they can't be completed.
- 50: Quest completed, goods returned.

One of the issues here is that the MacGuffin might not actually be in the player's inventory when they return it. Set a script on the MacGuffin so if it's inactivated I set the quest to expired (if current status is 20 or 30)?

I'll have to delete the MacGuffin once the quest status hits 40 or 50 via a script.

I'll have to spawn the Note when quest status hits 10.

I'll have to spawn the MacGuffin when the target cell is entered. This can be done by placing the item in an owned container or doing interesting things with chained race traces.

Placing the MacGuffin on NPCs who sell items of that type should be avoided, or the player can just buy the thing. This will bypass the OnTheft handler.

## MacGuffins

These are split into categories. We should cycle through each category once before repeating them. Only one item in a category should be picked to mark that category as completed. The actual item selected shoudn't match anything that the owner sells.

### Blackmail
- `ernradianttheft_incriminatinglet` (book)

### Forgery
- `ernradianttheft_signetring` (clothing)

### Trade Secrets
- `ernradianttheft_ledger` (book)

### Illicit Dwemer Artifacts
- `dwemer_helm` (armor)
- `misc_dwrv_bowl00` Ornate Dwemer Bowl (misc)
- `misc_dwrv_artifact60` Dwemer Tube (misc)

### Skooma
- `ingred_moon_sugar_01` Moon Sugar (ingredient)
- `potion_skooma_01` Skooma (potion)

### Evidence of Necromancy
- `bk_corpsepreperation1_c` Corpse Preparation v I (book)
- `bk_corpsepreperation2_c` Corpse Preparation v II (book)
- `bk_corpsepreperation3_c` Corpse Preparation v II (book)


## The Notes

When we make a note, it contains this info:

- The NPC owner record name.
- Not the actual name of the interior cell, but the name of the cell that a door in the interior points to. This makes it more of a scavenger hunt, since it ends up being the city name. The names of interior cells also don't always follow natural language rules.

