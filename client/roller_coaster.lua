--[[
     Client - Roller Coaster
    Sound management: tracked IDs, one-shot flags, proper stop/release.
    Performance: distance-throttled ticks, no per-frame redundant calls.
]]

-- ============================================================
-- CLASSES
-- ============================================================

RollerCoasterData = Class()
function RollerCoasterData:init()
    self.speed       = 0.0
    self.varSpeed    = 0.0
    self.waypointIdx = 0
    self.state       = "WAITING"
    self.cars        = {}
    self.waypoints   = {}
    self.distances   = {}
    self.speedMap    = {}
    self.enabled     = false
end

RollerCarData = Class()
function RollerCarData:init()
    self.entity   = 0
    self.occupied = 0
end

-- ============================================================
-- MODULE
-- ============================================================

RollerCoaster = {}

local Roller         = RollerCoasterData:new()
local CurrentSeat    = "one"
local BoardingCoord  = vector3(0, 0, 0)
local IsActive       = false
local ImSitting      = false
local Timer          = Config.RollerCoaster.WaitTime
local PrevTimeRC     = 0
local DeltaTimeRC    = 0.0
local CurrentNodeIdx = 0
local ScaleformRC    = false
local ScaleformRCH   = 0

local ANIM = Config.RollerCoaster.AnimDict

-- ============================================================
-- SOUND STATE — prevents per-frame calls and tracks IDs
-- ============================================================

local RCSounds = {
    barLock     = -1,   -- Bar_Lower_And_Lock
    barUnlock   = -1,   -- Bar_Unlock_And_Raise
    rideStop    = -1,   -- Ride_Stop
}

local RCAudioFlags = {
    streamStarted  = false,  -- PlayStreamFromPed/Object called once
    sceneStarted   = false,  -- StartAudioScene LEVIATHAN called once
    streamLoaded   = false,  -- LoadStreamWithStartOffset called once
}

-- ============================================================
-- SOUND MANAGEMENT
-- ============================================================

--- Play a tracked one-shot sound from an entity.
function RollerCoaster.PlayTrackedSound(key, soundName, entity)
    -- Stop previous instance if still playing
    if RCSounds[key] ~= -1 then
        StopSound(RCSounds[key])
        ReleaseSoundId(RCSounds[key])
    end
    RCSounds[key] = GetSoundId()
    PlaySoundFromEntity(RCSounds[key], soundName, entity, "DLC_IND_ROLLERCOASTER_SOUNDS", false, 0)
end

--- Stop and release all tracked roller coaster sounds.
function RollerCoaster.StopAllSounds()
    for key, id in pairs(RCSounds) do
        if id ~= -1 then
            StopSound(id)
            ReleaseSoundId(id)
            RCSounds[key] = -1
        end
    end
end

--- Stop streams and audio scenes, reset all flags.
function RollerCoaster.StopAllAudio()
    RollerCoaster.StopAllSounds()

    StopStream()

    if IsAudioSceneActive("FAIRGROUND_RIDES_LEVIATHAN") then
        StopAudioScene("FAIRGROUND_RIDES_LEVIATHAN")
    end

    RCAudioFlags.streamStarted = false
    RCAudioFlags.sceneStarted  = false
    RCAudioFlags.streamLoaded  = false
end

-- ============================================================
-- INIT
-- ============================================================

function RollerCoaster.Init()
    RollerCoaster.BuildTrack()

    for i = 0, Config.RollerCoaster.CarCount - 1 do
        Roller.cars[i] = RollerCarData:new()
    end

    local bcfg = Config.RollerCoaster.Blip
    local blip = AddBlipForCoord(bcfg.Position.x, bcfg.Position.y, bcfg.Position.z)
    SetBlipSprite(blip, bcfg.Sprite)
    SetBlipAsShortRange(blip, bcfg.ShortRange)
    SetBlipDisplay(blip, bcfg.Display)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(bcfg.Name)
    EndTextCommandSetBlipName(blip)

    RegisterNetEvent("RollerCoaster:ForceState")
    AddEventHandler("RollerCoaster:ForceState", function(state) Roller.state = state end)

    RegisterNetEvent("RollerCoaster:PlayerGetOn")
    AddEventHandler("RollerCoaster:PlayerGetOn", function(netId, carIdx)
        RollerCoaster.HandlePlayerGetOn(netId, carIdx)
    end)

    RegisterNetEvent("RollerCoaster:PlayerGetOff")
    AddEventHandler("RollerCoaster:PlayerGetOff", function(netId)
        RollerCoaster.HandlePlayerGetOff(netId)
    end)

    RegisterNetEvent("RollerCoaster:SyncCars")
    AddEventHandler("RollerCoaster:SyncCars", function(carIdx, occ)
        if Roller.cars[carIdx] then Roller.cars[carIdx].occupied = occ end
    end)

    RollerCoaster.LoadAssets()
end

-- ============================================================
-- ASSET LOADING
-- ============================================================

function RollerCoaster.LoadAssets()
    local cfg = Config.RollerCoaster

    RequestModel(cfg.CarModel)
    while not HasModelLoaded(cfg.CarModel) do Wait(100) end
    RequestModel(cfg.CarModel2)
    while not HasModelLoaded(cfg.CarModel2) do Wait(100) end
    RequestAnimDict(ANIM)
    while not HasAnimDictLoaded(ANIM) do Wait(100) end
    LoadStream("LEVIATHON_RIDE_MASTER", "")

    RollerCoaster.SpawnCars()
    RollerCoaster.RegisterOwnCars()

    Citizen.CreateThread(RollerCoaster.TickMovement)
    Citizen.CreateThread(RollerCoaster.TickPlayerControl)
    Citizen.CreateThread(RollerCoaster.TickDeleteVanillaCars)
end

-- ============================================================
-- SPAWN CARS
-- ============================================================

function RollerCoaster.SpawnCars()
    local wp = Roller.waypoints

    for i = 0, Config.RollerCoaster.CarCount - 1 do
        local spd = Roller.speed - (2.55 * i)
        local nodeIdx = RollerCoaster.FindNode(spd, CurrentNodeIdx)
        local pos = RollerCoaster.Interpolate(spd, nodeIdx)

        if i == 0 then
            Roller.cars[0].entity = CreateObject(Config.RollerCoaster.CarModel,
                wp[1].x, wp[1].y, wp[1].z, false, false, false)
        else
            Roller.cars[i].entity = CreateObject(Config.RollerCoaster.CarModel2,
                pos.x, pos.y, pos.z, false, false, false)
            RollerCoaster.SetCarRotation(i, nodeIdx, spd)
        end

        FreezeEntityPosition(Roller.cars[i].entity, true)
        SetEntityLodDist(Roller.cars[i].entity, 300)
        SetEntityInvincible(Roller.cars[i].entity, true)
    end

    Roller.speed = Roller.distances[1] or 0.0
    RollerCoaster.UpdatePhysics(false)

    for i = 0, Config.RollerCoaster.CarCount - 1 do
        if DoesEntityExist(Roller.cars[i].entity) then
            PlayEntityAnim(Roller.cars[i].entity, "idle_a_roller_car", ANIM, 8.0, true, false, false, 0.0, 0)
        end
    end

    PrevTimeRC = 0
    RollerCoaster.UpdateCarPositions()
end

-- ============================================================
-- DELETE VANILLA YELLOW CARTS
-- ============================================================

local OWN_CAR_HANDLES = {}

function RollerCoaster.RegisterOwnCars()
    OWN_CAR_HANDLES = {}
    for i = 0, Config.RollerCoaster.CarCount - 1 do
        if Roller.cars[i] and Roller.cars[i].entity ~= 0 then
            OWN_CAR_HANDLES[Roller.cars[i].entity] = true
        end
    end
end

function RollerCoaster.IsOwnCar(entity)
    return OWN_CAR_HANDLES[entity] == true
end

function RollerCoaster.DeleteAllOfModel(modelName, radius)
    local center = Config.RollerCoaster.ProximityCenter
    local modelHash = GetHashKey(modelName)
    local deleted = 0

    for _ = 1, 50 do
        local obj = GetClosestObjectOfType(center.x, center.y, center.z, radius, modelHash, false, false, false)
        if obj == 0 or not DoesEntityExist(obj) then break end
        if RollerCoaster.IsOwnCar(obj) then break end

        SetEntityAsMissionEntity(obj, true, true)
        DeleteObject(obj)
        deleted = deleted + 1
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    return deleted
end

function RollerCoaster.TickDeleteVanillaCars()
    Wait(2000)
    RollerCoaster.RegisterOwnCars()
    while true do
        Wait(1000)
        for _, modelName in ipairs(Config.RollerCoaster.DeleteModels) do
            RollerCoaster.DeleteAllOfModel(modelName, 500.0)
        end
    end
end

-- ============================================================
-- MOVEMENT TICK — sound-safe, no per-frame redundant calls
-- ============================================================

function RollerCoaster.TickMovement()
    while true do
        Wait(0)

        if Roller.state == "WAITING" then
            -- Reset audio from previous ride
            RollerCoaster.StopAllAudio()

            local localTimer = Timer
            while localTimer > 0 do
                Wait(1000)
                localTimer = localTimer - 1
                if Roller.state ~= "WAITING" then break end
            end
            if Roller.state == "WAITING" then
                Wait(6000)
                TriggerServerEvent("RollerCoaster:SyncState", "DEPARTING")
            end

        elseif Roller.state == "DEPARTING" then
            if not IsActive then
                for i = 0, Config.RollerCoaster.CarCount - 1 do
                    if DoesEntityExist(Roller.cars[i].entity) then
                        PlayEntityAnim(Roller.cars[i].entity, "safety_bar_enter_roller_car", ANIM, 8.0, false, true, false, 0.0, 0)
                    end
                end

                -- Tracked sound: bar lock (plays once, can be stopped)
                if Roller.cars[1] and DoesEntityExist(Roller.cars[1].entity) then
                    RollerCoaster.PlayTrackedSound("barLock", "Bar_Lower_And_Lock", Roller.cars[1].entity)
                end

                if ImSitting then
                    TaskPlayAnim(PlayerPedId(), ANIM, "safety_bar_enter_player_" .. CurrentSeat, 8.0, -8.0, -1, 2, 0, false, false, false)
                    while GetEntityAnimCurrentTime(PlayerPedId(), ANIM, "safety_bar_enter_player_" .. CurrentSeat) < 0.2 do
                        Wait(0)
                    end
                else
                    Wait(5000)
                end

                TriggerServerEvent("RollerCoaster:SyncState", "TRIP")
                IsActive = true
            end

        elseif Roller.state == "TRIP" then
            if CurrentNodeIdx ~= 0 then
                RollerCoaster.UpdatePhysics(true)

                if ImSitting then
                    RollerCoaster.RenderRCButtons()

                    -- Start audio scene ONCE (not every frame!)
                    if not RCAudioFlags.sceneStarted then
                        StartAudioScene("FAIRGROUND_RIDES_LEVIATHAN")
                        RCAudioFlags.sceneStarted = true
                    end

                    -- Start stream ONCE (not every frame!)
                    if not RCAudioFlags.streamStarted then
                        PlayStreamFromPed(PlayerPedId())
                        RCAudioFlags.streamStarted = true
                    end

                    -- Default grip anim
                    if not IsEntityPlayingAnim(PlayerPedId(), ANIM, "safety_bar_grip_move_a_player_" .. CurrentSeat, 3)
                        and not IsEntityPlayingAnim(PlayerPedId(), ANIM, "hands_up_idle_a_player_" .. CurrentSeat, 3)
                        and not IsEntityPlayingAnim(PlayerPedId(), ANIM, "hands_up_exit_player_" .. CurrentSeat, 3) then
                        TaskPlayAnim(PlayerPedId(), ANIM, "safety_bar_grip_move_a_player_" .. CurrentSeat, 8.0, -1.0, -1, 1, 0, false, false, false)
                    end

                    -- Arms up toggle
                    if IsControlJustPressed(2, 203) then
                        if not IsEntityPlayingAnim(PlayerPedId(), ANIM, "hands_up_idle_a_player_" .. CurrentSeat, 3) then
                            TaskPlayAnim(PlayerPedId(), ANIM, "hands_up_enter_player_" .. CurrentSeat, 8.0, -1.0, -1, 2, 0, false, false, false)
                            while IsEntityPlayingAnim(PlayerPedId(), ANIM, "hands_up_enter_player_" .. CurrentSeat, 3) do Wait(0) end
                            TaskPlayAnim(PlayerPedId(), ANIM, "hands_up_idle_a_player_" .. CurrentSeat, 8.0, -1.0, -1, 1, 0, false, false, false)
                        else
                            TaskPlayAnim(PlayerPedId(), ANIM, "hands_up_exit_player_" .. CurrentSeat, 8.0, -1.0, -1, 2, 0, false, false, false)
                            while IsEntityPlayingAnim(PlayerPedId(), ANIM, "hands_up_exit_player_" .. CurrentSeat, 3) do Wait(0) end
                            TaskPlayAnim(PlayerPedId(), ANIM, "safety_bar_grip_move_a_player_" .. CurrentSeat, 8.0, -1.0, -1, 1, 0, false, false, false)
                        end
                    end
                else
                    -- Not sitting: play ambient stream ONCE
                    if not RCAudioFlags.streamStarted then
                        if Roller.cars[2] and DoesEntityExist(Roller.cars[2].entity) then
                            PlayStreamFromObject(Roller.cars[2].entity)
                            RCAudioFlags.streamStarted = true
                        end
                    end
                end
            else
                TriggerServerEvent("RollerCoaster:SyncState", "ARRIVAL")
            end

        elseif Roller.state == "ARRIVAL" then
            -- Tracked sound: ride stop (once, not every frame)
            if Roller.cars[1] and DoesEntityExist(Roller.cars[1].entity) then
                RollerCoaster.PlayTrackedSound("rideStop", "Ride_Stop", Roller.cars[1].entity)
            end

            if ImSitting and IsEntityPlayingAnim(PlayerPedId(), ANIM, "hands_up_idle_a_player_" .. CurrentSeat, 3) then
                TaskPlayAnim(PlayerPedId(), ANIM, "hands_up_exit_player_" .. CurrentSeat, 8.0, -1.0, -1, 2, 0, false, false, false)
                while GetEntityAnimCurrentTime(PlayerPedId(), ANIM, "hands_up_exit_player_" .. CurrentSeat) < 0.99 do Wait(0) end
                TaskPlayAnim(PlayerPedId(), ANIM, "safety_bar_grip_move_a_player_" .. CurrentSeat, 8.0, -1.0, -1, 1, 0, false, false, false)
            end
            TriggerServerEvent("RollerCoaster:SyncState", "STOP")

        elseif Roller.state == "STOP" then
            if Roller.varSpeed > 1 then
                RollerCoaster.UpdatePhysics(true)
                -- Stream already started in TRIP, no need to call again
            else
                if IsActive then
                    Wait(1000)

                    -- Stop streams/scenes before exit sounds
                    RollerCoaster.StopAllAudio()

                    -- Safety bar exit anim
                    for i = 0, Config.RollerCoaster.CarCount - 1 do
                        if DoesEntityExist(Roller.cars[i].entity) then
                            PlayEntityAnim(Roller.cars[i].entity, "safety_bar_exit_roller_car", ANIM, 8.0, false, true, false, 0.0, 0)
                        end
                    end

                    -- Tracked sound: bar unlock
                    if Roller.cars[1] and DoesEntityExist(Roller.cars[1].entity) then
                        RollerCoaster.PlayTrackedSound("barUnlock", "Bar_Unlock_And_Raise", Roller.cars[1].entity)
                    end

                    if ImSitting then
                        TriggerServerEvent("RollerCoaster:PlayerGetOff", NetworkGetNetworkIdFromEntity(PlayerPedId()))
                    end

                    for i = 0, Config.RollerCoaster.CarCount - 1 do
                        Roller.cars[i].occupied = 0
                        TriggerServerEvent("RollerCoaster:SyncCars", i, 0)
                    end

                    Wait(1000)
                    PrevTimeRC = 0
                    DeltaTimeRC = 0.0
                    ScaleformRC = false
                    Timer = Config.RollerCoaster.WaitTime
                    TriggerServerEvent("RollerCoaster:SyncState", "WAITING")
                    IsActive = false
                end
            end
        end
    end
end

-- ============================================================
-- PLAYER CONTROL TICK — distance-throttled, one-shot stream load
-- ============================================================

function RollerCoaster.TickPlayerControl()
    while true do
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local cfg = Config.RollerCoaster
        local dist = #(pos - cfg.ProximityCenter)

        -- Distance throttle
        if dist > cfg.ProximityRadius * 5 then
            Wait(2000)
        elseif dist > cfg.ProximityRadius then
            Wait(500)
        else
            Wait(0)
        end

        -- Boarding check (only when close)
        if dist < cfg.ProximityRadius then
            for idx, bpos in ipairs(cfg.BoardingPositions) do
                if #(pos - bpos) < cfg.BoardingRadius and Roller.state == "WAITING" and Timer > 0 then
                    RollerCoaster.ShowHelpText("Press ~INPUT_CONTEXT~ to ride the Roller Coaster")
                    if IsControlJustPressed(2, 51) then
                        local carIdx = math.floor((idx - 1) / 2)
                        local fVar2 = 0.0
                        if (idx - 1) % 2 == 0 then fVar2 = -1.017 end

                        if Roller.cars[carIdx] and DoesEntityExist(Roller.cars[carIdx].entity) then
                            BoardingCoord = GetOffsetFromEntityInWorldCoords(Roller.cars[carIdx].entity, 0.0, fVar2, 0.0)
                            TriggerServerEvent("RollerCoaster:PlayerGetOn",
                                NetworkGetNetworkIdFromEntity(ped), carIdx)
                        end
                    end
                    break
                end
            end

            -- Stream loading: ONCE, not every frame
            if not RCAudioFlags.streamLoaded then
                if ImSitting then
                    LoadStreamWithStartOffset("Player_Ride", 0, "DLC_IND_ROLLERCOASTER_SOUNDS")
                else
                    LoadStreamWithStartOffset("Ambient_Ride", 1, "DLC_IND_ROLLERCOASTER_SOUNDS")
                end
                RCAudioFlags.streamLoaded = true
            end

            Roller.enabled = (Roller.state == "WAITING" and Timer > 0)
        else
            Roller.enabled = false
            -- Reset stream loaded flag when leaving area so it reloads on return
            RCAudioFlags.streamLoaded = false
        end
    end
end

-- ============================================================
-- PLAYER GET ON
-- ============================================================

function RollerCoaster.HandlePlayerGetOn(netId, carIdx)
    Citizen.CreateThread(function()
        local ped = NetworkGetEntityFromNetworkId(netId)
        if not DoesEntityExist(ped) then return end

        if ped ~= PlayerPedId() then
            if not NetworkHasControlOfNetworkId(netId) then
                local t = 0
                while not NetworkRequestControlOfNetworkId(netId) and t < 100 do Wait(0); t = t + 1 end
            end
        end

        local car = Roller.cars[carIdx]
        if not car then return end
        local carEntity = car.entity
        if not DoesEntityExist(carEntity) then return end

        local seat
        if car.occupied == 0 then
            seat = "one"; car.occupied = 1
        elseif car.occupied == 1 then
            seat = "two"; car.occupied = 2
        else
            RollerCoaster.ShowNotification("This car is full!")
            return
        end

        if ped == PlayerPedId() then CurrentSeat = seat end

        TaskGoStraightToCoord(ped, BoardingCoord.x, BoardingCoord.y, BoardingCoord.z, 1.0, -1, 229.3511, 0.2)
        Wait(1000)

        local scene = NetworkCreateSynchronisedScene(BoardingCoord.x, BoardingCoord.y, BoardingCoord.z,
            0.0, 0.0, 139.96, 2, true, false, 1065353216, 0, 1065353216)
        NetworkAddPedToSynchronisedScene(ped, scene, ANIM, "enter_player_" .. seat, 8.0, -8.0, 131072, 0, 1148846080, 0)
        NetworkStartSynchronisedScene(scene)
        Wait(5000)

        local pedPos = GetEntityCoords(ped)
        local attOffset = GetOffsetFromEntityGivenWorldCoords(carEntity, pedPos.x, pedPos.y, pedPos.z)
        AttachEntityToEntity(ped, carEntity, 0,
            attOffset.x, attOffset.y, attOffset.z,
            0.0, 0.0, GetEntityHeading(ped) - 139.96,
            false, false, false, false, 2, true)

        if ped == PlayerPedId() then ImSitting = true end

        TriggerServerEvent("RollerCoaster:SyncCars", carIdx, car.occupied)
    end)
end

-- ============================================================
-- PLAYER GET OFF
-- ============================================================

function RollerCoaster.HandlePlayerGetOff(netId)
    Citizen.CreateThread(function()
        local ped = NetworkGetEntityFromNetworkId(netId)
        if not DoesEntityExist(ped) then return end

        if ped ~= PlayerPedId() then
            if not NetworkHasControlOfNetworkId(netId) then
                local t = 0
                while not NetworkRequestControlOfNetworkId(netId) and t < 100 do Wait(0); t = t + 1 end
            end
        end

        if IsEntityAttached(ped) then DetachEntity(ped, true, true) end

        if ped == PlayerPedId() then
            ImSitting = false
            -- Stop all roller coaster audio on exit
            RollerCoaster.StopAllAudio()
        end

        local scene1 = NetworkCreateSynchronisedScene(BoardingCoord.x, BoardingCoord.y, BoardingCoord.z,
            0.0, 0.0, 139.96, 2, true, false, 1065353216, 0, 1065353216)
        NetworkAddPedToSynchronisedScene(ped, scene1, ANIM, "safety_bar_exit_player_" .. CurrentSeat, 8.0, -8.0, 131072, 0, 1148846080, 0)
        NetworkStartSynchronisedScene(scene1)
        Wait(3000)

        local scene2 = NetworkCreateSynchronisedScene(BoardingCoord.x, BoardingCoord.y, BoardingCoord.z,
            0.0, 0.0, 139.96, 2, true, false, 1065353216, 0, 1065353216)
        NetworkAddPedToSynchronisedScene(ped, scene2, ANIM, "exit_player_" .. CurrentSeat, 8.0, -8.0, 131072, 0, 1148846080, 0)
        NetworkStartSynchronisedScene(scene2)
        Wait(7000)

        ClearPedTasks(ped)
    end)
end

-- ============================================================
-- UI
-- ============================================================

function RollerCoaster.ShowHelpText(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

function RollerCoaster.ShowNotification(text)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, false)
end

function RollerCoaster.RenderRCButtons()
    if not ScaleformRC then
        ScaleformRCH = RequestScaleformMovie("instructional_buttons")
        while not HasScaleformMovieLoaded(ScaleformRCH) do Wait(0) end
        PushScaleformMovieFunction(ScaleformRCH, "CLEAR_ALL")
        PopScaleformMovieFunctionVoid()
        PushScaleformMovieFunction(ScaleformRCH, "TOGGLE_MOUSE_BUTTONS")
        PushScaleformMovieFunctionParameterBool(false)
        PopScaleformMovieFunctionVoid()
        PushScaleformMovieFunction(ScaleformRCH, "SET_DATA_SLOT")
        PushScaleformMovieFunctionParameterInt(0)
        PushScaleformMovieFunctionParameterString(GetControlInstructionalButton(2, 203, 1))
        PushScaleformMovieFunctionParameterString("Raise/Lower Arms")
        PopScaleformMovieFunctionVoid()
        PushScaleformMovieFunction(ScaleformRCH, "DRAW_INSTRUCTIONAL_BUTTONS")
        PushScaleformMovieFunctionParameterInt(-1)
        PopScaleformMovieFunctionVoid()
        ScaleformRC = true
    end
    if ScaleformRC then
        DrawScaleformMovieFullscreen(ScaleformRCH, 255, 255, 255, 255, 0)
    end
end

-- ============================================================
-- CLEANUP
-- ============================================================

AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    RollerCoaster.StopAllAudio()
    for i = 0, Config.RollerCoaster.CarCount - 1 do
        if Roller.cars[i] and DoesEntityExist(Roller.cars[i].entity) then
            DeleteEntity(Roller.cars[i].entity)
        end
    end
end)

-- ============================================================
-- PHYSICS / MOVEMENT CORE
-- ============================================================

function RollerCoaster.UpdatePhysics(useDelta)
    if useDelta then
        if PrevTimeRC ~= 0 then
            DeltaTimeRC = GetTimeDifference(GetNetworkTimeAccurate(), PrevTimeRC) / 1000.0
        end
        PrevTimeRC = GetNetworkTimeAccurate()
    end

    -- Gravity simulation
    local gravity = RollerCoaster.CalculateGravity()

    if CurrentNodeIdx < 20 then
        -- Initial acceleration
        if Roller.varSpeed < 3.0 then
            Roller.varSpeed = Roller.varSpeed + 0.3
        else
            Roller.varSpeed = Roller.varSpeed - 0.3
        end
        if math.abs(Roller.varSpeed - 3.0) < 0.3 then
            Roller.varSpeed = 3.0
        end
    else
        Roller.varSpeed = Roller.varSpeed + (gravity * DeltaTimeRC)
    end

    -- Advance position
    local lastIdx = Roller.waypointIdx - 1
    if lastIdx < 1 then lastIdx = #Roller.distances end

    if Roller.speed < (Roller.distances[1] or 0.0)
        and (Roller.speed + (Roller.varSpeed * DeltaTimeRC)) >= (Roller.distances[1] or 0.0) then
        Roller.speed = Roller.distances[1] or 0.0
    else
        Roller.speed = Roller.speed + (Roller.varSpeed * DeltaTimeRC)
    end

    -- Wrap around
    if Roller.varSpeed >= 0 then
        if Roller.speed >= (Roller.distances[lastIdx] or 0.0) then
            if Roller.state ~= "ARRIVAL" then
                Roller.speed = Roller.speed - (Roller.distances[lastIdx] or 0.0)
            else
                Roller.speed = Roller.distances[1] or 0.0
            end
            CurrentNodeIdx = 0
        end

        -- Find current segment
        local nextIdx = RollerCoaster.WrapNext(CurrentNodeIdx)
        local found = false
        local safety = 0
        while not found and safety < 300 do
            safety = safety + 1
            if Roller.distances[nextIdx] and Roller.speed < Roller.distances[nextIdx] then
                found = true
                if CurrentNodeIdx ~= (nextIdx - 1) then
                    if Roller.speedMap[nextIdx - 1] and Roller.speedMap[nextIdx - 1] ~= Roller.varSpeed then
                        Roller.varSpeed = Roller.speedMap[nextIdx - 1]
                    end
                end
                CurrentNodeIdx = nextIdx - 1
            end
            nextIdx = RollerCoaster.WrapNext(nextIdx)
        end
    else
        if Roller.speed < 0 then
            Roller.speed = Roller.speed + (Roller.distances[lastIdx] or 0.0)
            CurrentNodeIdx = lastIdx - 1
        end

        local idx = CurrentNodeIdx
        local found = false
        local safety = 0
        while not found and safety < 300 do
            safety = safety + 1
            if Roller.distances[idx] and Roller.distances[idx] < Roller.speed then
                found = true
                CurrentNodeIdx = idx
            end
            idx = RollerCoaster.WrapPrev(idx)
        end
    end

    RollerCoaster.UpdateCarPositions()
end

function RollerCoaster.CalculateGravity()
    local nextIdx = RollerCoaster.WrapNext(CurrentNodeIdx)
    local wp = Roller.waypoints

    if not wp[CurrentNodeIdx] or not wp[nextIdx] then return 0.0 end

    local heightDiff = wp[CurrentNodeIdx].z - wp[nextIdx].z
    local distDiff = (Roller.distances[nextIdx] or 0.0) - (Roller.distances[CurrentNodeIdx] or 0.0)
    if distDiff < 0 then
        distDiff = distDiff + (Roller.distances[#Roller.distances] or 0.0)
    end

    if distDiff == 0 then return 0.0 end

    local angle = Config.ConvertRadiansToDegrees(math.asin(Config.ConvertDegreesToRadians(heightDiff / distDiff)))
    return 10.0 * Config.ConvertRadiansToDegrees(math.sin(Config.ConvertDegreesToRadians(angle)))
end

function RollerCoaster.WrapNext(idx)
    local nxt = idx + 1
    if nxt >= Roller.waypointIdx then nxt = 1 end
    return nxt
end

function RollerCoaster.WrapPrev(idx)
    local prev = idx - 1
    if prev < 0 then prev = Roller.waypointIdx - 2 end
    return prev
end

-- ============================================================
-- INTERPOLATION & CAR PLACEMENT
-- ============================================================

function RollerCoaster.UpdateCarPositions()
    for i = 0, Config.RollerCoaster.CarCount - 1 do
        local spd = Roller.speed - (2.55 * i)
        local nodeIdx = RollerCoaster.FindNode(spd, CurrentNodeIdx)
        local pos = RollerCoaster.Interpolate(spd, nodeIdx)
        if DoesEntityExist(Roller.cars[i].entity) then
            SetEntityCoordsNoOffset(Roller.cars[i].entity, pos.x, pos.y, pos.z, true, false, false)
            RollerCoaster.SetCarRotation(i, nodeIdx, spd)
        end
    end
end

function RollerCoaster.FindNode(spd, startIdx)
    if spd <= 0 then
        spd = spd + (Roller.distances[Roller.waypointIdx - 1] or 0.0)
        startIdx = Roller.waypointIdx - 1
    end
    local idx = startIdx
    while idx >= 0 do
        if Roller.distances[idx] and Roller.distances[idx] < spd then
            return idx
        end
        idx = idx - 1
    end
    return 0
end

function RollerCoaster.Interpolate(spd, nodeIdx)
    local wp = Roller.waypoints
    if spd < 0 then
        spd = spd + (Roller.distances[Roller.waypointIdx - 1] or 0.0)
    end

    local idx1, idx2
    if Roller.varSpeed >= 0 then
        idx1 = nodeIdx
        idx2 = RollerCoaster.WrapNext(nodeIdx)
    else
        idx1 = RollerCoaster.WrapNext(nodeIdx)
        idx2 = nodeIdx
    end

    if not wp[idx1] or not wp[idx2] or not Roller.distances[idx1] or not Roller.distances[idx2] then
        return vector3(0, 0, 0)
    end

    local segDist = math.abs((Roller.distances[idx2]) - (Roller.distances[idx1]))
    if segDist == 0 then return wp[idx1] end

    local localDist = spd - (Roller.distances[idx1])
    local t = localDist / segDist

    local dx = wp[idx2].x - wp[idx1].x
    local dy = wp[idx2].y - wp[idx1].y
    local dz = wp[idx2].z - wp[idx1].z

    if Roller.varSpeed >= 0 then
        return vector3(wp[idx1].x + dx * t, wp[idx1].y + dy * t, wp[idx1].z + dz * t)
    else
        return vector3(wp[idx1].x - dx * t, wp[idx1].y - dy * t, wp[idx1].z - dz * t)
    end
end

function RollerCoaster.SetCarRotation(carIdx, nodeIdx, spd)
    if not DoesEntityExist(Roller.cars[carIdx].entity) then return end

    local prevIdx = RollerCoaster.WrapPrev(nodeIdx)
    local nextIdx = RollerCoaster.WrapNext(nodeIdx)
    local nextNextIdx = RollerCoaster.WrapNext(nextIdx)

    if not Roller.distances[nodeIdx] or not Roller.distances[nextIdx] then return end

    if spd < 0 then
        spd = spd + (Roller.distances[Roller.waypointIdx - 1] or 0.0)
    end

    local segDist = Roller.distances[nextIdx] - Roller.distances[nodeIdx]
    if segDist == 0 then return end

    local t = (spd - Roller.distances[nodeIdx]) / segDist

    -- Calculate quaternion rotation via slerp between adjacent segments
    local rot1 = RollerCoaster.SegmentRotation(prevIdx, nodeIdx)
    local rot2 = RollerCoaster.SegmentRotation(nodeIdx, nextIdx)

    local q1 = RollerCoaster.EulerToQuat(rot1)
    local q2 = RollerCoaster.EulerToQuat(rot2)

    local interpT
    if t < 0.5 then
        interpT = t + 0.5
        -- Use prev->current and current->next
    else
        interpT = t - 0.5
        q1 = RollerCoaster.EulerToQuat(rot2)
        q2 = RollerCoaster.EulerToQuat(RollerCoaster.SegmentRotation(nextIdx, nextNextIdx))
    end

    local qr = RollerCoaster.SlerpQuat(q1, q2, interpT)
    SetEntityQuaternion(Roller.cars[carIdx].entity, qr[1], qr[2], qr[3], qr[4])

    -- Vibration feedback for lead car
    if carIdx == 0 and prevIdx % 3 == 0 then
        local playerPos = GetEntityCoords(PlayerPedId())
        local carPos = GetEntityCoords(Roller.cars[0].entity)
        if #(playerPos - carPos) < 50.0 then
            SetPadShake(0, 32, 32)
        end
    end
end

function RollerCoaster.SegmentRotation(idx1, idx2)
    local wp = Roller.waypoints
    if not wp[idx1] or not wp[idx2] then return vector3(0, 0, 0) end

    local dx = wp[idx2].x - wp[idx1].x
    local dy = wp[idx2].y - wp[idx1].y
    local dz = wp[idx2].z - wp[idx1].z

    local mag = math.sqrt(dx * dx + dy * dy + dz * dz)
    if mag ~= 0 then
        local inv = 1.0 / mag
        dx = dx * inv
        dy = dy * inv
        dz = dz * inv
    end

    local yaw = 0.0
    if dy ~= 0 then
        yaw = math.deg(math.atan(dx, dy))
    elseif dx < 0 then
        yaw = -90.0
    else
        yaw = 90.0
    end

    local horiz = math.sqrt(dx * dx + dy * dy)
    local pitch = 0.0
    if horiz ~= 0 then
        pitch = math.deg(math.atan(dz, horiz))
    elseif dz < 0 then
        pitch = -90.0
    else
        pitch = 90.0
    end

    return vector3(-pitch, 0.0, -yaw - 180.0)
end

function RollerCoaster.EulerToQuat(rot)
    local hp = rot.y / 2.0
    local hy = rot.z / 2.0
    local hr = rot.x / 2.0

    local sp = Config.ConvertRadiansToDegrees(math.sin(Config.ConvertDegreesToRadians(hp)))
    local sy = Config.ConvertRadiansToDegrees(math.sin(Config.ConvertDegreesToRadians(hy)))
    local sr = Config.ConvertRadiansToDegrees(math.sin(Config.ConvertDegreesToRadians(hr)))
    local cp = Config.ConvertRadiansToDegrees(math.cos(Config.ConvertDegreesToRadians(hp)))
    local cy = Config.ConvertRadiansToDegrees(math.cos(Config.ConvertDegreesToRadians(hy)))
    local cr = Config.ConvertRadiansToDegrees(math.cos(Config.ConvertDegreesToRadians(hr)))

    local x = (sr * cp * cy) - (cr * sp * sy)
    local y = (cr * sp * cy) + (sr * cp * sy)
    local z = (cr * cp * sy) - (sr * sp * cy)
    local w = (cr * cp * cy) + (sr * sp * sy)

    return { x, y, z, w }
end

function RollerCoaster.SlerpQuat(q1, q2, t)
    local qx, qy, qz, qw = SlerpNearQuaternion(t,
        q1[1], q1[2], q1[3], q1[4],
        q2[1], q2[2], q2[3], q2[4])
    return { qx, qy, qz, qw }
end

-- ============================================================
-- UI HELPERS
-- ============================================================

function RollerCoaster.ShowHelpText(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

function RollerCoaster.ShowNotification(text)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, false)
end

function RollerCoaster.RenderRCButtons()
    if not ScaleformRC then
        ScaleformRCH = RequestScaleformMovie("instructional_buttons")
        while not HasScaleformMovieLoaded(ScaleformRCH) do Wait(0) end

        PushScaleformMovieFunction(ScaleformRCH, "CLEAR_ALL")
        PopScaleformMovieFunctionVoid()
        PushScaleformMovieFunction(ScaleformRCH, "TOGGLE_MOUSE_BUTTONS")
        PushScaleformMovieFunctionParameterBool(false)
        PopScaleformMovieFunctionVoid()

        PushScaleformMovieFunction(ScaleformRCH, "SET_DATA_SLOT")
        PushScaleformMovieFunctionParameterInt(0)
        PushScaleformMovieFunctionParameterString(GetControlInstructionalButton(2, 203, 1))
        PushScaleformMovieFunctionParameterString("Raise/Lower Arms")
        PopScaleformMovieFunctionVoid()

        PushScaleformMovieFunction(ScaleformRCH, "DRAW_INSTRUCTIONAL_BUTTONS")
        PushScaleformMovieFunctionParameterInt(-1)
        PopScaleformMovieFunctionVoid()

        ScaleformRC = true
    end
    if ScaleformRC then
        DrawScaleformMovieFullscreen(ScaleformRCH, 255, 255, 255, 255, 0)
    end
end

-- ============================================================
-- CLEANUP
-- ============================================================

AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    for i = 0, Config.RollerCoaster.CarCount - 1 do
        if Roller.cars[i] and DoesEntityExist(Roller.cars[i].entity) then
            DeleteEntity(Roller.cars[i].entity)
        end
    end
end)

-- ============================================================
-- TRACK DATA (225 waypoints + speed values)
-- ============================================================

function RollerCoaster.BuildTrack()
    local wp = {}
    local idx = 0

    local function addWP(x, y, z)
        wp[idx] = vector3(x, y, z)
        idx = idx + 1
    end

    addWP(-1659.01, -1143.129, 17.4192)
    addWP(-1643.524, -1124.681, 17.4326)
    addWP(-1639.621, -1120.021, 17.6357)
    addWP(-1638.199, -1118.316, 17.9966)
    addWP(-1637.011, -1116.896, 18.5407)
    addWP(-1635.772, -1115.417, 19.2558)
    addWP(-1634.227, -1113.569, 20.1725)
    addWP(-1632.692, -1111.734, 21.0835)
    addWP(-1631.179, -1109.922, 21.9826)
    addWP(-1629.692, -1108.145, 22.865)
    addWP(-1628.243, -1106.411, 23.7252)
    addWP(-1626.84, -1104.733, 24.558)
    addWP(-1625.491, -1103.12, 25.3588)
    addWP(-1624.206, -1101.582, 26.1218)
    addWP(-1622.992, -1100.13, 26.8424)
    addWP(-1620.721, -1097.416, 28.1892)
    addWP(-1618.866, -1095.196, 29.2895)
    addWP(-1617.533, -1093.603, 30.0795)
    addWP(-1616.778, -1092.699, 30.5401)
    addWP(-1615.677, -1091.388, 30.9156)
    addWP(-1614.829, -1090.377, 31.0008)
    addWP(-1614.011, -1089.406, 30.9417)
    addWP(-1612.615, -1087.747, 30.3463)
    addWP(-1610.992, -1085.82, 29.1724)
    addWP(-1609.228, -1083.725, 27.949)
    addWP(-1608.295, -1082.615, 27.4861)
    addWP(-1606.937, -1081.002, 27.4328)
    addWP(-1605.471, -1079.258, 27.5762)
    addWP(-1604.159, -1077.701, 28.0216)
    addWP(-1602.511, -1075.749, 28.5244)
    addWP(-1600.932, -1073.873, 28.9813)
    addWP(-1599.342, -1071.983, 29.1756)
    addWP(-1597.851, -1070.067, 29.1552)
    addWP(-1596.723, -1067.995, 29.0611)
    addWP(-1596.123, -1065.708, 28.9503)
    addWP(-1595.991, -1063.354, 28.8316)
    addWP(-1596.365, -1061.041, 28.7074)
    addWP(-1597.254, -1058.857, 28.577)
    addWP(-1598.562, -1056.894, 28.4423)
    addWP(-1600.27, -1055.292, 28.3045)
    addWP(-1602.288, -1054.077, 28.163)
    addWP(-1604.497, -1053.295, 28.019)
    addWP(-1606.845, -1053.063, 27.8712)
    addWP(-1609.193, -1053.3, 27.7214)
    addWP(-1611.416, -1054.029, 27.5695)
    addWP(-1613.432, -1055.248, 27.4148)
    addWP(-1615.167, -1056.844, 27.2581)
    addWP(-1616.486, -1058.782, 27.0998)
    addWP(-1617.371, -1060.964, 26.9395)
    addWP(-1617.803, -1063.281, 26.7771)
    addWP(-1617.669, -1065.625, 26.6138)
    addWP(-1617.071, -1067.903, 26.4484)
    addWP(-1616.006, -1069.994, 26.2817)
    addWP(-1614.489, -1071.798, 26.1132)
    addWP(-1612.646, -1073.265, 25.9435)
    addWP(-1610.523, -1074.272, 25.7722)
    addWP(-1608.231, -1074.807, 25.5996)
    addWP(-1605.875, -1074.877, 25.4258)
    addWP(-1603.576, -1074.385, 25.251)
    addWP(-1601.417, -1073.441, 25.0748)
    addWP(-1599.508, -1072.067, 24.8974)
    addWP(-1597.961, -1070.289, 24.7188)
    addWP(-1596.798, -1068.241, 24.5393)
    addWP(-1596.121, -1065.987, 24.3586)
    addWP(-1595.946, -1063.637, 24.177)
    addWP(-1596.242, -1061.301, 23.9942)
    addWP(-1597.079, -1059.097, 23.8103)
    addWP(-1598.345, -1057.109, 23.6258)
    addWP(-1599.996, -1055.426, 23.44)
    addWP(-1601.991, -1054.172, 23.2534)
    addWP(-1604.195, -1053.339, 23.0661)
    addWP(-1606.533, -1053.01, 22.8773)
    addWP(-1608.881, -1053.199, 22.6882)
    addWP(-1611.144, -1053.85, 22.4984)
    addWP(-1613.199, -1055.015, 22.3068)
    addWP(-1614.982, -1056.581, 22.1126)
    addWP(-1616.545, -1058.398, 21.7888)
    addWP(-1618.098, -1060.261, 21.3373)
    addWP(-1619.583, -1062.043, 20.7536)
    addWP(-1621.058, -1063.813, 20.1778)
    addWP(-1622.535, -1065.582, 19.6021)
    addWP(-1624.009, -1067.352, 19.0262)
    addWP(-1625.482, -1069.119, 18.4527)
    addWP(-1626.88, -1070.806, 17.9515)
    addWP(-1628.218, -1072.426, 17.7058)
    addWP(-1629.509, -1073.975, 17.7076)
    addWP(-1631.046, -1075.816, 17.7079)
    addWP(-1632.36, -1077.393, 17.7079)
    addWP(-1633.897, -1079.234, 17.7081)
    addWP(-1635.397, -1080.972, 17.7074)
    addWP(-1636.924, -1082.801, 17.7074)
    addWP(-1638.383, -1084.535, 17.8395)
    addWP(-1639.644, -1086.005, 18.3624)
    addWP(-1640.985, -1087.563, 19.3675)
    addWP(-1642.482, -1089.276, 20.5799)
    addWP(-1644.108, -1091.096, 21.5914)
    addWP(-1645.844, -1092.97, 21.9359)
    addWP(-1647.561, -1094.781, 21.6225)
    addWP(-1649.239, -1096.506, 20.9627)
    addWP(-1650.894, -1098.148, 20.1969)
    addWP(-1652.535, -1099.704, 19.525)
    addWP(-1654.248, -1101.247, 18.9923)
    addWP(-1656.05, -1102.794, 18.5631)
    addWP(-1657.911, -1104.315, 18.2393)
    addWP(-1659.798, -1105.782, 18.0219)
    addWP(-1661.681, -1107.168, 17.911)
    addWP(-1663.525, -1108.445, 17.9064)
    addWP(-1665.293, -1109.582, 18.0057)
    addWP(-1667.317, -1110.773, 18.2989)
    addWP(-1669.263, -1111.836, 18.8213)
    addWP(-1671.144, -1112.787, 19.5262)
    addWP(-1673.022, -1113.685, 20.3691)
    addWP(-1674.958, -1114.582, 21.2989)
    addWP(-1676.995, -1115.534, 22.249)
    addWP(-1679.084, -1116.478, 23.1368)
    addWP(-1681.219, -1117.389, 23.9532)
    addWP(-1683.374, -1118.29, 24.6845)
    addWP(-1685.517, -1119.208, 25.3158)
    addWP(-1687.62, -1120.167, 25.8329)
    addWP(-1689.705, -1121.188, 26.2178)
    addWP(-1691.772, -1122.315, 26.5427)
    addWP(-1693.635, -1123.75, 26.845)
    addWP(-1695.254, -1125.474, 27.1175)
    addWP(-1696.581, -1127.444, 27.3373)
    addWP(-1697.574, -1129.602, 27.5003)
    addWP(-1698.207, -1131.882, 27.623)
    addWP(-1698.465, -1134.234, 27.7231)
    addWP(-1698.344, -1136.602, 27.7949)
    addWP(-1697.841, -1138.921, 27.8328)
    addWP(-1696.972, -1141.131, 27.8321)
    addWP(-1695.759, -1143.174, 27.7892)
    addWP(-1694.234, -1144.995, 27.7019)
    addWP(-1692.435, -1146.544, 27.5687)
    addWP(-1690.415, -1147.784, 27.39)
    addWP(-1688.226, -1148.682, 27.1671)
    addWP(-1685.926, -1149.218, 26.9025)
    addWP(-1683.576, -1149.376, 26.5994)
    addWP(-1681.237, -1149.161, 26.2631)
    addWP(-1678.968, -1148.578, 25.8985)
    addWP(-1676.825, -1147.645, 25.5118)
    addWP(-1674.862, -1146.388, 25.1091)
    addWP(-1673.124, -1144.839, 24.6968)
    addWP(-1671.654, -1143.039, 24.2822)
    addWP(-1670.486, -1141.031, 23.8716)
    addWP(-1669.649, -1138.865, 23.472)
    addWP(-1669.163, -1136.595, 23.0898)
    addWP(-1669.04, -1134.274, 22.7307)
    addWP(-1669.284, -1131.962, 22.4006)
    addWP(-1669.888, -1129.713, 22.1045)
    addWP(-1670.841, -1127.585, 21.8463)
    addWP(-1672.12, -1125.632, 21.6294)
    addWP(-1673.694, -1123.904, 21.4559)
    addWP(-1675.523, -1122.444, 21.327)
    addWP(-1677.563, -1121.29, 21.2429)
    addWP(-1679.762, -1120.476, 21.2021)
    addWP(-1682.064, -1120.019, 21.2025)
    addWP(-1684.41, -1119.933, 21.2408)
    addWP(-1686.742, -1120.221, 21.3125)
    addWP(-1689.0, -1120.877, 21.4123)
    addWP(-1691.128, -1121.884, 21.5343)
    addWP(-1693.069, -1123.218, 21.672)
    addWP(-1694.779, -1124.849, 21.8191)
    addWP(-1695.93, -1126.324, 21.9029)
    addWP(-1696.878, -1127.99, 21.9873)
    addWP(-1697.674, -1129.878, 22.0778)
    addWP(-1698.292, -1131.96, 22.1685)
    addWP(-1698.699, -1134.206, 22.2533)
    addWP(-1698.866, -1136.587, 22.3261)
    addWP(-1698.764, -1139.072, 22.3807)
    addWP(-1698.363, -1141.633, 22.4112)
    addWP(-1697.633, -1144.24, 22.4113)
    addWP(-1696.546, -1146.863, 22.3751)
    addWP(-1695.061, -1149.484, 22.295)
    addWP(-1693.239, -1151.881, 22.1555)
    addWP(-1691.225, -1153.872, 21.965)
    addWP(-1689.074, -1155.483, 21.737)
    addWP(-1686.842, -1156.74, 21.485)
    addWP(-1684.583, -1157.674, 21.2224)
    addWP(-1682.351, -1158.311, 20.9625)
    addWP(-1680.161, -1158.67, 20.7161)
    addWP(-1678.176, -1158.802, 20.5023)
    addWP(-1676.344, -1158.712, 20.3287)
    addWP(-1674.755, -1158.437, 20.2097)
    addWP(-1672.606, -1157.658, 20.0965)
    addWP(-1670.584, -1156.442, 19.9803)
    addWP(-1668.831, -1154.866, 19.8642)
    addWP(-1667.418, -1152.986, 19.7482)
    addWP(-1666.452, -1150.833, 19.6319)
    addWP(-1665.911, -1148.538, 19.5158)
    addWP(-1665.817, -1146.181, 19.3996)
    addWP(-1666.207, -1143.862, 19.2836)
    addWP(-1667.073, -1141.668, 19.1674)
    addWP(-1668.339, -1139.679, 19.0512)
    addWP(-1669.962, -1137.965, 18.935)
    addWP(-1671.913, -1136.65, 18.8189)
    addWP(-1674.087, -1135.737, 18.7028)
    addWP(-1676.397, -1135.256, 18.5866)
    addWP(-1678.751, -1135.237, 18.4705)
    addWP(-1681.058, -1135.73, 18.3543)
    addWP(-1683.23, -1136.65, 18.2382)
    addWP(-1685.187, -1137.968, 18.1219)
    addWP(-1686.824, -1139.661, 18.0059)
    addWP(-1688.081, -1141.657, 17.8896)
    addWP(-1688.938, -1143.855, 17.7735)
    addWP(-1689.359, -1146.177, 17.6571)
    addWP(-1689.26, -1148.532, 17.5411)
    addWP(-1688.71, -1150.826, 17.425)
    addWP(-1687.733, -1152.976, 17.3087)
    addWP(-1686.342, -1154.887, 17.1759)
    addWP(-1684.573, -1156.462, 17.0021)
    addWP(-1682.54, -1157.669, 16.7987)
    addWP(-1680.313, -1158.466, 16.5838)
    addWP(-1677.973, -1158.77, 16.3415)
    addWP(-1675.626, -1158.601, 16.0948)
    addWP(-1673.361, -1157.994, 15.9205)
    addWP(-1671.255, -1156.966, 15.8075)
    addWP(-1669.435, -1155.511, 15.7719)
    addWP(-1667.848, -1153.66, 15.766)
    addWP(-1666.33, -1151.852, 15.7703)
    addWP(-1664.875, -1150.117, 15.8984)
    addWP(-1663.46, -1148.431, 16.198)
    addWP(-1662.033, -1146.731, 16.6412)
    addWP(-1660.556, -1144.97, 17.1643)
    addWP(-1659.01, -1143.129, 17.4192)

    -- Close the loop
    wp[idx - 1] = wp[0]

    Roller.waypoints = wp
    Roller.waypointIdx = idx

    -- Calculate cumulative distances
    RollerCoaster.CalculateDistances()

    -- Speed map (copied from original C# data)
    Roller.speedMap = {
        [0] = 0, [1] = 0.3, [2] = 0.3,
    }
    -- Fill 3-21 with 3.0
    for i = 3, 21 do Roller.speedMap[i] = 3.0 end

    -- Remaining speed values from original
    local speedData = {
        3.1794, 4.8025, 6.7585, 8.3448, 8.8436, 8.9045, 8.7073, 8.1965,
        7.5921, 7.0097, 6.6959, 6.7221, 6.8771, 7.0232, 7.18, 7.3457,
        7.5605, 7.6956, 7.8806, 8.0659, 8.2597, 8.4085, 8.6081, 8.7629,
        8.9647, 9.1286, 9.2889, 9.4513, 9.6107, 9.8224, 9.9849, 10.1485,
        10.3112, 10.4793, 10.648, 10.7657, 10.9378, 11.1113, 11.285, 11.4038,
        11.5785, 11.7563, 11.8826, 12.0063, 12.1858, 12.311, 12.4905, 12.6186,
        12.752, 12.9366, 13.069, 13.2002, 13.3271, 13.5131, 13.6428, 13.8557,
        14.1467, 14.7078, 15.0933, 15.4812, 15.6897, 16.072, 16.4288, 16.6158,
        16.615, 16.6148, 16.6148, 16.6147, 16.6151, 16.6151, 16.5645, 16.145,
        15.4464, 14.6939, 14.0775, 13.7741, 13.9723, 14.39, 14.8988, 15.3516,
        15.7118, 15.9945, 16.2069, 16.3518, 16.3944, 16.3977, 16.3236, 16.1241,
        15.9292, 15.4375, 14.8409, 14.2057, 13.5752, 12.7336, 12.2095, 11.5221,
        11.0986, 10.6031, 10.2269, 9.9111, 9.5337, 9.2694, 9.0583, 8.8516,
        8.7288, 8.6021, 8.51, 8.4733, 8.4742, 8.5294, 8.6157, 8.7849,
        8.9639, 9.2546, 9.514, 9.8293, 10.1114, 10.5312, 10.9067, 11.1773,
        11.5836, 11.9962, 12.2748, 12.6632, 12.9328, 13.1711, 13.3959, 13.6873,
        13.8612, 14.0083, 14.1297, 14.2155, 14.2732, 14.3011, 14.3008, 14.2746,
        14.2251, 14.1577, 14.0733, 13.9385, 13.8385, 13.7996, 13.7301, 13.6586,
        13.5902, 13.5308, 13.482, 13.4313, 13.4127, 13.4126, 13.433, 13.4949,
        13.6046, 13.761, 13.8937, 14.1199, 14.2919, 14.4699, 14.6443, 14.7383,
        14.889, 14.9538, 15.0334, 15.1141, 15.1923, 15.2712, 15.3499, 15.4286,
        15.5073, 15.5512, 15.6299, 15.7082, 15.7859, 15.8647, 15.9434, 16.0226,
        16.0645, 16.1422, 16.2213, 16.2996, 16.3783, 16.4226, 16.5003, 16.5796,
        16.6622, 16.7055, 16.7837, 16.8729, 16.9907, 17.0661, 17.2127, 17.3761,
        17.4689, 17.5883, 17.6648, 17.6783, 17.6822, 17.6806, 17.5908, 17.371,
        17.1986, 16.8458,
    }
    for i, v in ipairs(speedData) do
        Roller.speedMap[21 + i] = v
    end
end

function RollerCoaster.CalculateDistances()
    local wp = Roller.waypoints
    local dist = {}
    local cumulative = 0.0

    for i = 0, Roller.waypointIdx - 1 do
        if wp[i] and wp[i].x ~= 0 and wp[i].y ~= 0 then
            dist[i] = cumulative
            if i < Roller.waypointIdx - 1 and wp[i + 1] then
                local dx = wp[i + 1].x - wp[i].x
                local dy = wp[i + 1].y - wp[i].y
                local dz = wp[i + 1].z - wp[i].z
                cumulative = cumulative + math.sqrt(dx * dx + dy * dy + dz * dz)
            end
        else
            break
        end
    end

    Roller.distances = dist
end
