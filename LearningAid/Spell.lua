local LA = LibStub("AceAddon-3.0"):GetAddon("LearningAid",true)

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
function LA:UpdateSpellBook()
  self.spellBookCache = {}
  self.flyoutCache = {}
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
    else
      known = IsSpellKnown(spellGlobalID)
      -- BOOGA -- local spellIsPassive = IsPassiveSpell(i, BOOKTYPE_SPELL) or false
      self.spellBookCache[spellGlobalID] = {
        name = spellName,
        status = spellStatus,
        --subName = subSpellName or "",
        globalID = spellGlobalID,
        -- BOOGA -- passive = spellIsPassive,
        spellBookID = i,
        known = known
      }
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
    table.insert(self.queue, { action = action, id = id, kind = BOOKTYPE_SPELL })
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
    table.insert(self.queue, { action = "FORGET", id = id, kind = BOOKTYPE_SPELL })
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
        table.insert(flyoutChanges, {kind="NEW", spellBookID = i, flyoutID = spellGlobalID, name = flyoutName})
        updated = updated + 1
      else
        old.fresh = true
        if old.known ~= known then
          table.insert(flyoutChanges, {kind="CHANGE", spellBookID = i, flyoutID = spellGlobalID, name=flyoutName})
          updated = updated + 1
        end
      end
    else
      old = cache[spellGlobalID]
      if old == nil then
        updated = updated + 1
        table.insert(changes, {kind="NEW", spellBookID = i, globalID = spellGlobalID, name = spellName})
      else
        old.fresh = true
        local known = IsSpellKnown(spellGlobalID)
        if old.known ~= known then
          updated = updated + 1
          table.insert(changes, {kind="CHANGE", spellBookID = i, globalID = spellGlobalID, name = spellName})
          self:DebugPrint("SOMETHING CHANGED IN THE MATRIX")
          self:DebugPrint("OLD: "..old.name.." "..old.status.." "..old.globalID.." "..old.spellBookID.." "..tostring(old.known))
          self:DebugPrint("NEW: "..spellName.." "..spellStatus.." "..spellGlobalID.." "..i.." "..tostring(known))
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
      table.insert(changes, {kind="REMOVE", spellBookID = v.spellBookID, globalID = v.globalID, name = v.name})
    end
  end
  for k, v in pairs(flyout) do
    if not v.fresh then
      updated = updated + 1
      table.insert(flyoutChanges, {kind="REMOVE", spellBookID = v.spellBookID, flyoutID = v.flyoutID, name = v.name})
    end
  end
  if updated > 0 then
    self:UpdateSpellBook()
    for k, v in ipairs(changes) do
      self:DebugPrint("Spell "..v.spellBookID.." "..v.kind.." "..k.." "..v.globalID.." "..v.name)
      --self:DebugPrint("Old spell removed: "..cache[i].name.." ("..cache[i].subName..") id "..(i))
      if v.kind == "REMOVE" then
        self:RemoveSpell(v.spellBookID)
      --self:DebugPrint("New spell found: "..spellName.." ("..subSpellName..")") -- Old spell: "..cache[i + 1].name.." ("..cache[i + 1].rank..")")
      elseif v.kind == "NEW" then
        self:AddSpell(v.spellBookID, true)
      elseif v.kind == "CHANGE" then
        self:AddSpell(v.spellBookID)
      end
    end
    for k, v in ipairs(flyoutChanges) do
      self:DebugPrint("Flyout "..v.spellBookID.." "..v.kind.." "..k.." "..v.flyoutID.." "..v.name)
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
function LA:LearnSpell(kind, id)
  local frame = self.frame
  local buttons = self.buttons
  for i = 1, self:GetVisible() do
    local button = buttons[i]
    local buttonID = button:GetID()
    if button.kind == kind and buttonID >= id then
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
    local globalID = self:GlobalSpellID(id)
    for slot, oldIDs in pairs(self.character.unlearned[spec]) do
      local actionType = GetActionInfo(slot)
      for oldID in pairs(oldIDs) do
        --local actionType, actionID, actionSubType, globalID = GetActionInfo(slot)
        if oldID == globalID and actionType == nil then
          PickupSpellBookItem(id, BOOKTYPE_SPELL)
          PlaceAction(slot)
          self.character.unlearned[spec][slot][oldID] = nil
        end
      end
    end
  end
end
function LA:ForgetSpell(id)
  local frame = self.frame
  local buttons = self.buttons
  for i = 1, self:GetVisible() do
    local button = buttons[i]
    local buttonID = button:GetID()
    if button.kind == BOOKTYPE_SPELL and buttonID > id then
      button:SetID(buttonID - 1)
      self:UpdateButton(button)
    end
  end
end
