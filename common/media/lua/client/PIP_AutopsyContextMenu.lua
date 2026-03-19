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
require "PIP_Constants"
require "PIP_AutopsyProxy"
require "PIP_SandboxIntegration"
require "PIP_RVBridge"
require "PIP_EquipmentCheck"
require "PIP_TimedActionRemoteAutopsy"
require "PIP_TimedActionRemoteGetRemains"
require "PIP_TimedActionRemoteCollectPart"
require "PIP_TimedActionRemoteClearTable"


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
-- Area safety gate (RV Bridge only)
---------------------------------------------------------------

--- Apply area safety gate to a context menu option.
--- If the area is NOT safe (zombies nearby), greys out the option
--- and prepends a RED safety warning to the tooltip.
--- Only used for RV Bridge path — proximity path delegates to ZVV.
---@param opt any           ISContextMenu option
---@param player any        IsoPlayer
---@return boolean          true if area is safe, false if gated
local function applySafetyGate(opt, player)
    if PhobosLib.isAreaSafe(player) then return true end

    opt.notAvailable = true

    -- Ensure tooltip exists
    if not opt.toolTip then
        local tooltip = ISToolTip:new()
        tooltip:initialise()
        tooltip:setVisible(false)
        tooltip.description = ""
        opt.toolTip = tooltip
    end

    -- Prepend safety warning in RED
    local safetyLine = string.format(
        "<RED> %s <RGB:1,1,1> <LINE> <RGB:0.6,0.6,0.6> %s <RGB:1,1,1> <LINE> ",
        getText("UI_PIP_AreaNotSafe"),
        getText("UI_PIP_AreaNotSafe_Tooltip")
    )
    opt.toolTip.description = safetyLine .. (opt.toolTip.description or "")
    return false
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

    -- RV Bridge: area safety gate (zombies nearby → greyed out)
    if isRemote then
        applySafetyGate(opt, player)
    end

    PhobosLib.debug("PIP", "CorpseOption", "Added corpse option: zombie=" .. tostring(zombie)
        .. " fresh=" .. tostring(not notFresh) .. " autopsied=" .. tostring(notOrgans)
        .. " tableReady=" .. tostring(not tableNotReady)
        .. " remote=" .. tostring(isRemote))
end


---------------------------------------------------------------
-- RV Bridge: secondary extraction menus (Remains / Dirty)
---------------------------------------------------------------

--- Body part definitions for the "Collect Body Parts" submenu.
local BODY_PARTS = {
    { itemType = "RANDOM_BRAIN",                      textKey = "ContextMenu_LabCollectBrain" },
    { itemType = "LabItems.LabHumanBoneLargeWP",      textKey = "ContextMenu_LabCollectLargeBones" },
    { itemType = "LabItems.LabHumanTeeth",             textKey = "ContextMenu_LabCollectTeeth" },
    { itemType = "LabItems.LabHumanSkullWithBrain",    textKey = "ContextMenu_LabCollectSkull" },
    { itemType = "LabItems.LabSmallRandomHumanBones",  textKey = "ContextMenu_LabCollectSmallBones" },
    { itemType = "LabItems.LabRegularHumanBoneWP",     textKey = "ContextMenu_LabCollectRegularBones" },
}

--- Create a PIP tooltip with a table status header line.
---@param tableStatus string
---@param tableNotReady boolean
---@return any  ISToolTip
local function makeStatusTooltip(tableStatus, tableNotReady)
    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip:setVisible(false)
    tooltip.description = string.format(
        "%s: <%s> %s <RGB:1,1,1> <LINE> ",
        getText("UI_PIP_TableStatus"),
        tableNotReady and "RED" or "GREEN",
        getText("UI_PIP_TableStatus_" .. tableStatus)
    )
    return tooltip
end

--- Build the "Remains" state menu: Get Remains + Collect Body Parts.
---@param context any           ISContextMenu
---@param player any            IsoPlayer
---@param inv any               ItemContainer
---@param remoteResult table    From findRemoteTableViaRV
---@param worldobjects table
local function addRemainsMenu(context, player, inv, remoteResult, worldobjects)
    local parent = context:addOption(getText("UI_PIP_RVLabTable"), worldobjects, nil)
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(parent, subMenu)

    -- Table status tooltip on parent
    local parentTip = makeStatusTooltip("Remains", false)
    parent.toolTip = parentTip

    -- "Get Remains" option
    local getRemainsOk, grSack, grPlastics = PIP_EquipmentCheck.checkGetRemains(inv)
    local grOpt = subMenu:addOption(
        getText("UI_PIP_GetRemains"),
        player, function(plr)
            ISTimedActionQueue.add(
                PIP_TimedActionRemoteGetRemains:new(plr, remoteResult)
            )
        end
    )
    local grTip = ISToolTip:new()
    grTip:initialise()
    grTip:setVisible(false)
    grTip.description = getText("UI_PIP_GetRemains_Tooltip") .. " <LINE> "
    PIP_EquipmentCheck.appendContainerTooltip(grTip, grSack, grPlastics)
    grOpt.toolTip = grTip
    if not getRemainsOk then grOpt.notAvailable = true end
    applySafetyGate(grOpt, player)

    -- "Collect Body Parts" submenu
    local cpOk, cpScalpel, cpSaw, cpSack, cpPlastics = PIP_EquipmentCheck.checkCollectPart(inv)
    local collectParent = subMenu:addOption(getText("UI_PIP_CollectBodyParts"), worldobjects, nil)
    local collectSub = ISContextMenu:getNew(subMenu)
    subMenu:addSubMenu(collectParent, collectSub)

    for _, part in ipairs(BODY_PARTS) do
        local partOpt = collectSub:addOption(
            getText(part.textKey),
            player, function(plr)
                ISTimedActionQueue.add(
                    PIP_TimedActionRemoteCollectPart:new(plr, remoteResult, part.itemType)
                )
            end
        )
        local partTip = ISToolTip:new()
        partTip:initialise()
        partTip:setVisible(false)
        partTip.description = ""
        PIP_EquipmentCheck.appendCollectPartTooltip(partTip, cpScalpel, cpSaw, cpSack, cpPlastics)
        partOpt.toolTip = partTip
        if not cpOk then partOpt.notAvailable = true end
        applySafetyGate(partOpt, player)
    end

    PhobosLib.debug("PIP", "RVMenu", "Added Remains menu: getRemains=" .. tostring(getRemainsOk)
        .. " collectPart=" .. tostring(cpOk))
end

--- Build the "Dirty" state menu: Clear Table.
---@param context any           ISContextMenu
---@param player any            IsoPlayer
---@param inv any               ItemContainer
---@param remoteResult table    From findRemoteTableViaRV
---@param worldobjects table
local function addDirtyMenu(context, player, inv, remoteResult, worldobjects)
    local parent = context:addOption(getText("UI_PIP_RVLabTable"), worldobjects, nil)
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(parent, subMenu)

    -- Table status tooltip on parent
    local parentTip = makeStatusTooltip("Dirty", true)
    parent.toolTip = parentTip

    -- "Clear Table" option
    local clearOk, hasBleach, hasRag = PIP_EquipmentCheck.checkClearTable(inv)
    local clearOpt = subMenu:addOption(
        getText("UI_PIP_ClearTable"),
        player, function(plr)
            ISTimedActionQueue.add(
                PIP_TimedActionRemoteClearTable:new(plr, remoteResult)
            )
        end
    )
    local clearTip = ISToolTip:new()
    clearTip:initialise()
    clearTip:setVisible(false)
    clearTip.description = getText("UI_PIP_ClearTable_Tooltip") .. " <LINE> "
    PIP_EquipmentCheck.appendClearTableTooltip(clearTip, hasBleach, hasRag)
    clearOpt.toolTip = clearTip
    if not clearOk then clearOpt.notAvailable = true end
    applySafetyGate(clearOpt, player)

    PhobosLib.debug("PIP", "RVMenu", "Added Dirty menu: clearOk=" .. tostring(clearOk))
end

--- Build a greyed-out "Corpse" (occupied) info option.
---@param context any
---@param worldobjects table
local function addCorpseStateInfo(context, worldobjects)
    local parent = context:addOption(getText("UI_PIP_RVLabTable"), worldobjects, nil)
    parent.notAvailable = true
    local tip = makeStatusTooltip(PIP_Constants.TABLE_CORPSE, true)
    tip.description = tip.description .. getText("UI_PIP_TableStatus_Corpse_Info")
    parent.toolTip = tip
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

    local inv = player:getInventory()

    -- Find corpses in 3x3 grid around click (matches ZVV's pattern)
    local corpseEntries = PhobosLib.getCorpsesInRadius(sq, 1)

    -------------------------------------------------------
    -- Path 1: Proximity table (existing behaviour)
    -- Requires nearby corpses to show options.
    -------------------------------------------------------
    if #corpseEntries > 0 then
        local range = PIP_Sandbox.getAutopsyTableRange()
        local tableResult = PIP_Autopsy.findNearbyMorgueTable(sq, range)

        if tableResult then
            local tableNotReady = tableResult.status ~= PIP_Constants.TABLE_EMPTY
            local parent = context:addOption(getText("UI_PIP_AutopsyWithTable"), worldobjects, nil)
            local subMenu = ISContextMenu:getNew(context)
            context:addSubMenu(parent, subMenu)

            for _, entry in ipairs(corpseEntries) do
                addCorpseOption(subMenu, player, entry.corpse, entry.square,
                    inv, tableResult.status, tableNotReady, tableResult, false)
            end
            return  -- proximity takes priority; don't show RV bridge too
        end
    end

    -------------------------------------------------------
    -- Path 2: RV Bridge (remote table in RV interior)
    -- Shows menus based on cached table state.
    -- Remains/Dirty states don't require nearby corpses.
    -------------------------------------------------------
    if not PIP_Sandbox.isRVBridgeEnabled() then return end

    local vehicleRange = PIP_Sandbox.getRVVehicleSearchRange()
    local remoteResult, reason = PIP_Autopsy.findRemoteTableViaRV(player, vehicleRange)

    if not remoteResult then
        -- Show greyed-out option when player IS near an RV but no table
        -- was ever cached (discoverability — tells player what to do)
        if reason == "no_table" then
            local noTableParent = context:addOption(getText("UI_PIP_AutopsyWithRVTable"), worldobjects, nil)
            noTableParent.notAvailable = true
            local tooltip = ISToolTip:new()
            tooltip:initialise()
            tooltip:setVisible(false)
            tooltip.description = string.format(
                "%s: <RED> %s <RGB:1,1,1> <LINE> <RED> %s",
                getText("UI_PIP_TableStatus"),
                getText("UI_PIP_TableStatus_NotAvailable"),
                getText("UI_PIP_RVNoTable")
            )
            noTableParent.toolTip = tooltip
        end
        return
    end

    -- Dispatch based on cached table status
    local status = remoteResult.status

    if status == PIP_Constants.TABLE_REMAINS then
        -- Post-autopsy: offer extraction and collection options
        addRemainsMenu(context, player, inv, remoteResult, worldobjects)

    elseif status == PIP_Constants.TABLE_DIRTY then
        -- Post-extraction: offer table cleanup
        addDirtyMenu(context, player, inv, remoteResult, worldobjects)

    elseif status == PIP_Constants.TABLE_CORPSE then
        -- Corpse on table — can't do anything, show info
        addCorpseStateInfo(context, worldobjects)

    elseif status == PIP_Constants.TABLE_EMPTY then
        -- Table is ready — show autopsy options if corpses nearby
        if #corpseEntries > 0 then
            local parent = context:addOption(getText("UI_PIP_AutopsyWithRVTable"), worldobjects, nil)
            local subMenu = ISContextMenu:getNew(context)
            context:addSubMenu(parent, subMenu)

            for _, entry in ipairs(corpseEntries) do
                addCorpseOption(subMenu, player, entry.corpse, entry.square,
                    inv, remoteResult.status, false, remoteResult, true)
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
