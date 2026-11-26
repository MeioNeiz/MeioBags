# Meio Bags

One key deletes your cheapest junk when your bags are full.

For WoW Forever.

![Full bags: before, "Inventory is full."; with Meio Bags, one key press deletes the cheapest
grey stack, Ruined Pelt x5, and says so in chat](docs/before-after.png)

## What it does

Works on install; bind a key for the delete (Esc > Options > Keybindings > AddOns >
MeioBags). Press it when your bags are full: it deletes the junk stack that sells for least,
one per press, and says what went. With the loot window open, it then loots.

- Frees a slot your loot can use: never a reagent bag, soul bag or quiver slot that the
  loot can't go in, even when cheaper junk sits there
- Junk is your grey items, plus any you add with `/meiobags junk`, minus any you protect
  with `/meiobags keep`
- Never deletes quest items, a stack that sells for more than 1 gold, or anything in combat
  or a boss fight
- Opens clams, sacks and unlocked lockboxes for you, one per click or key press; never in
  combat, while looting, at a vendor, bank, mailbox or auction house, or with full bags
- Opening a vendor sells all your junk; hold Shift while opening to skip it
- Baganator marks the same junk in your bags, unless you picked another junk plugin there

![At a vendor: four grey stacks gone from the bags, and in chat "sold 4 junk items for 1
gold 12 silver 97 copper"](docs/vendor.png)

Settings: Esc > Options > AddOns > MeioBags, or `/meiobags`.

- `/meiobags delete`: delete the cheapest junk now
- `/meiobags junk <item>`, `/meiobags keep <item>`: always or never junk (Shift-click the
  item into chat; again to undo)
- `/meiobags list`: your junk and keep lists
- `/meiobags open on|off`: open containers for you
- `/meiobags sell on|off`: sell your junk when you open a vendor
- `/meiobags rxp`: with RestedXP Guides, turn its Inventory Manager off and move its delete
  key and junk marks to Meio Bags (its vendor auto-sell stops too)
- `/meiobags help`

## Coming soon

- Quest leftovers are junk once the quest is done (spare Gnoll Paws): the key deletes them
  first, never while a quest in your log still wants them
- See which junk goes next: a red X on it in Baganator and a line in its tooltip

## Install

Use your addon manager (CurseForge, Wago), or unzip a GitHub release into
`World of Warcraft\_forever_\Interface\AddOns` and restart WoW fully.

## Feedback

Bugs, ideas or just a thumbs up: leave a comment on the CurseForge or Wago page you got it from. [GitHub issues](https://github.com/MeioNeiz/MeioBags/issues) are welcome too.

## More Meio addons

[Meio Trainer Compare](https://www.curseforge.com/wow/addons/trainercompare) | [Meio Next Stop](https://www.curseforge.com/wow/addons/leavebutton) | [Meio Auto Rank](https://www.curseforge.com/wow/addons/meio-autorank) | [Meio Meter Hover](https://www.curseforge.com/wow/addons/meterhover) | [Meio Map](https://addons.wago.io/addons/meiomap) | [Meio Alts](https://addons.wago.io/addons/meioalts) | [Meio DPS](https://addons.wago.io/addons/meiodps) | [Meio Nameplates](https://addons.wago.io/addons/meioplates) | [Meio Hub](https://addons.wago.io/addons/meiohub) | [Meio Pets](https://addons.wago.io/addons/meiopets) | [Meio XP Meter](https://addons.wago.io/addons/meiostats) | [Meio Fixes](https://addons.wago.io/addons/meiofixes) | [Meio Flight Times](https://addons.wago.io/addons/meioflighttimes) | [Meio Tooltips](https://addons.wago.io/addons/meiotooltipfold) | [Meio Autorun](https://addons.wago.io/addons/meioautorunturn) | [Meio Mail](https://addons.wago.io/addons/meiomail) | [Meio QoL](https://addons.wago.io/addons/meioqol) | [Meio TSM Browse](https://addons.wago.io/addons/tsmbrowse) | [Meio Shards](https://addons.wago.io/addons/meioshards) | [Meionomics](https://www.curseforge.com/wow/addons/meionomics) | [Meio Spike Check](https://addons.wago.io/addons/meiospikecheck) | [Meio BiS Extras](https://addons.wago.io/addons/meiobisextras) | [Meio Buff Thanks](https://addons.wago.io/addons/meiobuffthanks) | [Meio Flare Fixes](https://addons.wago.io/addons/meioflarefixes) | [Meio Flare Questie](https://addons.wago.io/addons/meioflarequestie)

## Licence

[MIT](LICENSE)
