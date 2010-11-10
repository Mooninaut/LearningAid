-- SpellButton.lua

local addonName, private = ...
local LA = private.LA

-- Adapted from SpellBookFrame.lua
function LA:UpdateButton(button)
  local id = button:GetID();

  local name = button:GetName()
  local iconTexture = _G[name.."IconTexture"]
  local spellString = _G[name.."SpellName"]
  local subSpellString = _G[name.."SubSpellName"]
  local cooldown = _G[name.."Cooldown"]
  local autoCastableTexture = _G[name.."AutoCastable"]
  local highlightTexture = _G[name.."Highlight"]
  -- CATA -- local normalTexture = _G[name.."NormalTexture"]
  if not self.inCombat then
    button:Enable()
  end

  if button.kind == BOOKTYPE_SPELL then

    local texture = GetSpellTexture(id, BOOKTYPE_SPELL);

    -- If no spell, hide everything and return
    if ( not texture or (strlen(texture) == 0) ) then
      iconTexture:Hide()
      spellString:Hide()
      subSpellString:Hide()
      cooldown:Hide()
      autoCastableTexture:Hide()
      SpellBook_ReleaseAutoCastShine(button.shine)
      button.shine = nil
      highlightTexture:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
      button:SetChecked(0)
      -- CATA -- normalTexture:SetVertexColor(1.0, 1.0, 1.0)
      return;
    end

    local start, duration, enable = GetSpellCooldown(id, BOOKTYPE_SPELL)
    CooldownFrame_SetTimer(cooldown, start, duration, enable)
    cooldown.start = start
    cooldown.duration = duration
    cooldown.enable = enable
    if ( enable == 1 ) then
      iconTexture:SetVertexColor(1.0, 1.0, 1.0)
    else
      iconTexture:SetVertexColor(0.4, 0.4, 0.4)
    end

    local spellName, subSpellName = GetSpellBookItemName(id, BOOKTYPE_SPELL)

    -- CATA -- normalTexture:SetVertexColor(1.0, 1.0, 1.0)
    highlightTexture:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    spellString:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)

    -- Set Secure Action Button attribute
    if not self.inCombat then
      button:SetAttribute("spell*", spellName)
    end

    iconTexture:SetTexture(texture)
    spellString:SetText(spellName)
    subSpellString:SetText(subSpellName)
    if ( subSpellName ~= "" ) then
      spellString:SetPoint("LEFT", button, "RIGHT", 4, 4)
    else
      spellString:SetPoint("LEFT", button, "RIGHT", 4, 2)
    end
    if self.saved.ignore[self.localClass] and
       self.saved.ignore[self.localClass][string.lower(spellName)] then
      iconTexture:SetVertexColor(0.8, 0.1, 0.1) -- cribbed from Bartender4
    end
  elseif button.kind == "MOUNT" or button.kind == "CRITTER" then

    -- Some companions have two names, the display name and the spell name
    -- Make sure to use the spell name for casting
    local creatureID, creatureName, creatureSpellID, icon, isSummoned = GetCompanionInfo(button.kind, id)
    local spellName = GetSpellInfo(creatureSpellID)
    iconTexture:SetTexture(icon)
    spellString:SetText(creatureName)
    subSpellString:SetText("")
    if not self.inCombat then
      button:SetAttribute("spell*", spellName)
    end
  end
  iconTexture:Show()
  spellString:Show()
  subSpellString:Show()
  --SpellButton_UpdateSelection(self)
end
-- Adapted from SpellBookFrame.lua
function LA:SpellButton_OnDrag(button)
  local id = button:GetID()
  if button.kind == BOOKTYPE_SPELL then
    PickupSpellBookItem(id, button.kind)
  elseif button.kind == "MOUNT" or button.kind == "CRITTER" then
    PickupCompanion(button.kind, id)
  end
end
-- Adapted from SpellBookFrame.lua
function LA:SpellButton_OnEnter(button)
  --self:DebugPrint("Outer SpellButton_OnEnter")
  local id = button:GetID()
  local kind = button.kind
  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  if kind == BOOKTYPE_SPELL then
    if GameTooltip:SetSpellBookItem(id, BOOKTYPE_SPELL) then
      button.UpdateTooltip = function (...)
        --self:DebugPrint("Inner SpellButton_OnEnter")
        self:SpellButton_OnEnter(...)
      end
    else
      button.UpdateTooltip = nil
    end
    GameTooltip:AddLine("dummy")
    _G["GameTooltipTextLeft"..GameTooltip:NumLines()]:SetText(self:GetText("ctrlToIgnore"))
    GameTooltip:Show()
  elseif kind == "MOUNT" or kind == "CRITTER" then
    local creatureID, creatureName, creatureSpellID, icon, isSummoned = GetCompanionInfo(kind, id)
    if GameTooltip:SetHyperlink("spell:"..creatureSpellID) then
      button.UpdateTooltip = function (...) self:SpellButton_OnEnter(...) end
    else
      button.UpdateTooltip = nil
    end
  else
    self:DebugPrint("Invalid button type in LearningAid:SpellButton_OnEnter: "..button.kind)
  end
end
-- Adapted from SpellBookFrame.lua
function LA:SpellButton_UpdateSelection(button)
  if button.kind == BOOKTYPE_SPELL then
    local id = button:GetID()
    if IsSelectedSpellBookItem(id, BOOKTYPE_SPELL) then
      button:SetChecked("true")
    else
      button:SetChecked("false")
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
        spellName, subSpellName = GetSpellBookItemName(id, BOOKTYPE_SPELL)
          if ( spellName and not IsPassiveSpell(id, BOOKTYPE_SPELL) ) then
            if ( subSpellName and (strlen(subSpellName) > 0) ) then
              ChatEdit_InsertLink(spellName.."("..subSpellName..")")
            else
              ChatEdit_InsertLink(spellName)
            end
          end
        return;
      else
        local spellLink = GetSpellLink(id, BOOKTYPE_SPELL)
          if(spellLink) then
            ChatEdit_InsertLink(spellLink)
          end
        return;
      end
    end
    if ( IsModifiedClick("PICKUPACTION") ) then
      PickupSpell(id, BOOKTYPE_SPELL)
      return;
    end
  elseif spellButton.kind == "MOUNT" or spellButton.kind == "CRITTER" then
    local creatureID, creatureName, creatureSpellID, icon, isSummoned = GetCompanionInfo(spellButton.kind, id)
    if ( IsModifiedClick("CHATLINK") ) then
      if ( MacroFrame and MacroFrame:IsShown() ) then
        local spellName = GetSpellInfo(creatureSpellID)
        ChatEdit_InsertLink(spellName)
      else
        local spellLink = GetSpellLink(creatureSpellID)
        ChatEdit_InsertLink(spellLink)
      end
    elseif ( IsModifiedClick("PICKUPACTION") ) then
      self.SpellButton_OnDrag(spellButton)
    end
  end
end
function LA:SpellButton_OnHide(button)
  self:DebugPrint("Hiding button "..button.index)
  button:SetChecked(false)
  button.iconTexture:SetVertexColor(1, 1, 1)
  button.cooldown:Hide()
end
function LA:UpdateButtons()
  for i = 1, self:GetVisible() do
    self:UpdateButton(self.buttons[i])
  end
end