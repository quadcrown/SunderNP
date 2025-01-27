-- SunderNP.lua
-- Tracks:
--  1) Sunder stacks
--  2) Overpower (4s window + 5s cooldown)
--  3) Whirlwind range detection (8 yd + 2.5 "leeway") with movement-based alpha
-- + [NEW] Whirlwind cooldown (10s base, minus up to 2s via Improved Whirlwind).
--
-- Slash commands:
--   /sundernp opon   => enable Overpower
--   /sundernp opoff  => disable Overpower
--   /sundernp wwon   => enable Whirlwind range detection
--   /sundernp wwoff  => disable Whirlwind range detection
--   /sundernp help   => help

------------------------------------------------
-- 0) Saved Variables & Defaults
------------------------------------------------
SunderNPDB = SunderNPDB or {}

local SunderNP_Defaults = {
  overpowerEnabled = false, -- Overpower off by default
  whirlwindEnabled = false, -- Whirlwind detection off by default
}

-- UnitXP check
local SunderNP_CanUseWhirlwind = false

local function SunderNP_Initialize()
  for k, v in pairs(SunderNP_Defaults) do
    if SunderNPDB[k] == nil then
      SunderNPDB[k] = v
    end
  end
end

------------------------------------------------
-- 1) Slash Command Handler
------------------------------------------------
local function SunderNP_SlashCommand(msg)
  if type(msg) ~= "string" then
    msg = ""
  end
  msg = string.lower(msg)

  if msg == "opon" then
    SunderNPDB.overpowerEnabled = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SunderNP]|r Overpower feature: |cff00ff00ENABLED|r.")

  elseif msg == "opoff" then
    SunderNPDB.overpowerEnabled = false
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SunderNP]|r Overpower feature: |cffff0000DISABLED|r.")

  elseif msg == "wwon" then
    -- [NEW] Check if UnitXP_SP3 v22+ is available
    if not SunderNP_CanUseWhirlwind then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[SunderNP]|r You do NOT have UnitXP_SP3 v22 or newer. Whirlwind cannot be enabled. Please install v22 or the latest UnitXP https://github.com/allfoxwy/UnitXP_SP3/releases")
      return
    end
    SunderNPDB.whirlwindEnabled = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SunderNP]|r Whirlwind range detection: |cff00ff00ENABLED|r.")

  elseif msg == "wwoff" then
    SunderNPDB.whirlwindEnabled = false
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SunderNP]|r Whirlwind range detection: |cffff0000DISABLED|r.")

  elseif msg == "help" or msg == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SunderNP]|r usage:")
    DEFAULT_CHAT_FRAME:AddMessage("  /sundernp opon   -> enable Overpower icon")
    DEFAULT_CHAT_FRAME:AddMessage("  /sundernp opoff  -> disable Overpower icon")
    DEFAULT_CHAT_FRAME:AddMessage("  /sundernp wwon   -> enable Whirlwind range detection")
    DEFAULT_CHAT_FRAME:AddMessage("  /sundernp wwoff  -> disable Whirlwind range detection")
    DEFAULT_CHAT_FRAME:AddMessage("  /sundernp help   -> this help text")

  else
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SunderNP]|r: Unrecognized command '"..msg.."'. Type '/sundernp help' for usage.")
  end
end

SLASH_SUNDERNP1 = "/sundernp"
SLASH_SUNDERNP2 = "/snp"
SlashCmdList["SUNDERNP"] = SunderNP_SlashCommand


------------------------------------------------
-- 2) Register an Event for Initialization
------------------------------------------------
local SunderNPFrame = CreateFrame("Frame", "SunderNP_MainFrame")
SunderNPFrame:RegisterEvent("VARIABLES_LOADED")
SunderNPFrame:RegisterEvent("PLAYER_LOGIN")

-- [NEW] So we can re-check improved Whirlwind talent rank
SunderNPFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")

-- [NEW] Function to check UnitXP_SP3 version
local function CheckUnitXPVersion()
  -- Attempt to call UnitXP safely
  local ok = pcall(UnitXP, "nop", "nop")
  if not ok then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[SunderNP]|r You do NOT have UnitXP_SP3 installed. Whirlwind is disabled. Please install v22 or the latest UnitXP https://github.com/allfoxwy/UnitXP_SP3/releases")
    SunderNPDB.whirlwindEnabled = false
    SunderNP_CanUseWhirlwind = false
    return
  end

  -- Grab compile time
  local compileTime = UnitXP("version", "coffTimeDateStamp")
  local additionalInfo = UnitXP("version", "additionalInformation")
  local versionThreshold = time({year = 2025, month = 1, day = 26, hour = 0, min = 0, sec = 0})

  if not compileTime then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[SunderNP]|r Cannot retrieve UnitXP_SP3 version. Whirlwind is disabled. Please install v22 or the latest UnitXP https://github.com/allfoxwy/UnitXP_SP3/releases")
    SunderNPDB.whirlwindEnabled = false
    SunderNP_CanUseWhirlwind = false
    return
  end

  if compileTime < versionThreshold then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[SunderNP]|r Your UnitXP_SP3 is older than v22. Whirlwind is disabled. Please install v22 or the latest UnitXP https://github.com/allfoxwy/UnitXP_SP3/releases")
    SunderNPDB.whirlwindEnabled = false
    SunderNP_CanUseWhirlwind = false
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SunderNP]|r UnitXP_SP3 v22 or newer detected. Whirlwind can be enabled.")
    SunderNP_CanUseWhirlwind = true
  end

  -- Optional: show extra info if you want
  if additionalInfo then
    DEFAULT_CHAT_FRAME:AddMessage("UnitXP_SP3 Info: "..additionalInfo)
  end
end

SunderNPFrame:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    SunderNP_Initialize()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SunderNP]|r loaded. Type '/sundernp help' for options.")

  elseif event == "PLAYER_LOGIN" then
    local _, playerGUID = UnitExists("player")
    SunderNPDB.playerGUID = playerGUID
    UpdateImpWhirlwindTalent() -- [NEW] check once at login
    CheckUnitXPVersion()       -- [NEW] check UnitXP_SP3 on login

  elseif event == "CHARACTER_POINTS_CHANGED" then
    -- [NEW] re-check rank in case talents changed
    UpdateImpWhirlwindTalent()
  end
end)


------------------------------------------------
-- 3) Overpower Logic (4s window + 5s cooldown)
------------------------------------------------
local OverpowerFrame = CreateFrame("Frame", "SunderNP_OverpowerFrame", UIParent)


-- Overpower state
local overpowerActive = false
local overpowerEndTime = 0


local overpowerOnCooldown = false
local overpowerCdEndTime  = 0


local function IsOverpowerActive()
  return overpowerActive and (GetTime() < overpowerEndTime)
end


local function IsOverpowerOnCooldown()
  return overpowerOnCooldown and (GetTime() < overpowerCdEndTime)
end


local function IsOverpowerUsable()
  return IsOverpowerActive() and not IsOverpowerOnCooldown()
end


local castevent = {}

-- Listen for events that cause Overpower
OverpowerFrame:RegisterEvent("COMBAT_TEXT_UPDATE")           -- "SPELL_ACTIVE", Overpower
OverpowerFrame:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")  -- "dodges"
OverpowerFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")   -- "Your Overpower..."
OverpowerFrame:RegisterEvent("UNIT_CASTEVENT")               -- SuperWoW cast events
OverpowerFrame:RegisterEvent("UNIT_COMBAT")                  -- Hack attributing 0 target whirlwinds


OverpowerFrame:SetScript("OnEvent", function()
  local msg = arg1 or ""


  if event == "COMBAT_TEXT_UPDATE" then
    if arg1 == "SPELL_ACTIVE" and arg2 == "Overpower" then
      overpowerActive = true
      overpowerEndTime = GetTime() + 4
    end

  elseif event == "CHAT_MSG_COMBAT_SELF_MISSES" then
    if string.find(msg, "dodges") then
      castevent.overpowerGUID = castevent.targetGUID
      if overpowerActive then
        overpowerEndTime = GetTime() + 4
      else
        overpowerActive = true
        overpowerEndTime = GetTime() + 4
      end
    end

  elseif event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
    if string.find(arg1, "dodged") then
      castevent.overpowerGUID = castevent.targetGUID
      if string.find(arg1, "Whirlwind") then
        castevent.whirlwind = true
      end
      if overpowerActive then
        overpowerEndTime = GetTime() + 4
      else
        overpowerActive = true
        overpowerEndTime = GetTime() + 4
      end
   end
    if string.find(msg, "^Your Overpower") then
      -- Used Overpower => 5s cooldown
      overpowerOnCooldown = true
      overpowerCdEndTime  = GetTime() + 5

      if overpowerActive then
        overpowerActive = false
        castevent.overpowerGUID = nil -- Overpower used, reset
      end
    end

  elseif event == "UNIT_CASTEVENT" then
    if arg1 == SunderNPDB.playerGUID then
      local action, _, _, _, _ = SpellInfo(arg4)
      castevent.action = action
      castevent.targetGUID = arg2
    end

  elseif event == "UNIT_COMBAT" then
    if castevent.whirlwind and arg2 == "DODGE" and castevent.action == "Whirlwind" then
      castevent.overpowerGUID = arg1
      castevent.whirlwind = false
    end
  end
end)


OverpowerFrame:SetScript("OnUpdate", function()
  local now = GetTime()


  if overpowerActive and now >= overpowerEndTime then
    overpowerActive = false
    castevent.overpowerGUID = nil -- overpower expired, reset
  end


  if overpowerOnCooldown and now >= overpowerCdEndTime then
    overpowerOnCooldown = false
  end
end)

------------------------------------------------
-- 4) Sunder Tracking
------------------------------------------------
local SunderArmorTexture = "Interface\\Icons\\Ability_Warrior_Sunder"
local function GetSunderStacks(unit)
  for i=1, 16 do
    local name, icon, count = UnitDebuff(unit, i)
    if name == SunderArmorTexture then
      return tonumber(icon) or 0
    end
  end
  return 0
end

------------------------------------------------
-- 5) Whirlwind Range + Movement (like MagePlates)
------------------------------------------------
local isMoving   = false
local lastX, lastY = 0,0

-- [NEW] Whirlwind base cd + improved talent rank
local WW_BASE_CD  = 10
local wwTalentRank= 0
local wwEndTime   = 0  -- next time WW is off cd

-- [NEW] read improved whirlwind rank (Fury=2, Talent=11)
function UpdateImpWhirlwindTalent()
  local _, _, _, _, rank = GetTalentInfo(2, 11)
  if rank then
    wwTalentRank = rank
  else
    wwTalentRank = 0
  end
end

-- [NEW] function to get current cd left
local function GetWWCooldownLeft()
  local left = wwEndTime - GetTime()
  return (left>0) and left or 0
end

-- [CHANGED] hooking cast event (instead of CHAT_MSG_SPELL_...) for Whirlwind to set wwEndTime
local WWCDFrame = CreateFrame("Frame", "SunderNP_WWCDFrame", UIParent)
WWCDFrame:RegisterEvent("UNIT_CASTEVENT")
WWCDFrame:SetScript("OnEvent", function()
  if event == "UNIT_CASTEVENT" then
    -- arg1 == caster GUID, arg2 == targetGUID, arg4 holds SpellInfo ID
    if arg1 == SunderNPDB.playerGUID then
      local action, _, _, _, _ = SpellInfo(arg4)
      if action == "Whirlwind" then
        -- compute cd
        local cd = WW_BASE_CD
        if wwTalentRank == 1 then
          cd = cd - 1
        elseif wwTalentRank == 2 then
          cd = cd - 1.5
        elseif wwTalentRank == 3 then
          cd = cd - 2
        end
        wwEndTime = GetTime() + cd
      end
    end
  end
end)

-- movement detection
local WhirlwindRangeFrame = CreateFrame("Frame", "SunderNP_WhirlwindRangeFrame", UIParent)
WhirlwindRangeFrame:SetScript("OnUpdate", function()
  -- [NEW] If Whirlwind is disabled or UnitXP_SP3 < v22, skip
  if not SunderNPDB.whirlwindEnabled then return end
  if not SunderNP_CanUseWhirlwind then return end

  if not this.nextUpdate then this.nextUpdate=0 end
  if GetTime()<this.nextUpdate then return end
  this.nextUpdate=GetTime()+0.1

  local x,y = UnitPosition("player")
  if x and y then
    local dx= x-lastX
    local dy= y-lastY
    local distSq= dx*dx + dy*dy
    if distSq>0.0001 then
      isMoving = true
    else
      isMoving = false
    end
    lastX, lastY = x,y
  end
end)

-- range alpha logic
local function GetWhirlwindAlphaForGUID(guid)
  -- [NEW] Additional check to prevent usage if UnitXP_SP3 is missing or old
  if not SunderNP_CanUseWhirlwind then
    return 0
  end

  if not SunderNPDB.whirlwindEnabled or not guid or guid=="0x0000000000000000" or not UnitExists(guid) then
    return 0
  end

  local dist = UnitXP("distanceBetween","player",guid,"AoE")
  if not dist then
    return 0
  end

  if dist <= 8 then
    return 1.0
  elseif dist <= 10.5 then
    if isMoving then
      return 1.0
    else
      return 0.3
    end
  else
    return 0
  end
end

------------------------------------------------
-- 6) Icon Layout: center horizontally
------------------------------------------------
local ICON_SPACING = 35
local function ArrangeIconsCentered(iconList, parent, offsetY)
  local n = table.getn(iconList)
  if n<=0 then return end

  for i=1,n do
    local data=iconList[i]
    local offsetX= (i-(n+1)/2)*ICON_SPACING
    data.icon:ClearAllPoints()
    data.icon:SetPoint("TOP", parent,"TOP", offsetX, offsetY)
    if data.timerFS then
      data.timerFS:ClearAllPoints()
      data.timerFS:SetPoint("CENTER", data.icon,"CENTER",0,0)
    end
  end
end

------------------------------------------------
-- 7) pfUI Nameplate Hook
------------------------------------------------
local OverpowerIconTexture  = "Interface\\Icons\\Ability_MeleeDamage"
local WhirlwindIconTexture  = "Interface\\Icons\\Ability_Whirlwind"

local function HookPfuiNameplates()
  if not pfUI or not pfUI.nameplates then return end

  local oldOnCreate = pfUI.nameplates.OnCreate
  pfUI.nameplates.OnCreate = function(frame)
    oldOnCreate(frame)

    local plate = frame.nameplate
    if not plate or not plate.health then return end

    -- Sunder text
    local sunderText = plate.health:CreateFontString(nil,"OVERLAY")
    sunderText:SetFont("Fonts\\FRIZQT__.TTF",25,"OUTLINE")
    sunderText:SetPoint("LEFT", plate.health,"RIGHT",15,0)
    plate.sunderText = sunderText

    -- Overpower icon
    local overpowerIcon = plate.health:CreateTexture(nil,"OVERLAY")
    overpowerIcon:SetTexture(OverpowerIconTexture)
    overpowerIcon:SetWidth(32)
    overpowerIcon:SetHeight(32)
    overpowerIcon:SetPoint("TOP", plate.health,"TOP",0,60)
    overpowerIcon:Hide()
    plate.overpowerIcon = overpowerIcon

    local overpowerTimer= plate.health:CreateFontString(nil,"OVERLAY")
    overpowerTimer:SetFont("Fonts\\FRIZQT__.TTF",16,"OUTLINE")
    overpowerTimer:SetText("")
    overpowerTimer:Hide()
    plate.overpowerTimer = overpowerTimer

    -- Whirlwind icon
    local wwIcon= plate.health:CreateTexture(nil,"OVERLAY")
    wwIcon:SetTexture(WhirlwindIconTexture)
    wwIcon:SetWidth(32)
    wwIcon:SetHeight(32)
    wwIcon:Hide()
    plate.wwIcon= wwIcon

    -- [NEW] Whirlwind timer for CD
    local wwTimer= plate.health:CreateFontString(nil,"OVERLAY")
    wwTimer:SetFont("Fonts\\FRIZQT__.TTF",16,"OUTLINE")
    wwTimer:SetText("")
    wwTimer:Hide()
    plate.wwTimer= wwTimer
  end

  local oldOnDataChanged = pfUI.nameplates.OnDataChanged
  pfUI.nameplates.OnDataChanged = function(self, plate)
    oldOnDataChanged(self, plate)
    if not plate or not plate.sunderText or not plate.overpowerIcon
       or not plate.overpowerTimer or not plate.wwIcon or not plate.wwTimer then
      return
    end

    local guid = plate.parent:GetName(1)

    -- [NEW] Filter out friendly units or critters:
    if guid and UnitExists(guid) then
      if UnitIsFriend("player", guid) or (UnitCreatureType(guid) == "Critter") then
        plate:Hide()
        return
      else
        plate:Show()
      end
    end

    -- Sunder logic
    if guid and UnitExists(guid) then
      local stacks = GetSunderStacks(guid)
      if stacks > 0 then
        plate.sunderText:SetText(stacks)
        if stacks == 5 then
          plate.sunderText:SetTextColor(0,1,0,1)
        elseif stacks == 4 then
          plate.sunderText:SetTextColor(0,0.6,0,1)
        elseif stacks == 3 then
          plate.sunderText:SetTextColor(1,1,0,1)
        elseif stacks == 2 then
          plate.sunderText:SetTextColor(1,0.647,0,1)
        elseif stacks == 1 then
          plate.sunderText:SetTextColor(1,0,0,1)
        end
      else
        plate.sunderText:SetText("")
      end
    else
      plate.sunderText:SetText("")
    end

    local iconsToShow={}

    -- Overpower
    if SunderNPDB.overpowerEnabled and guid and guid==castevent.overpowerGUID then
      if IsOverpowerActive() then
        plate.overpowerIcon:Show()
        plate.overpowerTimer:Show()
        local data={ icon= plate.overpowerIcon }

        if IsOverpowerOnCooldown() then
          local cdLeft= math.floor(overpowerCdEndTime - GetTime()+0.5)
          if cdLeft<0 then cdLeft=0 end
          plate.overpowerTimer:SetText(cdLeft)
          plate.overpowerTimer:SetTextColor(1,0,0,1)
        else
          local wLeft= math.floor(overpowerEndTime - GetTime()+0.5)
          if wLeft<0 then wLeft=0 end
          plate.overpowerTimer:SetText(wLeft)
          plate.overpowerTimer:SetTextColor(1,1,1,1)
        end
        data.timerFS= plate.overpowerTimer
        table.insert(iconsToShow, data)
      else
        plate.overpowerIcon:Hide()
        plate.overpowerTimer:Hide()
        plate.overpowerTimer:SetText("")
      end
    else
      plate.overpowerIcon:Hide()
      plate.overpowerTimer:Hide()
      plate.overpowerTimer:SetText("")
    end

    -- Whirlwind
    if SunderNPDB.whirlwindEnabled then
      local cdLeft = GetWWCooldownLeft()
      if cdLeft>3 then
        plate.wwIcon:Hide()
        plate.wwTimer:Hide()
        plate.wwTimer:SetText("")
      elseif cdLeft>0 then
        plate.wwIcon:SetAlpha(1)
        plate.wwIcon:Show()
        plate.wwTimer:Show()
        plate.wwTimer:SetTextColor(1,0,0,1)
        plate.wwTimer:SetText(tostring(math.floor(cdLeft)))
        table.insert(iconsToShow,{ icon=plate.wwIcon, timerFS=plate.wwTimer })
      else
        local alpha= GetWhirlwindAlphaForGUID(guid)
        if alpha>0 then
          plate.wwIcon:SetAlpha(alpha)
          plate.wwIcon:Show()
          plate.wwTimer:Hide()
          plate.wwTimer:SetText("")
          table.insert(iconsToShow,{ icon=plate.wwIcon })
        else
          plate.wwIcon:Hide()
          plate.wwTimer:Hide()
          plate.wwTimer:SetText("")
        end
      end
    else
      plate.wwIcon:Hide()
      plate.wwTimer:Hide()
      plate.wwTimer:SetText("")
    end

    ArrangeIconsCentered(iconsToShow, plate.health, 60)
  end
end

------------------------------------------------
-- 8) Default Blizzard Nameplates
------------------------------------------------
local nameplateCache = {}

local function CreatePlateElements(frame)
  -- Sunder text
  local sunderText = frame:CreateFontString(nil,"OVERLAY")
  sunderText:SetFont("Fonts\\FRIZQT__.TTF",25,"OUTLINE")
  sunderText:SetPoint("RIGHT", frame,"RIGHT",15,0)

  -- Overpower icon
  local overpowerIcon = frame:CreateTexture(nil,"OVERLAY")
  overpowerIcon:SetTexture(OverpowerIconTexture)
  overpowerIcon:SetWidth(32)
  overpowerIcon:SetHeight(32)
  overpowerIcon:SetPoint("TOP", frame,"TOP",0,60)
  overpowerIcon:Hide()

  local overpowerTimer = frame:CreateFontString(nil,"OVERLAY")
  overpowerTimer:SetFont("Fonts\\FRIZQT__.TTF",16,"OUTLINE")
  overpowerTimer:SetText("")
  overpowerTimer:Hide()

  -- Whirlwind icon
  local wwIcon = frame:CreateTexture(nil,"OVERLAY")
  wwIcon:SetTexture(WhirlwindIconTexture)
  wwIcon:SetWidth(32)
  wwIcon:SetHeight(32)
  wwIcon:Hide()

  -- [NEW] Whirlwind timer for cooldown
  local wwTimer= frame:CreateFontString(nil,"OVERLAY")
  wwTimer:SetFont("Fonts\\FRIZQT__.TTF",16,"OUTLINE")
  wwTimer:SetText("")
  wwTimer:Hide()

  nameplateCache[frame] = {
    sunderText     = sunderText,
    overpowerIcon  = overpowerIcon,
    overpowerTimer = overpowerTimer,
    wwIcon         = wwIcon,
    wwTimer        = wwTimer,
  }
end

local function UpdateDefaultNameplates()
  local frames = { WorldFrame:GetChildren() }
  for _, frame in ipairs(frames) do
    if frame:IsVisible() and frame:GetName()==nil then
      local healthBar = frame:GetChildren()
      if healthBar and healthBar:IsObjectType("StatusBar") then
        if not nameplateCache[frame] then
          CreatePlateElements(frame)
        end
        local cache = nameplateCache[frame]
        local sunderText= cache.sunderText
        local opIcon    = cache.overpowerIcon
        local opTimer   = cache.overpowerTimer
        local wwIcon    = cache.wwIcon
        local wwTimer   = cache.wwTimer

        local guid = frame:GetName(1)

        -- [NEW] Filter out friendly units or critters:
        if guid and UnitExists(guid) then
          if UnitIsFriend("player", guid) or (UnitCreatureType(guid) == "Critter") then
            frame:Hide()
          else
            frame:Show()

            -- Attempt sunder logic
            local sunderUnit
            if guid and guid~="0x0000000000000000" and UnitExists(guid) then
              sunderUnit = guid
            else
              sunderUnit = "target"
            end

            local stacks=0
            if UnitExists(sunderUnit) then
              stacks= GetSunderStacks(sunderUnit)
            end
            if stacks>0 then
              sunderText:SetText(stacks)
              if stacks==5 then
                sunderText:SetTextColor(0,1,0,1)
              elseif stacks==4 then
                sunderText:SetTextColor(0,0.6,0,1)
              elseif stacks==3 then
                sunderText:SetTextColor(1,1,0,1)
              elseif stacks==2 then
                sunderText:SetTextColor(1,0.647,0,1)
              elseif stacks==1 then
                sunderText:SetTextColor(1,0,0,1)
              end
            else
              sunderText:SetText("")
            end

            local iconsToShow={}

            -- Overpower
            if SunderNPDB.overpowerEnabled and guid and guid==castevent.overpowerGUID then
              if IsOverpowerActive() then
                opIcon:Show()
                opTimer:Show()
                local data={ icon=opIcon }
                if IsOverpowerOnCooldown() then
                  local cdLeft= math.floor(overpowerCdEndTime - GetTime()+0.5)
                  if cdLeft<0 then cdLeft=0 end
                  opTimer:SetText(cdLeft)
                  opTimer:SetTextColor(1,0,0,1)
                else
                  local wLeft= math.floor(overpowerEndTime - GetTime()+0.5)
                  if wLeft<0 then wLeft=0 end
                  opTimer:SetText(wLeft)
                  opTimer:SetTextColor(1,1,1,1)
                end
                data.timerFS= opTimer
                table.insert(iconsToShow,data)
              else
                opIcon:Hide()
                opTimer:Hide()
                opTimer:SetText("")
              end
            else
              opIcon:Hide()
              opTimer:Hide()
              opTimer:SetText("")
            end

            -- Whirlwind
            if SunderNPDB.whirlwindEnabled then
              local cdLeft= GetWWCooldownLeft()
              if cdLeft>3 then
                wwIcon:Hide()
                wwTimer:Hide()
                wwTimer:SetText("")
              elseif cdLeft>0 then
                wwIcon:SetAlpha(1)
                wwIcon:Show()
                wwTimer:Show()
                wwTimer:SetTextColor(1,0,0,1)
                wwTimer:SetText(tostring(math.floor(cdLeft)))
                table.insert(iconsToShow,{ icon=wwIcon, timerFS=wwTimer })
              else
                local alpha= GetWhirlwindAlphaForGUID(guid)
                if alpha>0 then
                  wwIcon:SetAlpha(alpha)
                  wwIcon:Show()
                  wwTimer:Hide()
                  wwTimer:SetText("")
                  table.insert(iconsToShow,{ icon=wwIcon })
                else
                  wwIcon:Hide()
                  wwTimer:Hide()
                  wwTimer:SetText("")
                end
              end
            else
              wwIcon:Hide()
              wwTimer:Hide()
              wwTimer:SetText("")
            end

            ArrangeIconsCentered(iconsToShow, frame, 60)
          end
        end
      end
    end
  end
end

local function HookDefaultNameplates()
  local updater= CreateFrame("Frame","SunderNP_DefaultFrame")
  updater.tick=0
  updater:SetScript("OnUpdate", function()
    if (this.tick or 0)>GetTime() then return end
    this.tick=GetTime()+0.5
    UpdateDefaultNameplates()
  end)
end

------------------------------------------------
-- 9) Hook pfUI or Default
------------------------------------------------
if pfUI and pfUI.nameplates then
  HookPfuiNameplates()
else
  HookDefaultNameplates()
end
