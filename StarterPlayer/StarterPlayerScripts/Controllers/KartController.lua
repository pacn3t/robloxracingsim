local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KartState         = require(ReplicatedStorage.Modules.KartState)

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")

local SPEED         = 40
local REVERSE_SPEED = 20
local ACCELERATION  = 8
local FRICTION      = 6
local TURN_SPEED    = 2.2

local kart         = nil
local body         = nil
local currentSpeed = 0
local facingAngle  = 0
local groundY      = nil

local kartModel = workspace.Karts.Kart
local seat      = kartModel:WaitForChild("Seat")

local Remotes     = ReplicatedStorage:WaitForChild("Remotes")
local RaceStarted = Remotes:WaitForChild("RaceStarted")
local RaceEnded   = Remotes:WaitForChild("RaceEnded")
local RaceReset   = Remotes:WaitForChild("RaceReset")

-- =====================
--    AUTO-SIT ON JOIN
-- =====================
task.wait(1)
seat:Sit(humanoid)

-- =====================
--   RACE EVENT HOOKS
-- =====================
RaceStarted.OnClientEvent:Connect(function()
	KartState.raceStarted = true
end)

RaceEnded.OnClientEvent:Connect(function()
	KartState.raceStarted = false
	currentSpeed          = 0
end)

RaceReset.OnClientEvent:Connect(function()
	KartState.raceStarted  = false
	KartState.currentLap   = 1
	KartState.currentItem  = nil
	KartState.speedMultiplier = 1
	currentSpeed           = 0

	task.wait(0.5)
	seat:Sit(humanoid)
end)

-- =====================
--    SEAT DETECTION
-- =====================
humanoid.Seated:Connect(function(isSeated, activeSeat)
	if isSeated and activeSeat.Parent:FindFirstChild("Body") then
		kart        = activeSeat.Parent
		body        = kart.Body
		groundY     = body.Position.Y
		facingAngle = math.atan2(
			body.CFrame.LookVector.X,
			body.CFrame.LookVector.Z
		)
		KartState.body     = body
		KartState.isInKart = true
	else
		kart                   = nil
		body                   = nil
		currentSpeed           = 0
		KartState.body         = nil
		KartState.isInKart     = false
		KartState.currentSpeed = 0

		if KartState.raceStarted then
			task.delay(1.5, function()
				if not KartState.isInKart then
					seat:Sit(humanoid)
				end
			end)
		end
	end
end)

-- =====================
--      MAIN LOOP
-- =====================
RunService.Heartbeat:Connect(function(dt)
	if not body or not kart then return end
	if not KartState.raceStarted then return end

	local w = UserInputService:IsKeyDown(Enum.KeyCode.W)
	local s = UserInputService:IsKeyDown(Enum.KeyCode.S)
	local a = UserInputService:IsKeyDown(Enum.KeyCode.A)
	local d = UserInputService:IsKeyDown(Enum.KeyCode.D)

	local maxSpeed = SPEED * KartState.speedMultiplier

	if w then
		currentSpeed = math.min(currentSpeed + ACCELERATION * dt, maxSpeed)
	elseif s then
		currentSpeed = math.max(currentSpeed - ACCELERATION * dt, -REVERSE_SPEED)
	else
		if currentSpeed > 0 then
			currentSpeed = math.max(currentSpeed - FRICTION * dt, 0)
		elseif currentSpeed < 0 then
			currentSpeed = math.min(currentSpeed + FRICTION * dt, 0)
		end
	end

	if math.abs(currentSpeed) > 1 then
		local turnDirection = 0
		if a then turnDirection =  1 end
		if d then turnDirection = -1 end

		local reverseMultiplier = currentSpeed > 0 and 1 or -1
		facingAngle = facingAngle + turnDirection * TURN_SPEED * dt * reverseMultiplier
	end

	local moveDirection = Vector3.new(math.sin(facingAngle), 0, math.cos(facingAngle))
	local newPosition   = body.Position - moveDirection * currentSpeed * dt
	newPosition         = Vector3.new(newPosition.X, groundY, newPosition.Z)

	body.CFrame            = CFrame.lookAt(newPosition, newPosition + moveDirection)
	KartState.currentSpeed = currentSpeed
end)
