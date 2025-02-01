-- SunderNP.lua
-- Tracks:
--  1) Sunder stacks
--  2) Overpower (4s window + 5s cooldown)
--  3) Whirlwind range detection (8 yd + 2.5 "leeway") with movement-based alpha
-- + [NEW] Whirlwind cooldown (10s base, minus up to 2s via Improved Whirlwind).
--
-- Slash commands:
--   /sundernp opon       => enable Overpower
--   /sundernp opoff      => disable Overpower
--   /sundernp wwon       => enable Whirlwind range detection
--   /sundernp wwoff      => disable Whirlwind range detection
--   /sundernp defaultnp  => display number of Blizzard default nameplates detected
--   /sundernp pfuinp     => display number of PFUI nameplates detected (via globals)
--   /sundernp help       => help

------------------------------------------------
-- 0) Saved Variables & Defaults
------------------------------------------------
SunderNPDB = SunderNPDB or {}

-- store timers and callbacks
local UpdateTimer = -1
WWIconGuids = {}

function GuidInCandidates(_guid, _candidates)
  for _, v in pairs(_candidates) do
    if v.guid == _guid then
      return true
    end
  end

  return false
end

local SunderNP_Defaults = {
  overpowerEnabled = false, -- Overpower off by default
  whirlwindEnabled = false, -- Whirlwind detection off by default
}

function EnforceWWIconCap()
  local activeList = {}
  -- Gather PFUI nameplates by iterating over global names "pfNamePlate1" ... "pfNamePlate100"
  local g = getfenv(0)
  for i = 1, 100 do
    local plate = g["pfNamePlate" .. i]
    if plate and plate.wwIcon then
      local guid = (plate.parent and plate.parent:GetName(1)) or nil
      local dist = 9999
      if guid and UnitExists(guid) and (not UnitIsDead(guid)) and not GuidInCandidates(guid, activeList) then
        local d = UnitXP("distanceBetween", "player", guid, "AoE")
        if d then dist = d end
        table.insert(activeList, { plate = plate, guid = guid, distance = dist, type = "pfui" })
      end
    end
  end

  -- Gather default Blizzard nameplates from nameplateCache
  if nameplateCache then
    for frame, cache in pairs(nameplateCache) do
      if cache.wwIcon and cache.wwIcon:IsShown() then
        local guid = frame:GetName(1)
        local dist = 9999
        if guid and UnitExists(guid) and (not UnitIsDead(guid)) then
          local d = UnitXP("distanceBetween", "player", guid, "AoE")
          if d then dist = d end
        end
        table.insert(activeList, { plate = frame, guid = guid, distance = dist, type = "default", cache = cache })
      end
    end
  end

  -- Sort activeList by distance (closest first)
  table.sort(activeList, function(a, b) return a.distance < b.distance end)

  -- Force only the 4 closest panels to show their WW icon; hide all others.
  local n = table.getn(activeList)
  local _candidates = {}
  for i = 1, n do
    local candidate = activeList[i]
    if candidate.type == "pfui" then
      if i <= 4 then
        table.insert(_candidates, candidate)
      end
    else
      if candidate.cache then
        if i <= 4 then
          candidate.cache.wwIcon:Show()
        else
          candidate.cache.wwIcon:Hide()
        end
      end
    end
  end
  WWIconGuids = _candidates
end

-- Declare our default nameplate cache in file‐global scope so it is available in slash commands.
local nameplateCache = {}

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

  -- Existing branch for Blizzard default nameplates:
  elseif msg == "defaultnp" then
    local count = 0
    for frame, cache in pairs(nameplateCache) do
      if frame:IsShown() then
        count = count + 1
      end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SunderNP]|r Blizzard default nameplates detected: " .. count)
    return

  -- New branch: Count PFUI nameplates via their global names.
  elseif msg == "pfuinp" then
    local count = 0
    local g = getfenv(0)  -- get the global environment
    for i = 1, 100 do  -- adjust the upper limit as needed
      local plate = g["pfNamePlate" .. i]
      if plate and plate:IsShown() then
        count = count + 1
      end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SunderNP]|r PFUI nameplates detected (via globals): " .. count)
    return

  elseif msg == "help" or msg == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SunderNP]|r usage:")
    DEFAULT_CHAT_FRAME:AddMessage("  /sundernp opon       -> enable Overpower icon")
    DEFAULT_CHAT_FRAME:AddMessage("  /sundernp opoff      -> disable Overpower icon")
    DEFAULT_CHAT_FRAME:AddMessage("  /sundernp wwon       -> enable Whirlwind range detection")
    DEFAULT_CHAT_FRAME:AddMessage("  /sundernp wwoff      -> disable Whirlwind range detection")
    DEFAULT_CHAT_FRAME:AddMessage("  /sundernp defaultnp  -> display number of Blizzard default nameplates detected")
    DEFAULT_CHAT_FRAME:AddMessage("  /sundernp pfuinp     -> display number of PFUI nameplates detected (via globals)")
    DEFAULT_CHAT_FRAME:AddMessage("  /sundernp help       -> this help text")
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SunderNP]|r: Unrecognized command '" .. msg .. "'. Type '/sundernp help' for usage.")
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
SunderNPFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")  -- For re-checking improved Whirlwind talent
SunderNPFrame:RegisterEvent("UNIT_DIED")
SunderNPFrame:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
SunderNPFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
SunderNPFrame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- When leaving combat, clean up candidate table
SunderNPFrame:RegisterEvent("PLAYER_LOGOUT")        -- Also clean up on logout

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

  if additionalInfo then
    DEFAULT_CHAT_FRAME:AddMessage("UnitXP_SP3 Info: " .. additionalInfo)
  end
end

SunderNPFrame:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    SunderNP_Initialize()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SunderNP]|r loaded. Type '/sundernp help' for options.")
    
  elseif event == "PLAYER_LOGIN" then
    local _, playerGUID = UnitExists("player")
    SunderNPDB.playerGUID = playerGUID
    UpdateImpWhirlwindTalent()  -- Check improved Whirlwind talent once at login
    CheckUnitXPVersion()        -- Check UnitXP_SP3 version on login
    
  elseif event == "CHARACTER_POINTS_CHANGED" then
    UpdateImpWhirlwindTalent()
    
  -- On any death or target change, force a recheck and clear old candidate data.
  elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
    if EnforceWWIconCap then
      EnforceWWIconCap()
    end
    
  -- When leaving combat, clear the candidate table.
  elseif event == "PLAYER_REGEN_ENABLED" then
    WWIconGuids = {}
    
  -- On logout, also disarm any active timer.
  elseif event == "PLAYER_LOGOUT" then
    UnitXP("timer", "disarm", UpdateTimer)
    UpdateTimer = -1
  end
end)

------------------------------------------------
-- 3) Overpower Logic (4s window + 5s cooldown)
------------------------------------------------
local OverpowerFrame = CreateFrame("Frame", "SunderNP_OverpowerFrame", UIParent)
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

OverpowerFrame:RegisterEvent("COMBAT_TEXT_UPDATE")           -- "SPELL_ACTIVE", Overpower
OverpowerFrame:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")    -- "dodges"
OverpowerFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")     -- "Your Overpower..."
OverpowerFrame:RegisterEvent("UNIT_CASTEVENT")                 -- SuperWoW cast events
OverpowerFrame:RegisterEvent("UNIT_COMBAT")                    -- Hack attributing 0 target whirlwinds

OverpowerFrame:SetScript("OnEvent", function()
  local msg = arg1 or ""
  if event == "COMBAT_TEXT_UPDATE" then
    if arg1 == "SPELL_ACTIVE" and arg2 == "Overpower" then
      overpowerActive = true
      overpowerEndTime = GetTime() + 4
    end
  elseif event == "CHAT_MSG_COMBAT_SELF_MISSES" then
    if string.find(msg, "dodges") then
      -- FIX: If the last cast action was Whirlwind, mark this dodge as a whirlwind dodge.
      if castevent.action == "Whirlwind" then
        castevent.whirlwind = true
      end
      -- (For non-Whirlwind cases, castevent.targetGUID is already set.)
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
      -- Overpower was used – start cooldown.
      overpowerOnCooldown = true
      overpowerCdEndTime  = GetTime() + 5
      if overpowerActive then
        overpowerActive = false
        castevent.overpowerGUID = nil -- Reset since Overpower was used.
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
      -- When a Whirlwind dodge is detected in UNIT_COMBAT, update the target GUID.
      castevent.overpowerGUID = arg1
      castevent.whirlwind = false
    end
  end
end)

OverpowerFrame:SetScript("OnUpdate", function()
  local now = GetTime()
  if overpowerActive and now >= overpowerEndTime then
    overpowerActive = false
    castevent.overpowerGUID = nil -- Overpower window expired.
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
-- 5) Whirlwind Range + Movement (like MagePlates)
------------------------------------------------
local isMoving   = false
local lastX, lastY = 0, 0
local WW_BASE_CD  = 10
local wwTalentRank= 0
local wwEndTime   = 0  -- next time WW is off cd

function UpdateImpWhirlwindTalent()
  local _, _, _, _, rank = GetTalentInfo(2, 11)
  if rank then
    wwTalentRank = rank
  else
    wwTalentRank = 0
  end
end

local function GetWWCooldownLeft()
  local left = wwEndTime - GetTime()
  return (left > 0) and left or 0
end

local WWCDFrame = CreateFrame("Frame", "SunderNP_WWCDFrame", UIParent)
WWCDFrame:RegisterEvent("UNIT_CASTEVENT")
WWCDFrame:SetScript("OnEvent", function()
  if event == "UNIT_CASTEVENT" then
    if arg1 == SunderNPDB.playerGUID then
      local action, _, _, _, _ = SpellInfo(arg4)
      if action == "Whirlwind" then
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

local WhirlwindRangeFrame = CreateFrame("Frame", "SunderNP_WhirlwindRangeFrame", UIParent)
WhirlwindRangeFrame:SetScript("OnUpdate", function()
  if not SunderNPDB.whirlwindEnabled then return end
  if not SunderNP_CanUseWhirlwind then return end
  if not this.nextUpdate then this.nextUpdate = 0 end
  if GetTime() < this.nextUpdate then return end
  this.nextUpdate = GetTime() + 0.1
  local x, y = UnitPosition("player")
  if x and y then
    local dx = x - lastX
    local dy = y - lastY
    local distSq = dx * dx + dy * dy
    isMoving = (distSq > 0.0001)
    lastX, lastY = x, y
  end
end)

local function GetWhirlwindAlphaForGUID(guid)
  if not SunderNP_CanUseWhirlwind then return 0 end
  if not SunderNPDB.whirlwindEnabled or not guid or guid == "0x0000000000000000" or not UnitExists(guid) then
    return 0
  end
  local dist = UnitXP("distanceBetween", "player", guid, "AoE")
  if not dist then return 0 end
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
  if n <= 0 then return end
  for i = 1, n do
    local data = iconList[i]
    local offsetX = (i - (n + 1) / 2) * ICON_SPACING
    data.icon:ClearAllPoints()
    data.icon:SetPoint("TOP", parent, "TOP", offsetX, offsetY)
    if data.timerFS then
      data.timerFS:ClearAllPoints()
      data.timerFS:SetPoint("CENTER", data.icon, "CENTER", 0, 0)
    end
  end
end

------------------------------------------------
-- 7) PFUI Nameplate Hook (Modified Inline Enforcement)
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

    local sunderText = plate.health:CreateFontString(nil, "OVERLAY")
    sunderText:SetFont("Fonts\\FRIZQT__.TTF", 25, "OUTLINE")
    sunderText:SetPoint("LEFT", plate.health, "RIGHT", 15, 0)
    plate.sunderText = sunderText

    local overpowerIcon = plate.health:CreateTexture(nil, "OVERLAY")
    overpowerIcon:SetTexture(OverpowerIconTexture)
    overpowerIcon:SetWidth(32)
    overpowerIcon:SetHeight(32)
    overpowerIcon:SetPoint("TOP", plate.health, "TOP", 0, 60)
    overpowerIcon:Hide()
    plate.overpowerIcon = overpowerIcon

    local overpowerTimer = plate.health:CreateFontString(nil, "OVERLAY")
    overpowerTimer:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    overpowerTimer:SetText("")
    overpowerTimer:Hide()
    plate.overpowerTimer = overpowerTimer

    local wwIcon = plate.health:CreateTexture(nil, "OVERLAY")
    wwIcon:SetTexture(WhirlwindIconTexture)
    wwIcon:SetWidth(32)
    wwIcon:SetHeight(32)
    wwIcon:Hide()
    plate.wwIcon = wwIcon

    local wwTimer = plate.health:CreateFontString(nil, "OVERLAY")
    wwTimer:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    wwTimer:SetText("")
    wwTimer:Hide()
    plate.wwTimer = wwTimer
  end

  if UpdateTimer < 0 then
    UpdateTimer = UnitXP("timer", "arm", 1000, 1000, "EnforceWWIconCap")
  end
  local oldOnDataChanged = pfUI.nameplates.OnDataChanged
  pfUI.nameplates.OnDataChanged = function(self, plate)
    oldOnDataChanged(self, plate)
    if not plate or not plate.sunderText or not plate.overpowerIcon or
       not plate.overpowerTimer or not plate.wwIcon or not plate.wwTimer then
      return
    end

    local guid = plate.parent:GetName(1)
    if guid and UnitExists(guid) then
      if UnitIsFriend("player", guid) or (UnitCreatureType(guid) == "Critter") then
        plate:Hide()
        return
      else
        plate:Show()
      end
    end

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

    local iconsToShow = {}

    if SunderNPDB.overpowerEnabled and guid and guid == castevent.overpowerGUID then
      if IsOverpowerActive() then
        plate.overpowerIcon:Show()
        plate.overpowerTimer:Show()
        local data = { icon = plate.overpowerIcon }
        if IsOverpowerOnCooldown() then
          local cdLeft = math.floor(overpowerCdEndTime - GetTime() + 0.5)
          if cdLeft < 0 then cdLeft = 0 end
          plate.overpowerTimer:SetText(cdLeft)
          plate.overpowerTimer:SetTextColor(1, 0, 0, 1)
        else
          local wLeft = math.floor(overpowerEndTime - GetTime() + 0.5)
          if wLeft < 0 then wLeft = 0 end
          plate.overpowerTimer:SetText(wLeft)
          plate.overpowerTimer:SetTextColor(1, 1, 1, 1)
        end
        data.timerFS = plate.overpowerTimer
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

    if SunderNPDB.whirlwindEnabled then
      local cdLeft = GetWWCooldownLeft()
      if cdLeft > 3 then
        plate.wwIcon:Hide()
        plate.wwTimer:Hide()
        plate.wwTimer:SetText("")
      elseif cdLeft > 0 then
        local alpha = GetWhirlwindAlphaForGUID(guid)
        if GuidInCandidates(guid, WWIconGuids) and alpha > 0 then
          plate.wwIcon:SetAlpha(1)
          plate.wwIcon:Show()
          plate.wwTimer:Show()
          plate.wwTimer:SetTextColor(1, 0, 0, 1)
          plate.wwTimer:SetText(tostring(math.floor(cdLeft)))
          table.insert(iconsToShow, { icon = plate.wwIcon, timerFS = plate.wwTimer })
        else
          plate.wwIcon:Hide()
          plate.wwTimer:Hide()
          plate.wwTimer:SetText("")
        end
      else
        local alpha = GetWhirlwindAlphaForGUID(guid)
        if GuidInCandidates(guid, WWIconGuids) and alpha > 0 then
          plate.wwIcon:SetAlpha(alpha)
          plate.wwIcon:Show()
          plate.wwTimer:Hide()
          plate.wwTimer:SetText("")
          table.insert(iconsToShow, { icon = plate.wwIcon })
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
  overpowerTimer:SetText("")
  overpowerTimer:Hide()

  local wwIcon = frame:CreateTexture(nil, "OVERLAY")
  wwIcon:SetTexture(WhirlwindIconTexture)
  wwIcon:SetWidth(32)
  wwIcon:SetHeight(32)
  wwIcon:Hide()

  local wwTimer = frame:CreateFontString(nil, "OVERLAY")
  wwTimer:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
  wwTimer:SetText("")
  wwTimer:Hide()

  nameplateCache[frame] = {
    sunderText = sunderText,
    overpowerIcon = overpowerIcon,
    overpowerTimer = overpowerTimer,
    wwIcon = wwIcon,
    wwTimer = wwTimer,
  }
end

local function UpdateDefaultNameplates()
  local frames = { WorldFrame:GetChildren() }
  for _, frame in ipairs(frames) do
    if frame:IsVisible() and frame:GetName() == nil then
      local healthBar = frame:GetChildren()
      if healthBar and healthBar:IsObjectType("StatusBar") then
        if not nameplateCache[frame] then
          CreatePlateElements(frame)
        end
        local cache = nameplateCache[frame]
        local sunderText = cache.sunderText
        local opIcon = cache.overpowerIcon
        local opTimer = cache.overpowerTimer
        local wwIcon = cache.wwIcon
        local wwTimer = cache.wwTimer

        local guid = frame:GetName(1)
        if guid and UnitExists(guid) then
          if UnitIsFriend("player", guid) or (UnitCreatureType(guid) == "Critter") then
            frame:Hide()
          else
            frame:Show()
            local sunderUnit = (guid and guid ~= "0x0000000000000000" and UnitExists(guid)) and guid or "target"
            local stacks = 0
            if UnitExists(sunderUnit) then stacks = GetSunderStacks(sunderUnit) end
            if stacks > 0 then
              sunderText:SetText(stacks)
              if stacks == 5 then
                sunderText:SetTextColor(0, 1, 0, 1)
              elseif stacks == 4 then
                sunderText:SetTextColor(0, 0.6, 0, 1)
              elseif stacks == 3 then
                sunderText:SetTextColor(1, 1, 0, 1)
              elseif stacks == 2 then
                sunderText:SetTextColor(1, 0.647, 0, 1)
              elseif stacks == 1 then
                sunderText:SetTextColor(1, 0, 0, 1)
              end
            else
              sunderText:SetText("")
            end

            local iconsToShow = {}

            if SunderNPDB.overpowerEnabled and guid and guid == castevent.overpowerGUID then
              if IsOverpowerActive() then
                opIcon:Show()
                opTimer:Show()
                local data = { icon = opIcon }
                if IsOverpowerOnCooldown() then
                  local cdLeft = math.floor(overpowerCdEndTime - GetTime() + 0.5)
                  if cdLeft < 0 then cdLeft = 0 end
                  opTimer:SetText(cdLeft)
                  opTimer:SetTextColor(1, 0, 0, 1)
                else
                  local wLeft = math.floor(overpowerEndTime - GetTime() + 0.5)
                  if wLeft < 0 then wLeft = 0 end
                  opTimer:SetText(wLeft)
                  opTimer:SetTextColor(1, 1, 1, 1)
                end
                data.timerFS = opTimer
                table.insert(iconsToShow, data)
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

            if SunderNPDB.whirlwindEnabled then
              local cdLeft = GetWWCooldownLeft()
              if cdLeft > 3 then
                wwIcon:Hide()
                wwTimer:Hide()
                wwTimer:SetText("")
              elseif cdLeft > 0 then
                local alpha = GetWhirlwindAlphaForGUID(guid)
                if alpha > 0 then
                  wwIcon:SetAlpha(1)
                  wwIcon:Show()
                  wwTimer:Show()
                  wwTimer:SetTextColor(1, 0, 0, 1)
                  wwTimer:SetText(tostring(math.floor(cdLeft)))
                  table.insert(iconsToShow, { icon = wwIcon, timerFS = wwTimer })
                else
                  wwIcon:Hide()
                  wwTimer:Hide()
                  wwTimer:SetText("")
                end
              else
                local alpha = GetWhirlwindAlphaForGUID(guid)
                if alpha > 0 then
                  wwIcon:SetAlpha(alpha)
                  wwIcon:Show()
                  wwTimer:Hide()
                  wwTimer:SetText("")
                  table.insert(iconsToShow, { icon = wwIcon })
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
  local updater = CreateFrame("Frame", "SunderNP_DefaultFrame")
  updater.tick = 0
  updater:SetScript("OnUpdate", function()
    if (this.tick or 0) > GetTime() then return end
    this.tick = GetTime() + 0.5
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
