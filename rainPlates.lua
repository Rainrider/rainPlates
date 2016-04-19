local barTexture = [=[Interface\AddOns\rainPlates\media\normtexc]=]
local iconTexture = [=[Interface\AddOns\rainPlates\media\buttonnormal]=]
local glowTexture = [=[Interface\AddOns\rainPlates\media\glowTex]=]
local highlightTexture = [=[Interface\AddOns\rainPlates\media\highlighttex]=]
local font, fontSize, fontOutline = rainDB and rainDB.npfont or GameFontNormal:GetFont(), 8, nil
local raidIcons = [=[Interface\AddOns\rainPlates\media\raidicons]=]

local healthbarHeight = 5;
local castbarHeight = 5;
local playerLevel = UnitLevel("player")

local _G = _G
local floor = _G.math.floor
local select = _G.select
local tonumber = _G.tonumber
local find = _G.string.find
local gsub = _G.string.gsub
local strlenutf8 = _G.strlenutf8

local eventFrame = CreateFrame("Frame")

SetCVar("bloattest", 0) -- 1 might make nameplates larger but it fixes the disappearing ones.
SetCVar("bloatnameplates", 0) -- 1 makes nameplates larger depending on threat percentage.
SetCVar("bloatthreat", 0)

local UpdateThreat = function(plate, elapsed)
	plate.elapsed = plate.elapsed + elapsed
	if plate.elapsed >= 0.5 then
		if not plate.oldglow:IsShown() then
			plate.healthbar.glow:SetVertexColor(0, 0, 0)
		else
			local r, g, b = plate.oldglow:GetVertexColor()
			plate.healthbar.glow:SetVertexColor(r, g, b, 1)
		end

		plate.elapsed = 0
	end
end

local UpdatePlate = function(plate)
	local healthbar = plate.healthbar
	healthbar:ClearAllPoints()
	healthbar:SetPoint("CENTER", healthbar:GetParent())
	healthbar:SetHeight(healthbarHeight)

	local r, g, b = healthbar:GetStatusBarColor()
	healthbar.background:SetVertexColor(r * 0.33, g * 0.33, b * 0.33, 0.75)

	local name = plate.name:GetText()
	name = (strlenutf8(name) > 20) and gsub(name, "(%S[\128-\191]*)%S+%s", "%1. ") or name
	plate.name:SetText(name)

	local levelText = plate.level
	local level, elite = tonumber(levelText:GetText()), plate.elite:IsShown()
	if elite then
		plate.elite:Hide()
	end
	levelText:ClearAllPoints()
	levelText:SetPoint("RIGHT", healthbar, "LEFT", -2, 0)
	if plate.boss:IsShown() then
		levelText:SetText("??")
		levelText:SetTextColor(0.8, 0.05, 0)
		levelText:Show()
	elseif not elite and level == playerLevel then
		levelText:Hide()
	else
		levelText:SetText(level..(elite and "+" or ""))
	end

	local highlight = plate.highlight
	highlight:SetParent(plate)
	highlight:ClearAllPoints()
	highlight:SetAllPoints(healthbar)
end

local ColorCastbar = function(castbar)
	if castbar.shield:IsShown() then
		castbar:SetStatusBarColor(0.8, 0.05, 0)
	end
end

local FixCastbarSize = function(castbar, _, height)
	if floor(height + 0.1) ~= castbarHeight then
		local healthbar = castbar.hp
		castbar:ClearAllPoints()
		castbar:SetPoint("TOPLEFT", healthbar, "BOTTOMLEFT", 0, -4)
		castbar:SetPoint("TOPRIGHT", healthbar, "BOTTOMRIGHT", 0, -4)
		castbar:SetHeight(castbarHeight)
	end
end

local castbarValues = {}
local UpdateCastTime = function(castbar, value)
	local plate = castbar.frameName
	local _, maxValue = castbar:GetMinMaxValues()
	local oldValue = castbarValues[plate]
	if (oldValue) then
		if (value < oldValue) then -- castbar is depleting -> unit is channeling a spell
			castbar.time:SetFormattedText("%d ", value)
		else
			castbar.time:SetFormattedText("%d ", maxValue - value)
		end
	end
	castbarValues[plate] = value
end

local CreatePlate = function(plate, frameName)
	local barFrame, nameFrame = plate:GetChildren()

	local healthbar, absorbbar, castbar = barFrame:GetChildren()

	local glow, healthbarOverlay, highlight, level, bossIcon, raidIcon, eliteIcon = barFrame:GetRegions()
	local _, castbarOverlay, shieldIcon, spellIcon, spellName, spellNameBackground = castbar:GetRegions()
	local name = nameFrame:GetRegions()

	name:ClearAllPoints()
	name:SetPoint("BOTTOM", healthbar, "TOP", 0, 2)
	name:SetFont(font, fontSize, fontOutline)
	name:SetShadowOffset(1.25, -1.25)
	plate.name = name

	level:SetFont(font, fontSize, fontOutline)
	level:SetShadowOffset(1.25, -1.25)
	plate.level = level

	spellName:ClearAllPoints()
	spellName:SetPoint("TOP", castbar, "BOTTOM", 0, -2)
	spellName:SetFont(font, fontSize, fontOutline)
	spellName:SetShadowOffset(1.25, -1.25)

	healthbar:SetStatusBarTexture(barTexture)

	local hbBackground = healthbar:CreateTexture(nil, "BACKGROUND")
	hbBackground:SetAllPoints()
	hbBackground:SetTexture(barTexture)
	healthbar.background = hbBackground

	local hbGlow = healthbar:CreateTexture(nil, "BACKGROUND")
	hbGlow:SetTexture(glowTexture)
	hbGlow:SetPoint("TOPLEFT", -1.5, 1.5)
	hbGlow:SetPoint("BOTTOMRIGHT", 1.5, -1.5)
	hbGlow:SetVertexColor(0, 0, 0)
	healthbar.glow = hbGlow

	highlight:SetTexture(highlightTexture)
	plate.highlight = highlight

	castbar:SetStatusBarTexture(barTexture)
	castbar:ClearAllPoints()
	castbar:SetPoint("TOPLEFT", healthbar, "BOTTOMLEFT", 0, -4)
	castbar:SetPoint("TOPRIGHT", healthbar, "BOTTOMRIGHT", 0, -4)
	castbar:SetHeight(castbarHeight)

	castbar:HookScript("OnShow", ColorCastbar)
	castbar:HookScript("OnSizeChanged", FixCastbarSize)
	castbar:HookScript("OnValueChanged", UpdateCastTime)

	castbar.shield = shieldIcon
	castbar.frameName = frameName

	local cbBackground = castbar:CreateTexture(nil, "BACKGROUND")
	cbBackground:SetAllPoints()
	cbBackground:SetTexture(barTexture)
	cbBackground:SetVertexColor(0.25, 0.25, 0.25, 0.75)

	local cbGlow = castbar:CreateTexture(nil, "BACKGROUND")
	cbGlow:SetTexture(glowTexture)
	cbGlow:SetPoint("TOPLEFT", -1.5, 1.5)
	cbGlow:SetPoint("BOTTOMRIGHT", 1.5, -1.5)
	cbGlow:SetVertexColor(0, 0, 0)
	castbar.glow = cbGlow

	local castTime = castbar:CreateFontString()
	castTime:SetPoint("RIGHT", castbar, "LEFT", -2, 0)
	castTime:SetFont(font, fontSize, fontOutline)
	castTime:SetTextColor(0.84, 0.75, 0.65)
	castTime:SetShadowOffset(1.25, -1.25)
	castbar.time = castTime

	spellIcon:ClearAllPoints()
	spellIcon:SetPoint("LEFT", castbar, 8, 0)
	spellIcon:SetSize(15, 15)
	spellIcon:SetTexCoord(0.9, 0.1, 0.9, 0.1)

	local iconOverlay = castbar:CreateTexture(nil, "OVERLAY", nil, 2) -- 2 sublevels above spellIcon
	iconOverlay:SetPoint("TOPLEFT", spellIcon, -1.5, 1.5)
	iconOverlay:SetPoint("BOTTOMRIGHT", spellIcon, 1.5, -1.5)
	iconOverlay:SetTexture(iconTexture)
	castbar.iconOverlay = iconOverlay

	raidIcon:ClearAllPoints()
	raidIcon:SetPoint("RIGHT", healthbar, -8, 0)
	raidIcon:SetSize(15, 15)
	raidIcon:SetTexture(raidIcons)
	raidIcon:SetDrawLayer("ARTWORK", 1)

	plate.healthbar = healthbar
	castbar.hp = healthbar
	plate.castBar = castbar

	plate.oldglow = glow -- for threat update
	plate.elite = eliteIcon
	plate.boss = bossIcon

	glow:SetTexture(nil)
	healthbarOverlay:SetTexture(nil)
	shieldIcon:SetTexture(nil)
	castbarOverlay:SetTexture(nil)
	bossIcon:SetTexture(nil)
	spellNameBackground:SetTexture(nil)

	UpdatePlate(plate)

	plate:SetScript("OnShow", UpdatePlate)
	plate:SetScript("OnUpdate", UpdateThreat)

	plate.elapsed = 0
end

local CheckFrames = function(num, ...)
	for i = 1, num do
		local plate = select(i, ...)
		local name = plate:GetName()
		if name and find(name, "NamePlate%d") and not plate.done then
			CreatePlate(plate, name)
			plate.done = true
		end
	end
end

local numKids = 0
local lastUpdate = 0
eventFrame:SetScript("OnUpdate", function(_, elapsed)
	lastUpdate = lastUpdate + elapsed

	if lastUpdate > 0.1 then
		local newNumKids = _G.WorldFrame:GetNumChildren()

		if newNumKids ~= numKids then
			CheckFrames(newNumKids, _G.WorldFrame:GetChildren())

			numKids = newNumKids
		end
		lastUpdate = 0
	end
end)

if playerLevel ~= _G.MAX_PLAYER_LEVEL then
	eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
end

eventFrame:SetScript("OnEvent", function(self, _, level)
	playerLevel = tonumber(level)

	if playerLevel == _G.MAX_PLAYER_LEVEL then
		self:UnregisterEvent("PLAYER_LEVEL_UP")
	end
end)

hooksecurefunc("SetCVar", function(cVar, value)
	if cVar ~= "nameplateShowEnemies" and cVar ~= "nameplateShowFriends" then return end

	local text = ""
	local toggle = ""
	if cVar == "nameplateShowFriends" then
		text = _G.UNIT_NAMEPLATES_SHOW_FRIENDS
	elseif cVar == "nameplateShowEnemies" then
		text = _G.UNIT_NAMEPLATES_SHOW_ENEMIES
	end
	if value == 0 then
		toggle = "|cffFF0000OFF|r"
	elseif value == 1 then
		toggle = "|cff00FF00ON|r"
	end
	print("|cff0099CCrainPlates:|r", text, toggle)

end)
