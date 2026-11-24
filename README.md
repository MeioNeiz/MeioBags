# Meio Bags

One key deletes your cheapest junk when your bags are full.

![Full bags: before, "Inventory is full."; with MeioBags, one key press deleted the cheapest
grey stack, Ruined Pelt x5, and says so in chat](docs/before-after.png)

## What it does

Bind a key (Esc > Options > Keybindings > AddOns > MeioBags) and press it when your bags are
full: it deletes the junk stack that sells for least, one per press, and says what went.

- Junk is your grey items, plus any you add with `/meiobags junk`, minus any you protect
  with `/meiobags keep`
- Never deletes quest items, a stack that sells for more than 1 gold, or anything in combat
- Opens clams, sacks and unlocked lockboxes for you, one per click or key press; never in
  combat, while looting, at a vendor, bank, mailbox or auction house, or with full bags
- Opening a vendor sells all your junk; hold Shift while opening to skip it
- Baganator marks the same junk in your bags, unless you picked another junk plugin there

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

## Install

Use your addon manager (CurseForge, Wago), or unzip a GitHub release into
`World of Warcraft\_forever_\Interface\AddOns` and restart WoW fully.

## Feedback

Bugs and ideas: [GitHub issues](https://github.com/MeioNeiz/MeioBags/issues)

## More Meio addons

[Meio TrainerCompare](https://www.curseforge.com/wow/addons/trainercompare) | [Meio Next Stop](https://www.curseforge.com/wow/addons/leavebutton) | [Meio AutoRank](https://www.curseforge.com/wow/addons/meio-autorank) | [Meio MeterHover](https://www.curseforge.com/wow/addons/meterhover) | [Meio Map](https://addons.wago.io/addons/meiomap) | [Meio Alts](https://addons.wago.io/addons/meioalts) | [Meio DPS](https://addons.wago.io/addons/meiodps) | [Meio Plates](https://addons.wago.io/addons/meioplates) | [Meio Hub](https://addons.wago.io/addons/meiohub) | [Meio Pets](https://addons.wago.io/addons/meiopets) | [Meio Stats](https://addons.wago.io/addons/meiostats) | [Meio Fixes](https://addons.wago.io/addons/meiofixes) | [Meio Flight Times](https://addons.wago.io/addons/meioflighttimes)

## Licence

[MIT](LICENSE)
