local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local RESET_DELAY = 10
local KART_NAME = "Go-Kart"
local SEAT_NAME = "DriveSeat"
local RESET_FOLDER_NAME = "GoKartResetMarkers"
local RESPAWN_HIDDEN_TIME = 0.5
local COUNTDOWN_MAX_DISTANCE = 45
local RESET_POSITION_TOLERANCE = 6

local notifyEvent = ReplicatedStorage:WaitForChild("KutbahPointsNotify", 5)

local boundSeats = {}
local activeSessions = {}
local kartStates = {}
local claimedMarkers = {}

-- Create a safe storage for templates if not exists
local templateFolder = ServerStorage:FindFirstChild("GoKartTemplates")
if not templateFolder then
	templateFolder = Instance.new("Folder")
	templateFolder.Name = "GoKartTemplates"
	templateFolder.Parent = ServerStorage
end

local function getPlayerFromOccupant(occupant)
	if not occupant then return nil end
	return Players:GetPlayerFromCharacter(occupant.Parent)
end

local function zeroKartMotion(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function setKartVisible(state, visible)
	if not state or not state.model then return end
	for _, descendant in ipairs(state.model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local originalT = descendant:GetAttribute("GoKartOriginalTransparency") or 0
			descendant.Transparency = visible and originalT or 1
			-- Don't mess with CanCollide here to avoid physics issues
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			local originalT = descendant:GetAttribute("GoKartOriginalTransparency") or 0
			descendant.Transparency = visible and originalT or 1
		elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") then
			local originalE = descendant:GetAttribute("GoKartOriginalEnabled")
			descendant.Enabled = visible and (originalE ~= false) or false
		end
	end
end

local function setCountdownVisible(state, visible, text)
	if not state or not state.countdownGui then return end
	state.countdownGui.Enabled = visible
	if state.countdownLabel and text then
		state.countdownLabel.Text = text
	end
end

local function createCountdownGui(seat)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ResetCountdownGui"
	billboard.Size = UDim2.fromOffset(120, 34)
	billboard.StudsOffset = Vector3.new(0, 4.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = COUNTDOWN_MAX_DISTANCE
	billboard.Enabled = false
	billboard.Adornee = seat
	billboard.Parent = seat

	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(24, 58, 104)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = billboard

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 10)
	frameCorner.Parent = frame

	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = Color3.fromRGB(122, 186, 255)
	frameStroke.Transparency = 0.15
	frameStroke.Thickness = 1.2
	frameStroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Text = "Reset 10s"
	label.Parent = frame

	return billboard, label
end

local function getMarkerParts()
	local folder = Workspace:FindFirstChild(RESET_FOLDER_NAME)
	if not folder then return {} end
	local markers = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") then
			child.Transparency = 1
			table.insert(markers, child)
		end
	end
	table.sort(markers, function(a, b) return a.Name < b.Name end)
	return markers
end

local function assignResetMarker(model)
	local markerId = model:GetAttribute("ResetMarkerId")
	local folder = Workspace:FindFirstChild(RESET_FOLDER_NAME)
	local existing = markerId and folder and folder:FindFirstChild(markerId)
	if existing then return existing end

	local modelPivot = model:GetPivot().Position
	local bestMarker = nil
	local bestDistance = math.huge

	for _, marker in ipairs(getMarkerParts()) do
		local claimedBy = claimedMarkers[marker]
		if claimedBy == nil or not claimedBy.Parent then
			local distance = (marker.Position - modelPivot).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				bestMarker = marker
			end
		end
	end

	if bestMarker then
		claimedMarkers[bestMarker] = model
		model:SetAttribute("ResetMarkerId", bestMarker.Name)
	end
	return bestMarker
end

local function isKartAtReset(state)
	if not state or not state.model or not state.homePivot then return true end
	local currentPivot = state.model:GetPivot()
	local dist = (currentPivot.Position - state.homePivot.Position).Magnitude
	if dist > RESET_POSITION_TOLERANCE then return false end
	
	local _, currentY = currentPivot:ToOrientation()
	local _, homeY = state.homePivot:ToOrientation()
	local rotDiff = math.abs(math.deg(currentY - homeY)) % 360
	if rotDiff > 180 then rotDiff = 360 - rotDiff end
	return rotDiff <= 30
end

local bindSeat

local function respawnKart(oldSeat, state)
	if not state or not state.template or not state.homePivot then return end

	local oldModel = state.model
	local resetMarker = state.resetMarker
	local template = state.template
	local homePivot = state.homePivot
	local originalParent = state.originalParent

	-- Cleanup old references
	boundSeats[oldSeat] = nil
	kartStates[oldSeat] = nil

	-- Create new model
	local newModel = template:Clone()
	
	-- Keep it anchored and non-collidable with everything except ground during setup
	for _, descendant in ipairs(newModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end

	if resetMarker then
		newModel:SetAttribute("ResetMarkerId", resetMarker.Name)
	end
	
	-- Position it properly (slight offset up for safety)
	newModel:PivotTo(homePivot * CFrame.new(0, 0.2, 0))

	-- Destroy old before parenting new
	if oldModel and oldModel.Parent then
		oldModel:Destroy()
	end

	newModel.Parent = originalParent or Workspace

	-- Wait for welds and A-Chassis to stabilize
	task.wait(1)

	if newModel and newModel.Parent then
		local seat = newModel:FindFirstChild(SEAT_NAME, true)
		if seat then
			-- Final safety check on position
			newModel:PivotTo(homePivot)
			
			-- Let A-Chassis or our defer handle unanchoring
			task.defer(function()
				for _, descendant in ipairs(newModel:GetDescendants()) do
					if descendant:IsA("BasePart") then
						descendant.Anchored = false
					end
				end
			end)
			
			bindSeat(seat, newModel, resetMarker, template, homePivot)
		end
	end
end

local function runResetCountdown(seat, token)
	for remaining = RESET_DELAY, 1, -1 do
		local latestState = kartStates[seat]
		if not latestState or latestState.resetToken ~= token or seat.Occupant then return end
		setCountdownVisible(latestState, true, string.format("Reset %ds", remaining))
		task.wait(1)
	end

	local latestState = kartStates[seat]
	if not latestState or latestState.resetToken ~= token or seat.Occupant or isKartAtReset(latestState) then
		setCountdownVisible(latestState, false)
		return
	end

	setCountdownVisible(latestState, true, "Respawning...")
	setKartVisible(latestState, false)
	
	task.wait(RESPAWN_HIDDEN_TIME)
	respawnKart(seat, latestState)
end

local function scheduleKartReset(seat)
	local state = kartStates[seat]
	if not state or isKartAtReset(state) then 
		if state then setCountdownVisible(state, false) end
		return 
	end
	
	state.resetToken += 1
	task.spawn(runResetCountdown, seat, state.resetToken)
end

local function handleSeatChanged(seat)
	local occupant = seat.Occupant
	local currentPlayer = getPlayerFromOccupant(occupant)

	if not occupant or not currentPlayer then
		scheduleKartReset(seat)
		return
	end

	local state = kartStates[seat]
	if state then
		state.resetToken += 1
		setCountdownVisible(state, false)
		setKartVisible(state, true)
	end
end

bindSeat = function(seat, model, assignedMarker, template, homePivot)
	if boundSeats[seat] then return end
	boundSeats[seat] = true

	local resetMarker = assignedMarker or assignResetMarker(model)
	local countdownGui, countdownLabel = createCountdownGui(seat)
	
	local sourceTemplate = template
	if not sourceTemplate then
		-- Clean capture of the model
		model.Archivable = true
		sourceTemplate = model:Clone()
		-- Ensure template parts are marked with their original properties
		for _, v in ipairs(sourceTemplate:GetDescendants()) do
			if v:IsA("BasePart") then
				v:SetAttribute("GoKartOriginalTransparency", v.Transparency)
				v:SetAttribute("GoKartOriginalCanCollide", v.CanCollide)
			end
		end
		sourceTemplate.Parent = templateFolder
	end

	local modelPivot = homePivot
	if not modelPivot and resetMarker then
		modelPivot = resetMarker.CFrame * CFrame.new(0, 1.6, 0)
	end
	modelPivot = modelPivot or model:GetPivot()

	local state = {
		model = model,
		seat = seat,
		resetMarker = resetMarker,
		homePivot = modelPivot,
		template = sourceTemplate,
		originalParent = model.Parent,
		resetToken = 0,
		countdownGui = countdownGui,
		countdownLabel = countdownLabel,
	}

	kartStates[seat] = state
	setKartVisible(state, true)

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		handleSeatChanged(seat)
	end)
end

local function tryBindKart(instance)
	if instance.Name ~= KART_NAME or not instance:IsA("Model") then return end
	if instance:IsDescendantOf(templateFolder) then return end
	
	local seat = instance:FindFirstChild(SEAT_NAME, true)
	if seat and seat:IsA("VehicleSeat") then
		bindSeat(seat, instance)
	end
end

-- Initialize
task.spawn(function()
	task.wait(2)
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		tryBindKart(descendant)
	end
end)

Workspace.DescendantAdded:Connect(tryBindKart)

-- Safety loop
task.spawn(function()
	while task.wait(1) do
		for seat, state in pairs(kartStates) do
			if not seat.Occupant and not isKartAtReset(state) and state.resetToken == 0 then
				scheduleKartReset(seat)
			end
		end
	end
end)
