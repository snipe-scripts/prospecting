-----------------For support, scripts, and more----------------
--------------- https://discord.gg/VGYkkAYVv2  -------------
---------------------------------------------------------------

QBCore, ESX = nil, nil
if Config.Core == "QBCore" then
    QBCore = exports['qb-core']:GetCoreObject()
elseif Config.Core == "ESX" then
    ESX = exports['es_extended']:getSharedObject()
end


local ShowInteraction = false

local targetPool = {}

local maxTargetRange = 200.0
local targets = {}

RegisterNetEvent(Config.PlayerLoadedEvent)
AddEventHandler(Config.PlayerLoadedEvent, function()
    TriggerServerEvent("prospecting:userRequestsLocations")
end)

local function RemoveTargetIndex(coords)
    for index, target in next, targetPool do
        local targetCoords = target[1]
        if vec3(targetCoords.x, targetCoords.y, targetCoords.z) == coords then
            table.remove(targetPool, index)
            break
        end
    end
end

RegisterNetEvent("prospecting:client:removeTarget", function (coords)
    RemoveTargetIndex(coords)
end)


function EnsureAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(0)
    end
end
function EnsureModel(model)
    if not IsModelInCdimage(model) then
        print("model", model, "not in cd image")
    else
        if not HasModelLoaded(model) then
            RequestModel(model)
            while not HasModelLoaded(model) do
                Wait(0)
            end
        end
	end
end

local previousAnim = nil
function StopAnim(ped)
    if previousAnim then
        StopEntityAnim(ped, previousAnim[2], previousAnim[1], true)
        previousAnim = nil
    end
end
function PlayAnimFlags(ped, dict, anim, flags)
    StopAnim(ped)
    EnsureAnimDict(dict)
    local len = GetAnimDuration(dict, anim)
    TaskPlayAnim(ped, dict, anim, 1.0, -1.0, len, flags, 1, 0, 0, 0)
    previousAnim = {dict, anim}
end

function PlayAnimUpper(ped, dict, anim)
    PlayAnimFlags(ped, dict, anim, 49)
end
function PlayAnim(ped, dict, anim)
    PlayAnimFlags(ped, dict, anim, 0)
end



RegisterNetEvent("prospecting:setTargetPool")
AddEventHandler("prospecting:setTargetPool", function(pool)
    targetPool = {}
    for n, pos in next, pool do
        targetPool[n] = {vector3(pos[1], pos[2], pos[3]), pos[4], n}
    end
end)

local isProspecting = false
local pauseProspecting = false
local didCancelProspecting = false
local scannerState = "none"
local scannerFrametime = 0.0
local scannerScale = 0.0
local scannerAudio = true

local CONTROLS = {
    ["dig"] = {
        label = "PROSP_DIG",
        control = 24,
        input = "INPUT_ATTACK"
    },
    ["dig_hint"] = {
        label = "PROSP_DIG_HINT",
        control = 24,
        input = "INPUT_ATTACK"
    },
    ["stop"] = {
        label = "PROSP_STOP",
        control = 75,
        input = "INPUT_VEH_EXIT"
    },
    ["audio_on"] = {
        label = "PROSP_AUDIOON",
        control = 140,
        input = "INPUT_MELEE_ATTACK_LIGHT"
    },
    ["audio_off"] = {
        label = "PROSP_AUDIOOFF",
        control = 140,
        input = "INPUT_MELEE_ATTACK_LIGHT"
    },
}

local entityOffsets = {
    ["w_am_metaldetector"] = {
		bone = 18905,
        offset = vector3(0.15, 0.1, 0.0),
        rotation = vector3(270.0, 90.0, 80.0),
	},
}

local attachedEntities = {}
local scannerEntity = nil
function AttachEntity(ped, model)
    if entityOffsets[model] then
        EnsureModel(model)
        local pos = GetEntityCoords(PlayerPedId())
    	local ent = CreateObjectNoOffset(model, pos, 1, 1, 0)
    	AttachEntityToEntity(ent, ped, GetPedBoneIndex(ped, entityOffsets[model].bone), entityOffsets[model].offset, entityOffsets[model].rotation, 1, 1, 0, 0, 2, 1)
        scannerEntity = ent
        table.insert(attachedEntities, ent)
    end
end

function CleanupModels()
    for _, ent in next, attachedEntities do
        DetachEntity(ent, 0, 0)
        DeleteEntity(ent)
    end
    attachedEntities = {}
    scannerEntity = nil
    ClearPedTasksImmediately(PlayerPedId())
end

function DisableAllInstructions()
    -- for _, inst in next, CONTROLS do
    --     SetInstructionalButton(inst["label"], inst["control"], false)
    -- end
end

function DigSequence(cb)
    DisableAllInstructions()
    CleanupModels()
    local ped = PlayerPedId()
     StopEntityAnim(ped, "wood_idle_a", "mini@golfai", true)
    TaskStartScenarioInPlace(PlayerPedId(), "WORLD_HUMAN_GARDENER_PLANT", 0, true)
    Wait(5000)
    if cb then cb() end
    Wait(3000)
    ClearPedTasks(PlayerPedId())
    AttachEntity(PlayerPedId(), "w_am_metaldetector")
end

function ShowHelp(text, n)
    BeginTextCommandDisplayHelp(text)
    EndTextCommandDisplayHelp(n or 0, false, true, -1)
end
function ShowFloatingHelp(text, pos)
    SetFloatingHelpTextWorldPosition(1, pos)
    SetFloatingHelpTextStyle(1, 1, 2, -1, 3, 0)
    ShowHelp(text, 2)
end

function getClosestTarget(pos)
    local closest, index, closestdist, difficulty
    for n, target in next, targets do
        local dist = #(pos.xy - target[1].xy)
        if (not closest) or closestdist > dist then
            closestdist = dist
            index = n
            closest = target
            difficulty = target[2]
        end
    end
    -- Return 0,0,0 if no targets
    return closest or vector3(0.0, 0.0, 0.0), closestdist, index, difficulty
end

function DigTarget(index)
    pauseProspecting = true
    local target = table.remove(targets, index)
    local pos = target[1]
   
    DigSequence(function()
        -- TriggerServerEvent("prospecting:userCollectedNode", index, pos.x, pos.y, pos.z)
        lib.callback.await("prospecting:userCollectedNode", false, index, pos.x, pos.y, pos.z)
    end)
    Wait(5000)
    StopProspecting()
    scannerState = "none"
    pauseProspecting = false
end

function StopProspecting()
    if not didCancelProspecting then
        lib.hideTextUI()
        ShowInteraction = false
        didCancelProspecting = true
        CleanupModels()
        local ped = PlayerPedId()
        -- StopEntityAnim(ped, "wood_idle_a", "mini@golfai", true)
        Wait(1000)
        -- ClearPedTasksImmediately(PlayerPedId())
        circleScale = 0.0
        scannerScale = 0.0
        scannerState = "none"
        isProspecting = false
        TriggerServerEvent("prospecting:userStoppedProspecting")
    end
end

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        CleanupModels()
        StopProspecting()
    end
end)

function StartProspecting()
    if not isProspecting then
        ProspectingThreads()
    end
end

RegisterNetEvent("prospecting:forceStart")
AddEventHandler("prospecting:forceStart", function()
    StartProspecting()
end)

RegisterNetEvent("prospecting:forceStop")
AddEventHandler("prospecting:forceStop", function()
    StopProspecting()
end)

AddEventHandler("onResourceStart", function(name)
    if GetCurrentResourceName() == name then
        -- init
        Wait(1000) -- waits 10 secs on restart to populate the data
        TriggerServerEvent("prospecting:userRequestsLocations")
    end
end)

function ProspectingThreads()
    if IsProspecting then return false end
    TriggerServerEvent("prospecting:userStartedProspecting")
    isProspecting = true
    didCancelProspecting = false
    pauseProspecting = false
    if not ShowInteraction then
        ShowInteraction = true
        lib.showTextUI("Left Click to Digging | [F] Stop")
    end
    -- Prospecting handler
    CreateThread(function()
        AttachEntity(PlayerPedId(), "w_am_metaldetector")
        while isProspecting do
            Wait(0)
            local ped = PlayerPedId()
            local ply = PlayerId()
            local canProspect = true
            for _, control in next, CONTROLS do
                DisableControlAction(0, control["control"], true)
            end
            if not IsEntityPlayingAnim(ped, "mini@golfai", "wood_idle_a", 3) then
                PlayAnimUpper(PlayerPedId(), "mini@golfai", "wood_idle_a")
            end

            -- Actions that halt prospecting animations and scanning
            local restrictedMovement = false
            restrictedMovement = restrictedMovement or IsPedFalling(ped)
            restrictedMovement = restrictedMovement or IsPedJumping(ped)
            restrictedMovement = restrictedMovement or IsPedSprinting(ped)
            restrictedMovement = restrictedMovement or IsPedRunning(ped)
            restrictedMovement = restrictedMovement or IsPlayerFreeAiming(ply)
            restrictedMovement = restrictedMovement or IsPedRagdoll(ped)
            restrictedMovement = restrictedMovement or IsPedInAnyVehicle(ped)
            restrictedMovement = restrictedMovement or IsPedInCover(ped)
            restrictedMovement = restrictedMovement or IsPedInMeleeCombat(ped)

            if restrictedMovement then canProspect = false end
            if canProspect then
                local pos = GetEntityCoords(ped) + vector3(GetEntityForwardX(ped) * 0.75, GetEntityForwardY(ped) * 0.75, -0.75)

                -- local pos = GetWorldPositionOfEntityBone(scannerEntity, 0)
                local target, dist, index, difficulyModifier = getClosestTarget(pos)
                if index then
                    local dist = dist * difficulyModifier
                    if dist < 3.0 then
                        -- SetInstructionalButton(CONTROLS["dig"]["label"], CONTROLS["dig"]["control"], true)
                        -- ShowFloatingHelp(CONTROLS["dig_hint"]["label"], pos)
                        if IsDisabledControlJustPressed(0, CONTROLS["dig"]["control"]) then
                            DigTarget(index)
                        end
                    else

                        -- SetInstructionalButton(CONTROLS["dig"]["label"], CONTROLS["dig"]["control"], false)
                    end
                    if dist < 3.0 then
                        circleScale = 0.0
                        scannerScale = 0.0
                        scannerState = "ultra"
                    elseif dist < 4.0 then
                        scannerFrametime = 0.35
                        scannerScale = 4.50
                        scannerState = "fast"
                    elseif dist < 5.0 then
                        scannerFrametime = 0.4
                        scannerScale = 3.75
                        scannerState = "fast"
                    elseif dist < 6.5 then
                        scannerFrametime = 0.425
                        scannerScale = 3.00
                        scannerState = "fast"
                    elseif dist < 7.5 then
                        scannerFrametime = 0.45
                        scannerScale = 2.50
                        scannerState = "fast"
                    elseif dist < 10.0 then
                        scannerFrametime = 0.5
                        scannerScale = 1.75
                        scannerState = "fast"
                    elseif dist < 12.5 then
                        scannerFrametime = 0.75
                        scannerScale = 1.25
                        scannerState = "medium"
                    elseif dist < 15.0 then
                        scannerFrametime = 1.0
                        scannerScale = 1.00
                        scannerState = "medium"
                    elseif dist < 20.0 then
                        scannerFrametime = 1.25
                        scannerScale = 0.875
                        scannerState = "medium"
                    elseif dist < 25.0 then
                        scannerFrametime = 1.5
                        scannerScale = 0.75
                        scannerState = "slow"
                    elseif dist < 30.0 then
                        scannerFrametime = 2.0
                        scannerScale = 0.5
                        scannerState = "slow"
                    else
                        circleScale = 0.0
                        scannerScale = 0.0
                        scannerState = "none"
                    end
                    scannerDistance = dist
                else
                    circleScale = 0.0
                    scannerScale = 0.0
                    scannerState = "none"
                end
                -- SetInstructionalButton(CONTROLS["stop"]["label"], CONTROLS["stop"]["control"], true)
                if IsDisabledControlJustPressed(0, CONTROLS["stop"]["control"]) then
                    isProspecting = false
                end
                if IsDisabledControlJustPressed(0, CONTROLS["audio_on"]["control"]) then
                    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0)
                    scannerAudio = not scannerAudio
                end
            end
            if not canProspect then
                -- Ped is busy and can't prospect at this time (like falling or w/e)
                StopEntityAnim(ped, "wood_idle_a", "mini@golfai", true)
                circleScale = 0.0
                scannerScale = 0.0
                scannerState = "none"
            end
            if not isProspecting then
                -- We stopped prospecting mid-frame
                CleanupModels()
                StopEntityAnim(ped, "wood_idle_a", "mini@golfai", true)
                circleScale = 0.0
                scannerScale = 0.0
                scannerState = "none"
            end
        end
        DisableAllInstructions()
        StopProspecting()
    end)

    -- Marker rendering
    -- Audio
    CreateThread(function()
        local framecount = 0
        local frametime = 0
        local circleScale = 0.0
        local circleR, circleG, circleB, circleA = 255, 255, 255, 255
        local _circleR, _circleG, _circleB = 255, 255, 255
        local circleScaleMultiplier = 1.5
        local renderCircle = false
        while isProspecting do
            Wait(0)
            if not pauseProspecting then
                local ped = PlayerPedId()
                local pos = GetEntityCoords(ped) + vector3(GetEntityForwardX(ped) * 0.75, GetEntityForwardY(ped) * 0.75, -0.75)
                -- local pos = GetWorldPositionOfEntityBone(scannerEntity, 0)
                if scannerState == "none" then
                    renderCircle = false
                    circleR, circleG, circleB = 150, 255, 150
                    _circleR, _circleG, _circleB = 150, 255, 150
                    if Config.ShowDrawMaker then
                        circleSize = (circleScale % 100) / 100
                        circleA = math.floor(255 - ((circleScale % 100) / 100) * 255)
                        DrawMarker(1, pos, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, circleSize, circleSize, 0.1, circleR, circleG, circleB, circleA)
                    end
                elseif scannerState == "slow" then
                    renderCircle = true
                    circleScale = circleScale + scannerScale
                    circleR, circleG, circleB = 150, 255, 150
                    if frametime > scannerFrametime then
                        frametime = 0.0
                    end
                    if Config.ShowDrawMaker then
                        circleSize = (circleScale % 100) / 100
                        circleA = math.floor(255 - ((circleScale % 100) / 100) * 255)
                        DrawMarker(1, pos, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, circleSize, circleSize, 0.1, circleR, circleG, circleB, circleA)
                    end
                elseif scannerState == "medium" then
                    renderCircle = true
                    circleScale = circleScale + scannerScale
                    circleR, circleG, circleB = 255, 255, 150
                    if frametime > scannerFrametime then
                        frametime = 0.0
                    end
                elseif scannerState == "fast" then
                    renderCircle = true
                    circleScale = circleScale + scannerScale
                    circleR, circleG, circleB = 255, 150, 150
                    if frametime > scannerFrametime then
                        frametime = 0.0
                    end
                elseif scannerState == "ultra" then
                    renderCircle = false
                    circleScale = circleScale + scannerScale
                    circleR, circleG, circleB = 255, 100, 100
                    if frametime > 0.125 then
                        frametime = 0.0
                        if scannerAudio then PlaySoundFrontend(-1, "ATM_WINDOW", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0) end
                        -- PlaySoundFrontend(-1, "TIMER_STOP", "HUD_MINI_GAME_SOUNDSET", 0)
                        if scannerAudio then PlaySoundFrontend(-1, "BOATS_PLANES_HELIS_BOOM", "MP_LOBBY_SOUNDS", 0) end
                    end
                    if Config.ShowDrawMaker then
                        circleA = 150
                        circleSize = 1.20 * circleScaleMultiplier
                        DrawMarker(1, pos, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, circleSize, circleSize, 0.2, circleR, circleG, circleB, circleA)
                        DrawMarker(6, pos, 0.0, 0.0, 0.0, 270.0, 0.0, 0.0, circleSize, 0.1, circleSize, circleR, circleG, circleB, circleA)
                        circleA = 200
                        circleSize = 0.70 * circleScaleMultiplier
                        DrawMarker(1, pos, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, circleSize, circleSize, 0.2, circleR, circleG, circleB, circleA)
                        DrawMarker(6, pos, 0.0, 0.0, 0.0, 270.0, 0.0, 0.0, circleSize, 0.1, circleSize, circleR, circleG, circleB, circleA)
                        circleA = 255
                        circleSize = 0.20 * circleScaleMultiplier
                        DrawMarker(1, pos, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, circleSize, circleSize, 0.2, circleR, circleG, circleB, circleA)
                        DrawMarker(6, pos, 0.0, 0.0, 0.0, 270.0, 0.0, 0.0, circleSize, 0.1, circleSize, circleR, circleG, circleB, circleA)
                    end
                end
                if renderCircle then
                    if circleScale > 100 then
                        while circleScale > 100 do
                            circleScale = circleScale - 100
                        end
                        _circleR, _circleG, _circleB = circleR, circleG, circleB
                        -- PlaySoundFrontend(-1, "BOATS_PLANES_HELIS_BOOM", "MP_LOBBY_SOUNDS", 0)
                        if scannerAudio then PlaySoundFrontend(-1, "ATM_WINDOW", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0) end
                        
                    end
                    if Config.ShowDrawMaker then
                        circleSize = ((circleScale % 100) / 100) * circleScaleMultiplier
                        circleA = math.floor(255 - ((circleScale % 100) / 100) * 155)
                        DrawMarker(1, pos, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, circleSize, circleSize, 0.2, _circleR, _circleG, _circleB, circleA)
                        DrawMarker(6, pos, 0.0, 0.0, 0.0, 270.0, 0.0, 0.0, circleSize, 0.1, circleSize, _circleR, _circleG, _circleB, circleA)
                    end
                end

                framecount = (framecount + 1) % 120
                frametime = frametime + Timestep()
            end
        end
    end)

    -- Location updater
    -- Adds nearby targets to the target pool
    -- Prevents client from doing frame-checks on targets across the map
    CreateThread(function()
        while isProspecting do
            local pos = GetEntityCoords(PlayerPedId())
            local newTargets = {}
            for n, target in next, targetPool do
                if #(pos.xy - target[1].xy) < maxTargetRange then
                    newTargets[#newTargets + 1] = {target[1], target[2], n}
                end
            end
            targets = newTargets
            Wait(10000)
        end
    end)
    return true
end


CreateThread(function()
    if Config.ShowBlip then
        for _, zone in next, Config.Zones do
            local blip = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, zone.zoneSize * 1.0) 
            SetBlipColour(blip, 1)
            SetBlipAlpha(blip, 55)

            local blip2 = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
            SetBlipSprite(blip2, 485)
            SetBlipColour(blip2, 0)
            SetBlipAlpha(blip2, 128)
            SetBlipAsShortRange(blip2, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString("Prospecting")
            EndTextCommandSetBlipName(blip2)
        end
    end
end)