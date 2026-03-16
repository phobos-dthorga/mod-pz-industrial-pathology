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
-- PIP_RVAutopsyProxy.lua
-- Shared logic for proxying ZVV's Autopsy Table from inside
-- RV Interiors to outdoor corpses. Registration-based model:
-- player registers a table inside the RV, PIP validates on
-- each RV entry and checks modData at context menu time.
--
-- Depends on: PhobosLib, ZVV, Project RV Interior
---------------------------------------------------------------

require "PhobosLib"

PIP_RV = PIP_RV or {}

--- RV Interior coordinate threshold (Project RV places interiors here).
local RV_INTERIOR_X_THRESHOLD = 22500
local RV_INTERIOR_Y_THRESHOLD = 12000


--- Check if a player is currently inside an RV Interior.
---@param player any  IsoPlayer
---@return boolean
function PIP_RV.isPlayerInRV(player)
    if not player then return false end
    local ok, px = pcall(function() return player:getX() end)
    local ok2, py = pcall(function() return player:getY() end)
    if not (ok and ok2) then return false end
    return px > RV_INTERIOR_X_THRESHOLD and py > RV_INTERIOR_Y_THRESHOLD
end


--- Get the proxy registration data from a vehicle's modData.
---@param vehicle any  BaseVehicle
---@return table|nil  {x, y, z, sprite} or nil if not registered
function PIP_RV.getProxyData(vehicle)
    if not vehicle then return nil end
    local md = nil
    pcall(function() md = vehicle:getModData() end)
    if not md then return nil end
    return md.PIP_AutopsyProxy
end


--- Register an autopsy table as a field proxy on a vehicle.
---@param vehicle any       BaseVehicle
---@param tableX number     Tile X of the table top piece
---@param tableY number     Tile Y of the table top piece
---@param tableZ number     Tile Z of the table top piece
---@param sprite string     Sprite name of the table top piece
function PIP_RV.registerProxy(vehicle, tableX, tableY, tableZ, sprite)
    if not vehicle then return end
    local md = nil
    pcall(function() md = vehicle:getModData() end)
    if not md then return end
    md.PIP_AutopsyProxy = {
        x = tableX,
        y = tableY,
        z = tableZ,
        sprite = sprite,
    }
    PhobosLib.debug("PIP", "RVProxy", "Registered autopsy table proxy at "
        .. tostring(tableX) .. "," .. tostring(tableY) .. "," .. tostring(tableZ))
end


--- Clear proxy registration from a vehicle.
---@param vehicle any  BaseVehicle
function PIP_RV.clearProxy(vehicle)
    if not vehicle then return end
    local md = nil
    pcall(function() md = vehicle:getModData() end)
    if not md then return end
    md.PIP_AutopsyProxy = nil
    PhobosLib.debug("PIP", "RVProxy", "Cleared autopsy table proxy")
end


--- Validate that a registered proxy table still exists at the stored location.
--- If the table is gone or has an invalid sprite, clears the registration.
---@param vehicle any  BaseVehicle
---@return boolean  true if proxy is still valid
function PIP_RV.validateProxy(vehicle)
    local proxyData = PIP_RV.getProxyData(vehicle)
    if not proxyData then return false end

    local cell = getCell()
    if not cell then return false end

    local sq = cell:getGridSquare(proxyData.x, proxyData.y, proxyData.z)
    if not sq then
        PIP_RV.clearProxy(vehicle)
        return false
    end

    -- Check if any object on this square has a morgueTable sprite
    if not morgueTable then
        -- ZVV not loaded or morgueTable global not available
        PIP_RV.clearProxy(vehicle)
        return false
    end

    local objs = sq:getObjects()
    if not objs then
        PIP_RV.clearProxy(vehicle)
        return false
    end

    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if obj and instanceof(obj, "IsoThumpable") then
            local spriteName = nil
            pcall(function()
                local sprite = obj:getSprite()
                if sprite and sprite.getName then
                    spriteName = sprite:getName()
                end
            end)
            if spriteName and morgueTable[spriteName] then
                return true
            end
        end
    end

    -- Table not found at stored location
    PIP_RV.clearProxy(vehicle)
    PhobosLib.debug("PIP", "RVProxy", "Proxy validation failed — table no longer present")
    return false
end


--- Find the first nearby vehicle (within radius) that has a registered proxy.
---@param player any     IsoPlayer
---@param radius number  Tile radius
---@return table|nil  {vehicle, proxyData} or nil
function PIP_RV.findNearbyProxiedVehicle(player, radius)
    if not player then return nil end
    local vehicles = PhobosLib.findAllNearbyVehicles(player, radius)

    for _, v in ipairs(vehicles) do
        local proxyData = PIP_RV.getProxyData(v)
        if proxyData then
            return { vehicle = v, proxyData = proxyData }
        end
    end

    return nil
end


--- Fetch the actual table IsoThumpable objects (top + bottom) from stored
--- proxy coordinates. Uses ZVV's LabRecipes_GetBedObjects if available.
---@param proxyData table  {x, y, z, sprite}
---@return any, any, string|nil  top, bottom, status — or nil if not accessible
function PIP_RV.fetchTableObjects(proxyData)
    if not proxyData then return nil, nil, nil end

    local cell = getCell()
    if not cell then return nil, nil, nil end

    local sq = cell:getGridSquare(proxyData.x, proxyData.y, proxyData.z)
    if not sq then return nil, nil, nil end

    -- Find the table object on this square
    local objs = sq:getObjects()
    if not objs then return nil, nil, nil end

    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if obj and instanceof(obj, "IsoThumpable") then
            local spriteName = nil
            pcall(function()
                local sprite = obj:getSprite()
                if sprite and sprite.getName then
                    spriteName = sprite:getName()
                end
            end)
            if spriteName and morgueTable and morgueTable[spriteName] then
                -- Use ZVV's own function to get both table pieces
                if LabRecipes_GetBedObjects then
                    local top, bottom, status = LabRecipes_GetBedObjects(obj, morgueTable)
                    return top, bottom, status
                end
                return nil, nil, nil
            end
        end
    end

    return nil, nil, nil
end
