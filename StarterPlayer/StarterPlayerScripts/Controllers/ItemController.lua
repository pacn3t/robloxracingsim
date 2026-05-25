local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KartState         = require(ReplicatedStorage.Modules.KartState)

local player   = Players.LocalPlayer
local Remotes  = ReplicatedStorage:WaitForChild("Remotes")

local ItemPickedUp = Remotes:WaitForChild("ItemPickedUp")
local UseItem      = Remotes:WaitForChild("UseItem")

local BOOST_MULTIPLIER = 2
local BOOST_DURATION   = 5
local SHIELD_DURATION  = 10

ItemPickedUp.OnClientEvent:Connect(function(itemType)
	KartState.currentItem = itemType
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.F then return end
	if not KartState.isInKart then return end
	if not KartState.currentItem then return end

	local item            = KartState.currentItem
	KartState.currentItem = nil
	UseItem:FireServer()

	if item == "SpeedBoost" then
		KartState.speedMultiplier = BOOST_MULTIPLIER
		task.delay(BOOST_DURATION, function()
			KartState.speedMultiplier = 1
		end)

	elseif item == "Shield" then
		KartState.shieldActive = true
		task.delay(SHIELD_DURATION, function()
			KartState.shieldActive = false
		end)
	end
end)
