-- SunderNP.lua
-- Tracks Sunder stacks on nameplates + Overpower (4s window + 5s cooldown).
-- Slash commands: /sundernp or /snp
--   opon  : enable Overpower on nameplates
--   opoff : disable Overpower on nameplates
--   help  : usage info

------------------------------------------------
-- 0) Saved Variables & Defaults
------------------------------------------------
SunderNPDB = SunderNPDB or {}

local SunderNP_Defaults = {
  overpowerEnabled = false,  -- Overpower is off by default in this snippet
}

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
  elseif msg == "help" or msg == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SunderNP]|r usage:")
    DEFAULT_CHAT_FRAME:AddMessage("  /sundernp opon   -> enable Overpower icon on nameplates")
    DEFAULT_CHAT_FRAME:AddMessage("  /sundernp opoff  -> disable Overpower icon on nameplates")
    DEFAULT_CHAT_FRAME:AddMessage("  /sundernp help   -> show this help text")
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SunderNP]|r: Unrecognized command '"..msg.."'. Type '/sundernp help' for usage.")
  end
end

SLASH_SUNDERNP1 = "/sundernp"
SLASH_SUNDERNP2 = "/snp"
SlashCmdList["SUNDERNP"] = SunderNP_SlashCommand

------------------------------------------------
-- 2) Initialization
------------------------------------------------
local SunderNPFrame = CreateFrame("Frame", "SunderNP_MainFrame")
SunderNPFrame:RegisterEvent("VARIABLES_LOADED")
SunderNPFrame:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    SunderNP_Initialize()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SunderNP]|r loaded. Type '/sundernp help' for options.")
  end
end)

------------------------------------------------
-- 3) Overpower Logic (4s + 5s)
------------------------------------------------
local OverpowerFrame = CreateFrame("Frame", "SunderNP_OverpowerFrame", UIParent)

-- We store Overpower state globally as before:
local overpowerActive    = false
local overpowerEndTime   = 0

local overpowerOnCooldown = false
local overpowerCdEndTime  = 0

-- NEW: We store which GUID had the dodge
local OverpowerGUID = nil

local function IsOverpowerActive()
  return overpowerActive and (GetTime() < overpowerEndTime)
end

local function IsOverpowerOnCooldown()
  return overpowerOnCooldown and (GetTime() < overpowerCdEndTime)
end

-- Listen for events that cause Overpower
OverpowerFrame:RegisterEvent("COMBAT_TEXT_UPDATE")           -- "SPELL_ACTIVE", Overpower
OverpowerFrame:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")  -- "dodges"
OverpowerFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")   -- "Your Overpower..."

OverpowerFrame:SetScript("OnEvent", function()
  local msg = arg1 or ""

  if event == "COMBAT_TEXT_UPDATE" then
    if arg1 == "SPELL_ACTIVE" and arg2 == "Overpower" then
      overpowerActive = true
      overpowerEndTime = GetTime() + 4
      -- We do not know the specific GUID from this event, so we leave OverpowerGUID as is (or nil).

    elseif arg1 == "DODGE" then
      -- Rarely the client can do "COMBAT_TEXT_UPDATE" "DODGE" for your own target?
      -- Not always reliable. We'll rely on chat lines instead.
    end

  elseif event == "CHAT_MSG_COMBAT_SELF_MISSES" then
    if string.find(msg, "dodges") then
      -- If the user has a current target with a valid GUID, we store that GUID
      local _, targetGUID = UnitExists("target")  -- requires superwow
      if targetGUID and targetGUID ~= "0x0000000000000000" then
        -- Mark Overpower is active for that target's nameplate
        OverpowerGUID = targetGUID

        if overpowerActive then
          overpowerEndTime = GetTime() + 4
        else
          overpowerActive   = true
          overpowerEndTime  = GetTime() + 4
        end
      end
    end

  elseif event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
    if string.find(msg, "^Your Overpower") then
      -- Used Overpower => 5s cooldown
      overpowerOnCooldown = true
      overpowerCdEndTime  = GetTime() + 5

      if overpowerActive then
        overpowerActive = false
      end
    end
  end
end)

OverpowerFrame:SetScript("OnUpdate", function()
  local now = GetTime()

  if overpowerActive and now >= overpowerEndTime then
    overpowerActive = false
    -- Keep OverpowerGUID around or set it nil if you want to clear it
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
  for i = 1, 16 do
    local name, icon, count = UnitDebuff(unit, i)
    if name == SunderArmorTexture then
      return tonumber(icon) or 0
    end
  end
  return 0
end

------------------------------------------------
-- 5) pfUI Nameplates Hook
------------------------------------------------
local OverpowerIconTexture = "Interface\\Icons\\Ability_MeleeDamage"

local function HookPfuiNameplates()
  if not pfUI or not pfUI.nameplates then return end

  local oldOnCreate = pfUI.nameplates.OnCreate
  pfUI.nameplates.OnCreate = function(frame)
    oldOnCreate(frame)

    local plate = frame.nameplate
    if not plate or not plate.health then return end

    -- Sunder text
    local sunderText = plate.health:CreateFontString(nil, "OVERLAY")
    sunderText:SetFont("Fonts\\FRIZQT__.TTF", 25, "OUTLINE")
    sunderText:SetPoint("LEFT", plate.health, "RIGHT", 15, 0)
    plate.sunderText = sunderText

    -- Overpower icon
    local overpowerIcon = plate.health:CreateTexture(nil, "OVERLAY")
    overpowerIcon:SetTexture(OverpowerIconTexture)
    overpowerIcon:SetWidth(32)
    overpowerIcon:SetHeight(32)
    overpowerIcon:SetPoint("TOP", plate.health, "TOP", 0, 60)
    overpowerIcon:Hide()
    plate.overpowerIcon = overpowerIcon

    -- Overpower timer text
    local overpowerTimer = plate.health:CreateFontString(nil, "OVERLAY")
    overpowerTimer:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    overpowerTimer:SetPoint("CENTER", overpowerIcon, "CENTER", 0, 0)
    overpowerTimer:SetText("")
    overpowerTimer:Hide()
    plate.overpowerTimer = overpowerTimer
  end

  local oldOnDataChanged = pfUI.nameplates.OnDataChanged
  pfUI.nameplates.OnDataChanged = function(self, plate)
    oldOnDataChanged(self, plate)
    if not plate or not plate.sunderText or not plate.overpowerIcon or not plate.overpowerTimer then
      return
    end

    -- 1) Sunder logic
    local guid = plate.parent:GetName(1)
    if guid and UnitExists(guid) then
      local stacks = GetSunderStacks(guid)
      if stacks > 0 then
        plate.sunderText:SetText(stacks)
        if stacks == 5 then
          plate.sunderText:SetTextColor(0, 1, 0, 1)
        elseif stacks == 4 then
          plate.sunderText:SetTextColor(0, 0.6, 0, 1)
        elseif stacks == 3 then
          plate.sunderText:SetTextColor(1, 1, 0, 1)
        elseif stacks == 2 then
          plate.sunderText:SetTextColor(1, 0.647, 0, 1)
        elseif stacks == 1 then
          plate.sunderText:SetTextColor(1, 0, 0, 1)
        end
      else
        plate.sunderText:SetText("")
      end
    else
      plate.sunderText:SetText("")
    end

    -- 2) Overpower
    if not SunderNPDB.overpowerEnabled then
      plate.overpowerIcon:Hide()
      plate.overpowerTimer:Hide()
      plate.overpowerTimer:SetText("")
      return
    end

    -- If this nameplate's GUID is the one we stored at dodge time
    if guid and OverpowerGUID and guid == OverpowerGUID then
      if IsOverpowerActive() then
        plate.overpowerIcon:Show()
        plate.overpowerTimer:Show()

        if IsOverpowerOnCooldown() then
          local cdLeft = math.floor(overpowerCdEndTime - GetTime() + 0.5)
          if cdLeft < 0 then cdLeft = 0 end
          plate.overpowerTimer:SetText(cdLeft)
          plate.overpowerTimer:SetTextColor(1, 0, 0, 1) -- red
        else
          local windowLeft = math.floor(overpowerEndTime - GetTime() + 0.5)
          if windowLeft < 0 then windowLeft = 0 end
          plate.overpowerTimer:SetText(windowLeft)
          plate.overpowerTimer:SetTextColor(1, 1, 1, 1) -- white
        end
      else
        -- not in 4s window => hide
        plate.overpowerIcon:Hide()
        plate.overpowerTimer:Hide()
        plate.overpowerTimer:SetText("")
      end
    else
      -- Different GUID => hide
      plate.overpowerIcon:Hide()
      plate.overpowerTimer:Hide()
      plate.overpowerTimer:SetText("")
    end
  end
end

------------------------------------------------
-- 6) Default Blizzard Nameplates
------------------------------------------------
local nameplateCache = {}

local function CreatePlateElements(frame)
  local sunderText = frame:CreateFontString(nil, "OVERLAY")
  sunderText:SetFont("Fonts\\FRIZQT__.TTF", 25, "OUTLINE")
  sunderText:SetPoint("RIGHT", frame, "RIGHT", 15, 0)

  local overpowerIcon = frame:CreateTexture(nil, "OVERLAY")
  overpowerIcon:SetTexture(OverpowerIconTexture)
  overpowerIcon:SetWidth(32)
  overpowerIcon:SetHeight(32)
  overpowerIcon:SetPoint("TOP", frame, "TOP", 0, 60)
  overpowerIcon:Hide()

  local overpowerTimer = frame:CreateFontString(nil, "OVERLAY")
  overpowerTimer:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
  overpowerTimer:SetPoint("CENTER", overpowerIcon, "CENTER", 0, 0)
  overpowerTimer:SetText("")
  overpowerTimer:Hide()

  nameplateCache[frame] = {
    sunderText     = sunderText,
    overpowerIcon  = overpowerIcon,
    overpowerTimer = overpowerTimer,
  }
end

local function UpdateDefaultNameplates()
  local frames = { WorldFrame:GetChildren() }
  local now = GetTime()
  for _, frame in ipairs(frames) do
    if frame:IsVisible() and frame:GetName()==nil then
      local healthBar = frame:GetChildren()
      if healthBar and healthBar:IsObjectType("StatusBar") then
        if not nameplateCache[frame] then
          CreatePlateElements(frame)
        end
        local cache = nameplateCache[frame]
        local sunderText     = cache.sunderText
        local overpowerIcon  = cache.overpowerIcon
        local overpowerTimer = cache.overpowerTimer

        local guid = frame:GetName(1)
        -- Sunder logic (unchanged)
        if guid and UnitExists(guid) and frame:GetAlpha()==1 then
          local stacks = GetSunderStacks("target")
          if stacks>0 then
            sunderText:SetText(stacks)
            if stacks==5 then
              sunderText:SetTextColor(0,1,0,1)
            else
              sunderText:SetTextColor(1,1,0,1)
            end
          else
            sunderText:SetText("")
          end
        else
          sunderText:SetText("")
        end

        -- Overpower
        if not SunderNPDB.overpowerEnabled then
          overpowerIcon:Hide()
          overpowerTimer:Hide()
          overpowerTimer:SetText("")
        else
          if guid and OverpowerGUID and guid==OverpowerGUID then
            if IsOverpowerActive() then
              overpowerIcon:Show()
              overpowerTimer:Show()

              if IsOverpowerOnCooldown() then
                local cdLeft = math.floor(overpowerCdEndTime - now+0.5)
                if cdLeft<0 then cdLeft=0 end
                overpowerTimer:SetText(cdLeft)
                overpowerTimer:SetTextColor(1,0,0,1)
              else
                local wLeft = math.floor(overpowerEndTime - now+0.5)
                if wLeft<0 then wLeft=0 end
                overpowerTimer:SetText(wLeft)
                overpowerTimer:SetTextColor(1,1,1,1)
              end
            else
              overpowerIcon:Hide()
              overpowerTimer:Hide()
              overpowerTimer:SetText("")
            end
          else
            -- not the GUID that dodged => hide
            overpowerIcon:Hide()
            overpowerTimer:Hide()
            overpowerTimer:SetText("")
          end
        end
      end
    end
  end
end

local function HookDefaultNameplates()
  local updater = CreateFrame("Frame", "SunderNP_DefaultFrame")
  updater.tick=0
  updater:SetScript("OnUpdate", function()
    if (this.tick or 0)>GetTime() then return end
    this.tick=GetTime()+0.5
    UpdateDefaultNameplates()
  end)
end

------------------------------------------------
-- 7) Decide Which Hook
------------------------------------------------
if pfUI and pfUI.nameplates then
  HookPfuiNameplates()
else
  HookDefaultNameplates()
end
