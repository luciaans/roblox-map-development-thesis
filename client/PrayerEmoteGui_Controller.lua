local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local remote = ReplicatedStorage:WaitForChild("PrayerNotificationRemote")

local function sendNotification(payload)
	StarterGui:SetCore("SendNotification", {
		Title = payload.Title,
		Text = payload.Text,
		Duration = payload.Duration,
	})
end

local function showNotification(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local title = payload.Title or "Waktu Sholat"
	local text = payload.Text or "Sudah masuk waktu sholat."
	local duration = payload.Duration or 10
	local locationName = payload.LocationName
	if locationName and locationName ~= "" then
		text ..= " Lokasi: " .. locationName .. "."
	end

	local notificationPayload = {
		Title = title,
		Text = text,
		Duration = duration,
	}

	task.spawn(function()
		for _ = 1, 8 do
			local ok = pcall(sendNotification, notificationPayload)
			if ok then
				return
			end
			task.wait(0.5)
		end
	end)
end

remote.OnClientEvent:Connect(showNotification)