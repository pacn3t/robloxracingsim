local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KartState         = require(ReplicatedStorage.Modules.KartState)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

local LapUpdate       = Remotes:WaitForChild("LapUpdate")
local CountdownUpdate = Remotes:WaitForChild("CountdownUpdate")
local RaceStarted     = Remotes:WaitForChild("RaceStarted")
local RaceEnded       = Remotes:WaitForChild("RaceEnded")
local RaceReset       = Remotes:WaitForChild("RaceReset")
local RestartRace     = Remotes:WaitForChild("RestartRace")

-- =====================
--       HELPERS
-- =====================
local function makePanel(size, position, parent)
	local frame                  = Instance.new("Frame")
	frame.Size                   = size
	frame.Position               = position
	frame.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0.4
	frame.BorderSizePixel        = 0
	frame.Parent                 = parent

	local corner        = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent       = frame
	return frame
end

local function makeLabel(text, size, position, color, parent)
	local label                  = Instance.new("TextLabel")
	label.Size                   = size
	label.Position               = position
	label.BackgroundTransparency = 1
	label.Text                   = text
	label.TextColor3             = color
	label.TextScaled             = true
	label.Font                   = Enum.Font.GothamBold
	label.Parent                 = parent
	return label
end

-- =====================
--       BUILD HUD
-- =====================
local screenGui        = Instance.new("ScreenGui")
screenGui.Name         = "HUD"
screenGui.ResetOnSpawn = false
screenGui.Enabled      = false
screenGui.Parent       = playerGui

local speedPanel = makePanel(UDim2.new(0,130,0,65), UDim2.new(0.5,-65,1,-85), screenGui)
makeLabel("SPEED", UDim2.new(1,0,0.4,0), UDim2.new(0,0,0,0),   Color3.fromRGB(180,180,180), speedPanel)
local speedValue =
	makeLabel("0",     UDim2.new(1,0,0.6,0), UDim2.new(0,0,0.4,0), Color3.fromRGB(255,255,255), speedPanel)

local lapPanel = makePanel(UDim2.new(0,130,0,65), UDim2.new(0.5,-65,0,20), screenGui)
makeLabel("LAP",   UDim2.new(1,0,0.4,0), UDim2.new(0,0,0,0),   Color3.fromRGB(180,180,180), lapPanel)
local lapValue =
	makeLabel("1 / 3", UDim2.new(1,0,0.6,0), UDim2.new(0,0,0.4,0), Color3.fromRGB(255,220,0),   lapPanel)

local itemPanel = makePanel(UDim2.new(0,150,0,65), UDim2.new(0,20,1,-85), screenGui)
makeLabel("ITEM [F]", UDim2.new(1,0,0.4,0), UDim2.new(0,0,0,0),   Color3.fromRGB(180,180,180), itemPanel)
local itemValue =
	makeLabel("--",       UDim2.new(1,0,0.6,0), UDim2.new(0,0,0.4,0), Color3.fromRGB(255,200,50),   itemPanel)

local timerPanel = makePanel(UDim2.new(0,130,0,45), UDim2.new(1,-150,0,20), screenGui)
makeLabel("TIME",  UDim2.new(1,0,0.4,0), UDim2.new(0,0,0,0),   Color3.fromRGB(180,180,180), timerPanel)
local timerValue =
	makeLabel("0:00.00", UDim2.new(1,0,0.6,0), UDim2.new(0,0,0.4,0), Color3.fromRGB(255,255,255), timerPanel)

-- =====================
--   COUNTDOWN DISPLAY
-- =====================
local countdownLabel                  = Instance.new("TextLabel")
countdownLabel.Size                   = UDim2.new(0, 250, 0, 250)
countdownLabel.Position               = UDim2.new(0.5, -125, 0.5, -160)
countdownLabel.BackgroundTransparency = 1
countdownLabel.Text                   = ""
countdownLabel.TextScaled             = true
countdownLabel.Font                   = Enum.Font.GothamBold
countdownLabel.TextTransparency       = 1
countdownLabel.ZIndex                 = 20
countdownLabel.Parent                 = screenGui

CountdownUpdate.OnClientEvent:Connect(function(count)
	screenGui.Enabled = true

	countdownLabel.Text             = count == 0 and "GO!" or tostring(count)
	countdownLabel.TextColor3       = count == 0
		and Color3.fromRGB(80, 255, 120)
		or  Color3.fromRGB(255, 220, 50)
	countdownLabel.TextTransparency = 0

	task.delay(0.75, function()
		for i = 1, 15 do
			countdownLabel.TextTransparency = i / 15
			task.wait(0.04)
		end
		countdownLabel.Text = ""
	end)
end)

-- =====================
--       LAP NOTIF
-- =====================
local lapNotif                  = Instance.new("TextLabel")
lapNotif.Size                   = UDim2.new(0, 400, 0, 70)
lapNotif.Position               = UDim2.new(0.5, -200, 0.38, 0)
lapNotif.BackgroundTransparency = 1
lapNotif.Text                   = ""
lapNotif.TextTransparency       = 1
lapNotif.TextScaled             = true
lapNotif.Font                   = Enum.Font.GothamBold
lapNotif.ZIndex                 = 10
lapNotif.Parent                 = screenGui

local function showNotification(text, color)
	lapNotif.Text             = text
	lapNotif.TextColor3       = color or Color3.fromRGB(255,255,0)
	lapNotif.TextTransparency = 0
	task.delay(2, function()
		for i = 1, 20 do
			lapNotif.TextTransparency = i / 20
			task.wait(0.05)
		end
		lapNotif.Text = ""
	end)
end

LapUpdate.OnClientEvent:Connect(function(lap, totalLaps, finished)
	KartState.currentLap = lap
	if not finished then
		showNotification("LAP " .. lap .. " / " .. totalLaps)
	end
end)

-- =====================
--   RACE END SCREEN
-- =====================
local ordinals = { "1st", "2nd", "3rd", "4th" }

local endScreen                  = Instance.new("Frame")
endScreen.Name                   = "EndScreen"
endScreen.Size                   = UDim2.new(1, 0, 1, 0)
endScreen.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
endScreen.BackgroundTransparency = 0.45
endScreen.BorderSizePixel        = 0
endScreen.ZIndex                 = 30
endScreen.Visible                = false
endScreen.Parent                 = screenGui

local endTitle = Instance.new("TextLabel")
endTitle.Size                   = UDim2.new(0, 500, 0, 90)
endTitle.Position               = UDim2.new(0.5, -250, 0.25, 0)
endTitle.BackgroundTransparency = 1
endTitle.Text                   = "🏁 RACE FINISHED!"
endTitle.TextColor3             = Color3.fromRGB(255, 220, 50)
endTitle.TextScaled             = true
endTitle.Font                   = Enum.Font.GothamBold
endTitle.ZIndex                 = 31
endTitle.Parent                 = endScreen

local positionLabel = Instance.new("TextLabel")
positionLabel.Size                   = UDim2.new(0, 400, 0, 65)
positionLabel.Position               = UDim2.new(0.5, -200, 0.4, 0)
positionLabel.BackgroundTransparency = 1
positionLabel.Text                   = ""
positionLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
positionLabel.TextScaled             = true
positionLabel.Font                   = Enum.Font.GothamBold
positionLabel.ZIndex                 = 31
positionLabel.Parent                 = endScreen

local timeLabel = Instance.new("TextLabel")
timeLabel.Size                   = UDim2.new(0, 300, 0, 50)
timeLabel.Position               = UDim2.new(0.5, -150, 0.52, 0)
timeLabel.BackgroundTransparency = 1
timeLabel.Text                   = ""
timeLabel.TextColor3             = Color3.fromRGB(180, 180, 180)
timeLabel.TextScaled             = true
timeLabel.Font                   = Enum.Font.Gotham
timeLabel.ZIndex                 = 31
timeLabel.Parent                 = endScreen

local playAgainBtn                  = Instance.new("TextButton")
playAgainBtn.Size                   = UDim2.new(0, 220, 0, 65)
playAgainBtn.Position               = UDim2.new(0.5, -110, 0.63, 0)
playAgainBtn.BackgroundColor3       = Color3.fromRGB(50, 200, 100)
playAgainBtn.Text                   = "PLAY AGAIN"
playAgainBtn.TextColor3             = Color3.fromRGB(255, 255, 255)
playAgainBtn.TextScaled             = true
playAgainBtn.Font                   = Enum.Font.GothamBold
playAgainBtn.BorderSizePixel        = 0
playAgainBtn.ZIndex                 = 31
playAgainBtn.Parent                 = endScreen

local btnCorner        = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 12)
btnCorner.Parent       = playAgainBtn

playAgainBtn.MouseButton1Click:Connect(function()
	endScreen.Visible = false
	RestartRace:FireServer()
end)

-- =====================
--   RACE EVENT HOOKS
-- =====================
local raceStartTime = 0
local raceRunning   = false

RaceStarted.OnClientEvent:Connect(function()
	raceStartTime = os.clock()
	raceRunning   = true
end)

RaceEnded.OnClientEvent:Connect(function(position, timeStr)
	raceRunning  = false
	local ordinal = ordinals[position] or (position .. "th")

	positionLabel.Text = "You finished " .. ordinal .. "!"
	positionLabel.TextColor3 = position == 1
		and Color3.fromRGB(255, 220, 50)
		or  Color3.fromRGB(255, 255, 255)

	timeLabel.Text    = "Time: " .. timeStr
	endScreen.Visible = true
end)

RaceReset.OnClientEvent:Connect(function()
	endScreen.Visible    = false
	raceRunning          = false
	KartState.currentLap = 1
	timerValue.Text      = "0:00.00"
end)

-- =====================
--     UPDATE LOOP
-- =====================
RunService.Heartbeat:Connect(function()
	screenGui.Enabled = KartState.isInKart

	if not KartState.isInKart then return end

	speedValue.Text = tostring(math.floor(math.abs(KartState.currentSpeed)))
	speedValue.TextColor3 = KartState.speedMultiplier > 1
		and Color3.fromRGB(255, 200, 0)
		or  Color3.fromRGB(255, 255, 255)

	lapValue.Text  = KartState.currentLap .. " / " .. KartState.totalLaps
	itemValue.Text = KartState.currentItem or "--"

	if raceRunning then
		local elapsed = os.clock() - raceStartTime
		local m  = math.floor(elapsed / 60)
		local s  = math.floor(elapsed % 60)
		local ms = math.floor((elapsed % 1) * 100)
		timerValue.Text = string.format("%d:%02d.%02d", m, s, ms)
	end
end)
