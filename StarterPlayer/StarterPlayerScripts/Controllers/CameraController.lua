local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KartState         = require(ReplicatedStorage.Modules.KartState)

local camera = workspace.CurrentCamera

local CAMERA_HEIGHT   = 28
local CAMERA_DISTANCE = 38
local SMOOTHING       = 0.08

RunService.Heartbeat:Connect(function()
	if not KartState.isInKart or not KartState.body then
		camera.CameraType = Enum.CameraType.Custom
		return
	end

	camera.CameraType = Enum.CameraType.Scriptable

	local body       = KartState.body
	local lookVector = body.CFrame.LookVector

	local targetPos = body.Position
		+ lookVector * CAMERA_DISTANCE
		+ Vector3.new(0, CAMERA_HEIGHT, 0)

	local smoothedPos = camera.CFrame.Position:Lerp(targetPos, SMOOTHING)

	local lookTarget = body.Position - lookVector * 12
	camera.CFrame = CFrame.new(smoothedPos, lookTarget)
end)
