local LA = LibStub("AceAddon-3.0"):GetAddon("LearningAid",true)
function LA:CreateTrainAllButton()
  if not self.trainAllButton then
    local button = CreateFrame("Button", "LearningAid_TrainAllButton", ClassTrainerTrainButton, "MagicButtonTemplate")
    button:SetPoint("RIGHT", ClassTrainerTrainButton, "LEFT")
    button:SetText("Train All")
    button:SetScript("OnClick", function() StaticPopup_Show("LEARNING_AID_TRAINER_BUY_ALL") end)
    button:SetScript("OnShow", function(thisButton) 
      local services = LA:GetAvailableTrainerServices()
      --self.trainerServices = services
      if #services == 0 or services.cost > GetMoney() then
        thisButton:Disable()
      else
        thisButton:Enable()
      end
    end)
    button:SetScript("OnHide", function()
      wipe(LA.availableServices)
    end)
    button:Show()
    self.trainAllButton = button
    StaticPopupDialogs.LEARNING_AID_TRAINER_BUY_ALL = {
       text = LA:GetText("trainAllPopup"), -- "Train all skills for"
       button1 = ACCEPT,
       button2 = CANCEL,
       OnAccept = function()
          LA:BuyAllTrainerServices(LA.CONFIRM_TRAINER_BUY_ALL)
          button:Disable()
       end,
       OnShow = function(self)
         MoneyFrame_Update(self.moneyFrame, LA.availableServices.cost)
       end,
       hasMoneyFrame = 1,
       --showAlert = 1,
       timeout = 0,
       exclusive = 1,
       hideOnEscape = 1,
       whileDead = false
    }
    self.ClassTrainerFrame_Update = ClassTrainerFrame_Update
    ClassTrainerFrame_Update = function(...) LA:ClassTrainerFrame_Update(...); LA:GetAvailableTrainerServices() end
    return button
  end
end

function LA:GetAvailableTrainerServices()
  local copper = 0
  local services = self.availableServices
  wipe(services)
  for i = 1, GetNumTrainerServices() do
    local t = {}
    --name (String), subType (String), category (String), texture (String), requiredLevel (Number), topServiceLine (Number)
    t.name, t.subType, t.category, t.texture, t.level, t.topServiceLine = GetTrainerServiceInfo(i)
    t.copper, t.isProfession = GetTrainerServiceCost(i)
    --t.skillLine = GetTrainerServiceSkillLine(i)
    t.index = i
    --t.link = GetTrainerServiceItemLink(i)
    if t.category == "available" and not t.isProfession then
      copper = copper + t.copper
      table.insert(services, t)
    end
  end
  services.cost = copper
  --self:DebugPrint("Total cost of available services: "..GetCoinText(copper))
  if #services > 0 then 
    self.trainAllButton:Enable()
  else
    self.trainAllButton:Disable()
  end
  return services
end

function LA:BuyAllTrainerServices(really)
  local services = self.availableServices
  if services and really == LA.CONFIRM_TRAINER_BUY_ALL then
    self:DebugPrint("Buying all "..#services.." service(s) for "..services.cost.." copper")
    for i, t in ipairs(services) do
      --if t.category == "available" then
        BuyTrainerService(t.index)
      --end
    end
    wipe(services)
  end
end

