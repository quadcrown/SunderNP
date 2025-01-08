-- SunderNP.lua

-------------------------------------------------------------------------------
-- 1) Common Sunder-Tracking Logic
-------------------------------------------------------------------------------
local SunderArmorTexture = "Interface\\Icons\\Ability_Warrior_Sunder"

local function GetSunderStacks(unit)
  -- This version uses the “weird” but working logic you found:
  for i = 1, 16 do
    local name, icon, count = UnitDebuff(unit, i)
    if name == SunderArmorTexture then
      -- Here "icon" is actually your stack count, so use it
      return tonumber(icon) or 0
    end
  end
  return 0
end

-------------------------------------------------------------------------------
-- 2) If PFUI is Loaded: Hook pfUI Nameplates
-------------------------------------------------------------------------------
local function HookPfuiNameplates()
  -- Make sure pfUI nameplates exist
  if not pfUI or not pfUI.nameplates then return end

  -- Hook OnCreate to add the sunder text
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

  -- Hook OnDataChanged to update sunder text
  local oldOnDataChanged = pfUI.nameplates.OnDataChanged
  pfUI.nameplates.OnDataChanged = function(self, plate)
    oldOnDataChanged(self, plate)
    if not plate or not plate.sunderText then return end

    local guid = plate.parent:GetName(1)
    if guid and UnitExists(guid) then
      local stacks = GetSunderStacks(guid)
      if stacks > 0 then
        plate.sunderText:SetText(stacks)
        if stacks == 5 then
          plate.sunderText:SetTextColor(0, 1, 0, 1) -- green
        else
          plate.sunderText:SetTextColor(1, 1, 0, 1) -- yellow
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
  -- 'frame' is the entire Blizzard nameplate frame
  local healthBar = frame:GetChildren()

  local sunderText = frame:CreateFontString(nil, "OVERLAY")
  sunderText:SetFont("Fonts\\FRIZQT__.TTF", 25, "OUTLINE")
  
  -- Clear any default anchoring
  sunderText:ClearAllPoints()

  -- Anchor to the RIGHT side of the entire nameplate frame:
  -- We move it  -5  from the right edge so it's a bit inset.
  sunderText:SetPoint("RIGHT", frame, "RIGHT", 15, 0)

  -- Cache the font string so you can update it later
  nameplateCache[frame] = sunderText
end

local function UpdateDefaultNameplates()
  local frames = { WorldFrame:GetChildren() }
  for _, frame in ipairs(frames) do
    if frame:IsVisible() and frame:GetName() == nil then
      -- Standard check for a Blizzard nameplate
      local healthBar = frame:GetChildren()
      if healthBar and healthBar:IsObjectType("StatusBar") then

        -- If we haven't created a sunderText for this frame yet, do so
        if not nameplateCache[frame] then
          CreateSunderText(frame)
        end

        -- Show the Sunder count for your current target
        local stacks = GetSunderStacks("target")
        local sunderText = nameplateCache[frame]
        if stacks > 0 then
          sunderText:SetText(stacks)
          if stacks == 5 then
            sunderText:SetTextColor(0, 1, 0, 1) -- Green if 5
          else
            sunderText:SetTextColor(1, 1, 0, 1) -- Yellow if 1-4
          end
        else
          sunderText:SetText("")
        end
      end
    end
  end
end

local function HookDefaultNameplates()
  local updateFrame = CreateFrame("Frame")
  updateFrame.tick = 0  -- our simple timer

  updateFrame:SetScript("OnUpdate", function()
    -- If we haven't reached the next time threshold, just return
    if (this.tick or 0) > GetTime() then 
      return
    end

    -- Otherwise, set up our next throttle time
    this.tick = GetTime() + 0.5 -- 0.5 = interval in seconds

    -- Now do the expensive work
    UpdateDefaultNameplates()
  end)
end


-------------------------------------------------------------------------------
-- 4) Decide Which Hook to Use
-------------------------------------------------------------------------------
if pfUI and pfUI.nameplates then
  -- PFUI is present, so hook PFUI’s nameplates
  HookPfuiNameplates()
else
  -- Otherwise, fall back to default nameplate scanning
  HookDefaultNameplates()
end
