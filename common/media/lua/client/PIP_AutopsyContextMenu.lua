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
-- Context menu hooks for the RV Autopsy Table Proxy feature.
--
-- Inside RV: Adds "Register/Unregister as Field Proxy" on
--   morgue table objects.
-- Outside RV: Adds "Autopsy (RV Lab Table)" on ground corpses
--   when a proxied RV is nearby, invoking ZVV's own autopsy
--   timed action with table objects injected.
--
-- Depends on: PhobosLib, PIP_RVAutopsyProxy, PIP_SandboxIntegration,
--             ZVV (LabActionMakeAutopsy, morgueTable, LabRecipes_*)
---------------------------------------------------------------

require "PhobosLib"
require "PIP_RVAutopsyProxy"
require "PIP_SandboxIntegration"


--- Check all shared prerequisites for PIP proxy features.
---@return boolean
local function arePrerequisitesMet()
    if not PhobosLib.isExperimentalEnabled() then return false end
    if not PIP_Sandbox.isRVAutopsyProxyEnabled() then return false end
    if not PhobosLib.isModActive("ZVirusVaccine42BETA") then return false end
    return true
end


---------------------------------------------------------------
-- INSIDE RV: Register / Unregister proxy
---------------------------------------------------------------

--- Get the vehicle associated with the RV the player is currently in.
--- Uses Project RV Interior's global ModData to find the vehicle.
---@param player any  IsoPlayer
---@return any|nil  BaseVehicle or nil
local function getPlayerRVVehicle(player)
    if not player then return nil end

    local rvModData = ModData.getOrCreate("modPROJECTRVInterior")
    if not rvModData or not rvModData.Players then return nil end

    local playerKey = nil
    pcall(function() playerKey = tostring(player:getOnlineID()) end)
    if not playerKey then
        pcall(function() playerKey = tostring(player:getUsername()) end)
    end
    if not playerKey then return nil end

    local playerEntry = rvModData.Players[playerKey]
    if not playerEntry or not playerEntry.VehicleId then return nil end

    -- Find the vehicle by its persistent ID
    local cell = getCell()
    if not cell then return nil end

    local vehicles = nil
    pcall(function() vehicles = cell:getVehicles() end)
    if not vehicles then return nil end

    local targetId = playerEntry.VehicleId
    for i = 0, vehicles:size() - 1 do
        local v = vehicles:get(i)
        if v then
            local md = nil
            pcall(function() md = v:getModData() end)
            if md and md.projectRV_uniqueId == targetId then
                return v
            end
        end
    end

    return nil
end


--- Handle "Register as Field Proxy" action.
---@param player any
---@param obj any       IsoThumpable (the morgue table piece)
---@param vehicle any   BaseVehicle
local function onRegisterProxy(player, obj, vehicle)
    if not obj or not vehicle then return end

    local sq = obj:getSquare()
    if not sq then return end

    local spriteName = nil
    pcall(function()
        local sprite = obj:getSprite()
        if sprite and sprite.getName then
            spriteName = sprite:getName()
        end
    end)

    -- Find the top piece — register against that
    if morgueTable and spriteName and morgueTable[spriteName] then
        local top, _, _ = LabRecipes_GetBedObjects(obj, morgueTable)
        if top then
            local topSq = top:getSquare()
            if topSq then
                local topSprite = nil
                pcall(function() topSprite = top:getSprite():getName() end)
                PIP_RV.registerProxy(vehicle, topSq:getX(), topSq:getY(), topSq:getZ(), topSprite or spriteName)
                PhobosLib.say(player, getText("UI_PIP_ProxyRegistered"))
                return
            end
        end
    end

    -- Fallback: register using clicked object's coordinates
    PIP_RV.registerProxy(vehicle, sq:getX(), sq:getY(), sq:getZ(), spriteName or "")
    PhobosLib.say(player, getText("UI_PIP_ProxyRegistered"))
end


--- Handle "Unregister Field Proxy" action.
---@param player any
---@param vehicle any  BaseVehicle
local function onUnregisterProxy(player, vehicle)
    if not vehicle then return end
    PIP_RV.clearProxy(vehicle)
    PhobosLib.say(player, getText("UI_PIP_ProxyUnregistered"))
end


--- Add register/unregister options when inside RV and right-clicking a morgue table.
---@param player any
---@param context any   ISContextMenu
---@param worldobjects table
local function addInsideRVOptions(player, context, worldobjects)
    if not PIP_RV.isPlayerInRV(player) then return end
    if not morgueTable then return end

    -- Find morgue table object in clicked world objects
    for _, obj in ipairs(worldobjects) do
        if obj and instanceof(obj, "IsoThumpable") then
            local spriteName = nil
            pcall(function()
                local sprite = obj:getSprite()
                if sprite and sprite.getName then
                    spriteName = sprite:getName()
                end
            end)
            if spriteName and morgueTable[spriteName] then
                local vehicle = getPlayerRVVehicle(player)
                if not vehicle then return end

                local proxyData = PIP_RV.getProxyData(vehicle)
                if proxyData then
                    -- Already registered — offer unregister
                    local opt = context:addOption(
                        getText("UI_PIP_UnregisterProxy"),
                        player, onUnregisterProxy, vehicle
                    )
                    local tooltip = ISWorldObjectContextMenu.addToolTip()
                    tooltip.description = getText("UI_PIP_UnregisterProxy_Tooltip")
                    opt.toolTip = tooltip
                else
                    -- Not registered — offer register (only on Empty tables)
                    local _, _, status = LabRecipes_GetBedObjects(obj, morgueTable)
                    if status == "Empty" then
                        local opt = context:addOption(
                            getText("UI_PIP_RegisterProxy"),
                            player, onRegisterProxy, obj, vehicle
                        )
                        local tooltip = ISWorldObjectContextMenu.addToolTip()
                        tooltip.description = getText("UI_PIP_RegisterProxy_Tooltip")
                        opt.toolTip = tooltip
                    end
                end
                return  -- only process one table per right-click
            end
        end
    end
end


---------------------------------------------------------------
-- OUTSIDE RV: Proxy autopsy on ground corpses
---------------------------------------------------------------

--- Handle "Autopsy (RV Lab Table)" action.
--- Creates ZVV's LabActionMakeAutopsy with table objects injected.
---@param player any
---@param corpse any    IsoDeadBody
---@param top any       IsoThumpable (table top)
---@param bottom any    IsoThumpable (table bottom)
local function onProxyAutopsy(player, corpse, top, bottom)
    if not player or not corpse or not top or not bottom then return end
    if not LabActionMakeAutopsy then return end

    -- Create ZVV's autopsy action with table pieces injected
    local action = LabActionMakeAutopsy:new(player, corpse, top, bottom)
    ISTimedActionQueue.add(action)
end


--- Add proxy autopsy option when outside near a proxied RV and right-clicking a corpse.
---@param player any
---@param context any   ISContextMenu
---@param worldobjects table
local function addOutsideRVOptions(player, context, worldobjects)
    if PIP_RV.isPlayerInRV(player) then return end
    if not PhobosLib.isModActive("modPROJECTRVInterior") then return end

    local range = PIP_Sandbox.getRVAutopsyProxyRange()
    local match = PIP_RV.findNearbyProxiedVehicle(player, range)
    if not match then return end

    -- Get corpses from the right-clicked tile
    local sq = nil
    for _, obj in ipairs(worldobjects) do
        if obj and obj.getSquare then
            pcall(function() sq = obj:getSquare() end)
            if sq then break end
        end
    end
    if not sq then return end

    local corpses = PhobosLib.getCorpsesOnSquare(sq)
    if #corpses == 0 then return end

    -- Fetch the actual table objects from the RV interior
    local top, bottom, status = PIP_RV.fetchTableObjects(match.proxyData)

    -- Check table accessibility and status
    if not top or not bottom then return end

    if status ~= "Empty" then
        -- Table is occupied — add disabled option with explanation
        local opt = context:addOption(getText("UI_PIP_AutopsyRVTable"), worldobjects, nil)
        opt.notAvailable = true
        local tooltip = ISWorldObjectContextMenu.addToolTip()
        tooltip.description = getText("UI_PIP_RVTableInUse")
        opt.toolTip = tooltip
        return
    end

    -- Add autopsy option for each valid corpse
    local hasValidCorpse = false
    for _, corpse in ipairs(corpses) do
        local isZombie = false
        pcall(function() isZombie = corpse:isZombie() end)

        local alreadyAutopsied = false
        pcall(function()
            local md = corpse:getModData()
            alreadyAutopsied = md and md.Autopsy == true
        end)

        local age = PhobosLib.getCorpseAge(corpse)
        -- Use ZVV's 12-hour limit for consistency
        local tooOld = age > 12

        if isZombie and not alreadyAutopsied and not tooOld then
            hasValidCorpse = true
            local opt = context:addOption(
                getText("UI_PIP_AutopsyRVTable"),
                player, onProxyAutopsy, corpse, top, bottom
            )
            local tooltip = ISWorldObjectContextMenu.addToolTip()
            tooltip.description = getText("UI_PIP_AutopsyRVTable_Tooltip")
            opt.toolTip = tooltip

            -- Check ZVV equipment requirements and mark unavailable if missing
            if LabRecipes_CreateCorpseAutopsyTooltip then
                local inv = player:getInventory()
                local notFresh = tooOld
                local notZombie = not isZombie
                local notOrgans = alreadyAutopsied
                LabRecipes_CreateCorpseAutopsyTooltip(opt, inv, notFresh, notZombie, notOrgans)
            end
        end
    end
end


---------------------------------------------------------------
-- Context menu hook
---------------------------------------------------------------

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then return end
    if not arePrerequisitesMet() then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    addInsideRVOptions(player, context, worldobjects)
    addOutsideRVOptions(player, context, worldobjects)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
