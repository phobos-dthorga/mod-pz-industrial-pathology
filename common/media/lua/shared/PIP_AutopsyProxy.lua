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
-- PIP_AutopsyProxy.lua
-- Shared logic for proximity-based autopsy table detection.
-- Scans nearby squares for ZVV morgue table furniture and
-- provides table objects for PIP's context menu.
--
-- Depends on: PhobosLib, ZVV (morgueTable, LabRecipes_GetBedObjects)
---------------------------------------------------------------

require "PhobosLib"

PIP_Autopsy = PIP_Autopsy or {}

--- ZVV's corpse age limit for autopsy eligibility (hours).
--- Mirrors LabConst.AUTOPSY_MAX_HOURS. Update if ZVV changes this.
PIP_Autopsy.ZVV_AUTOPSY_MAX_HOURS = 12


---------------------------------------------------------------
-- ZVV compatibility gate
---------------------------------------------------------------

local zvvCompatChecked = false
local zvvCompatResult = false

--- Check if all required ZVV globals are available.
--- Caches result after first check. LabRecipes_CreateCorpseAutopsyTooltip
--- and LabRecipes_WMOnCorpseAutopsy are optional and not included in the gate.
---@return boolean
function PIP_Autopsy.isZVVCompatible()
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
-- Morgue table scanning
---------------------------------------------------------------

--- Scan a single square for a ZVV morgue table.
--- Returns {top, bottom, status} or nil.
---@param sq any  IsoGridSquare
---@return table|nil
local function scanSquareForMorgueTable(sq)
    local objs = sq:getObjects()
    if not objs then return nil end

    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if obj and instanceof(obj, "IsoThumpable") then
            local sprite = obj:getSprite()
            local spriteName = sprite and sprite.getName and sprite:getName() or nil
            if spriteName and morgueTable[spriteName] then
                local top, bottom, status = LabRecipes_GetBedObjects(obj, morgueTable)
                if top and bottom and status then
                    return { top = top, bottom = bottom, status = status }
                end
            end
        end
    end
    return nil
end


--- Find the nearest morgue table within radius of a square.
--- Returns the closest table of ANY status (Empty, Corpse, Remains, Dirty).
--- Uses PhobosLib.scanNearbySquares for iteration and ZVV's
--- LabRecipes_GetBedObjects for top/bottom piece resolution.
---@param originSquare any   IsoGridSquare to search around
---@param radius number      Search radius in tiles
---@return table|nil  {top, bottom, status, distSq} or nil if none found
function PIP_Autopsy.findNearbyMorgueTable(originSquare, radius)
    if not originSquare or not radius then return nil end
    if not PIP_Autopsy.isZVVCompatible() then return nil end

    local ok, cx = PhobosLib.pcallMethod(originSquare, "getX")
    local ok2, cy = PhobosLib.pcallMethod(originSquare, "getY")
    if not (ok and ok2) then return nil end

    local best = nil
    local bestDist = math.huge

    PhobosLib.scanNearbySquares(originSquare, radius, function(sq)
        local result = scanSquareForMorgueTable(sq)
        if result then
            local sok, sx = PhobosLib.pcallMethod(sq, "getX")
            local sok2, sy = PhobosLib.pcallMethod(sq, "getY")
            if sok and sok2 then
                local dist = (sx - cx) ^ 2 + (sy - cy) ^ 2
                if dist < bestDist then
                    best = { top = result.top, bottom = result.bottom, status = result.status, distSq = dist }
                    bestDist = dist
                end
            end
        end
        return false
    end)

    if best then
        PhobosLib.debug("PIP", "TableScan", "Found morgue table (status=" .. best.status
            .. ", dist=" .. string.format("%.0f", math.sqrt(best.distSq)) .. " tiles)")
    end

    return best
end


---------------------------------------------------------------
-- Remote table scanning (RV Bridge) — cache-first approach
---------------------------------------------------------------

require "PIP_RVBridge"

--- Find a morgue table inside an RV interior. Uses a cache-first
--- strategy: the OnTick scanner in PIP_RVBridge caches table
--- coordinates while the player is inside the RV. When outside,
--- the cached data is used (since the remote chunks are unloaded).
---
--- Falls back to live scanning if the chunk happens to be loaded.
---@param player any     IsoPlayer
---@param vehicleRadius number  How close player must be to the RV
---@return table|nil  {status, isRemote, remoteTopX, remoteTopY, remoteTopZ, rvData} or nil
---@return string|nil  reason code if failed: "no_zvv", "no_rv_mod", "no_rv_nearby", "no_table"
function PIP_Autopsy.findRemoteTableViaRV(player, vehicleRadius)
    if not PIP_Autopsy.isZVVCompatible() then return nil, "no_zvv" end
    if not PIP_RVBridge.isAvailable() then return nil, "no_rv_mod" end

    local rvData = PIP_RVBridge.findNearbyRVWithRoom(player, vehicleRadius)
    if not rvData then return nil, "no_rv_nearby" end

    -- Strategy 1: Check persistent cache (populated by OnTick scanner inside RV)
    local cached = PIP_RVBridge.getCachedTableLocation(player, rvData.vehicleId)
    if cached and cached.topX and cached.topY and cached.topZ then
        PhobosLib.debug("PIP", "RVTableScan", "Using cached table at "
            .. cached.topX .. "," .. cached.topY .. " status=" .. tostring(cached.status))
        return {
            status      = cached.status or "Empty",
            isRemote    = true,
            remoteTopX  = cached.topX,
            remoteTopY  = cached.topY,
            remoteTopZ  = cached.topZ,
            rvData      = rvData,
        }, nil
    end

    -- Strategy 2: Live scan (works if chunk is loaded, e.g. just exited RV)
    local roomSq = PIP_RVBridge.getRoomSquare(rvData.room)
    if roomSq then
        local scanRadius = 8
        local best = nil
        local bestDist = math.huge
        local roomX, roomY = rvData.room.x, rvData.room.y

        PhobosLib.scanNearbySquares(roomSq, scanRadius, function(sq)
            local result = scanSquareForMorgueTable(sq)
            if result then
                local sok, sx = PhobosLib.pcallMethod(sq, "getX")
                local sok2, sy = PhobosLib.pcallMethod(sq, "getY")
                if sok and sok2 then
                    local dist = (sx - roomX) ^ 2 + (sy - roomY) ^ 2
                    if dist < bestDist then
                        local topSq = result.top and result.top:getSquare()
                        local topX = topSq and topSq:getX()
                        local topY = topSq and topSq:getY()
                        local topZ = topSq and topSq:getZ()
                        if topX and topY and topZ then
                            best = {
                                status      = result.status,
                                isRemote    = true,
                                remoteTopX  = topX,
                                remoteTopY  = topY,
                                remoteTopZ  = topZ,
                                rvData      = rvData,
                            }
                            bestDist = dist
                        end
                    end
                end
            end
            return false
        end)

        if best then
            -- Cache for future use
            PIP_RVBridge.cacheTableLocation(player, rvData.vehicleId, {
                topX = best.remoteTopX, topY = best.remoteTopY, topZ = best.remoteTopZ,
                status = best.status,
            })
            PhobosLib.debug("PIP", "RVTableScan", "Live-scanned table in RV (status="
                .. best.status .. " at " .. best.remoteTopX .. "," .. best.remoteTopY .. ")")
            return best, nil
        end
    end

    -- Neither cache nor live scan found a table
    return nil, "no_table"
end
