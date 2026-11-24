-- Podric DE Check 0.1.4 for World of Warcraft: Forever (Interface 16001)
-- Completed Auctionator full scans first; Crafter's Journal fallback.
-- Estimates use Classic disenchant brackets, not guaranteed Forever server drops.

local ADDON = ...
local WEAPON, ARMOR = 2, 4
local UNCOMMON, RARE, EPIC = 2, 3, 4

-- Classic reagent IDs. Probabilities refer to complete disenchant outcomes,
-- not independent drops. For uncommon weapons, dust/essence chances swap.
local DUST = {10940, 11083, 11137, 11176, 16204}
local ESSENCE = {10938, 10939, 10998, 11082, 11134, 11135, 11174, 11175, 16202, 16203}
local SHARD = {10978, 11084, 11138, 11139, 11177, 11178, 14343, 14344, 20725}

-- {maximum item level, dust ID, dust min, dust max, essence ID,
--  essence min, essence max, shard ID, dust chance, essence chance, shard chance}
local greens = {
  { 15, DUST[1], 1, 2, ESSENCE[1], 1, 2, nil,      .80, .20, 0 },
  { 20, DUST[1], 2, 3, ESSENCE[2], 1, 2, SHARD[1], .75, .20, .05 },
  { 25, DUST[1], 4, 6, ESSENCE[3], 1, 2, SHARD[1], .75, .15, .10 },
  { 30, DUST[2], 1, 2, ESSENCE[4], 1, 2, SHARD[2], .75, .20, .05 },
  { 35, DUST[2], 2, 5, ESSENCE[5], 1, 2, SHARD[3], .75, .20, .05 },
  { 40, DUST[3], 1, 2, ESSENCE[6], 1, 2, SHARD[4], .75, .20, .05 },
  { 45, DUST[3], 2, 5, ESSENCE[7], 1, 2, SHARD[5], .75, .20, .05 },
  { 50, DUST[4], 1, 2, ESSENCE[8], 1, 2, SHARD[6], .75, .20, .05 },
  { 55, DUST[4], 2, 5, ESSENCE[9], 1, 2, SHARD[7], .75, .20, .05 },
  { 60, DUST[5], 1, 2, ESSENCE[10],1, 2, SHARD[8], .75, .20, .05 },
  {999, DUST[5], 2, 5, ESSENCE[10],2, 3, SHARD[8], .75, .20, .05 },
}
local blues = {
  {25,SHARD[1]}, {30,SHARD[2]}, {35,SHARD[3]}, {40,SHARD[4]},
  {45,SHARD[5]}, {50,SHARD[6]}, {55,SHARD[7]}, {999,SHARD[8]},
}
local epics = {
  {45,SHARD[5],2,4}, {50,SHARD[6],2,4}, {55,SHARD[7],2,4},
  {60,SHARD[9],1,1}, {999,SHARD[9],1,2},
}

local function bracket(brackets, itemLevel)
  for i = 1, #brackets do
    if itemLevel <= brackets[i][1] then return brackets[i] end
  end
end

local function addOutcome(results, materialID, chance, minQuantity, maxQuantity)
  if materialID and chance and chance > 0 then
    results[#results + 1] = {
      id = materialID,
      units = chance * (minQuantity + maxQuantity) / 2,
    }
  end
end

local function getOutcomes(itemLevel, quality, classID)
  if classID ~= WEAPON and classID ~= ARMOR then return nil end
  local results = {}
  if quality == UNCOMMON and itemLevel >= 5 then
    local b = bracket(greens, itemLevel)
    if not b then return nil end
    local dustChance, essenceChance = b[9], b[10]
    if classID == WEAPON then dustChance, essenceChance = essenceChance, dustChance end
    addOutcome(results, b[2], dustChance, b[3], b[4])
    addOutcome(results, b[5], essenceChance, b[6], b[7])
    addOutcome(results, b[8], b[11], 1, 1)
  elseif quality == RARE and itemLevel >= 11 then
    local b = bracket(blues, itemLevel)
    if not b then return nil end
    local nexusChance = (itemLevel > 55) and .005 or 0
    addOutcome(results, b[2], 1 - nexusChance, 1, 1)
    if nexusChance > 0 then addOutcome(results, SHARD[9], nexusChance, 1, 1) end
  elseif quality == EPIC and itemLevel >= 40 then
    local b = bracket(epics, itemLevel)
    if not b then return nil end
    addOutcome(results, b[2], 1, b[3], b[4])
  else
    return nil
  end
  return results
end

-- CJ 0.67+ uses ruleset/faction, not realm/faction (Forever 2026-11-21).
-- Never choose a scan merely because it is newer: other rulesets/factions
-- have different markets. Older CJ releases still use realm/faction.
local function getScan()
  local db = CraftersJournalDB
  if type(db) ~= "table" or type(db.scans) ~= "table" then return nil end
  local faction = UnitFactionGroup and UnitFactionGroup("player")
  if type(faction) ~= "string" or faction == "" then return nil end

  local function scanFor(key)
    if type(key) ~= "string" or key == "" then return nil end
    local scan = db.scans[key]
    if type(scan) == "table" and type(scan.items) == "table" then return scan end
  end

  local mode
  if C_GameRules and type(C_GameRules.GetCurrentGameModeRecordID) == "function" then
    local ok, id = pcall(C_GameRules.GetCurrentGameModeRecordID)
    if ok and type(id) == "number" and id > 0 then mode = id end
  end
  if mode then
    local key = "gm" .. mode .. "-" .. faction
    local scan = scanFor(key)
    if scan then return scan, key end
    -- A migrated CJ database must not fall back to another market.
    if type(db.dataKey) == "table" then return nil, key end
  end

  local realm = GetRealmName and GetRealmName()
  if type(realm) == "string" and realm ~= "" then
    local key = realm .. "-" .. faction
    return scanFor(key), key
  end

  -- CJ remembers the last valid market per faction while the client is
  -- still resolving its game mode. Mirror that fallback, read-only.
  if not mode and type(db.dataKey) == "table" then
    local key = db.dataKey[faction]
    if type(key) == "string" and key:sub(-#faction - 1) == "-" .. faction then
      return scanFor(key), key
    end
  end
  return nil
end


-- Save only relevant material prices from the actual completed full-scan payload.
-- Ordinary searches cannot overwrite this snapshot; both AH-wide modes can.
local materials = {}
for _, ids in ipairs({DUST, ESSENCE, SHARD}) do
  for _, id in ipairs(ids) do materials[id] = true end
end

-- Forever's 21 November client patch can return an empty realm name.
-- The AH market is identified by ruleset and faction, not the underlying realm.
local function marketKey()
  local faction = UnitFactionGroup and UnitFactionGroup("player")
  if type(faction) ~= "string" or faction == "" then return nil end
  if C_GameRules and type(C_GameRules.GetCurrentGameModeRecordID) == "function" then
    local ok, id = pcall(C_GameRules.GetCurrentGameModeRecordID)
    if ok and type(id) == "number" and id > 0 then
      return "gm" .. id .. "-" .. faction
    end
  end
  return nil
end

local function snapshot()
  local key = marketKey()
  if key and type(PodricDECheckDB) == "table" then
    return PodricDECheckDB[key]
  end
end

local listener
local function registerAuctionator()
  if listener then return end
  local a = Auctionator
  if not a or not a.EventBus then return end
  local eventMap, names, active = {}, {}, {}
  for _, kind in ipairs({"FullScan", "IncrementalScan"}) do
    local events = a[kind] and a[kind].Events
    if events and events.ScanStart and events.ScanComplete and events.ScanFailed then
      for _, phase in ipairs({"ScanStart", "ScanComplete", "ScanFailed"}) do
        local event = events[phase]
        eventMap[event] = {kind = kind, phase = phase}
        names[#names + 1] = event
      end
    end
  end
  if #names == 0 then return end
  listener = {ReceiveEvent = function(_, event, rows)
    local meta = eventMap[event]
    if not meta then return end
    local kind, phase = meta.kind, meta.phase
    if phase == "ScanStart" then
      active[kind] = marketKey()
      return
    end
    local key = active[kind]
    active[kind] = nil
    if not key or key ~= marketKey() then return end
    PodricDECheckDB = type(PodricDECheckDB) == "table" and PodricDECheckDB or {}
    local previous = PodricDECheckDB[key]
    if phase == "ScanFailed" then
      previous = type(previous) == "table" and previous or {}
      previous.failed = time()
      PodricDECheckDB[key] = previous
      return
    end
    if type(rows) ~= "table" then return end
    local items = {}
    for _, row in pairs(rows) do
      if type(row) == "table" then
        local id, price
        if kind == "IncrementalScan" then
          id = type(row.itemKey) == "table" and tonumber(row.itemKey.itemID)
          if (tonumber(row.totalQuantity) or 0) > 0 then price = tonumber(row.minPrice) end
        else
          local info = row.auctionInfo or row.replicateInfo
          id = type(row.itemLink) == "string" and tonumber(row.itemLink:match("item:(%d+)"))
          if type(info) == "table" then
            local count, buyout = tonumber(info[3]), tonumber(info[10])
            if count and count > 0 and buyout and buyout > 0 then price = math.ceil(buyout / count) end
          end
        end
        if id and materials[id] and price and price > 0 then
          if not items[id] or price < items[id] then items[id] = price end
        end
      end
    end
    PodricDECheckDB[key] = {time = time(), items = items}
  end}
  a.EventBus:Register(listener, names)
end

local function cjFailed(scan, key)
  local db = CraftersJournalDB
  local fail = key and db and type(db.lastScanFail) == "table" and db.lastScanFail[key]
  return type(fail) == "table" and type(fail.time) == "number"
    and (not scan or type(scan.time) ~= "number" or fail.time > scan.time)
end

local function money(copper)
  copper = math.max(0, math.floor((copper or 0) + .5))
  if GetCoinTextureString then return GetCoinTextureString(copper) end
  local gold = math.floor(copper / 10000)
  local silver = math.floor(copper % 10000 / 100)
  local coins = copper % 100
  return string.format("%dg %ds %dc", gold, silver, coins)
end

local function ageLabel(scan)
  if not scan or type(scan.time) ~= "number" or not time then return "unknown age", false end
  local seconds = math.max(0, time() - scan.time)
  if seconds < 3600 then return math.floor(seconds / 60) .. "m old", false end
  if seconds < 86400 then return math.floor(seconds / 3600) .. "h old", seconds >= 21600 end
  return math.floor(seconds / 86400) .. "d old", true
end

local function itemData(itemReference)
  local fetch = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if type(fetch) ~= "function" then return nil end
  local name, link, quality, itemLevel, _, _, _, _, _, _, vendorPrice, classID = fetch(itemReference)
  if not name or type(itemLevel) ~= "number" or type(vendorPrice) ~= "number" then return nil end
  return quality, itemLevel, vendorPrice, classID
end

local function appendDecision(tooltip, data)
  if not tooltip or not tooltip.AddDoubleLine then return end
  local _, link = tooltip.GetItem and tooltip:GetItem()
  local itemID = link and tonumber(link:match("item:(%d+)"))
  if not itemID and data and type(data.id) == "number" then itemID = data.id end
  if not itemID then return end

  local quality, itemLevel, vendorPrice, classID = itemData(link or itemID)
  if not quality then return end
  local outcomes = getOutcomes(itemLevel, quality, classID)
  if not outcomes then return end

  -- Some tooltip processors call the post-hook more than once for the same item.
  if tooltip.__podricDECheckID == itemID then return end
  tooltip.__podricDECheckID = itemID

  local scan, cjKey = getScan()
  local auction = snapshot()
  tooltip:AddLine(" ")
  tooltip:AddLine("Podric DE Check", .3, .85, 1)
  local expected, missing = 0, {}
  local usedAuction, usedCJ = false, false
  for _, outcome in ipairs(outcomes) do
    local price = auction and type(auction.items) == "table" and tonumber(auction.items[outcome.id])
    if price and price > 0 then
      usedAuction = true
    else
      local row = scan and (scan.items[outcome.id] or scan.items[tostring(outcome.id)])
      price = type(row) == "table" and tonumber(row.minUnit)
      if price and price > 0 then usedCJ = true end
    end
    if price and price > 0 then
      expected = expected + price * outcome.units
    else
      missing[#missing + 1] = outcome.id
    end
  end
  tooltip:AddDoubleLine("Vendor", money(vendorPrice), 1, .85, .3, 1, 1, 1)
  if #missing > 0 then
    expected = math.floor(expected + .5)
    tooltip:AddDoubleLine("Known DE (minimum)", money(expected), 1, .85, .3, 1, 1, 1)
    tooltip:AddLine("Missing " .. #missing .. " material price(s).", 1, .65, .35, true)
    if expected > vendorPrice then
      tooltip:AddDoubleLine("DISENCHANT (partial)", "+" .. money(expected - vendorPrice), .25, 1, .4, .25, 1, .4)
    else
      tooltip:AddLine("No reliable verdict until missing mats are priced.", 1, .65, .35, true)
    end
  else
    expected = math.floor(expected + .5)
    tooltip:AddDoubleLine("Estimated DE", money(expected), 1, .85, .3, 1, 1, 1)
    local difference = math.abs(expected - vendorPrice)
    if expected > vendorPrice then
      tooltip:AddDoubleLine("DISENCHANT", "+" .. money(difference), .25, 1, .4, .25, 1, .4)
    elseif expected < vendorPrice then
      tooltip:AddDoubleLine("VENDOR", "+" .. money(difference), 1, .65, .35, 1, .65, .35)
    else
      tooltip:AddLine("TIE: vendor is guaranteed; DE is random.", .9, .9, .5)
    end
  end
  local function sourceLine(name, source, failed)
    local age, stale = ageLabel(source)
    local suffix = (stale and " (stale)" or "") .. (failed and " (scan failed)" or "")
    local warning = stale or failed or age == "unknown age"
    tooltip:AddLine(name .. " · " .. age .. suffix, warning and 1 or .65, .65, warning and .35 or .65, true)
  end
  if usedAuction then
    sourceLine("Auctionator", auction, auction.failed and auction.failed >= auction.time)
  end
  if usedCJ then
    sourceLine("CJ fallback", scan, cjFailed(scan, cjKey))
  end
  if not usedAuction and not usedCJ then
    tooltip:AddLine("No AH prices; scan Auctionator.", 1, .65, .35, true)
  end
end

local function hookCleared(tooltip)
  if not tooltip or not tooltip.HookScript then return end
  tooltip:HookScript("OnTooltipCleared", function(tip) tip.__podricDECheckID = nil end)
end

local hooked = {}
local function initTooltips()
  local names = {"GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2"}
  for _, name in ipairs(names) do
    local tip = _G[name]
    if tip then hookCleared(tip) end
  end
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
     and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, appendDecision)
  else
    -- Older clients: fallback when TooltipDataProcessor is unavailable.
    for _, name in ipairs(names) do
      local tip = _G[name]
      if tip and not hooked[tip] and tip.HookScript then
        tip:HookScript("OnTooltipSetItem", appendDecision)
        hooked[tip] = true
      end
    end
  end
end

local startup = CreateFrame("Frame")
startup:RegisterEvent("PLAYER_LOGIN")
startup:RegisterEvent("ADDON_LOADED")
startup:SetScript("OnEvent", function(self, event, name)
  if event == "PLAYER_LOGIN" then
    initTooltips()
    registerAuctionator()
    self:UnregisterEvent("PLAYER_LOGIN")
  elseif name == "Auctionator" then
    registerAuctionator()
  end
end)
