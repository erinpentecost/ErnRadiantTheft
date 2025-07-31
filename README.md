# ErnRadiantTheft

Unlimited heists from the Thieves Guild.

There are unlimited marks to fleece out there in Tamriel. Talk to any Mastermind in the Thieves Guild after getting to Wet Ear rank, and you'll be able to take on heists. Heists will take you all across Tamriel (compatible with all landmass mods) as you attempt to steal valuable artifacts, incriminating letters, skooma, and more. Get the goods without being detected to get a hefty payout when you return to any Mastermind with your loot. The further away the job, the more you get paid.

## Installing

Download the [latest version here](https://github.com/erinpentecost/ErnRadiantTheft/archive/refs/heads/main.zip).

Extract to your `mods/` folder. In your `openmw.cfg` file, add these lines in the correct spots (AFTER *ErnBurglary* files):

```ini
data="/wherevermymodsare/mods/ErnRadiantTheft-main"
content=ErnRadiantTheft.omwaddon
content=ErnRadiantTheft.omwscripts
```

## Heist Cell Selection
It works like this:

1. Get a random list of all possible cells.
2. If the cell was used in the last 10 heists (whether you gave up or not), put it at the end of the list.
3. If the cell is too far away from your configured `Soft Max Distance`, put it at the end of the list.
4. Pick the first item in the list.

## Development

### Adding Heist Cell Targets
Either overwrite cells/default.txt or make a new .txt file that sits next to it.
Lines starting with `#` are comments.
The line is the name of the cell. This can be followed with `!` and then a weight for the cell. The higher the weight, the more often it will be chosen as the target.

### Adding MacGuffins
Add entries to `macguffins.txt`. The first token is the category, which must correspond to matching entries in `l10n/ErnRadiantTheft/en.yaml`. The second token is the type of the item, as defined in the OpenMW Lua API Types package. The third token is the item record id.

### Quest Bonus
The quest bonus is 100 + `ernradianttheft_questbonus`, which is a global variable that has a default value of 1.
You get more gold the higher your rank in the Thieves Guild, the further away the target cell is, and whether or not you were spotted.
