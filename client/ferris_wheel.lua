--[[
     Client - Ferris Wheel
    Sound IDs are tracked and properly released.
    Ticks throttle based on player distance.
]]

-- 
-- CLASSES
-- 
WheelData = Class()
function WheelData:init()
    self.entity    = 0
    self.gradient  = 0
    self.rotation  = 0.0
    self.state     = "IDLE"
    self.speed     = Config.FerrisWheel.Speed
    self.stopped   = false
end

CabinData = Class()
function CabinData:init(index)
    self.entity       = 0
    self.index        = index
    self.playerInside = false
    self.playerCount  = 0
    self.gradient     = (360.0 / Config.FerrisWheel.CabinCount) * index
end

-- 
-- MODULE
-- 

FerrisWheel = {}

local Wheel       = WheelData:new()
local Cabins      = {}
local ActualCabin = nil
local RideEnd     = true
local PrevTime    = 0

-- Camera
local Cam1             = 0
local CamIsFirstPerson = false
local ScaleformLoaded  = false
local ScaleformHandle  = 0

-- Sound tracking: store IDs so we can stop + release them
local SoundIds = {
    generator  = -1,
    squeak1    = -1,
    squeak2    = -1,
    carriage   = -1,
}

-- 
-- SOUND MANAGEMENT
-- 

--- Stop and release all tracked ferris wheel sounds.
function FerrisWheel.StopAllSounds()
    for key, id in pairs(SoundIds) do
        if id ~= -1 then
            StopSound(id)
            ReleaseSoundId(id)
            SoundIds[key] = -1
        end
    end
end

--- Start the ride sounds. Stops any existing ones first to prevent stacking.
function FerrisWheel.StartRideSounds()
    -- Always stop existing sounds first to prevent layering
    FerrisWheel.StopAllSounds()

    SoundIds.generator = GetSoundId()
    PlaySoundFromEntity(SoundIds.generator, "GENERATOR", Wheel.entity, Config.FerrisWheel.SoundSet, false, 0)

    SoundIds.squeak1 = GetSoundId()
    PlaySoundFromEntity(SoundIds.squeak1, "SLOW_SQUEAK", Wheel.entity, Config.FerrisWheel.SoundSet, false, 0)

    if Cabins[1] and DoesEntityExist(Cabins[1].entity) then
        SoundIds.squeak2 = GetSoundId()
        PlaySoundFromEntity(SoundIds.squeak2, "SLOW_SQUEAK", Cabins[1].entity, Config.FerrisWheel.SoundSet, false, 0)

        SoundIds.carriage = GetSoundId()
        PlaySoundFromEntity(SoundIds.carriage, "CARRIAGE", Cabins[1].entity, Config.FerrisWheel.SoundSet, false, 0)
    end
end

-- 
-- INIT
-- 

function FerrisWheel.Init()
    for i = 0, Config.FerrisWheel.CabinCount - 1 do
        Cabins[i] = CabinData:new(i)
    end

    local blip = AddBlipForCoord(Config.FerrisWheel.Position.x, Config.FerrisWheel.Position.y, Config.FerrisWheel.Position.z)
    SetBlipSprite(blip, Config.FerrisWheel.Blip.Sprite)
    SetBlipAsShortRange(blip, Config.FerrisWheel.Blip.ShortRange)
    SetBlipDisplay(blip, Config.FerrisWheel.Blip.Display)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(Config.FerrisWheel.Blip.Name)
    EndTextCommandSetBlipName(blip)

    RegisterNetEvent("FerrisWheel:ForceState")
    AddEventHandler("FerrisWheel:ForceState", function(state) Wheel.state = state end)

    RegisterNetEvent("FerrisWheel:UpdateCabins")
    AddEventHandler("FerrisWheel:UpdateCabins", function(index, count)
        if Cabins[index] then Cabins[index].playerCount = count end
    end)

    RegisterNetEvent("FerrisWheel:StopWheel")
    AddEventHandler("FerrisWheel:StopWheel", function(stopped) Wheel.stopped = stopped end)

    RegisterNetEvent("FerrisWheel:PlayerGetOn")
    AddEventHandler("FerrisWheel:PlayerGetOn", function(netId, cabIndex)
        FerrisWheel.HandlePlayerGetOn(netId, cabIndex)
    end)

    RegisterNetEvent("FerrisWheel:PlayerGetOff")
    AddEventHandler("FerrisWheel:PlayerGetOff", function(netId, cabIndex)
        FerrisWheel.HandlePlayerGetOff(netId, cabIndex)
    end)

    RegisterNetEvent("FerrisWheel:UpdateGradient")
    AddEventHandler("FerrisWheel:UpdateGradient", function(gradient) Wheel.gradient = gradient end)

    FerrisWheel.LoadAssets()
end

-- 
-- ASSET LOADING
-- 
function FerrisWheel.LoadAssets()
    local cfg = Config.FerrisWheel

    RequestModel(cfg.Model)
    while not HasModelLoaded(cfg.Model) do Wait(100) end
    RequestModel(cfg.CabinModel)
    while not HasModelLoaded(cfg.CabinModel) do Wait(100) end
    RequestAnimDict(cfg.AnimDict)
    while not HasAnimDictLoaded(cfg.AnimDict) do Wait(100) end

    for _, bank in ipairs(cfg.AudioBanks) do
        RequestScriptAudioBank(bank, false)
    end

    FerrisWheel.SpawnWheel()

    Citizen.CreateThread(FerrisWheel.TickMoveWheel)
    Citizen.CreateThread(FerrisWheel.TickPlayerControl)
end

-- 
-- SPAWN
-- 
function FerrisWheel.SpawnWheel()
    local cfg = Config.FerrisWheel
    local pos = cfg.Position

    Wheel.entity = CreateObject(cfg.Model, 0.0, 1.0, 2.0, false, false, false)
    SetEntityCoords(Wheel.entity, pos.x, pos.y, pos.z, false, false, false, true)
    SetEntityRotation(Wheel.entity, 360.0, 0.0, 0.0, 2, true)
    FreezeEntityPosition(Wheel.entity, true)
    SetEntityLodDist(Wheel.entity, 1000)
    SetEntityInvincible(Wheel.entity, true)

    for i = 0, cfg.CabinCount - 1 do
        Wait(0)
        local cabPos = FerrisWheel.GetCabinWorldPos(i)
        Cabins[i].entity = CreateObject(cfg.CabinModel, 0.0, 1.0, 2.0, false, false, false)
        SetEntityCoords(Cabins[i].entity, cabPos.x, cabPos.y, cabPos.z, false, false, false, true)
        SetEntityInvincible(Cabins[i].entity, true)
        SetEntityLodDist(Cabins[i].entity, 1000)
        FreezeEntityPosition(Cabins[i].entity, true)
    end
end

-- 
-- WHEEL MOVEMENT (tick) — distance-throttled
-- 
function FerrisWheel.TickMoveWheel()
    while true do
        local playerPos = GetEntityCoords(PlayerPedId())
        local dist = #(playerPos - Config.FerrisWheel.Position)

        -- Far away: sleep longer, skip heavy work
        if dist > 300.0 then
            Wait(2000)
        elseif dist > 150.0 then
            Wait(500)
        else
            Wait(0)
        end

        if not Wheel.stopped and Wheel.entity ~= 0 and DoesEntityExist(Wheel.entity) then
            local fVar2 = 0.0
            if PrevTime ~= 0 then
                fVar2 = GetTimeDifference(GetNetworkTimeAccurate(), PrevTime) / 800.0
            end
            PrevTime = GetNetworkTimeAccurate()

            Wheel.rotation = Wheel.rotation + (Wheel.speed * fVar2)
            if Wheel.rotation >= 360.0 then
                Wheel.rotation = Wheel.rotation - 360.0
            end

            -- Check cabin alignment for boarding/alighting
            for i = 0, Config.FerrisWheel.CabinCount - 1 do
                if math.abs(Wheel.rotation - Cabins[i].gradient) < 0.05 then
                    local nextGrad = (i + 1 > 15) and 0 or (i + 1)
                    Wheel.gradient = nextGrad
                    TriggerServerEvent("FerrisWheel:UpdateGradient", Wheel.gradient)

                    if Wheel.state == "BOARDING" then
                        ActualCabin = Cabins[Wheel.gradient]
                        TriggerServerEvent("FerrisWheel:PlayerGetOn",
                            NetworkGetNetworkIdFromEntity(PlayerPedId()), Wheel.gradient)
                    elseif Wheel.state == "ALIGHTING" then
                        TriggerServerEvent("FerrisWheel:PlayerGetOff",
                            NetworkGetNetworkIdFromEntity(PlayerPedId()), Wheel.gradient)
                    end
                end
            end

            SetEntityRotation(Wheel.entity, -Wheel.rotation - 22.5, 0.0, 0.0, 2, true)

            for i = 0, Config.FerrisWheel.CabinCount - 1 do
                FerrisWheel.UpdateCabinPosition(i)
            end

            -- Audio height (once per frame, not twice)
            if IsAudioSceneActive(Config.FerrisWheel.AudioScenes.Main) then
                SetAudioSceneVariable(Config.FerrisWheel.AudioScenes.Main, "HEIGHT", playerPos.z - 13.0)
            end
        end
    end
end

-- 
-- PLAYER CONTROL (tick) — distance-throttled
-- 
function FerrisWheel.TickPlayerControl()
    local audioStarted = false

    while true do
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local cfg = Config.FerrisWheel
       local dist = #(pos - cfg.BoardingPoint)

        --Throttle: if far away, sleep more
        if dist > cfg.ProximityRadius * 3 then
            Wait(1000)
        elseif dist > cfg.ProximityRadius then
            Wait(200)
        else
            Wait(0)
        end

        if dist < cfg.ProximityRadius then
            if not audioStarted then
                StartAudioScene(cfg.AudioScenes.Main)
                audioStarted = true
            end

            if dist < cfg.BoardingRadius then
                FerrisWheel.ShowHelpText("Press ~INPUT_CONTEXT~ to ride the Ferris Wheel")
                if IsControlJustPressed(2, 51) then
                    FerrisWheel.ShowNotification("Wait... the next free cabin is arriving...")
                    TriggerServerEvent("FerrisWheel:SyncState", "BOARDING")
                end
            end
        else
            if audioStarted then
                StopAudioScene(cfg.AudioScenes.Main)
                audioStarted = false
            end
        end

        -- Riding controls
        if not RideEnd then
            if GetFollowPedCamViewMode() == 4 then SetFollowPedCamViewMode(2) end
            DisableControlAction(0, 0, true)
            FerrisWheel.RenderButtons()

            if IsControlJustPressed(2, 204) then
                FerrisWheel.ShowNotification("The wheel will stop when your cabin reaches ground level.")
                Wheel.state = "ALIGHTING"
            end
            if IsControlJustPressed(2, 236) then
                FerrisWheel.ToggleCamera()
            end
        end
    end
end

-- 
-- PLAYER GET ON
-- 

function FerrisWheel.HandlePlayerGetOn(netId, cabIndex)
    Citizen.CreateThread(function()
        local ped = NetworkGetEntityFromNetworkId(netId)
        local cabin = Cabins[cabIndex]
        if not cabin or not DoesEntityExist(ped) then return end

        local boardPos = Config.FerrisWheel.BoardingPoint
        if not IsEntityAtCoord(ped, boardPos.x, boardPos.y, boardPos.z, 1.0, 1.0, 1.0, false, true, 0) then
            return
        end

        if ped ~= PlayerPedId() then
            if not NetworkHasControlOfNetworkId(netId) then
                local t = 0
                while not NetworkRequestControlOfNetworkId(netId) and t < 100 do Wait(0); t = t + 1 end
            end
        end

        TriggerServerEvent("FerrisWheel:StopWheel", true)
        Wheel.stopped = true
        Wait(100)

        local coord = GetOffsetFromEntityInWorldCoords(cabin.entity, 0.0, 0.0, 0.0)
        local scene = NetworkCreateSynchronisedScene(coord.x, coord.y, coord.z, 0.0, 0.0, 0.0, 2, true, false, 1065353216, 0, 1065353216)
        NetworkAddPedToSynchronisedScene(ped, scene, Config.FerrisWheel.AnimDict, "enter_player_one", 8.0, -8.0, 131072, 0, 1148846080, 0)
        NetworkStartSynchronisedScene(scene)
        Wait(7000)

        local attCoords = GetOffsetFromEntityGivenWorldCoords(cabin.entity,
            GetEntityCoords(ped).x, GetEntityCoords(ped).y, GetEntityCoords(ped).z)
        AttachEntityToEntity(ped, cabin.entity, 0,
            attCoords.x, attCoords.y, attCoords.z,
            0.0, 0.0, GetEntityHeading(ped),
            false, false, false, false, 2, true)

        cabin.playerCount = cabin.playerCount + 1
        TriggerServerEvent("FerrisWheel:UpdateCabins", cabin.index, cabin.playerCount)

        if ped == PlayerPedId() then
            RideEnd = false
            ActualCabin = cabin
        end

        Wheel.state = "IDLE"
        TriggerServerEvent("FerrisWheel:StopWheel", false)

        -- Start sounds (properly tracked, stops old ones first)
        FerrisWheel.StartRideSounds()

        if ped == PlayerPedId() then
            FerrisWheel.ActivateFarCamera()
        end
    end)
end

-- 
-- PLAYER GET OFF
-- 

function FerrisWheel.HandlePlayerGetOff(netId, cabIndex)
    Citizen.CreateThread(function()
        local ped = NetworkGetEntityFromNetworkId(netId)
        local cabin = Cabins[cabIndex]
        if not cabin or not DoesEntityExist(ped) then return end

        local isLocal = (ped == PlayerPedId())

        if isLocal then
            while ActualCabin ~= cabin do Wait(0) end

            TriggerServerEvent("FerrisWheel:StopWheel", true)

            -- Camera exit (snapshot trick for bone-attached cam)
            if CamIsFirstPerson and Cam1 ~= 0 and DoesCamExist(Cam1) then
                local camPos = GetCamCoord(Cam1)
                local camRot = GetCamRot(Cam1, 2)
                local camFov = GetCamFov(Cam1)

                SetCamActive(Cam1, false)
                DestroyCam(Cam1, false)
                Cam1 = 0

                local tmpCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA",
                    camPos.x, camPos.y, camPos.z,
                    camRot.x, camRot.y, camRot.z,
                    camFov, false, 2)
                SetCamActive(tmpCam, true)
                RenderScriptCams(true, false, 0, false, false)
                RenderScriptCams(false, true, 1500, true, false)
                Wait(1600)
                SetCamActive(tmpCam, false)
                DestroyCam(tmpCam, false)
            else
                if Cam1 ~= 0 and DoesCamExist(Cam1) then
                    RenderScriptCams(false, true, 1500, true, false)
                    Wait(1600)
                    SetCamActive(Cam1, false)
                    DestroyCam(Cam1, false)
                    Cam1 = 0
                else
                    RenderScriptCams(false, false, 0, false, false)
                end
            end

            DestroyAllCams(false)
            Cam1             = 0
            CamIsFirstPerson = false
            ScaleformLoaded  = false
        else
            if not NetworkHasControlOfNetworkId(netId) then
                local t = 0
                while not NetworkRequestControlOfNetworkId(netId) and t < 100 do Wait(0); t = t + 1 end
            end
        end

        local offset = GetOffsetFromEntityInWorldCoords(cabin.entity, 0.0, 0.0, 0.0)
        local scene = NetworkCreateSynchronisedScene(offset.x, offset.y, offset.z, 0.0, 0.0, 0.0, 2, false, false, 1065353216, 0, 1065353216)
        NetworkAddPedToSynchronisedScene(ped, scene, Config.FerrisWheel.AnimDict, "exit_player_one", 8.0, -8.0, 131072, 0, 1148846080, 0)
        NetworkStartSynchronisedScene(scene)

        DetachEntity(ped, true, true)
        Wait(5000)

        cabin.playerCount = 0
        TriggerServerEvent("FerrisWheel:UpdateCabins", cabin.index, cabin.playerCount)

        if isLocal then
            -- Stop and release ALL sounds
            FerrisWheel.StopAllSounds()

            if IsAudioSceneActive(Config.FerrisWheel.AudioScenes.Main) then
                StopAudioScene(Config.FerrisWheel.AudioScenes.Main)
            end
            if IsAudioSceneActive(Config.FerrisWheel.AudioScenes.Alt) then
                StopAudioScene(Config.FerrisWheel.AudioScenes.Alt)
            end
            RideEnd = true
            TriggerServerEvent("FerrisWheel:StopWheel", false)
            Wheel.state = "IDLE"
            ActualCabin = nil
        end
    end)
end

-- 
-- CABIN POSITION MATH
-- 

function FerrisWheel.GetCabinWorldPos(index)
    if not DoesEntityExist(Wheel.entity) then return Config.FerrisWheel.Position end
    local fVar0 = (6.28319 / Config.FerrisWheel.CabinCount) * index
    local y = Config.ConvertDegreesToRadians(15.3) * Config.ConvertRadiansToDegrees(math.sin(fVar0))
    local z = Config.ConvertDegreesToRadians(-15.3) * Config.ConvertRadiansToDegrees(math.cos(fVar0))
    return GetOffsetFromEntityInWorldCoords(Wheel.entity, 0.0, y, z)
end

function FerrisWheel.UpdateCabinPosition(i)
    if Cabins[i] and DoesEntityExist(Cabins[i].entity) then
        local offset = FerrisWheel.GetCabinWorldPos(i)
        SetEntityCoordsNoOffset(Cabins[i].entity, offset.x, offset.y, offset.z, true, false, false)
    end
end

-- 
-- CAMERA SYSTEM
-- 

function FerrisWheel.DestroyCam1()
    if Cam1 ~= 0 and DoesCamExist(Cam1) then
        SetCamActive(Cam1, false)
        DestroyCam(Cam1, false)
    end
    Cam1 = 0
    CamIsFirstPerson = false
end

function FerrisWheel.ActivateFarCamera()
    FerrisWheel.DestroyCam1()
    local cfg = Config.FerrisWheel.CamFar
    Cam1 = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA",
        cfg.Pos.x, cfg.Pos.y, cfg.Pos.z,
        cfg.Rot.x, cfg.Rot.y, cfg.Rot.z,
        cfg.Fov, false, 0)
    PointCamAtEntity(Cam1, Wheel.entity, 0.0, 0.0, 0.0, true)
    SetCamActive(Cam1, true)
    CamIsFirstPerson = false

    DoScreenFadeOut(500)
    Wait(800)
    RenderScriptCams(true, false, 0, false, false)
    DoScreenFadeIn(500)

    if IsAudioSceneActive(Config.FerrisWheel.AudioScenes.Main) then
        StopAudioScene(Config.FerrisWheel.AudioScenes.Main)
    end
    StartAudioScene(Config.FerrisWheel.AudioScenes.Alt)
    SetLocalPlayerInvisibleLocally(false)
end

function FerrisWheel.ActivateFirstPersonCamera()
    FerrisWheel.DestroyCam1()
    local pedCoords = GetPedBoneCoords(PlayerPedId(), 31086, 0.0, 0.2, 0.0)
    local rot = GetEntityRotation(PlayerPedId(), 2)

    Cam1 = CreateCam("DEFAULT_SCRIPTED_CAMERA", false)
    SetCamParams(Cam1, pedCoords.x, pedCoords.y, pedCoords.z, rot.x, rot.y, rot.z, 50.0, 0, 1, 1, 2)
    SetCamActive(Cam1, true)
    ShakeCam(Cam1, "HAND_SHAKE", 0.19)
    SetCamNearClip(Cam1, 0.1)
    AttachCamToPedBone(Cam1, PlayerPedId(), 31086, 0.0, 0.2, 0.0, true)
    CamIsFirstPerson = true
    SetLocalPlayerInvisibleLocally(false)
end

function FerrisWheel.ToggleCamera()
    if CamIsFirstPerson then
        DoScreenFadeOut(300)
        Wait(400)
        FerrisWheel.ActivateFarCamera()
        if not IsScreenFadedIn() then DoScreenFadeIn(300) end
    else
        DoScreenFadeOut(300)
        Wait(400)
        FerrisWheel.ActivateFirstPersonCamera()
        RenderScriptCams(true, false, 0, false, false)
        DoScreenFadeIn(300)
    end
end

-- 
-- UI
-- 

function FerrisWheel.ShowHelpText(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

function FerrisWheel.ShowNotification(text)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, false)
end

function FerrisWheel.RenderButtons()
    if not ScaleformLoaded then
        ScaleformHandle = RequestScaleformMovie("instructional_buttons")
        while not HasScaleformMovieLoaded(ScaleformHandle) do Wait(0) end
        PushScaleformMovieFunction(ScaleformHandle, "CLEAR_ALL")
        PopScaleformMovieFunctionVoid()
        PushScaleformMovieFunction(ScaleformHandle, "TOGGLE_MOUSE_BUTTONS")
        PushScaleformMovieFunctionParameterBool(false)
        PopScaleformMovieFunctionVoid()
        PushScaleformMovieFunction(ScaleformHandle, "SET_DATA_SLOT")
        PushScaleformMovieFunctionParameterInt(0)
        PushScaleformMovieFunctionParameterString(GetControlInstructionalButton(2, 236, 1))
        PushScaleformMovieFunctionParameterString("Change View")
        PopScaleformMovieFunctionVoid()
        PushScaleformMovieFunction(ScaleformHandle, "SET_DATA_SLOT")
        PushScaleformMovieFunctionParameterInt(1)
        PushScaleformMovieFunctionParameterString(GetControlInstructionalButton(2, 204, 1))
        PushScaleformMovieFunctionParameterString("Get Off")
        PopScaleformMovieFunctionVoid()
        PushScaleformMovieFunction(ScaleformHandle, "DRAW_INSTRUCTIONAL_BUTTONS")
        PushScaleformMovieFunctionParameterInt(-1)
        PopScaleformMovieFunctionVoid()
        ScaleformLoaded = true
    end
    if ScaleformLoaded then
        DrawScaleformMovieFullscreen(ScaleformHandle, 255, 255, 255, 255, 0)
    end
end

-- 
-- CLEANUP
-- 

AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    FerrisWheel.StopAllSounds()
    if DoesEntityExist(Wheel.entity) then DeleteEntity(Wheel.entity) end
    for i = 0, Config.FerrisWheel.CabinCount - 1 do
        if Cabins[i] and DoesEntityExist(Cabins[i].entity) then
            DeleteEntity(Cabins[i].entity)
        end
    end
    FerrisWheel.DestroyCam1()
    DestroyAllCams(false)
    RenderScriptCams(false, false, 0, false, false)
    StopAudioScene(Config.FerrisWheel.AudioScenes.Main)
    StopAudioScene(Config.FerrisWheel.AudioScenes.Alt)
end)
