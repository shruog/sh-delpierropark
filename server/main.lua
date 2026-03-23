--[[
    LunaPark Server - Event relay & synchronization
    The "host" (lowest server-id player) is authoritative for physics.
    All other events are relayed to every client.
]]

local function GetHostPlayer()
    local players = GetPlayers()
    if #players == 0 then return nil end
    table.sort(players, function(a, b) return tonumber(a) < tonumber(b) end)
    return players[1]
end

local function IsHost(source)
    return tostring(source) == tostring(GetHostPlayer())
end

-- ============================================================
-- FERRIS WHEEL EVENTS
-- ============================================================

RegisterNetEvent("FerrisWheel:SyncState")
AddEventHandler("FerrisWheel:SyncState", function(state)
    local src = source
    if IsHost(src) then
        TriggerClientEvent("FerrisWheel:ForceState", -1, state)
    end
end)

RegisterNetEvent("FerrisWheel:StopWheel")
AddEventHandler("FerrisWheel:StopWheel", function(stopped)
    TriggerClientEvent("FerrisWheel:StopWheel", -1, stopped)
end)

RegisterNetEvent("FerrisWheel:UpdateCabins")
AddEventHandler("FerrisWheel:UpdateCabins", function(cabinIndex, playerCount)
    TriggerClientEvent("FerrisWheel:UpdateCabins", -1, cabinIndex, playerCount)
end)

RegisterNetEvent("FerrisWheel:PlayerGetOn")
AddEventHandler("FerrisWheel:PlayerGetOn", function(playerNetId, cabinIndex)
    TriggerClientEvent("FerrisWheel:PlayerGetOn", -1, playerNetId, cabinIndex)
end)

RegisterNetEvent("FerrisWheel:PlayerGetOff")
AddEventHandler("FerrisWheel:PlayerGetOff", function(playerNetId, cabinIndex)
    TriggerClientEvent("FerrisWheel:PlayerGetOff", -1, playerNetId, cabinIndex)
end)

RegisterNetEvent("FerrisWheel:UpdateGradient")
AddEventHandler("FerrisWheel:UpdateGradient", function(gradient)
    local src = source
    if IsHost(src) then
        TriggerClientEvent("FerrisWheel:UpdateGradient", -1, gradient)
    end
end)

-- ============================================================
-- ROLLER COASTER EVENTS
-- ============================================================

RegisterNetEvent("RollerCoaster:SyncState")
AddEventHandler("RollerCoaster:SyncState", function(state)
    local src = source
    if IsHost(src) then
        TriggerClientEvent("RollerCoaster:ForceState", -1, state)
    end
end)

RegisterNetEvent("RollerCoaster:PlayerGetOn")
AddEventHandler("RollerCoaster:PlayerGetOn", function(playerNetId, carIndex)
    TriggerClientEvent("RollerCoaster:PlayerGetOn", -1, playerNetId, carIndex)
end)

RegisterNetEvent("RollerCoaster:PlayerGetOff")
AddEventHandler("RollerCoaster:PlayerGetOff", function(playerNetId)
    TriggerClientEvent("RollerCoaster:PlayerGetOff", -1, playerNetId)
end)

RegisterNetEvent("RollerCoaster:SyncCars")
AddEventHandler("RollerCoaster:SyncCars", function(carIndex, occupied)
    TriggerClientEvent("RollerCoaster:SyncCars", -1, carIndex, occupied)
end)

print("[LunaPark] Server loaded successfully.")
