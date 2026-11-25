-- Options panel (Esc > Options > AddOns > MeioBags), slash commands and the public API
local _, ns = ...

local category
local settings = {}

local function Register(key, name)
  local setting = Settings.RegisterAddOnSetting(category, "MEIOBAGS_" .. key:upper(), key,
    ns.db, Settings.VarType.Boolean, name, ns.DEFAULTS[key])
  settings[key] = setting
  return setting
end

local function Checkbox(key, name, tip) Settings.CreateCheckbox(category, Register(key, name), tip) end

local function Header(layout, title, tip)
  if CreateSettingsListSectionHeaderInitializer then
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(title, tip))
  end
end

local function RegisterSettings()
  if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
  local layout
  category, layout = Settings.RegisterVerticalLayoutCategory("MeioBags")
  Header(layout, "Delete key", "One item per press, only when you press the key ("
    .. ns.KEY_PATH .. "), click the button below or type /meiobags delete. Junk: grey items, "
    .. "plus /meiobags junk <item>, minus /meiobags keep <item>. Never in combat, never quest "
    .. "items, never a stack that sells for more than " .. GetMoneyString(ns.MAX_VALUE, true)
    .. ". Baganator marks the same junk when its junk plugin is MeioBags.")
  if ns.HasMeioShards() then
    Checkbox("shards", "Shards first", "A press first deletes the Soul Shards MeioShards "
      .. "counts as extra (above its cap, or loose with a full soul bag). Only once none are "
      .. "left does it delete junk. /meiobags shards on||off does the same.")
  end
  if CreateSettingsButtonInitializer then
    layout:AddInitializer(CreateSettingsButtonInitializer("Cheapest junk item", "Delete now",
      function() ns.DeleteJunk() end, "Deletes the junk stack that sells for least (same as "
      .. "/meiobags delete)." .. (ns.HasMeioShards() and " Soul Shards are left alone." or ""),
      true))
  end
  Header(layout, "Vendors", "Opening a vendor sells all your junk (the same junk as the "
    .. "key, at any value). Hold Shift while opening to skip it.")
  Checkbox("sell", "Sell junk", "Sells your junk when you open a vendor. Turns FlareUI's Sell "
    .. "Junk off, which sells only grey items, kept ones too. /meiobags sell on||off does the "
    .. "same.")
  Header(layout, "Containers", "Clams, sacks and unlocked lockboxes.")
  Checkbox("open", "Open containers", "Bag items that hold loot are opened one at a time, on "
    .. "your next click in the world or key press. Never in combat, while looting, at a "
    .. "vendor, bank, mailbox, trade window or auction house, or with no free bag slot. "
    .. "/meiobags open on||off does the same.")
  Settings.RegisterAddOnCategory(category)
end

ns.On("PLAYER_LOGIN", function()
  local ok, err = pcall(RegisterSettings)
  if not ok then geterrorhandler()(err) end
end)

------------------------------------------------------------------------------ slash
local function Help()
  ns.Say(ns.KeyName() .. " with one key; containers opened for you")
  ns.Line(ns.Cmd(ns.SLASH .. " delete") .. " - delete the cheapest junk item now (not in "
    .. "combat, not quest items, not worth over " .. GetMoneyString(ns.MAX_VALUE, true) .. ")")
  ns.Line(ns.Cmd(ns.SLASH .. " junk <item>") .. " - always junk, whatever the quality "
    .. "(again to undo)")
  ns.Line(ns.Cmd(ns.SLASH .. " keep <item>") .. " - never junk, even if grey (again to undo)")
  ns.Line(ns.Cmd(ns.SLASH .. " list") .. " - the junk and keep lists")
  if ns.HasMeioShards() then
    ns.Line(ns.Cmd(ns.SLASH .. " shards on||off") .. " - the key deletes extra Soul Shards "
      .. "first (now " .. ns.OnOff(ns.db.shards) .. ")")
  end
  ns.Line(ns.Cmd(ns.SLASH .. " sell on||off") .. " - sell your junk when you open a vendor, "
    .. "Shift to skip (now " .. ns.OnOff(ns.db.sell) .. ")")
  ns.Line(ns.Cmd(ns.SLASH .. " open on||off") .. " - open containers on your next click or "
    .. "key press (now " .. ns.OnOff(ns.db.open) .. ")")
  if ns.HasRXP() then
    ns.Line(ns.Cmd(ns.SLASH .. " rxp") .. " - turn RestedXP's Inventory Manager off and move "
      .. "its delete key and junk marks here (its vendor auto-sell stops too)")
  end
  ns.Line(ns.MUTED .. "<item>: Shift-click it into chat, or its item ID. Key: " .. ns.KEY_PATH
    .. "|r")
  ns.Line("Settings: " .. ns.SETTINGS_PATH .. " (" .. ns.Cmd(ns.SLASH .. " settings") .. ")")
end

local function OpenSettings()
  if category then Settings.OpenToCategory(category:GetID()) else Help() end
end

local function Name(id)
  return select(2, C_Item.GetItemInfo(id)) or ("item " .. id)
end

local function List()
  for _, list in ipairs({ "junk", "keep" }) do
    local names = {}
    for id in pairs(ns.db[list]) do names[#names + 1] = Name(id) end
    table.sort(names)
    ns.Say((list == "junk" and "always junk" or "never junk") .. ": "
      .. (#names > 0 and table.concat(names, " ") or ns.MUTED .. "none|r"))
  end
end

local function Set(key, value)
  if settings[key] then settings[key]:SetValue(value) else ns.db[key] = value end
end

SLASH_MEIOBAGS1 = ns.SLASH
SlashCmdList.MEIOBAGS = function(msg)
  local word, arg = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
  word = word:lower()
  if word == "" or word == "settings" or word == "options" then
    OpenSettings()
  elseif word == "help" or word == "?" then
    Help()
  elseif word == "delete" then
    ns.DeleteJunk()
  elseif word == "junk" or word == "keep" then
    local id = tonumber(arg) or tonumber(arg:match("item:(%d+)"))
    if not id then
      ns.Say(word .. " takes an item: Shift-click it into chat, or its item ID")
      return
    end
    if word == "junk" and not ns.db.junk[id] and ns.IsQuestItem(id) then
      ns.Say(Name(id) .. " is a quest item: never junk")
      return
    end
    local on = ns.Mark(word, id)
    local what = word == "junk" and "always junk" or "never junk"
    ns.Say(Name(id) .. (on and (" is now " .. what) or (" is no longer " .. what)))
  elseif word == "list" then
    List()
  elseif word == "rxp" then
    ns.TakeOverRXP()
  elseif (word == "shards" or word == "open" or word == "sell") and (arg == "on" or arg == "off") then
    Set(word, arg == "on")
    local what = { shards = "extra Soul Shards first ", open = "opening containers ",
      sell = "selling junk at vendors " }
    ns.Say(what[word] .. ns.OnOff(arg == "on"))
    if word == "sell" then ns.TakeOverFlare() end
  else
    ns.Say('unknown command "' .. word .. '"')
    Help()
  end
end

function MeioBags_OnAddonCompartmentClick() OpenSettings() end

MeioBags = {
  Key = function() ns.Key() end,
  DeleteJunk = function() ns.DeleteJunk() end,
  IsJunk = function(itemID) return ns.db ~= nil and ns.IsJunk(itemID) end,
  IsKept = function(itemID) return ns.db ~= nil and ns.db.keep[itemID] == true end,
}
BINDING_HEADER_MEIOBAGS = "MeioBags"
BINDING_NAME_MEIOBAGS_DELETE = ns.KeyName()
