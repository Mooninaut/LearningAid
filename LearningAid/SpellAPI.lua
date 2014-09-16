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

-- spellMeta._method.Foo = true indicates that Foo will be called as spell:Foo() rather than spell.Foo

private.API = { }
local bookMeta = { }
local globalMeta = { }
local spellMeta = { _method = { Pickup = true } }
local flyoutBookMeta = { }
local flyoutMeta = { _method = { Pickup = true } }

-- Top level
LA.Spell = {
  Global = { },
  Book = { },
  Flyout = { },
}

setmetatable(LA.Spell.Global, globalMeta)
setmetatable(LA.Spell.Book,   bookMeta)
setmetatable(LA.Spell.Flyout, flyoutBookMeta)

-- Spell Global ID object factory
function globalMeta.__index (t, index)
  index = tonumber(index)
  assert(index > 0)
  local gID = LA.specSpellCache[index] or index -- get base spell id
  local sID = select(2, LA:UnlinkSpell(GetSpellLink(gID))) -- get spec spell id
  local newSpell = { _gid = gID, _sid = index }
  setmetatable(newSpell, spellMeta)
  rawset(t, index, newSpell)
  return newSpell
end

-- Spell Book ID object factory

function bookMeta.__index(t, index)
  index = tonumber(index)
  assert(index > 0)
  local gType, gID = GetSpellBookItemInfo(index, BOOKTYPE_SPELL)
  if "SPELL" == gType or "FUTURESPELL" == gType then
    local spell = LA.Spell.Global[gID]
    spell._slot = index -- Remember which Spellbook slot the spell is in
    -- rawset(t, index, spell) -- Save this object for faster future retrieval
    -- TODO -- Expiration mechanism for cached spell objects when spec IDs change
    return spell
  elseif "FLYOUT" == gType then
    return LA.Spell.Flyout[gID]
  else
    assert(false, LA.name..": Type of spellbook slot #"..tostring(index).." ("..tostring(gType)..") is not known")
  end
end

-- Spell object instances
function spellMeta.__index(spell, index)
  -- Use rawget to avoid an infinite loop if _gid doesn't exist for some reason
  -- LA:DebugPrint("SpellMeta "..index.."("..tostring(rawget(spell, "_gid"))..")")
  assert(spellMeta[index], LA.name..": Invalid SpellAPI object method: "..tostring(index))
  if spellMeta._method[index] then
    LA:DebugPrint("SpellMeta "..index.."("..tostring(rawget(spell, "_gid"))..")")
    return spellMeta[index] -- return value will be called as a method, see spellMeta._method
  else
    local result = spellMeta[index](spell)
    LA:DebugPrint(tostring(result).." = SpellMeta "..index.."("..tostring(rawget(spell, "_gid"))..")")
    return result -- simple return value
  end
end

function spellMeta.__eq(spell1, spell2)
  return spell1._gid == spell2._gid
end
function spellMeta.Name(spell)
  return select(1, GetSpellInfo(spell._gid))
end
function spellMeta.SpecName(spell)
  return select(1, GetSpellInfo(spell._sid))
end
function spellMeta.Info(spell)
  local info = { }
  info.name, info.rank, info.icon, info.powerCost, info.isFunnel, info.powerType, info.castingTime, info.minRange, info.maxRange =
    GetSpellInfo(spell._gid)
  return info
end
function spellMeta.SpecInfo(spell)
  local info = { }
  info.name, info.rank, info.icon, info.powerCost, info.isFunnel, info.powerType, info.castingTime, info.minRange, info.maxRange =
    GetSpellInfo(spell._sid)
  return info
end
function spellMeta.SubName(spell)
  return select(2, GetSpellInfo(spell._gid))
end
function spellMeta.SpecSubName(spell)
  return select(2, GetSpellInfo(spell._sid))
end
function spellMeta.SpecID(spell)
  return spell._sid
end
function spellMeta.Known(spell)
  -- Only works on gid, not sid. IsSpellKnown(sid) will always return nil
  return IsSpellKnown(spell._gid)
end
function spellMeta.Status(spell)
  local slot = spell.Slot
  assert(spell.Slot, LA.name..": Spell #"..spell._gid.." slot unknown in Spell.Status.")
  return GetSpellBookItemInfo(slot, BOOKTYPE_SPELL)
end
function spellMeta.ID(spell)
  return spell._gid
end
function spellMeta.Slot(spell)
  --local name = spell.Name
  --local infoName = spell.Info.name
  globalID = spell._gid
  -- use rawget because _slot might be nil, which would call metatable._slot as a method and fail
  local oldSlot = rawget(spell, "_slot")
  local slot = FindSpellBookSlotBySpellID(globalID)
  if slot then
    if slot ~= oldSlot then
      -- tostring to guard against nil values
      LA:DebugPrint("Spell ".. globalID.. " slot changed from ".. tostring(oldSlot).. " to ".. tostring(slot))
    end
    spell._slot = slot
    return slot
  end
  return oldSlot
end
function spellMeta.Link(spell)
  return GetSpellLink(spell._gid)
end
function spellMeta.Spec(spell)
  return select(1, IsSpellClassOrSpec(spell.Slot, BOOKTYPE_SPELL))
end
function spellMeta.Class(spell)
  return select(2, IsSpellClassOrSpec(spell.Slot, BOOKTYPE_SPELL))
end
function spellMeta.Selected(spell)
  return IsSelectedSpellBookItem(spell.Slot, BOOKTYPE_SPELL)
end
function spellMeta.Perk(spell)
  return LA.guildSpells[spell._gid]
end
function spellMeta.Passive(spell)
  return IsPassiveSpell(spell._gid)
end
function spellMeta:Pickup()
  PickupSpell(self._gid)
end
-- Flyout object factory

-- Note: Uses flyout IDs which are discontinuous, analogous to global spellIDs.
-- Does not use flyout indexes, which are continuous and run from 1..GetNumFlyouts()

function flyoutBookMeta.__index(t, index)
  index = tonumber(index)
  assert(index > 0)
  local newFlyout = { _fid = index }
  setmetatable(newFlyout, flyoutMeta)
  return newFlyout
end

-- Flyout object instances
function flyoutMeta.__index(flyout, index)
  if "string" == type(index) then
    assert(flyoutMeta[index], index.." is not a known flyout method")
    if flyoutMeta._method[index] then
      LA:DebugPrint("FlyoutMeta "..index.."("..tostring(rawget(flyout, "_fid"))..")")
      return flyoutMeta[index] -- return value will be called as a method, see flyoutMeta._method
    else
      return flyoutMeta[index](flyout)
    end
  elseif "number" == type(index) then
    local globalID, isKnown = GetFlyoutSlotInfo(flyout._fid, index)
    if globalID then
      return LA.Spell.Global[globalID]
    else
      return nil
    end
  end
end

function flyoutMeta.__eq(flyout1, flyout2)
  return flyout1._fid == flyout2._fid
end

function flyoutMeta.ID(flyout)
  return flyout._fid
end

function flyoutMeta.Info(flyout)
  return LA:FlyoutInfo(flyout._fid)
end

function flyoutMeta.Size(flyout)
  --local name, description, size, flyoutKnown = GetFlyoutInfo(flyoutID)
  return select(3, GetFlyoutInfo(flyout._fid))
end
function flyoutMeta.Status(flyout)
  return "FLYOUT"
end
function flyoutMeta.Name(flyout)
  --local name, description, size, flyoutKnown = GetFlyoutInfo(flyoutID)
  return GetFlyoutInfo(flyout._fid) -- passes on only the first return value, which is the localized name
end
function flyoutMeta.SubName(flyout)
  return ""
end
function flyoutMeta.Known(flyout)
  --local name, description, size, flyoutKnown = GetFlyoutInfo(flyoutID)
  return select(4, GetFlyoutInfo(flyout._fid))
end
function flyoutMeta:Pickup()
  PickupSpellBookItem(self.Slot, BOOKTYPE_SPELL)
end
function flyoutMeta.Slot(flyout)
  return LA.flyoutCache[flyout._fid]
end