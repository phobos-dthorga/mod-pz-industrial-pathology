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
-- PIP_RVBridge.lua
-- Shared logic for detecting RV Interior Expansion rooms,
-- resolving their world coordinates, and caching morgue table
-- locations for remote autopsy access.
--
-- Depends on: PhobosLib (isModActive, findNearbyVehicles,
--             getGridSquareAt, getModData, getPlayerModDataTable)
-- Soft dep:   PROJECTRVInterior42 / RVInteriorExpansion
---------------------------------------------------------------

require "PhobosLib"

PIP_RVBridge = PIP_RVBridge or {}

--- Mod IDs for the RV Interior ecosystem.
local RV_CORE_MOD_ID = "PROJECTRVInterior42"
local RV_MODDATA_KEY = "modPROJECTRVInterior"

--- Player modData key for cached morgue table locations.
PIP_RVBridge._CACHE_KEY = "PIP_RVMorgueTableCache"

--- Boundary check: RV interior coordinates are at x > 22500, y > 12000.
local RV_INTERIOR_MIN_X = 22500
local RV_INTERIOR_MIN_Y = 12000

--- Tick interval for interior scanning (~1 second at 60 ticks/sec).
local SCAN_INTERVAL_TICKS = 60

local _availableChecked = false
local _availableResult  = false
local _scanTicker = 0


---------------------------------------------------------------
-- Availability check
---------------------------------------------------------------

--- Check whether the PROJECT RV Interior core mod is active.
--- Result is cached after first call.
---@return boolean
function PIP_RVBridge.isAvailable()
    if _availableChecked then return _availableResult end
    _availableChecked = true
    _availableResult = PhobosLib.isModActive(RV_CORE_MOD_ID)
    if _availableResult then
        PhobosLib.debug("PIP", "RVBridge", "PROJECT RV Interior detected")
    end
    return _availableResult
end


---------------------------------------------------------------
-- Room lookup
---------------------------------------------------------------

--- Look up the assigned room for a vehicle from the RV mod's world ModData.
---@param vehicle any  BaseVehicle
---@return table|nil   {x, y, z} room coordinates, or nil
local function getAssignedRoom(vehicle)
    if not vehicle then return nil end

    local vmd = PhobosLib.getModData(vehicle)
    if not vmd then return nil end

    local vehicleId = vmd.projectRV_uniqueId
    if not vehicleId then return nil end
    vehicleId = tostring(vehicleId)

    local typeKey = vmd.projectRV_type or "normal"
    local assignedKey = (typeKey == "normal") and "AssignedRooms"
        or ("AssignedRooms" .. typeKey)

    local modData = ModData.getOrCreate(RV_MODDATA_KEY)
    if not modData or not modData[assignedKey] then return nil end

    local room = modData[assignedKey][vehicleId]
    if not room or not room.x or not room.y then return nil end

    return room
end


--- Find the nearest vehicle within radius that has an assigned RV interior room.
--- Returns vehicle, room coordinates, and vehicle ID.
---@param player any     IsoPlayer
---@param radius number  Search radius in tiles
---@return table|nil     {vehicle, room={x,y,z}, vehicleId, typeKey} or nil
function PIP_RVBridge.findNearbyRVWithRoom(player, radius)
    if not PIP_RVBridge.isAvailable() then return nil end
    if not player or not radius then return nil end

    local vehicles = PhobosLib.findNearbyVehicles(player, radius)

    for _, entry in ipairs(vehicles) do
        local v = entry.vehicle
        local vmd = PhobosLib.getModData(v)
        if vmd and vmd.projectRV_uniqueId then
            local room = getAssignedRoom(v)
            if room then
                PhobosLib.debug("PIP", "RVBridge",
                    "Found RV with room at " .. tostring(room.x) .. "," .. tostring(room.y))
                return {
                    vehicle   = v,
                    room      = room,
                    vehicleId = tostring(vmd.projectRV_uniqueId),
                    typeKey   = vmd.projectRV_type or "normal",
                }
            end
        end
    end

    return nil
end


--- Retrieve the IsoGridSquare for an RV room's coordinates.
--- Returns nil if the chunk is not loaded (player hasn't entered this session).
---@param room table  {x, y, z}
---@return any|nil     IsoGridSquare or nil
function PIP_RVBridge.getRoomSquare(room)
    if not room or not room.x or not room.y then return nil end
    return PhobosLib.getGridSquareAt(room.x, room.y, room.z or 0)
end


---------------------------------------------------------------
-- Morgue table cache (persisted in player modData)
---------------------------------------------------------------

--- Store a morgue table's location in the player's modData cache.
---@param player any       IsoPlayer
---@param vehicleId string RV vehicle unique ID
---@param tableData table  {topX, topY, topZ, status}
function PIP_RVBridge.cacheTableLocation(player, vehicleId, tableData)
    if not player or not vehicleId or not tableData then return end
    local cache = PhobosLib.getPlayerModDataTable(player, PIP_RVBridge._CACHE_KEY)
    if not cache then return end
    cache[vehicleId] = {
        topX   = tableData.topX,
        topY   = tableData.topY,
        topZ   = tableData.topZ,
        status = tableData.status,
    }
    PhobosLib.debug("PIP", "RVCache", "Cached table for vehicle " .. vehicleId
        .. " at " .. tostring(tableData.topX) .. "," .. tostring(tableData.topY)
        .. " status=" .. tostring(tableData.status))
end


--- Read a cached morgue table location for a specific vehicle.
---@param player any       IsoPlayer
---@param vehicleId string RV vehicle unique ID
---@return table|nil       {topX, topY, topZ, status} or nil
function PIP_RVBridge.getCachedTableLocation(player, vehicleId)
    if not player or not vehicleId then return nil end
    local cache = PhobosLib.getPlayerModDataTable(player, PIP_RVBridge._CACHE_KEY)
    if not cache then return nil end
    return cache[vehicleId]
end


--- Clear the cached morgue table entry for a vehicle (e.g. table removed).
---@param player any       IsoPlayer
---@param vehicleId string RV vehicle unique ID
function PIP_RVBridge.clearCacheForVehicle(player, vehicleId)
    if not player or not vehicleId then return end
    local cache = PhobosLib.getPlayerModDataTable(player, PIP_RVBridge._CACHE_KEY)
    if not cache then return end
    if cache[vehicleId] then
        cache[vehicleId] = nil
        PhobosLib.debug("PIP", "RVCache", "Cleared cache for vehicle " .. vehicleId)
    end
end


---------------------------------------------------------------
-- Interior scanner (runs while player is inside RV)
---------------------------------------------------------------

--- Resolve which vehicle the player is currently inside.
--- Reads from RV mod's Players table in world ModData.
---@param player any  IsoPlayer
---@return string|nil vehicleId
local function getCurrentRVVehicleId(player)
    local pmd = PhobosLib.getModData(player)
    if not pmd or not pmd.projectRV_playerId then return nil end

    local playerId = tostring(pmd.projectRV_playerId)
    local modData = ModData.getOrCreate(RV_MODDATA_KEY)
    if not modData or not modData.Players then return nil end

    local playerEntry = modData.Players[playerId]
    if not playerEntry or not playerEntry.VehicleId then return nil end
    return tostring(playerEntry.VehicleId)
end


--- Check if a player is currently inside an RV interior.
---@param player any  IsoPlayer
---@return boolean
local function isInsideRVInterior(player)
    if not player then return false end
    local ok, px = PhobosLib.pcallMethod(player, "getX")
    local ok2, py = PhobosLib.pcallMethod(player, "getY")
    if not (ok and ok2) then return false end
    return px > RV_INTERIOR_MIN_X and py > RV_INTERIOR_MIN_Y
end


--- OnTick handler: when inside RV, scan for morgue tables and update cache.
--- Uses PIP_Autopsy.findNearbyMorgueTable() which requires ZVV globals.
local function onTick()
    _scanTicker = _scanTicker + 1
    if _scanTicker < SCAN_INTERVAL_TICKS then return end
    _scanTicker = 0

    if not PIP_RVBridge.isAvailable() then return end

    local player = getSpecificPlayer(0)
    if not player then return end
    if not isInsideRVInterior(player) then return end

    -- Resolve which vehicle this player is in
    local vehicleId = getCurrentRVVehicleId(player)
    if not vehicleId then return end

    -- Need PIP_Autopsy to be loaded (it's a shared module, loaded before client)
    if not PIP_Autopsy or not PIP_Autopsy.findNearbyMorgueTable then return end

    local playerSq = player:getSquare()
    if not playerSq then return end

    -- Scan nearby (RV rooms are small, 8 tiles covers most layouts)
    local tableResult = PIP_Autopsy.findNearbyMorgueTable(playerSq, 8)

    if tableResult then
        -- Get the top piece's world coordinates
        local topSq = tableResult.top and tableResult.top:getSquare()
        if topSq then
            PIP_RVBridge.cacheTableLocation(player, vehicleId, {
                topX   = topSq:getX(),
                topY   = topSq:getY(),
                topZ   = topSq:getZ(),
                status = tableResult.status,
            })
        end
    else
        -- No table found — clear stale cache
        PIP_RVBridge.clearCacheForVehicle(player, vehicleId)
    end
end

Events.OnTick.Add(onTick)


---------------------------------------------------------------
-- Timed action helpers (shared by all PIP_TimedAction* modules)
---------------------------------------------------------------

--- Stop and clear the looping sound on a timed action.
--- ISBaseTimedAction does NOT provide this — each action must handle its own.
--- Call from both :stop() and :perform() methods.
---@param action table  The ISBaseTimedAction instance (must have .sound and .character)
function PIP_RVBridge.stopActionSound(action)
    if action.sound and action.character:getEmitter():isPlaying(action.sound) then
        action.character:getEmitter():stopSound(action.sound)
        action.sound = nil
    end
end

--- Optimistic cache update for timed action completion.
--- Updates the cached table status without waiting for a server round-trip.
---@param character any            IsoPlayer
---@param remoteTableData table    From PIP_Autopsy.findRemoteTableViaRV()
---@param newStatus string         New status (use PIP_Constants.TABLE_*)
function PIP_RVBridge.optimisticCacheUpdate(character, remoteTableData, newStatus)
    local rd = remoteTableData
    if rd and rd.rvData and rd.rvData.vehicleId then
        PIP_RVBridge.cacheTableLocation(character, rd.rvData.vehicleId, {
            topX   = rd.remoteTopX,
            topY   = rd.remoteTopY,
            topZ   = rd.remoteTopZ,
            status = newStatus,
        })
    end
end
