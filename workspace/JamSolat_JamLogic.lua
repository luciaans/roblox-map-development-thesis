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
