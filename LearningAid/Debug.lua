-- Debug.lua

local addonName, private = ...
local LA = private.LA

function LA:TestAdd(kind, ...)
  print("Testing!")
  local t = {...}
  for i = 1, #t do
    local id = t[i]
    if kind == BOOKTYPE_SPELL then
      if GetSpellInfo(id, kind) and not IsPassiveSpell(id, kind) then
        print("Test: Adding button with spell id "..id)
        if self.inCombat then
          table.insert(self.queue, { action = "SHOW", id = id, kind = kind })
        else
          self:AddButton(kind, id)
        end
      else
        print("Test: Spell id "..id.." is passive or does not exist")
      end
    elseif kind == "CRITTER" or kind == "MOUNT" then
      if GetCompanionInfo(kind, id) then
        print("Test: Adding companion type "..kind.." id "..id)
        if self.inCombat then
          table.insert(self.queue, { action = "SHOW", id = id, kind = kind})
        else
          self:AddButton(kind, id)
        end
      else
        print("Test: Companion type "..kind..", id "..id.." does not exist")
      end
    else
      print("Test: Action type "..kind.." is not valid.  Valid types are spell, CRITTER or MOUNT.")
    end
  end
end
function LA:TestRemove(kind, ...)
  print("Testing!")
  local t = {...}
  for i = 1, #t do
    local id = t[i]
    print("Test: Removing "..kind.." id "..id)
    if self.inCombat then
      table.insert(self.queue, { action = "CLEAR", id = id, kind = kind })
    else
      self:ClearButtonID(kind, id)
    end
  end
end

function LA:ListJoin(...)
  local str = ""
  local argc = select("#", ...)
  if argc == 1 and type(...) == "table" then
    return self:ListJoin(unpack(...))
  elseif argc >= 1 then
    str = str..tostring(...)
    for i = 2, argc do
      str = str..", "..tostring(select(i, ...))
    end
  end
  return str
end

function private:DebugPrint(...)
  private.debugCount = private.debugCount + 1
  LearningAid_DebugLog[private.debugCount] = LA:ListJoin(...)
  if private.debugCount > 5000 then
    LearningAid_DebugLog[private.debugCount - 5000] = nil
  end
end
-- don't call the stub DebugPrint, call the real DebugPrint
private.wrappers.DebugPrint = private.DebugPrint

private.meta = {
  __index = function(t, key)
    local value = private.shadow[key]
    if type(value) == "function" then
      if private.debugFlags.CALL and not private.noLog[key] then
        return private:Wrap(key, value)
      else
        return value
      end
    elseif private.debugFlags.GET then
      private:DebugPrint("__index["..tostring(key).."] = "..tostring(value))
    end
    return value
  end,
  __newindex = function(t, key, value)
    if private.debugFlags.SET then
      private:DebugPrint("__newindex["..tostring(key).."] = "..tostring(value))
    end
    private.shadow[key] = value
  end
}
-- when debugging is enabled, calls to LA:DebugPrint will be diverted to private:DebugPrint
function LA:DebugPrint() end

--setmetatable(private.empty, private.meta)

-- call after original LA is in private.LA and LA is empty
function private:Wrap(name, f)
  if not self.wrappers[name] then
    self.wrappers[name] = function(...)
      self:DebugPrint(name.."("..LA:ListJoin(select(2,...))..")")
      local result = { f(...) } -- junk table created, boo hoo
      self:DebugPrint(name.."() return "..LA:ListJoin(unpack(result)))
      return unpack(result)
    end
  end
  return self.wrappers[name]
end

function LA:Debug(flag, newValue)
  local oldDebug = private.debug
  local newDebug = oldDebug
  local debugFlags = self.saved.debugFlags
  local oldValue = debugFlags[flag]
  
  if flag == nil then -- initialize
    newDebug = 0
    private.debugFlags = debugFlags
    for savedFlag, savedValue in pairs(debugFlags) do
      --debugFlags[savedFlag] = savedValue
      if savedValue then
        newDebug = newDebug + 1
      end
    end
  elseif newValue == nil then -- getter
    return oldValue
  elseif newValue ~= oldValue then -- setter
    debugFlags[flag] = newValue
    newDebug = newDebug + (newValue and 1 or -1)
  end

  local shadow = private.shadow

  if oldDebug == 0 and newDebug > 0 then -- we're turning debugging on
    for k, v in pairs(LA) do
      shadow[k] = LA[k]
      LA[k] = nil
    end
    setmetatable(LA, private.meta)
    LearningAid_DebugLog = { }
  elseif oldDebug > 0 and newDebug == 0 then -- we're turning debugging off
    setmetatable(LA, nil)
    for k, v in pairs(shadow) do
      LA[k] = shadow[k]
      shadow[k] = nil
    end
  end

  private.debug = newDebug
end
