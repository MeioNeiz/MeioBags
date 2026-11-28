# Meio Bags

## 1.3.0

- Quest leftovers are junk once the quest is handed in (spare Gnoll Paws): the key takes them
  first, never while a quest in your log still wants them. `/meiobags quest off`
- The item the key takes next has a red X in Baganator and says so in its tooltip;
  `/meiobags next`
- Bags full while looting: one chat line names the key and what it deletes
- New, try it: your bags in MeioBags' own window (`/meiobags bags` or its key): soul bag,
  quiver and reagent bag in their own rows with free slots, junk and the next delete marked,
  search, sort. Baganator is left as it is
- New, try it: your bank in the same style (`/meiobags bank` at a banker, or
  `/meiobags bankopen on`): one grid or by bag, account bank tabs, search, sort, right-click
  to move items
- Your other characters' bags and bank in the same windows (character button), your bank
  anywhere; item tooltip counts across characters with `/meiobags alttips on`
- Categories view: items grouped by type, junk and new, plus your own from a search
  (`/meiobags category`)

## 1.2.0

- Your loot fits: the key deletes junk from a bag your loot can use first, never a reagent
  bag, soul bag or quiver slot that normal loot can't go in
- With the loot window open, the key loots after the delete
- Never tries to delete in combat or during a boss; in a dungeon that blocks deletes it says
  so once instead of failing

## 1.1.1

- Works with MeioShards (was ShardKeeper)

## 1.1.0

- Opening a vendor sells all your junk (greys and your junk list, never your keep list or quest
  items); hold Shift while opening to skip it. `/meiobags sell on|off` or Settings
- Turns FlareUI's Sell Junk off while on, since it sells only greys, kept ones too

## 1.0.0

- First release: one key deletes your cheapest junk, one stack per press, never quest items,
  junk worth more than 1 gold or anything in combat
- `/meiobags junk` and `keep` lists, Baganator junk marks, clams and sacks opened for you
- `/meiobags rxp`: hands RestedXP's Inventory Manager over (its delete key and junk marks)
