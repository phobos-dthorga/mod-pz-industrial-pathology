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
    if not PIP_RV.isZVVCompatible() then return false end
    return true
end


--- Extract sprite name from an object via PhobosLib.
---@param obj any  IsoObject
---@return string|nil
local function getSpriteName(obj)
    local ok, sprite = PhobosLib.pcallMethod(obj, "getSprite")
    if not ok or not sprite then return nil end
    local ok2, name = PhobosLib.pcallMethod(sprite, "getName")
    return (ok2 and name) or nil
end


---------------------------------------------------------------
-- INSIDE RV: Register / Unregister proxy
---------------------------------------------------------------

--- Get the vehicle associated with the RV the player is currently in.
--- Uses Project RV Interior's global ModData to find the vehicle.
--- NOTE (MP): getOnlineID() -> getUsername() fallback is sound for SP
--- and standard MP. Edge cases (split-screen, reconnects, stale ModData)
--- need in-game MP testing but no code changes without concrete failures.
---@param player any  IsoPlayer
---@return any|nil  BaseVehicle or nil
local function getPlayerRVVehicle(player)
    if not player then return nil end

    local rvModData = ModData.getOrCreate("modPROJECTRVInterior")
    if not rvModData or not rvModData.Players then return nil end

    local ok, onlineId = PhobosLib.pcallMethod(player, "getOnlineID")
    local playerKey = ok and onlineId and tostring(onlineId) or nil
    if not playerKey then
        local ok2, username = PhobosLib.pcallMethod(player, "getUsername")
        playerKey = ok2 and username and tostring(username) or nil
    end
    if not playerKey then return nil end

    local playerEntry = rvModData.Players[playerKey]
    if not playerEntry or not playerEntry.VehicleId then return nil end

    -- Find the vehicle by its persistent ID
    local cell = getCell()
    if not cell then return nil end

    local ok3, vehicles = PhobosLib.pcallMethod(cell, "getVehicles")
    if not ok3 or not vehicles then return nil end

    local targetId = playerEntry.VehicleId
    for i = 0, vehicles:size() - 1 do
        local v = vehicles:get(i)
        if v then
            local md = PhobosLib.getModData(v)
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

    local spriteName = getSpriteName(obj)

    -- Find the top piece — register against that
    if morgueTable and spriteName and morgueTable[spriteName] then
        local top, _, _ = LabRecipes_GetBedObjects(obj, morgueTable)
        if top then
            local topSq = top:getSquare()
            if topSq then
                local topSprite = getSpriteName(top)
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

    -- Find morgue table object in clicked world objects
    for _, obj in ipairs(worldobjects) do
        if obj and instanceof(obj, "IsoThumpable") then
            local spriteName = getSpriteName(obj)
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
            local ok
            ok, sq = PhobosLib.pcallMethod(obj, "getSquare")
            if ok and sq then break end
        end
    end
    if not sq then return end

    local corpses = PhobosLib.getCorpsesOnSquare(sq)
    if #corpses == 0 then return end

    -- Fetch the actual table objects from the RV interior
    local top, bottom, status = PIP_RV.fetchTableObjects(match.proxyData)

    -- Auto-invalidate proxy if table is no longer accessible
    if not top or not bottom then
        PIP_RV.clearProxy(match.vehicle)
        PhobosLib.say(player, getText("UI_PIP_ProxyInvalidated"))
        PhobosLib.debug("PIP", "RVProxy", "Auto-invalidated proxy — table not accessible")
        return
    end

    if status ~= "Empty" then
        -- Table is occupied — add disabled option with explanation
        local opt = context:addOption(getText("UI_PIP_AutopsyRVTable"), worldobjects, nil)
        opt.notAvailable = true
        local tooltip = ISWorldObjectContextMenu.addToolTip()
        tooltip.description = getText("UI_PIP_RVTableInUse")
        opt.toolTip = tooltip
        return
    end

    -- Collect valid corpses with debug logging for rejections
    local candidates = {}
    for _, corpse in ipairs(corpses) do
        local ok, isZombie = PhobosLib.pcallMethod(corpse, "isZombie")
        isZombie = ok and isZombie or false

        local alreadyAutopsied = false
        local md = PhobosLib.getModData(corpse)
        if md then
            alreadyAutopsied = md.Autopsy == true
        end

        local age = PhobosLib.getCorpseAge(corpse)
        local tooOld = age > PIP_RV.ZVV_AUTOPSY_MAX_HOURS

        if not isZombie then
            PhobosLib.debug("PIP", "CorpseGate", "Rejected: not a zombie")
        elseif alreadyAutopsied then
            PhobosLib.debug("PIP", "CorpseGate", "Rejected: already autopsied")
        elseif tooOld then
            PhobosLib.debug("PIP", "CorpseGate", "Rejected: age " .. string.format("%.1f", age) .. "h > limit")
        else
            table.insert(candidates, { corpse = corpse, age = age })
        end
    end

    if #candidates == 0 then return end

    -- Sort by age ascending (freshest first), pick only the freshest
    table.sort(candidates, function(a, b) return a.age < b.age end)
    local best = candidates[1]

    local opt = context:addOption(
        getText("UI_PIP_AutopsyRVTable"),
        player, onProxyAutopsy, best.corpse, top, bottom
    )
    local tooltip = ISWorldObjectContextMenu.addToolTip()
    tooltip.description = getText("UI_PIP_AutopsyRVTable_Tooltip")
    opt.toolTip = tooltip

    -- Enhance tooltip with ZVV equipment requirements if available
    if LabRecipes_CreateCorpseAutopsyTooltip then
        local inv = player:getInventory()
        LabRecipes_CreateCorpseAutopsyTooltip(opt, inv, false, false, false)
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
