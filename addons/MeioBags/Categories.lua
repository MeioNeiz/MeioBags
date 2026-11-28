-- Category view (opt-in, `categories`): items of the normal bags grouped into labelled
-- sections instead of laid out by bag. Each item goes to the first category that takes it:
-- the player's own categories (a name and a search, in the order made), then New, Quest
-- leftovers, Junk, Gear sets, then by item type. Special bags (soul bag, quiver, reagent bag,
-- keyring) keep their own rows, and one empty slot per window stays as a drop target.
local _, ns = ...

local CLASS = Enum and Enum.ItemClass or {}
local function Class(name, fallback) return CLASS[name] or fallback end
local CONSUMABLE, CONTAINER, WEAPON, ARMOR = Class("Consumable", 0), Class("Container", 1),
  Class("Weapon", 2), Class("Armor", 4)
local REAGENT, PROJECTILE, TRADE, RECIPE = Class("Reagent", 5), Class("Projectile", 6),
  Class("Tradegoods", 7), Class("Recipe", 9)
local QUIVER, KEY = Class("Quiver", 11), Class("Key", 13)

local function ClassOf(it) return select(6, C_Item.GetItemInfoInstant(it.id)) end
local function IsClass(...)
  local want = { ... }
  return function(it)
    local c = ClassOf(it)
    for _, w in ipairs(want) do
      if c == w then return true end
    end
    return false
  end
end

local function InSet(it)
  local get = C_Container.GetContainerItemEquipmentSetInfo
  return it.bag ~= nil and get ~= nil and get(it.bag, it.slot) == true
end

-- it: ns.SearchItem's fields (bag and slot nil for a saved copy)
ns.CATEGORIES = {
  { key = "new", name = "New",
    test = function(it) return it.bag ~= nil and C_NewItems.IsNewItem(it.bag, it.slot) == true end },
  { key = "leftover", name = "Quest leftovers",
    test = function(it) return ns.IsLeftover(it.id, it.bag, it.slot) end },
  { key = "junk", name = "Junk",
    test = function(it) return ns.IsJunk(it.id, it.quality, it.bag, it.slot) end },
  { key = "sets", name = "Gear sets", test = InSet },
  { key = "gear", name = "Equipment", test = IsClass(WEAPON, ARMOR) },
  { key = "consumable", name = "Consumables", test = IsClass(CONSUMABLE) },
  { key = "quest", name = "Quest items",
    test = function(it) return ns.IsQuestItem(it.id, it.bag, it.slot) end },
  { key = "trade", name = "Trade goods", test = IsClass(TRADE) },
  { key = "reagent", name = "Reagents", test = IsClass(REAGENT) },
  { key = "recipe", name = "Recipes", test = IsClass(RECIPE) },
  { key = "ammo", name = "Ammo", test = IsClass(PROJECTILE) },
  { key = "bags", name = "Bags", test = IsClass(CONTAINER, QUIVER) },
  { key = "key", name = "Keys", test = IsClass(KEY) },
  { key = "other", name = "Other", test = function() return true end },
}

-- the player's categories, then the defaults: { { name, test } }
local function Ordered()
  local list = {}
  for _, c in ipairs(ns.db.categories) do
    local match = ns.ParseSearch(c.search)
    if match then list[#list + 1] = { name = c.name, test = match } end
  end
  for _, c in ipairs(ns.CATEGORIES) do list[#list + 1] = c end
  return list
end

function ns.CategoryOf(it)
  for _, c in ipairs(Ordered()) do
    if c.test(it) then return c.name end
  end
end

-- bags: the normal bags in bag order; grid: whose Info (live or saved) to read.
-- -> sections of { slots = { { bag, slot } }, label } in category order, then "Empty" with
-- the first free slot
function ns.CategorySections(grid, bags)
  local saved = grid.saved ~= nil
  local order = Ordered()
  local groups = {}
  local firstFree, free
  for _, bag in ipairs(bags) do
    for slot = 1, grid:Size(bag) do
      local info = grid:Info(bag, slot)
      local it = info and ns.SearchItem(bag, slot, info, saved)
      if it then
        for i, c in ipairs(order) do
          if c.test(it) then
            groups[i] = groups[i] or {}
            table.insert(groups[i], { bag, slot })
            break
          end
        end
      else
        free = (free or 0) + 1
        firstFree = firstFree or { bag, slot }
      end
    end
  end
  local sections = {}
  for i, c in ipairs(order) do
    if groups[i] then sections[#sections + 1] = { slots = groups[i], label = c.name } end
  end
  if firstFree then
    sections[#sections + 1] = { slots = { firstFree }, label = ns.RowLabel(EMPTY or "Empty",
      free) }
  end
  return sections
end

-- sections whose first one is the normal bags' unlabelled grid -> that grid split into
-- categories when the category view is on; labelled rows after it stay as they are
function ns.Categorise(grid, sections)
  local first = sections[1]
  if not (ns.db.categoryview and first and first.bags and not first.label) then
    return sections
  end
  local out = ns.CategorySections(grid, first.bags)
  for i = 2, #sections do out[#out + 1] = sections[i] end
  return out
end

-- Regrouping in combat would move the button under the cursor (a potion mid-fight): keep
-- the layout, repaint, and regroup when combat ends.
function ns.HoldCategories(grid)
  if not (ns.db.categoryview and grid.key and InCombatLockdown()) then return false end
  grid:PaintAll()
  grid.waitCombat = true
  return true
end

function ns.SetCategoryView(on)
  ns.SetOption("categoryview", on)
  ns.WindowSettingsChanged()
end

-- the bag window's bottom right button: categories <-> one grid
function ns.CategoryButton(win, right)
  local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
  b:SetSize(84, 20)
  b:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -right + 4, 5)
  b:SetScript("OnClick", function() ns.SetCategoryView(not ns.db.categoryview) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if ns.db.categoryview then
      GameTooltip:SetText("One grid")
      GameTooltip:AddLine("Items as they lie in your bags, normal bags in one grid.", 1, 1, 1,
        true)
    else
      GameTooltip:SetText("Categories")
      GameTooltip:AddLine("Items grouped: new, quest leftovers, junk, gear sets, then by type. "
        .. "Your own categories from a search go first (" .. ns.SLASH .. " category). Bank "
        .. "too.", 1, 1, 1, true)
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  return b
end

------------------------------------------------------------------------------ custom
local function Find(name)
  for i, c in ipairs(ns.db.categories) do
    if c.name:lower() == name:lower() then return i end
  end
end

-- -> true when new, false when changed
function ns.SetCategory(name, search)
  local i = Find(name)
  if i then
    ns.db.categories[i].search = search
  else
    table.insert(ns.db.categories, { name = name, search = search })
  end
  ns.CategoriesChanged()
  return i == nil
end

function ns.RemoveCategory(name)
  local i = Find(name)
  if not i then return nil end
  local c = table.remove(ns.db.categories, i)
  ns.CategoriesChanged()
  return c.name
end

function ns.CategoriesChanged()
  for _, f in ipairs(ns.gridWindows) do
    f.grid:Relayout()
    if f:IsShown() and f.relayout then f.relayout() end
  end
end
