-- Learning Aid v1.11 by Jamash (Kil'jaeden-US)
-- LearningAid.lua

local addonName, private = ...

private.debug = 0
private.debugCount = 0
private.shadow = { }
private.wrappers = { }
private.debugFlags = { }
private.noLog = {
  GetVisible = true,
  GetText = true,
  ListJoin = true
}

local LA = { 
  version = "1.11",
  name = addonName,
  titleHeight = 40, -- pixels
  frameWidth = 200, -- pixels
  verticalSpacing = 5, -- pixels
  horizontalSpacing = 153, -- pixels
  buttonSize = 37, -- pixels
  width = 1, -- button columns
  height = 0, -- button rows
  visible = 0, -- buttons
  strings = { },
  FILTER_SHOW_ALL  = 0,
  FILTER_SUMMARIZE = 1, -- default
  FILTER_SHOW_NONE = 2,
  CONFIRM_TRAINER_BUY_ALL = 732297, -- magic number randomly chosen via /roll 1000000 to prevent users from accidentally spending hundreds of gold at a trainer
  patterns = {
    learnAbility    = ERR_LEARN_ABILITY_S,
    learnSpell      = ERR_LEARN_SPELL_S,
    unlearnSpell    = ERR_SPELL_UNLEARNED_S,
    petLearnAbility = ERR_PET_LEARN_ABILITY_S,
    petLearnSpell   = ERR_PET_LEARN_SPELL_S,
    petUnlearnSpell = ERR_PET_SPELL_UNLEARNED_S
  },
  defaults = {
    macros = true,
    totem = true,
    enabled = true,
    restoreActions = true,
    filterSpam = 1, -- FILTER_SUMMARIZE
    debugFlags = { },
    ignore = { }
  },
  menuHideDelay = 5, -- seconds
  pendingBuyCount = 0,
  inCombat = false,
  retalenting = false,
  untalenting = false,
  learning = false,
  activatePrimarySpec = 63645,
  activateSecondarySpec = 63644,
  buttons = { },
  queue = { },
  availableServices = { },
  spellsLearned = { name = { }, link = { } },
  spellsUnlearned = { name = { }, link = { } },
  petLearned = { },
  petUnlearned = { },
  companionCache = {
    MOUNT = { },
    CRITTER = { }
  },
  spellBookCache = { },
  flyoutCache = { },
--  events = { }, -- EVENT DEBUGGING
  numSpells = 0,
  companionsReady = false,
  backdrop = {
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
    edgeFile = "Interface/DialogFrame/UI-DialogBox-Gold-Border",
    tile = false, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  }
}

private.LA = LA
_G[addonName] = LA

LibStub("AceConsole-3.0"):Embed(LA)

function private.onEvent(frame, event, ...)
  LA[event](LA, ...)
end

function private.onEventDebug(frame, event, ...)
  if LA.events[event] then
    LA[event](LA, ...)
  else
    LA:DebugPrint(event)
  end
end

LA.frame = CreateFrame("Frame", nil, UIParent)
LA.frame:SetScript("OnEvent", private.onEvent)
LA.frame:RegisterEvent("ADDON_LOADED")

for name, pattern in pairs(LA.patterns) do
  LA.patterns[name] = string.gsub(pattern, "%%s", "(.+)")
end

function LA:Init()
  --self:DebugPrint("Initialize()")
  self:SetDefaultSettings()
  local version, build, buildDate, tocversion = GetBuildInfo()
  self.locale = GetLocale()
  self.tocVersion = tocversion

  -- set up main frame
  local frame = self.frame
  frame:Hide()
  frame:SetClampedToScreen(true)
  frame:SetWidth(self.frameWidth)
  frame:SetHeight(self.titleHeight)
  frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -200, -200)
  frame:SetMovable(true)
  frame:SetScript("OnShow", function () self:OnShow() end)
  frame:SetScript("OnHide", function () self:OnHide() end)
  frame:SetBackdrop(self.backdrop)

  -- create title bar
  local titleBar = CreateFrame("Frame", nil, frame)
  self.titleBar = titleBar
  titleBar:SetPoint("TOPLEFT")
  titleBar:SetPoint("TOPRIGHT")
  titleBar:SetHeight(self.titleHeight)
  titleBar:RegisterForDrag("LeftButton")
  titleBar:EnableMouse()
  titleBar.text = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  titleBar.text:SetText(self:GetText("title"))
  titleBar.text:SetPoint("CENTER", titleBar, "CENTER", 0, 0)

  -- create close button
  local closeButton = CreateFrame("Button", nil, titleBar)
  self.closeButton = closeButton
  closeButton:SetWidth(32)
  closeButton:SetHeight(32)
  closeButton:SetPoint("RIGHT", titleBar, "RIGHT", -2, 0)
  closeButton:SetNormalTexture("Interface/BUTTONS/UI-Panel-MinimizeButton-Up")
  closeButton:SetPushedTexture("Interface/BUTTONS/UI-Panel-MinimizeButton-Down")
  closeButton:SetDisabledTexture("Interface/BUTTONS/UI-Panel-MinimizeButton-Disabled")
  closeButton:SetHighlightTexture("Interface/BUTTONS/UI-Panel-MinimizeButton-Highlight")
  closeButton:SetScript("OnClick", function () self:Hide() end)

  -- initialize right-click menu
  self.menuTable = {
    { text = self:GetText("lockPosition"), 
      func = function () self:ToggleLock() end },
    { text = self:GetText("close"),
      func = function () self:Hide() end }
  }

  local menu = CreateFrame("Frame", "LearningAid_Menu", titleBar, "UIDropDownMenuTemplate")

  -- set drag and click handlers for the title bar
  titleBar:SetScript(
    "OnDragStart",
    function (bar, button)
      if not self.saved.locked then
        bar:GetParent():StartMoving()
      end
    end
  )

  titleBar:SetScript(
    "OnDragStop",
    function (bar)
      local parent = bar:GetParent()
      parent:StopMovingOrSizing()
      self.saved.x = parent:GetLeft()
      self.saved.y = parent:GetTop()
    end
  )

  titleBar:SetScript(
    "OnMouseUp",
    function (bar, button)
      if button == "MiddleButton" then
        self:Hide()
      elseif button == "RightButton" then
        EasyMenu(self.menuTable, menu, "cursor", 0, 8, "MENU", self.menuHideDelay)
      end
    end
  )

  self.options = {
    handler = self,
    type = "group",
    args = {
      lock = {
        name = self:GetText("lockWindow"),
        desc = self:GetText("lockWindowHelp"),
        type = "toggle",
        set = function(info, val) if val then self:Lock() else self:Unlock() end end,
        get = function(info) return self.saved.locked end,
        width = "full",
        order = 1
      },
      restoreactions = {
        name = self:GetText("restoreActions"),
        desc = self:GetText("restoreActionsHelp"),
        type = "toggle",
        set = function(info, val) if val then self.saved.restoreActions = val end end,
        get = function(info) return self.saved.restoreActions end,
        width = "full",
        order = 2
      },
      filter = {
        name = self:GetText("showLearnSpam"),
        desc = self:GetText("showLearnSpamHelp"),
        type = "select",
        values = {
          [self.FILTER_SHOW_ALL ] = self:GetText("showAll"),
          [self.FILTER_SUMMARIZE] = self:GetText("summarize"),
          [self.FILTER_SHOW_NONE] = self:GetText("showNone")
        },
        set = function(info, val)
          local old = self.saved.filterSpam
          if old ~= val then
            self.saved.filterSpam = val
            if val == self.FILTER_SHOW_ALL then
              self:DebugPrint("Removing chat filter for CHAT_MSG_SYSTEM")
              ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", private.spellSpamFilter)
            elseif old == self.FILTER_SHOW_ALL then
              self:DebugPrint("Adding chat filter for CHAT_MSG_SYSTEM")
              ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", private.spellSpamFilter)
            end
          end
        end,
        get = function(info) return self.saved.filterSpam end,
        order = 3
      },
      reset = {
        name = self:GetText("resetPosition"),
        desc = self:GetText("resetPositionHelp"),
        type = "execute",
        func = "ResetFramePosition",
        width = "full",
        order = 4
      },
      missing = {
        type = "group",
        inline = true,
        name = self:GetText("findMissingAbilities"),
        order = 10,
        args = {
          search = {
            name = self:GetText("searchMissing"),
            desc = self:GetText("searchMissingHelp"),
            type = "execute",
            func = "FindMissingActions",
            -- width = "full",
            order = 1
          },
          tracking = {
            name = self:GetText("findTracking"),
            desc = self:GetText("findTrackingHelp"),
            type = "toggle",
            set = function(info, val) self.saved.tracking = val end,
            get = function(info) return self.saved.tracking end,
            width = "full",
            order = 2
          },
          shapeshift = {
            name = self:GetText("findShapeshift"),
            desc = self:GetText("findShapeshiftHelp"),
            type = "toggle",
            set = function(info, val) self.saved.shapeshift = val end,
            get = function(info) return self.saved.shapeshift end,
            width = "full",
            order = 3
          },
          macros = {
            name = self:GetText("searchInsideMacros"),
            desc = self:GetText("searchInsideMacrosHelp"),
            type = "toggle",
            set = function(info, val) self.saved.macros = val end,
            get = function(info) return self.saved.macros end,
            width = "full",
            order = 4
          },
          ignore = {
            name = self:GetText("ignore"),
            desc = self:GetText("ignoreHelp"),
            type = "input",
            guiHidden = true,
            set = "Ignore"
          },
          unignore = {
            name = self:GetText("unignore"),
            desc = self:GetText("unignoreHelp"),
            type = "input",
            guiHidden = true,
            set = "Unignore"
          },
          unignoreall = {
            order = 5,
            name = self:GetText("unignoreAll"),
            desc = self:GetText("unignoreAllHelp"),
            type = "execute",
            -- width = "full",
            func = "UnignoreAll"
          }
        }
      },
      unlock = {
        name = self:GetText("unlockWindow"),
        desc = self:GetText("unlockWindowHelp"),
        type = "execute",
        guiHidden = true,
        func = "Unlock"
      },
      config = {
        name = self:GetText("configure"),
        desc = self:GetText("configureHelp"),
        type = "execute",
        func = function() InterfaceOptionsFrame_OpenToCategory(self.optionsFrame) end,
        guiHidden = true
      },
      advanced = {
        type = "group",
        name = self:GetText("advanced"),
        args = {
          framestrata = {
            name = self:GetText("frameStrata"),
            desc = self:GetText("frameStrataHelp"),
            type = "select",
            values = {
              -- PARENT = "Parent",
              BACKGROUND = "Background",
              LOW = "Low",
              MEDIUM = "Medium",
              HIGH = "High",
              DIALOG = "Dialog",
              FULLSCREEN = "Fullscreen",
              FULLSCREEN_DIALOG = "Fullscreen Dialog",
              TOOLTIP = "Tooltip"
            },
            set = function(info, val)
              self.saved.frameStrata = val
              self.frame:SetFrameStrata(val)
            end,
            get = function(info) return self.frame:GetFrameStrata() end,
            order = 1
          },
          debug = {
            name = self:GetText("debugOutput"),
            desc = self:GetText("debugOutputHelp"),
            values = { SET = "Assignment", GET = "Access", CALL = "Function Calls" },
            type = "multiselect",
            set = function(info, key, val) self:Debug(key, val) end,
            get = function(info, key) return self:Debug(key) end,
            width = "full",
            order = 99
          }
        }
      },
      test = {
        type = "group",
        name = "Test",
        desc = "Perform various tests with Learning Aid.",
        hidden = true,
        guiHidden = true,
        args = {
          add = {
            type = "group",
            name = "Add",
            desc = "Add a button to the Learning Aid window.",
            args = {
              spell = {
                type = "input",
                name = "Spell",
                pattern = "^%d+$",
                set = function(info, val)
                  self:AddButton(BOOKTYPE_SPELL, tonumber(val))
                end
              },
              mount = {
                type = "input",
                name = "Mount",
                pattern = "^%d+$",
                set = function(info, val)
                  self:AddButton("MOUNT", tonumber(val))
                end
              },
              critter = {
                type = "input",
                name = "Critter (Minipet)",
                pattern = "^%d+$",
                set = function(info, val)
                  self:AddButton("CRITTER", tonumber(val))
                end
              },
              all = {
                name = "All",
                desc = "The Kitchen Sink",
                type = "execute",
                func = function ()
                  local i = 1
                  local spellName, spellRank = GetSpellBookItemName(i, BOOKTYPE_SPELL)
                  while spellName do
                    self:AddButton(BOOKTYPE_SPELL, i)
                    i = i + 1
                    spellName, spellRank = GetSpellBookItemName(i, BOOKTYPE_SPELL)
                  end
                end
              }
            }
          },
          remove = {
            type = "group",
            name = "Remove",
            desc = "Remove a button from the Learning Aid window.",
            args = {
              spell = {
                type = "input",
                name = "Spell",
                pattern = "^%d+$",
                set = function(info, val)
                  self:ClearButtonID(BOOKTYPE_SPELL, tonumber(val))
                end
              },
              mount = {
                type = "input",
                name = "Mount",
                pattern = "^%d+$",
                set = function(info, val)
                  self:ClearButtonID("MOUNT", tonumber(val))
                end
              },
              critter = {
                type = "input",
                name = "Critter (Minipet)",
                pattern = "^%d+$",
                set = function(info, val)
                  self:ClearButtonID("CRITTER", tonumber(val))
                end
              },
              button = {
                type = "input",
                name = "Button",
                pattern = "^%d+$",
                set = function(info, val)
                  self:ClearButtonIndex(tonumber(val))
                end
              }
            }
          }
        }
      }
    }
  }
  self.localClass, self.enClass = UnitClass("player")
  if self.enClass == "SHAMAN" then
    self.options.args.missing.args.totem = {
      name = self:GetText("findTotem"),
      desc = self:GetText("findTotemHelp"),
      type = "toggle",
      set = function(info, val) self.saved.totem = val end,
      get = function(info) return self.saved.totem end,
      width = "full",
      order = 4
    }
  end
  LibStub("AceConfig-3.0"):RegisterOptionsTable("LearningAidConfig", self.options, {"la", "learningaid"})
  self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("LearningAidConfig", self:GetText("title").." "..self.version)
  hooksecurefunc("ConfirmTalentWipe", function()
    self:DebugPrint("ConfirmTalentWipe")
    self:SaveActionBars()
    self.untalenting = true
    self.spellsUnlearned = {}
    self:RegisterEvent("ACTIONBAR_SLOT_CHANGED", "OnEvent")
    self:RegisterEvent("PLAYER_TALENT_UPDATE", "OnEvent")
    self:RegisterEvent("UI_ERROR_MESSAGE", "OnEvent")
  end)
  hooksecurefunc("LearnPreviewTalents", function(pet)
    self:DebugPrint("LearnPreviewTalents", pet)
    if not pet then
      self:RegisterEvent("PLAYER_TALENT_UPDATE", "OnEvent")
      --wipe(self.spellsLearned)
      --wipe(self.spellsUnlearned)
      self.learning = true
    end
  end)
  hooksecurefunc("SetCVar", function (cvar, value)
    if cvar == nil then cvar = "" end
    if value == nil then value = "" end
    cvarLower = string.lower(cvar)
    self:DebugPrint("SetCVar("..cvar..", "..value..")")
    if cvarLower == "uiscale" or cvarLower == "useuiscale" then
      self:AutoSetMaxHeight()
    end      
  end)
  self.LearnTalent = LearnTalent
  self.pendingTalents = {}
  self.pendingTalentCount = 0
  LearnTalent = function(tab, talent, pet, group, ...)
    self:DebugPrint("LearnTalent", tab, talent, pet, group, ...)
    local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq, unknown1, unknown2 = GetTalentInfo(tab, talent, false, pet, group)
    self:DebugPrint("GetTalentInfo", name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq, unknown1, unknown2)
    self.LearnTalent(tab, talent, pet, group, ...)
    if rank < maxRank and meetsPrereq and not pet then
      --wipe(self.spellsLearned)
      --self.learning = true
      if self.pendingTalentCount == 0 then wipe(self.pendingTalents) end
      self:RegisterEvent("PLAYER_TALENT_UPDATE", "OnEvent")
      local id = (group or GetActiveTalentGroup()).."."..tab.."."..talent.."."..rank
      if not self.pendingTalents[id] then
        self.pendingTalents[id] = true
        self.pendingTalentCount = self.pendingTalentCount + 1
      end
      --self:DebugPrint(GetTalentInfo(tab, talent, false, pet, group))
    end
  end
  self:RegisterChatCommand("la", "AceSlashCommand")
  self:RegisterChatCommand("learningaid", "AceSlashCommand")
  --self:SetEnabledState(self.saved.enabled)
  --self.saved.enabled = true
  --self:DebugPrint("OnEnable()")
  local baseEvents = {
    "ADDON_LOADED",
    "CHAT_MSG_SYSTEM",
    "COMPANION_LEARNED",
    "COMPANION_UPDATE",
    "PET_TALENT_UPDATE",
    "PLAYER_LEAVING_WORLD",
    "PLAYER_LEVEL_UP",
    "PLAYER_LOGIN",
    "PLAYER_LOGOUT",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
--    "SPELLS_CHANGED", -- wait until PLAYER_LOGIN
    "UNIT_SPELLCAST_START",
    "UPDATE_BINDINGS",
    "VARIABLES_LOADED"
--[[
    "CURRENT_SPELL_CAST_CHANGED",
    "SPELL_UPDATE_COOLDOWN",
    "TRADE_SKILL_CLOSE",
    "TRADE_SKILL_SHOW",
    "UNIT_SPELLCAST_SUCCEEDED"
--]]
  }
  for i, event in ipairs(baseEvents) do
    self:RegisterEvent(event, "OnEvent")
  end
  
  --self:UpdateSpellBook()
  self:UpdateCompanions()
  self:DiffActionBars()
  self:SaveActionBars()
  if self.saved.filterSpam ~= LA.FILTER_SHOW_ALL then
    self:DebugPrint("Initially adding chat filter for CHAT_MSG_SYSTEM")
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", private.spellSpamFilter)
  end
  if self.saved.locked then
    self.menuTable[1].text = self:GetText("unlockPosition")
  else
    self.saved.locked = false
  end
  if self.saved.frameStrata then
    self.frame:SetFrameStrata(self.saved.frameStrata)
  end
end

-- this is a function
function private.spellSpamFilter(...) return LA:spellSpamFilter(...) end

-- this is a method
function LA:spellSpamFilter(chatFrame, event, message, ...)
  local spell
  local patterns = self.patterns
  if self.saved.filterSpam ~= self.FILTER_SHOW_ALL and (
    (
      self.untalenting or
      self.retalenting or
     (self.pendingTalentCount > 0) or
     (self.saved.filterSpam == self.FILTER_SHOW_NONE) or
      self.learning or
      (self.pendingBuyCount > 0)
    ) and (
      string.match(message, patterns.learnSpell) or 
      string.match(message, patterns.learnAbility) or
      string.match(message, patterns.unlearnSpell) or
--    )
--  ) or
    string.match(message, patterns.petLearnAbility) or
    string.match(message, patterns.petLearnSpell) or
    string.match(message, patterns.petUnlearnSpell))
  ) then
    self:DebugPrint("Suppressing message")
    return true -- do not display the message
  else
    self:DebugPrint("Allowing message")
    return false, message, ... -- pass the message along
  end
end

function LA:GetText(id, ...)
  if not id then
    if self.DebugPrint then
      self:DebugPrint("Nil supplied to GetText()")
    end
    return "Nil"
  end
  local result = "Invalid String ID '" .. id .. "'"
  if self.strings[self.locale] and self.strings[self.locale][id] then
    result = self.strings[self.locale][id]
  elseif self.strings.enUS[id] then
    result = self.strings.enUS[id]
  else
    self:DebugPrint(result)
  end
  return format(result, ...)
end

function LA:SetDefaultSettings()
  LearningAid_Saved = LearningAid_Saved or {}
  LearningAid_Character = LearningAid_Character or {}
  self.saved = LearningAid_Saved
  self.character = LearningAid_Character
  self.saved.version = self.version
  self.character.version = self.version
  for key, value in pairs(self.defaults) do
    if self.saved[key] == nil then
      self.saved[key] = value
    end
  end
  -- update with new debug option format as of 1.11
  if self.saved.debug ~= nil then
    if self.saved.debug then
      self.saved.debugFlags = { SET = true, GET = true, CALL = true }
    end
    self.saved.debug = nil
  end
  for k, v in pairs(self.saved.debugFlags) do
    if v then
      self:Debug()
      break
    end
  end
end

function LA:RegisterEvent(event)
  self.frame:RegisterEvent(event)
--  self.events[event] = true -- EVENT DEBUGGING
end

function LA:UnregisterEvent(event)
  self.frame:UnregisterEvent(event)
--  self.events[event] = false -- EVENT DEBUGGING
end

function LA:Ignore(info, str)
  local strLower = string.lower(str)
  if #strtrim(str) == 0 and self.saved.ignore[self.localClass] then
    -- print ignore list to the chat frame
    for lowercase, titlecase in pairs(self.saved.ignore[self.localClass]) do
      print(self:GetText("title")..": ".. self:GetText("listIgnored", titlecase))
    end
  end
  for index, spell in pairs(self.spellBookCache) do
    local spellLower = string.lower(spell.name)
    if strLower == spellLower then
      if not self.saved.ignore[self.localClass] then
        self.saved.ignore[self.localClass] = {}
      end
      self.saved.ignore[self.localClass][spellLower] = spell.name
      self:UpdateButtons()
      break
    end
  end
end
function LA:Unignore(info, str)
  if self.saved.ignore[self.localClass] then
    local ignoreList = self.saved.ignore[self.localClass]
    local strLower = string.lower(str)
    if ignoreList[strLower] then
      ignoreList[strLower] = nil
      self:UpdateButtons()
    end
  end
end
function LA:ToggleIgnore(spell)
  local spellLower = string.lower(spell)
  if self.saved.ignore[self.localClass] and
     self.saved.ignore[self.localClass][spellLower] then
    self:Unignore(nil, spell)
  else
    self:Ignore(nil, spell)
  end
end
function LA:UnignoreAll(info)
  if self.saved.ignore[self.localClass] then
    wipe(self.saved.ignore[self.localClass])
  end
end
function LA:ResetFramePosition()
  local frame = self.frame
  frame:ClearAllPoints()
  frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -200, -200)
  self.saved.x = frame:GetLeft()
  self.saved.y = frame:GetTop()
end
function LA:AceSlashCommand(msg)
  LibStub("AceConfigCmd-3.0").HandleCommand(LearningAid, "la", "LearningAidConfig", msg)
end
--[[
function LA:OnEvent(event, ...)
  --self:DebugPrint(event, ...)
  if self[event] then
    self[event](self, ...)
  end
end
]]
--[[
function LA:OnEnable()
end
function LA:OnDisable()
  self:Hide()
  self.saved.enabled = false
  if self.saved.filterSpam ~= LA.FILTER_SHOW_ALL then
    ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", spellSpamFilter)
  end
end
]]
--[[
function LA:UnRankSpell(str)
  local rank = tonumber(string.match(str, "%(%D*(%d+)%D*%)"))
  local spell = strtrim(string.match(str, "^([^%(]+)"))
  return spell, rank
end
--]]
--[[ FormatSpells(t)
  t = {
    { key = "spell used as sort key", value = <spell link or spell name and rank, doesn't matter> },
    { more of the same},
    { etc}
  }
--]]
function LA:FormatSpells(t)
--  LoadAddOn("Blizzard_DebugTools")
--  DevTools_Dump(t)
  if #t > 0 then
    table.sort(t, function(a, b) return a.key < b.key end)
    local str = ""
    for i = 1, #t - 1 do 
      str = str..t[i].value
      str = str..", "
    end
    str = str..t[#t].value
    return str
  end
end

function LA:SystemPrint(message)
  local systemInfo = ChatTypeInfo["SYSTEM"]
  DEFAULT_CHAT_FRAME:AddMessage(LA:GetText("title")..": "..message, systemInfo.r, systemInfo.g, systemInfo.b, systemInfo.id)
end

function LA:ProcessQueue()
  if self.inCombat then
    self:DebugPrint("ProcessQueue(): Cannot process action queue during combat.")
    return
  end
  local queue = self.queue
  for index = 1, #queue do
    local item = queue[index]
    if item.action == "SHOW" then
      self:AddButton(item.kind, item.id)
    elseif item.action == "CLEAR" then
      self:ClearButtonID(item.kind, item.id)
    elseif item.kind == BOOKTYPE_SPELL then
      if item.action == "LEARN" then
        self:AddSpell(item.id)
      elseif item.action == "FORGET" then
        self:RemoveSpell(item.id)
      else
        self:DebugPrint("ProcessQueue(): Invalid action type " .. item.action)
      end
    elseif item.kind == "CRITTER" or item.kind == "MOUNT" then
      if item.action == "LEARN" then
        self:AddCompanion(item.kind, item.id)
      else
        self:DebugPrint("ProcessQueue(): Invalid action type " .. item.action)
      end
    elseif item.kind == "HIDE" then
      self:Hide()
    else
      self:DebugPrint("ProcessQueue(): Invalid entry type " .. item.kind)
    end
  end
  self.queue = {}
end

function LA:PrintPending()
  if self.saved.filterSpam == self.FILTER_SUMMARIZE then
    local learned = self:FormatSpells(self.spellsLearned)
    local unlearned = self:FormatSpells(self.spellsUnlearned)
    if unlearned then self:SystemPrint(self:GetText("youHaveUnlearned", unlearned)) end
    if learned then self:SystemPrint(self:GetText("youHaveLearned", learned)) end

    table.sort(self.petLearned)
    table.sort(self.petUnlearned)

    local petLearned = self:ListJoin(self.petLearned)
    local petUnlearned = self:ListJoin(self.petUnlearned)
    if petUnlearned then self:SystemPrint(self:GetText("yourPetHasUnlearned", petUnlearned)) end
    if petLearned then self:SystemPrint(self:GetText("yourPetHasLearned", petLearned)) end
  end
  wipe(self.petLearned)
  wipe(self.petUnlearned)
  wipe(self.spellsLearned)
  wipe(self.spellsUnlearned)
  wipe(self.pendingTalents)
end

function LA:CreateButton()
  local frame = self.frame
  local buttons = self.buttons
  local count = #buttons
  -- button global variable names start with "SpellButton" to work around an
  -- issue with the Blizzard Feedback Tool used in beta and on the PTR
  local name = "SpellButton_LearningAid_"..(count + 1)
  local button = CreateFrame("CheckButton", name, frame, "LearningAidSpellButtonTemplate")
  local background = _G[name.."Background"]
  background:Hide()
  local subSpellName = _G[name.."SubSpellName"]
  subSpellName:SetTextColor(NORMAL_FONT_COLOR.r - 0.1, NORMAL_FONT_COLOR.g - 0.1, NORMAL_FONT_COLOR.b - 0.1)
  buttons[count + 1] = button
  button.index = count + 1
  button:SetAttribute("type*", "spell")
  button:SetAttribute("type3", "hideButton")
  button:SetAttribute("alt-type*", "hideButton")
  button:SetAttribute("shift-type1", "linkSpell")
  button:SetAttribute("ctrl-type*", "toggleIgnore")
  button.hideButton = function(spellButton, mouseButton, down)
    if not self.inCombat then
      self:ClearButtonIndex(spellButton.index)
    end
  end
  button.linkSpell = function (...) self:SpellButton_OnModifiedClick(...) end
  button.toggleIgnore = function(spellButton, mouseButton, down)
    if spellButton.kind == BOOKTYPE_SPELL then
      self:ToggleIgnore(spellButton.spellName:GetText())
      self:UpdateButton(spellButton)
    end
  end
  button.iconTexture = _G[name.."IconTexture"]
  button.cooldown = _G[name.."Cooldown"]
  button.spellName = _G[name.."SpellName"]
  button.subSpellName = _G[name.."SubSpellName"]
  return button
end
function LA:AddButton(kind, id)
  if kind == BOOKTYPE_SPELL then
    if id > self.numSpells or id < 1 then
      self:DebugPrint("AddButton(): Invalid spell ID", id)
      return
    end
  elseif kind == "MOUNT" or kind == "CRITTER" then
    if id < 1 or id > GetNumCompanions(kind) then
      self:DebugPrint("AddButton(): Invalid companion, type", kind, "ID", id)
      return
    end
  end
  local frame = self.frame
  local buttons = self.buttons
  local visible = self:GetVisible()
  for i = 1, visible do
    if buttons[i].kind == kind and buttons[i]:GetID() == id then
      return
    end
  end
  local button
  -- if bar is full
  if visible == #buttons then
    button = self:CreateButton()
    self:DebugPrint("Adding button id "..id.." index "..button.index)
  else
  -- if bar has free buttons
    button = buttons[self:GetVisible() + 1]
    self:DebugPrint("Changing button index "..(self:GetVisible() + 1).." from id "..button:GetID().." to "..id)
    button:Show()
  end

  button.kind = kind
  self:SetVisible(visible + 1)
  button:SetID(id)
  button:SetChecked(false)
  
  if kind == BOOKTYPE_SPELL then
    -- if id > 1 then
    --   local name, subName = GetSpellBookItemName(id, kind)
    --   local prevName, prevSubName = GetSpellBookItemName(id - 1, kind)
      -- CATA -- if name == prevName then
      --   self:DebugPrint("Found new rank of existing ability "..name.." "..prevRank)
      --   self:ClearButtonID(kind, id - 1)
      -- else
      --   self:DebugPrint(name.." ~= "..prevName)
      -- end
    -- end
    if IsSelectedSpellBookItem(id, kind) then
      button:SetChecked(true)
    end
  elseif kind == "MOUNT" or kind == "CRITTER" then
    -- button.Companion = name
    local creatureID, creatureName, creatureSpellID, icon, isSummoned = GetCompanionInfo(kind, id)
    if isSummoned then
      button:SetChecked(true)
    end
  else
    self:DebugPrint("AddButton(): Invalid button type "..kind)
  end
  self:UpdateButton(button)
  self:AutoSetMaxHeight()
  frame:Show()
end
function LA:ClearButtonID(kind, id)
  local frame = self.frame
  local buttons = self.buttons
  local i = 1
  -- not using a for loop because self.visible may change during the loop execution
  while i <= self:GetVisible() do
    if buttons[i].kind == kind and buttons[i]:GetID() == id then
      self:DebugPrint("Clearing button "..i.." with ID "..buttons[i]:GetID())
      self:ClearButtonIndex(i)
    else
      --self:DebugPrint("Button "..i.." has id "..buttons[i]:GetID().." which does not match "..id)
      i = i + 1
    end
  end
end
function LA:SetMaxHeight(newMaxHeight) -- in buttons, not pixels
  self.maxHeight = newMaxHeight
  self:ReshapeFrame()
end
function LA:GetMaxHeight()
  return self.maxHeight
end
function LA:AutoSetMaxHeight()
  local screenHeight = UIParent:GetHeight()
  self:DebugPrint("Screen Height = ".. screenHeight)
  local newMaxHeight = math.floor((UIParent:GetHeight()-self.titleHeight)/(self.buttonSize+self.verticalSpacing) - 3)
  self:DebugPrint("Setting MaxHeight to " .. newMaxHeight)
  self:SetMaxHeight(newMaxHeight)
  return newMaxHeight
end
function LA:ReshapeFrame()
  local newHeight
  local newWidth
  local maxHeight = self.maxHeight
  local visible = self:GetVisible()
  if visible > maxHeight then
    newHeight = maxHeight
    newWidth = math.ceil(visible / maxHeight)
  else
    newHeight = visible
    newWidth = 1
  end
  local frame = self.frame
  frame:SetHeight(self.titleHeight + 10 + (self.buttonSize + self.verticalSpacing) * newHeight)
  frame:SetWidth(10 + (self.buttonSize + self.horizontalSpacing) * newWidth)
  self.height = newHeight
  self.width = newWidth
  self:ParentButtons()
end
function LA:ParentButtons()
  local buttons = self.buttons
  local visible = self:GetVisible()
  if visible >= 1 then
    buttons[1]:SetPoint("TOPLEFT", self.titleBar, "BOTTOMLEFT", 16, 0)
  end
  for i = 2, visible do
    if i <= self.height then
      buttons[i]:SetPoint("TOPLEFT", buttons[i-1], "BOTTOMLEFT", 0, -self.verticalSpacing)
    else
      buttons[i]:SetPoint("TOPLEFT", buttons[i-self.height], "TOPRIGHT", self.horizontalSpacing, 0)
    end
  end
end
function LA:ClearButtonIndex(index)
-- I have buttons 1 2 3 (4 5)
-- I remove button 2
-- I want 1 3 (3 4 5)
-- before, visible = 3
-- after, visible = 2
  local frame = self.frame
  local buttons = self.buttons
  local visible = self:GetVisible()
  for i = index, visible - 1 do
    local button = buttons[i]
    local nextButton = buttons[i + 1]
    button:SetID(nextButton:GetID())
    button:SetChecked(nextButton:GetChecked())
    button.kind = nextButton.kind
    button.iconTexture:SetVertexColor(nextButton.iconTexture:GetVertexColor())
    local cooldown = button.cooldown
    local nextCooldown = nextButton.cooldown
    cooldown.start = nextCooldown.start
    cooldown.duration = nextCooldown.duration
    cooldown.enable = nextCooldown.enable
    if cooldown.start and cooldown.duration and cooldown.enable then 
      CooldownFrame_SetTimer(cooldown, cooldown.start, cooldown.duration, cooldown.enable)
    else
      cooldown:Hide()
    end
    --if buttons[i]:IsShown() then
    self:UpdateButton(button)
    --end
  end
  buttons[visible]:Hide()
  self:SetVisible(visible - 1)
  self:ReshapeFrame()
end
function LA:SetVisible(visible)
  local frame = self.frame
  self.visible = visible
  local top, left = frame:GetTop(), frame:GetLeft()
  frame:SetHeight(self.titleHeight + 10 + (self.buttonSize + self.verticalSpacing) * visible)
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
  if visible == 0 then
    frame:Hide()
  end
end
function LA:GetVisible()
  return self.visible
end
function LA:Hide()
  local frame = self.frame
  if not self.inCombat then
    for i = 1, self:GetVisible() do
      self.buttons[i]:SetChecked(false)
      self.buttons[i]:Hide()
    end
    self:SetVisible(0)
  else
    table.insert(self.queue, { kind = "HIDE" })
  end
end
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

--[[
function LA:DebugPrint(...)
  if self.saved and self.saved.debug and self.saved.enabled then
    private:DebugPrint(...)
  end
end
--]]

function LA:ListJoin(...)
  local str = ""
  local argc = select("#", ...)
  if argc == 1 and type(...) == "table" then
    self:ListJoin(unpack(...))
  elseif argc >= 1 then
    str = str..tostring((...))
    for i = 2, argc do
      str = str..", "..tostring((select(i, ...)))
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
-- when debugging is enabled, calls to LA:DebugPrint will be shunted to private:DebugPrint
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
  local debugFlags = private.debugFlags
  local oldValue = debugFlags[flag]
  --newValue = (newValue and true or false) -- boolean-ify
  if flag == nil then -- initialize
    newDebug = 0
    for savedFlag, savedValue in pairs(self.saved.debugFlags) do
      debugFlags[savedFlag] = savedValue
      if savedValue then
        newDebug = newDebug + 1
      end
    end
  elseif newValue == nil then
    return oldValue
  elseif newValue ~= oldValue then
    debugFlags[flag] = newValue
    newDebug = newDebug + (newValue and 1 or -1)
  end
  local shadow = private.shadow
  if oldDebug == 0 and newDebug > 0 then -- we're turning debugging on
--    LA.frame:SetScript("OnEvent", private.onEventDebug)
--    LA.frame:RegisterAllEvents()
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
--[[
    LA.frame:SetScript("OnEvent", private.onEvent)
    LA.frame:UnregisterAllEvents()
    for event, bool in pairs(LA.events) do
      if bool then
        LA.frame:RegisterEvent(event)
      end
    end
]]
  end
  private.debug = newDebug
end

function LA:OnShow()
  self:RegisterEvent("COMPANION_UPDATE", "OnEvent")
  self:RegisterEvent("TRADE_SKILL_SHOW", "OnEvent")
  self:RegisterEvent("TRADE_SKILL_CLOSE", "OnEvent")
  self:RegisterEvent("SPELL_UPDATE_COOLDOWN", "OnEvent")
  self:RegisterEvent("CURRENT_SPELL_CAST_CHANGED", "OnEvent")
end
function LA:OnHide()
  self:UnregisterEvent("COMPANION_UPDATE")
  self:UnregisterEvent("TRADE_SKILL_SHOW")
  self:UnregisterEvent("TRADE_SKILL_CLOSE")
  self:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
  self:UnregisterEvent("CURRENT_SPELL_CAST_CHANGED")
end
function LA:Lock()
    self.saved.locked = true
    self.menuTable[1].text = self:GetText("unlockPosition")
end
function LA:Unlock()
    self.saved.locked = false
    self.menuTable[1].text = self:GetText("lockPosition")
end
function LA:ToggleLock()
  if self.saved.locked then
    self:Unlock()
  else
    self:Lock()
  end
end
function LA:PurgeConfig()
  wipe(self.saved)
  wipe(self.character)
  self:SetDefaultSettings()
end