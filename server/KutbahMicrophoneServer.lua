local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

-- === 1. PENGATURAN ===
local VOLUME_MIC = 7
local DIRECT_LEVEL = 0.35
local REVERB_WET = 0.02
local REVERB_DECAY = 0.12
local MAX_MIMBAR_DISTANCE = 5
local MIC_COST = 50

local kutbahModel = Workspace:WaitForChild("Misc_Models"):WaitForChild("Kutbah")
local micModel = kutbahModel:WaitForChild("Microphone")
local emitterPart = micModel:FindFirstChild("Part") or micModel:FindFirstChildOfClass("BasePart")
local notifyEvent = ReplicatedStorage:WaitForChild("KutbahPointsNotify")

local apiFolder      = ServerScriptService:WaitForChild("PlayerPointsApi")
local adjustPointsFn = apiFolder:WaitForChild("AdjustPoints")
local getPointsFn    = apiFolder:WaitForChild("GetPoints")

-- State
local isMicActive = false
local currentSpeaker = nil

local function notifyPlayer(player, title, text)
	if player and player.Parent == Players then
		notifyEvent:FireClient(player, { title = title, text = text })
	end
end

-- === 2. SETUP AUDIO EFFECTS ===
local function setupEffects()
	for _, v in ipairs(micModel:GetDescendants()) do
		if v:IsA("AudioEcho") or v:IsA("AudioReverb") or v:IsA("AudioEmitter") or v:IsA("AudioFader") or v:IsA("Wire") then
			v:Destroy()
		end
	end

	local emitter = Instance.new("AudioEmitter")
	emitter.Name = "Toa_Speaker"
	emitter:SetDistanceAttenuation({ [0]=4.0, [150]=2.5, [350]=1.2, [600]=0 })
	emitter.Parent = emitterPart

	local directFader = Instance.new("AudioFader", micModel)
	directFader.Name = "DirectFader"; directFader.Volume = DIRECT_LEVEL

	local reverb = Instance.new("AudioReverb", micModel)
	reverb.DryLevel = 0; reverb.WetLevel = REVERB_WET; reverb.DecayTime = REVERB_DECAY

	local function connect(name, src, tgt)
		local w = Instance.new("Wire", micModel)
		w.Name = name; w.SourceInstance = src; w.TargetInstance = tgt
	end
	connect("W_DirectToEmitter", directFader, emitter)
	connect("W_ReverbToEmitter", reverb, emitter)
	return directFader, reverb, emitter
end

local directFader, reverbEffect, toaEmitter = setupEffects()

-- === 3. UI ENGINE ===
local function refreshStatusUI(state, player)
	local gui = micModel:FindFirstChild("MicStatusGui")
	local label = gui and gui:FindFirstChild("StatusLabel")
	if label then
		if state then
			label.Text = "● TOA LIVE: " .. (player and player.DisplayName:upper() or "UNKNOWN")
			label.TextColor3 = Color3.fromRGB(0, 255, 120)
		else
			label.Text = "○ MIC STANDBY"
			label.TextColor3 = Color3.fromRGB(255, 70, 70)
		end
	end
	local indicator = micModel:FindFirstChild("IndicatorLight")
	if indicator then
		indicator.Color = state and Color3.fromRGB(0, 255, 120) or Color3.fromRGB(200, 0, 0)
	end
end

-- === 4. CORE LOGIC ===
local function toggleMic(player)
	if isMicActive then
		-- OFF
		isMicActive = false; currentSpeaker = nil
		if player then
			local mic = player:FindFirstChild("ToaMic")
			if mic then mic:Destroy() end
		end
		for _, v in ipairs(micModel:GetChildren()) do
			if v.Name == "PlayerWire" or v.Name == "DirectWire" or v.Name == "ReverbWire" or v.Name == "MonitorWire" then
				v:Destroy()
			end
		end
		refreshStatusUI(false)
		print("Mic OFF")
	else
		-- Cek poin sebelum aktifkan
		local pts = getPointsFn:Invoke(player)
		if pts < MIC_COST then
			notifyPlayer(player, "Poin Tidak Cukup",
				string.format("Butuh %d poin. Kamu punya %d poin.", MIC_COST, pts))
			return
		end
		adjustPointsFn:Invoke(player, -MIC_COST)
		notifyPlayer(player, "Mic Aktif",
			string.format("-%d poin digunakan. Sisa: %d poin.", MIC_COST, pts - MIC_COST))

		-- ON
		isMicActive = true; currentSpeaker = player

		local micInput = Instance.new("AudioDeviceInput")
		micInput.Name = "ToaMic"; micInput.Player = player
		micInput.Volume = VOLUME_MIC; micInput.Parent = player

		local directWire = Instance.new("Wire", micModel)
		directWire.Name = "DirectWire"
		directWire.SourceInstance = micInput; directWire.TargetInstance = directFader

		local reverbWire = Instance.new("Wire", micModel)
		reverbWire.Name = "ReverbWire"
		reverbWire.SourceInstance = micInput; reverbWire.TargetInstance = reverbEffect

		task.wait(0.4)
		if isMicActive and currentSpeaker == player then
			micInput.Muted = false
			refreshStatusUI(true, player)
			print("Mic ON")
		end
	end
end

-- === 5. INTERAKSI ===
local promptPart = micModel:FindFirstChild("Union") or micModel:FindFirstChild("Part")
local prompt = promptPart and promptPart:FindFirstChild("MicTogglePrompt")
if prompt then
	prompt.ActionText = "Gunakan Mic"
	prompt.Triggered:Connect(function(player)
		if not isMicActive or currentSpeaker == player then
			toggleMic(player)
		else
			warn("Mic sedang digunakan")
		end
	end)
end

-- === 6. AUTO-OFF DISTANCE LOOP ===
task.spawn(function()
	while task.wait(1) do
		if isMicActive and currentSpeaker then
			local char = currentSpeaker.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dist = (hrp.Position - emitterPart.Position).Magnitude
				if dist > MAX_MIMBAR_DISTANCE then
					print("Penceramah terlalu jauh dari mimbar, Mic OFF")
					toggleMic(currentSpeaker)
				end
			else
				toggleMic(currentSpeaker)
			end
		end
	end
end)

refreshStatusUI(false)
Players.PlayerRemoving:Connect(function(p)
	if currentSpeaker == p then toggleMic(p) end
end)