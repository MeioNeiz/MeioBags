-- Search for the bag window. A word matches an item's name, type or subtype; keywords,
-- qualities and item level ranges below. Space or & = and, | = or, ! = not:
-- "junk | !boe & cloth". The same words as Baganator where we have them, so habits carry over.
local _, ns = ...

local QUALITY = { poor = 0, grey = 0, gray = 0, junkgrey = 0, common = 1, white = 1,
  uncommon = 2, green = 2, rare = 3, blue = 3, epic = 4, purple = 4, legendary = 5,
  orange = 5 }

local function Equip(it) return it.equipLoc ~= nil and it.equipLoc ~= "" end

-- it: { id, bag, slot, quality, bound, link } plus item info when cached
local KEYWORDS = {
  junk = function(it) return ns.IsJunk(it.id, it.quality, it.bag, it.slot) end,
  next = function(it) return ns.IsNext and ns.IsNext(it.bag, it.slot) end,
  quest = function(it) return ns.IsQuestItem(it.id, it.bag, it.slot) end,
  leftover = function(it) return ns.IsLeftover(it.id, it.bag, it.slot) end,
  boe = function(it) return Equip(it) and not it.bound end,
  soulbound = function(it) return it.bound end,
  bound = function(it) return it.bound end,
  gear = Equip,
  equipment = Equip,
  new = function(it) return it.bag ~= nil and C_NewItems.IsNewItem(it.bag, it.slot) == true end,
}

local function Term(word)
  local q = QUALITY[word]
  if q then return function(it) return it.quality == q end end
  if KEYWORDS[word] then return KEYWORDS[word] end
  local lo, hi = word:match("^(%d+)%-(%d+)$")
  if lo then
    lo, hi = tonumber(lo), tonumber(hi)
    return function(it) return it.ilvl ~= nil and it.ilvl >= lo and it.ilvl <= hi end
  end
  local op, n = word:match("^([<>])(%d+)$")
  if op then
    n = tonumber(n)
    if op == ">" then return function(it) return it.ilvl ~= nil and it.ilvl > n end end
    return function(it) return it.ilvl ~= nil and it.ilvl < n end
  end
  return function(it)
    for _, text in ipairs({ it.name, it.type, it.subtype }) do
      if text and text:lower():find(word, 1, true) then return true end
    end
    return false
  end
end

local function Negated(word)
  local nots = 0
  while word:sub(1, 1) == "!" do
    nots = nots + 1
    word = word:sub(2)
  end
  if word == "" then return nil end
  local fn = Term(word)
  if nots % 2 == 0 then return fn end
  return function(it) return not fn(it) end
end

-- -> fn(it) -> bool, or nil for an empty search
function ns.ParseSearch(text)
  text = strtrim((text or ""):lower())
  if text == "" then return nil end
  local anyOf = {}
  for part in (text .. "|"):gmatch("([^|]*)|") do
    local allOf = {}
    for word in part:gsub("&", " "):gmatch("%S+") do
      allOf[#allOf + 1] = Negated(word)
    end
    if #allOf > 0 then anyOf[#anyOf + 1] = allOf end
  end
  if #anyOf == 0 then return nil end
  return function(it)
    for _, allOf in ipairs(anyOf) do
      local ok = true
      for _, fn in ipairs(allOf) do
        if not fn(it) then
          ok = false
          break
        end
      end
      if ok then return true end
    end
    return false
  end
end

-- -> the fields a search reads, for the item in bag, slot (nil for an empty slot); saved:
-- info is a saved copy (an alt's bags), so nothing reads the live bag slot
function ns.SearchItem(bag, slot, info, saved)
  info = info or C_Container.GetContainerItemInfo(bag, slot)
  if not info then return nil end
  if saved then bag, slot = nil, nil end
  local name, _, _, ilvl, _, type, subtype, _, equipLoc = C_Item.GetItemInfo(info.itemID)
  return { id = info.itemID, bag = bag, slot = slot, quality = info.quality,
    bound = info.isBound == true, name = name or (info.hyperlink or ""):match("%[(.-)%]"),
    ilvl = ilvl, type = type, subtype = subtype, equipLoc = equipLoc }
end
