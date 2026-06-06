local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local remote = ReplicatedStorage:WaitForChild("SpeakerMusicRemote")
local audioFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Audio")

local gui = script.Parent
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 8

local main = gui:WaitForChild("Main")
local title = main:WaitForChild("Title")
local subtitle = main:WaitForChild("Subtitle")
local status = main:WaitForChild("Status")
local closeButton = main:WaitForChild("CloseButton")
local stopButton = main:WaitForChild("StopButton")
local rangeTitle = main:WaitForChild("RangeTitle")
local minLabel = main:WaitForChild("MinLabel")
local minBox = main:WaitForChild("MinBox")
local maxLabel = main:WaitForChild("MaxLabel")
local maxBox = main:WaitForChild("MaxBox")
local applyRangeButton = main:WaitForChild("ApplyRangeButton")
local songList = main:WaitForChild("SongList")
local template = songList:WaitForChild("SongButtonTemplate")
local listLayout = songList:WaitForChild("ListLayout")
local sizeConstraint = main:FindFirstChild("UISizeConstraint")
local aspectConstraint = main:FindFirstChild("UIAspectRatioConstraint")
local songListPadding = songList:FindFirstChild("UIPadding")

local PALETTE = {
	Panel = Color3.fromRGB(0, 0, 0),
	PanelBorder = Color3.fromRGB(255, 255, 255),
	Surface = Color3.fromRGB(10, 10, 10),
	SurfaceAlt = Color3.fromRGB(18, 18, 18),
	Primary = Color3.fromRGB(255, 255, 255),
	PrimaryDark = Color3.fromRGB(196, 196, 196),
	Text = Color3.fromRGB(245, 245, 245),
	TextMuted = Color3.fromRGB(186, 186, 186),
	Danger = Color3.fromRGB(116, 24, 24),
	DangerDark = Color3.fromRGB(165, 54, 54),
	Warning = Color3.fromRGB(255, 204, 102),
	White = Color3.fromRGB(255, 255, 255),
	Black = Color3.fromRGB(0, 0, 0),
}

local PANEL_TRANSPARENCY = 0.32
local SURFACE_TRANSPARENCY = 0.48
local BUTTON_TRANSPARENCY = 0.52
local INPUT_TRANSPARENCY = 0.56

local DEFAULT_STATUS_COLOR = PALETTE.TextMuted
local DEFAULT_BUTTON_COLOR = PALETTE.Surface
local DEFAULT_BUTTON_TEXT_COLOR = PALETTE.Text
local ACTIVE_BUTTON_COLOR = PALETTE.Primary
local ACTIVE_BUTTON_TEXT_COLOR = PALETTE.Black
local WARNING_STATUS_COLOR = PALETTE.Warning
local ACTIVE_STATUS_COLOR = PALETTE.Text

local currentState = {
	trackName = nil,
	minDistance = 12,
	maxDistance = 75,
}

local songButtons = {}
local songConnections = {}
local compactLayout = false
local viewportConnection = nil

local function ensureUICorner(instance, radius)
	local corner = instance:FindFirstChildOfClass("UICorner")
	if not corner then
		corner = Instance.new("UICorner")
		corner.Parent = instance
	end
	corner.CornerRadius = UDim.new(0, radius)
	return corner
end

local function ensureUIStroke(instance, color, thickness, transparency)
	local stroke = instance:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = instance
	end
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	return stroke
end

local function styleButton(button, backgroundColor, textColor)
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.BackgroundColor3 = backgroundColor
	button.BackgroundTransparency = BUTTON_TRANSPARENCY
	button.TextColor3 = textColor
	button.Font = Enum.Font.GothamMedium
	button.TextScaled = false
	ensureUICorner(button, 12)
	ensureUIStroke(button, PALETTE.PanelBorder, 1, 0.68)
end

local function styleInput(box)
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.BackgroundColor3 = PALETTE.Surface
	box.BackgroundTransparency = INPUT_TRANSPARENCY
	box.TextColor3 = PALETTE.Text
	box.PlaceholderColor3 = PALETTE.TextMuted
	box.Font = Enum.Font.GothamMedium
	box.TextScaled = false
	box.TextXAlignment = Enum.TextXAlignment.Center
	ensureUICorner(box, 12)
	ensureUIStroke(box, PALETTE.PanelBorder, 1, 0.72)
end

local function styleLabel(label, color, font)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.TextColor3 = color
	label.Font = font
	label.TextScaled = false
	label.TextXAlignment = Enum.TextXAlignment.Left
end

local function styleStaticUi()
	main.AnchorPoint = Vector2.new(0.5, 0.5)
	main.Position = UDim2.fromScale(0.5, 0.5)
	main.Active = true
	main.ClipsDescendants = true
	main.BorderSizePixel = 0
	main.BackgroundColor3 = PALETTE.Panel
	main.BackgroundTransparency = PANEL_TRANSPARENCY
	ensureUICorner(main, 20)
	ensureUIStroke(main, PALETTE.PanelBorder, 1, 0.62)

	if aspectConstraint then
		aspectConstraint:Destroy()
	end

	if sizeConstraint then
		sizeConstraint.MinSize = Vector2.new(280, 420)
		sizeConstraint.MaxSize = Vector2.new(400, 600)
	end

	styleLabel(title, PALETTE.Text, Enum.Font.GothamBold)
	title.Position = UDim2.fromScale(0.07, 0.055)
	title.Size = UDim2.fromScale(0.66, 0.075)
	title.Text = "Pemutar Musik"

	styleLabel(subtitle, PALETTE.TextMuted, Enum.Font.Gotham)
	subtitle.Position = UDim2.fromScale(0.07, 0.12)
	subtitle.Size = UDim2.fromScale(0.86, 0.05)
	subtitle.TextWrapped = true

	status.BackgroundTransparency = SURFACE_TRANSPARENCY
	status.BorderSizePixel = 0
	status.BackgroundColor3 = PALETTE.SurfaceAlt
	status.TextColor3 = DEFAULT_STATUS_COLOR
	status.Font = Enum.Font.GothamMedium
	status.TextScaled = false
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.TextYAlignment = Enum.TextYAlignment.Center
	status.Position = UDim2.fromScale(0.07, 0.205)
	status.Size = UDim2.fromScale(0.86, 0.105)
	ensureUICorner(status, 14)
	ensureUIStroke(status, PALETTE.PanelBorder, 1, 0.76)

	styleButton(closeButton, PALETTE.Surface, PALETTE.Text)
	closeButton.Position = UDim2.fromScale(0.84, 0.055)
	closeButton.Size = UDim2.fromScale(0.09, 0.075)
	closeButton.Text = "X"

	styleLabel(rangeTitle, PALETTE.Text, Enum.Font.GothamBold)
	rangeTitle.Position = UDim2.fromScale(0.07, 0.345)
	rangeTitle.Size = UDim2.fromScale(0.4, 0.045)
	rangeTitle.Text = "Jangkauan Speaker"

	styleLabel(minLabel, PALETTE.TextMuted, Enum.Font.GothamMedium)
	minLabel.Position = UDim2.fromScale(0.07, 0.405)
	minLabel.Size = UDim2.fromScale(0.12, 0.05)
	minLabel.Text = "Min"

	styleInput(minBox)
	minBox.Position = UDim2.fromScale(0.19, 0.402)
	minBox.Size = UDim2.fromScale(0.18, 0.075)

	styleLabel(maxLabel, PALETTE.TextMuted, Enum.Font.GothamMedium)
	maxLabel.Position = UDim2.fromScale(0.43, 0.405)
	maxLabel.Size = UDim2.fromScale(0.12, 0.05)
	maxLabel.Text = "Max"

	styleInput(maxBox)
	maxBox.Position = UDim2.fromScale(0.55, 0.402)
	maxBox.Size = UDim2.fromScale(0.18, 0.075)

	styleButton(applyRangeButton, PALETTE.Primary, PALETTE.Black)
	applyRangeButton.BackgroundTransparency = 0.18
	applyRangeButton.Position = UDim2.fromScale(0.76, 0.402)
	applyRangeButton.Size = UDim2.fromScale(0.17, 0.075)
	applyRangeButton.Text = "Terapkan"

	songList.BorderSizePixel = 0
	songList.BackgroundColor3 = PALETTE.SurfaceAlt
	songList.BackgroundTransparency = SURFACE_TRANSPARENCY
	songList.Position = UDim2.fromScale(0.07, 0.505)
	songList.Size = UDim2.fromScale(0.86, 0.27)
	songList.ScrollBarImageColor3 = PALETTE.PanelBorder
	songList.ScrollBarImageTransparency = 0.5
	songList.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	ensureUICorner(songList, 16)
	ensureUIStroke(songList, PALETTE.PanelBorder, 1, 0.76)

	if songListPadding then
		songListPadding.PaddingTop = UDim.new(0, 8)
		songListPadding.PaddingBottom = UDim.new(0, 8)
		songListPadding.PaddingLeft = UDim.new(0, 8)
		songListPadding.PaddingRight = UDim.new(0, 8)
	end

	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	template.BorderSizePixel = 0
	template.BackgroundColor3 = DEFAULT_BUTTON_COLOR
	template.BackgroundTransparency = BUTTON_TRANSPARENCY
	template.TextColor3 = DEFAULT_BUTTON_TEXT_COLOR
	template.Font = Enum.Font.GothamMedium
	template.TextScaled = false
	template.TextWrapped = false
	template.TextXAlignment = Enum.TextXAlignment.Center
	template.TextYAlignment = Enum.TextYAlignment.Center
	ensureUICorner(template, 10)
	ensureUIStroke(template, PALETTE.PanelBorder, 1, 0.72)

	styleButton(stopButton, PALETTE.Danger, PALETTE.White)
	stopButton.BackgroundTransparency = 0.3
	stopButton.Position = UDim2.fromScale(0.07, 0.825)
	stopButton.Size = UDim2.fromScale(0.86, 0.09)
	stopButton.Text = "Hentikan Musik"
end

local function updateCanvas()
	local extraPadding = compactLayout and 8 or 12
	songList.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + extraPadding)
end

local function applyResponsiveLayout()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)

	compactLayout = viewport.X < 520

	local width = math.clamp(viewport.X - (compactLayout and 24 or 72), 280, 400)
	local height = math.clamp(math.floor(viewport.Y * (compactLayout and 0.76 or 0.72)), 420, 600)
	local titleSize = compactLayout and 14 or 15
	local bodySize = compactLayout and 11 or 12
	local buttonTextSize = compactLayout and 11 or 12
	local songButtonHeight = compactLayout and 32 or 34

	main.Size = UDim2.fromOffset(width, height)

	title.TextSize = titleSize
	subtitle.TextSize = bodySize
	status.TextSize = bodySize
	rangeTitle.TextSize = bodySize
	minLabel.TextSize = bodySize
	maxLabel.TextSize = bodySize
	minBox.TextSize = bodySize
	maxBox.TextSize = bodySize
	applyRangeButton.TextSize = buttonTextSize
	stopButton.TextSize = compactLayout and 11 or 12
	closeButton.TextSize = compactLayout and 12 or 13
	closeButton.TextStrokeTransparency = 1
	closeButton.TextTransparency = 0

	songList.ScrollBarThickness = compactLayout and 4 or 6
	listLayout.Padding = UDim.new(0, compactLayout and 6 or 8)
	template.TextSize = buttonTextSize

	for _, button in ipairs(songButtons) do
		button.Size = UDim2.new(1, 0, 0, songButtonHeight)
		button.TextSize = buttonTextSize
	end

	updateCanvas()
end

local function attachViewportListener()
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end

	local camera = Workspace.CurrentCamera
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout)
	end
end

local function setStatus(message, tone)
	status.Text = message
	if tone == "warning" then
		status.TextColor3 = WARNING_STATUS_COLOR
	elseif tone == "active" then
		status.TextColor3 = ACTIVE_STATUS_COLOR
	else
		status.TextColor3 = DEFAULT_STATUS_COLOR
	end
end

local function disconnectSongConnections()
	for _, connection in ipairs(songConnections) do
		connection:Disconnect()
	end
	table.clear(songConnections)
end

local function clearSongButtons()
	disconnectSongConnections()
	for _, button in ipairs(songButtons) do
		button:Destroy()
	end
	table.clear(songButtons)
end

local function getSongNames(songNames)
	local names = {}
	if typeof(songNames) == "table" then
		for _, songName in ipairs(songNames) do
			table.insert(names, songName)
		end
	else
		for _, child in ipairs(audioFolder:GetChildren()) do
			if child:IsA("Sound") then
				table.insert(names, child.Name)
			end
		end
	end
	
	table.sort(names, function(a, b)
		return string.lower(a) < string.lower(b)
	end)
	return names
end

local function refreshSongButtons()
	for _, button in ipairs(songButtons) do
		local isActive = currentState.trackName ~= nil and currentState.trackName == button:GetAttribute("SongName")
		button.BackgroundColor3 = isActive and ACTIVE_BUTTON_COLOR or DEFAULT_BUTTON_COLOR
		button.BackgroundTransparency = isActive and 0.18 or BUTTON_TRANSPARENCY
		button.TextColor3 = isActive and ACTIVE_BUTTON_TEXT_COLOR or DEFAULT_BUTTON_TEXT_COLOR
		button.Text = button:GetAttribute("SongName")
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = isActive and PALETTE.PrimaryDark or PALETTE.PanelBorder
			stroke.Transparency = isActive and 0.35 or 0.72
		end
	end
end

local function buildSongButtons(songNames)
	clearSongButtons()

	local names = getSongNames(songNames)
	if #names == 0 then
		setStatus("Belum ada audio di ReplicatedStorage.Assets.Audio.", "warning")
		updateCanvas()
		return
	end

	for index, songName in ipairs(names) do
		local button = template:Clone()
		button.Name = "Song_" .. index
		button.Visible = true
		button.Parent = songList
		button.LayoutOrder = index
		button.Size = UDim2.new(1, 0, 0, compactLayout and 36 or 40)
		button.Text = songName
		button.TextSize = compactLayout and 13 or 14
		button:SetAttribute("SongName", songName)

		table.insert(songConnections, button.MouseButton1Click:Connect(function()
			setStatus("Memutar: " .. songName, "active")
			remote:FireServer("play", songName)
		end))

		table.insert(songButtons, button)
	end

	refreshSongButtons()
	updateCanvas()
end

local function applyState(nextState)
	if typeof(nextState) ~= "table" then
		nextState = {}
	end

	currentState.trackName = nextState.trackName
	currentState.minDistance = nextState.minDistance or currentState.minDistance
	currentState.maxDistance = nextState.maxDistance or currentState.maxDistance

	minBox.Text = tostring(currentState.minDistance)
	maxBox.Text = tostring(currentState.maxDistance)

	if currentState.trackName and currentState.trackName ~= "" then
		setStatus(currentState.trackName, "active")
	else
		setStatus("Belum ada lagu yang diputar.")
	end

	refreshSongButtons()
end

local function parseDistances()
	local minDistance = tonumber(minBox.Text)
	local maxDistance = tonumber(maxBox.Text)
	if not minDistance or not maxDistance then
		setStatus("Jarak minimum dan maksimum harus berupa angka.", "warning")
		return nil
	end

	minDistance = math.floor(minDistance + 0.5)
	maxDistance = math.floor(maxDistance + 0.5)

	if minDistance < 1 then
		setStatus("Jarak minimum harus lebih dari 0.", "warning")
		return nil
	end

	if maxDistance <= minDistance then
		setStatus("Jarak maksimum harus lebih besar dari minimum.", "warning")
		return nil
	end

	return minDistance, maxDistance
end

local function openPanel()
	applyResponsiveLayout()
	main.Visible = true
end

local function closePanel()
	main.Visible = false
end

styleStaticUi()
attachViewportListener()
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	attachViewportListener()
	applyResponsiveLayout()
end)

template.Visible = false
main.Visible = false

closeButton.MouseButton1Click:Connect(closePanel)

stopButton.MouseButton1Click:Connect(function()
	setStatus("Menghentikan musik...", "active")
	remote:FireServer("stop")
end)

applyRangeButton.MouseButton1Click:Connect(function()
	local minDistance, maxDistance = parseDistances()
	if not minDistance then
		return
	end

	currentState.minDistance = minDistance
	currentState.maxDistance = maxDistance
	setStatus(string.format("Jangkauan diperbarui: %d - %d", minDistance, maxDistance), "active")
	remote:FireServer("setDistances", {
		minDistance = minDistance,
		maxDistance = maxDistance,
	})
end)

listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

remote.OnClientEvent:Connect(function(action, payload)
	if action == "open" then
		title.Text = payload and payload.speaker or "Pemutar Musik"
		subtitle.Text = "Pilih lagu dan atur jangkauan suara speaker"
		buildSongButtons(payload and payload.songs or nil)
		applyState(payload and payload.state or nil)
		openPanel()
		remote:FireServer("requestState")
	elseif action == "state" then
		applyState(payload)
	end
end)

applyResponsiveLayout()
applyState(currentState)
updateCanvas()