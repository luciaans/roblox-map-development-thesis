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