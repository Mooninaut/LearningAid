-- LearningAid v1.07 by Jamash (Kil'jaeden-US)

LearningAid = LibStub("AceAddon-3.0"):NewAddon("LearningAid", "AceConsole-3.0", "AceEvent-3.0")
local LA = LearningAid
--LearningAid_Saved = {}
--[[
local eventFrame = CreateFrame("Frame", nil, UIParent)
eventFrame:RegisterAllEvents()
eventFrame:SetScript("OnEvent", function (self, event, ...)
  local actionType, actionID, actionSubType, absoluteID = GetActionInfo(1)
  if actionType then
    print("Action Bar info available at event", event, ...)
    print(actionType, actionID, actionSubType, absoluteID)
    eventFrame:UnregisterAllEvents()
  end
end)
--]]
-- Adapted from SpellBookFrame.lua
function LA:UpdateButton(button)
  local id = button:GetID();

  local name = button:GetName();
  local iconTexture = getglobal(name.."IconTexture");
  local spellString = getglobal(name.."SpellName");
  local subSpellString = getglobal(name.."SubSpellName");
  local cooldown = getglobal(name.."Cooldown");
  local autoCastableTexture = getglobal(name.."AutoCastable");
  local highlightTexture = getglobal(name.."Highlight");
  local normalTexture = getglobal(name.."NormalTexture");
  if not self.inCombat then
    button:Enable();
  end

  if button.kind == BOOKTYPE_SPELL then

    local texture = GetSpellTexture(id, BOOKTYPE_SPELL);

    -- If no spell, hide everything and return
    if ( not texture or (strlen(texture) == 0) ) then
      iconTexture:Hide();
      spellString:Hide();
      subSpellString:Hide();
      cooldown:Hide();
      autoCastableTexture:Hide();
      SpellBook_ReleaseAutoCastShine(button.shine)
      button.shine = nil;
      highlightTexture:SetTexture("Interface\\Buttons\\ButtonHilight-Square");
      button:SetChecked(0);
      normalTexture:SetVertexColor(1.0, 1.0, 1.0);
      return;
    end

    local start, duration, enable = GetSpellCooldown(id, BOOKTYPE_SPELL);
    CooldownFrame_SetTimer(cooldown, start, duration, enable);
    cooldown.start = start
    cooldown.duration = duration
    cooldown.enable = enable
    if ( enable == 1 ) then
      iconTexture:SetVertexColor(1.0, 1.0, 1.0);
    else
      iconTexture:SetVertexColor(0.4, 0.4, 0.4);
    end

    local spellName, subSpellName = GetSpellName(id, BOOKTYPE_SPELL);

    normalTexture:SetVertexColor(1.0, 1.0, 1.0);
    highlightTexture:SetTexture("Interface\\Buttons\\ButtonHilight-Square");
    spellString:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);

  -- Set Secure Action Button attribute
    if not self.inCombat then
      button:SetAttribute("spell*", spellName)
    end

    iconTexture:SetTexture(texture);
    spellString:SetText(spellName);
    subSpellString:SetText(subSpellName);
    if ( subSpellName ~= "" ) then
      spellString:SetPoint("LEFT", button, "RIGHT", 4, 4);
    else
      spellString:SetPoint("LEFT", button, "RIGHT", 4, 2);
    end
  elseif button.kind == "MOUNT" or button.kind == "CRITTER" then

    -- Some companions have two names, the display name and the spell name
    -- Make sure to use the spell name for casting
    local creatureID, creatureName, creatureSpellID, icon, isSummoned = GetCompanionInfo(button.kind, id)
    local spellName = GetSpellInfo(creatureSpellID);
    iconTexture:SetTexture(icon)
    spellString:SetText(creatureName)
    subSpellString:SetText("")
    if not self.inCombat then
      button:SetAttribute("spell*", spellName)
    end
  end
  iconTexture:Show();
  spellString:Show();
  subSpellString:Show();
  --SpellButton_UpdateSelection(self);
end
-- Adapted from SpellBookFrame.lua
function LA:SpellButton_OnDrag(button) 
  local id = button:GetID();
  if button.kind == BOOKTYPE_SPELL then
    PickupSpell(id, button.kind);
  elseif button.kind == "MOUNT" or button.kind == "CRITTER" then
    PickupCompanion(button.kind, id)
  end
end
-- Adapted from SpellBookFrame.lua
function LA:SpellButton_OnEnter(button)
  local id = button:GetID();
  local kind = button.kind
  GameTooltip:SetOwner(button, "ANCHOR_RIGHT");
  if kind == BOOKTYPE_SPELL then
    if GameTooltip:SetSpell(id, BOOKTYPE_SPELL) then
      button.UpdateTooltip = function (...) self:SpellButton_OnEnter(...) end
    else
      button.UpdateTooltip = nil
    end
  elseif kind == "MOUNT" or kind == "CRITTER" then
    local creatureID, creatureName, creatureSpellID, icon, isSummoned = GetCompanionInfo(kind, id)
    if GameTooltip:SetHyperlink("spell:"..creatureSpellID) then
      button.UpdateTooltip = function (...) self:SpellButton_OnEnter(...) end
    else
      button.UpdateTooltip = nil;
    end
  else
    print("Invalid button type in LearningAid:SpellButton_OnEnter: "..button.kind)
  end
end
-- Adapted from SpellBookFrame.lua
function LA:SpellButton_UpdateSelection(button)
  if button.kind == BOOKTYPE_SPELL then
    local id = button:GetID()
    if IsSelectedSpell(id, BOOKTYPE_SPELL) then
      button:SetChecked("true");
    else
      button:SetChecked("false");
    end
  end
end
-- Adapted from SpellBookFrame.lua
function LA:SpellButton_OnModifiedClick(spellButton, mouseButton) 
  local id = spellButton:GetID()
  local spellName, subSpellName
  if spellButton.kind == BOOKTYPE_SPELL then
    if ( id > MAX_SPELLS ) then
      return;
    end
    if ( IsModifiedClick("CHATLINK") ) then
      if ( MacroFrame and MacroFrame:IsShown() ) then
        spellName, subSpellName = GetSpellName(id, BOOKTYPE_SPELL);
          if ( spellName and not IsPassiveSpell(id, BOOKTYPE_SPELL) ) then
            if ( subSpellName and (strlen(subSpellName) > 0) ) then
              ChatEdit_InsertLink(spellName.."("..subSpellName..")");
            else
              ChatEdit_InsertLink(spellName);
            end
          end
        return;
      else
        local spellLink = GetSpellLink(id, BOOKTYPE_SPELL);
          if(spellLink) then
            ChatEdit_InsertLink(spellLink);
          end
        return;
      end
    end
    if ( IsModifiedClick("PICKUPACTION") ) then
      PickupSpell(id, BOOKTYPE_SPELL);
      return;
    end
  elseif spellButton.kind == "MOUNT" or spellButton.kind == "CRITTER" then
    local creatureID, creatureName, creatureSpellID, icon, isSummoned = GetCompanionInfo(spelButton.kind, id)
    if ( IsModifiedClick("CHATLINK") ) then
      if ( MacroFrame and MacroFrame:IsShown() ) then
        local spellName = GetSpellInfo(creatureSpellID);
        ChatEdit_InsertLink(spellName);
      else
        local spellLink = GetSpellLink(creatureSpellID)
        ChatEdit_InsertLink(spellLink);
      end
    elseif ( IsModifiedClick("PICKUPACTION") ) then
      self.SpellButton_OnDrag(spellButton);
    end
  end
end
function LA:OnInitialize()
  if not LearningAid_Saved then LearningAid_Saved = {} end
  if not LearningAid_Character then LearningAid_Character = {} end
  self.saved = LearningAid_Saved
  self.character = LearningAid_Character
  self.version = "1.07"
  self.saved.version = self.version
  self.character.version = self.version
  if self.saved.macros == nil then self.saved.macros = true end
  if self.saved.enabled == nil then self.saved.enabled = true end
  self:DebugPrint("LearningAid:OnInitialize()")
  self.titleHeight = 40
  self.width = 170
  self.buttonSpacing = 5
  self.buttonSize = 37
  self.titleText = "Learning Aid"
  self.lockText = "Lock Position"
  self.unlockText = "Unlock Position"
  self.closeText = "Close"
  local version, build, date, tocversion = GetBuildInfo()
  self.tocVersion = tocversion
  self.companionCache = {}
  self.menuHideDelay = 5
  self.inCombat = false
  self.retalenting = false
  self.activatePrimarySpec = GetSpellInfo(63645)
  self.activateSecondarySpec = GetSpellInfo(63644)
  self.queue = {}

  -- create main frame
  local frame = CreateFrame("Frame", "LearningAid_Frame", UIParent)
  self.frame = frame
  frame:SetWidth(self.width)
  frame:SetHeight(self.titleHeight)
  frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -200, -200)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:SetScript("OnShow", function () self:OnShow() end)
  frame:SetScript("OnHide", function () self:OnHide() end)
  frame.buttons = {}
  frame.visible = 0
  frame:Hide()
  local backdrop = {
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
    edgeFile = "Interface/DialogFrame/UI-DialogBox-Gold-Border",
    tile = false, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  }
  frame:SetBackdrop(backdrop)

  -- create title bar
  local titleBar = CreateFrame("Frame", "LearningAid_Frame_TitleBar", frame)
  frame.titleBar = titleBar
  titleBar:SetPoint("TOPLEFT")
  titleBar:SetPoint("TOPRIGHT")
  titleBar:SetHeight(self.titleHeight)
  titleBar:RegisterForDrag("LeftButton")
  titleBar:EnableMouse()
  titleBar.text = titleBar:CreateFontString("LearningAid_Frame_Title_Text", "OVERLAY", "GameFontNormalLarge")
  titleBar.text:SetText(self.titleText)
  titleBar.text:SetPoint("CENTER", titleBar, "CENTER", 0, 0)

  -- create close button
  local closeButton = CreateFrame("Button", "LearningAid_Frame_CloseButton", titleBar)
  frame.closeButton = closeButton
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
    { text = self.lockText, 
      func = function () self:ToggleLock() end },
    { text = self.closeText,
      func = function () self:Hide() end }
  }

  local menu = CreateFrame("Frame", "LearningAid_Menu", titleBar, "UIDropDownMenuTemplate")

  -- set drag and click handlers for the title bar
  titleBar:SetScript(
    "OnDragStart",
    function (self, button)
      if not LA.saved.locked then
        self:GetParent():StartMoving()
      end
    end
  )

  titleBar:SetScript(
    "OnDragStop",
    function (self)
      local parent = self:GetParent()
      parent:StopMovingOrSizing()
      LA.saved.x = parent:GetLeft()
      LA.saved.y = parent:GetTop()
    end
  )

  titleBar:SetScript(
    "OnMouseUp",
    function (self, button)
      if button == "MiddleButton" then
        LA:Hide()
      elseif button == "RightButton" then
        EasyMenu(LA.menuTable, menu, titleBar, 0, 8, "MENU", LA.menuHideDelay)
      end
    end
  )

  -- set up the slash command
  --SlashCmdList["LearningAid"] = function(msg) self:SlashCommand(msg) end
  --SLASH_LearningAid1 = "/learningaid"
  --SLASH_LearningAid2 = "/la"

  --self:CreateOptionsPanel()
  self.options = {
    handler = LA,
    type = "group",
    args = {
      lock = {
        name = "Lock Frame",
        desc = "Locks the Learning Aid frame so it cannot by moved by accident",
        type = "toggle",
        set = function(info, val) if val then self:Lock() else self:Unlock() end end,
        get = function(info) return self.saved.locked end,
        width = "full",
        order = 1
      },
      debug = {
        name = "Debug Output",
        desc = "Enables / disables printing debugging information to the chat frame",
        type = "toggle",
        set = function(info, val) self.saved.debug = val end,
        get = function(info) return self.saved.debug end,
        width = "full",
        order = 2
      },
      reset = {
        name = "Reset Position",
        desc = "Reset the position of the Learning Aid frame to the default",
        type = "execute",
        func = "ResetFramePosition",
        width = "full",
        order = 3
      },
      missing = {
        name = "Find Missing Abilities",
        desc = "Search the spellbook and action bars to find spells or abilities which are not on any action bar",
        type = "execute",
        func = "FindMissingActions",
        width = "full",
        order = 4
      },
      tracking = {
        name = "Find Tracking Abilities",
        desc = "If enabled, Find Missing Abilities will search for Tracking Abilities as well",
        type = "toggle",
        set = function(info, val) self.saved.tracking = val end,
        get = function(info, val) return self.saved.tracking end,
        width = "full",
        order = 5
      },
      shapeshift = {
        name = "Find Shapeshift Forms",
        desc = "If enabled, Find Missing Abilities will search for forms, auras, stances, presences, etc.",
        type = "toggle",
        set = function(info, val) self.saved.shapeshift = val end,
        get = function(info, val) return self.saved.shapeshift end,
        width = "full",
        order = 6
      },
      macros = {
        name = "Search Macros",
        desc = "If enabled, Find Missing Abilities will search macros for spells",
        type = "toggle",
        set = function(info, val) self.saved.macros = val end,
        get = function(info, val) return self.saved.macros end,
        width = "full",
        order = 7
      },
      unlock = {
        name = "Unlock frame",
        desc = "Unlocks the Learning Aid frame so it can be moved",
        type = "execute",
        guiHidden = true,
        func = "Unlock"
      },
      config = {
        name = "Configure",
        desc = "Open the Learning Aid configuration panel",
        type = "execute",
        func = function() InterfaceOptionsFrame_OpenToCategory(self.optionsFrame) end,
        guiHidden = true
      },
      test = {
        type = "group",
        name = "Test",
        desc = "Perform various tests with Learning Aid",
        guiHidden = true,
        args = {
          add = {
            type = "group",
            name = "Add",
            desc = "Add a button to the Learning Aid frame",
            args = {
              spell = {
                type = "input",
                name = "Spell",
                pattern = "^%d+$",
                set = function(info, val)
                  self:AddButton("spell", tonumber(val))
                end,
              },
              mount = {
                type = "input",
                name = "Mount",
                pattern = "^%d+$",
                set = function(info, val)
                  self:AddButton("MOUNT", tonumber(val))
                end,
              },
              critter = {
                type = "input",
                name = "Critter (Minipet)",
                pattern = "^%d+$",
                set = function(info, val)
                  self:AddButton("CRITTER", tonumber(val))
                end,
              }
            }
          },
          remove = {
            type = "group",
            name = "Remove",
            desc = "Remove a button from the Learning Aid frame",
            args = {
              spell = {
                type = "input",
                name = "Spell",
                pattern = "^%d+$",
                set = function(info, val)
                  self:ClearButtonID("spell", tonumber(val))
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
  LibStub("AceConfig-3.0"):RegisterOptionsTable("LearningAidConfig", self.options, {"la", "learningaid"})
  self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("LearningAidConfig", self.titleText)
  hooksecurefunc("ConfirmTalentWipe", function() 
    print("LearningAid:ConfirmTalentWipe")
    self:SaveActionBars()
    self.untalenting = true
    self:RegisterEvent("ACTIONBAR_SLOT_CHANGED", "OnEvent")
    self:RegisterEvent("PLAYER_TALENT_UPDATE", "OnEvent")
    self:RegisterEvent("UI_ERROR_MESSAGE", "OnEvent")
  end) -- PLACEHOLDER
  self:RegisterChatCommand("la", "AceSlashCommand")
  self:RegisterChatCommand("learningaid", "AceSlashCommand")
  self:SetEnabledState(self.saved.enabled)
  
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
function LA:OnEvent(event, ...)
  self:DebugPrint(event, ...)
  if LearningAid[event] then
    LearningAid[event](self, ...)
  end
end
function LA:OnEnable()
  self.saved.enabled = true
  self:DebugPrint("LearningAid:OnEnable()")
  self:RegisterEvent("SPELLS_CHANGED", "OnEvent")
  self:RegisterEvent("COMPANION_LEARNED", "OnEvent")
  --self:RegisterEvent("COMPANION_UPDATE")
  --self:RegisterEvent("TRADE_SKILL_SHOW")
  --self:RegisterEvent("TRADE_SKILL_CLOSE")
  --self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
  --self:RegisterEvent("CURRENT_SPELL_CAST_CHANGED")
  self:RegisterEvent("VARIABLES_LOADED", "OnEvent")
  self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEvent")
  self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
  --self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  self:RegisterEvent("UNIT_SPELLCAST_START", "OnEvent")
  self:RegisterEvent("PLAYER_LEAVING_WORLD", "OnEvent")
  self:RegisterEvent("PLAYER_LOGOUT", "OnEvent")
  self:UpdateSpellBook()
  self:UpdateCompanions()
  self:DiffActionBars()
  self:SaveActionBars()
end
function LA:OnDisable()
  self:Hide()
  self.saved.enabled = false
end
function LA:PLAYER_REGEN_DISABLED()
  self.inCombat = true
  self.frame.closeButton:Disable()
end
function LA:PLAYER_REGEN_ENABLED()
  self.inCombat = false
  self.frame.closeButton:Enable()
  self:ProcessQueue()
end
function LA:SPELLS_CHANGED()
  if self.spellBookCache ~= nil then
    if not self:DiffSpellBook() then
      self:DebugPrint("Event SPELLS_CHANGED fired without spell changes")
    end
  end
end
function LA:COMPANION_LEARNED()
  self:DiffCompanions()
  self:UpdateCompanions()
end
function LA:COMPANION_UPDATE()
  local frame = self.frame
  local buttons = frame.buttons
  for i = 1, frame.visible do
    local button = buttons[i]
    local kind = button.kind
    if kind == "MOUNT" or kind == "CRITTER" then
      local creatureID, creatureName, creatureSpellID, icon, isSummoned = GetCompanionInfo(kind, button:GetID())
      if isSummoned then
        button:SetChecked(true)
      else
        button:SetChecked(false)
      end
    end
  end
end
function LA:TRADE_SKILL_SHOW()
  local frame = self.frame
  local buttons = frame.buttons
  for i = 1, frame.visible do
    local button = buttons[i]
    if button.kind == BOOKTYPE_SPELL then
      if IsSelectedSpell(button:GetID(), button.kind) then
        button:SetChecked(true)
      else
        button:SetChecked(false)
      end
    end
  end
end
LA.TRADE_SKILL_CLOSE = LA.TRADE_SKILL_SHOW
function LA:SPELL_UPDATE_COOLDOWN()
  local frame = self.frame
  local buttons = frame.buttons
  for i = 1, frame.visible do
    local button = buttons[i]
    if button.kind == BOOKTYPE_SPELL then
      self:UpdateButton(button)
    elseif button.kind == "MOUNT" or button.kind == "CRITTER" then
      local start, duration, enable = GetCompanionCooldown(button.kind, button:GetID())
      CooldownFrame_SetTimer(button.cooldown, start, duration, enable);
    end
  end
end
function LA:CURRENT_SPELL_CAST_CHANGED()
  local frame = self.frame
  local buttons = frame.buttons
  for i = 1, frame.visible do
    local button = buttons[i]
    if button.kind == BOOKTYPE_SPELL then
      self:SpellButton_UpdateSelection(button)
    end
  end
end
function LA:UNIT_SPELLCAST_START(unit, spell)
  if unit == "player" and (spell == self.activatePrimarySpec or spell == self.activateSecondarySpec) then
    self:DebugPrint("Learning Aid: Talent swap initiated")
    self.retalenting = true
    self:RegisterEvent("PLAYER_TALENT_UPDATE", "OnEvent")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", "OnEvent")
  end
end
function LA:UNIT_SPELLCAST_INTERRUPTED(unit, spell)
  if unit == "player" and (spell == self.activatePrimarySpec or spell == self.activateSecondarySpec) then
    self:DebugPrint("Learning Aid: Talent swap canceled")
    self.retalenting = false
    self:UnregisterEvent("PLAYER_TALENT_UPDATE", "OnEvent")
    self:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED", "OnEvent")
  end
end
function LA:PLAYER_TALENT_UPDATE()
  if self.retalenting then
    self:DebugPrint("Learning Aid: Talent swap completed")
    self.retalenting = false
    self:UnregisterEvent("PLAYER_TALENT_UPDATE")
    self:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED")
  elseif self.untalenting then
    self.untalenting = false
    self:UnregisterEvent("ACTIONBAR_SLOT_CHANGED")
    self:UnregisterEvent("PLAYER_TALENT_UPDATE")
  end
end
function LA:PLAYER_LEAVING_WORLD()
  self:UnregisterEvent("SPELLS_CHANGED", "OnEvent")
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
end
function LA:PLAYER_ENTERING_WORLD()
  self:RegisterEvent("SPELLS_CHANGED", "OnEvent")
end
function LA:VARIABLES_LOADED()
  if self.saved.locked then
    self.menuTable[1].text = self.unlockText
  else
    self.saved.locked = false
  end
  if self.saved.x and self.saved.y then
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", self.saved.x, self.saved.y)
  end
end

function LA:ACTIONBAR_SLOT_CHANGED(slot)
-- actionbar1 = ["spell" 2354] ["macro" 5] [nil]
-- then after untalenting actionbar1 = [nil] ["macro" 5] [nil]
-- self.character.actions[spec][1] = 2354
  
  if self.untalenting then
    -- something something on (slot)
    local spec = GetActiveTalentGroup()
    local actionType, actionID, actionSubType, absoluteID = GetActionInfo(slot)
    local oldID = self.character.actions[spec][slot]
    self:DebugPrint("Action Slot "..slot.." changed:",
      (actionType or "")..",",
      (actionID or "")..",",
      (actionSubType or "")..",",
      (absoluteID or "")..",",
      (oldID or "")
    )
    if oldID and (actionType ~= "spell" or absoluteID ~= oldID) then
      if not self.character.unlearned then self.character.unlearned = {} end
      if not self.character.unlearned[spec] then self.character.unlearned[spec] = {} end
      self.character.unlearned[spec][slot] = oldID
    end
  end
end
function LA:UI_ERROR_MESSAGE()
  if self.untalenting then
    self:UnregisterEvent("ACTIONBAR_SLOT_CHANGED")
    self:UnregisterEvent("UI_ERROR_MESSAGE")
    self.untalenting = false
  end
end
function LA:PLAYER_LOGOUT()
  self:SaveActionBars()
end
function LA:DiffActionBars()
  local spec = GetActiveTalentGroup()
  for slot = 1, 120 do
    local actionType = GetActionInfo(slot)
    -- local actionType, actionID, actionSubType, globalID = GetActionInfo(slot)
    if self.character.actions and 
       self.character.actions[spec] and
       self.character.actions[spec][slot] and
       not actionType
    then
      if not self.character.unlearned then self.character.unlearned = {} end
      if not self.character.unlearned[spec] then self.character.unlearned[spec] = {} end
      self.character.unlearned[spec][slot] = self.character.actions[spec][slot]
    end
  end
end
function LA:UpdateCompanions()
  self:UpdateCompanionType("MOUNT")
  self:UpdateCompanionType("CRITTER")
end
function LA:UpdateCompanionType(kind)
  self.companionCache[kind] = {}
  local cache = self.companionCache[kind]
  local i = 1
  local creatureID, creatureName, creatureSpellID, icon, isSummoned = GetCompanionInfo(kind, i)
  while creatureName do
    cache[i] = creatureName
    i = i + 1
    creatureID, creatureName, creatureSpellID, icon, isSummoned = GetCompanionInfo(kind, i)
  end
end
function LA:DiffCompanions()
  self:DiffCompanionType("MOUNT")
  self:DiffCompanionType("CRITTER")
end
function LA:AddCompanion(kind, id)
  if self.inCombat then
    table.insert(self.queue, { action = "LEARN", id = id, kind = kind})
  else
    self:LearnSpell(kind, id)
    self:AddButton(kind, id)
  end
end
function LA:DiffCompanionType(kind)
  local i = 1
  local creatureID, creatureName, creatureSpellID, icon, isSummoned = GetCompanionInfo(kind, i)
  local cache = self.companionCache[kind]
  local updated = false
  while creatureName do 
    if cache[i] == nil or
       cache[i] ~= creatureName then
      self:DebugPrint("Found new companion, type "..kind..", index "..i)
      self:UpdateCompanionType(kind)
      self:AddCompanion(kind, i)
      updated = true
      break
    end
    i = i + 1
    creatureID, creatureName, creatureSpellID, icon, isSummoned = GetCompanionInfo(kind, i)
  end
  return updated
end
function LA:UpdateSpellBook()
  self.spellBookCache = {}
  local i = 1
  local spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL)
  while spellName do
    spellRank = tonumber(string.match(spellRank, "%d+")) or 0
    local spellAbsoluteID = self:AbsoluteSpellID(i)
    local spellIsPassive = IsPassiveSpell(i, BOOKTYPE_SPELL) or false
    self.spellBookCache[i] = {
      name = spellName,
      rank = spellRank,
      absoluteID = spellAbsoluteID,
      passive = spellIsPassive,
      spellBookID = i
    }
    i = i + 1
    spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL)
  end
  self:DebugPrint("Updated Spellbook, "..i.." spells found")
end
function LA:AddSpell(id)
  if self.inCombat then
    table.insert(self.queue, { action = "LEARN", id = id, kind = BOOKTYPE_SPELL })
  else
    self:LearnSpell(BOOKTYPE_SPELL, id)
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
function LA:ProcessQueue()
  if self.inCombat then
    self:DebugPrint("Cannot process action queue during combat in LearningAid:ProcessQueue")
    return
  end
  local queue = self.queue
  for index = 1, #queue do
    local item = queue[index]
    if item.action == "ADD" then
      self:AddButton(item.kind, item.id)
    elseif item.action == "CLEAR" then
      self:ClearButtonID(item.kind, item.id)
    elseif item.kind == BOOKTYPE_SPELL then
      if item.action == "LEARN" then
        self:AddSpell(item.id)
      elseif item.action == "FORGET" then
        self:RemoveSpell(item.id)
      else
        self:DebugPrint("Invalid action type " .. item.action .. " in LearningAid:ProcessQueue")
      end
    elseif item.kind == "CRITTER" or item.kind == "MOUNT" then
      if item.action == "LEARN" then
        self:AddCompanion(item.kind, item.id)
      else
        self:DebugPrint("Invalid action type " .. item.action .. "in LearningAid:ProcessQueue")
      end
    elseif item.kind == "HIDE" then
      self:Hide()
    else
      self:DebugPrint("Invalid entry type " .. item.kind .. " in LearningAid:ProcessQueue")
    end
  end
  self.queue = {}
end
function LA:DiffSpellBook()
  local i = 1
  local cache = self.spellBookCache
  local updated = false
  local spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL)
  local spellAbsoluteID = self:AbsoluteSpellID(i)
  while spellName do
    if cache[i] == nil or
       cache[i].absoluteID ~= spellAbsoluteID then
      -- if spell removed
      if cache[i + 1] ~= nil and
         cache[i+1].absoluteID == spellAbsoluteID then
        self:DebugPrint("Old spell removed: "..cache[i].name.." ("..cache[i].rank..") id "..(i))
        self:UpdateSpellBook()
        self:RemoveSpell(i)
      else
        self:DebugPrint("New spell found: "..spellName.." ("..spellRank..")") -- Old spell: "..cache[i + offset].name.." ("..cache[i + offset].rank..")")
        self:UpdateSpellBook()
        self:AddSpell(i)
      end
      updated = true
      break
    end
    i = i + 1
    spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL)
    spellAbsoluteID = self:AbsoluteSpellID(i)
  end
  -- if the last spell in the spellbook is removed
  if i == #cache and not updated then
    self:DebugPrint("Last spell removed: "..cache[i].name.." ("..cache[i].rank..") id "..i)
    self:UpdateSpellBook()
    self:RemoveSpell(i)
    updated = true
  end
  return updated
end
function LA:LearnSpell(kind, id)
  local frame = self.frame
  local buttons = frame.buttons
  for i = 1, frame.visible do
    local button = buttons[i]
    local buttonID = button:GetID()
    if button.kind == kind and buttonID >= id then
      button:SetID(buttonID + 1)
      self:UpdateButton(button)
    end
  end
  local spec = GetActiveTalentGroup()
  if (not self.retalenting) and
      kind == BOOKTYPE_SPELL and
      self.character.unlearned and
      self.character.unlearned[spec] then
    local absoluteID = self:AbsoluteSpellID(id)
    for slot, oldID in pairs(self.character.unlearned[spec]) do
      local actionType = GetActionInfo(slot)
      --local actionType, actionID, actionSubType, absoluteID = GetActionInfo(slot)
      if oldID == absoluteID and actionType == nil then
        PickupSpell(id, BOOKTYPE_SPELL)
        PlaceAction(slot)
        self.character.unlearned[spec][slot] = nil
      end
    end
  end
end
function LA:ForgetSpell(id)
  local frame = self.frame
  local buttons = frame.buttons
  for i = 1, frame.visible do
    local button = buttons[i]
    local buttonID = button:GetID()
    if button.kind == BOOKTYPE_SPELL and buttonID > id then
      button:SetID(buttonID - 1)
      self:UpdateButton(button)
    end
  end
end
function LA:CreateButton()
  local frame = self.frame
  local buttons = frame.buttons
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
  if count > 0 then
    -- position relative to button above
    button:SetPoint("TOP", buttons[count], "BOTTOM", 0, -self.buttonSpacing)
  else
    -- position relative to header
    button:SetPoint("TOPLEFT", frame.titleBar, "BOTTOMLEFT", 16, 0)
  end
  button:SetAttribute("type*", "spell")
  button:SetAttribute("type3", "hideButton")
  button:SetAttribute("alt-type*", "hideButton")
  button:SetAttribute("shift-type1", "linkSpell")
  button.hideButton = function(spellButton, mouseButton, down)
    if not self.inCombat then
      self:ClearButtonIndex(spellButton.index)
    end
  end
  button.linkSpell = function (...) self:SpellButton_OnModifiedClick(...) end
  button.iconTexture = _G[name.."IconTexture"]
  button.cooldown = _G[name.."Cooldown"]
  return button
end
function LA:SpellButton_OnHide(button)
  self:DebugPrint("Hiding button "..button.index)
  button:SetChecked(false)
  button.iconTexture:SetVertexColor(1, 1, 1)
  button.cooldown:Hide()
end
function LA:AddButton(kind, id)
  if kind == BOOKTYPE_SPELL then
    if id > #self.spellBookCache or id < 1 then
      self:DebugPrint("LearningAid:AddButton() - Invalid spell ID", id)
      return
    end
  elseif kind == "MOUNT" or kind == "CRITTER" then
    if id > #self.companionCache[kind] or id < 1 then
      self:DebugPrint("LearningAid:AddButton() - Invalid companion type", kind, "ID", id)
      return
    end
  end
  local frame = self.frame
  local buttons = frame.buttons
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
    button = buttons[frame.visible + 1]
    self:DebugPrint("Changing button index "..(frame.visible + 1).." from id "..button:GetID().." to "..id)
    button:Show()
  end

  button.kind = kind
  self:SetVisible(visible + 1)
  button:SetID(id)
  button:SetChecked(false)
  
  if kind == BOOKTYPE_SPELL then
    if id > 1 then
      local name, rank = GetSpellName(id, BOOKTYPE_SPELL)
      local prevName, prevRank = GetSpellName(id - 1, BOOKTYPE_SPELL)
      if name == prevName then
        self:DebugPrint("Found new rank of existing ability "..name.." "..prevRank)
        self:ClearButtonID(kind, id - 1)
      else
        self:DebugPrint(name.." ~= "..prevName)
      end
    end
    if IsSelectedSpell(id, kind) then
      button:SetChecked(true)
    end
  elseif kind == "MOUNT" or kind == "CRITTER" then
    -- button.Companion = name
    local creatureID, creatureName, creatureSpellID, icon, isSummoned = GetCompanionInfo(kind, id)
    if isSummoned then
      button:SetChecked(true)
    end
  else
    print("Invalid button type "..kind.." in LearningAid.AddButton()")
  end
  self:UpdateButton(button)
  frame:Show()
end
function LA:ClearButtonID(kind, id)
  local frame = self.frame
  local buttons = frame.buttons
  local i = 1
  -- not using a for loop because frame.visible may change during the loop execution
  while i <= self:GetVisible() do
    if buttons[i].kind == kind and buttons[i]:GetID() == id then
      self:DebugPrint("Clearing button "..i.." with ID "..buttons[i]:GetID())
      self:ClearButtonIndex(i)
    else
      self:DebugPrint("Button "..i.." has id "..buttons[i]:GetID().." which does not match "..id)
      i = i + 1
    end
  end
end
LA.castSlashCommands = {
  [SLASH_USE1] = true,
  [SLASH_USE2] = true,
  [SLASH_USERANDOM1] = true,
  [SLASH_USERANDOM2] = true,
  [SLASH_CAST1] = true,
  [SLASH_CAST2] = true,
  [SLASH_CAST3] = true,
  [SLASH_CAST4] = true,
  [SLASH_CASTRANDOM1] = true,
  [SLASH_CASTRANDOM2] = true,
  [SLASH_CASTSEQUENCE1] = true,
  [SLASH_CASTSEQUENCE2] = true
}
function LA:MacroSpells(macroText)
  macroText = string.lower(macroText)
  local spells = {}
  local first, last, line
  first, last, line = macroText:find("([^\n]+)[\n]?")
  while first ~= nil do
    self:DebugPrint("Line",line)
    local lineFirst, lineLast, slash = line:find("^(/%a+)%s+")
    if lineFirst ~= nil then
      self:DebugPrint('Slash "'..slash..'"')
      if self.castSlashCommands[slash] then
        --self:DebugPrint("found slash command")
        local token
        local linePos = lineLast
        local found = true
        -- ignore reset=
        lineFirst, lineLast = line:find("^reset=%S+%s*", linePos + 1)
        if lineLast ~= nil then linePos = lineLast end
        while found do
          while found do
            found = false
            -- ignore macro options
            lineFirst, lineLast = line:find("^%[[^%]]*]", linePos + 1)
            if lineLast ~= nil then linePos = lineLast; found = true end
            -- ignore whitespace and punctuation
            lineFirst, lineLast = line:find("^[%s,;]+", linePos + 1)
            if lineLast ~= nil then linePos = lineLast; found = true end
            -- ignore ranks
            lineFirst, lineLast = line:find("^%([^%)]+%)", linePos + 1)
            if lineLast ~= nil then linePos = lineLast; found = true end
          end
          found = false
          lineFirst, lineLast, token = line:find("^([%a%s':]+)", linePos + 1)
          if lineLast ~= nil then
            token = strtrim(token)
            linePos = lineLast
            found = true
            self:DebugPrint('Token: "'..token..'"')
            spells[token] = true
          end
        end
      end
    end
    first, last, line = macroText:find("([^\n]+)\n?", last + 1)
  end
  return spells
end
function LA:FindMissingActions()
  if self.inCombat then
    print("Learning Aid: Cannot do that in combat.")
    return
  end
  local actions = {}
  local types = {}
  local subTypes = {}
  local ranks = {}
  local tracking = {}
  local shapeshift = {}
  local results = {}
  local macroSpells = {}
  local numTrackingTypes = GetNumTrackingTypes()
  for trackingType = 1, numTrackingTypes do
    local name, texture, active, category = GetTrackingInfo(trackingType)
    if category == BOOKTYPE_SPELL then
      tracking[name] = true
    end
  end
  for slot = 1, 120 do
    local actionType, actionID, actionSubType = GetActionInfo(slot)
    if actionSubType == nil then
      actionSubType = ""
    end
    if actionType == nil then
      actionType = ""
    end
    -- development info
    if not types[actionType] then
      self:DebugPrint("Type "..actionType)
      types[actionType] = true
    end
    if not subTypes[actionSubType] then
      self:DebugPrint("Subtype "..actionSubType)
      subTypes[actionSubType] = true
    end
    if actionType == "spell" then
      actions[actionID] = true
    elseif actionType == "macro" and actionID ~= 0 and self.saved.macros then
      self:DebugPrint("Macro in slot", slot, "with ID", actionID)
      local body = GetMacroBody(actionID)
      local spells = self:MacroSpells(body)
      for spell in pairs(spells) do
        macroSpells[spell] = true
      end
    end
  end
  -- Macaroon support code
  if self.saved.macros and Macaroon and Macaroon.Buttons then
    for index, button in ipairs(Macaroon.Buttons) do
      local buttonType = button[1].config.type
      local macroText = button[1].config.macro
      local storage = button[2]
      if (buttonType == "macro") and (storage == 0) then
        self:DebugPrint("Macaroon macro in slot", index)
        local spells = self:MacroSpells(macroText)
        for spell in pairs(spells) do
          macroSpells[spell] = true
        end
      end
    end
  end
  -- End Macaroon code
  for actionID, info in ipairs(self.spellBookCache) do
    if (not ranks[info.name]) or ranks[info.name].rank < info.rank then
      ranks[info.name] = info
    end
  end
  local numForms = GetNumShapeshiftForms()
  for form = 1, numForms do
    local formTexture, formName, formIsActive, formIsCastable = GetShapeshiftFormInfo(form)
    shapeshift[formName] = true
  end
  for spellName, info in pairs(ranks) do
    spellNameLower = string.lower(spellName)
    if 
      (not actions[info.spellBookID]) and -- spell is not on any action bar
      (not info.passive)              and -- spell is not passive
      -- spell is not a tracking spell, or displaying tracking spells has been enabled
      ((not tracking[spellName]) or self.saved.tracking) and
      ((not shapeshift[spellName]) or self.saved.shapeshift) and
      (not macroSpells[spellNameLower])
    then
      self:DebugPrint("Spell "..info.name.." Rank "..info.rank.." is not on any action bar.")
      if macroSpells[spellNameLower] then self:DebugPrint("Found spell in macro") end
      results[#results + 1] = info
    end
  end
  table.sort(results, function (a, b) return a.spellBookID < b.spellBookID end)
  for result = 1, #results do
    self:AddButton(BOOKTYPE_SPELL, results[result].spellBookID)
  end
end
function LA:SaveActionBars()
  local spec = GetActiveTalentGroup()
  if self.character.actions == nil then self.character.actions = {} end
  self.character.actions[spec] = {}
  local savedActions = self.character.actions[spec]
  for actionSlot = 1, 120 do
    local actionType, actionID, actionSubType, absoluteID = GetActionInfo(actionSlot)
    if actionType == "spell" then
      savedActions[actionSlot] = absoluteID
    end
  end
end
function LA:RestoreAction(absoluteID)
  -- self.character.actions[spec][slot] = absoluteID
  local spec = GetActiveTalentGroup()
  if self.character.actions and self.character.actions[spec] then -- and self.character.actions[spec][absoluteID]
    for actionSlot, id in pairs(self.character.actions[spec]) do
      if id == absoluteID then
        self:DebugPrint("LearningAid:RestoreAction("..absoluteID..") found action at action slot "..actionSlot)
        --local actionType, actionID, actionSubType, slotAbsoluteID = GetActionInfo(actionSlot)
        local actionType = GetActionInfo(actionSlot)
        if actionType == nil then
          local spellBookID
          for index, info in ipairs(self.spellBookCache) do
            if info.absoluteID == absoluteID then
              spellBookID = info.spellBookID
              self:DebugPrint("LearningAid:RestoreAction("..absoluteID..") found action at Spellbook ID "..spellBookID)
              break
            end
          end
          if spellBookID then
            PickupSpell(spellBookID, BOOKTYPE_SPELL)
            PlaceAction(actionSlot)
          end
        end
      end
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
  local buttons = frame.buttons
  for i = index, frame.visible - 1 do
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
  local visible = self:GetVisible()
  buttons[visible]:Hide()
  self:SetVisible(visible - 1)
end
function LA:SetVisible(visible)
  frame = self.frame
  frame.visible = visible
  local top, left = frame:GetTop(), frame:GetLeft()
  frame:SetHeight(self.titleHeight + 10 + (self.buttonSize + self.buttonSpacing) * visible)
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
  if visible == 0 then
    frame:Hide()
  end
end
function LA:GetVisible()
  return self.frame.visible
end
function LA:Hide()
  local frame = self.frame
  if not self.inCombat then
    for i = 1, frame.visible do
      frame.buttons[i]:SetChecked(false)
      frame.buttons[i]:Hide()
    end
    frame.visible = 0
    frame:Hide()
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
          table.insert(self.queue, { action = "ADD", id = id, kind = kind })
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
          table.insert(self.queue, { action = "ADD", id = id, kind = kind})
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
function LA:DebugPrint(...)
  if self.saved.debug and self.saved.enabled then
    print(...)
  end
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
    self.menuTable[1].text = self.unlockText
end
function LA:Unlock()
    self.saved.locked = false
    self.menuTable[1].text = self.lockText
end
function LA:ToggleLock()
  if self.saved.locked then
    self:Unlock()
  else
    self:Lock()
  end
end
-- Transforms a spellbook ID into an absolute spell ID
function LA:AbsoluteSpellID(id)
  local link = GetSpellLink(id, BOOKTYPE_SPELL)
  if link then
    local absoluteID = string.match(link, "Hspell:([^\124]+)\124")
    return tonumber(absoluteID)
  end
end