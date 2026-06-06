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