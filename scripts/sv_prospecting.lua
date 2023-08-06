-----------------For support, scripts, and more----------------
--------------- https://discord.gg/VGYkkAYVv2  -------------
---------------------------------------------------------------

QBCore, ESX = nil, nil

if Config.Core == "QBCore" then
    QBCore = exports['qb-core']:GetCoreObject()
elseif Config.Core == "ESX" then
    ESX = exports['es_extended']:getSharedObject()
end

local PROSPECTING_STATUS = {}
local PROSPECTING_TARGETS = {}

local PROSPECTING_DIFFICULTIES = {}

--[[ Common ]]
function UpdateProspectingTargets(player)
    local targets = {}
    for _, target in next, PROSPECTING_TARGETS do
        local difficulty = PROSPECTING_DIFFICULTIES[target.resource] or 1.0
        targets[#targets + 1] = {target.x, target.y, target.z, difficulty}
    end
    TriggerClientEvent("prospecting:setTargetPool", player, targets)
end

function InsertProspectingTarget(resource, x, y, z, data)
    PROSPECTING_TARGETS[#PROSPECTING_TARGETS + 1] = {resource = resource, data = data, x = x, y = y, z = z}
end

function InsertProspectingTargets(resource, targets)
    for _, target in next, targets do
        InsertProspectingTarget(resource, target.x, target.y, target.z, target.data)
    end
end

local function RemoveTargetIndex(coords)
    for index, target in next, PROSPECTING_TARGETS do
        local dx, dy, dz = target.x, target.y, target.z
        if math.floor(dx) == math.floor(coords.x) and math.floor(dy) == math.floor(coords.y) and math.floor(dz) == math.floor(coords.z) then
            table.remove(PROSPECTING_TARGETS, index)
            break
        end
    end
end

function RemoveProspectingTarget(coords)
    RemoveTargetIndex(coords)
    TriggerClientEvent("prospecting:client:removeTarget", -1, coords)
end

function FindMatchingPickup(x, y, z)
    for index, target in next, PROSPECTING_TARGETS do
        local dx, dy, dz = target.x, target.y, target.z
        if math.floor(dx) == math.floor(x) and math.floor(dy) == math.floor(y) and math.floor(dz) == math.floor(z) then
            return index
        end
    end
    return nil
end

function HandleProspectingPickup(player, index, x, y, z)
    local target = PROSPECTING_TARGETS[index]
    if target then
        local dx, dy, dz = target.x, target.y, target.z
        local resource, data = target.resource, target.data
        if math.floor(dx) == math.floor(x) and math.floor(dy) == math.floor(y) and math.floor(dz) == math.floor(z) then
            RemoveProspectingTarget(vec3(x, y, z))
            OnCollected(player, resource, data, x, y, z)
        else
            local newMatch = FindMatchingPickup(x, y, z)
            if newMatch then
                HandleProspectingPickup(player, newMatch, x, y, z)
            end
        end
    else
    end
end

local function AddItem(id, name, amount)
    if Config.Core == "QBCore" then
        local Player = QBCore.Functions.GetPlayer(id)
        Player.Functions.AddItem(name, amount)
        TriggerClientEvent("inventory:client:ItemBox", id, QBCore.Shared.Items[name], "add")
    elseif Config.Core == "ESX" then
        local xPlayer = ESX.GetPlayerFromId(id)
        xPlayer.addInventoryItem(name, amount)
    end
end

function OnCollected(player, resource, data, x, y, z)
    
    local items = {}
    math.randomseed(os.time())
    local randomizer = math.random(1, 100)
    if randomizer < Config.Chances.epic then
        items = Config.Items[data]["epic"] or Config.DefaultItems
    elseif randomizer < Config.Chances.rare and randomizer > Config.Chances.epic then
        items = Config.Items[data]["rare"] or Config.DefaultItems
    else
        items = Config.Items[data]["common"] or Config.DefaultItems
    end
    local item = items[math.random(1, #items)]
    local amount = math.random(item.min, item.max)
    AddItem(player, item.name, amount)
end

--[[ Export handling ]]

function AddProspectingTarget(x, y, z, data)
    local resource = GetInvokingResource()
    InsertProspectingTarget(resource, x, y, z, data)
end

function AddProspectingTargets(list)
    local resource = GetInvokingResource()
    InsertProspectingTargets(resource, list)
    
end

function StartProspecting(player)
    if not PROSPECTING_STATUS[player] then
        TriggerClientEvent("prospecting:forceStart", player)
    end
end
AddEventHandler("prospecting:StartProspecting", function(player)
    StartProspecting(player)
end)

function StopProspecting(player)
    if PROSPECTING_STATUS[player] then
        TriggerClientEvent("prospecting:forceStop", player)
    end
end
AddEventHandler("prospecting:StopProspecting", function(player)
    StopProspecting(player)
end)

function IsProspecting(player)
    return PROSPECTING_STATUS[player] ~= nil
end

function SetDifficulty(modifier)
    local resource = GetInvokingResource()
    PROSPECTING_DIFFICULTIES[resource] = modifier
end

--[[ Client triggered events ]]

-- When the client stops prospecting
RegisterServerEvent("prospecting:userStoppedProspecting")
AddEventHandler("prospecting:userStoppedProspecting", function()
    local player = source
    if PROSPECTING_STATUS[player] then
        local time = GetGameTimer() - PROSPECTING_STATUS[player]
        PROSPECTING_STATUS[player] = nil
        TriggerEvent("prospecting:onStop", player, time)
    end
end)

-- When the client starts prospecting
RegisterServerEvent("prospecting:userStartedProspecting")
AddEventHandler("prospecting:userStartedProspecting", function()
    local player = source
    if not PROSPECTING_STATUS[player] then
        PROSPECTING_STATUS[player] = GetGameTimer()
        TriggerEvent("prospecting:onStart", player)
    end
end)

-- When the client collects a node
-- RegisterServerEvent("prospecting:userCollectedNode")
-- AddEventHandler("prospecting:userCollectedNode", function(index, x, y, z)
lib.callback.register("prospecting:userCollectedNode", function(source, index, x, y, z)
    local player = source
    if PROSPECTING_STATUS[player] then
        HandleProspectingPickup(player, index, x, y, z)
    end
end)

RegisterServerEvent("prospecting:userRequestsLocations")
AddEventHandler("prospecting:userRequestsLocations", function()
    local player = source
    UpdateProspectingTargets(player)
end)

-- thread to setup prospecting target at server start

--command to start and stop prospecting

CreateThread(function()
    if Config.Core == "QBCore" then
        QBCore.Functions.CreateUseableItem(Config.DetectorItem, function(source, item)
            if Prospecting.IsProspecting(source) then
                Prospecting.StopProspecting(source)
            else
                Prospecting.StartProspecting(source)
            end
            
        end)
    elseif Config.Core == "ESX" then
        ESX.RegisterUsableItem(Config.DetectorItem, function(source)
            if Prospecting.IsProspecting(source) then
                Prospecting.StopProspecting(source)
            else
                Prospecting.StartProspecting(source)
            end
        end)
    end
end)


CreateThread(function()
    for k, v in pairs(Config.Zones) do
        GenerateCoords(v.coords, v.data, v.zoneSize, v.zoneLocations)
    end
end)


function GenerateCoords(coords, data, zoneSize, zoneLocations)
    local coordslist = {}
    local totalLocationsForOneCoord = zoneLocations
	while totalLocationsForOneCoord > 0 do
        totalLocationsForOneCoord = totalLocationsForOneCoord - 1

		local coordX, coordY

		local modX = math.random(-zoneSize, zoneSize)


		local modY = math.random(-zoneSize, zoneSize)

		coordX = coords.x + modX
		coordY = coords.y + modY
		coordslist[#coordslist + 1] = {x = coordX, y = coordY, z = coords.z, data = data}
	end
    AddProspectingTargets(coordslist)
end