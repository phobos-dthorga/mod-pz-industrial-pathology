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
-- Shared logic for detecting RV Interior Expansion rooms and
-- resolving their world coordinates for remote table access.
--
-- Depends on: PhobosLib (isModActive, findNearbyVehicles,
--             getGridSquareAt, getModData)
-- Soft dep:   PROJECTRVInterior42 / RVInteriorExpansion
---------------------------------------------------------------

require "PhobosLib"

PIP_RVBridge = PIP_RVBridge or {}

--- Mod IDs for the RV Interior ecosystem.
local RV_CORE_MOD_ID = "PROJECTRVInterior42"
local RV_MODDATA_KEY = "modPROJECTRVInterior"

local _availableChecked = false
local _availableResult  = false


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
