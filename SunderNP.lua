-- SunderNP.lua

-------------------------------------------------------------------------------
-- 1) Common Sunder-Tracking Logic
-------------------------------------------------------------------------------
local SunderArmorTexture = "Interface\\Icons\\Ability_Warrior_Sunder"

local function GetSunderStacks(unit)
  -- Sunder stacks
  for i = 1, 16 do
    local name, icon, count = UnitDebuff(unit, i)
    if name == SunderArmorTexture then
      return tonumber(icon) or 0  -- icon is actually the stack count
    end
  end
  return 0
end

-------------------------------------------------------------------------------
-- 2) If PFUI is Loaded: Hook pfUI Nameplates
-------------------------------------------------------------------------------
local function HookPfuiNameplates()
  if not pfUI or not pfUI.nameplates then return end

  -- Hook OnCreate
  local oldOnCreate = pfUI.nameplates.OnCreate
  pfUI.nameplates.OnCreate = function(frame)
    oldOnCreate(frame)

    local plate = frame.nameplate
    if not plate or not plate.health then return end

    local sunderText = plate.health:CreateFontString(nil, "OVERLAY")
    sunderText:SetFont("Fonts\\FRIZQT__.TTF", 25, "OUTLINE")
    sunderText:SetPoint("LEFT", plate.health, "RIGHT", 15, 0)
    plate.sunderText = sunderText
  end

  -- Hook OnDataChanged
  local oldOnDataChanged = pfUI.nameplates.OnDataChanged
  pfUI.nameplates.OnDataChanged = function(self, plate)
    oldOnDataChanged(self, plate)
    if not plate or not plate.sunderText then return end

    local guid = plate.parent:GetName(1)  -- pfUI sets a real GUID here
    if guid and UnitExists(guid) then
      local stacks = GetSunderStacks(guid)
      if stacks > 0 then
        plate.sunderText:SetText(stacks)
        if stacks == 5 then
          plate.sunderText:SetTextColor(0, 1, 0, 1) -- green
        elseif stacks == 4 then
          plate.sunderText:SetTextColor(0, 0.6, 0, 1) -- green
        elseif stacks == 3 then
          plate.sunderText:SetTextColor(1, 1, 0, 1) -- yellow
        elseif stacks == 2 then
          plate.sunderText:SetTextColor(1, 0.647, 0, 1) -- orange
        elseif stacks == 1 then
          plate.sunderText:SetTextColor(1, 0, 0, 1)
        end
      else
        plate.sunderText:SetText("")
      end
    else
      plate.sunderText:SetText("")
    end
  end
end

-------------------------------------------------------------------------------
-- 3) If pfUI Is *Not* Loaded: Hook Default Blizzard Nameplates
-------------------------------------------------------------------------------
local nameplateCache = {}

local function CreateSunderText(frame)
  local sunderText = frame:CreateFontString(nil, "OVERLAY")
  sunderText:SetFont("Fonts\\FRIZQT__.TTF", 25, "OUTLINE")
  sunderText:ClearAllPoints()
  -- Adjust anchor as needed
  sunderText:SetPoint("RIGHT", frame, "RIGHT", 15, 0)

  nameplateCache[frame] = sunderText
  return sunderText
end

local function UpdateDefaultNameplates()
  local frames = { WorldFrame:GetChildren() }
  for _, frame in ipairs(frames) do
    if frame:IsVisible() and frame:GetName() == nil then
      -- Likely a Blizzard nameplate
      local healthBar = frame:GetChildren()
      if healthBar and healthBar:IsObjectType("StatusBar") then

        -- Ensure we have our sunder text
        local sunderText = nameplateCache[frame]
        if not sunderText then
          sunderText = CreateSunderText(frame)
        end

        -- Try reading a GUID from GetName(1)
        local guid = frame:GetName(1)
        if guid and guid ~= "0x0000000000000000" and UnitExists(guid) then
          -- If something (e.g. SuperWoW) actually set this nameplate's GUID
          local stacks = GetSunderStacks(guid)
          if stacks > 0 then
            sunderText:SetText(stacks)
            if stacks == 5 then
              sunderText:SetTextColor(0, 1, 0, 1) -- green
            else
              sunderText:SetTextColor(1, 1, 0, 1) -- yellow
            end
          else
            sunderText:SetText("")
          end
        else
          -- Fallback to "target" if no real GUID is assigned
          local stacks = GetSunderStacks("target")
          if stacks > 0 then
            sunderText:SetText(stacks)
            if stacks == 5 then
              sunderText:SetTextColor(0, 1, 0, 1)
            else
              sunderText:SetTextColor(1, 1, 0, 1)
            end
          else
            sunderText:SetText("")
          end
        end
      end
    end
  end
end

local function HookDefaultNameplates()
  local updater = CreateFrame("Frame")
  updater.tick = 0

  updater:SetScript("OnUpdate", function()
    if (this.tick or 0) > GetTime() then return end
    this.tick = GetTime() + 0.5
    UpdateDefaultNameplates()
  end)
end

-------------------------------------------------------------------------------
-- 4) Decide Which Hook to Use
-------------------------------------------------------------------------------
if pfUI and pfUI.nameplates then
  HookPfuiNameplates()
else
  HookDefaultNameplates()
end
