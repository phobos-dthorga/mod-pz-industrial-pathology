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

--- ZVV's corpse age limit for autopsy eligibility (hours).
--- Mirrors LabConst.AUTOPSY_MAX_HOURS. Update if ZVV changes this.
PIP_RV.ZVV_AUTOPSY_MAX_HOURS = 12


---------------------------------------------------------------
-- ZVV compatibility gate
---------------------------------------------------------------

local zvvCompatChecked = false
local zvvCompatResult = false

--- Check if all required ZVV globals are available.
--- Caches result after first check. LabRecipes_CreateCorpseAutopsyTooltip
--- is optional (tooltip enhancement only) and not included in the gate.
---@return boolean
function PIP_RV.isZVVCompatible()
    if zvvCompatChecked then return zvvCompatResult end
    zvvCompatChecked = true
    local missing = {}
    if not morgueTable then table.insert(missing, "morgueTable") end
    if not LabRecipes_GetBedObjects then table.insert(missing, "LabRecipes_GetBedObjects") end
    if not LabActionMakeAutopsy then table.insert(missing, "LabActionMakeAutopsy") end
    if #missing > 0 then
        PhobosLib.debug("PIP", "ZVVCompat", "Missing ZVV globals: " .. table.concat(missing, ", "))
        zvvCompatResult = false
        return false
    end
    zvvCompatResult = true
    return true
end


---------------------------------------------------------------
-- Sprite name helper
---------------------------------------------------------------

--- Extract the sprite name from an IsoObject using PhobosLib.
---@param obj any  IsoObject
---@return string|nil
local function getSpriteName(obj)
    local ok, sprite = PhobosLib.pcallMethod(obj, "getSprite")
    if not ok or not sprite then return nil end
    local ok2, name = PhobosLib.pcallMethod(sprite, "getName")
    return (ok2 and name) or nil
end


---------------------------------------------------------------
-- Core functions
---------------------------------------------------------------

--- Check if a player is currently inside an RV Interior.
---@param player any  IsoPlayer
---@return boolean
function PIP_RV.isPlayerInRV(player)
    if not player then return false end
    local ok, px = PhobosLib.pcallMethod(player, "getX")
    local ok2, py = PhobosLib.pcallMethod(player, "getY")
    if not (ok and ok2) then return false end
    return px > RV_INTERIOR_X_THRESHOLD and py > RV_INTERIOR_Y_THRESHOLD
end


--- Get the proxy registration data from a vehicle's modData.
---@param vehicle any  BaseVehicle
---@return table|nil  {x, y, z, sprite} or nil if not registered
function PIP_RV.getProxyData(vehicle)
    if not vehicle then return nil end
    local md = PhobosLib.getModData(vehicle)
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
    local md = PhobosLib.getModData(vehicle)
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
    local md = PhobosLib.getModData(vehicle)
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

    if not PIP_RV.isZVVCompatible() then
        PIP_RV.clearProxy(vehicle)
        return false
    end

    local cell = getCell()
    if not cell then return false end

    local sq = cell:getGridSquare(proxyData.x, proxyData.y, proxyData.z)
    if not sq then
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
            local spriteName = getSpriteName(obj)
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


--- Find the nearest nearby vehicle (within radius) that has a registered proxy.
--- Deterministic: picks nearest by squared distance, tie-breaks on vehicle ID.
---@param player any     IsoPlayer
---@param radius number  Tile radius
---@return table|nil  {vehicle, proxyData} or nil
function PIP_RV.findNearbyProxiedVehicle(player, radius)
    if not player then return nil end
    local sq = PhobosLib.getSquareFromPlayer(player)
    if not sq then return nil end
    local ok, px = PhobosLib.pcallMethod(sq, "getX")
    local ok2, py = PhobosLib.pcallMethod(sq, "getY")
    if not (ok and ok2) then return nil end

    local vehicles = PhobosLib.findAllNearbyVehicles(player, radius)
    local best, bestDist, bestId = nil, math.huge, nil

    for _, v in ipairs(vehicles) do
        local proxyData = PIP_RV.getProxyData(v)
        if proxyData then
            local vok, vx = PhobosLib.pcallMethod(v, "getX")
            local vok2, vy = PhobosLib.pcallMethod(v, "getY")
            if vok and vok2 then
                local dist = (vx - px) ^ 2 + (vy - py) ^ 2
                local md = PhobosLib.getModData(v)
                local vid = md and tostring(md.projectRV_uniqueId or "") or ""
                if dist < bestDist or (dist == bestDist and vid < (bestId or "")) then
                    best = { vehicle = v, proxyData = proxyData }
                    bestDist = dist
                    bestId = vid
                end
            end
        end
    end
    return best
end


--- Fetch the actual table IsoThumpable objects (top + bottom) from stored
--- proxy coordinates. Uses ZVV's LabRecipes_GetBedObjects if available.
---@param proxyData table  {x, y, z, sprite}
---@return any, any, string|nil  top, bottom, status — or nil if not accessible
function PIP_RV.fetchTableObjects(proxyData)
    if not proxyData then return nil, nil, nil end
    if not PIP_RV.isZVVCompatible() then return nil, nil, nil end

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
            local spriteName = getSpriteName(obj)
            if spriteName and morgueTable[spriteName] then
                local top, bottom, status = LabRecipes_GetBedObjects(obj, morgueTable)
                return top, bottom, status
            end
        end
    end

    return nil, nil, nil
end
