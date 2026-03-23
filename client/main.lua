--[[
     Client - Main Entry Point
    Initializes both the Ferris Wheel and Roller Coaster modules.
]]

Citizen.CreateThread(function()
    -- Wait for resource to be fully started
    while not NetworkIsSessionStarted() do
        Wait(100)
    end

    print("[LunaPark] Client initializing...")

    FerrisWheel.Init()
    RollerCoaster.Init()

    print("[LunaPark] Client loaded successfully.")
end)
