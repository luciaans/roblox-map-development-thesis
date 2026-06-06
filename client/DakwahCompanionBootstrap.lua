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