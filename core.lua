local addonName, db = ...



local faction = {
	Horde = "_horde_",
	Alliance = "_alliance_",
	Neutral = nil
}

local factionID = {
	Horde = "1",
	Alliance = ""
}

local dataBaseQueue = {}
local localDatabase
local AddDatabase
local login = true
local palyerFaction
local wipe = table.wipe

local frame = CreateFrame("Frame")

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

local function onevent(self, event, arg1, ...)
    if(login and ((event == "ADDON_LOADED" and name == arg1) or (event == "PLAYER_LOGIN"))) then
        login = nil
        frame:UnregisterEvent("ADDON_LOADED")
        frame:UnregisterEvent("PLAYER_LOGIN")
        init()
    end
end

function AddDatabase(data)
	dataBaseQueue[#dataBaseQueue + 1] = data
end

function init()
	for i = #dataBaseQueue, 1, -1 do
		local data = dataBaseQueue[i]
		factionGroup, factionName = UnitFactionGroup("player")
		palyerFaction = factionID[factionGroup]
		if localDatabase and data.faction == palyerFaction then
			if not localDatabase.characters and data.characters then
				localDatabase.characters = data.characters
			end
			if not localDatabase.scores_karma and data.scores_karma then
				localDatabase.scores_karma = data.scores_karma
			end
		else
			localDatabase = data
		end
		dataBaseQueue[i] = nil
		data = nil
	end
	_G.MplusGG.AddDatabase = nil
	collectgarbage()
end



local function updateTooltip(characterName, characterRealm, factionGroup)
	if login == nil and palyerFaction == factionID[factionGroup] then
	fixedCharacterRealm = string.gsub(characterRealm, "%W", "_");
	index = "eu" .. faction[factionGroup] .. fixedCharacterRealm
	for i, name in ipairs(localDatabase.characters[index]) do
		if name == characterName then
			temp = localDatabase.scores_karma[index][i]
			score = temp:match('[%d]+[_]')
			karma = temp:match('[_][%d]+')
			GameTooltip:AddLine("Score: " .. score:gsub('[%W]', ""))
			GameTooltip:AddLine("Karma: " .. karma:gsub('[%W]', ""))
			return
		end
	end
end
end

local function getCharacterInfo()
	unit = GameTooltip:GetUnit()
	if UnitIsPlayer(unit) or UnitIsPlayer("mouseover") then
		characterName, characterRealm = UnitName(unit);
		factionGroup, factionName = UnitFactionGroup(unit)
		if characterName == nil then
			characterName, characterRealm = UnitName("mouseover");
		end
		if characterRealm == nil or characterRealm == "" then
			characterRealm = GetRealmName();
		end
		if factionGroup == nil then
			factionGroup, factionName = UnitFactionGroup("mouseover")
		end
		
		updateTooltip(characterName, characterRealm, factionGroup)
		GameTooltip:Show()
	end
end

GameTooltip:HookScript("OnTooltipSetUnit", getCharacterInfo)
frame:SetScript("OnEvent", onevent)

_G.MplusGG = {}
_G.MplusGG.AddDatabase = AddDatabase