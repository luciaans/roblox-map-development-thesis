local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PrayerTimeUtils = require(ReplicatedStorage:WaitForChild("PrayerTimeUtils"))
local remote = ReplicatedStorage:WaitForChild("PrayerNotificationRemote")

local PRAYER_ORDER = PrayerTimeUtils.PRAYER_ORDER
local PRAYER_MESSAGES = {
	SUBUH = "Sudah masuk waktu sholat Subuh.",
	DZUHUR = "Sudah masuk waktu sholat Dzuhur.",
	ASHAR = "Sudah masuk waktu sholat Ashar.",
	MAGHRIB = "Sudah masuk waktu sholat Maghrib.",
	ISYA = "Sudah masuk waktu sholat Isya.",
}

local PRAYER_REMINDER_MESSAGES = {
	SUBUH = "10 menit lagi akan masuk waktu sholat Subuh.",
	DZUHUR = "10 menit lagi akan masuk waktu sholat Dzuhur.",
	ASHAR = "10 menit lagi akan masuk waktu sholat Ashar.",
	MAGHRIB = "10 menit lagi akan masuk waktu sholat Maghrib.",
	ISYA = "10 menit lagi akan masuk waktu sholat Isya.",
}

local lastBroadcastKey
local lastReminderKey
local lastDateKey
local lastConfigKey
local cachedSchedule = {}

local function findReferenceJam()
	return Workspace:FindFirstChild("JamSolat")
end

local function getScheduleForToday(dateTable, jamModel)
	local dateKey = PrayerTimeUtils.getDateKey(dateTable)
	local configKey = PrayerTimeUtils.getConfigKey(jamModel, { "ReminderMinutesBefore" })
	if dateKey ~= lastDateKey or configKey ~= lastConfigKey then
		cachedSchedule = PrayerTimeUtils.computePrayerSchedule(table.clone(dateTable), jamModel) or {}
		lastDateKey = dateKey
		lastConfigKey = configKey
	end
	return cachedSchedule
end

local function fireNotification(title, text, prayerName, locationName, duration)
	remote:FireAllClients({
		Title = title,
		Text = text,
		PrayerName = prayerName,
		LocationName = locationName,
		Duration = duration,
	})
end

task.spawn(function()
	while true do
		local jamModel = findReferenceJam()
		if jamModel then
			PrayerTimeUtils.ensureDefaultAttributes(jamModel)
			local dateTable = PrayerTimeUtils.getLocalDateTable(jamModel)
			local schedule = getScheduleForToday(dateTable, jamModel)
			if next(schedule) ~= nil then
				local dateKey = PrayerTimeUtils.getDateKey(dateTable)
				local locationName = PrayerTimeUtils.getStringAttribute(jamModel, "LocationName")
				local reminderMinutesBefore = math.max(0, math.floor(PrayerTimeUtils.getNumberAttribute(jamModel, "ReminderMinutesBefore")))
				local nowMinuteOfDay = dateTable.hour * 60 + dateTable.min

				for _, prayerName in ipairs(PRAYER_ORDER) do
					local prayerMinutes = schedule[prayerName]
					if prayerMinutes then
						local prayerHour = math.floor(prayerMinutes / 60)
						local prayerMinute = math.floor(prayerMinutes % 60)
						local prayerTimeKey = string.format("%02d:%02d", prayerHour, prayerMinute)

						if reminderMinutesBefore > 0 then
							local reminderMinutes = PrayerTimeUtils.normalizeMinutes(prayerMinutes - reminderMinutesBefore)
							local reminderHour = math.floor(reminderMinutes / 60)
							local reminderMinute = math.floor(reminderMinutes % 60)
							if nowMinuteOfDay == reminderHour * 60 + reminderMinute then
								local reminderKey = dateKey .. "|reminder|" .. prayerName .. "|" .. prayerTimeKey
								if lastReminderKey ~= reminderKey then
									lastReminderKey = reminderKey
									local reminderText = (PRAYER_REMINDER_MESSAGES[prayerName] or ("Sebentar lagi masuk waktu sholat " .. prayerName .. ".")):gsub("10 menit", tostring(reminderMinutesBefore) .. " menit")
									fireNotification("Pengingat Sholat", reminderText, prayerName, locationName, 8)
								end
							end
						end

						if nowMinuteOfDay == prayerHour * 60 + prayerMinute then
							local broadcastKey = dateKey .. "|prayer|" .. prayerName .. "|" .. prayerTimeKey
							if lastBroadcastKey ~= broadcastKey then
								lastBroadcastKey = broadcastKey
								fireNotification("Waktu Sholat", PRAYER_MESSAGES[prayerName] or ("Sudah masuk waktu sholat " .. prayerName .. "."), prayerName, locationName, 10)
							end
							break
						end
					end
				end
			end
		end
		task.wait(1)
	end
end)