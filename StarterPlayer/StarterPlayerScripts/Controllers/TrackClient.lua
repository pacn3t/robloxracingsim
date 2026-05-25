local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KartState         = require(ReplicatedStorage.Modules.KartState)

local Remotes            = ReplicatedStorage:WaitForChild("Remotes")
local HitCheckpoint      = Remotes:WaitForChild("HitCheckpoint")
local HitFinishLine      = Remotes:WaitForChild("HitFinishLine")
local HitItemBox         = Remotes:WaitForChild("HitItemBox")
local ShowNextCheckpoint = Remotes:WaitForChild("ShowNextCheckpoint")

local trackFolder       = workspace:WaitForChild("Track")
local checkpointsFolder = trackFolder:WaitForChild("Checkpoints")
local itemsFolder       = trackFolder:WaitForChild("Items")

local CHECKPOINT_RADIUS = 18
local ITEM_RADIUS       = 8
local ITEM_RESPAWN_TIME = 10

local cpCooldown   = {}
local itemCooldown = {}

local checkpoints = {}
local i = 1
while true do
	local cp = checkpointsFolder:WaitForChild("CP" .. i, 5)
	if not cp then break end
	table.insert(checkpoints, cp)
	i = i + 1
end
local finishLine = checkpointsFolder:WaitForChild("FinishLine", 5)

task.wait(1)
local itemBoxes = {}
for _, box in ipairs(itemsFolder:GetChildren()) do
	if box:IsA("BasePart") then
		table.insert(itemBoxes, box)
	end
end

-- =====================
--  CHECKPOINT VISUALS
-- =====================
local function showNextCheckpoint(next)
	for _, cp in ipairs(checkpoints) do
		cp.Transparency = 0.92
	end
	if finishLine then
		finishLine.Transparency = 0.92
	end

	if next == "finish" then
		if finishLine then
			finishLine.Transparency = 0.15
		end
	else
		local cp = checkpointsFolder:FindFirstChild("CP" .. next)
		if cp then
			cp.Transparency = 0.15
		end
	end
end

ShowNextCheckpoint.OnClientEvent:Connect(function(next)
	showNextCheckpoint(next)
end)

-- =====================
--      MAIN LOOP
-- =====================
RunService.Heartbeat:Connect(function()
	if not KartState.isInKart or not KartState.body then return end

	local kartPos = KartState.body.Position

	for idx, cp in ipairs(checkpoints) do
		if not cpCooldown[idx] then
			if (kartPos - cp.Position).Magnitude < CHECKPOINT_RADIUS then
				cpCooldown[idx] = true
				HitCheckpoint:FireServer(idx)
				task.delay(4, function()
					cpCooldown[idx] = false
				end)
			end
		end
	end

	if finishLine and not cpCooldown["finish"] then
		if (kartPos - finishLine.Position).Magnitude < CHECKPOINT_RADIUS then
			cpCooldown["finish"] = true
			HitFinishLine:FireServer()
			task.delay(5, function()
				cpCooldown["finish"] = false
			end)
		end
	end

	for idx, box in ipairs(itemBoxes) do
		if not itemCooldown[idx] then
			if (kartPos - box.Position).Magnitude < ITEM_RADIUS then
				itemCooldown[idx] = true
				HitItemBox:FireServer(idx)
				task.delay(ITEM_RESPAWN_TIME, function()
					itemCooldown[idx] = false
				end)
			end
		end
	end
end)
