local barTexture = [=[Interface\AddOns\rainPlates\media\normtexc]=]
local iconTexture = [=[Interface\AddOns\rainPlates\media\buttonnormal]=]
local glowTexture = [=[Interface\AddOns\rainPlates\media\glowTex]=]
local highlightTexture = [=[Interface\AddOns\rainPlates\media\highlighttex]=]
local font, fontSize, fontOutline = rainDB and rainDB.npfont or GameFontNormal:GetFont(), 8
local raidIcons = [=[Interface\AddOns\rainPlates\media\raidicons]=]

local healthBarHeight = 5;
local castBarHeight = 5;
local playerLevel = UnitLevel("player")

local select = select
local GetMinMaxValues = GetMinMaxValues

local eventFrame = CreateFrame("Frame")

SetCVar("bloattest", 0) -- 1 might make nameplates larger but it fixes the disappearing ones.
SetCVar("bloatnameplates", 0) -- 1 makes nameplates larger depending on threat percentage.
SetCVar("bloatthreat", 0)

local castbarValues = {}

local UpdateCastTime = function(castbar, value)
	local minValue, maxValue = castbar:GetMinMaxValues()
	local oldValue = castbarValues[castbar.frameName]
	if (oldValue) then
		if (value < oldValue) then -- castbar is depleting -> unit is channeling a spell
			castbar.time:SetFormattedText("%d ", value)
		else
			castbar.time:SetFormattedText("%d ", maxValue - value)
		end
	end
	castbarValues[castbar.frameName] = value
end

local UpdateThreat = function(plate, elapsed)
	plate.elapsed = plate.elapsed + elapsed
	if plate.elapsed >= 0.5 then
		if not plate.oldglow:IsShown() then
			plate.healthBar.glow:SetVertexColor(0, 0, 0)
		else
			local r, g, b = plate.oldglow:GetVertexColor()
			plate.healthBar.glow:SetVertexColor(r, g, b, 1)
		end

		plate.elapsed = 0
	end
end

local UpdatePlate = function(plate)
	local healthbar = plate.healthBar
	healthbar:ClearAllPoints()
	healthbar:SetPoint("CENTER", healthbar:GetParent())
	healthbar:SetHeight(healthBarHeight)

	local r, g, b = healthbar:GetStatusBarColor()
	healthbar.background:SetVertexColor(r * 0.33, g * 0.33, b * 0.33, 0.75)

	local name = plate.name:GetText()
	name = (strlenutf8(name) > 20) and string.gsub(name, "(%S[\128-\191]*)%S+%s", "%1. ") or name
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

local Castbar_OnShow = function(castbar)
	if castbar.shield:IsShown() then
		castbar:SetStatusBarColor(0.8, 0.05, 0)
	end
end

local Castbar_OnSizeChanged = function(castbar, width, height)
	if floor(height + 0.1) ~= castBarHeight then
		local healthbar = castbar.hp
		castbar:ClearAllPoints()
		castbar:SetPoint("TOPLEFT", healthbar, "BOTTOMLEFT", 0, -4)
		castbar:SetPoint("TOPRIGHT", healthbar, "BOTTOMRIGHT", 0, -4)
		castbar:SetHeight(castBarHeight)
	end
end

local CreatePlate = function(plate, frameName)
	local barFrame, nameFrame = plate:GetChildren()

	local healthBar, absorbBar, castBar = barFrame:GetChildren()

	local glow, healthbarOverlay, highlight, levelText, bossIcon, raidIcon, stateIcon = barFrame:GetRegions()
	local _, castbarOverlay, shieldIcon, spellIcon, spellName, spellNameBackground = castBar:GetRegions()
	local nameText = nameFrame:GetRegions()

	nameText:ClearAllPoints()
	nameText:SetPoint("BOTTOM", healthBar, "TOP", 0, 2)
	nameText:SetFont(font, fontSize, fontOutline)
	nameText:SetShadowOffset(1.25, -1.25)
	plate.name = nameText

	levelText:SetFont(font, fontSize, fontOutline)
	levelText:SetShadowOffset(1.25, -1.25)
	plate.level = levelText

	spellName:ClearAllPoints()
	spellName:SetPoint("TOP", castBar, "BOTTOM", 0, -2)
	spellName:SetFont(font, fontSize, fontOutline)
	spellName:SetShadowOffset(1.25, -1.25)

	healthBar:SetStatusBarTexture(barTexture)

	local hbBackground = healthBar:CreateTexture(nil, "BACKGROUND")
	hbBackground:SetAllPoints()
	hbBackground:SetTexture(barTexture)
	healthBar.background = hbBackground

	local hbGlow = healthBar:CreateTexture(nil, "BACKGROUND")
	hbGlow:SetTexture(glowTexture)
	hbGlow:SetPoint("TOPLEFT", -1.5, 1.5)
	hbGlow:SetPoint("BOTTOMRIGHT", 1.5, -1.5)
	hbGlow:SetVertexColor(0, 0, 0)
	healthBar.glow = hbGlow

	highlight:SetTexture(highlightTexture)
	plate.highlight = highlight

	castBar:SetStatusBarTexture(barTexture)
	castBar:ClearAllPoints()
	castBar:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT", 0, -4)
	castBar:SetPoint("TOPRIGHT", healthBar, "BOTTOMRIGHT", 0, -4)
	castBar:SetHeight(castBarHeight)

	castBar:HookScript("OnShow", Castbar_OnShow)
	castBar:HookScript("OnSizeChanged", Castbar_OnSizeChanged)
	castBar:HookScript("OnValueChanged", UpdateCastTime)

	castBar.shield = shieldIcon
	castBar.frameName = frameName

	local cbBackground = castBar:CreateTexture(nil, "BACKGROUND")
	cbBackground:SetAllPoints()
	cbBackground:SetTexture(barTexture)
	cbBackground:SetVertexColor(0.25, 0.25, 0.25, 0.75)

	local cbGlow = castBar:CreateTexture(nil, "BACKGROUND")
	cbGlow:SetTexture(glowTexture)
	cbGlow:SetPoint("TOPLEFT", -1.5, 1.5)
	cbGlow:SetPoint("BOTTOMRIGHT", 1.5, -1.5)
	cbGlow:SetVertexColor(0, 0, 0)
	castBar.glow = cbGlow

	local castTime = castBar:CreateFontString()
	castTime:SetPoint("RIGHT", castBar, "LEFT", -2, 0)
	castTime:SetFont(font, fontSize, fontOutline)
	castTime:SetTextColor(0.84, 0.75, 0.65)
	castTime:SetShadowOffset(1.25, -1.25)
	castBar.time = castTime

	spellIcon:ClearAllPoints()
	spellIcon:SetPoint("LEFT", castBar, 8, 0)
	spellIcon:SetSize(15, 15)
	spellIcon:SetTexCoord(0.9, 0.1, 0.9, 0.1)

	local iconOverlay = castBar:CreateTexture(nil, "OVERLAY", nil, 2) -- 2 sublevels above spellIcon
	iconOverlay:SetPoint("TOPLEFT", spellIcon, -1.5, 1.5)
	iconOverlay:SetPoint("BOTTOMRIGHT", spellIcon, 1.5, -1.5)
	iconOverlay:SetTexture(iconTexture)
	castBar.iconOverlay = iconOverlay

	raidIcon:ClearAllPoints()
	raidIcon:SetPoint("RIGHT", healthBar, -8, 0)
	raidIcon:SetSize(15, 15)
	raidIcon:SetTexture(raidIcons)
	raidIcon:SetDrawLayer("ARTWORK", 1)

	plate.healthBar = healthBar
	castBar.hp = healthBar
	plate.castBar = castBar

	plate.oldglow = glow -- for threat update
	plate.elite = stateIcon
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
		if name and name:find("NamePlate%d") and not plate.done then
			CreatePlate(plate, name)
			plate.done = true
		end
	end
end

local numKids = 0
local lastUpdate = 0
eventFrame:SetScript("OnUpdate", function(self, elapsed)
	lastUpdate = lastUpdate + elapsed

	if lastUpdate > 0.1 then
		local newNumKids = WorldFrame:GetNumChildren()

		if newNumKids ~= numKids then
			CheckFrames(newNumKids, WorldFrame:GetChildren())

			numKids = newNumKids
		end
		lastUpdate = 0
	end
end)

if playerLevel ~= MAX_PLAYER_LEVEL then
	eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
end

eventFrame:SetScript("OnEvent", function(self, event, level)
	playerLevel = tonumber(level)

	if playerLevel == MAX_PLAYER_LEVEL then
		self:UnregisterEvent("PLAYER_LEVEL_UP")
	end
end)

hooksecurefunc("SetCVar", function(cVar, value)
	if cVar ~= "nameplateShowEnemies" and cVar ~= "nameplateShowFriends" then return end

	local text = ""
	local toggle = ""
	if cVar == "nameplateShowFriends" then
		text = UNIT_NAMEPLATES_SHOW_FRIENDS
	elseif cVar == "nameplateShowEnemies" then
		text = UNIT_NAMEPLATES_SHOW_ENEMIES
	end
	if value == 0 then
		toggle = "|cffFF0000OFF|r"
	elseif value == 1 then
		toggle = "|cff00FF00ON|r"
	end
	print("|cff0099CCrainPlates:|r", text, toggle)

end)
