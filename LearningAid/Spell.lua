--[[

Learning Aid is copyright © 2008-2014 Jamash (Kil'jaeden US Horde)
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
-- GetSpellLink(bookID, "spell") will return current spec link, which will fail when fed to IsSpellKnown and company
function LA:UnlinkSpell(link)
  assert(link, "LearningAid:UnlinkSpell(link): bad link", tostring(link))
  local globalID, name = string.match(link, "Hspell:([^|]+)|h%[([^]]+)%]")
  return name, tonumber(globalID)
end
function LA:RealSpellBookItemInfo(spellBookID, bookType)
  -- returns status, globalID, spec-specific name, spec-specific globalID
  if not bookType then bookType = BOOKTYPE_SPELL end
  assert(spellBookID and spellBookID > 0, "LearningAid:RealSpellBookItemInfo(spellBookID [, bookType]): bad spellBookID")
  local spellStatus, spellGlobalID = GetSpellBookItemInfo(spellBookID, bookType)
  if "SPELL" == spellStatus or "FUTURESPELL" == spellStatus then
    return spellStatus, spellGlobalID, self:UnlinkSpell(GetSpellLink(spellBookID, bookType))
  end
  return spellStatus, spellGlobalID
  -- specSpellName, specSpellGlobalID
end
-- do not modify the return value of this method
function LA:SpellInfo(globalID)
  --[[assert(globalID, "LearningAid:SpellInfo(globalID): bad globalID")
  local spellCache = self.spellCache
  spellCache[globalID] = spellCache[globalID] or { }
		local name, subName = GetSpellInfo(globalID)
		spellCache[globalID] = {
			name = name,
			subName = subName,
			passive = IsPassiveSpell(globalID) and true or false, -- coerce to boolean
      globalID = globalID,
      bookID = FindSpellBookSlotBySpellID(globalID)
		}
	end
  return infoCache[globalID]
  ]]
end
-- do not modify the return value of this method
-- caller must specify spellOrigin when this method is called for a spell not already in the cache
function LA:SpellBookInfo(spellBookID, spellOrigin)
  --[[assert(spellBookID)
  local spellCache = self.spellCache
  -- Some spells morph based on spec. GetSpellBookItemInfo returns the spec-agnostic base spell ID
  -- GetSpellLink, on the other hand returns the spec-specific link
  local spellStatus, spellGlobalID, specSpellName, specSpellGlobalID = self:RealSpellBookItemInfo(spellBookID, BOOKTYPE_SPELL)
  local cacheEntry = spellCache[spellGlobalID]
  if not cacheEntry then
    cacheEntry = { }
    spellCache[spellGlobalID] = cacheEntry
  end
  if spellOrigin and not cacheEntry.origin then cacheEntry.origin = spellOrigin end
  if not cacheEntry.known then cacheEntry.known = IsSpellKnown(spellGlobalID) and true or false end -- coerce to boolean
  cacheEntry.status = spellStatus
  cacheEntry.bookID = spellBookID
  cacheEntry.specName = specSpellName
  cacheEntry.specGlobalID = specSpellGlobalID
  cacheEntry.specLink = GetSpellLink(globalID) -- varies by player spec...should this be cached, then?
      -- info = self:SpellInfo(spellGlobalID) -- convenience reference -- OBSOLETE
    }
  end
  return bookCache[spellGlobalID]
  ]]
end
-- do not modify the return value of this method

-- FIXME -- Work in progress -- FIXME -- 
function LA:FlyoutInfo(flyoutID)
--  local flyoutCache = self.flyoutCache
  --local flyoutID = select(2, GetSpellBookItemInfo(spellBookID, BOOKTYPE_SPELL))
--  if not flyoutCache[flyoutID] then
    local flyoutName, flyoutDescription, numFlyoutSpells, flyoutKnown = GetFlyoutInfo(flyoutID)
    --flyoutCache[flyoutID] = {
    local info = {
      known = flyoutKnown,
      name = flyoutName,
      count = numFlyoutSpells,
      description = flyoutDescription--,
      --bookID = spellBookID
    }
  --end
  --return flyoutCache[flyoutID]
  return info
end

function LA:UpdateSpellBook()
  --local infoCache = self.spellInfoCache
  --local bookCache = self.spellBookCache
  --wipe(bookCache)
  wipe(self.flyoutCache)
  local known = self.knownSpells
  wipe(known)
  local total = 0
  local professions = { GetProfessions() }
  -- { Primary1, Primary2, Archaeology, Fishing, Cooking, First Aid }
  local numKnown = 0
  for i = 1, self.numProfessions do
    if professions[i] then
      local name, texture, rank, maxRank, numSpells, spellOffset, skillLine, rankModifier = GetProfessionInfo(professions[i])
      -- for k = spellOffset + 1, spellOffset + numSpells do
         --self:SpellBookInfo(k, self.origin.profession)
         numKnown = numKnown + numSpells -- 1
         total = total + numSpells -- 1
      -- end
    end
  end
  --local racial = self.Spell.Global[self.racialSpell].SubName
  --local racialPassive = self.Spell.Global[self.racialPassiveSpell].SubName
  -- tab 1 is general, tab 2 is current spec, tabs 3, 4 and possibly 5 if druid are not current spec, rest are professions...?
  for tab = 1, 2 do -- GetNumSpellTabs()
    local tabName, tabTexture, tabOffset, tabSpells, tabIsGuild, offspecID = GetSpellTabInfo(tab)
    for slot = tabOffset + 1, tabOffset + tabSpells do
      --print("Checking spell "..slot) -- DEBUG
      local spell = self.Spell.Book[slot]
      -- rawset(self.Spell.Book, slot, spell)
      local status, globalID, specName, specGlobalID = self:RealSpellBookItemInfo(slot, BOOKTYPE_SPELL)
      if status == "FLYOUT" then
        -- flyout spells are not included in the regular spell tabs, they're
        -- in gaps between the last index of one tab and the first index of
        -- the next tab
        local flyoutID = globalID
        local flyoutInfo = self:FlyoutInfo(flyoutID)
        self.flyoutCache[flyoutID] = slot
        for flyoutSpell = 1, flyoutInfo.count do
          local flyoutSpellID, flyoutSpellKnown = GetFlyoutSlotInfo(flyoutID, flyoutSpell)
          -- all flyout spells are class-based as of 4.1.0
          local bookID = FindSpellBookSlotBySpellID(flyoutSpellID)
          if bookID then -- future spells return nil
            -- self:SpellBookInfo(bookID, self.origin.class)
            numKnown = numKnown + (flyoutSpellKnown and 1 or 0)
            total = total + 1
          end
        end
      elseif spell and spell.Known then
        known[globalID] = slot
        if specGlobalID ~= globalID then
          --known[specGlobalID] = slot -- Causes problems when spec IDs change (Mangle in particular)
          self.specSpellCache[specGlobalID] = globalID
        end
        --local info = self:SpellInfo(spellGlobalID)
        --[[local bookInfo = self:SpellBookInfo(k,
          tabIsGuild and self.origin.guild or
          (info.subName == racial or info.subName == racialPassive) and self.origin.race or
          self.ridingSpells[spellGlobalID] and self.origin.riding or
          self.origin.class
        )
        ]]
        numKnown = numKnown + 1
      end
      total = total + 1
    end
  end
  self:DebugPrint("Updated Spellbook, "..total.." entries found, "..numKnown.." spells known.")
  self.numSpells = total
end
function LA:UpdateGuild()
  --[[ MOP
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
  ]]
end
-- true if spell is known, false if spell is not know, nil if not in a guild
--[[ MOP
function LA:GuildSpellKnown(globalID)
  return self:UpdateGuild() and (self.character.guildSpells[globalID] and true or false) or nil
end
]]
-- if new is true, a spell has been added to the spellbook
-- if new is false, an existing spell has been newly learned
function LA:AddSpell(id, new)
  local action = "SHOW"
  if new then
    action = "LEARN"
  end
  if InCombatLockdown() then
    table.insert(self.queue, { action = action, id = id }) -- trash oh noes
  else
    if new then
      self:LearnSpell(id)
    end
    -- local bookInfo = self:SpellBookInfo(FindSpellBookSlotBySpellID(id))
    local spell = self.Spell.Global[id]
    if (not self.state.retalenting) and
       (not spell.Passive) --and
       --(not bookInfo.origin == self.origin.guild)
    then
      -- Display button with draggable spell icon
      
      --if bookInfo.origin == self.origin.guild then
        --self:DebugPrint("Found Guild Spell",bookInfo.info.globalID,bookInfo.info.name,time())
        --self.character.guildSpells[bookInfo.info.globalID] = true
      --else
      self:AddButton(spell)
      --end
	  
    end
  end
end
-- a spell has been removed from the spellbook
function LA:RemoveSpell(id)
  if InCombatLockdown() then
    table.insert(self.queue, { action = "FORGET", id = id }) -- trash oh noes
  else
    self:ClearButtonID(id)
    self:ForgetSpell(id)
  end
end
function LA:DiffSpellBook()
  -- swap caches
  --self.oldSpellBookCache, self.spellBookCache = self.spellBookCache, self.oldSpellBookCache
  self.oldKnownSpells, self.knownSpells = self.knownSpells, self.oldKnownSpells
  self:UpdateSpellBook()
  --local old = self.oldSpellBookCache
  --local new = self.spellBookCache
  local old = self.oldKnownSpells
  local new = self.knownSpells
  local updated = 0
  for newID, newItem in pairs(new) do -- look for things learned
    if newItem then
      if not old[newID] then -- spell added to spellbook
        self:AddSpell(newID, true)
        updated = updated + 1
      --elseif not old[newID].known then -- spell changed from unkown to known
      --  self:AddSpell(newID)
      --  updated = updated + 1
      end
    end
  end
  for oldID, oldItem in pairs(old) do -- look for things forgotten
    if oldItem then
      if not new[oldID] then
        self:RemoveSpell(oldID)
        updated = updated + 1
      --elseif not new[oldID].known then
      --  self:DebugPrint("Spell "..oldItem.info.name.." with globalID "..oldID.." forgotten but not removed")
      --  updated = updated + 1
      end
    end
  end
  if updated > 1 then
    self:DebugPrint("Multiple updates ("..updated..") in DiffSpellBook")
  end
  -- TODO: Detect flyout changes (right now the spell button can't handle flyouts)
  return updated
end
-- A new spellbook ID has been added, bumping existing spellbook IDs up by one
function LA:LearnSpell(id)
  local frame = self.frame
  local buttons = self.buttons
  --[[ MOP using global ids, don't need to munge book ids anymore, yay!
  for i = 1, self:GetVisible() do
    local button = buttons[i]
    local buttonID = button:GetID()
    if button.kind == kind and buttonID >= bookID then
      button:SetID(buttonID + 1)
      self:UpdateButton(button)
    end
  end
  ]]
  local spec = GetActiveSpecGroup()
  if self.saved.restoreActions and
      (not self.state.retalenting) and
      -- MOP -- kind == BOOKTYPE_SPELL and
      self.character.unlearned and
      self.character.unlearned[spec] then    
    --local globalID = self:SpellBookInfo(bookID).info.globalID
    for slot, oldIDs in pairs(self.character.unlearned[spec]) do
      local actionType = GetActionInfo(slot) -- local actionType, actionID, actionSubType, globalID = GetActionInfo(slot)
      for oldID in pairs(oldIDs) do
        if oldID == id and actionType == nil then
          PickupSpell(id)
          PlaceAction(slot)
          self.character.unlearned[spec][slot][oldID] = nil
        end
      end
    end
  end
end
-- An old spellbook ID has been deleted, shifting spellbook IDs down by one
function LA:ForgetSpell(bookID)
  --[[local frame = self.frame
  local buttons = self.buttons
  for i = 1, self:GetVisible() do
    local button = buttons[i]
    local buttonID = button:GetID()
    if button.kind == BOOKTYPE_SPELL and buttonID > bookID then
      button:SetID(buttonID - 1)
      self:UpdateButton(button)
    end
  end]]
end
