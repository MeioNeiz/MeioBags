-- Quest leftovers: quest items a quest you just handed in named (extra Gnoll Paws), once no
-- quest still in your log wants them. No item database: the log's own objectives say what a
-- quest wants. Abandoning never marks (you may take the quest again); a quest starter or an
-- item a log quest names stays a quest item.
local _, ns = ...

local QUEST_CLASS = Enum and Enum.ItemClass and Enum.ItemClass.Questitem or 12

-- questID -> { names = {}, ids = {} }; kept after a quest leaves the log, as
-- QUEST_LOG_UPDATE can come before QUEST_TURNED_IN. inLog: the quests in the log now.
local seen, inLog = {}, {}

-- "Gnoll Paw: 3/8", "3/8 Gnoll Paw", "Gnoll Paw (Complete)" -> "Gnoll Paw"
local function ObjectiveItem(text)
  if type(text) ~= "string" then return nil end
  text = text:gsub("%s*%(.-%)%s*$", ""):gsub(":%s*%d+%s*/%s*%d+%s*$", "")
    :gsub("^%d+%s*/%s*%d+%s+", "")
  text = strtrim(text)
  return text ~= "" and text or nil
end

local function QuestID(i)
  local info = C_QuestLog.GetInfo(i)
  return info and not info.isHeader and info.questID or nil
end

local function Snapshot()
  inLog = {}
  for i = 1, (C_QuestLog.GetNumQuestLogEntries()) do
    local id = QuestID(i)
    if id and id ~= 0 then
      local want = { names = {}, ids = {} }
      for _, o in ipairs(C_QuestLog.GetQuestObjectives(id) or {}) do
        local name = o.type == "item" and ObjectiveItem(o.text)
        if name then want.names[name] = true end
      end
      local link = GetQuestLogSpecialItemInfo and GetQuestLogSpecialItemInfo(i)
      local special = link and C_Item.GetItemInfoInstant(link)
      if special then want.ids[special] = true end
      seen[id], inLog[id] = want, true
    end
  end
end

local function Named(want, itemID, name)
  return want.ids[itemID] or (name ~= nil and want.names[name]) or false
end

local function ItemName(itemID, link)
  return link and link:match("|h%[(.-)%]|h") or C_Item.GetItemNameByID(itemID)
end

-- an item no name is known for counts as wanted: never junk on a guess
function ns.QuestWants(itemID, link)
  local name = ItemName(itemID, link)
  if not name then return true end
  for id in pairs(inLog) do
    if Named(seen[id], itemID, name) then return true end
  end
  return false
end

local function Starter(bag, slot)
  local q = bag and C_Container.GetContainerItemQuestInfo
    and C_Container.GetContainerItemQuestInfo(bag, slot)
  return q ~= nil and q.questID ~= nil
end

-- -> true for a quest item to treat as junk; bag and slot when known
function ns.IsLeftover(itemID, bag, slot)
  local db = ns.db
  if not (db.quest and db.leftover[itemID]) then return false end
  if Starter(bag, slot) then return false end
  local info = bag and C_Container.GetContainerItemInfo(bag, slot)
  return not ns.QuestWants(itemID, info and info.hyperlink)
end

local function EachBagItem(fn)
  for bag = 0, ns.LastBag() do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID then fn(info, bag, slot) end
    end
  end
end

local function TurnedIn(questID)
  local want = questID and seen[questID]
  inLog[questID] = nil
  if not want then return end
  local marked = false
  EachBagItem(function(info, bag, slot)
    local id = info.itemID
    local class = select(6, C_Item.GetItemInfoInstant(id))
    if class ~= QUEST_CLASS or Starter(bag, slot) then return end
    if Named(want, id, ItemName(id, info.hyperlink)) then
      ns.db.leftover[id] = questID
      marked = true
    end
  end)
  if marked then ns.RefreshBags() end
end

-- marks for items no longer in the bags go, once the bags have loaded
local pruned = false
local function Prune()
  if pruned then return end
  local have, any = {}, false
  EachBagItem(function(info)
    have[info.itemID] = true
    any = true
  end)
  if not any then return end
  pruned = true
  for id in pairs(ns.db.leftover) do
    if not have[id] then ns.db.leftover[id] = nil end
  end
end

-- a quest picked up again wants its items again: Baganator's junk marks follow
ns.On("QUEST_LOG_UPDATE", function()
  Snapshot()
  if next(ns.db.leftover) then ns.RefreshBags() end
end)
ns.On("QUEST_TURNED_IN", TurnedIn)
ns.On("BAG_UPDATE_DELAYED", Prune)
