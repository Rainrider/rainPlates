local barTexture = [=[Interface\AddOns\rainPlates\media\normtexc]=]
local iconTexture = [=[Interface\AddOns\rainPlates\media\buttonnormal]=]
local overlayTexture = [=[Interface\Tooltips\Nameplate-Border]=]
local font, fontSize, fontOutline = GameFontNormal:GetFont(), 8
local raidIcons = [=[Interface\AddOns\rainPlates\media\raidicons]=]

local backdrop = {
	bgFile   = [=[Interface\ChatFrame\ChatFrameBackground]=],
    edgeFile = [=[Interface\AddOns\rainPlates\media\glowTex3]=],
    edgeSize = 2,
    insets   = {
		left   = 2,
		right  = 2,
		top    = 2,
		bottom = 2,
	},
}

local healthBarHeight = 5;
local castBarHeight = 3;
-- TODO: when does UnitLevel("player") return the right level?
local playerLevel = UnitLevel("player")

local select = select

local eventFrame = CreateFrame("Frame")

SetCVar("bloattest", 0) -- 1 might make nameplates larger but it fixes the disappearing ones.
SetCVar("bloatnameplates", 0) -- 1 makes nameplates larger depending on threat percentage.
SetCVar("bloatthreat", 0)

local UpdateTime = function(self, value)
	local minValue, maxValue = self:GetMinMaxValues()
	if self.channeling then
		self.time:SetFormattedText("%.1f ", value)
	else
		self.time:SetFormattedText("%.1f ", maxValue - value)
	end
end

local UpdateThreat = function(self, elapsed)
	self.elapsed = self.elapsed + elapsed
	if self.elapsed >= 0.5 then
		if not self.oldglow:IsShown() then
			self.healthBar.hpGlow:SetBackdropBorderColor(0, 0, 0)
		else
			local r, g, b = self.oldglow:GetVertexColor()

			self.healthBar.hpGlow:SetBackdropBorderColor(r, g, b)
		end

		self.elapsed = 0
	end
end

local UpdatePlate = function(self)
	self.healthBar:ClearAllPoints()
	self.healthBar:SetPoint("CENTER", self.healthBar:GetParent())
	self.healthBar:SetHeight(healthBarHeight)

	local r, g, b = self.healthBar:GetStatusBarColor()
	self.healthBar.hpBackground:SetVertexColor(r * 0.33, g * 0.33, b * 0.33, 0.75)

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
	self.channeling = UnitChannelInfo("target") -- castbars on nameplates are only visible for the target (arena?)

	if self.shield:IsShown() then
		self:SetStatusBarColor(0.8, 0.05, 0)
		self.iconOverlay:SetVertexColor(0.8, 0.05, 0)
	else
		self.iconOverlay:SetVertexColor(1, 1, 1)
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

local CreatePlate = function(self)
	local barFrame, nameFrame = self:GetChildren()

	local healthBar, castBar = barFrame:GetChildren()
	local glowRegion, overlayRegion, highlightRegion, levelTextRegion, bossIconRegion, raidIconRegion, stateIconRegion = barFrame:GetRegions()
	local _, castbarOverlay, shieldedRegion, spellIconRegion = castBar:GetRegions()
	local nameTextRegion = nameFrame:GetRegions()

	nameTextRegion:SetPoint("BOTTOM", healthBar, "TOP", 0, 2)
	nameTextRegion:SetFont(font, fontSize, fontOutline)
	nameTextRegion:SetShadowOffset(1.25, -1.25)
	self.name = nameTextRegion

	levelTextRegion:SetFont(font, fontSize, fontOutline)
	levelTextRegion:SetShadowOffset(1.25, -1.25)
	self.level = levelTextRegion

	healthBar:SetStatusBarTexture(barTexture)

	local hpBackground = healthBar:CreateTexture(nil, "BACKGROUND")
	hpBackground:SetAllPoints()
	hpBackground:SetTexture(barTexture)
	healthBar.hpBackground = hpBackground

	-- TODO: could use a texture or apply the backdrop directly to the healthbar instead
	local hpGlow = CreateFrame("Frame", nil, healthBar)
	hpGlow:SetFrameLevel(healthBar:GetFrameLevel() -1 > 0 and healthBar:GetFrameLevel() -1 or 0)
	hpGlow:SetPoint("TOPLEFT", healthBar, "TOPLEFT", -2, 2)
	hpGlow:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 2, -2)
	hpGlow:SetBackdrop(backdrop)
	hpGlow:SetBackdropColor(0, 0, 0, 0)
	hpGlow:SetBackdropBorderColor(0, 0, 0)
	healthBar.hpGlow = hpGlow

	castBar:HookScript("OnShow", ColorCastbar)
	castBar:HookScript("OnSizeChanged", OnSizeChanged)
	castBar:HookScript("OnValueChanged", UpdateTime)

	castBar:SetStatusBarTexture(barTexture)

	castBar.shield = shieldedRegion

	local cbBackground = castBar:CreateTexture(nil, "BACKGROUND")
	cbBackground:SetAllPoints()
	cbBackground:SetTexture(barTexture)
	cbBackground:SetVertexColor(0.25, 0.25, 0.25, 0.75)

	-- TODO: could use a texture or apply the backdrop directly to the castbar instead
	local cbGlow = CreateFrame("Frame", nil, castBar)
	cbGlow:SetFrameLevel(castBar:GetFrameLevel() -1 > 0 and castBar:GetFrameLevel() -1 or 0)
	cbGlow:SetPoint("TOPLEFT", castBar, -2, 2)
	cbGlow:SetPoint("BOTTOMRIGHT", castBar, 2, -2)
	cbGlow:SetBackdrop(backdrop)
	cbGlow:SetBackdropColor(0, 0, 0, 0)
	cbGlow:SetBackdropBorderColor(0, 0, 0)

	local castTime = castBar:CreateFontString()
	castTime:SetPoint("RIGHT", castBar, "LEFT", -2, 0)
	castTime:SetFont(font, fontSize, fontOutline)
	castTime:SetTextColor(0.84, 0.75, 0.65)
	castTime:SetShadowOffset(1.25, -1.25)
	castBar.time = castTime

	spellIconRegion:ClearAllPoints()
	spellIconRegion:SetParent(castBar)
	spellIconRegion:SetPoint("LEFT", castBar, 8, 0)
	spellIconRegion:SetSize(15, 15)
	spellIconRegion:SetTexCoord(0.9, 0.1, 0.9, 0.1)

	local iconOverlay = castBar:CreateTexture(nil, "OVERLAY", nil, 2) -- 2 sublevels above spellIconRegion
	iconOverlay:SetPoint("TOPLEFT", spellIconRegion, -1.5, 1.5)
	iconOverlay:SetPoint("BOTTOMRIGHT", spellIconRegion, 1.5, -1.5)
	iconOverlay:SetTexture(iconTexture)
	castBar.iconOverlay = iconOverlay

	-- TODO: what is that for
	highlightRegion:SetTexture(barTexture)
	highlightRegion:SetVertexColor(0.25, 0.25, 0.25)
	self.highlight = highlightRegion

	raidIconRegion:ClearAllPoints()
	raidIconRegion:SetPoint("RIGHT", healthBar, -8, 0)
	raidIconRegion:SetSize(15, 15)
	raidIconRegion:SetTexture(raidIcons)

	self.healthBar = healthBar
	self.castBar = castBar

	self.oldglow = glowRegion -- for threat update
	self.elite = stateIconRegion
	self.boss = bossIconRegion

	glowRegion:SetTexture(nil)
	overlayRegion:SetTexture(nil)
	shieldedRegion:SetTexture(nil)
	castbarOverlay:SetTexture(nil)
	stateIconRegion:SetTexture(nil)
	bossIconRegion:SetTexture(nil)

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
			CreatePlate(frame)
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
	if event == "PLAYER_LEVEL_UP" then
		playerLevel = tonumber(level)
	end
	
	if playerLevel == MAX_PLAYER_LEVEL then
		self:UnregisterEvent("PLAYER_LEVEL_UP")
	end
end)