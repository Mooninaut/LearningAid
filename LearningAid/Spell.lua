-- Spell.lua

local addonName, private = ...
local LA = private.LA

-- Transforms a spellbook ID into a global spell ID
function LA:GlobalSpellID(id)
  -- CATA --
  -- local link = GetSpellLink(id, BOOKTYPE_SPELL)
  -- if link then
  --   local globalID = string.match(link, "Hspell:([^\124]+)\124")
  --   return tonumber(globalID)
  -- end
  return select(2, GetSpellBookItemInfo(id, BOOKTYPE_SPELL))
end

function LA:UnLinkSpell(link)
  local globalID, name = string.match(link, "Hspell:([^|]+)|h%[([^]]+)%]")
  return name, tonumber(globalID)
end

-- do not modify the return value of this method
function LA:SpellInfo(globalID, name, link, passive)
  local infoCache = self.spellInfoCache
  
  infoCache[globalID] = infoCache[globalID] or {
    name = name or (GetSpellInfo(globalID)),
    passive = passive or IsPassiveSpell(globalID),
    link = link or GetSpellLink(globalID)
  }
  return infoCache[globalID]
end

function LA:UpdateSpellBook()
  
  local infoCache = self.spellInfoCache
  local bookCache = self.spellBookCache
  wipe(bookCache) -- trash generated oh noes
  wipe(self.flyoutCache) -- trash generated oh noes
  local numKnown = 0
  local i = 1
  -- CATA -- local spellName, spellRank = GetSpellBookItemName(i, BOOKTYPE_SPELL)
  -- local spellName, subSpellName = GetSpellBookItemName(i, BOOKTYPE_SPELL)
  local spellName = GetSpellBookItemName(i, BOOKTYPE_SPELL)
  local known
  while spellName do
    -- CATA -- spellRank = tonumber(string.match(spellRank, "%d+")) or 0
    local spellStatus, spellGlobalID = GetSpellBookItemInfo(i, BOOKTYPE_SPELL)
    if spellStatus == "FLYOUT" then
      local flyoutName, flyoutDescription, numFlyoutSpells
      flyoutName, flyoutDescription, numFlyoutSpells, known = GetFlyoutInfo(spellGlobalID)
      self.flyoutCache[spellGlobalID] = {
        name = flyoutName,
        description = flyoutDescription, 
        count = numFlyoutSpells,
        known = known,
        id = spellGlobalID
      }
    else -- not a flyout
      known = IsSpellKnown(spellGlobalID)
      -- invariant info
      self:SpellInfo(spellGlobalID, spellName)
      bookCache[spellGlobalID] = bookCache[spellGlobalID] or { } -- trash not generated yay
      local bookItem = bookCache[spellGlobalID]
      -- variable info
      --bookItem.globalID = spellGlobalID -- redundant
      bookItem.known = known
      bookItem.status = spellStatus
      bookItem.bookID = i
      bookItem.info = infoCache[spellGlobalID] -- convenience link
    end
    i = i + 1
    if known then
      numKnown = numKnown + 1
    end
    spellName = GetSpellBookItemName(i, BOOKTYPE_SPELL)
  end
  i = i - 1
  self:DebugPrint("Updated Spellbook, "..i.." spells found, "..numKnown.." spells known.")
  self.numSpells = i
end

function LA:AddSpell(id, new)
  local action = "SHOW"
  if new then
    action = "LEARN"
  end
  if self.inCombat then
    table.insert(self.queue, { action = action, id = id, kind = BOOKTYPE_SPELL }) -- trash oh noes
  else
    if new then
      self:LearnSpell(BOOKTYPE_SPELL, id)
    end
    if (not self.retalenting) and (not IsPassiveSpell(id, BOOKTYPE_SPELL)) then
      -- Display button with draggable spell icon
      self:AddButton(BOOKTYPE_SPELL, id)
    end
  end
end

function LA:RemoveSpell(id)
  if self.inCombat then
    table.insert(self.queue, { action = "FORGET", id = id, kind = BOOKTYPE_SPELL }) -- trash oh noes
  else
    self:ClearButtonID(BOOKTYPE_SPELL, id)
    self:ForgetSpell(id)
  end
end

function LA:DiffSpellBook()
  local cache = self.spellBookCache
  local flyout = self.flyoutCache
  for k, v in pairs(cache) do
    v.fresh = false
  end
  for k, v in pairs(flyout) do
    v.fresh = false
  end
  local changes = {}
  local flyoutChanges = {}
  local old
  local spellGlobalID
  local spellStatus
  local updated = 0
  -- begin spellbook scan
  local i = 1
  local spellName = GetSpellBookItemName(i, BOOKTYPE_SPELL)
  while spellName do
    spellStatus, spellGlobalID = GetSpellBookItemInfo(i, BOOKTYPE_SPELL)
    if spellStatus == "FLYOUT" then
      local flyoutName, flyoutDescription, numFlyoutSpells, known = GetFlyoutInfo(spellGlobalID)
      old = flyout[spellGlobalID]
      if old == nil then
        updated = updated + 1
        if known then
          table.insert(flyoutChanges, {kind="NEW", bookID = i, flyoutID = spellGlobalID, name = flyoutName}) -- garbage oh noes
        end
      else
        old.fresh = true
        if old.known ~= known then
          -- assuming flyouts can go from unknown to known, but not known to unknown
          table.insert(flyoutChanges, {kind="CHANGE", bookID = i, flyoutID = spellGlobalID, name=flyoutName}) -- garbage oh noes
          updated = updated + 1
        end
      end
    else
      local known = IsSpellKnown(spellGlobalID)
      old = cache[spellGlobalID]
      if old == nil then
        updated = updated + 1
        if known then
          table.insert(changes, {kind="NEW", bookID = i, globalID = spellGlobalID, name = spellName}) -- garbage oh noes
        end
      else
        old.fresh = true
        if old.known ~= known then
          -- assuming spells can go from unknown to known, or known to removed, but not known to unknown
          updated = updated + 1
          table.insert(changes, {kind="CHANGE", bookID = i, globalID = spellGlobalID, name = spellName}) -- garbage oh noes
          self:DebugPrint("CHANGE: name "..spellName.." global "..spellGlobalID.." old status "..old.status.." old bookid "..old.bookID.." old known "..tostring(old.known)
            .." new status "..spellStatus.." new bookid "..i.." new known "..tostring(known))
        end
      end
    end
    i = i + 1
    spellName = GetSpellBookItemName(i, BOOKTYPE_SPELL)
  end
  -- end spellbook scan
  for k, v in pairs(cache) do
    if not v.fresh then
      updated = updated + 1
      table.insert(changes, {kind="REMOVE", bookID = v.bookID, globalID = k, name = v.info.name}) -- garbage oh noes
    end
  end
  for k, v in pairs(flyout) do
    if not v.fresh then
      updated = updated + 1
      table.insert(flyoutChanges, {kind="REMOVE", bookID = v.bookID, flyoutID = v.flyoutID, name = v.name}) -- garbage oh noes
    end
  end
  if updated > 0 then
    self:UpdateSpellBook()
    for k, v in ipairs(changes) do
      self:DebugPrint("Spell name "..v.name.." change "..v.kind.." global "..v.globalID.." bookid "..v.bookID)
      --self:DebugPrint("Old spell removed: "..cache[i].name.." ("..cache[i].subName..") id "..(i))
      if v.kind == "REMOVE" then
        self:RemoveSpell(v.bookID)
      --self:DebugPrint("New spell found: "..spellName.." ("..subSpellName..")") -- Old spell: "..cache[i + 1].name.." ("..cache[i + 1].rank..")")
      elseif v.kind == "NEW" then
        self:AddSpell(v.bookID, true)
      elseif v.kind == "CHANGE" then
        self:AddSpell(v.bookID)
      end
    end
    for k, v in ipairs(flyoutChanges) do
      self:DebugPrint("Flyout "..v.bookID.." "..v.kind.." "..k.." "..v.flyoutID.." "..v.name)
      if v.kind == "REMOVE" then
        -- ?? TODO
      elseif v.kind == "NEW" then
        -- ?? TODO
      elseif v.kind == "CHANGE" then
        -- ?? TODO
      end
    end
  end
  if updated == 0 then updated = false end
  return updated
end

function LA:LearnSpell(kind, bookID)
  local frame = self.frame
  local buttons = self.buttons
  for i = 1, self:GetVisible() do
    local button = buttons[i]
    local buttonID = button:GetID()
    if button.kind == kind and buttonID >= bookID then
      button:SetID(buttonID + 1)
      self:UpdateButton(button)
    end
  end
  local spec = GetActiveTalentGroup()
  if self.saved.restoreActions and
      (not self.retalenting) and
      kind == BOOKTYPE_SPELL and
      self.character.unlearned and
      self.character.unlearned[spec] then
    local globalID = self:GlobalSpellID(bookID)
    for slot, oldIDs in pairs(self.character.unlearned[spec]) do
      local actionType = GetActionInfo(slot)
      for oldID in pairs(oldIDs) do
        --local actionType, actionID, actionSubType, globalID = GetActionInfo(slot)
        if oldID == globalID and actionType == nil then
          PickupSpellBookItem(bookID, BOOKTYPE_SPELL)
          PlaceAction(slot)
          self.character.unlearned[spec][slot][oldID] = nil
        end
      end
    end
  end
end

function LA:ForgetSpell(bookID)
  local frame = self.frame
  local buttons = self.buttons
  for i = 1, self:GetVisible() do
    local button = buttons[i]
    local buttonID = button:GetID()
    if button.kind == BOOKTYPE_SPELL and buttonID > bookID then
      button:SetID(buttonID - 1)
      self:UpdateButton(button)
    end
  end
end
