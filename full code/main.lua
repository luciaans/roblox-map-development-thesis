-- Lampiran Kode Lua Map Roblox
-- GeneratedAt: 2026-06-06 19:32:22 UTC
-- ModuleScript ini menyimpan semua source code sebagai string agar mudah disalin ke lampiran skripsi.
-- Panggil require hanya jika ingin membaca tabel Lampiran, bukan untuk menjalankan script asli.

local Lampiran = {}

-- 01. 01_JamSolat_JamLogic
-- OriginalPath: Workspace.Systems_And_Scripts.JamSolat.SurfaceGui.JamLogic
-- Role: Menampilkan jam, jadwal salat, running text, highlight salat aktif, dan alarm pada papan JamSolat 3D.
Lampiran["01_JamSolat_JamLogic"] = {
	OriginalPath = "Workspace.Systems_And_Scripts.JamSolat.SurfaceGui.JamLogic",
	ClassName = "Script",
	Role = "Menampilkan jam, jadwal salat, running text, highlight salat aktif, dan alarm pada papan JamSolat 3D.",
	Source = [=[
local RunService = game:GetService("RunService")

local surfaceGui = script.Parent
local jamModel = surfaceGui.Parent
local mainFrame = surfaceGui:WaitForChild("MainFrame")
local dateLabel = mainFrame:WaitForChild("DateLabel")
local bigClock = mainFrame:WaitForChild("BigClock")
local gridFrame = mainFrame:WaitForChild("GridFrame")
local runContainer = mainFrame:WaitForChild("RunContainer")
local runningTextLabel = runContainer:WaitForChild("RunningText")
local runningTextValue = script:FindFirstChild("RUNNINGTEXT")
local alarmSound = jamModel:FindFirstChild("AlarmSound")

local DEFAULTS = {
	LocationName = "Jakarta",
	Latitude = -6.2088,
	Longitude = 106.8456,
	TimeZoneOffset = 7,
	FajrAngle = 20,
	IshaAngle = 18,
	DhuhrOffsetMinutes = 2,
	AlarmDurationSeconds = 18,
}

local PRAYER_ORDER = { "SUBUH", "DZUHUR", "ASHAR", "MAGHRIB", "ISYA" }
local WEEKDAYS = { "MINGGU", "SENIN", "SELASA", "RABU", "KAMIS", "JUMAT", "SABTU" }
local MONTHS = { "JAN", "FEB", "MAR", "APR", "MEI", "JUN", "JUL", "AGS", "SEP", "OKT", "NOV", "DES" }
local HIGHLIGHT_COLOR = Color3.fromRGB(255, 220, 120)
local NORMAL_COLOR = Color3.fromRGB(255, 255, 255)

local lastDateKey
local lastScheduleKey
local cachedSchedule = {}
local lastTriggeredMinuteKey
local marqueeOffset = 0

local function ensureAttribute(name)
	if jamModel:GetAttribute(name) == nil then
		jamModel:SetAttribute(name, DEFAULTS[name])
	end
end

for attributeName in pairs(DEFAULTS) do
	ensureAttribute(attributeName)
end

local function getNumberAttribute(name)
	local value = jamModel:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return DEFAULTS[name]
end

local function getStringAttribute(name)
	local value = jamModel:GetAttribute(name)
	if typeof(value) == "string" and value ~= "" then
		return value
	end
	return DEFAULTS[name]
end

local function getPrayerRows()
	local rows = {}
	for _, child in ipairs(gridFrame:GetChildren()) do
		if child:IsA("Frame") then
			local labels = {}
			for _, descendant in ipairs(child:GetChildren()) do
				if descendant:IsA("TextLabel") then
					table.insert(labels, descendant)
				end
			end
			if #labels >= 2 then
				local prayerName = string.upper(labels[1].Text)
				rows[prayerName] = {
					nameLabel = labels[1],
					timeLabel = labels[2],
				}
			end
		end
	end
	return rows
end

local prayerRows = getPrayerRows()

local function clamp(value, minValue, maxValue)
	return math.max(minValue, math.min(maxValue, value))
end

local function degToRad(value)
	return math.rad(value)
end

local function radToDeg(value)
	return math.deg(value)
end

local function normalizeMinutes(minutes)
	local wrapped = minutes % 1440
	if wrapped < 0 then
		wrapped += 1440
	end
	return wrapped
end

local function minutesToClock(minutes, includeSeconds)
	local totalSeconds = math.floor(minutes * 60 + 0.5)
	totalSeconds %= 86400
	local hours = math.floor(totalSeconds / 3600)
	local mins = math.floor((totalSeconds % 3600) / 60)
	local secs = totalSeconds % 60
	if includeSeconds then
		return string.format("%02d:%02d:%02d", hours, mins, secs)
	end
	return string.format("%02d:%02d", hours, mins)
end

local function getLocalUnixTime()
	local utcUnix = DateTime.now().UnixTimestampMillis / 1000
	return utcUnix + getNumberAttribute("TimeZoneOffset") * 3600
end

local function getLocalDateTable()
	return os.date("!*t", getLocalUnixTime())
end

local function dayOfYear(dateTable)
	local yearStart = os.time({ year = dateTable.year, month = 1, day = 1, hour = 0, min = 0, sec = 0 })
	local current = os.time({ year = dateTable.year, month = dateTable.month, day = dateTable.day, hour = 0, min = 0, sec = 0 })
	return math.floor((current - yearStart) / 86400) + 1
end

local function solarDeclinationAndEquationOfTime(dateTable)
	local gamma = 2 * math.pi / (dateTable.yday or dayOfYear(dateTable)) * ((dateTable.hour - 12) / 24)
	local decl = 0.006918
		- 0.399912 * math.cos(gamma)
		+ 0.070257 * math.sin(gamma)
		- 0.006758 * math.cos(2 * gamma)
		+ 0.000907 * math.sin(2 * gamma)
		- 0.002697 * math.cos(3 * gamma)
		+ 0.00148 * math.sin(3 * gamma)
	local eqTime = 229.18 * (
		0.000075
		+ 0.001868 * math.cos(gamma)
		- 0.032077 * math.sin(gamma)
		- 0.014615 * math.cos(2 * gamma)
		- 0.040849 * math.sin(2 * gamma)
	)
	return decl, eqTime
end

local function hourAngle(latitudeDeg, declinationRad, solarAltitudeDeg)
	local latitudeRad = degToRad(latitudeDeg)
	local altitudeRad = degToRad(solarAltitudeDeg)
	local numerator = math.sin(altitudeRad) - math.sin(latitudeRad) * math.sin(declinationRad)
	local denominator = math.cos(latitudeRad) * math.cos(declinationRad)
	if math.abs(denominator) < 1e-6 then
		return nil
	end
	local value = clamp(numerator / denominator, -1, 1)
	return radToDeg(math.acos(value))
end

local function computePrayerSchedule(dateTable)
	local latitude = getNumberAttribute("Latitude")
	local longitude = getNumberAttribute("Longitude")
	local timezone = getNumberAttribute("TimeZoneOffset")
	local fajrAngle = getNumberAttribute("FajrAngle")
	local ishaAngle = getNumberAttribute("IshaAngle")
	local dhuhrOffset = getNumberAttribute("DhuhrOffsetMinutes")

	dateTable.yday = dateTable.yday or dayOfYear(dateTable)
	local declinationRad, equationOfTime = solarDeclinationAndEquationOfTime(dateTable)
	local solarNoon = 720 - 4 * longitude - equationOfTime + timezone * 60

	local sunriseHourAngle = hourAngle(latitude, declinationRad, -0.833)
	local fajrHourAngle = hourAngle(latitude, declinationRad, -fajrAngle)
	local ishaHourAngle = hourAngle(latitude, declinationRad, -ishaAngle)
	local asrAngle = radToDeg(math.atan(1 / (1 + math.tan(math.abs(degToRad(latitude) - declinationRad)))))
	local asrHourAngle = hourAngle(latitude, declinationRad, asrAngle)

	if not sunriseHourAngle or not fajrHourAngle or not ishaHourAngle or not asrHourAngle then
		return nil
	end

	local schedule = {
		SUBUH = normalizeMinutes(solarNoon - fajrHourAngle * 4),
		DZUHUR = normalizeMinutes(solarNoon + dhuhrOffset),
		ASHAR = normalizeMinutes(solarNoon + asrHourAngle * 4),
		MAGHRIB = normalizeMinutes(solarNoon + sunriseHourAngle * 4),
		ISYA = normalizeMinutes(solarNoon + ishaHourAngle * 4),
	}

	return schedule
end

local function getScheduleForToday(dateTable)
	local dateKey = string.format("%04d-%02d-%02d", dateTable.year, dateTable.month, dateTable.day)
	local configKey = table.concat({
		getStringAttribute("LocationName"),
		getNumberAttribute("Latitude"),
		getNumberAttribute("Longitude"),
		getNumberAttribute("TimeZoneOffset"),
		getNumberAttribute("FajrAngle"),
		getNumberAttribute("IshaAngle"),
		getNumberAttribute("DhuhrOffsetMinutes"),
	}, "|")

	if dateKey ~= lastDateKey or configKey ~= lastScheduleKey then
		cachedSchedule = computePrayerSchedule(table.clone(dateTable)) or {}
		lastDateKey = dateKey
		lastScheduleKey = configKey
	end

	return cachedSchedule
end

local function updateDateAndClock(dateTable)
	local weekdayName = WEEKDAYS[(dateTable.wday or 1)] or WEEKDAYS[1]
	local monthName = MONTHS[dateTable.month] or "JAN"
	dateLabel.Text = string.format("%s, %02d %s %04d", weekdayName, dateTable.day, monthName, dateTable.year)
	bigClock.Text = string.format("%02d:%02d:%02d", dateTable.hour, dateTable.min, dateTable.sec)
end

local function getCurrentPrayerAndNext(schedule, nowMinutes)
	local currentPrayer
	local nextPrayer

	for index, prayerName in ipairs(PRAYER_ORDER) do
		local prayerMinutes = schedule[prayerName]
		local nextName = PRAYER_ORDER[index + 1]
		local nextMinutes = nextName and schedule[nextName] or (schedule[PRAYER_ORDER[1]] + 1440)
		local comparableNow = nowMinutes
		if nextMinutes < prayerMinutes then
			nextMinutes += 1440
			if comparableNow < prayerMinutes then
				comparableNow += 1440
			end
		end
		if comparableNow >= prayerMinutes and comparableNow < nextMinutes then
			currentPrayer = prayerName
			nextPrayer = nextName or PRAYER_ORDER[1]
			break
		end
	end

	if not currentPrayer then
		currentPrayer = PRAYER_ORDER[#PRAYER_ORDER]
		nextPrayer = PRAYER_ORDER[1]
	end

	return currentPrayer, nextPrayer
end

local function updatePrayerRows(schedule, nowMinutes)
	local currentPrayer, nextPrayer = getCurrentPrayerAndNext(schedule, nowMinutes)
	for _, prayerName in ipairs(PRAYER_ORDER) do
		local row = prayerRows[prayerName]
		if row then
			row.timeLabel.Text = minutesToClock(schedule[prayerName] or 0, false)
			local color = NORMAL_COLOR
			if prayerName == currentPrayer then
				color = HIGHLIGHT_COLOR
			elseif prayerName == nextPrayer then
				color = Color3.fromRGB(180, 255, 180)
			end
			row.nameLabel.TextColor3 = color
			row.timeLabel.TextColor3 = color
		end
	end
end

local function updateRunningText(deltaTime)
	local message = runningTextValue and runningTextValue.Value or runningTextLabel.Text
	if message == "" then
		message = DEFAULTS.LocationName
	end
	runningTextLabel.Text = "   " .. message .. "   "
	marqueeOffset += deltaTime * 0.12
	local wrapped = marqueeOffset % 2
	runningTextLabel.Position = UDim2.new(1 - wrapped, 0, runningTextLabel.Position.Y.Scale, runningTextLabel.Position.Y.Offset)
end

local function triggerAlarmIfNeeded(dateTable, schedule)
	if not alarmSound then
		return
	end

	local minuteKeyDate = string.format("%04d-%02d-%02d", dateTable.year, dateTable.month, dateTable.day)
	for _, prayerName in ipairs(PRAYER_ORDER) do
		local prayerMinutes = schedule[prayerName]
		local prayerHour = math.floor(prayerMinutes / 60)
		local prayerMinute = math.floor(prayerMinutes % 60)
		if dateTable.hour == prayerHour and dateTable.min == prayerMinute then
			local minuteKey = minuteKeyDate .. "|" .. prayerName .. "|" .. string.format("%02d:%02d", prayerHour, prayerMinute)
			if lastTriggeredMinuteKey ~= minuteKey then
				lastTriggeredMinuteKey = minuteKey
				alarmSound.TimePosition = 0
				alarmSound:Play()
				task.delay(getNumberAttribute("AlarmDurationSeconds"), function()
					if alarmSound.IsPlaying and lastTriggeredMinuteKey == minuteKey then
						alarmSound:Stop()
					end
				end)
			end
			return
		end
	end
end

RunService.Heartbeat:Connect(function(deltaTime)
	local dateTable = getLocalDateTable()
	updateDateAndClock(dateTable)
	updateRunningText(deltaTime)

	local schedule = getScheduleForToday(dateTable)
	if next(schedule) == nil then
		return
	end

	local nowMinutes = dateTable.hour * 60 + dateTable.min + dateTable.sec / 60
	updatePrayerRows(schedule, nowMinutes)
	triggerAlarmIfNeeded(dateTable, schedule)
end)

]=],
}

-- 02. 02_PrayerTimeUtils
-- OriginalPath: ReplicatedStorage.PrayerTimeUtils
-- Role: Library perhitungan jadwal salat berdasarkan koordinat, zona waktu, sudut Subuh/Isya, serta utilitas format waktu.
Lampiran["02_PrayerTimeUtils"] = {
	OriginalPath = "ReplicatedStorage.PrayerTimeUtils",
	ClassName = "ModuleScript",
	Role = "Library perhitungan jadwal salat berdasarkan koordinat, zona waktu, sudut Subuh/Isya, serta utilitas format waktu.",
	Source = [[
local PrayerTimeUtils = {}

PrayerTimeUtils.DEFAULTS = {
	LocationName = "Jakarta",
	Latitude = -6.2088,
	Longitude = 106.8456,
	TimeZoneOffset = 7,
	FajrAngle = 20,
	IshaAngle = 18,
	DhuhrOffsetMinutes = 2,
	ReminderMinutesBefore = 10,
	AlarmDurationSeconds = 18,
}

PrayerTimeUtils.PRAYER_ORDER = { "SUBUH", "DZUHUR", "ASHAR", "MAGHRIB", "ISYA" }
PrayerTimeUtils.WEEKDAYS_UPPER = { "MINGGU", "SENIN", "SELASA", "RABU", "KAMIS", "JUMAT", "SABTU" }
PrayerTimeUtils.MONTHS_UPPER = { "JAN", "FEB", "MAR", "APR", "MEI", "JUN", "JUL", "AGS", "SEP", "OKT", "NOV", "DES" }
PrayerTimeUtils.WEEKDAYS_TITLE = { "Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu" }
PrayerTimeUtils.MONTHS_TITLE = { "Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Ags", "Sep", "Okt", "Nov", "Des" }

local function clamp(value, minValue, maxValue)
	return math.max(minValue, math.min(maxValue, value))
end

local function degToRad(value)
	return math.rad(value)
end

local function radToDeg(value)
	return math.deg(value)
end

function PrayerTimeUtils.ensureDefaultAttributes(instance, defaults)
	defaults = defaults or PrayerTimeUtils.DEFAULTS
	for name, value in pairs(defaults) do
		if instance:GetAttribute(name) == nil then
			instance:SetAttribute(name, value)
		end
	end
end

function PrayerTimeUtils.getNumberAttribute(instance, name, defaults)
	defaults = defaults or PrayerTimeUtils.DEFAULTS
	local value = instance and instance:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	if typeof(value) == "string" then
		local parsed = tonumber(value)
		if parsed ~= nil then
			return parsed
		end
	end
	return defaults[name]
end

function PrayerTimeUtils.getStringAttribute(instance, name, defaults)
	defaults = defaults or PrayerTimeUtils.DEFAULTS
	local value = instance and instance:GetAttribute(name)
	if typeof(value) == "string" and value ~= "" then
		return value
	end
	return defaults[name]
end

function PrayerTimeUtils.normalizeMinutes(minutes)
	local wrapped = minutes % 1440
	if wrapped < 0 then
		wrapped += 1440
	end
	return wrapped
end

function PrayerTimeUtils.minutesToClock(minutes, includeSeconds)
	local totalSeconds = math.floor(minutes * 60 + 0.5)
	totalSeconds %= 86400
	local hours = math.floor(totalSeconds / 3600)
	local mins = math.floor((totalSeconds % 3600) / 60)
	local secs = totalSeconds % 60
	if includeSeconds then
		return string.format("%02d:%02d:%02d", hours, mins, secs)
	end
	return string.format("%02d:%02d", hours, mins)
end

function PrayerTimeUtils.dayOfYear(dateTable)
	local yearStart = os.time({ year = dateTable.year, month = 1, day = 1, hour = 0, min = 0, sec = 0 })
	local current = os.time({ year = dateTable.year, month = dateTable.month, day = dateTable.day, hour = 0, min = 0, sec = 0 })
	return math.floor((current - yearStart) / 86400) + 1
end

function PrayerTimeUtils.getDateKey(dateTable)
	return string.format("%04d-%02d-%02d", dateTable.year, dateTable.month, dateTable.day)
end

function PrayerTimeUtils.getConfigKey(instance, extraKeys, defaults)
	defaults = defaults or PrayerTimeUtils.DEFAULTS
	local keys = {
		PrayerTimeUtils.getStringAttribute(instance, "LocationName", defaults),
		PrayerTimeUtils.getNumberAttribute(instance, "Latitude", defaults),
		PrayerTimeUtils.getNumberAttribute(instance, "Longitude", defaults),
		PrayerTimeUtils.getNumberAttribute(instance, "TimeZoneOffset", defaults),
		PrayerTimeUtils.getNumberAttribute(instance, "FajrAngle", defaults),
		PrayerTimeUtils.getNumberAttribute(instance, "IshaAngle", defaults),
		PrayerTimeUtils.getNumberAttribute(instance, "DhuhrOffsetMinutes", defaults),
	}
	for _, key in ipairs(extraKeys or {}) do
		if type(key) == "string" then
			local stringValue = PrayerTimeUtils.getStringAttribute(instance, key, defaults)
			local numberValue = PrayerTimeUtils.getNumberAttribute(instance, key, defaults)
			if stringValue ~= defaults[key] or defaults[key] == nil then
				table.insert(keys, stringValue)
			else
				table.insert(keys, numberValue)
			end
		else
			table.insert(keys, key)
		end
	end
	return table.concat(keys, "|")
end

function PrayerTimeUtils.getLocalDateTable(instance, defaults)
	defaults = defaults or PrayerTimeUtils.DEFAULTS
	local utcUnix = DateTime.now().UnixTimestampMillis / 1000
	local localUnix = utcUnix + PrayerTimeUtils.getNumberAttribute(instance, "TimeZoneOffset", defaults) * 3600
	return os.date("!*t", localUnix), localUnix
end

function PrayerTimeUtils.solarDeclinationAndEquationOfTime(dateTable)
	local gamma = 2 * math.pi / (dateTable.yday or PrayerTimeUtils.dayOfYear(dateTable)) * ((dateTable.hour - 12) / 24)
	local decl = 0.006918
		- 0.399912 * math.cos(gamma)
		+ 0.070257 * math.sin(gamma)
		- 0.006758 * math.cos(2 * gamma)
		+ 0.000907 * math.sin(2 * gamma)
		- 0.002697 * math.cos(3 * gamma)
		+ 0.00148 * math.sin(3 * gamma)
	local eqTime = 229.18 * (
		0.000075
		+ 0.001868 * math.cos(gamma)
		- 0.032077 * math.sin(gamma)
		- 0.014615 * math.cos(2 * gamma)
		- 0.040849 * math.sin(2 * gamma)
	)
	return decl, eqTime
end

function PrayerTimeUtils.hourAngle(latitudeDeg, declinationRad, solarAltitudeDeg)
	local latitudeRad = degToRad(latitudeDeg)
	local altitudeRad = degToRad(solarAltitudeDeg)
	local numerator = math.sin(altitudeRad) - math.sin(latitudeRad) * math.sin(declinationRad)
	local denominator = math.cos(latitudeRad) * math.cos(declinationRad)
	if math.abs(denominator) < 1e-6 then
		return nil
	end
	return radToDeg(math.acos(clamp(numerator / denominator, -1, 1)))
end

function PrayerTimeUtils.computePrayerSchedule(dateTable, instance, options)
	options = options or {}
	local defaults = options.defaults or PrayerTimeUtils.DEFAULTS
	local latitude = PrayerTimeUtils.getNumberAttribute(instance, "Latitude", defaults)
	local longitude = PrayerTimeUtils.getNumberAttribute(instance, "Longitude", defaults)
	local timezone = PrayerTimeUtils.getNumberAttribute(instance, "TimeZoneOffset", defaults)
	local fajrAngle = PrayerTimeUtils.getNumberAttribute(instance, "FajrAngle", defaults)
	local ishaAngle = PrayerTimeUtils.getNumberAttribute(instance, "IshaAngle", defaults)
	local dhuhrOffset = PrayerTimeUtils.getNumberAttribute(instance, "DhuhrOffsetMinutes", defaults)

	dateTable.yday = dateTable.yday or PrayerTimeUtils.dayOfYear(dateTable)
	local declinationRad, equationOfTime = PrayerTimeUtils.solarDeclinationAndEquationOfTime(dateTable)
	local solarNoon = 720 - 4 * longitude - equationOfTime + timezone * 60

	local sunriseHourAngle = PrayerTimeUtils.hourAngle(latitude, declinationRad, -0.833)
	local fajrHourAngle = PrayerTimeUtils.hourAngle(latitude, declinationRad, -fajrAngle)
	local ishaHourAngle = PrayerTimeUtils.hourAngle(latitude, declinationRad, -ishaAngle)
	local asrAngle = radToDeg(math.atan(1 / (1 + math.tan(math.abs(degToRad(latitude) - declinationRad)))))
	local asrHourAngle = PrayerTimeUtils.hourAngle(latitude, declinationRad, asrAngle)

	if not sunriseHourAngle or not fajrHourAngle or not ishaHourAngle or not asrHourAngle then
		return nil
	end

	local schedule = {
		SUBUH = PrayerTimeUtils.normalizeMinutes(solarNoon - fajrHourAngle * 4),
		DZUHUR = PrayerTimeUtils.normalizeMinutes(solarNoon + dhuhrOffset),
		ASHAR = PrayerTimeUtils.normalizeMinutes(solarNoon + asrHourAngle * 4),
		MAGHRIB = PrayerTimeUtils.normalizeMinutes(solarNoon + sunriseHourAngle * 4),
		ISYA = PrayerTimeUtils.normalizeMinutes(solarNoon + ishaHourAngle * 4),
	}
	if options.includeSunrise then
		schedule.SUNRISE = PrayerTimeUtils.normalizeMinutes(solarNoon - sunriseHourAngle * 4)
	end
	return schedule
end

function PrayerTimeUtils.getCurrentPrayerAndNext(schedule, nowMinutes, prayerOrder)
	prayerOrder = prayerOrder or PrayerTimeUtils.PRAYER_ORDER
	local currentPrayer = prayerOrder[#prayerOrder]
	local nextPrayer = prayerOrder[1]
	for index, prayerName in ipairs(prayerOrder) do
		local prayerMinutes = schedule[prayerName]
		local nextName = prayerOrder[index + 1] or prayerOrder[1]
		local nextMinutes = schedule[nextName]
		local comparableNow = nowMinutes
		if nextName == prayerOrder[1] then
			nextMinutes += 1440
			if comparableNow < prayerMinutes then
				comparableNow += 1440
			end
		end
		if comparableNow >= prayerMinutes and comparableNow < nextMinutes then
			currentPrayer = prayerName
			nextPrayer = nextName
			break
		end
	end
	return currentPrayer, nextPrayer
end

function PrayerTimeUtils.minutesUntil(nowMinutes, targetMinutes)
	local delta = targetMinutes - nowMinutes
	if delta < 0 then
		delta += 1440
	end
	return delta
end

function PrayerTimeUtils.formatCountdown(totalMinutes)
	local rounded = math.max(0, math.floor(totalMinutes + 0.5))
	local hours = math.floor(rounded / 60)
	local mins = rounded % 60
	if hours > 0 then
		return string.format("%dj %02dm lagi", hours, mins)
	end
	return string.format("%dm lagi", mins)
end

return PrayerTimeUtils
]],
}

-- 03. 03_DakwahWorldController
-- OriginalPath: ServerScriptService.DakwahWorldController
-- Role: Mengatur siklus waktu dunia, atmosfer, sky, cloud, lighting, dan state salat global.
Lampiran["03_DakwahWorldController"] = {
	OriginalPath = "ServerScriptService.DakwahWorldController",
	ClassName = "Script",
	Role = "Mengatur siklus waktu dunia, atmosfer, sky, cloud, lighting, dan state salat global.",
	Source = [[
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local terrain = Workspace:WaitForChild("Terrain")

local PrayerTimeUtils = require(ReplicatedStorage:WaitForChild("PrayerTimeUtils"))

local jamModel = Workspace:WaitForChild("Systems_And_Scripts"):WaitForChild("JamSolat")
local stateFolder = ReplicatedStorage:WaitForChild("DakwahWorldState")

local LIGHT_CLASSES = {
	PointLight = true,
	SpotLight = true,
	SurfaceLight = true,
}

local PRAYER_ORDER = PrayerTimeUtils.PRAYER_ORDER
local WEEKDAYS = PrayerTimeUtils.WEEKDAYS_TITLE
local MONTHS = PrayerTimeUtils.MONTHS_TITLE

local EFFECT_NAMES = {
	Atmosphere = "DakwahAtmosphere",
	Bloom = "DakwahBloom",
	ColorCorrection = "DakwahColorCorrection",
	SunRays = "DakwahSunRays",
	ManagedSky = "DakwahManagedSky",
	DaySkyTemplate = "Sky",
	NightSkyTemplate = "NIGHT",
}

local controlledLights = {}
local masjidTeleport = Workspace:WaitForChild("Teleporters"):WaitForChild("TeleportMasjid")
local MASJID_LIGHT_RADIUS = 130

local function getLightWorldPosition(light)
	local parent = light.Parent
	if parent and parent:IsA("Attachment") then
		parent = parent.Parent
	end
	if parent and parent:IsA("BasePart") then
		return parent.Position
	end
	return nil
end

local function isNearMasjid(light)
	local lightPosition = getLightWorldPosition(light)
	if not lightPosition then
		return false
	end
	return (lightPosition - masjidTeleport.Position).Magnitude <= MASJID_LIGHT_RADIUS
end
local lastStateKey

local function cleanupGuidePrompts()
	for _, child in ipairs(Workspace:GetChildren()) do
		if child.Name == "JamSolat" then
			PrayerTimeUtils.ensureDefaultAttributes(child)
			local existingGuidePrompt = child:FindFirstChild("DakwahGuidePrompt")
			if existingGuidePrompt then
				existingGuidePrompt:Destroy()
			end
		end
	end
end

PrayerTimeUtils.ensureDefaultAttributes(jamModel)
cleanupGuidePrompts()

local function getLocationName()
	return PrayerTimeUtils.getStringAttribute(jamModel, "LocationName")
end

local function clamp(value, minValue, maxValue)
	return math.max(minValue, math.min(maxValue, value))
end

local function lerpColor(a, b, alpha)
	return Color3.new(
		a.R + (b.R - a.R) * alpha,
		a.G + (b.G - a.G) * alpha,
		a.B + (b.B - a.B) * alpha
	)
end

local function lerpNumber(a, b, alpha)
	return a + (b - a) * alpha
end

local function getLightingKeyframes(schedule)
	local subuh = schedule.SUBUH
	local sunrise = schedule.SUNRISE
	local dzuhur = schedule.DZUHUR
	local ashar = schedule.ASHAR
	local maghrib = schedule.MAGHRIB
	local isya = schedule.ISYA

	return {
		{ time = 0, phase = "Malam", brightness = 1.2, exposure = 0.05, ambient = Color3.fromRGB(45, 55, 75), outdoor = Color3.fromRGB(110, 120, 150), atmosphereDensity = 0.25, atmosphereHaze = 0.8, atmosphereGlare = 0.1, atmosphereColor = Color3.fromRGB(82, 111, 168), atmosphereDecay = Color3.fromRGB(10, 16, 30), tint = Color3.fromRGB(200, 215, 255), contrast = 0.1, saturation = -0.05, bloom = 0.18, sun = 0.02, fogEnd = 1200 },
		{ time = math.max(0, subuh - 35), phase = "Menjelang Subuh", brightness = 1.3, exposure = 0.08, ambient = Color3.fromRGB(55, 65, 85), outdoor = Color3.fromRGB(125, 135, 165), atmosphereDensity = 0.25, atmosphereHaze = 0.8, atmosphereGlare = 0.08, atmosphereColor = Color3.fromRGB(108, 132, 189), atmosphereDecay = Color3.fromRGB(24, 28, 45), tint = Color3.fromRGB(210, 220, 255), contrast = 0.08, saturation = -0.02, bloom = 0.2, sun = 0.03, fogEnd = 1300 },
		{ time = subuh + 20, phase = "Subuh", brightness = 1.55, exposure = 0.03, ambient = Color3.fromRGB(72, 72, 84), outdoor = Color3.fromRGB(132, 128, 128), atmosphereDensity = 0.32, atmosphereHaze = 1.15, atmosphereGlare = 0.1, atmosphereColor = Color3.fromRGB(255, 180, 140), atmosphereDecay = Color3.fromRGB(82, 76, 122), tint = Color3.fromRGB(255, 236, 220), contrast = 0.03, saturation = 0.02, bloom = 0.12, sun = 0.04, fogEnd = 900 },
		{ time = sunrise + 55, phase = "Pagi", brightness = 2.45, exposure = 0.1, ambient = Color3.fromRGB(116, 120, 120), outdoor = Color3.fromRGB(170, 176, 180), atmosphereDensity = 0.24, atmosphereHaze = 0.8, atmosphereGlare = 0.14, atmosphereColor = Color3.fromRGB(199, 217, 255), atmosphereDecay = Color3.fromRGB(121, 147, 189), tint = Color3.fromRGB(255, 248, 235), contrast = 0.05, saturation = 0.07, bloom = 0.08, sun = 0.08, fogEnd = 1200 },
		{ time = dzuhur, phase = "Siang", brightness = 3.1, exposure = 0.15, ambient = Color3.fromRGB(138, 142, 145), outdoor = Color3.fromRGB(194, 200, 204), atmosphereDensity = 0.18, atmosphereHaze = 0.55, atmosphereGlare = 0.22, atmosphereColor = Color3.fromRGB(186, 213, 255), atmosphereDecay = Color3.fromRGB(146, 169, 203), tint = Color3.fromRGB(255, 250, 242), contrast = 0.08, saturation = 0.08, bloom = 0.04, sun = 0.12, fogEnd = 1600 },
		{ time = ashar + 20, phase = "Sore", brightness = 2.55, exposure = 0.08, ambient = Color3.fromRGB(110, 101, 96), outdoor = Color3.fromRGB(172, 148, 128), atmosphereDensity = 0.22, atmosphereHaze = 0.72, atmosphereGlare = 0.16, atmosphereColor = Color3.fromRGB(255, 196, 144), atmosphereDecay = Color3.fromRGB(173, 110, 92), tint = Color3.fromRGB(255, 226, 188), contrast = 0.06, saturation = 0.1, bloom = 0.07, sun = 0.08, fogEnd = 1100 },
		{ time = math.max(ashar + 40, maghrib - 18), phase = "Maghrib", brightness = 1.35, exposure = -0.02, ambient = Color3.fromRGB(78, 64, 78), outdoor = Color3.fromRGB(120, 86, 94), atmosphereDensity = 0.33, atmosphereHaze = 1.2, atmosphereGlare = 0.1, atmosphereColor = Color3.fromRGB(255, 146, 114), atmosphereDecay = Color3.fromRGB(76, 40, 56), tint = Color3.fromRGB(255, 204, 176), contrast = 0.04, saturation = 0.12, bloom = 0.15, sun = 0.04, fogEnd = 900 },
		{ time = isya, phase = "Malam", brightness = 1.25, exposure = 0.06, ambient = Color3.fromRGB(45, 55, 75), outdoor = Color3.fromRGB(110, 120, 150), atmosphereDensity = 0.25, atmosphereHaze = 0.8, atmosphereGlare = 0.1, atmosphereColor = Color3.fromRGB(82, 111, 168), atmosphereDecay = Color3.fromRGB(10, 16, 30), tint = Color3.fromRGB(200, 215, 255), contrast = 0.1, saturation = -0.05, bloom = 0.18, sun = 0.02, fogEnd = 1200 },
		{ time = 1440, phase = "Malam", brightness = 1.2, exposure = 0.05, ambient = Color3.fromRGB(45, 55, 75), outdoor = Color3.fromRGB(110, 120, 150), atmosphereDensity = 0.25, atmosphereHaze = 0.8, atmosphereGlare = 0.1, atmosphereColor = Color3.fromRGB(82, 111, 168), atmosphereDecay = Color3.fromRGB(10, 16, 30), tint = Color3.fromRGB(200, 215, 255), contrast = 0.1, saturation = -0.05, bloom = 0.18, sun = 0.02, fogEnd = 1200 },
	}
end

local function evaluateStyle(schedule, nowMinutes)
	local keyframes = getLightingKeyframes(schedule)
	for index = 1, #keyframes - 1 do
		local current = keyframes[index]
		local nextKeyframe = keyframes[index + 1]
		if nowMinutes >= current.time and nowMinutes <= nextKeyframe.time then
			local span = math.max(1, nextKeyframe.time - current.time)
			local alpha = clamp((nowMinutes - current.time) / span, 0, 1)
			return {
				phase = alpha < 0.5 and current.phase or nextKeyframe.phase,
				brightness = lerpNumber(current.brightness, nextKeyframe.brightness, alpha),
				exposure = lerpNumber(current.exposure, nextKeyframe.exposure, alpha),
				ambient = lerpColor(current.ambient, nextKeyframe.ambient, alpha),
				outdoor = lerpColor(current.outdoor, nextKeyframe.outdoor, alpha),
				atmosphereDensity = lerpNumber(current.atmosphereDensity, nextKeyframe.atmosphereDensity, alpha),
				atmosphereHaze = lerpNumber(current.atmosphereHaze, nextKeyframe.atmosphereHaze, alpha),
				atmosphereGlare = lerpNumber(current.atmosphereGlare, nextKeyframe.atmosphereGlare, alpha),
				atmosphereColor = lerpColor(current.atmosphereColor, nextKeyframe.atmosphereColor, alpha),
				atmosphereDecay = lerpColor(current.atmosphereDecay, nextKeyframe.atmosphereDecay, alpha),
				tint = lerpColor(current.tint, nextKeyframe.tint, alpha),
				contrast = lerpNumber(current.contrast, nextKeyframe.contrast, alpha),
				saturation = lerpNumber(current.saturation, nextKeyframe.saturation, alpha),
				bloom = lerpNumber(current.bloom, nextKeyframe.bloom, alpha),
				sun = lerpNumber(current.sun, nextKeyframe.sun, alpha),
				fogEnd = lerpNumber(current.fogEnd, nextKeyframe.fogEnd, alpha),
			}
		end
	end
	return nil
end

local function createOrGet(className, name)
	local instance = Lighting:FindFirstChild(name)
	if instance and instance.ClassName ~= className then
		instance:Destroy()
		instance = nil
	end
	if not instance then
		instance = Instance.new(className)
		instance.Name = name
		instance.Parent = Lighting
	end
	return instance
end

local function copySkyProperties(sourceSky, targetSky)
	if not sourceSky or not targetSky then
		return
	end

	targetSky.SkyboxBk = sourceSky.SkyboxBk
	targetSky.SkyboxDn = sourceSky.SkyboxDn
	targetSky.SkyboxFt = sourceSky.SkyboxFt
	targetSky.SkyboxLf = sourceSky.SkyboxLf
	targetSky.SkyboxRt = sourceSky.SkyboxRt
	targetSky.SkyboxUp = sourceSky.SkyboxUp
	targetSky.SunTextureId = sourceSky.SunTextureId
	targetSky.MoonTextureId = sourceSky.MoonTextureId
	targetSky.StarCount = sourceSky.StarCount
	targetSky.CelestialBodiesShown = sourceSky.CelestialBodiesShown
end

local atmosphere = createOrGet("Atmosphere", EFFECT_NAMES.Atmosphere)
local bloom = createOrGet("BloomEffect", EFFECT_NAMES.Bloom)
local depthOfField = createOrGet("DepthOfFieldEffect", "DakwahDepthOfField")
local colorCorrection = createOrGet("ColorCorrectionEffect", EFFECT_NAMES.ColorCorrection)
local sunRays = createOrGet("SunRaysEffect", EFFECT_NAMES.SunRays)
local managedSky = createOrGet("Sky", EFFECT_NAMES.ManagedSky)
local daySkyTemplate = Lighting:FindFirstChild(EFFECT_NAMES.DaySkyTemplate)
local nightSkyTemplate = Lighting:FindFirstChild(EFFECT_NAMES.NightSkyTemplate)

if daySkyTemplate == managedSky then
	daySkyTemplate = nil
end
if nightSkyTemplate == managedSky then
	nightSkyTemplate = nil
end
if daySkyTemplate then
	daySkyTemplate.Parent = nil
end
if nightSkyTemplate then
	nightSkyTemplate.Parent = nil
end
if daySkyTemplate and managedSky then
	copySkyProperties(daySkyTemplate, managedSky)
end

local clouds = terrain:FindFirstChild("DakwahClouds")
if clouds and not clouds:IsA("Clouds") then
	clouds:Destroy()
	clouds = nil
end
if not clouds then
	clouds = Instance.new("Clouds")
	clouds.Name = "DakwahClouds"
	clouds.Parent = terrain
end

local function shouldControlLight(descendant)
	if not LIGHT_CLASSES[descendant.ClassName] then
		return false
	end
	if descendant:IsDescendantOf(jamModel) then
		return false
	end
	local parentPath = descendant:GetFullName()
	if string.find(parentPath, "IndoorUnit") then
		return false
	end

	local managedRoot = Workspace:FindFirstChild("ZZ_PenyesuaianWorkspace") or Workspace
	if descendant:IsDescendantOf(managedRoot) then
		return true
	end

	return isNearMasjid(descendant)
end

local function refreshControlledLights()
	controlledLights = {}
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if shouldControlLight(descendant) then
			if descendant:GetAttribute("BaseBrightness") == nil then
				descendant:SetAttribute("BaseBrightness", descendant.Brightness)
				descendant:SetAttribute("BaseRange", descendant.Range)
				descendant:SetAttribute("BaseColor", descendant.Color)
			end
			
			table.insert(controlledLights, {
				instance = descendant,
				baseBrightness = descendant:GetAttribute("BaseBrightness"),
				baseRange = descendant:GetAttribute("BaseRange"),
				baseColor = descendant:GetAttribute("BaseColor"),
				nearMasjid = isNearMasjid(descendant),
			})
		end
	end
end
local function applyLightState(style, schedule, nowMinutes)
	local sunriseGate = PrayerTimeUtils.normalizeMinutes(schedule.SUNRISE + 20)
	local maghribGate = PrayerTimeUtils.normalizeMinutes(schedule.MAGHRIB - 12)
	local nightWeight
	if nowMinutes >= maghribGate or nowMinutes <= sunriseGate then
		nightWeight = 1
	elseif nowMinutes < schedule.DZUHUR then
		nightWeight = clamp(1 - ((nowMinutes - sunriseGate) / math.max(1, schedule.DZUHUR - sunriseGate)), 0, 1) * 0.1
	else
		nightWeight = clamp((nowMinutes - (schedule.ASHAR + 10)) / math.max(1, maghribGate - (schedule.ASHAR + 10)), 0, 1)
	end

	for _, item in ipairs(controlledLights) do
		local light = item.instance
		if light.Parent then
			local brightnessScale = lerpNumber(0.08, 1.25, nightWeight)
			local rangeScale = lerpNumber(0.75, 1.05, nightWeight)
			light.Enabled = nightWeight > 0.12
			light.Brightness = item.baseBrightness * brightnessScale
			light.Range = item.baseRange * rangeScale
			light.Color = lerpColor(Color3.fromRGB(255, 244, 220), item.baseColor, 0.65)
		end
	end
end

refreshControlledLights()

Workspace.DescendantAdded:Connect(function(descendant)
	if shouldControlLight(descendant) then
		task.defer(refreshControlledLights)
	end
end)
Workspace.DescendantRemoving:Connect(function(descendant)
	if LIGHT_CLASSES[descendant.ClassName] then
		task.defer(refreshControlledLights)
	end
end)

local function updateWorldState()
	PrayerTimeUtils.ensureDefaultAttributes(jamModel)
	local dateTable, localUnix = PrayerTimeUtils.getLocalDateTable(jamModel)
	local schedule = PrayerTimeUtils.computePrayerSchedule(table.clone(dateTable), jamModel, { includeSunrise = true })
	if not schedule then
		return nil
	end

	local nowMinutes = dateTable.hour * 60 + dateTable.min + dateTable.sec / 60
	local currentPrayer, nextPrayer = PrayerTimeUtils.getCurrentPrayerAndNext(schedule, nowMinutes, PRAYER_ORDER)
	local nextPrayerClock = schedule[nextPrayer]
	local style = evaluateStyle(schedule, nowMinutes)
	if not style then
		return nil
	end
	pcall(function()
		local cloudCover = clamp(0.16 + style.atmosphereDensity * 0.55, 0.16, 0.42)
		local cloudDensity = clamp(0.55 + style.atmosphereHaze * 0.12, 0.55, 0.9)
		local focusIntensity = clamp(0.02 + style.atmosphereDensity * 0.08, 0.02, 0.08)
		local useNightSky = nowMinutes >= schedule.MAGHRIB or nowMinutes < schedule.SUNRISE
		local targetSky = useNightSky and nightSkyTemplate or daySkyTemplate

		Lighting.ClockTime = nowMinutes / 60
		Lighting.GlobalShadows = true
		Lighting.ShadowSoftness = 0.24
		Lighting.Brightness = 1.1
		Lighting.ExposureCompensation = -0.22
		Lighting.Ambient = Color3.fromRGB(82, 86, 96)
		Lighting.OutdoorAmbient = Color3.fromRGB(102, 106, 118)
		Lighting.FogColor = Color3.fromRGB(160, 170, 188)
		Lighting.FogStart = 0
		Lighting.FogEnd = 2000
		Lighting.ColorShift_Top = Color3.fromRGB(245, 245, 245)
		Lighting.ColorShift_Bottom = Color3.fromRGB(235, 238, 242)
		Lighting.EnvironmentDiffuseScale = 0.72
		Lighting.EnvironmentSpecularScale = 0.3

		if targetSky and managedSky then
			copySkyProperties(targetSky, managedSky)
		end

		atmosphere.Density = 0.18
		atmosphere.Offset = 0.05
		atmosphere.Color = Color3.fromRGB(176, 188, 210)
		atmosphere.Decay = Color3.fromRGB(92, 104, 128)
		atmosphere.Glare = 0.02
		atmosphere.Haze = 0.65

		bloom.Intensity = 0.03
		bloom.Size = 8
		bloom.Threshold = 3

		colorCorrection.TintColor = Color3.fromRGB(245, 245, 245)
		colorCorrection.Brightness = -0.03
		colorCorrection.Contrast = 0.02
		colorCorrection.Saturation = -0.08

		sunRays.Intensity = 0.01
		sunRays.Spread = 0.55
		depthOfField.FarIntensity = 0.02
		depthOfField.NearIntensity = 0.01
		depthOfField.InFocusRadius = 100
		depthOfField.FocusDistance = 48

		if clouds then
			clouds.Cover = 0.22
			clouds.Density = 0.68
			clouds.Color = Color3.fromRGB(198, 204, 214)
		end

		applyLightState(style, schedule, nowMinutes)
	end)

	local weekdayName = WEEKDAYS[dateTable.wday] or WEEKDAYS[1]
	local monthName = MONTHS[dateTable.month] or MONTHS[1]
	local payload = {
		LocationName = getLocationName(),
		DateLabel = string.format("%s, %02d %s %04d", weekdayName, dateTable.day, monthName, dateTable.year),
		PhaseName = style.phase,
		CurrentPrayer = currentPrayer,
		NextPrayer = nextPrayer,
		NextPrayerClock = PrayerTimeUtils.minutesToClock(nextPrayerClock),
		CountdownText = PrayerTimeUtils.formatCountdown(PrayerTimeUtils.minutesUntil(nowMinutes, nextPrayerClock)),
		LocalTimeText = string.format("%02d:%02d:%02d", dateTable.hour, dateTable.min, dateTable.sec),
		LocalUnix = math.floor(localUnix),
		Schedule = schedule,
	}

	local stateKey = table.concat({ payload.DateLabel, payload.PhaseName, payload.CurrentPrayer, payload.NextPrayer, payload.LocalTimeText }, "|")
	if stateKey ~= lastStateKey then
		lastStateKey = stateKey
		for key, value in pairs(payload) do
			if key ~= "Schedule" then
				stateFolder:SetAttribute(key, value)
			end
		end
	end

	return payload
end

task.spawn(function()
	while true do
		updateWorldState()
		task.wait(1)
	end
end)
]],
}

-- 04. 04_PrayerNotificationServer
-- OriginalPath: ServerScriptService.PrayerNotificationServer
-- Role: Mengirim notifikasi server untuk pengingat dan masuknya waktu salat.
Lampiran["04_PrayerNotificationServer"] = {
	OriginalPath = "ServerScriptService.PrayerNotificationServer",
	ClassName = "Script",
	Role = "Mengirim notifikasi server untuk pengingat dan masuknya waktu salat.",
	Source = [[
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
]],
}

-- 05. 05_PrayerNotificationClient
-- OriginalPath: StarterPlayer.StarterPlayerScripts.PrayerNotificationClient
-- Role: Menampilkan notifikasi waktu salat di sisi client/player.
Lampiran["05_PrayerNotificationClient"] = {
	OriginalPath = "StarterPlayer.StarterPlayerScripts.PrayerNotificationClient",
	ClassName = "LocalScript",
	Role = "Menampilkan notifikasi waktu salat di sisi client/player.",
	Source = [[
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
]],
}

-- 06. 06_DakwahCompanionBootstrap
-- OriginalPath: StarterGui.DakwahCompanionBootstrap
-- Role: Membuat panel UI jadwal salat/topbar companion di client.
Lampiran["06_DakwahCompanionBootstrap"] = {
	OriginalPath = "StarterGui.DakwahCompanionBootstrap",
	ClassName = "LocalScript",
	Role = "Membuat panel UI jadwal salat/topbar companion di client.",
	Source = [[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local PrayerTimeUtils = require(ReplicatedStorage:WaitForChild("PrayerTimeUtils"))
local jamModel = Workspace:WaitForChild("Systems_And_Scripts"):WaitForChild("JamSolat")

local roroomsScript = Workspace:WaitForChild("Indoor_Units"):WaitForChild("Rorooms"):WaitForChild("Rorooms")
local Fusion = require(roroomsScript.Packages.Fusion)
local OnyxUI = require(roroomsScript.Packages.OnyxUI)
local States = require(roroomsScript.Packages.Rorooms.SourceCode.Client.UI.States)
local TopbarState = require(roroomsScript.Packages.Rorooms.SourceCode.Client.UI.States.Topbar)
local Assets = require(roroomsScript.Packages.Rorooms.SourceCode.Shared.Assets)
local Components = require(roroomsScript.Packages.Rorooms.SourceCode.Client.UI.Components)

local MENU_NAME = "SolatPanel"

local Children = Fusion.Children
local Themer = OnyxUI.Themer
local Theme = Themer.Theme:now()
local Scope = Fusion.scoped(Fusion, OnyxUI.Util, OnyxUI.Components, Components)

local PRAYER_ORDER = PrayerTimeUtils.PRAYER_ORDER
local PRAYER_LABELS = {
	SUBUH = "Subuh",
	DZUHUR = "Dzuhur",
	ASHAR = "Ashar",
	MAGHRIB = "Maghrib",
	ISYA = "Isya",
}

local ACTIVE_ACCENT = Color3.fromRGB(59, 130, 246)
local ACTIVE_ROW_COLOR = Color3.fromRGB(59, 130, 246)
local ACTIVE_ROW_TEXT = Color3.fromRGB(244, 255, 248)

local currentTimeText = Scope:Value("00:00")
local currentDateText = Scope:Value("Memuat tanggal...")
local locationText = Scope:Value("Memuat lokasi...")
local timezoneText = Scope:Value("WIB")
local currentPrayerKey = Scope:Value(nil)
local currentPrayerText = Scope:Value("Belum ada jadwal aktif")
local nextPrayerName = Scope:Value("...")
local nextPrayerTime = Scope:Value("--:--")
local countdownText = Scope:Value("--:--")
local prayerSchedules = Scope:Value({})

local function getPrayerLabel(key)
	if not key then
		return "--"
	end
	return PRAYER_LABELS[key] or key
end

local function getTimezoneLabel(offset)
	if offset >= 9 then
		return "WIT"
	end
	if offset >= 8 then
		return "WITA"
	end
	return "WIB"
end

local function updateDisplay()
	PrayerTimeUtils.ensureDefaultAttributes(jamModel)

	local dateTable = PrayerTimeUtils.getLocalDateTable(jamModel)
	local schedule = PrayerTimeUtils.computePrayerSchedule(table.clone(dateTable), jamModel)
	if not schedule then
		return
	end

	local nowMinutes = dateTable.hour * 60 + dateTable.min + dateTable.sec / 60
	local currentPrayer, nextPrayer = PrayerTimeUtils.getCurrentPrayerAndNext(schedule, nowMinutes)
	local weekday = PrayerTimeUtils.WEEKDAYS_TITLE[dateTable.wday] or ""
	local month = PrayerTimeUtils.MONTHS_TITLE[dateTable.month] or ""
	local timezoneOffset = PrayerTimeUtils.getNumberAttribute(jamModel, "TimeZoneOffset")
	local locationName = PrayerTimeUtils.getStringAttribute(jamModel, "LocationName")

	currentTimeText:set(PrayerTimeUtils.minutesToClock(nowMinutes, true))
	currentDateText:set(string.format("%s, %02d %s %04d", weekday, dateTable.day, month, dateTable.year))
	locationText:set(locationName)
	timezoneText:set(getTimezoneLabel(timezoneOffset))
	currentPrayerKey:set(currentPrayer)
	currentPrayerText:set("Sedang berlangsung: " .. getPrayerLabel(currentPrayer))
	nextPrayerName:set(getPrayerLabel(nextPrayer))
	nextPrayerTime:set(PrayerTimeUtils.minutesToClock(schedule[nextPrayer]))
	countdownText:set(PrayerTimeUtils.formatCountdown(PrayerTimeUtils.minutesUntil(nowMinutes, schedule[nextPrayer])))

	local updatedSchedules = {}
	for _, prayerKey in ipairs(PRAYER_ORDER) do
		updatedSchedules[prayerKey] = PrayerTimeUtils.minutesToClock(schedule[prayerKey])
	end
	prayerSchedules:set(updatedSchedules)
end

local MenuOpen = Scope:Computed(function(Use)
	return Use(States.Menus.CurrentMenu) == MENU_NAME
end)

local MenuSize = Scope:Computed(function(Use)
	local screenSize = Use(States.CoreGui.ScreenSize)
	local width = screenSize and screenSize.X or 1280
	local height = screenSize and screenSize.Y or 720
	local menuWidth = width < 500 and 226 or 270
	local menuHeight = math.clamp(height - 140, 300, 360)
	return UDim2.fromOffset(menuWidth, menuHeight)
end)

local HeaderTextSize = Scope:Computed(function(Use)
	local screenSize = Use(States.CoreGui.ScreenSize)
	local width = screenSize and screenSize.X or 1280
	return width < 500 and 22 or 24
end)

local BodyTextSize = Scope:Computed(function(Use)
	local screenSize = Use(States.CoreGui.ScreenSize)
	local width = screenSize and screenSize.X or 1280
	return width < 500 and 11 or 12
end)

local SmallTextSize = Scope:Computed(function(Use)
	local screenSize = Use(States.CoreGui.ScreenSize)
	local width = screenSize and screenSize.X or 1280
	return width < 500 and 10 or 11
end)

local SectionGap = Scope:Computed(function(Use)
	local screenSize = Use(States.CoreGui.ScreenSize)
	local width = screenSize and screenSize.X or 1280
	return UDim.new(0, width < 500 and 6 or 8)
end)

local SectionPadding = Scope:Computed(function(Use)
	local screenSize = Use(States.CoreGui.ScreenSize)
	local width = screenSize and screenSize.X or 1280
	return UDim.new(0, width < 500 and 8 or 10)
end)

local CornerRadius = Scope:Computed(function(Use)
	local screenSize = Use(States.CoreGui.ScreenSize)
	local width = screenSize and screenSize.X or 1280
	return UDim.new(0, width < 500 and 10 or 12)
end)

local RowHeight = Scope:Computed(function(Use)
	local screenSize = Use(States.CoreGui.ScreenSize)
	local width = screenSize and screenSize.X or 1280
	return width < 500 and 26 or 28
end)

Scope:Menu {
	Name = MENU_NAME,
	Open = MenuOpen,
	Parent = playerGui,
	Size = MenuSize,
	ListHorizontalFlex = Enum.UIFlexAlignment.Fill,
	Padding = UDim.new(0, 8),
	ListPadding = SectionGap,

	[Children] = {
		Scope:Frame {
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundColor3 = Theme.Colors.Base.Main,
			BackgroundTransparency = 0.05,
			CornerRadius = CornerRadius,
			Padding = SectionPadding,
			ListEnabled = true,
			ListHorizontalFlex = Enum.UIFlexAlignment.Fill,
			ListPadding = UDim.new(0, 4),

			[Children] = {
				Scope:Frame {
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundTransparency = 1,
					[Children] = {
						Scope:Text {
							Text = locationText,
							Size = UDim2.new(0.72, 0, 1, 0),
							TextSize = SmallTextSize,
							TextColor3 = Theme.Colors.NeutralContent.Dark,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
							FontFace = Scope:Computed(function(Use)
								return Font.new(Use(Theme.Font.Body), Use(Theme.FontWeight.Bold))
							end),
						},
						Scope:Text {
							Text = timezoneText,
							Size = UDim2.new(0.28, 0, 1, 0),
							Position = UDim2.fromScale(0.72, 0),
							TextSize = SmallTextSize,
							TextColor3 = Theme.Colors.NeutralContent.Dark,
							TextXAlignment = Enum.TextXAlignment.Right,
						},
					},
				},
				Scope:Text {
					Text = currentTimeText,
					Size = UDim2.new(1, 0, 0, 28),
					TextSize = HeaderTextSize,
					TextColor3 = ACTIVE_ACCENT,
					TextXAlignment = Enum.TextXAlignment.Left,
					FontFace = Scope:Computed(function(Use)
						return Font.new(Use(Theme.Font.Heading), Use(Theme.FontWeight.Heading))
					end),
				},
				Scope:Text {
					Text = currentDateText,
					Size = UDim2.new(1, 0, 0, 14),
					TextSize = BodyTextSize,
					TextColor3 = Theme.Colors.NeutralContent.Dark,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				},
				Scope:Text {
					Text = currentPrayerText,
					Size = UDim2.new(1, 0, 0, 14),
					TextSize = SmallTextSize,
					TextColor3 = ACTIVE_ACCENT,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					FontFace = Scope:Computed(function(Use)
						return Font.new(Use(Theme.Font.Body), Use(Theme.FontWeight.Bold))
					end),
				},
			},
		},

		Scope:Frame {
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundColor3 = Theme.Colors.Neutral.Main,
			BackgroundTransparency = 0.08,
			CornerRadius = CornerRadius,
			Padding = SectionPadding,
			ListEnabled = true,
			ListHorizontalFlex = Enum.UIFlexAlignment.Fill,
			ListPadding = UDim.new(0, 4),

			[Children] = {
				Scope:Text {
					Text = "Salat berikutnya",
					Size = UDim2.new(1, 0, 0, 14),
					TextSize = SmallTextSize,
					TextColor3 = Theme.Colors.NeutralContent.Dark,
					TextXAlignment = Enum.TextXAlignment.Left,
				},
				Scope:Frame {
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundTransparency = 1,
					[Children] = {
						Scope:Text {
							Text = nextPrayerName,
							Size = UDim2.new(0.62, 0, 1, 0),
							TextSize = BodyTextSize,
							TextXAlignment = Enum.TextXAlignment.Left,
							FontFace = Scope:Computed(function(Use)
								return Font.new(Use(Theme.Font.Heading), Use(Theme.FontWeight.Heading))
							end),
						},
						Scope:Text {
							Text = nextPrayerTime,
							Size = UDim2.new(0.38, 0, 1, 0),
							Position = UDim2.fromScale(0.62, 0),
							TextSize = BodyTextSize,
							TextColor3 = ACTIVE_ACCENT,
							TextXAlignment = Enum.TextXAlignment.Right,
							FontFace = Scope:Computed(function(Use)
								return Font.new(Use(Theme.Font.Heading), Use(Theme.FontWeight.Heading))
							end),
						},
					},
				},
				Scope:Text {
					Text = Scope:Computed(function(Use)
						return "Mulai dalam " .. Use(countdownText)
					end),
					Size = UDim2.new(1, 0, 0, 14),
					TextSize = SmallTextSize,
					TextColor3 = Theme.Colors.NeutralContent.Dark,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				},
			},
		},

		Scope:Frame {
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundColor3 = Theme.Colors.Base.Main,
			BackgroundTransparency = 0.05,
			CornerRadius = CornerRadius,
			Padding = SectionPadding,
			ListEnabled = true,
			ListHorizontalFlex = Enum.UIFlexAlignment.Fill,
			ListPadding = UDim.new(0, 4),

			[Children] = {
				Scope:Text {
					Text = "Jadwal hari ini",
					Size = UDim2.new(1, 0, 0, 14),
					TextSize = SmallTextSize,
					TextColor3 = Theme.Colors.NeutralContent.Dark,
					TextXAlignment = Enum.TextXAlignment.Left,
				},
				Scope:ForValues(PRAYER_ORDER, function(Use, InnerScope, prayerKey)
					local isCurrentPrayer = InnerScope:Computed(function(innerUse)
						return innerUse(currentPrayerKey) == prayerKey
					end)

					return InnerScope:Frame {
						Size = InnerScope:Computed(function(innerUse)
							return UDim2.new(1, 0, 0, innerUse(RowHeight))
						end),
						BackgroundColor3 = InnerScope:Computed(function(innerUse)
							return innerUse(isCurrentPrayer) and ACTIVE_ROW_COLOR or innerUse(Theme.Colors.Neutral.Main)
						end),
						BackgroundTransparency = InnerScope:Computed(function(innerUse)
							return innerUse(isCurrentPrayer) and 0.08 or 0.45
						end),
						CornerRadius = UDim.new(0, 8),
						Padding = UDim.new(0, 8),
						[Children] = {
							InnerScope:Text {
								Text = getPrayerLabel(prayerKey),
								Size = UDim2.new(0.62, 0, 1, 0),
								TextSize = BodyTextSize,
								TextColor3 = InnerScope:Computed(function(innerUse)
									return innerUse(isCurrentPrayer) and ACTIVE_ROW_TEXT or innerUse(Theme.Colors.BaseContent.Main)
								end),
								TextXAlignment = Enum.TextXAlignment.Left,
								FontFace = InnerScope:Computed(function(innerUse)
									if innerUse(isCurrentPrayer) then
										return Font.new(innerUse(Theme.Font.Body), innerUse(Theme.FontWeight.Bold))
									end
									return Font.new(innerUse(Theme.Font.Body))
								end),
							},
							InnerScope:Text {
								Text = InnerScope:Computed(function(innerUse)
									return innerUse(prayerSchedules)[prayerKey] or "--:--"
								end),
								Size = UDim2.new(0.38, 0, 1, 0),
								Position = UDim2.fromScale(0.62, 0),
								TextSize = BodyTextSize,
								TextColor3 = InnerScope:Computed(function(innerUse)
									return innerUse(isCurrentPrayer) and ACTIVE_ROW_TEXT or innerUse(Theme.Colors.NeutralContent.Dark)
								end),
								TextXAlignment = Enum.TextXAlignment.Right,
								FontFace = InnerScope:Computed(function(innerUse)
									if innerUse(isCurrentPrayer) then
										return Font.new(innerUse(Theme.Font.Body), innerUse(Theme.FontWeight.Bold))
									end
									return Font.new(innerUse(Theme.Font.Body))
								end),
							},
						},
					}
				end),
			},
		},
	},
}

TopbarState:AddTopbarButton("Solat", {
	MenuName = MENU_NAME,
	Icon = Assets.Icons.General.Star,
	IconFilled = Assets.Icons.General.Star,
	LayoutOrder = 10,
	HoverColor = ACTIVE_ACCENT,
	Callback = function() end,
})

task.spawn(function()
	while true do
		updateDisplay()
		task.wait(1)
	end
end)
]],
}

-- 07. 07_PrayerEmoteGui_Controller
-- OriginalPath: StarterGui.PrayerEmoteGui.Controller
-- Role: Membuat panel emote salat/doa/duduk dan teleport cepat ke area masjid/sirkuit.
Lampiran["07_PrayerEmoteGui_Controller"] = {
	OriginalPath = "StarterGui.PrayerEmoteGui.Controller",
	ClassName = "LocalScript",
	Role = "Membuat panel emote salat/doa/duduk dan teleport cepat ke area masjid/sirkuit.",
	Source = [[
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local roroomsScript = Workspace:WaitForChild("Indoor_Units"):WaitForChild("Rorooms"):WaitForChild("Rorooms")
local Fusion      = require(roroomsScript.Packages.Fusion)
local OnyxUI      = require(roroomsScript.Packages.OnyxUI)
local States      = require(roroomsScript.Packages.Rorooms.SourceCode.Client.UI.States)
local TopbarState = require(roroomsScript.Packages.Rorooms.SourceCode.Client.UI.States.Topbar)
local Assets      = require(roroomsScript.Packages.Rorooms.SourceCode.Shared.Assets)
local Components  = require(roroomsScript.Packages.Rorooms.SourceCode.Client.UI.Components)

local MENU_NAME   = "EmotePanel"
local TP_MENU_NAME = "TeleportPanel"

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Children = Fusion.Children
local Themer = OnyxUI.Themer
local Peek = Fusion.peek

local Scope = Fusion.scoped(Fusion, OnyxUI.Util, OnyxUI.Components, Components)
local Theme = Themer.Theme:now()

local EMOTES = {
	pray = { label = "Sholat", emoji = "🕌", animationId = "rbxassetid://93009184159377" },
	dua  = { label = "Berdoa", emoji = "🤲", animationId = "rbxassetid://103139921501496" },
	sit  = { label = "Duduk",  emoji = "🧘", animationId = "rbxassetid://80554731110555", hipHeightOffset = -1.1, lockRotate = true },
}
local EMOTE_ORDER = { "pray", "dua", "sit" }

local activeTrack, activeAnimation
local activeHumanoid, originalHipHeight, originalAutoRotate
local activeEmoteKey = Scope:Value(nil)

local function clearHumanoidAdjustments()
	if activeHumanoid then
		if originalHipHeight ~= nil then activeHumanoid.HipHeight = originalHipHeight end
		if originalAutoRotate ~= nil then activeHumanoid.AutoRotate = originalAutoRotate end
	end
	activeHumanoid = nil; originalHipHeight = nil; originalAutoRotate = nil
end

local function destroyPlayback(track, animation)
	if track then track:Destroy() end
	if animation then animation:Destroy() end
end

local function stopTrack()
	local track, animation = activeTrack, activeAnimation
	activeTrack = nil; activeAnimation = nil; activeEmoteKey:set(nil)
	if track then track:Stop(0.2) end
	clearHumanoidAdjustments(); destroyPlayback(track, animation)
end

local function getAnimator()
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then return animator, humanoid end
	return Instance.new("Animator", humanoid), humanoid
end

local function toggleEmote(emoteKey)
	local emote = EMOTES[emoteKey]; if not emote then return end
	local animator, humanoid = getAnimator()
	if not animator or not humanoid or humanoid.Health <= 0 then return end
	
	if Peek(activeEmoteKey) == emoteKey and activeTrack and activeTrack.IsPlaying then 
		stopTrack()
		return 
	end
	
	stopTrack()
	local animation = Instance.new("Animation")
	animation.AnimationId = emote.animationId
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action; track.Looped = true
	
	track.Stopped:Connect(function()
		if activeTrack == track then 
			activeTrack = nil
			activeAnimation = nil
			activeEmoteKey:set(nil) 
		end
		clearHumanoidAdjustments(); destroyPlayback(track, animation)
	end)
	
	activeTrack = track; activeAnimation = animation; activeEmoteKey:set(emoteKey)
	clearHumanoidAdjustments(); activeHumanoid = humanoid
	originalHipHeight = humanoid.HipHeight; originalAutoRotate = humanoid.AutoRotate
	
	if emote.hipHeightOffset then
		humanoid.HipHeight = math.max(0, humanoid.HipHeight + emote.hipHeightOffset)
	end
	if emote.lockRotate ~= nil then
		humanoid.AutoRotate = not emote.lockRotate and originalAutoRotate or false
	end
	
	track:Play(0.15)
end

player.CharacterRemoving:Connect(stopTrack)

local function findTeleportTarget(targetName)
	local teleportFolder = Workspace:FindFirstChild("Teleporters")
	if teleportFolder then
		local target = teleportFolder:FindFirstChild(targetName)
		if target and target:IsA("BasePart") then
			return target
		end
	end

	local fallback = Workspace:FindFirstChild(targetName, true)
	if fallback and fallback:IsA("BasePart") then
		return fallback
	end

	return nil
end

local function teleportToTarget(targetName)
	local character = player.Character or player.CharacterAdded:Wait()
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local target = findTeleportTarget(targetName)
	if not target then
		warn(string.format("[PrayerEmoteGui] Target teleport '%s' tidak ditemukan", targetName))
		return
	end

	character:PivotTo(target.CFrame * CFrame.new(0, 3, 0))
	States.Menus.CurrentMenu:set(nil)
end

-- ==========================================
-- NATIVE MENUS USING FUSION
-- ==========================================

-- 1. Emote Menu
local EmoteMenuOpen = Scope:Computed(function(Use)
	return Use(States.Menus.CurrentMenu) == MENU_NAME
end)

Scope:Menu {
	Name = MENU_NAME,
	Open = EmoteMenuOpen,
	Parent = playerGui,
	Size = Scope:Computed(function(Use)
		local screenSize = Use(States.CoreGui.ScreenSize)
		if screenSize.X > 0 and screenSize.X < 500 then
			return UDim2.fromOffset(230, 0)
		end
		return UDim2.fromOffset(260, 0)
	end),
	ListHorizontalFlex = Enum.UIFlexAlignment.Fill,

	[Children] = {
		Scope:Text {
			Text = Scope:Computed(function(Use)
				local currentEmote = Use(activeEmoteKey)
				if currentEmote and EMOTES[currentEmote] then
					return "Aktif: " .. EMOTES[currentEmote].label
				else
					return "Pilih gerakan untuk memulai"
				end
			end),
			TextSize = Scope:Computed(function(Use) return Use(Theme.TextSize["0.875"]) end),
			TextColor3 = Theme.Colors.NeutralContent.Dark,
			TextXAlignment = Enum.TextXAlignment.Left,
		},
		Scope:Divider {},
		Scope:ForValues(EMOTE_ORDER, function(Use, Scope, key)
			local emote = EMOTES[key]
			local isActive = Scope:Computed(function(Use) return Use(activeEmoteKey) == key end)
			return Scope:Button {
				Name = key,
				Content = { emote.emoji .. "   " .. emote.label },
				Color = Scope:Computed(function(Use)
					return Use(isActive) and Use(Theme.Colors.Primary.Main) or Use(Theme.Colors.Base.Main)
				end),
				OnActivated = function()
					toggleEmote(key)
				end,
			}
		end),
	},
}

-- 2. Teleport Menu
local TpMenuOpen = Scope:Computed(function(Use)
	return Use(States.Menus.CurrentMenu) == TP_MENU_NAME
end)

Scope:Menu {
	Name = TP_MENU_NAME,
	Open = TpMenuOpen,
	Parent = playerGui,
	Size = Scope:Computed(function(Use)
		local screenSize = Use(States.CoreGui.ScreenSize)
		if screenSize.X > 0 and screenSize.X < 500 then
			return UDim2.fromOffset(230, 0)
		end
		return UDim2.fromOffset(260, 0)
	end),
	ListHorizontalFlex = Enum.UIFlexAlignment.Fill,

	[Children] = {
		Scope:Text {
			Text = "Pindah area dengan cepat",
			TextSize = Scope:Computed(function(Use) return Use(Theme.TextSize["0.875"]) end),
			TextColor3 = Theme.Colors.NeutralContent.Dark,
			TextXAlignment = Enum.TextXAlignment.Left,
		},
		Scope:Divider {},
		Scope:Button {
			Content = { "🕌", "Area Masjid" },
			OnActivated = function()
				teleportToTarget("TeleportMasjid")
			end,
		},
		Scope:Button {
			Content = { "🏁", "Area Sirkuit" },
			OnActivated = function()
				teleportToTarget("TeleportSirkuit")
			end,
		},
	},
}

-- ==========================================
-- REGISTER TOPBAR BUTTONS
-- ==========================================

TopbarState:AddTopbarButton("Emote", {
	MenuName    = MENU_NAME,
	Icon        = Assets.Icons.Topbar.Emotes.Outlined,
	IconFilled  = Assets.Icons.Topbar.Emotes.Filled,
	LayoutOrder = 11,
	Callback    = function() end,
})

-- Teleport = Worlds/Pin icon (The reliable one from "tadi")
TopbarState:AddTopbarButton("Teleport", {
	MenuName    = TP_MENU_NAME,
	Icon        = Assets.Icons.Topbar.Worlds.Outlined,
	IconFilled  = Assets.Icons.Topbar.Worlds.Filled,
	LayoutOrder = 12,
	Callback    = function() end,
})

]],
}

-- 08. 08_PrayEmoteService
-- OriginalPath: ServerScriptService.PrayEmoteService
-- Role: Server handler untuk menjalankan/menonaktifkan animasi salat.
Lampiran["08_PrayEmoteService"] = {
	OriginalPath = "ServerScriptService.PrayEmoteService",
	ClassName = "Script",
	Role = "Server handler untuk menjalankan/menonaktifkan animasi salat.",
	Source = [[
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:WaitForChild("PlayPrayEmoteEvent")
local PRAY_ANIMATION_ID = "rbxassetid://93009184159377"
local activeTracks = {}

local function stopTrack(player)
	local track = activeTracks[player]
	if track then
		activeTracks[player] = nil
		track:Stop(0.2)
		track:Destroy()
	end
end

local function getAnimator(player)
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		return animator
	end
	return Instance.new("Animator", humanoid)
end

remote.OnServerEvent:Connect(function(player)
	local animator = getAnimator(player)
	if not animator then
		return
	end

	local currentTrack = activeTracks[player]
	if currentTrack and currentTrack.IsPlaying then
		stopTrack(player)
		return
	end

	stopTrack(player)

	local animation = Instance.new("Animation")
	animation.AnimationId = PRAY_ANIMATION_ID

	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track.Stopped:Connect(function()
		if activeTracks[player] == track then
			activeTracks[player] = nil
		end
		animation:Destroy()
		track:Destroy()
	end)

	activeTracks[player] = track
	track:Play(0.15)
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	stopTrack(player)
end)
]],
}

-- 09. 09_PlayerPointsService
-- OriginalPath: ServerScriptService.PlayerPointsService
-- Role: DataStore poin player, reward berkala, leaderstats, dan API penyesuaian poin.
Lampiran["09_PlayerPointsService"] = {
	OriginalPath = "ServerScriptService.PlayerPointsService",
	ClassName = "Script",
	Role = "DataStore poin player, reward berkala, leaderstats, dan API penyesuaian poin.",
	Source = [[
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

]],
}

-- 10. 10_PointsNotifyClient
-- OriginalPath: StarterPlayer.StarterPlayerScripts.PointsNotifyClient
-- Role: Menampilkan notifikasi perubahan poin di client.
Lampiran["10_PointsNotifyClient"] = {
	OriginalPath = "StarterPlayer.StarterPlayerScripts.PointsNotifyClient",
	ClassName = "LocalScript",
	Role = "Menampilkan notifikasi perubahan poin di client.",
	Source = [[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local notifyEvent = ReplicatedStorage:WaitForChild("KutbahPointsNotify")

local function showNotification(title, text)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = 4,
		})
	end)
end

notifyEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	showNotification(payload.title or "Poin", payload.text or "")
end)

]],
}

-- 11. 11_KutbahMicrophoneServer
-- OriginalPath: ServerScriptService.KutbahMicrophoneServer
-- Role: Sistem mikrofon/toa kutbah, biaya poin, audio routing, status UI, dan auto-off jarak mimbar.
Lampiran["11_KutbahMicrophoneServer"] = {
	OriginalPath = "ServerScriptService.KutbahMicrophoneServer",
	ClassName = "Script",
	Role = "Sistem mikrofon/toa kutbah, biaya poin, audio routing, status UI, dan auto-off jarak mimbar.",
	Source = [[
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
]],
}

-- 12. 12_VoiceDistanceController
-- OriginalPath: ServerScriptService.VoiceDistanceController
-- Role: Mengatur kurva jarak voice chat normal, voice di mikrofon, dan speaker masjid.
Lampiran["12_VoiceDistanceController"] = {
	OriginalPath = "ServerScriptService.VoiceDistanceController",
	ClassName = "Script",
	Role = "Mengatur kurva jarak voice chat normal, voice di mikrofon, dan speaker masjid.",
	Source = [[
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local microphoneModel = Workspace:WaitForChild("Misc_Models"):WaitForChild("Kutbah"):WaitForChild("Microphone")

local ATTR_ENABLED = "MicEnabled"
local ATTR_ACTIVE_USER_ID = "MicActiveUserId"

local NORMAL_VOICE_CURVE = {
	[0] = 1,
	[8] = 1,
	[14] = 0.9,
	[20] = 0.45,
	[28] = 0.1,
	[36] = 0,
}

local MIC_SPEAKER_CURVE = {
	[0] = 0,
	[3] = 0,
	[6] = 0.06,
	[10] = 0.12,
	[16] = 0.2,
	[24] = 0.28,
	[36] = 0,
}

local MOSQUE_SPEAKER_CURVE = {
	[0] = 1,
	[40] = 1,
	[120] = 1,
	[260] = 0.92,
	[480] = 0.72,
	[760] = 0.4,
	[1100] = 0.14,
	[1450] = 0,
}

local function applyEmitterCurve(emitter, curve)
	if not emitter:IsA("AudioEmitter") then
		return
	end
	pcall(function()
		emitter:SetDistanceAttenuation(curve)
		emitter:SetAngleAttenuation({
			[0] = 1,
			[180] = 1,
		})
	end)
end

local function getPlayerCurve(player)
	if microphoneModel:GetAttribute(ATTR_ENABLED) == true
		and (microphoneModel:GetAttribute(ATTR_ACTIVE_USER_ID) or 0) == player.UserId
	then
		return MIC_SPEAKER_CURVE
	end
	return NORMAL_VOICE_CURVE
end

local function refreshCharacterEmitters(player, character)
	local curve = getPlayerCurve(player)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("AudioEmitter") and descendant.Name ~= "KutbahVoiceEmitter" then
			applyEmitterCurve(descendant, curve)
		end
	end
end

local function watchCharacter(player, character)
	refreshCharacterEmitters(player, character)
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("AudioEmitter") and descendant.Name ~= "KutbahVoiceEmitter" then
			applyEmitterCurve(descendant, getPlayerCurve(player))
		end
	end)
end

local function refreshAllPlayerEmitters()
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			refreshCharacterEmitters(player, player.Character)
		end
	end
end

local function watchPlayer(player)
	if player.Character then
		watchCharacter(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
end

for _, descendant in ipairs(microphoneModel:GetDescendants()) do
	if descendant:IsA("AudioEmitter") and descendant.Name == "KutbahVoiceEmitter" then
		applyEmitterCurve(descendant, MOSQUE_SPEAKER_CURVE)
	end
end

microphoneModel.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("AudioEmitter") and descendant.Name == "KutbahVoiceEmitter" then
		applyEmitterCurve(descendant, MOSQUE_SPEAKER_CURVE)
	end
end)

microphoneModel:GetAttributeChangedSignal(ATTR_ENABLED):Connect(refreshAllPlayerEmitters)
microphoneModel:GetAttributeChangedSignal(ATTR_ACTIVE_USER_ID):Connect(refreshAllPlayerEmitters)

for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end

Players.PlayerAdded:Connect(watchPlayer)

refreshAllPlayerEmitters()
]],
}

-- 13. 13_SpeakerMusicServer
-- OriginalPath: ServerScriptService.SpeakerMusicServer
-- Role: Server pemutar musik, pilihan track, jarak audio, validasi jarak interaksi, dan state playback.
Lampiran["13_SpeakerMusicServer"] = {
	OriginalPath = "ServerScriptService.SpeakerMusicServer",
	ClassName = "Script",
	Role = "Server pemutar musik, pilihan track, jarak audio, validasi jarak interaksi, dan state playback.",
	Source = [[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local speaker = Workspace:WaitForChild("Systems_And_Scripts"):WaitForChild("Pemutar Musik")
local musicOrigin = speaker:WaitForChild("MusicOrigin")
local prompt = musicOrigin:WaitForChild("SpeakerPrompt")
local remote = ReplicatedStorage:WaitForChild("SpeakerMusicRemote")
local audioFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Audio")

local DEFAULT_MIN_DISTANCE = 12
local DEFAULT_MAX_DISTANCE = 75
local MIN_LIMIT = 1
local MAX_LIMIT = 500
local MAX_CONTROL_DISTANCE = math.max(10, prompt.MaxActivationDistance)
local ACTION_COOLDOWN = 0.2

local activeSound
local currentTrackName
local currentMinDistance = DEFAULT_MIN_DISTANCE
local currentMaxDistance = DEFAULT_MAX_DISTANCE
local lastActionAtByUserId = {}

local function getSongNames()
	local names = {}
	for _, child in ipairs(audioFolder:GetChildren()) do
		if child:IsA("Sound") then
			table.insert(names, child.Name)
		end
	end
	table.sort(names)
	return names
end

local function getState()
	return {
		trackName = currentTrackName,
		minDistance = currentMinDistance,
		maxDistance = currentMaxDistance,
	}
end

local function sendState(player)
	remote:FireClient(player, "state", getState())
end

local function broadcastState()
	for _, player in ipairs(Players:GetPlayers()) do
		sendState(player)
	end
end

local function applyDistances(sound)
	if not sound then
		return
	end
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = currentMinDistance
	sound.RollOffMaxDistance = currentMaxDistance
	sound.EmitterSize = math.max(4, math.floor(currentMinDistance / 2))
end

local function normalizeDistances(minDistance, maxDistance)
	if typeof(minDistance) ~= "number" or typeof(maxDistance) ~= "number" then
		return nil
	end

	minDistance = math.clamp(math.floor(minDistance + 0.5), MIN_LIMIT, MAX_LIMIT - 1)
	maxDistance = math.clamp(math.floor(maxDistance + 0.5), minDistance + 1, MAX_LIMIT)
	return minDistance, maxDistance
end

local function updateDistances(minDistance, maxDistance)
	local nextMin, nextMax = normalizeDistances(minDistance, maxDistance)
	if not nextMin then
		return false
	end

	currentMinDistance = nextMin
	currentMaxDistance = nextMax
	applyDistances(activeSound)
	broadcastState()
	return true
end

local function stopPlayback()
	if activeSound then
		activeSound:Stop()
		activeSound:Destroy()
		activeSound = nil
	end
	currentTrackName = nil
	broadcastState()
end

local function playTrack(trackName)
	local template = audioFolder:FindFirstChild(trackName)
	if not template or not template:IsA("Sound") then
		return false
	end

	if activeSound then
		activeSound:Stop()
		activeSound:Destroy()
		activeSound = nil
	end

	activeSound = template:Clone()
	activeSound.Name = "ActiveSpeakerSound"
	activeSound.Looped = true
	if activeSound.Volume <= 0 then
		activeSound.Volume = 1
	end
	applyDistances(activeSound)
	activeSound.Parent = musicOrigin
	activeSound:Play()

	currentTrackName = template.Name
	broadcastState()
	return true
end

local function isPlayerNearSpeaker(player)
	local character = player.Character
	if not character then
		return false
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return false
	end
	return (rootPart.Position - musicOrigin.Position).Magnitude <= MAX_CONTROL_DISTANCE + 1
end

local function canRunAction(player)
	local now = os.clock()
	local lastActionAt = lastActionAtByUserId[player.UserId] or 0
	if now - lastActionAt < ACTION_COOLDOWN then
		return false
	end
	lastActionAtByUserId[player.UserId] = now
	return true
end

prompt.Triggered:Connect(function(player)
	remote:FireClient(player, "open", {
		speaker = "Pemutar Musik",
		songs = getSongNames(),
		state = getState(),
	})
end)

remote.OnServerEvent:Connect(function(player, action, payload)
	if typeof(action) ~= "string" then
		return
	end

	if action == "requestState" then
		sendState(player)
		return
	end

	if not canRunAction(player) or not isPlayerNearSpeaker(player) then
		return
	end

	if action == "play" then
		if typeof(payload) ~= "string" then
			return
		end
		playTrack(payload)
	elseif action == "stop" then
		stopPlayback()
	elseif action == "setDistances" then
		if typeof(payload) ~= "table" then
			return
		end
		updateDistances(payload.minDistance, payload.maxDistance)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastActionAtByUserId[player.UserId] = nil
	if #Players:GetPlayers() <= 1 and activeSound then
		stopPlayback()
	end
end)

for _, child in ipairs(musicOrigin:GetChildren()) do
	if child:IsA("Sound") and child.Name ~= "ActiveSpeakerSound" then
		child:Destroy()
	end
end
]],
}

-- 14. 14_SpeakerMusicGui_Controller
-- OriginalPath: StarterGui.SpeakerMusicGui.Controller
-- Role: GUI client untuk memilih lagu, menghentikan musik, dan mengatur jangkauan speaker.
Lampiran["14_SpeakerMusicGui_Controller"] = {
	OriginalPath = "StarterGui.SpeakerMusicGui.Controller",
	ClassName = "LocalScript",
	Role = "GUI client untuk memilih lagu, menghentikan musik, dan mengatur jangkauan speaker.",
	Source = [[
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
]],
}

-- 15. 15_WearablesServer
-- OriginalPath: ServerScriptService.WearablesServer
-- Role: Interaksi wearable sarung/hijab, pemasangan accessory, dan prompt toggle di map.
Lampiran["15_WearablesServer"] = {
	OriginalPath = "ServerScriptService.WearablesServer",
	ClassName = "Script",
	Role = "Interaksi wearable sarung/hijab, pemasangan accessory, dan prompt toggle di map.",
	Source = [[
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local TEMPLATE_FOLDER_NAME = "WearableAssets"
local ACTION_COOLDOWN = 0.35

local missingTemplateWarnings = {}
local lastToggleAtByUserId = {}

local function getTemplateFolder()
	local templateFolder = ServerStorage:FindFirstChild(TEMPLATE_FOLDER_NAME)
	if templateFolder and templateFolder:IsA("Folder") then
		return templateFolder
	end

	if not missingTemplateWarnings[TEMPLATE_FOLDER_NAME] then
		missingTemplateWarnings[TEMPLATE_FOLDER_NAME] = true
		warn("Wearable folder missing:", TEMPLATE_FOLDER_NAME)
	end

	return nil
end

local function getTemplate(templateName)
	local templateFolder = getTemplateFolder()
	if not templateFolder then
		return nil
	end

	local template = templateFolder:FindFirstChild(templateName)
	if template and template:IsA("Accessory") then
		return template
	end

	if not missingTemplateWarnings[templateName] then
		missingTemplateWarnings[templateName] = true
		warn("Wearable template missing:", templateName)
	end

	return nil
end

local function canToggleWearable(player)
	local userId = player and player.UserId
	if not userId or userId <= 0 then
		return false
	end

	local now = os.clock()
	local lastToggleAt = lastToggleAtByUserId[userId]
	if lastToggleAt and now - lastToggleAt < ACTION_COOLDOWN then
		return false
	end

	lastToggleAtByUserId[userId] = now
	return true
end
local function getCharacterAndHumanoid(player)
	local character = player.Character
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return character, humanoid
end

local function findEquipped(character, accessoryName)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") and child.Name == accessoryName then
			return child
		end
	end

	return nil
end

local function accessoryHasBinding(accessory)
	local handle = accessory and accessory:FindFirstChild("Handle")
	if not handle then
		return false
	end

	for _, descendant in ipairs(handle:GetDescendants()) do
		if descendant:IsA("Weld") or descendant:IsA("WeldConstraint") or descendant:IsA("Motor6D") then
			return true
		end
	end

	return false
end

local function prepareHandle(handle)
	handle.Anchored = false
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
end

local function findAttachmentInCharacter(character, attachmentName)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Attachment") and descendant.Name == attachmentName then
			local parent = descendant.Parent
			if parent and parent:IsA("BasePart") then
				return descendant, parent
			end
		end
	end

	return nil, nil
end

local function removeFallbackBinding(handle)
	for _, child in ipairs(handle:GetChildren()) do
		if child:IsA("Weld") or child:IsA("WeldConstraint") then
			child:Destroy()
		end
	end
end

local function attachWithCFrames(handle, accessoryAttachment, attachedPart, targetCFrame)
	removeFallbackBinding(handle)
	handle.CFrame = attachedPart.CFrame * targetCFrame * accessoryAttachment.CFrame:Inverse()

	local weld = Instance.new("Weld")
	weld.Name = "AccessoryWeld"
	weld.Part0 = handle
	weld.Part1 = attachedPart
	weld.C0 = accessoryAttachment.CFrame
	weld.C1 = targetCFrame
	weld.Parent = handle
	return true
end

local function attachByMatchingAttachment(character, accessory)
	local handle = accessory:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return false
	end

	for _, child in ipairs(handle:GetChildren()) do
		if child:IsA("Attachment") then
			local characterAttachment, attachedPart = findAttachmentInCharacter(character, child.Name)
			if characterAttachment and attachedPart then
				return attachWithCFrames(handle, child, attachedPart, characterAttachment.CFrame)
			end
		end
	end

	return false
end

local function attachByPartFallback(character, accessory, attachmentName, partName, targetCFrame)
	local handle = accessory:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return false
	end

	local accessoryAttachment = handle:FindFirstChild(attachmentName)
	local attachedPart = character:FindFirstChild(partName)
	if not accessoryAttachment or not accessoryAttachment:IsA("Attachment") then
		return false
	end
	if not attachedPart or not attachedPart:IsA("BasePart") then
		return false
	end

	return attachWithCFrames(handle, accessoryAttachment, attachedPart, targetCFrame)
end

local function buildAccessory(templateName, accessoryName)
	local template = getTemplate(templateName)
	if not template then
		return nil
	end

	local accessory = template:Clone()
	accessory.Name = accessoryName

	for _, descendant in ipairs(accessory:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ProximityPrompt") or descendant:IsA("TouchTransmitter") then
			descendant:Destroy()
		end
	end

	local handle = accessory:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		prepareHandle(handle)
	end

	return accessory
end

local HEAD_ACCESSORY_ATTACHMENT_NAMES = {
	HatAttachment = true,
	HairAttachment = true,
	FaceFrontAttachment = true,
	FaceCenterAttachment = true,
	NeckAttachment = true,
}

local HIJAB_HIDDEN_ATTRIBUTE = "HijabHiddenAccessory"
local ORIGINAL_TRANSPARENCY_ATTRIBUTE = "HijabOriginalTransparency"
local ORIGINAL_ENABLED_ATTRIBUTE = "HijabOriginalEnabled"

local function setAccessoryVisualState(accessory, isVisible)
	for _, descendant in ipairs(accessory:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if isVisible then
				local originalTransparency = descendant:GetAttribute(ORIGINAL_TRANSPARENCY_ATTRIBUTE)
				if originalTransparency ~= nil then
					descendant.Transparency = originalTransparency
					descendant:SetAttribute(ORIGINAL_TRANSPARENCY_ATTRIBUTE, nil)
				end
			else
				if descendant:GetAttribute(ORIGINAL_TRANSPARENCY_ATTRIBUTE) == nil then
					descendant:SetAttribute(ORIGINAL_TRANSPARENCY_ATTRIBUTE, descendant.Transparency)
				end
				descendant.Transparency = 1
			end
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			if isVisible then
				local originalTransparency = descendant:GetAttribute(ORIGINAL_TRANSPARENCY_ATTRIBUTE)
				if originalTransparency ~= nil then
					descendant.Transparency = originalTransparency
					descendant:SetAttribute(ORIGINAL_TRANSPARENCY_ATTRIBUTE, nil)
				end
			else
				if descendant:GetAttribute(ORIGINAL_TRANSPARENCY_ATTRIBUTE) == nil then
					descendant:SetAttribute(ORIGINAL_TRANSPARENCY_ATTRIBUTE, descendant.Transparency)
				end
				descendant.Transparency = 1
			end
		elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") then
			if isVisible then
				local originalEnabled = descendant:GetAttribute(ORIGINAL_ENABLED_ATTRIBUTE)
				if originalEnabled ~= nil then
					descendant.Enabled = originalEnabled
					descendant:SetAttribute(ORIGINAL_ENABLED_ATTRIBUTE, nil)
				end
			else
				if descendant:GetAttribute(ORIGINAL_ENABLED_ATTRIBUTE) == nil then
					descendant:SetAttribute(ORIGINAL_ENABLED_ATTRIBUTE, descendant.Enabled)
				end
				descendant.Enabled = false
			end
		end
	end
end

local function isHeadAccessory(accessory)
	if not accessory:IsA("Accessory") or accessory.Name == "HijabAccessory" then
		return false
	end

	local handle = accessory:FindFirstChild("Handle")
	if not handle then
		return false
	end

	for _, descendant in ipairs(handle:GetDescendants()) do
		if descendant:IsA("Attachment") and HEAD_ACCESSORY_ATTACHMENT_NAMES[descendant.Name] then
			return true
		end
	end

	return false
end

local function setHijabHeadAccessoriesHidden(character, isHidden)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") and isHeadAccessory(child) then
			setAccessoryVisualState(child, not isHidden)
			child:SetAttribute(HIJAB_HIDDEN_ATTRIBUTE, isHidden or nil)
		elseif child:IsA("Accessory") and not isHidden and child:GetAttribute(HIJAB_HIDDEN_ATTRIBUTE) then
			setAccessoryVisualState(child, true)
			child:SetAttribute(HIJAB_HIDDEN_ATTRIBUTE, nil)
		end
	end
end

local WEARABLE_MODELS = {
	Sarong = {
		accessoryName = "SarongAccessory",
		templateName = "SarongTemplate",
		promptAction = "Toggle Sarung",
		getDisplayPart = function(sourceModel)
			local handle = sourceModel:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				return handle
			end
			return sourceModel:FindFirstChildWhichIsA("BasePart", true)
		end,
		fallbackAttach = function(character, accessory)
			if attachByMatchingAttachment(character, accessory) then
				return true
			end

			return attachByPartFallback(character, accessory, "WaistCenterAttachment", "LowerTorso", CFrame.new())
				or attachByPartFallback(character, accessory, "WaistCenterAttachment", "Torso", CFrame.new())
		end,
	},
	Hijab = {
		accessoryName = "HijabAccessory",
		templateName = "HijabTemplate",
		promptAction = "Toggle Hijab",
		getDisplayPart = function(sourceModel)
			return sourceModel:FindFirstChildWhichIsA("BasePart", true)
		end,
		fallbackAttach = function(character, accessory)
			if attachByMatchingAttachment(character, accessory) then
				return true
			end

			return attachByPartFallback(character, accessory, "HatAttachment", "Head", CFrame.new(0, 0.5, 0))
		end,
	},
}

local function finishEquip(character, accessory, config)
	for _ = 1, 10 do
		if accessoryHasBinding(accessory) then
			return
		end
		task.wait()
	end

	if accessory.Parent == character and not config.fallbackAttach(character, accessory) then
		warn("Failed to attach wearable:", accessory.Name)
	end
end

local function toggleWearable(player, wearableType)
	local config = WEARABLE_MODELS[wearableType]
	if not config or not canToggleWearable(player) then
		return
	end

	local character, humanoid = getCharacterAndHumanoid(player)
	if not character or not humanoid then
		return
	end

	local existing = findEquipped(character, config.accessoryName)
	if existing then
		if wearableType == "Hijab" then
			setHijabHeadAccessoriesHidden(character, false)
		end

		existing:Destroy()
		return
	end

	if wearableType == "Hijab" then
		setHijabHeadAccessoriesHidden(character, true)
	end

	local accessory = buildAccessory(config.templateName, config.accessoryName)
	if not accessory then
		if wearableType == "Hijab" then
			setHijabHeadAccessoriesHidden(character, false)
		end
		return
	end

	humanoid:AddAccessory(accessory)
	task.defer(finishEquip, character, accessory, config)
end

local function configurePrompt(basePart, wearableType)
	local config = WEARABLE_MODELS[wearableType]
	if not config then
		return
	end

	local prompt = basePart:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = basePart
	end

	prompt.ActionText = config.promptAction
	prompt.ObjectText = wearableType
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false

	if prompt:GetAttribute("WearablePromptBound") then
		return
	end

	prompt:SetAttribute("WearablePromptBound", true)
	prompt.Triggered:Connect(function(player)
		toggleWearable(player, wearableType)
	end)
end

local function tryConfigureWearableModel(instance)
	if not instance:IsA("Model") then
		return
	end

	local config = WEARABLE_MODELS[instance.Name]
	if not config then
		return
	end

	local basePart = config.getDisplayPart(instance)
	if basePart then
		configurePrompt(basePart, instance.Name)
	end
end

for _, descendant in ipairs(Workspace:GetDescendants()) do
	tryConfigureWearableModel(descendant)
end

Workspace.DescendantAdded:Connect(function(instance)
	tryConfigureWearableModel(instance)

	local wearableModel = instance:FindFirstAncestorWhichIsA("Model")
	if wearableModel then
		tryConfigureWearableModel(wearableModel)
	end
end)

]],
}

-- 16. 16_GoKartAccessService
-- OriginalPath: ServerScriptService.GoKartAccessService
-- Role: Pengelolaan go-kart, reset/respawn otomatis, marker reset, dan countdown BillboardGui.
Lampiran["16_GoKartAccessService"] = {
	OriginalPath = "ServerScriptService.GoKartAccessService",
	ClassName = "Script",
	Role = "Pengelolaan go-kart, reset/respawn otomatis, marker reset, dan countdown BillboardGui.",
	Source = [[
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

]],
}

-- 17. 17_LeaderboardPlaytimeSyncService
-- OriginalPath: ServerScriptService.LeaderboardPlaytimeSyncService
-- Role: Sinkronisasi menit bermain antara profile Rorooms dan OrderedDataStore leaderboard.
Lampiran["17_LeaderboardPlaytimeSyncService"] = {
	OriginalPath = "ServerScriptService.LeaderboardPlaytimeSyncService",
	ClassName = "Script",
	Role = "Sinkronisasi menit bermain antara profile Rorooms dan OrderedDataStore leaderboard.",
	Source = [[
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local leaderboardModel = Workspace:WaitForChild("Systems_And_Scripts"):WaitForChild("TimePlayedLeaderboard")
local config = require(leaderboardModel:WaitForChild("Settings"))

local roroomsScript = Workspace:WaitForChild("Indoor_Units"):WaitForChild("Rorooms"):WaitForChild("Rorooms")
local PlayerDataStoreService = require(
	roroomsScript.Packages.Rorooms.SourceCode.Server.PlayerDataStore.PlayerDataStoreService
)

local ATTRIBUTE_NAME = "LeaderboardPlaytimeMinutes"
local playtimeStore = DataStoreService:GetOrderedDataStore(config.DATA_STORE)

local function getStatKey(userId)
	return string.format("%s%d", config.NAME_OF_STAT, userId)
end

local function normalizeMinutes(value)
	return math.max(0, math.floor(tonumber(value) or 0))
end

local function setPlayerPlaytime(player, minutes)
	player:SetAttribute(ATTRIBUTE_NAME, normalizeMinutes(minutes))
end

local function getLegacyPlaytimeMinutes(userId)
	local ok, result = pcall(function()
		return playtimeStore:GetAsync(getStatKey(userId))
	end)

	if ok and type(result) == "number" then
		return normalizeMinutes(result)
	end

	if not ok then
		warn("Gagal memuat playtime leaderboard:", userId, result)
	end

	return nil
end

local function syncPlayerPlaytime(player)
	if not player.Parent then
		return
	end

	local profile = PlayerDataStoreService:GetProfile(player.UserId)
	local profileMinutes = profile and normalizeMinutes(profile.Data.MinutesSpent) or nil
	local legacyMinutes = getLegacyPlaytimeMinutes(player.UserId)
	local currentMinutes = normalizeMinutes(player:GetAttribute(ATTRIBUTE_NAME))

	local bestMinutes = math.max(currentMinutes, profileMinutes or 0, legacyMinutes or 0)
	setPlayerPlaytime(player, bestMinutes)

	if profile and bestMinutes > normalizeMinutes(profile.Data.MinutesSpent) then
		PlayerDataStoreService:UpdateData(player, function(data)
			data.MinutesSpent = bestMinutes
			return data
		end)
	end
end

PlayerDataStoreService.ProfileLoaded:Connect(function(profile)
	if profile.Player then
		task.spawn(syncPlayerPlaytime, profile.Player)
	end
end)

PlayerDataStoreService.DataUpdated:Connect(function(player, oldData, newData)
	if oldData.MinutesSpent ~= newData.MinutesSpent then
		setPlayerPlaytime(player, newData.MinutesSpent)
	end
end)

Players.PlayerAdded:Connect(function(player)
	local currentMinutes = player:GetAttribute(ATTRIBUTE_NAME)
	if currentMinutes ~= nil then
		setPlayerPlaytime(player, currentMinutes)
	end
	task.spawn(syncPlayerPlaytime, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(syncPlayerPlaytime, player)
end
]],
}

-- 18. 18_PlayerTimeService
-- OriginalPath: ServerScriptService.PlayerTimeApi.PlayerTimeService
-- Role: API penyesuaian waktu bermain dan update leaderboard time-played.
Lampiran["18_PlayerTimeService"] = {
	OriginalPath = "ServerScriptService.PlayerTimeApi.PlayerTimeService",
	ClassName = "Script",
	Role = "API penyesuaian waktu bermain dan update leaderboard time-played.",
	Source = [[
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local roroomsScript = Workspace:WaitForChild("Indoor_Units"):WaitForChild("Rorooms"):WaitForChild("Rorooms")
local PlayerDataStoreService = require(
	roroomsScript.Packages.Rorooms.SourceCode.Server.PlayerDataStore.PlayerDataStoreService
)

local leaderboardModel = Workspace:WaitForChild("Systems_And_Scripts"):WaitForChild("TimePlayedLeaderboard")
local leaderboardConfig = require(leaderboardModel:WaitForChild("Settings"))
local playtimeStore = DataStoreService:GetOrderedDataStore(leaderboardConfig.DATA_STORE)

local adjustTimeFn = script.Parent:WaitForChild("AdjustTime")

adjustTimeFn.OnInvoke = function(playerOrUserId, delta)
	local userId = if typeof(playerOrUserId) == "Instance" and playerOrUserId:IsA("Player") then playerOrUserId.UserId else tonumber(playerOrUserId)
	local player = if typeof(playerOrUserId) == "Instance" and playerOrUserId:IsA("Player") then playerOrUserId else Players:GetPlayerByUserId(userId)
	
	if not userId then return false, 0, "Invalid player/userId" end
	if not delta or typeof(delta) ~= "number" then return false, 0, "Invalid delta" end
	
	-- 1. Update Rorooms Data
	local profile = PlayerDataStoreService:GetProfile(userId)
	if profile and player then
		PlayerDataStoreService:UpdateData(player, function(data)
			data.MinutesSpent = math.max(0, data.MinutesSpent + delta)
			return data
		end)
	end
	
	-- 2. Update Leaderboard DataStore (TopTimePlayed)
	local statKey = leaderboardConfig.NAME_OF_STAT .. userId
	local success, newMinutes = pcall(function()
		return playtimeStore:IncrementAsync(statKey, delta)
	end)
	
	if success then
		return true, newMinutes
	else
		return false, 0, "Failed to update leaderboard datastore: " .. tostring(newMinutes)
	end
end

]],
}

-- 19. 19_MosqueLightManager
-- OriginalPath: ServerScriptService.MosqueLightManager
-- Role: Mengatur intensitas lampu masjid/chandelier berdasarkan ClockTime.
Lampiran["19_MosqueLightManager"] = {
	OriginalPath = "ServerScriptService.MosqueLightManager",
	ClassName = "Script",
	Role = "Mengatur intensitas lampu masjid/chandelier berdasarkan ClockTime.",
	Source = [[
local Lighting = game:GetService("Lighting")

local function getLights()
    local lights = {}
    local buildingsDir = workspace:FindFirstChild("ZZ_PenyesuaianWorkspace")
    if buildingsDir then
        buildingsDir = buildingsDir:FindFirstChild("Buildings")
    end
    
    if buildingsDir then
        for _, desc in ipairs(buildingsDir:GetDescendants()) do
            if desc:IsA("Light") then
                local p = desc:GetFullName():lower()
                if p:find("pala lampu") or p:find("chandelier") then
                    table.insert(lights, desc)
                end
            end
        end
    end
    return lights
end

local mosqueLights = getLights()

-- Fungsi untuk mendapatkan tingkat kecerahan berdasarkan waktu
local function getTargetValues(clockTime)
    -- Antara jam 6 pagi (06:00) sampai 6 sore (18:00)
    if clockTime >= 6 and clockTime <= 18 then
        -- Siang hari: Lampu lebih terang (mengimbangi cahaya matahari)
        local progress = (clockTime - 6) / 12 
        local multiplier = math.sin(progress * math.pi)
        
        -- Brightness: 0.8 di pagi/sore, 3.5 di puncak siang
        return 0.8 + (2.7 * multiplier)
    else
        -- Malam hari: Lampu diredupkan agar tidak membuat malam terlalu terang (0.8)
        return 0.8
    end
end

local function updateLights()
    if #mosqueLights == 0 then
        mosqueLights = getLights()
    end
    
    local targetBrightness = getTargetValues(Lighting.ClockTime)
    
    for _, light in ipairs(mosqueLights) do
        light.Enabled = true
        
        -- Chandelier dibuat sedikit lebih terang dari lampu biasa
        if light:GetFullName():lower():find("chandelier") then
            light.Brightness = targetBrightness * 1.5
        else
            light.Brightness = targetBrightness
        end
    end
end

Lighting:GetPropertyChangedSignal("ClockTime"):Connect(updateLights)

task.spawn(function()
    while task.wait(5) do
        mosqueLights = getLights()
        updateLights()
    end
end)

updateLights()

]],
}

return Lampiran