--  ________________________________________________________________________
-- / Copyright (c) 2026 Phobos A. D'thorga                                \
-- |                                                                        |
-- |           /\_/\                                                         |
-- |         =/ o o \=    Phobos' PZ Modding                                |
-- |          (  V  )     All rights reserved.                              |
-- |     /\  / \   / \                                                      |
-- |    /  \/   '-'   \   This source code is part of the Phobos            |
-- |   /  /  \  ^  /\  \  mod suite for Project Zomboid (Build 42).         |
-- |  (__/    \_/ \/  \__)                                                  |
-- |     |   | |  | |     Unauthorised copying, modification, or            |
-- |     |___|_|  |_|     distribution of this file is prohibited.          |
-- |                                                                        |
-- \________________________________________________________________________/
--

---------------------------------------------------------------
-- PIP_AutopsyContextMenu.lua
-- Context menu hook for proximity-based autopsy table usage.
--
-- When the player right-clicks near a ZVV morgue table AND
-- corpses are nearby, adds "Autopsy (Lab Table)" options.
-- Options always show when conditions are partially met,
-- with red/green indicators for unmet/met requirements
-- (matching vanilla B42 UX patterns).
--
-- Depends on: PhobosLib, PIP_AutopsyProxy, PIP_SandboxIntegration,
--             ZVV (LabActionMakeAutopsy, morgueTable, LabRecipes_*)
---------------------------------------------------------------

require "PhobosLib"
require "PIP_AutopsyProxy"
require "PIP_SandboxIntegration"


---------------------------------------------------------------
-- Prerequisites
---------------------------------------------------------------

local _prereqLogged = false

--- Check all shared prerequisites for PIP autopsy features.
---@return boolean
local function arePrerequisitesMet()
    if not PIP_Sandbox.isProximityAutopsyEnabled() then
        if not _prereqLogged then
            PhobosLib.debug("PIP", "Prereq", "Proximity autopsy disabled in sandbox")
            _prereqLogged = true
        end
        return false
    end
    if not PhobosLib.isModActive("ZVirusVaccine42BETA") then
        if not _prereqLogged then
            PhobosLib.debug("PIP", "Prereq", "ZVirusVaccine42BETA not active")
            _prereqLogged = true
        end
        return false
    end
    if not PIP_Autopsy.isZVVCompatible() then
        if not _prereqLogged then
            PhobosLib.debug("PIP", "Prereq", "ZVV globals not available")
            _prereqLogged = true
        end
        return false
    end
    return true
end


---------------------------------------------------------------
-- Helpers
---------------------------------------------------------------

--- Safely check if a corpse was a zombie.
---@param corpse any  IsoDeadBody
---@return boolean
local function isZombieSafe(corpse)
    if not corpse then return false end
    local ok, result = PhobosLib.pcallMethod(corpse, "isZombie")
    return ok and (result == true)
end

--- Safely check if a corpse is a skeleton.
---@param corpse any  IsoDeadBody
---@return boolean
local function isSkeletonSafe(corpse)
    if not corpse then return false end
    local md = PhobosLib.getModData(corpse)
    return md and (md.Skeleton == true)
end

--- Get the square from worldobjects list.
---@param worldobjects table
---@return any|nil  IsoGridSquare
local function getSquareFromWorldObjects(worldobjects)
    for _, obj in ipairs(worldobjects) do
        if obj and type(obj.getSquare) == "function" then
            local ok, sq = pcall(function() return obj:getSquare() end)
            if ok and sq then return sq end
        end
    end
    return nil
end


---------------------------------------------------------------
-- Context menu hook
---------------------------------------------------------------

--- @param playerNum number
--- @param context any       ISContextMenu
--- @param worldobjects table
--- @param test boolean
local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test and ISWorldObjectContextMenu.Test then return true end
    if not arePrerequisitesMet() then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local sq = getSquareFromWorldObjects(worldobjects)
    if not sq then return end

    -- Find nearest morgue table within range (any status)
    local range = PIP_Sandbox.getAutopsyTableRange()
    local tableResult = PIP_Autopsy.findNearbyMorgueTable(sq, range)
    if not tableResult then return end

    -- Find corpses in 3x3 grid around click (matches ZVV's pattern)
    local corpseEntries = PhobosLib.getCorpsesInRadius(sq, 1)
    if #corpseEntries == 0 then return end

    local inv = player:getInventory()
    local tableNotReady = tableResult.status ~= "Empty"

    -- Build submenu (like ZVV's ground autopsy submenu)
    local parent = context:addOption(getText("UI_PIP_AutopsyWithTable"), worldobjects, nil)
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(parent, subMenu)

    for _, entry in ipairs(corpseEntries) do
        local corpse = entry.corpse
        local corpseSq = entry.square

        local zombie = isZombieSafe(corpse)
        local skeleton = isSkeletonSafe(corpse)
        local age = PhobosLib.getCorpseAge(corpse)
        local notFresh = skeleton or (age > PIP_Autopsy.ZVV_AUTOPSY_MAX_HOURS)
        local notZombie = not zombie

        local md = PhobosLib.getModData(corpse)
        local notOrgans = md and (md.Autopsy == true) or false

        -- Add option — ZVV's callback handles equipment, walking, and the timed action
        local opt = subMenu:addOption(
            getText("ContextMenu_LabCorpse"),
            player, LabRecipes_WMOnCorpseAutopsy,
            corpse, corpseSq, tableResult.top, tableResult.bottom
        )

        -- Corpse highlighting on hover (mirrors ZVV LabModEngine_Client.lua:579-591)
        local hc = getCore():getGoodHighlitedColor()
        opt.onHighlightParams = { corpse, hc }
        opt.onHighlight = function(_option, _menu, _isHighlighted, _object, _color)
            if not _object then return end
            if _isHighlighted then
                _object:setHighlightColor(_menu.player, _color)
                _object:setOutlineHighlightCol(_menu.player, _color)
            end
            _object:setHighlighted(_menu.player, _isHighlighted, false)
            _object:setOutlineHighlight(_menu.player, _isHighlighted)
            _object:setOutlineHlAttached(_menu.player, _isHighlighted)
            ISInventoryPage.OnObjectHighlighted(_menu.player, _object, _isHighlighted)
        end

        -- ZVV's tooltip: corpse conditions + equipment (creates opt.toolTip, sets opt.notAvailable)
        if LabRecipes_CreateCorpseAutopsyTooltip then
            LabRecipes_CreateCorpseAutopsyTooltip(opt, inv, notFresh, notZombie, notOrgans)
        end

        -- Prepend PIP's table status line
        if opt.toolTip then
            local tableStatusLine = string.format(
                "%s: <%s> %s <RGB:1,1,1> <LINE>",
                getText("UI_PIP_TableStatus"),
                tableNotReady and "RED" or "GREEN",
                getText("UI_PIP_TableStatus_" .. tableResult.status)
            )
            opt.toolTip.description = tableStatusLine .. (opt.toolTip.description or "")
        end

        -- Table not ready makes option unavailable regardless of other checks
        if tableNotReady then
            opt.notAvailable = true
        end

        PhobosLib.debug("PIP", "CorpseOption", "Added corpse option: zombie=" .. tostring(zombie)
            .. " fresh=" .. tostring(not notFresh) .. " autopsied=" .. tostring(notOrgans)
            .. " tableReady=" .. tostring(not tableNotReady))
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
