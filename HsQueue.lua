-- cancelled:
-- UNIT_SPELLCAST_SENT <--- Press heroic strike/cleave
-- UNIT_SPELLCAST_FAILED_QUIET <-- Cancelled cast event (arg1 (cancelledCast) == true)
-- UNIT_SPELLCAST_INTERRUPTED
-- UNIT_SPELLCAST_INTERRUPTED

-- ok:
-- UNIT_SPELLCAST_SENT <-- Press heroic strike/cleave
-- UNIT_SPELLCAST_SUCCEEDED <-- Attack goes through

-- when swapping between cleave and hs:
-- UNIT_SPELLCAST_SENT <-- Press heroic strike
-- UNIT_SPELLCAST_SENT <-- Press cleave
-- UNIT_SPELLCAST_FAILED_QUIET <-- for the cancelled heroic strike
-- UNIT_SPELLCAST_FAILED_QUIET <-- for the cancelled heroic strike (again?)

local MAIN_FRAME_NAME = "HsQueueFrame"
local FONT_NAME = "Fonts\\FRIZQT__.TTF"
local TITLE_FONT_SIZE = 10
local FONT_SIZE = 12

local heroicStrikeIDs = {
   [78]=true,    -- Heroic Strike 1
   [284]=true,   -- Heroic Strike 2
   [285]=true,   -- Heroic Strike 3
   [1608]=true,  -- Heroic Strike 4
   [11564]=true, -- Heroic Strike 5
   [11565]=true, -- Heroic Strike 6
   [11566]=true, -- Heroic Strike 7
   [11567]=true, -- Heroic Strike 8
   [25286]=true, -- Heroic Strike 9
   [29707]=true, -- Heroic Strike 10
   [30324]=true, -- Heroic Strike 11
}

local cleaveIDs = {
   [845]=true,   -- Cleave 1
   [7369]=true,  -- Cleave 2
   [11608]=true, -- Cleave 3
   [11609]=true, -- Cleave 4
   [20569]=true, -- Cleave 5
   [25231]=true, -- Cleave 6
}

local isDebug = false
local hasEpilepsy = false
local fadeOutTime = 0.8

local ui = {
   f = nil,
}

local stats = {
   isHsQueued = false,
   isCleaveQueued = false,
   queuedOHs = { -- The number of OH hits with a queued hs/cleave
      total = 0,
      misses = 0,
   },
   unqueuedOHs = { -- The number of OH hits with a unqueued hs/cleave
      total = 0,
      misses = 0,
   },
}

function resetStats()
   stats.isHsQueued = false
   stats.isCleaveQueued = false
   stats.queuedOHs.total = 0
   stats.queuedOHs.misses = 0
   stats.unqueuedOHs.total = 0
   stats.unqueuedOHs.misses = 0
end

-- aka debug print
function dprint(...)
   if isDebug then
      print(...)
   end
end

function isHs(spellID)
   return heroicStrikeIDs[spellID]
end

function isCleave(spellID)
   return cleaveIDs[spellID]
end

function isPlayer(unitID)
   return unitID == "player"
end

function boolToNum(b)
   return b and 1 or 0
end

function registerCast(spellID, isQueued)
   if isHs(spellID) then
      if isQueued then
         dprint("hs queued")
      else
         dprint("hs unqueued")
      end
      stats.isHsQueued = isQueued
   elseif isCleave(spellID) then
      if isQueued then
         dprint("cleave queued")
      else
         dprint("cleave unqueued")
      end
      stats.isCleaveQueued = isQueued
   end
end

function OnEvent(self, event, ...)
   if (event == "UNIT_SPELLCAST_SENT") then
      -- castGUID will be unique for each new cast but since casts
      -- can't overlap, we probably do not need it.
      local unit, target, castGUID, spellID = ...
      if not isPlayer(unit) then
         return
      end
      registerCast(spellID, true)
   elseif (event == "UNIT_SPELLCAST_FAILED") then
      local unit, castGUID, spellID = ...
      if not isPlayer(unit) then
         return
      end
      registerCast(spellID, false)
   elseif (event == "UNIT_SPELLCAST_FAILED_QUIET") then
      local unit, castGUID, spellID = ...
      if not isPlayer(unit) then
         return
      end
      registerCast(spellID, false)
   elseif (event == "UNIT_SPELLCAST_SUCCEEDED") then
      local unit, castGUID, spellID = ...
      if not isPlayer(unit) then
         return
      end
      registerCast(spellID, false)
   elseif (event == "UNIT_SPELLCAST_INTERRUPTED") then
      local unit, castGUID, spellID = ...
      if not isPlayer(unit) then
         return
      end
      registerCast(spellID, false)
   else
      onCLEU(event)
   end
   updateMainFrame(self)
end

-- a miss is a MISS, not a PARRY, DODGE or anything else.
function registerOHSwing(isMiss)
   if stats.isHsQueued or stats.isCleaveQueued then
      dprint("oh hit with hs/cleave queued")
      stats.queuedOHs.total = stats.queuedOHs.total + 1
      stats.queuedOHs.misses = stats.queuedOHs.misses + boolToNum(isMiss)
      if not hasEpilepsy then
         UIFrameFadeOut(ui.f.greenFader, fadeOutTime, 1, 0)
      end
   else
      dprint("oh hit without hs/cleave queued")
      stats.unqueuedOHs.total = stats.unqueuedOHs.total + 1
      stats.unqueuedOHs.misses = stats.unqueuedOHs.misses + boolToNum(isMiss)
      if not hasEpilepsy then
         UIFrameFadeOut(ui.f.redFader, fadeOutTime, 1, 0)
      end
   end
end

function onCLEU(event)
   local combatInfo = {CombatLogGetCurrentEventInfo()}
   local _, event, _, sourceGUID, _, _, _, _, _, _, _, spellID, _, _ = unpack(combatInfo)
   if not (sourceGUID == UnitGUID("player")) then
      return
   end
   if event == "SWING_DAMAGE" then
      local _, _, _, _, _, _, _, _, _, isOffHand = select(12, unpack(combatInfo))
      if isOffHand then
         registerOHSwing(false)
      end
   elseif (event == "SWING_MISSED") then
      local missType, isOffHand = select(12, unpack(combatInfo))
      if isOffHand then
         registerOHSwing(missType == "MISS")
      end
   end
end

function registerSwingEvents(f)
   f:RegisterEvent("UNIT_SPELLCAST_SENT")
   f:RegisterEvent("UNIT_SPELLCAST_FAILED")
   f:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
   f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
   f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
   f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
   f:SetScript("OnEvent", OnEvent)
end

function makeFrameDraggable(f)
   f:SetMovable(true)
   f:EnableMouse(true)
   f:RegisterForDrag("LeftButton")
   f:SetScript("OnDragStart", f.StartMoving)
   f:SetScript("OnDragStop", f.StopMovingOrSizing)
end

function setFrameVisuals(f, width, height, r, g, b, a)
   f:SetPoint("CENTER")
   f:SetSize(width, height)
   f:SetBackdrop({
         bgFile = "Interface/Tooltips/UI-Tooltip-Background",
         edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
         edgeSize = 16,
         insets = { left = 4, right = 4, top = 4, bottom = 4 },
   })
   f:SetBackdropColor(r, g, b, a)
end

function makeMainFrame()
   local f = CreateFrame("Frame", MAIN_FRAME_NAME, UIParent, BackdropTemplateMixin and "BackdropTemplate")
   makeFrameDraggable(f)
   local width, height = 110, 54
   setFrameVisuals(f, width, height, 0, 0, 0, 0.8)

   f.greenFader = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate")
   setFrameVisuals(f.greenFader, width, height, 0, 1, 0, 1)
   f.greenFader:Hide()

   f.redFader = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate")
   setFrameVisuals(f.redFader, width, height, 1, 0, 0, 1)
   f.redFader:Hide()

   local vertPad = 2
   local borderPad = 8
   f.titleText = f:CreateFontString(nil, "OVERLAY")
   f.titleText:SetFont(FONT_NAME, TITLE_FONT_SIZE)
   f.titleText:SetPoint("CENTER", 0, height/2 - TITLE_FONT_SIZE - vertPad)
   f.titleText:SetText("Queued OHs")
   f.titleText:Show()
   local yOffset = TITLE_FONT_SIZE + borderPad + vertPad

   f.queuedTotalTextLeftText = f:CreateFontString(nil, "OVERLAY")
   f.queuedTotalTextLeftText:SetFont(FONT_NAME, FONT_SIZE)
   f.queuedTotalTextLeftText:SetPoint("TOPLEFT", borderPad, -yOffset)
   f.queuedTotalTextLeftText:SetText("#")
   f.queuedTotalTextLeftText:Show()

   f.queuedTotalTextRightText = f:CreateFontString(nil, "OVERLAY")
   f.queuedTotalTextRightText:SetFont(FONT_NAME, FONT_SIZE)
   f.queuedTotalTextRightText:SetPoint("TOPRIGHT", -borderPad, -yOffset)
   f.queuedTotalTextRightText:Show()

   yOffset = yOffset + FONT_SIZE + vertPad

   f.missPercentageLeftText = f:CreateFontString(nil, "OVERLAY")
   f.missPercentageLeftText:SetFont(FONT_NAME, FONT_SIZE)
   f.missPercentageLeftText:SetPoint("TOPLEFT", borderPad, -yOffset)
   f.missPercentageLeftText:SetText("Miss%")
   f.missPercentageLeftText:Show()

   f.missPercentageRightText = f:CreateFontString(nil, "OVERLAY")
   f.missPercentageRightText:SetFont(FONT_NAME, FONT_SIZE)
   f.missPercentageRightText:SetPoint("TOPRIGHT", -borderPad, -yOffset)
   f.missPercentageRightText:Show()
   return f
end

function updateMainFrame(f)
   f.queuedTotalTextRightText:SetText(string.format("%d/%d", stats.queuedOHs.total, stats.unqueuedOHs.total))

   local queuedMiss = stats.queuedOHs.total > 0 and stats.queuedOHs.misses / stats.queuedOHs.total or 0
   local unqueuedMiss = stats.unqueuedOHs.total > 0 and stats.unqueuedOHs.misses / stats.unqueuedOHs.total or 0
   f.missPercentageRightText:SetText(string.format("%d/%d", queuedMiss * 100, unqueuedMiss * 100))
end

ui.f = makeMainFrame()
registerSwingEvents(ui.f)
resetStats()
updateMainFrame(ui.f)

function HSQCommands(msg, editbox)
   if msg == 'reset' then
      resetStats()
      updateMainFrame(ui.f)
   else
      print("Usage: /hsq reset : reset statistics")
   end
end

SLASH_HSQ1 = "/hsq"
SlashCmdList["HSQ"] = HSQCommands
