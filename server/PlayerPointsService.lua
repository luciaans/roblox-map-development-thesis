local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local POINTS_DATASTORE = "KutbahPlayerPoints_v1"
local POINTS_STAT_NAME = "Points"
local POINTS_REWARD = 10
local REWARD_INTERVAL = 60

local pointsStore = DataStoreService:GetDataStore(POINTS_DATASTORE)
local sessionPoints = {}
local notifyEvent = ReplicatedStorage:WaitForChild("KutbahPointsNotify")
local apiFolder = ServerScriptService:WaitForChild("PlayerPointsApi")
local adjustPointsFn = apiFolder:WaitForChild("AdjustPoints")
local getPointsFn = apiFolder:WaitForChild("GetPoints")

local function notifyPlayer(player, title, text)
	if player and player.Parent == Players then
		notifyEvent:FireClient(player, {
			title = title,
			text = text,
		})
	end
end

local function getLeaderstatsFolder(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		return leaderstats
	end

	leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	return leaderstats
end

local function getPointsValue(player)
	local leaderstats = getLeaderstatsFolder(player)
	local pointsValue = leaderstats:FindFirstChild(POINTS_STAT_NAME)
	if pointsValue then
		return pointsValue
	end

	pointsValue = Instance.new("IntValue")
	pointsValue.Name = POINTS_STAT_NAME
	pointsValue.Parent = leaderstats
	return pointsValue
end

local function setPlayerPoints(player, amount)
	amount = math.max(0, math.floor(amount))
	sessionPoints[player.UserId] = amount
	player:SetAttribute("KutbahPoints", amount)
	getPointsValue(player).Value = amount
	return amount
end

local function getPlayerPoints(player)
	return sessionPoints[player.UserId] or getPointsValue(player).Value
end

local function savePlayerPoints(player)
	local points = sessionPoints[player.UserId]
	if points == nil then
		return
	end

	local ok, err = pcall(function()
		pointsStore:SetAsync(tostring(player.UserId), points)
	end)
	if not ok then
		warn("Gagal menyimpan poin player:", player.Name, err)
	end
end

local function loadPlayerPoints(player)
	local points = 0
	local ok, result = pcall(function()
		return pointsStore:GetAsync(tostring(player.UserId))
	end)
	if ok and type(result) == "number" then
		points = result
	elseif not ok then
		warn("Gagal memuat poin player:", player.Name, result)
	end

	setPlayerPoints(player, points)
end

adjustPointsFn.OnInvoke = function(playerOrUserId, delta)
	delta = math.floor(tonumber(delta) or 0)
	if delta == 0 then
		return false, nil, "Jumlah poin tidak valid"
	end

	local player = playerOrUserId
	if typeof(playerOrUserId) == "number" then
		player = Players:GetPlayerByUserId(playerOrUserId)
	end
	if not player or not player:IsA("Player") then
		return false, nil, "Player harus sedang online"
	end

	local newAmount = setPlayerPoints(player, getPlayerPoints(player) + delta)
	savePlayerPoints(player)
	local sign = delta > 0 and "+" or ""
	notifyPlayer(player, "Poin", string.format("Poin Anda %s%d. Total sekarang: %d", sign, delta, newAmount))
	return true, newAmount, nil
end

getPointsFn.OnInvoke = function(playerOrUserId)
	local player = playerOrUserId
	if typeof(playerOrUserId) == "number" then
		player = Players:GetPlayerByUserId(playerOrUserId)
	end
	if not player or not player:IsA("Player") then
		return 0
	end
	return getPlayerPoints(player)
end

Players.PlayerAdded:Connect(function(player)
	loadPlayerPoints(player)
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayerPoints(player)
	sessionPoints[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadPlayerPoints, player)
end

task.spawn(function()
	while task.wait(REWARD_INTERVAL) do
		for _, player in ipairs(Players:GetPlayers()) do
			local newAmount = setPlayerPoints(player, getPlayerPoints(player) + POINTS_REWARD)
			savePlayerPoints(player)
			notifyPlayer(player, "Poin Bertambah", string.format("Anda mendapat +%d poin. Total: %d", POINTS_REWARD, newAmount))
			print(string.format("Poin +%d untuk %s. Total: %d", POINTS_REWARD, player.Name, newAmount))
		end
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerPoints(player)
	end
end)
