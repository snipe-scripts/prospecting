QBCore = exports["qb-core"]:GetCoreObject()

local DEBUG = false
local function debugLog() end
if DEBUG then debugLog = function(...)
    print(...)
end end

local PROSPECTING_STATUS = {}
local PROSPECTING_TARGETS = {}

-- Multiplier for distance to check
-- 1.0 is default, allows ~3m around target
-- 2.0 allows ~1.5m around target
-- 10.0 allows ~0.3m around target
-- Alters all distance checks, so higher means you need to be closer to the target to get a signal
-- Each controller resource can define their own difficulty
local PROSPECTING_DIFFICULTIES = {}

--[[ Common ]]
function UpdateProspectingTargets(player)
    local targets = {}
    for _, target in next, PROSPECTING_TARGETS do
        local difficulty = PROSPECTING_DIFFICULTIES[target.resource] or 1.0
        targets[#targets + 1] = {target.x, target.y, target.z, difficulty}
    end
    debugLog("new targets", json.encode(targets))
    TriggerClientEvent("prospecting:setTargetPool", player, targets)
end

function InsertProspectingTarget(resource, x, y, z, data)
    PROSPECTING_TARGETS[#PROSPECTING_TARGETS + 1] = {resource = resource, data = data, x = x, y = y, z = z}
end

function InsertProspectingTargets(resource, targets)
    for _, target in next, targets do
        InsertProspectingTarget(resource, target.x, target.y, target.z, target.data)
    end
    -- UpdateProspectingTargets(-1)
end

function RemoveProspectingTarget(index)
    local new_targets = {}
    for n, target in next, PROSPECTING_TARGETS do
        if n ~= index then
            new_targets[#new_targets + 1] = target
        end
    end
    PROSPECTING_TARGETS = new_targets
    UpdateProspectingTargets(-1)
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
    debugLog("pickup", player, "idx", index, "pos", x, y, z)
    local target = PROSPECTING_TARGETS[index]
    if target then
        local dx, dy, dz = target.x, target.y, target.z
        local resource, data = target.resource, target.data
        if math.floor(dx) == math.floor(x) and math.floor(dy) == math.floor(y) and math.floor(dz) == math.floor(z) then
            debugLog("pickup matches")
            RemoveProspectingTarget(index)
            TriggerEvent("prospecting:onCollected", player, resource, data, x, y, z)
        else
            debugLog("pickup does not match")
            local newMatch = FindMatchingPickup(x, y, z)
            if newMatch then
                HandleProspectingPickup(player, newMatch, x, y, z)
            end
        end
    else
        debugLog("target does not exist?")
    end
end

RegisterServerEvent("prospecting:onCollected")
AddEventHandler("prospecting:onCollected", function(player, resource, data, x, y, z)
    local player = 6
    local data = "loc1"
    local player = player
    local Player = QBCore.Functions.GetPlayer(player)
    local items = {}
    local randomizer = math.random(1, 100)
    if randomizer < 5 then
        items = Config.Items[data]["rare"] or Config.DefaultItems
    elseif randomizer < 15 and randomizer > 5 then
        items = Config.Items[data]["epic"] or Config.DefaultItems
    else
        items = Config.Items[data]["common"] or Config.DefaultItems
    end
    local item = items[math.random(1, #items)]
    local amount = math.random(item.min, item.max)
    Player.Functions.AddItem(item.name, amount)
    TriggerClientEvent("inventory:client:ItemBox", player, QBCore.Shared.Items[item.name], "add")
end)

--[[ Export handling ]]

function AddProspectingTarget(x, y, z, data)
    local resource = GetInvokingResource()
    debugLog("adding prospecting target at", vector3(x, y, z), "with data", data)
    InsertProspectingTarget(resource, x, y, z, data)
end
AddEventHandler("prospecting:AddProspectingTarget", function(x, y, z, data)
    AddProspectingTarget(x, y, z, data)
end)

function AddProspectingTargets(list)
    local resource = GetInvokingResource()
    debugLog("adding prospecting targets")
    InsertProspectingTargets(resource, list)
    
end
AddEventHandler("prospecting:AddProspectingTargets", function(list)
    AddProspectingTargets(list)
end)

function StartProspecting(player)
    if not PROSPECTING_STATUS[player] then
        debugLog("forcing", player, "to start")
        TriggerClientEvent("prospecting:forceStart", player)
    end
end
AddEventHandler("prospecting:StartProspecting", function(player)
    StartProspecting(player)
end)

function StopProspecting(player)
    if PROSPECTING_STATUS[player] then
        debugLog("forcing", player, "to stop")
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
RegisterServerEvent("prospecting:userCollectedNode")
AddEventHandler("prospecting:userCollectedNode", function(index, x, y, z)
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
    QBCore.Functions.CreateUseableItem("prop_chain", function(source, item)
        local Player = QBCore.Functions.GetPlayer(source)
        if Player.Functions.GetItemByName(item.name) ~= nil then
            if Prospecting.IsProspecting(source) then
                Prospecting.StopProspecting(source)
            else
                Prospecting.StartProspecting(source)
            end
        end
    end)
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
    print(json.encode(coordslist))
    AddProspectingTargets(coordslist)
end