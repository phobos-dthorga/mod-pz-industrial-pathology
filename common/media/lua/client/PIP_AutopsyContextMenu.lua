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
-- Also supports RV Bridge: if no local table is found but the
-- player is near an RV with a morgue table inside, offers
-- "Autopsy (RV Lab Table)" with remote relay to ZVV.
--
-- Depends on: PhobosLib, PIP_AutopsyProxy, PIP_SandboxIntegration,
--             PIP_RVBridge, PIP_TimedActionRemoteAutopsy,
--             ZVV (LabActionMakeAutopsy, morgueTable, LabRecipes_*)
---------------------------------------------------------------

require "PhobosLib"
require "PIP_AutopsyProxy"
require "PIP_SandboxIntegration"
require "PIP_RVBridge"
require "PIP_TimedActionRemoteAutopsy"


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
-- Corpse highlighting callback (reused by both paths)
---------------------------------------------------------------

local function makeHighlightCallback()
    local hc = getCore():getGoodHighlitedColor()
    return hc, function(_option, _menu, _isHighlighted, _object, _color)
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
end


---------------------------------------------------------------
-- Add corpse option with ZVV tooltip + status line
---------------------------------------------------------------

--- Build a corpse submenu option with tooltip, highlighting, and status line.
---@param subMenu any           ISContextMenu submenu
---@param player any            IsoPlayer
---@param corpse any            IsoDeadBody
---@param corpseSq any          IsoGridSquare
---@param inv any               ItemContainer
---@param tableStatus string    Table status key (Empty, Corpse, Remains, Dirty, NotAvailable)
---@param tableNotReady boolean Whether the table is NOT ready for autopsy
---@param actionTarget any      Either {top, bottom, ...} or remoteTableData
---@param isRemote boolean      true for RV bridge path
local function addCorpseOption(subMenu, player, corpse, corpseSq, inv, tableStatus, tableNotReady, actionTarget, isRemote)
    local zombie = isZombieSafe(corpse)
    local skeleton = isSkeletonSafe(corpse)
    local age = PhobosLib.getCorpseAge(corpse)
    local notFresh = skeleton or (age > PIP_Autopsy.ZVV_AUTOPSY_MAX_HOURS)
    local notZombie = not zombie

    local md = PhobosLib.getModData(corpse)
    local notOrgans = md and (md.Autopsy == true) or false

    local opt
    if isRemote then
        -- RV bridge: queue PIP's custom timed action
        local remoteTableData = actionTarget
        opt = subMenu:addOption(
            getText("ContextMenu_LabCorpse"),
            player, function(plr)
                ISTimedActionQueue.add(
                    PIP_TimedActionRemoteAutopsy:new(plr, corpse, corpseSq, remoteTableData)
                )
            end
        )
    else
        -- Proximity: use ZVV's callback directly
        opt = subMenu:addOption(
            getText("ContextMenu_LabCorpse"),
            player, LabRecipes_WMOnCorpseAutopsy,
            corpse, corpseSq, actionTarget.top, actionTarget.bottom
        )
    end

    -- Corpse highlighting on hover
    local hc, highlightFn = makeHighlightCallback()
    opt.onHighlightParams = { corpse, hc }
    opt.onHighlight = highlightFn

    -- ZVV's tooltip: corpse conditions + equipment
    if LabRecipes_CreateCorpseAutopsyTooltip then
        LabRecipes_CreateCorpseAutopsyTooltip(opt, inv, notFresh, notZombie, notOrgans)
    end

    -- Prepend PIP's table status line
    if opt.toolTip then
        local tableStatusLine = string.format(
            "%s: <%s> %s <RGB:1,1,1> <LINE>",
            getText("UI_PIP_TableStatus"),
            tableNotReady and "RED" or "GREEN",
            getText("UI_PIP_TableStatus_" .. tableStatus)
        )
        opt.toolTip.description = tableStatusLine .. (opt.toolTip.description or "")
    end

    -- Table not ready makes option unavailable
    if tableNotReady then
        opt.notAvailable = true
    end

    PhobosLib.debug("PIP", "CorpseOption", "Added corpse option: zombie=" .. tostring(zombie)
        .. " fresh=" .. tostring(not notFresh) .. " autopsied=" .. tostring(notOrgans)
        .. " tableReady=" .. tostring(not tableNotReady)
        .. " remote=" .. tostring(isRemote))
end


---------------------------------------------------------------
-- Context menu hook
---------------------------------------------------------------

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test and ISWorldObjectContextMenu.Test then return true end
    if not arePrerequisitesMet() then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local sq = getSquareFromWorldObjects(worldobjects)
    if not sq then return end

    -- Find corpses in 3x3 grid around click (matches ZVV's pattern)
    local corpseEntries = PhobosLib.getCorpsesInRadius(sq, 1)
    if #corpseEntries == 0 then return end

    local inv = player:getInventory()

    -------------------------------------------------------
    -- Path 1: Proximity table (existing behaviour)
    -------------------------------------------------------
    local range = PIP_Sandbox.getAutopsyTableRange()
    local tableResult = PIP_Autopsy.findNearbyMorgueTable(sq, range)

    if tableResult then
        local tableNotReady = tableResult.status ~= "Empty"
        local parent = context:addOption(getText("UI_PIP_AutopsyWithTable"), worldobjects, nil)
        local subMenu = ISContextMenu:getNew(context)
        context:addSubMenu(parent, subMenu)

        for _, entry in ipairs(corpseEntries) do
            addCorpseOption(subMenu, player, entry.corpse, entry.square,
                inv, tableResult.status, tableNotReady, tableResult, false)
        end
        return  -- proximity takes priority; don't show RV bridge too
    end

    -------------------------------------------------------
    -- Path 2: RV Bridge (remote table in RV interior)
    -------------------------------------------------------
    if not PIP_Sandbox.isRVBridgeEnabled() then return end

    local vehicleRange = PIP_Sandbox.getRVVehicleSearchRange()
    local remoteResult, reason = PIP_Autopsy.findRemoteTableViaRV(player, vehicleRange)

    if not remoteResult then
        -- Show greyed-out option when player IS near an RV but no table
        -- was ever cached (discoverability — tells player what to do)
        if reason == "no_table" then
            local parent = context:addOption(getText("UI_PIP_AutopsyWithRVTable"), worldobjects, nil)
            parent.notAvailable = true
            local tooltip = ISToolTip:new()
            tooltip:initialise()
            tooltip:setVisible(false)
            tooltip.description = string.format(
                "%s: <RED> %s <RGB:1,1,1> <LINE> <RED> %s",
                getText("UI_PIP_TableStatus"),
                getText("UI_PIP_TableStatus_NotAvailable"),
                getText("UI_PIP_RVNoTable")
            )
            parent.toolTip = tooltip
        end
        -- For other reasons (no_rv_mod, no_rv_nearby), silently skip
        return
    end

    -- Remote table found — build submenu
    local tableNotReady = remoteResult.status ~= "Empty"
    local parent = context:addOption(getText("UI_PIP_AutopsyWithRVTable"), worldobjects, nil)
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(parent, subMenu)

    for _, entry in ipairs(corpseEntries) do
        addCorpseOption(subMenu, player, entry.corpse, entry.square,
            inv, remoteResult.status, tableNotReady, remoteResult, true)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
