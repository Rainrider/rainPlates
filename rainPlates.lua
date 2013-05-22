local barTexture = [=[Interface\AddOns\rainPlates\media\normtexc]=]
local iconTexture = [=[Interface\AddOns\rainPlates\media\buttonnormal]=]
local glowTexture = [=[Interface\AddOns\rainPlates\media\glowTex]=]
local font, fontSize, fontOutline = GameFontNormal:GetFont(), 8
local raidIcons = [=[Interface\AddOns\rainPlates\media\raidicons]=]

local healthBarHeight = 5;
local castBarHeight = 5;
-- TODO: when does UnitLevel("player") return the right level?
local playerLevel = UnitLevel("player")

local select = select
local GetMinMaxValues = GetMinMaxValues

local eventFrame = CreateFrame("Frame")

SetCVar("bloattest", 0) -- 1 might make nameplates larger but it fixes the disappearing ones.
SetCVar("bloatnameplates", 0) -- 1 makes nameplates larger depending on threat percentage.
SetCVar("bloatthreat", 0)

local castbarValues = {}

local UpdateTime = function(self, value)
	local minValue, maxValue = self:GetMinMaxValues()
	local oldValue = castbarValues[self.frameName]
	if (oldValue) then
		if (value < oldValue) then -- castbar is depleting -> unit is channeling a spell
			self.time:SetFormattedText("%.1f ", value)
		else
			self.time:SetFormattedText("%.1f ", maxValue - value)
		end
	end
	castbarValues[self.frameName] = value
end

local UpdateThreat = function(self, elapsed)
	self.elapsed = self.elapsed + elapsed
	if self.elapsed >= 0.5 then
		if not self.oldglow:IsShown() then
			self.healthBar.glow:SetVertexColor(0, 0, 0)
		else
			local r, g, b = self.oldglow:GetVertexColor()
			self.healthBar.glow:SetVertexColor(r, g, b, 1)
		end

		self.elapsed = 0
	end
end

local UpdatePlate = function(self)
	self.healthBar:ClearAllPoints()
	self.healthBar:SetPoint("CENTER", self.healthBar:GetParent())
	self.healthBar:SetHeight(healthBarHeight)

	local r, g, b = self.healthBar:GetStatusBarColor()
	self.healthBar.background:SetVertexColor(r * 0.33, g * 0.33, b * 0.33, 0.75)

	self.castBar:ClearAllPoints()
	self.castBar:SetPoint("TOPLEFT", self.healthBar, "BOTTOMLEFT", 0, -4)
	self.castBar:SetPoint("TOPRIGHT", self.healthBar, "BOTTOMRIGHT", 0, -4)
	self.castBar:SetHeight(castBarHeight)

	self.highlight:ClearAllPoints()
	--self.highlight:SetAllPoints(self.healthBar) -- TODO: almost same position as hpGlow?
	self.highlight:SetAllPoints(self)

	local name = self.name:GetText()
	name = (string.len(name) > 20) and string.gsub(name, "%s?(.[\128-\191]*)%S+%s", "%1. ") or name
	self.name:SetText(name)

	local level, elite = tonumber(self.level:GetText()), self.elite:IsShown()
	self.level:ClearAllPoints()
	self.level:SetPoint("RIGHT", self.healthBar, "LEFT", -2, 0)
	if self.boss:IsShown() then
		self.level:SetText("??")
		self.level:SetTextColor(0.8, 0.05, 0)
		self.level:Show()
	elseif not elite and level == playerLevel then
		self.level:Hide()
	else
		self.level:SetText(level..(elite and "+" or ""))
	end
	-- TODO: testing only
	if self.highlight:IsShown() then
		print(self.highlight:GetVertexColor())
	end
end

local ColorCastbar = function(self)
	if self.shield:IsShown() then
		self:SetStatusBarColor(0.8, 0.05, 0)
		self.iconOverlay:SetVertexColor(0.8, 0.05, 0)
		self.glow:SetVertexColor(0.75, 0.75, 0.75)
	else
		self.iconOverlay:SetVertexColor(1, 1, 1)
		self.glow:SetVertexColor(0, 0, 0)
	end
end

local OnHide = function(self)
	self.highlight:Hide()
end

local OnSizeChanged = function(self, width, height)
	if floor(height) ~= castBarHeight then
		self:ClearAllPoints()
		self:SetHeight(castBarHeight)
		local healthBar = self:GetParent():GetChildren()
		self:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT", 0, -4)
		self:SetPoint("TOPRIGHT", healthBar, "BOTTOMRIGHT", 0, -4)
	end
end

local CreatePlate = function(self, frameName)
	local barFrame, nameFrame = self:GetChildren()

	local healthBar, castBar = barFrame:GetChildren()

	local glow, healthbarOverlay, highlight, levelText, bossIcon, raidIcon, stateIcon = barFrame:GetRegions()
	local _, castbarOverlay, shieldIcon, spellIcon, spellName, spellNameBackground = castBar:GetRegions()
	local nameText = nameFrame:GetRegions()

	nameText:ClearAllPoints()
	nameText:SetPoint("BOTTOM", healthBar, "TOP", 0, 2)
	nameText:SetFont(font, fontSize, fontOutline)
	nameText:SetShadowOffset(1.25, -1.25)
	self.name = nameText

	levelText:SetFont(font, fontSize, fontOutline)
	levelText:SetShadowOffset(1.25, -1.25)
	self.level = levelText

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

	castBar:HookScript("OnShow", ColorCastbar)
	castBar:HookScript("OnSizeChanged", OnSizeChanged)
	castBar:HookScript("OnValueChanged", UpdateTime)

	castBar:SetStatusBarTexture(barTexture)

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
	spellIcon:SetParent(castBar)
	spellIcon:SetPoint("LEFT", castBar, 8, 0)
	spellIcon:SetSize(15, 15)
	spellIcon:SetTexCoord(0.9, 0.1, 0.9, 0.1)

	local iconOverlay = castBar:CreateTexture(nil, "OVERLAY", nil, 2) -- 2 sublevels above spellIcon
	iconOverlay:SetPoint("TOPLEFT", spellIcon, -1.5, 1.5)
	iconOverlay:SetPoint("BOTTOMRIGHT", spellIcon, 1.5, -1.5)
	iconOverlay:SetTexture(iconTexture)
	castBar.iconOverlay = iconOverlay

	-- TODO: what is that for
	highlight:SetTexture(barTexture)
	highlight:SetVertexColor(0.25, 0.25, 0.25)
	self.highlight = highlight

	raidIcon:ClearAllPoints()
	raidIcon:SetPoint("RIGHT", healthBar, -8, 0)
	raidIcon:SetSize(15, 15)
	raidIcon:SetTexture(raidIcons)

	self.healthBar = healthBar
	self.castBar = castBar

	self.oldglow = glow -- for threat update
	self.elite = stateIcon
	self.boss = bossIcon

	glow:SetTexture(nil)
	healthbarOverlay:SetTexture(nil)
	shieldIcon:SetTexture(nil)
	castbarOverlay:SetTexture(nil)
	stateIcon:SetTexture(nil)
	bossIcon:SetTexture(nil)
	spellNameBackground:SetTexture(nil)

	UpdatePlate(self)

	self:SetScript("OnShow", UpdatePlate)
	--self:SetScript("OnHide", OnHide)
	self:SetScript("OnUpdate", UpdateThreat)

	self.elapsed = 0
end

local CheckFrames = function(num, ...)
	for i = 1, num do
		local frame = select(i, ...)
		local frameName = frame:GetName()
		if frameName and frameName:find("NamePlate%d") and not frame.done then
			CreatePlate(frame, frameName)
			frame.done = true
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