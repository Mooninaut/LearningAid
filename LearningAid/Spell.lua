--[[

Learning Aid version 1.12
Compatible with World of Warcraft version 5.0.4
Learning Aid is copyright � 2008-2012 Jamash (Kil'jaeden US Horde)
Email: jamashkj@gmail.com

Spell.lua is part of Learning Aid.

  Learning Aid is free software: you can redistribute it and/or modify
  it under the terms of the GNU Lesser General Public License as
  published by the Free Software Foundation, either version 3 of the
  License, or (at your option) any later version.

  Learning Aid is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with Learning Aid.  If not, see
  <http://www.gnu.org/licenses/>.

To download the latest official version of Learning Aid, please visit 
either Curse or WowInterface at one of the following URLs: 

http://wow.curse.com/downloads/wow-addons/details/learningaid.aspx

http://www.wowinterface.com/downloads/info10622-LearningAid.html

Other sites that host Learning Aid are not official and may contain 
outdated or modified versions. If you have obtained Learning Aid from 
any other source, I strongly encourage you to use Curse or WoWInterface 
for updates in the future. 

]]

local addonName, private = ...
local LA = private.LA

-- Transforms a spellbook ID into a global spell ID
function LA:SpellGlobalID(id)
  -- CATA --
  -- local link = GetSpellLink(id, BOOKTYPE_SPELL)
  -- if link then
  --   local globalID = string.match(link, "Hspell:([^\124]+)\124")
  --   return tonumber(globalID)
  -- end
  return select(2, GetSpellBookItemInfo(id, BOOKTYPE_SPELL))
end

function LA:UnlinkSpell(link)
  local globalID, name = string.match(link, "Hspell:([^|]+)|h%[([^]]+)%]")
  return name, tonumber(globalID)
end

-- do not modify the return value of this method
function LA:SpellInfo(globalID)
  local infoCache = self.spellInfoCache
  if not infoCache[globalID] then
		local name, subName = GetSpellInfo(globalID)
		infoCache[globalID] = {
			name = name,
			subName = subName,
			passive = IsPassiveSpell(globalID) and true or false, -- coerce to boolean
			link = GetSpellLink(globalID),
      globalID = globalID
		}
	end
  return infoCache[globalID]
end

-- do not modify the return value of this method
-- caller must specify spellOrigin when this method is called for a spell not already in the cache
function LA:SpellBookInfo(spellBookID, spellOrigin)
  local bookCache = self.spellBookCache
  local spellStatus, spellGlobalID = GetSpellBookItemInfo(spellBookID, BOOKTYPE_SPELL)
  if spellOrigin and not bookCache[spellGlobalID] then
    bookCache[spellGlobalID] = {
      known = IsSpellKnown(spellGlobalID) and true or false, -- coerce to boolean
      status = spellStatus,
      bookID = spellBookID,
      origin = spellOrigin,
      info = self:SpellInfo(spellGlobalID) -- convenience reference
    }
  end
  return bookCache[spellGlobalID]
end

-- do not modify the return value of this method
function LA:FlyoutInfo(flyoutID)
  local flyoutCache = self.flyoutCache
  --local flyoutID = select(2, GetSpellBookItemInfo(spellBookID, BOOKTYPE_SPELL))
  if not flyoutCache[flyoutID] then
    local flyoutName, flyoutDescription, numFlyoutSpells, flyoutKnown = GetFlyoutInfo(flyoutID)
    flyoutCache[flyoutID] = {
      known = flyoutKnown,
      name = flyoutName,
      count = numFlyoutSpells,
      description = flyoutDescription--,
      --bookID = spellBookID
    }
  end
  return flyoutCache[flyoutID]
end

function LA:UpdateSpellBook()
  local infoCache = self.spellInfoCache
  local bookCache = self.spellBookCache
  wipe(bookCache) -- trash generated oh noes
  wipe(self.flyoutCache) -- trash generated oh noes
  -- { Primary1, Primary2, Archaeology, Fishing, Cooking, First Aid }
  local total = 0
  local professions = { GetProfessions() }
  local numKnown = 0
  for i = 1, self.numProfessions do
    if professions[i] then
      local name, texture, rank, maxRank, numSpells, spellOffset, skillLine, rankModifier = GetProfessionInfo(professions[i])
      for k = spellOffset + 1, spellOffset + numSpells do
         self:SpellBookInfo(k, self.origin.profession)
         numKnown = numKnown + 1
         total = total + 1
      end
    end
  end
  local racial = self:SpellInfo(self.racialSpell).subName
  local racialPassive = self:SpellInfo(self.racialPassiveSpell).subName
  for i = 1, GetNumSpellTabs() do
    local tabName, tabTexture, tabOffset, tabSpells, tabIsGuild = GetSpellTabInfo(i)
    for k = tabOffset + 1, tabOffset + tabSpells do
      local spellStatus, spellGlobalID = GetSpellBookItemInfo(k, BOOKTYPE_SPELL)
      if spellStatus == "FLYOUT" then
        -- flyout spells are not included in the regular spell tabs, they're in gaps between the index
		-- one tab ends at and the index the next tab starts
        local flyoutID = spellGlobalID
        local flyoutInfo = self:FlyoutInfo(flyoutID)
        for f = 1, flyoutInfo.count do
          local flyoutSpellID, isKnown = GetFlyoutSlotInfo(flyoutID, f)
          -- all flyout spells are class-based as of 4.1.0
          local bookID = FindSpellBookSlotBySpellID(flyoutSpellID)
          if bookID then -- non-known flyout spells don't have book ids
            self:SpellBookInfo(bookID, self.origin.class)
            numKnown = numKnown + (isKnown and 1 or 0)
            total = total + 1
          end
        end
      else
        local info = self:SpellInfo(spellGlobalID)
        local bookInfo = self:SpellBookInfo(k,
          tabIsGuild and self.origin.guild or
          (info.subName == racial or info.subName == racialPassive) and self.origin.race or
          self.ridingSpells[spellGlobalID] and self.origin.riding or
          self.origin.class
        )
        numKnown = numKnown + (bookInfo.known and 1 or 0)
      end
      total = total + 1
    end
  end
  self:DebugPrint("Updated Spellbook, "..total.." entries found, "..numKnown.." spells known.")
  self.numSpells = total
end
function LA:UpdateGuild()
  if IsInGuild() then
    local guildName = GetGuildInfo("player")
    if guildName and guildName:len() > 0 and self.character.guild ~= guildName then
      self.character.guild = guildName
      self.character.guildSpells = { }
    end
    return true
  else
    self.character.guild = nil
    self.character.guildSpells = nil
    return false
  end
end
-- true if spell is known, false if spell is not know, nil if not in a guild
function LA:GuildSpellKnown(globalID)
  return self:UpdateGuild() and (self.character.guildSpells[globalID] and true or false) or nil
end
-- if new is true, a spell has been added to the spellbook
-- if new is false, an existing spell has been newly learned
function LA:AddSpell(bookID, new)
  local action = "SHOW"
  if new then
    action = "LEARN"
  end
  if InCombatLockdown() then
    table.insert(self.queue, { action = action, id = bookID, kind = BOOKTYPE_SPELL }) -- trash oh noes
  else
    if new then
      self:LearnSpell(BOOKTYPE_SPELL, bookID)
    end
    local bookInfo = self:SpellBookInfo(bookID)
    if (not self.state.retalenting) and
       (not bookInfo.info.passive) and
       (not self:GuildSpellKnown(bookInfo.info.globalID))
    then
      -- Display button with draggable spell icon
      if bookInfo.origin == self.origin.guild then
        self:DebugPrint("Found Guild Spell",bookInfo.info.globalID,bookInfo.info.name,time())
        self.character.guildSpells[bookInfo.info.globalID] = true
      else
	    self:AddButton(BOOKTYPE_SPELL, bookID)
      end
	  
    end
  end
end

-- a spell has been removed from the spellbook
function LA:RemoveSpell(id)
  if InCombatLockdown() then
    table.insert(self.queue, { action = "FORGET", id = id, kind = BOOKTYPE_SPELL }) -- trash oh noes
  else
    self:ClearButtonID(BOOKTYPE_SPELL, id)
    self:ForgetSpell(id)
  end
end

function LA:DiffSpellBook()
  -- swap caches
  self.oldSpellBookCache, self.spellBookCache = self.spellBookCache, self.oldSpellBookCache
  self:UpdateSpellBook()
  local old = self.oldSpellBookCache
  local new = self.spellBookCache
  local updated = 0
  for newID, newItem in pairs(new) do -- look for things learned
    if newItem.known then
      if not old[newID] then -- spell added to spellbook
        self:AddSpell(newItem.bookID, true)
        updated = updated + 1
      elseif not old[newID].known then -- spell changed from unkown to known
        self:AddSpell(newItem.bookID)
        updated = updated + 1
      end
    end
  end
  for oldID, oldItem in pairs(old) do -- look for things forgotten
    if oldItem.known then
      if not new[oldID] then
        self:RemoveSpell(oldItem.bookID)
        updated = updated + 1
      elseif not new[oldID].known then
        self:DebugPrint("Warning: Spell "..oldItem.info.name.." with globalID "..oldID.." forgotten but not removed!")
        updated = updated + 1
      end
    end
  end
  if updated > 1 then
    self:DebugPrint("Warning: Multiple updates ("..updated..") in DiffSpellBook detected!")
  end
  -- TODO: Detect flyout changes (right now the spell button can't handle flyouts)
  return updated
end

-- A new spellbook ID has been added, bumping existing spellbook IDs up by one
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
  local spec = GetActiveSpecGroup()
  if self.saved.restoreActions and
      (not self.state.retalenting) and
      kind == BOOKTYPE_SPELL and
      self.character.unlearned and
      self.character.unlearned[spec] then    
    local globalID = self:SpellBookInfo(bookID).info.globalID
    for slot, oldIDs in pairs(self.character.unlearned[spec]) do
      local actionType = GetActionInfo(slot) -- local actionType, actionID, actionSubType, globalID = GetActionInfo(slot)
      for oldID in pairs(oldIDs) do
        if oldID == globalID and actionType == nil then
          PickupSpellBookItem(bookID, BOOKTYPE_SPELL)
          PlaceAction(slot)
          self.character.unlearned[spec][slot][oldID] = nil
        end
      end
    end
  end
end

-- An old spellbook ID has been deleted, shifting spellbook IDs down by one
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
