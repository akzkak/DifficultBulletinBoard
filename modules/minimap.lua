-- Localize frequently used globals for performance
local math_rad = math.rad
local math_deg = math.deg
local math_cos = math.cos
local math_sin = math.sin
local math_atan = math.atan
local math_atan2 = math.atan2
local math_pi = math.pi

local function Atan2(y, x)
  if math_atan2 then
    return math_atan2(y, x)
  end
  if x > 0 then
    return math_atan(y / x)
  elseif x < 0 and y >= 0 then
    return math_atan(y / x) + math_pi
  elseif x < 0 and y < 0 then
    return math_atan(y / x) - math_pi
  elseif x == 0 and y > 0 then
    return math_pi / 2
  elseif x == 0 and y < 0 then
    return -math_pi / 2
  end
  return 0
end

DBB2:RegisterModule("minimap", function()
  -- Create minimap button (standard circular minimap button)
  DBB2.minimapButton = CreateFrame("Button", "DBB2MinimapButton", Minimap)
  DBB2.minimapButton:SetFrameStrata("HIGH")
  DBB2.minimapButton:SetWidth(31)
  DBB2.minimapButton:SetHeight(31)
  DBB2.minimapButton:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 10)
  DBB2.minimapButton:RegisterForDrag("LeftButton")
  DBB2.minimapButton:SetMovable(true)
  DBB2.minimapButton:SetClampedToScreen(true)
  DBB2.minimapButton:EnableMouse(true)
  DBB2.minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  DBB2.minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  
  -- Create overlay frame for circular mask
  DBB2.minimapButton.overlay = CreateFrame("Frame", nil, DBB2.minimapButton)
  DBB2.minimapButton.overlay:SetWidth(53)
  DBB2.minimapButton.overlay:SetHeight(53)
  DBB2.minimapButton.overlay:SetPoint("TOPLEFT", 0, 0)
  DBB2.minimapButton.overlay:SetFrameLevel(DBB2.minimapButton:GetFrameLevel() + 1)
  
  -- Create overlay texture (circular border)
  DBB2.minimapButton.overlay.texture = DBB2.minimapButton.overlay:CreateTexture(nil, "OVERLAY")
  DBB2.minimapButton.overlay.texture:SetWidth(53)
  DBB2.minimapButton.overlay.texture:SetHeight(53)
  DBB2.minimapButton.overlay.texture:SetPoint("TOPLEFT", 0, 0)
  DBB2.minimapButton.overlay.texture:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  
  -- Create icon texture (circular)
  DBB2.minimapButton.icon = DBB2.minimapButton:CreateTexture(nil, "BACKGROUND")
  DBB2.minimapButton.icon:SetWidth(20)
  DBB2.minimapButton.icon:SetHeight(20)
  DBB2.minimapButton.icon:SetPoint("TOPLEFT", 7, -5)
  DBB2.minimapButton.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
  DBB2.minimapButton.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
  
  -- Dragging functionality
  DBB2.minimapButton.angle = DBB2_Config.minimapAngle or 45
  DBB2.minimapButton.freePos = DBB2_Config.minimapFreePos or nil
  DBB2.minimapButton.freeMode = DBB2_Config.minimapFreeMode or false

  local function ClampFreePosition(pos)
    if not pos or type(pos.x) ~= "number" or type(pos.y) ~= "number" then
      return nil
    end

    local width = UIParent:GetWidth() or 0
    local height = UIParent:GetHeight() or 0

    -- During early addon load some clients report zero here. Keep the saved
    -- value and let the next layout/update use it instead of resetting it.
    if width <= 0 or height <= 0 then
      return { x = pos.x, y = pos.y }
    end

    local margin = 16
    local x = pos.x
    local y = pos.y

    if x < margin then x = margin end
    if y < margin then y = margin end
    if x > width - margin then x = width - margin end
    if y > height - margin then y = height - margin end

    return { x = x, y = y }
  end

  local function SavePosition()
    if not DBB2.minimapButton then return end
    DBB2_Config.minimapAngle = DBB2.minimapButton.angle or 45
    DBB2_Config.minimapFreeMode = DBB2.minimapButton.freeMode and true or false
    if DBB2.minimapButton.freeMode and DBB2.minimapButton.freePos then
      DBB2.minimapButton.freePos = ClampFreePosition(DBB2.minimapButton.freePos)
      if DBB2.minimapButton.freePos then
        DBB2_Config.minimapFreePos = {
          x = DBB2.minimapButton.freePos.x,
          y = DBB2.minimapButton.freePos.y
        }
      else
        DBB2_Config.minimapFreeMode = false
        DBB2_Config.minimapFreePos = nil
      end
    else
      DBB2_Config.minimapFreePos = nil
    end
  end

  local function HasValidFreePosition()
    local pos = DBB2.minimapButton.freePos
    return pos and type(pos.x) == "number" and type(pos.y) == "number"
  end

  DBB2.api.SaveMinimapButtonPosition = function()
    SavePosition()
  end

  local function ResetPosition(printMessage)
    DBB2.minimapButton.angle = 45
    DBB2.minimapButton.freeMode = false
    DBB2.minimapButton.freePos = nil
    SavePosition()
    if printMessage and DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cffaaa7ccDBB2:|r Minimap button position reset.")
    end
  end

  local function ApplyButtonParent(freeMode)
    if freeMode then
      if DBB2.minimapButton:GetParent() ~= UIParent then
        DBB2.minimapButton:SetParent(UIParent)
      end
      DBB2.minimapButton:SetFrameStrata("HIGH")
      DBB2.minimapButton:SetFrameLevel(100)
    else
      if DBB2.minimapButton:GetParent() ~= Minimap then
        DBB2.minimapButton:SetParent(Minimap)
      end
      DBB2.minimapButton:SetFrameStrata("HIGH")
      DBB2.minimapButton:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 10)
    end

    if DBB2.minimapButton.overlay then
      DBB2.minimapButton.overlay:SetFrameLevel(DBB2.minimapButton:GetFrameLevel() + 1)
    end
  end
  
  local function UpdatePosition()
    DBB2.minimapButton:ClearAllPoints()
    if DBB2.minimapButton.freeMode and HasValidFreePosition() then
      ApplyButtonParent(true)
      -- Free positioning mode - position relative to UIParent
      DBB2.minimapButton:SetPoint("CENTER", UIParent, "BOTTOMLEFT", DBB2.minimapButton.freePos.x, DBB2.minimapButton.freePos.y)
    else
      ApplyButtonParent(false)
      -- Locked to minimap circle
      local angle = math_rad(DBB2.minimapButton.angle)
      local radius = 80
      local x = math_cos(angle) * radius
      local y = math_sin(angle) * radius
      DBB2.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    DBB2.minimapButton:Show()
  end

  DBB2.api.ResetMinimapButton = function()
    if not DBB2.minimapButton then return end
    ResetPosition(true)
    UpdatePosition()
  end
  
  DBB2.minimapButton:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self.isDragging = true
    self.freeDragging = IsControlKeyDown()
  end)
  
  DBB2.minimapButton:SetScript("OnDragStop", function(self)
    self:UnlockHighlight()
    self.isDragging = false
    self.freeDragging = false
    SavePosition()
  end)
  
  DBB2.minimapButton:SetScript("OnUpdate", function(self, elapsed)
    if self.isDragging then
      local mx, my = GetCursorPosition()
      local scale = UIParent:GetEffectiveScale()
      mx = mx / scale
      my = my / scale
      
      if self.freeDragging then
        -- Free drag mode - place anywhere
        DBB2.minimapButton.freeMode = true
        DBB2.minimapButton.freePos = ClampFreePosition({ x = mx, y = my }) or { x = mx, y = my }
      else
        -- Locked drag mode - rotate around minimap
        DBB2.minimapButton.freeMode = false
        DBB2.minimapButton.freePos = nil
        local px, py = Minimap:GetCenter()
        local angle = math_deg(Atan2(my - py, mx - px))
        DBB2.minimapButton.angle = angle
      end
      UpdatePosition()
      SavePosition()
    end
  end)
  
  -- Click handler
  DBB2.minimapButton:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
      if DBB2.gui:IsShown() then
        DBB2.gui:Hide()
      else
        DBB2.gui:Show()
      end
    elseif button == "RightButton" and IsControlKeyDown() then
      -- Reset position to default (locked mode, 45 degrees)
      DBB2.api.ResetMinimapButton()
    end
  end)
  
  -- Tooltip
  DBB2.minimapButton:SetScript("OnEnter", function(self)
    DBB2.api.ShowTooltip(self, "LEFT", {
      {"|cffaaa7ccDifficult|cffffffffBulletinBoard", "highlight"},
      "Left-click to toggle window",
      "Drag to rotate around minimap",
      "Ctrl + Drag to move freely",
      "Ctrl + Right-click to reset position"
    })
  end)
  
  DBB2.minimapButton:SetScript("OnLeave", function(self)
    DBB2.api.HideTooltip()
  end)
  
  -- Initial position
  UpdatePosition()
  DBB2.minimapButton.icon:Show()
  DBB2.minimapButton.overlay.texture:Show()
end)
