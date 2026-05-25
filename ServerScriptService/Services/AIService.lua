local RunService = game:GetService("RunService")
local RaceState  = require(script.Parent.RaceState)

local checkpointsFolder = workspace:WaitForChild("Track"):WaitForChild("Checkpoints")
local cp1        = checkpointsFolder:WaitForChild("CP1")
local cp2        = checkpointsFolder:WaitForChild("CP2")
local cp3        = checkpointsFolder:WaitForChild("CP3")
local finishLine = checkpointsFolder:WaitForChild("FinishLine")
local kartBody   = workspace.Karts.Kart:WaitForChild("Body")

local groundY = kartBody.Position.Y
local origin  = kartBody.Position

local waypoints = {
	origin + Vector3.new(0, 0, 75),
	cp1.Position,
	Vector3.new((cp1.Position.X + cp2.Position.X) / 2, groundY, cp1.Position.Z),
	cp2.Position,
	Vector3.new(cp2.Position.X, groundY, (cp2.Position.Z + cp3.Position.Z) / 2),
	cp3.Position,
	Vector3.new((cp3.Position.X + finishLine.Position.X) / 2, groundY, (cp3.Position.Z + finishLine.Position.Z) / 2),
	finishLine.Position,
	origin,
}

for i, wp in ipairs(waypoints) do
	waypoints[i] = Vector3.new(wp.X, groundY, wp.Z)
end

RaceState.totalWaypoints = #waypoints

local aiDefs = {
	{ name = "Blaze", color = Color3.fromRGB(220,50,50),  speed = 30, startOffset = Vector3.new(10,0,5)  },
	{ name = "Frost", color = Color3.fromRGB(50,130,220), speed = 34, startOffset = Vector3.new(-10,0,5) },
	{ name = "Storm", color = Color3.fromRGB(160,50,220), speed = 28, startOffset = Vector3.new(0,0,10)  },
}

local aiFolder      = Instance.new("Folder")
aiFolder.Name       = "AIKarts"
aiFolder.Parent     = workspace.Karts

for _, def in ipairs(aiDefs) do
	local startPos  = origin + def.startOffset

	local body      = Instance.new("Part")
	body.Name       = "Body"
	body.Size       = Vector3.new(6, 2, 3)
	body.Color      = def.color
	body.Material   = Enum.Material.SmoothPlastic
	body.Anchored   = true
	body.CanCollide = false
	body.CastShadow = false
	body.CFrame     = CFrame.new(startPos)

	local billboard       = Instance.new("BillboardGui", body)
	billboard.Size        = UDim2.new(0, 80, 0, 25)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true

	local nameTag                  = Instance.new("TextLabel", billboard)
	nameTag.Size                   = UDim2.new(1, 0, 1, 0)
	nameTag.BackgroundTransparency = 1
	nameTag.Text                   = def.name
	nameTag.TextColor3             = Color3.fromRGB(255, 255, 255)
	nameTag.TextScaled             = true
	nameTag.Font                   = Enum.Font.GothamBold

	local model       = Instance.new("Model")
	model.Name        = def.name
	model.PrimaryPart = body
	body.Parent       = model
	model.Parent      = aiFolder

	table.insert(RaceState.aiKarts, {
		body          = body,
		waypointIndex = 1,
		lap           = 1,
		speed         = def.speed,
		baseSpeed     = def.speed,
		startPosition = startPos,
	})
end

local function getRubberbandSpeed(ai)
	local playerPos = kartBody.Position
	local gap       = (ai.body.Position - origin).Magnitude
	- (playerPos - origin).Magnitude

	if gap > 80 then return ai.baseSpeed * 0.75 end
	if gap < -80 then return ai.baseSpeed * 1.25 end
	return ai.baseSpeed
end

RunService.Heartbeat:Connect(function(dt)
	if not RaceState.active then return end

	for _, ai in ipairs(RaceState.aiKarts) do
		local targetWP = waypoints[ai.waypointIndex]
		local aiPos    = ai.body.Position
		local diff     = Vector3.new(targetWP.X - aiPos.X, 0, targetWP.Z - aiPos.Z)

		if diff.Magnitude < 8 then
			local nextIndex  = ai.waypointIndex % #waypoints + 1
			if nextIndex == 1 then
				ai.lap = ai.lap + 1
			end
			ai.waypointIndex = nextIndex
		else
			local direction = diff.Unit
			local speed     = getRubberbandSpeed(ai)
			local newPos    = aiPos + direction * speed * dt
			newPos          = Vector3.new(newPos.X, groundY, newPos.Z)
			ai.body.CFrame  = CFrame.lookAt(newPos, newPos + direction)
		end
	end
end)

print("AI ready — " .. #RaceState.aiKarts .. " karts spawned")
