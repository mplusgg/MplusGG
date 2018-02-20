local addonName, db = ...

local function getScore(characterName, characterRealm)
	for i, name in ipairs(db.characters) do
		if name == characterName then
			return db.score[i]
		end
	end
end

local function getCharacterInfo()
	unit = GameTooltip:GetUnit()
	if UnitIsPlayer(unit) then
		characterName, characterRealm = UnitName(unit)
		if characterName == nil then
			characterName, characterRealm = UnitName("mouseover")
		end
		GameTooltip:AddLine(characterName)

		if characterRealm == nil or characterRealm == "" then
			characterRealm = GetRealmName()
		end
		GameTooltip:AddLine(characterRealm)
		score = getScore(characterName, characterRealm)
		GameTooltip:AddLine(score)
		GameTooltip:Show()
	end
end

GameTooltip:HookScript("OnTooltipSetUnit", getCharacterInfo)
