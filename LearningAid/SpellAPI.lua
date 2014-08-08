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

--[[
PROBLEM

The search dingus can't find stuff because...?

I don't actually know. I thought it was related to spec spell IDs,
because those are the ones that fail
However, it appears that the API consistently uses the global ID, not
the spec ID for action bar buttons and for the spellbook
So why isn't it matching???
]]

--[[

DESIGN WORK

bottom-up

A Spell is an object with data globalID and getter methods Name(),
Slot(), Status(), Link(), Known(), etc
The metatable contains the actual methods, when attempting to index
the object, the methods are called on the object
spell.Name -> meta.Name(spell) -> GetSpellBookItemName(spell.Slot)

BookID is an object that instantiates a new Spell object whenever a 
nonexistent index is accessed
BookID[n] -> bookIDMeta.__index (t, n) -> setmetatable({ globalID = g }, SpellMeta)

Why look up the slot each time with FindSpellBookSlotBySpellID? Because
slots change. It's easier to always use the globalID than try to
track spellbook ID changes dynamically. I've tried.

Concern: Neither SpellBookIDs nor GlobalIDs are stable across spec changes.
]]
local addonName, private = ...
local LA = private.LA

-- backend data
private.API = { }
local bookIDMeta = { }
local globalIDMeta = { }
local spellMeta = { }
local flyoutIDMeta = { }
local flyoutMeta = { }

-- Top level
LA.Spell = {
  GlobalID = { },
  BookID = { },
  FlyoutID = { },
}

setmetatable(LA.Spell.GlobalID, globalIDMeta)
setmetatable(LA.Spell.BookID,   bookIDMeta)
setmetatable(LA.Spell.FlyoutID, flyoutIDMeta)

-- Spell Global ID object factory
function globalIDMeta.__index (t, index)
  index = tonumber(index)
  assert(index > 0)
  local gID = LA.specSpellCache[index] or index -- make sure to use parent spell ids, not spec spell ids
  local newSpell = { globalID = gID, specID = index }
  setmetatable(newSpell, spellMeta)
  t[index] = newSpell
  return newSpell
end

-- Spell Book ID object factory

function bookIDMeta.__index(t, index)
  index = tonumber(index)
  assert(index > 0)
  local gType, gID = GetSpellBookItemInfo(index, BOOKTYPE_SPELL)
  if "SPELL" == gType or "FUTURESPELL" == gType then
    local spell = LA.Spell.GlobalID[gID]
    rawset(spell, "slot", index)
    return spell
  elseif "FLYOUT" == gType then
    return LA.Spell.FlyoutID[gID]
  else
    assert(false, tostring(gType).." is not known")
  end
end

-- Spell object instances
function spellMeta.__index(t, index)
  --if spellMeta[index] then
    assert(spellMeta[index], "Invalid SpellAPI object method: "..tostring(index))
    LA:DebugPrint("SpellMeta "..index.."("..rawget(t, "globalID")..")")
    return spellMeta[index](t)
  --end
end

function spellMeta.Name(spell)
  return select(1, GetSpellInfo(spell.globalID))
end
function spellMeta.SpecName(spell)
  return select(1, GetSpellInfo(spell.specID))
end
function spellMeta.Info(spell)
  local info = { }
  info.name, info.rank, info.icon, info.powerCost, info.isFunnel, info.powerType, info.castingTime, info.minRange, info.maxRange =
    GetSpellInfo(spell.globalID)
  return info
end
function spellMeta.SpecInfo(spell)
  local info = { }
  info.name, info.rank, info.icon, info.powerCost, info.isFunnel, info.powerType, info.castingTime, info.minRange, info.maxRange =
    GetSpellInfo(spell.specID)
  return info
end
function spellMeta.SubName(spell)
  return select(2, GetSpellInfo(spell.globalID))
end
function spellMeta.SpecSubName(spell)
  return select(2, GetSpellInfo(spell.specID))
end
function spellMeta.SpecGlobalID(spell)
  return spell.specID
end
function spellMeta.Known(spell)
  return IsSpellKnown(spell.globalID)
end
function spellMeta.Status(spell)
  local slot = spell.Slot
  assert(spell.Slot, "Spell #"..spell.globalID.." slot unknown in Spell.Status.")
  GetSpellBookItemInfo(slot, BOOKTYPE_SPELL)
end
function spellMeta.Slot(spell)
  --local name = spell.Name
  --local infoName = spell.Info.name
  local globalID = rawget(spell, "globalID")
  local oldSlot = rawget(spell, "slot")
  local slot = FindSpellBookSlotBySpellID(globalID)
  if slot then
    if slot ~= oldSlot then
      -- tostring to guard against nil values
      LA:DebugPrint("Spell ".. globalID.. " slot changed from ".. tostring(oldSlot).. " to ".. tostring(slot))
    end
    rawset(spell, "slot", slot)
    return slot
  end
  return oldSlot
  --[[
  if spell.slot then
    if spell.slot == slot then
  --  if name == spell.Name then
      return slot
  --  else
  --    assert(false, "Spell "..tostring(name).."name does not match "..tostring(infoName).." in spellAPI method Slot("..tostring(spell)..")")
  --  end
  else
    if name == spell.Name then
      spell.slot = slot
      return slot
  end
  --]]
end
function spellMeta.Link(spell)
  return GetSpellLink(spell.globalID)
end
function spellMeta.Spec(spell)
  return select(1, IsSpellClassOrSpec(spell.Slot, BOOKTYPE_SPELL))
end
function spellMeta.Class(spell)
  return select(2, IsSpellClassOrSpec(spell.Slot, BOOKTYPE_SPELL))
end
function spellMeta.Perk(spell)
  return LA.guildSpells[rawget(spell, "globalID")]
end
function spellMeta.Passive(spell)
  return IsPassiveSpell(rawget(spell, "globalID"))
end

-- Flyout object factory

function flyoutIDMeta.__index(t, index)
  index = tonumber(index)
  assert(index > 0)
  local newFlyout = { id = index }
  setmetatable(newFlyout, flyoutMeta)
  return newFlyout
end

-- Flyout object instances
function flyoutMeta.__index(t,index)
  assert(flyoutMeta[index], index.." is not a known flyout method")
  return flyoutMeta[index](t)
end

function flyoutMeta.ID(flyout)
  return rawget(flyout, "id")
end

function flyoutMeta.Info(flyout)
  return LA:FlyoutInfo(rawget(flyout, "id"))
end

function flyoutMeta.Slot(flyout)
  -- FIXME -- return
end
function flyoutMeta.Status(flyout)
  return "FLYOUT"
end