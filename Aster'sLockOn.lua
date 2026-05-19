-- ==========================================
-- SERVICES & CONFIGURATION
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local HapticService = game:GetService("HapticService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local LOCK_RADIUS = 250
local UI_SIZE = 80 

-- State Variables
local uiLocked = false
local targetLocked = false
local currentTarget = nil
local dragging = false
local dragStart, startPos

-- Custom Camera State
local lockOnZoom = 15

-- PC Keybind Logic
local isPC = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
local lockKeybind = Enum.KeyCode.K 
local isWaitingForKeybind = isPC

-- Enemy Tracking
local activeHighlight = nil
local lastHighlightedChar = nil
local lastTargetHealth = -1
local lastTargetPlayer = nil
local isPanelVisible = false
local activeHitMarker = nil
local hitComboDamage = 0
local hitComboTask = nil

-- Local Player Tracking
local lastMyHealth = -1
local myHitComboDamage = 0
local myHitComboTask = nil

-- ==========================================
-- UI CREATION: TARGET PANEL (Universal)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PremiumLockOnGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true 
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local TargetPanel = Instance.new("Frame")
TargetPanel.Size = UDim2.new(0, 220, 0, 70)
TargetPanel.Position = UDim2.new(0.5, 0, -0.2, 0)
TargetPanel.AnchorPoint = Vector2.new(0.5, 0)
TargetPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
TargetPanel.BackgroundTransparency = 1
TargetPanel.Visible = false
TargetPanel.ClipsDescendants = true
TargetPanel.Parent = ScreenGui

local PanelCorner = Instance.new("UICorner")
PanelCorner.CornerRadius = UDim.new(0, 12)
PanelCorner.Parent = TargetPanel

local PanelStroke = Instance.new("UIStroke")
PanelStroke.Color = Color3.fromRGB(255, 50, 50)
PanelStroke.Thickness = 1.5
PanelStroke.Transparency = 1
PanelStroke.Parent = TargetPanel

local TargetName = Instance.new("TextLabel")
TargetName.Size = UDim2.new(1, 0, 0.35, 0)
TargetName.Position = UDim2.new(0, 0, 0.05, 0)
TargetName.BackgroundTransparency = 1
TargetName.TextColor3 = Color3.fromRGB(255, 255, 255)
TargetName.TextTransparency = 1
TargetName.Font = Enum.Font.GothamBold
TargetName.TextSize = 16
TargetName.Parent = TargetPanel

local HealthBarBg = Instance.new("Frame")
HealthBarBg.Size = UDim2.new(0.9, 0, 0.15, 0)
HealthBarBg.Position = UDim2.new(0.05, 0, 0.45, 0)
HealthBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
HealthBarBg.BackgroundTransparency = 1
HealthBarBg.BorderSizePixel = 0
HealthBarBg.Parent = TargetPanel

local HealthCorner = Instance.new("UICorner")
HealthCorner.CornerRadius = UDim.new(1, 0)
HealthCorner.Parent = HealthBarBg

local HealthBarFill = Instance.new("Frame")
HealthBarFill.Size = UDim2.new(1, 0, 1, 0)
HealthBarFill.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
HealthBarFill.BackgroundTransparency = 1
HealthBarFill.BorderSizePixel = 0
HealthBarFill.Parent = HealthBarBg

local FillCorner = Instance.new("UICorner")
FillCorner.CornerRadius = UDim.new(1, 0)
FillCorner.Parent = HealthBarFill

local HealthText = Instance.new("TextLabel")
HealthText.Size = UDim2.new(1, 0, 1, 0)
HealthText.BackgroundTransparency = 1
HealthText.TextColor3 = Color3.fromRGB(255, 255, 255)
HealthText.TextTransparency = 1
HealthText.Font = Enum.Font.GothamBold
HealthText.TextSize = 11
HealthText.ZIndex = 2
HealthText.Parent = HealthBarBg

local DistanceText = Instance.new("TextLabel")
DistanceText.Size = UDim2.new(1, 0, 0.3, 0)
DistanceText.Position = UDim2.new(0, 0, 0.65, 0)
DistanceText.BackgroundTransparency = 1
DistanceText.TextColor3 = Color3.fromRGB(180, 180, 180)
DistanceText.TextTransparency = 1
DistanceText.Font = Enum.Font.GothamMedium
DistanceText.TextSize = 12
DistanceText.Parent = TargetPanel

-- ==========================================
-- UI CREATION: LOCAL DAMAGE TEXT
-- ==========================================
local LocalDamageText = Instance.new("TextLabel")
LocalDamageText.Size = UDim2.new(0, 200, 0, 50)
LocalDamageText.Position = UDim2.new(0.5, 0, 0.75, 0) -- Lower center of screen
LocalDamageText.AnchorPoint = Vector2.new(0.5, 0.5)
LocalDamageText.BackgroundTransparency = 1
LocalDamageText.Font = Enum.Font.GothamBlack
LocalDamageText.Text = ""
LocalDamageText.TextColor3 = Color3.fromRGB(255, 40, 40)
LocalDamageText.TextSize = 0
LocalDamageText.TextTransparency = 1
LocalDamageText.TextStrokeTransparency = 1
LocalDamageText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
LocalDamageText.ZIndex = 10
LocalDamageText.Parent = ScreenGui

-- ==========================================
-- UI CREATION: MOBILE EXCLUSIVE
-- ==========================================
local MainButton, UIStroke, ConfirmButton
if not isPC then
	local ButtonShadow = Instance.new("Frame")
	ButtonShadow.Size = UDim2.new(0, UI_SIZE + 4, 0, UI_SIZE + 4)
	ButtonShadow.Position = UDim2.new(0.7, -2, 0.6, -2)
	ButtonShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	ButtonShadow.BackgroundTransparency = 0.6
	ButtonShadow.Parent = ScreenGui
	
	local ShadowCorner = Instance.new("UICorner")
	ShadowCorner.CornerRadius = UDim.new(1, 0)
	ShadowCorner.Parent = ButtonShadow

	MainButton = Instance.new("TextButton")
	MainButton.Size = UDim2.new(1, -4, 1, -4)
	MainButton.Position = UDim2.new(0, 2, 0, 2)
	MainButton.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	MainButton.BackgroundTransparency = 0.15
	MainButton.Text = "⌖" 
	MainButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	MainButton.TextSize = 35
	MainButton.Font = Enum.Font.GothamBold
	MainButton.Parent = ButtonShadow

	local UICorner = Instance.new("UICorner")
	UICorner.CornerRadius = UDim.new(1, 0)
	UICorner.Parent = MainButton

	UIStroke = Instance.new("UIStroke")
	UIStroke.Color = Color3.fromRGB(200, 200, 200)
	UIStroke.Thickness = 2.5
	UIStroke.Transparency = 0.3
	UIStroke.Parent = MainButton

	ConfirmButton = Instance.new("TextButton")
	ConfirmButton.Size = UDim2.new(0, 0, 0, 30) 
	ConfirmButton.Position = UDim2.new(0.5, 0, 1.2, 0)
	ConfirmButton.AnchorPoint = Vector2.new(0.5, 0)
	ConfirmButton.BackgroundColor3 = Color3.fromRGB(40, 120, 255)
	ConfirmButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	ConfirmButton.Text = "" 
	ConfirmButton.Font = Enum.Font.GothamBold
	ConfirmButton.TextSize = 12
	ConfirmButton.ClipsDescendants = true
	ConfirmButton.Parent = ButtonShadow

	local ConfirmCorner = Instance.new("UICorner")
	ConfirmCorner.CornerRadius = UDim.new(1, 0)
	ConfirmCorner.Parent = ConfirmButton
end

-- ==========================================
-- UI CREATION: PC EXCLUSIVE
-- ==========================================
local SetupPrompt, ReminderText
if isPC then
	SetupPrompt = Instance.new("Frame")
	SetupPrompt.Size = UDim2.new(1, 0, 1, 0)
	SetupPrompt.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	SetupPrompt.BackgroundTransparency = 0.5
	SetupPrompt.Parent = ScreenGui
	
	local PromptBox = Instance.new("Frame")
	PromptBox.Size = UDim2.new(0, 350, 0, 100)
	PromptBox.Position = UDim2.new(0.5, 0, 0.5, 0)
	PromptBox.AnchorPoint = Vector2.new(0.5, 0.5)
	PromptBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	PromptBox.Parent = SetupPrompt
	
	local PromptCorner = Instance.new("UICorner")
	PromptCorner.CornerRadius = UDim.new(0, 8)
	PromptCorner.Parent = PromptBox
	
	local PromptText = Instance.new("TextLabel")
	PromptText.Size = UDim2.new(1, 0, 1, 0)
	PromptText.BackgroundTransparency = 1
	PromptText.TextColor3 = Color3.fromRGB(255, 255, 255)
	PromptText.Font = Enum.Font.GothamBold
	PromptText.TextSize = 18
	PromptText.Text = "Press any key to bind Lock-On..."
	PromptText.Parent = PromptBox
	
	ReminderText = Instance.new("TextLabel")
	ReminderText.Size = UDim2.new(0, 200, 0, 30)
	ReminderText.Position = UDim2.new(0, 20, 1, -40)
	ReminderText.BackgroundTransparency = 1
	ReminderText.TextColor3 = Color3.fromRGB(200, 200, 200)
	ReminderText.Font = Enum.Font.GothamBold
	ReminderText.TextSize = 14
	ReminderText.TextXAlignment = Enum.TextXAlignment.Left
	ReminderText.Visible = false
	ReminderText.Parent = ScreenGui
end

-- ==========================================
-- IMPACT EFFECTS (ENEMY DAMAGE)
-- ==========================================

local function triggerImpactEffects(damage, maxHealth, character)
	local damageRatio = math.clamp(damage / maxHealth, 0, 1)
	
	if not isPC then
		if HapticService:IsMotorSupported(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small) then
			local hapticIntensity = math.clamp(0.2 + (damageRatio * 2), 0.2, 1)
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, hapticIntensity)
			
			task.delay(0.15, function()
				HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
			end)
		end
	end
	
	if isPanelVisible then
		local basePos = UDim2.new(0.5, 0, 0.05, 0)
		local shakeMag = math.clamp(damageRatio * 40, 5, 25) 
		
		TweenService:Create(TargetPanel, TweenInfo.new(0.05, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
			Position = basePos + UDim2.new(0, math.random(-shakeMag, shakeMag), 0, math.random(-shakeMag, shakeMag))
		}):Play()
		
		task.delay(0.05, function()
			if isPanelVisible then
				TweenService:Create(TargetPanel, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = basePos}):Play()
			end
		end)
	end
	
	if character and character:FindFirstChild("HumanoidRootPart") then
		hitComboDamage += damage
		local comboRatio = hitComboDamage / maxHealth
		
		local hitColor = Color3.fromRGB(255, 255, 255)
		if comboRatio >= 0.3 then hitColor = Color3.fromRGB(255, 50, 50)
		elseif comboRatio >= 0.15 then hitColor = Color3.fromRGB(255, 150, 50)
		elseif comboRatio >= 0.05 then hitColor = Color3.fromRGB(255, 200, 50) end
		
		if activeHitMarker and activeHitMarker.Parent then
			local txt = activeHitMarker:FindFirstChild("TextLabel")
			if txt then
				txt.Text = "-" .. math.floor(hitComboDamage)
				txt.TextColor3 = hitColor
				
				TweenService:Create(txt, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {TextSize = 45}):Play()
				task.delay(0.1, function()
					if txt and txt.Parent then
						TweenService:Create(txt, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextSize = 32}):Play()
					end
				end)
			end
		else
			activeHitMarker = Instance.new("BillboardGui")
			activeHitMarker.Size = UDim2.new(0, 200, 0, 100)
			activeHitMarker.StudsOffset = Vector3.new(math.random(-15, 15)/10, 1.5, math.random(-15, 15)/10)
			activeHitMarker.Adornee = character.HumanoidRootPart
			activeHitMarker.AlwaysOnTop = true
			activeHitMarker.Parent = ScreenGui 
			
			local txt = Instance.new("TextLabel")
			txt.Size = UDim2.new(1, 0, 1, 0)
			txt.BackgroundTransparency = 1
			txt.Font = Enum.Font.GothamBlack
			txt.Text = "-" .. math.floor(hitComboDamage)
			txt.TextColor3 = hitColor
			txt.TextSize = 0 
			txt.TextStrokeTransparency = 0.2
			txt.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			txt.Parent = activeHitMarker
			
			TweenService:Create(txt, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {TextSize = 32}):Play()
		end
		
		if hitComboTask then task.cancel(hitComboTask) end
		
		local savedMarker = activeHitMarker
		hitComboTask = task.delay(1.5, function()
			if savedMarker and savedMarker.Parent then
				local txt = savedMarker:FindFirstChild("TextLabel")
				if txt then
					TweenService:Create(txt, TweenInfo.new(0.4), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
					TweenService:Create(savedMarker, TweenInfo.new(0.4), {StudsOffset = savedMarker.StudsOffset + Vector3.new(0, 2, 0)}):Play()
					task.delay(0.4, function() savedMarker:Destroy() end)
				end
			end
			if activeHitMarker == savedMarker then
				activeHitMarker = nil
				hitComboDamage = 0
			end
		end)
	end
end

-- ==========================================
-- IMPACT EFFECTS (LOCAL PLAYER DAMAGE)
-- ==========================================

local function triggerLocalImpactEffects(damage, maxHealth)
	local damageRatio = math.clamp(damage / maxHealth, 0, 1)

	-- 1. Haptics (Stronger vibration for taking damage yourself)
	if not isPC then
		if HapticService:IsMotorSupported(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large) then
			local hapticIntensity = math.clamp(0.4 + (damageRatio * 1.5), 0.4, 1)
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, hapticIntensity)
			
			task.delay(0.2, function()
				HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, 0)
			end)
		end
	end

	-- 2. Screen Space Hitmarker & Shake
	myHitComboDamage += damage
	LocalDamageText.Text = "-" .. math.floor(myHitComboDamage)
	LocalDamageText.TextTransparency = 0
	LocalDamageText.TextStrokeTransparency = 0.3
	
	local basePos = UDim2.new(0.5, 0, 0.75, 0)
	local shakeMag = math.clamp(damageRatio * 60, 10, 40) -- Shake magnitude in pixels

	-- Violent pop and shake
	TweenService:Create(LocalDamageText, TweenInfo.new(0.05, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
		Position = basePos + UDim2.new(0, math.random(-shakeMag, shakeMag), 0, math.random(-shakeMag, shakeMag)),
		TextSize = 55
	}):Play()
	
	-- Snap back
	task.delay(0.05, function()
		TweenService:Create(LocalDamageText, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = basePos,
			TextSize = 40
		}):Play()
	end)

	-- 3. Reset combo timer
	if myHitComboTask then task.cancel(myHitComboTask) end
	myHitComboTask = task.delay(1.5, function()
		TweenService:Create(LocalDamageText, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
			Position = basePos + UDim2.new(0, 0, 0.05, 0) -- Float down slightly to disappear
		}):Play()
		
		task.delay(0.4, function()
			myHitComboDamage = 0
		end)
	end)
end

-- ==========================================
-- GENERAL ANIMATIONS & SYSTEM TOGGLES
-- ==========================================

local function tweenTargetPanel(show)
	if show == isPanelVisible then return end
	isPanelVisible = show
	
	local targetTrans = show and 0.2 or 1
	local targetTextTrans = show and 0 or 1
	local targetPos = show and UDim2.new(0.5, 0, 0.05, 0) or UDim2.new(0.5, 0, -0.2, 0)
	
	if show then TargetPanel.Visible = true end
	
	local tInfo = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
	
	TweenService:Create(TargetPanel, tInfo, {BackgroundTransparency = targetTrans, Position = targetPos}):Play()
	TweenService:Create(PanelStroke, tInfo, {Transparency = targetTrans}):Play()
	TweenService:Create(TargetName, tInfo, {TextTransparency = targetTextTrans}):Play()
	TweenService:Create(HealthBarBg, tInfo, {BackgroundTransparency = targetTrans}):Play()
	TweenService:Create(HealthBarFill, tInfo, {BackgroundTransparency = targetTextTrans}):Play()
	TweenService:Create(HealthText, tInfo, {TextTransparency = targetTextTrans}):Play()
	TweenService:Create(DistanceText, tInfo, {TextTransparency = targetTextTrans}):Play()
	
	if not show then
		task.delay(0.5, function()
			if not isPanelVisible then TargetPanel.Visible = false end
		end)
	end
end

local function setHighlight(character)
	if lastHighlightedChar == character then return end
	
	if activeHighlight then
		local oldHighlight = activeHighlight
		local fadeOut = TweenService:Create(oldHighlight, TweenInfo.new(0.3), {FillTransparency = 1, OutlineTransparency = 1})
		fadeOut:Play()
		fadeOut.Completed:Connect(function() oldHighlight:Destroy() end)
		activeHighlight = nil
	end
	
	lastHighlightedChar = character
	
	if character then
		activeHighlight = Instance.new("Highlight")
		activeHighlight.FillColor = Color3.fromRGB(255, 50, 50)
		activeHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		activeHighlight.FillTransparency = 1 
		activeHighlight.OutlineTransparency = 1
		activeHighlight.Parent = character
		
		TweenService:Create(activeHighlight, TweenInfo.new(0.3), {FillTransparency = 0.5, OutlineTransparency = 0}):Play()
	end
end

local function unlockTarget()
	targetLocked = false
	currentTarget = nil
	Camera.CameraType = Enum.CameraType.Custom
	setHighlight(nil)
	tweenTargetPanel(false)
	
	if not isPC and UIStroke then 
		TweenService:Create(UIStroke, TweenInfo.new(0.3), {Color = Color3.fromRGB(200, 200, 200), Thickness = 2.5, Transparency = 0.3}):Play()
		TweenService:Create(MainButton, TweenInfo.new(0.3), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
	end
end

local function triggerLockToggle()
	if targetLocked then
		unlockTarget()
	elseif currentTarget then
		targetLocked = true
		Camera.CameraType = Enum.CameraType.Scriptable
		
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
			local myRootPos = LocalPlayer.Character.HumanoidRootPart.Position + Vector3.new(0, 1.5, 0)
			lockOnZoom = (Camera.CFrame.Position - myRootPos).Magnitude
			lockOnZoom = math.clamp(lockOnZoom, 5, 35)
		end
		
		if not isPC and UIStroke then
			local tInfo = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
			TweenService:Create(UIStroke, tInfo, {Color = Color3.fromRGB(255, 50, 50), Thickness = 3, Transparency = 0}):Play()
			TweenService:Create(MainButton, tInfo, {TextColor3 = Color3.fromRGB(255, 50, 50)}):Play()
		end
	end
end

-- ==========================================
-- INPUT HANDLING (MANUAL ZOOM ONLY)
-- ==========================================

UserInputService.TouchPinch:Connect(function(touchPositions, scale, velocity, state, gameProcessed)
	if targetLocked and not gameProcessed then
		lockOnZoom = math.clamp(lockOnZoom - (velocity * 0.5), 5, 35)
	end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if targetLocked and input.UserInputType == Enum.UserInputType.MouseWheel then
		lockOnZoom = math.clamp(lockOnZoom - (input.Position.Z * 3), 5, 35)
	end
	
	if dragging and not uiLocked and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		MainButton.Parent.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X, 
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if isPC and isWaitingForKeybind and input.UserInputType == Enum.UserInputType.Keyboard then
		lockKeybind = input.KeyCode
		isWaitingForKeybind = false
		TweenService:Create(SetupPrompt, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
		task.delay(0.5, function() SetupPrompt.Visible = false end)
		
		ReminderText.Text = "Lock-On: [" .. lockKeybind.Name .. "]"
		ReminderText.Visible = true
		TweenService:Create(ReminderText, TweenInfo.new(1), {TextTransparency = 0}):Play()
		return
	end
	
	if isPC and not isWaitingForKeybind and input.KeyCode == lockKeybind then
		triggerLockToggle()
	end
end)

if not isPC then
	local function pressTween(isDown)
		local scale = isDown and 0.85 or 1
		TweenService:Create(MainButton.Parent, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, (UI_SIZE + 4) * scale, 0, (UI_SIZE + 4) * scale)
		}):Play()
	end

	MainButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressTween(true)
			if not uiLocked then
				dragging = true
				dragStart = input.Position
				startPos = MainButton.Parent.Position
				
				ConfirmButton.Text = "Save Placement"
				TweenService:Create(ConfirmButton, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Size = UDim2.new(0, 120, 0, 30)
				}):Play()
			end
		end
	end)

	MainButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressTween(false)
			dragging = false
		end
	end)

	ConfirmButton.MouseButton1Click:Connect(function()
		uiLocked = true
		TweenService:Create(ConfirmButton, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 0, 0, 30), TextTransparency = 1
		}):Play()
		TweenService:Create(MainButton, TweenInfo.new(0.5), {BackgroundColor3 = Color3.fromRGB(10, 10, 12)}):Play()
	end)

	MainButton.MouseButton1Click:Connect(function()
		if uiLocked then triggerLockToggle() end
	end)
end

-- ==========================================
-- MAIN COMBAT LOOP
-- ==========================================

local function getClosestTargetInCenter()
	local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	local closestDistance = LOCK_RADIUS
	local closestPlayer = nil

	for _, player in pairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
			local rootPart = player.Character.HumanoidRootPart
			local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)

			if onScreen then
				local distanceFromCenter = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
				if distanceFromCenter < closestDistance then
					closestDistance = distanceFromCenter
					closestPlayer = player
				end
			end
		end
	end
	return closestPlayer
end

RunService:BindToRenderStep("LockOnSystem", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local myCharacter = LocalPlayer.Character
	local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
	local myHumanoid = myCharacter and myCharacter:FindFirstChild("Humanoid")
	
	-- TRACK LOCAL PLAYER HEALTH (Always active, even when not locked on)
	if myHumanoid then
		local currentMyHealth = math.floor(myHumanoid.Health)
		local myMaxHealth = math.floor(myHumanoid.MaxHealth)
		
		if currentMyHealth < lastMyHealth and lastMyHealth ~= -1 then
			local damageTaken = lastMyHealth - currentMyHealth
			triggerLocalImpactEffects(damageTaken, myMaxHealth)
		end
		lastMyHealth = currentMyHealth
	else
		lastMyHealth = -1
	end
	
	-- ENEMY TARGET SWITCH CLEANUP
	if currentTarget ~= lastTargetPlayer then
		lastTargetHealth = -1
		lastTargetPlayer = currentTarget
		if hitComboTask then task.cancel(hitComboTask) end
		hitComboDamage = 0
		if activeHitMarker then activeHitMarker:Destroy() activeHitMarker = nil end
	end
	
	if not targetLocked then
		currentTarget = getClosestTargetInCenter()
		setHighlight(currentTarget and currentTarget.Character or nil)
		tweenTargetPanel(false)
		
		if not isPC and UIStroke then
			if currentTarget then
				TweenService:Create(UIStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(255, 200, 50), Transparency = 0}):Play()
			else
				TweenService:Create(UIStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(200, 200, 200), Transparency = 0.3}):Play()
			end
		end
	else
		local meAlive = myRoot and myHumanoid and myHumanoid.Health > 0
		
		local targetChar = currentTarget and currentTarget.Character
		local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
		local targetHumanoid = targetChar and targetChar:FindFirstChild("Humanoid")
		local targetAlive = currentTarget and currentTarget.Parent == Players and targetRoot and targetHumanoid and targetHumanoid.Health > 0
		
		if meAlive and targetAlive then
			local targetPos = targetRoot.Position
			
			if myHumanoid:GetState() ~= Enum.HumanoidStateType.Physics then
				myRoot.CFrame = CFrame.lookAt(myRoot.Position, Vector3.new(targetPos.X, myRoot.Position.Y, targetPos.Z))
			end
			
			local focusPos = myRoot.Position + Vector3.new(0, 1.5, 0) 
			local lookDir = (targetPos - focusPos).Unit
			
			local desiredCamPos = focusPos - (lookDir * lockOnZoom)
			
			local rayParams = RaycastParams.new()
			rayParams.FilterDescendantsInstances = {myCharacter, targetChar}
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			local rayResult = Workspace:Raycast(focusPos, desiredCamPos - focusPos, rayParams)
			
			if rayResult then
				desiredCamPos = rayResult.Position + (lookDir * 0.5)
			end
			
			local targetCFrame = CFrame.lookAt(desiredCamPos, targetPos)
			local lerpFactor = 1 - math.exp(-15 * dt)
			Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, lerpFactor)
			
			setHighlight(targetChar)
			tweenTargetPanel(true)
			TargetName.Text = currentTarget.Name
			
			local distance = math.floor((myRoot.Position - targetRoot.Position).Magnitude)
			DistanceText.Text = distance .. " Studs"
			
			local currentHealth = math.floor(targetHumanoid.Health)
			local maxHealth = math.floor(targetHumanoid.MaxHealth)
			
			if currentHealth < lastTargetHealth and lastTargetHealth ~= -1 then
				local damageDealt = lastTargetHealth - currentHealth
				triggerImpactEffects(damageDealt, maxHealth, targetChar)
			end
			
			if currentHealth ~= lastTargetHealth then
				lastTargetHealth = currentHealth
				local healthRatio = math.clamp(currentHealth / maxHealth, 0, 1)
				local targetColor = Color3.fromRGB(255, 50, 50):Lerp(Color3.fromRGB(50, 255, 50), healthRatio)
				
				TweenService:Create(HealthBarFill, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Size = UDim2.new(healthRatio, 0, 1, 0),
					BackgroundColor3 = targetColor
				}):Play()
				
				HealthText.Text = currentHealth .. " / " .. maxHealth
			end
		else
			unlockTarget()
		end
	end
end)
