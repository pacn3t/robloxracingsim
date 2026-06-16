-- Roblox: Infernobl1tz - Discord: infernotheguy

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RaceState         = require(script.Parent.RaceState)

-- =====================
--       REMOTES
-- =====================
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function makeRemote(name)
    local r = Instance.new("RemoteEvent")
    r.Name   = name
    r.Parent = Remotes
    return r
end

-- creating all the remotes we'll need for client-server communication
-- these are super important because almost everything the player sees or interacts with
-- has to be synced back to the server or pushed to clients.
local LapUpdate          = makeRemote("LapUpdate")
local ItemPickedUp       = makeRemote("ItemPickedUp")
local UseItem            = makeRemote("UseItem")
local HitCheckpoint      = makeRemote("HitCheckpoint")
local HitFinishLine      = makeRemote("HitFinishLine")
local HitItemBox         = makeRemote("HitItemBox")
local ShowNextCheckpoint = makeRemote("ShowNextCheckpoint")
local CountdownUpdate    = makeRemote("CountdownUpdate")
local RaceStarted        = makeRemote("RaceStarted")
local RaceEnded          = makeRemote("RaceEnded")
local RaceReset          = makeRemote("RaceReset")
local RestartRace        = makeRemote("RestartRace")

-- =====================
--       CONFIG
-- =====================
local TOTAL_LAPS        = 3
local ITEM_RESPAWN_TIME = 10
local ITEM_TYPES        = { "SpeedBoost", "Shield" }

local rng = Random.new()

-- =====================
--    CREATE FOLDERS
-- =====================
-- We make sure the Track folder exists (or create it). This keeps everything organized
-- and makes it easier to clean up or find things in Studio later.
local trackFolder = workspace:FindFirstChild("Track")
if not trackFolder then
    trackFolder      = Instance.new("Folder")
    trackFolder.Name = "Track"
    trackFolder.Parent = workspace
end

local checkpointsFolder = trackFolder:FindFirstChild("Checkpoints")
if not checkpointsFolder then
    checkpointsFolder        = Instance.new("Folder")
    checkpointsFolder.Name   = "Checkpoints"
    checkpointsFolder.Parent = trackFolder
end

local itemsFolder = trackFolder:FindFirstChild("Items")
if not itemsFolder then
    itemsFolder        = Instance.new("Folder")
    itemsFolder.Name   = "Items"
    itemsFolder.Parent = trackFolder
end

-- =====================
--  CREATE CHECKPOINTS
-- =====================
local kartBody = workspace.Karts.Kart:WaitForChild("Body")
local origin   = kartBody.Position   -- Using the starting kart position as our origin point

-- These checkpoint definitions are what actually define the track layout.
-- Changing positions/sizes here directly changes the race path.
local cpDefs = {
    { name = "CP1",       pos = origin + Vector3.new(0,   4, 150), size = Vector3.new(30,15,2),  color = Color3.fromRGB(255,220,0)   },
    { name = "CP2",       pos = origin + Vector3.new(150, 4, 150), size = Vector3.new(2, 15,30), color = Color3.fromRGB(255,140,0)   },
    { name = "CP3",       pos = origin + Vector3.new(150, 4, 20),  size = Vector3.new(30,15,2),  color = Color3.fromRGB(255,80,0)    },
    { name = "FinishLine",pos = origin + Vector3.new(0,   4, -20), size = Vector3.new(30,15,2),  color = Color3.fromRGB(0,255,100)   },
}

local TOTAL_CPS = #cpDefs - 1   -- Important: we subtract 1 because the last one is the finish line, not a normal checkpoint

for _, def in ipairs(cpDefs) do
    local part        = Instance.new("Part")
    part.Name         = def.name
    part.Size         = def.size
    part.CFrame       = CFrame.new(def.pos)
    part.Color        = def.color
    part.Transparency = 1          -- invisible trigger zones - players shouldn't see the actual parts
    part.Anchored     = true
    part.CanCollide   = false
    part.Material     = Enum.Material.Neon
    part.CastShadow   = false
    part.Parent       = checkpointsFolder
end

-- =====================
--    CREATE ITEM BOXES
-- =====================
local itemPositions = {
    origin + Vector3.new(0,   4, 85),
    origin + Vector3.new(75,  4, 150),
    origin + Vector3.new(150, 4, 85),
    origin + Vector3.new(75,  4, 20),
}

local itemBoxList = {}

for _, pos in ipairs(itemPositions) do
    local box        = Instance.new("Part")
    box.Name         = "ItemBox"
    box.Size         = Vector3.new(5, 5, 5)
    box.CFrame       = CFrame.new(pos)
    box.Color        = Color3.fromRGB(0, 200, 255)
    box.Transparency = 0.3
    box.Anchored     = true
    box.CanCollide   = false
    box.Material     = Enum.Material.Neon
    box.CastShadow   = false
    box.Parent       = itemsFolder
    table.insert(itemBoxList, box)
end

print("Track ready — " .. TOTAL_CPS .. " checkpoints")

-- =====================
--     PLAYER DATA
-- =====================
local playerData = {}

Players.PlayerAdded:Connect(function(player)
    playerData[player] = {
        nextCP   = 1,      -- Tracks which checkpoint the player should hit next
        lap      = 1,
        finished = false,
        hasItem  = false,
    }
    
    -- Small delay so the client has time to load before we tell it what to show
    task.delay(3, function()
        ShowNextCheckpoint:FireClient(player, 1)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    playerData[player] = nil   -- Clean up memory when someone leaves
end)

-- =====================
--  FINISH POSITION
-- =====================
local function getFinishPosition(player)
    local totalWPs    = RaceState.totalWaypoints or 9 
    local playerTotal = TOTAL_LAPS * totalWPs + (TOTAL_CPS + 1)
    local position    = 1

    -- Compare against every AI kart to figure out where the player placed
    -- who crossed the line first in a simple order (handles lapping etc.)
    for _, ai in ipairs(RaceState.aiKarts) do
        local aiTotal = (ai.lap - 1) * totalWPs + ai.waypointIndex
        if aiTotal > playerTotal then
            position = position + 1
        end
    end

    return position
end

local function formatTime(seconds)
    local m  = math.floor(seconds / 60)
    local s  = math.floor(seconds % 60)
    local ms = math.floor((seconds % 1) * 100)
    return string.format("%d:%02d.%02d", m, s, ms)
end

-- =====================
--      COUNTDOWN
-- =====================
local function startCountdown()
    task.wait(3)
    for count = 3, 1, -1 do
        CountdownUpdate:FireAllClients(count)
        task.wait(1)
    end
    CountdownUpdate:FireAllClients(0)
    task.wait(0.5)
    
    -- only now do we officially start the race, this timing prevents players from
    -- moving during the countdown sequence
    RaceState.active        = true
    RaceState.raceStartTime = os.clock()
    RaceStarted:FireAllClients()
    print("Race started!")
end

task.wait(5)
startCountdown()

-- =====================
--  CHECKPOINT HANDLER
-- =====================
HitCheckpoint.OnServerEvent:Connect(function(player, cpIndex)
    local data = playerData[player]
    if not data or data.finished then return end

    -- Only progress if they're hitting the exact checkpoint they're supposed to
    -- This stops people from skipping or hitting them out of order
    if data.nextCP == cpIndex then
        data.nextCP = cpIndex + 1
        print(player.Name .. " hit CP" .. cpIndex)

        if data.nextCP > TOTAL_CPS then
            ShowNextCheckpoint:FireClient(player, "finish")
        else
            ShowNextCheckpoint:FireClient(player, data.nextCP)
        end
    end
end)

-- =====================
--  FINISH LINE HANDLER
-- =====================
HitFinishLine.OnServerEvent:Connect(function(player)
    local data = playerData[player]
    if not data or data.finished then return end
    if data.nextCP <= TOTAL_CPS then return end   -- Must hit all checkpoints first

    data.lap    = data.lap + 1
    data.nextCP = 1

    local finished = data.lap > TOTAL_LAPS
    if finished then
        data.lap      = TOTAL_LAPS
        data.finished = true

        local raceTime = os.clock() - RaceState.raceStartTime
        local position = getFinishPosition(player)
        local timeStr  = formatTime(raceTime)

        print(player.Name .. " finished in position " .. position .. " — " .. timeStr)

        -- Ending the race for everyone once someone finishes feels better in small lobbies
        RaceState.active = false
        RaceEnded:FireAllClients(position, timeStr)
        return
    end

    print(player.Name .. " completed lap " .. data.lap)
    LapUpdate:FireClient(player, data.lap, TOTAL_LAPS, false)

    if not finished then
        ShowNextCheckpoint:FireClient(player, 1)
    end
end)

-- =====================
--   ITEM BOX HANDLER
-- =====================
HitItemBox.OnServerEvent:Connect(function(player, boxIndex)
    local data = playerData[player]
    if not data or data.hasItem then return end   -- One item at a time

    local box = itemBoxList[boxIndex]
    if not box or box.Transparency >= 0.9 then return end

    local item   = ITEM_TYPES[rng:NextInteger(1, #ITEM_TYPES)]
    data.hasItem = true
    ItemPickedUp:FireClient(player, item)

    -- Visual feedback + respawn timer
    box.Transparency = 1
    task.delay(ITEM_RESPAWN_TIME, function()
        box.Transparency = 0.3
    end)
end)

-- =====================
--    USE ITEM HANDLER
-- =====================
UseItem.OnServerEvent:Connect(function(player)
    local data = playerData[player]
    if data then 
        data.hasItem = false   -- clear the item once used
    end
end)

-- =====================
--    RESTART HANDLER
-- =====================
RestartRace.OnServerEvent:Connect(function()
    print("Restarting race...")

    RaceState.active = false

    -- Reset the main kart
    kartBody.CFrame = CFrame.new(origin)

    -- Reset all AI karts to starting positions
    for _, ai in ipairs(RaceState.aiKarts) do
        ai.body.CFrame   = CFrame.new(ai.startPosition)
        ai.waypointIndex = 1
        ai.lap           = 1
    end

    -- Bring all item boxes back
    for _, box in ipairs(itemBoxList) do
        box.Transparency = 0.3
    end

    -- Reset every player's progress
    for player, data in pairs(playerData) do
        data.nextCP   = 1
        data.lap      = 1
        data.finished = false
        data.hasItem  = false
        ShowNextCheckpoint:FireClient(player, 1)
    end

    RaceReset:FireAllClients()

    startCountdown()
end)
