local addonName, db = ...

-- Encode WoW API Faction to match our search logic
local faction = {
	Horde = "_horde_",
	Alliance = "_alliance_",
	Neutral = nil
}

-- Endcode WoW API Faction to match our DBLoad logic
local factionID = {
	Horde = "1",
	Alliance = ""
}

-- Local Vars 
local AddDatabase
local dataBaseQueue = {}
local localDatabase
local login = true
local playerFaction
local wipe = table.wipe
local showScore = true

-- Frame for Evenets 
local frame = CreateFrame("Frame")


-- RegisterEvents here
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent('LFG_LIST_APPLICANT_LIST_UPDATED')


-- Array for incoming Data
function AddDatabase(data)
	dataBaseQueue[#dataBaseQueue + 1] = data
end

-- Initializes the localDatabase from files
-- Loads only playerFaction and Region Data 
function init()
	for i = #dataBaseQueue, 1 , -1 do
		local data = dataBaseQueue[i]
		factionGroup, factionName = UnitFactionGroup("player")
		playerFaction = factionID[factionGroup]
		if localDatabase and data.faction == playerFaction then
			if not localDatabase.characters and data.characters then
				localDatabase.characters = data.characters
			end
			if not localDatabase.scores_karma and data.scores_karma then
				localDatabase.scores_karma = data.scores_karma
			end
		else
			if data.faction == playerFaction then
				localDatabase = data
			end
		end
		dataBaseQueue[i] = nil
		data = nil
	end
	_G.MplusGG.AddDatabase = nil
	collectgarbage()
end


-- Adds Score and Karma to the ToolTip
-- Checking if player is logged in and data is loaded
-- Updates Data only for same faction
-- Decodes score and karma from table
local function updateTooltip(characterName, characterRealm, factionGroup)
	if login == nil and playerFaction == factionID[factionGroup] then
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

-- OnToolTipSetUnit initializes the ToolTip update
-- Calls updateTooltip with 
-- @para characterName, characterRealm, factionGroup
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

-- Create Space for LFG Score UI
ScoreCheckButton = CreateFrame("CheckButton", nil, LFGListFrame.ApplicationViewer.RefreshButton, "UICheckButtonTemplate")
ScoreCheckButton:SetPoint("RIGHT", LFGListFrame.ApplicationViewer.RefreshButton, "LEFT", 0, 0)
ScoreCheckButton:SetSize(30, 32)
ScoreCheckButton:SetChecked(true)

ScoreCheckButtonText = ScoreCheckButton:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
ScoreCheckButtonText:SetPoint("RIGHT", ScoreCheckButton, "LEFT", 0, 0)
ScoreCheckButtonText:SetText("Show Score")



ScoreHeaderButton = CreateFrame("Button", nil, LFGListFrame.ApplicationViewer.ItemLevelColumnHeader, "LFGListColumnHeaderTemplate")
ScoreHeaderButton:SetSize(75,24)
ScoreHeaderButton:SetPoint("LEFT", LFGListFrame.ApplicationViewer.ItemLevelColumnHeader, "RIGHT")
ScoreHeaderButton:SetText("Score")
ScoreHeaderButton:Hide()

local applicantSpace = { LFGListApplicationViewerScrollFrameScrollChild:GetChildren() }
for _, child in ipairs(applicantSpace) do
	ScoreLabel  = child.Member1:CreateFontString(nil, "ARTWORK", "ScoreLabelSmall")
	ScoreLabel:SetPoint("LEFT", child.Member1, "LEFT", 200, 0)
	ScoreLabel:SetParent(child.Member1)
	ScoreLabel:SetTextColor(0.5,0.5,0.5,1)
	ScoreLabel:SetText("Unknown")
	ScoreLabel:Hide()
end

function Score_DeleteData()
	
	local applicantSpace = { LFGListApplicationViewerScrollFrameScrollChild:GetChildren() }
	for _, child in ipairs(applicantSpace) do
		ScoreLabel  = child.Member1.ScoreLabel
		ScoreLabel:SetPoint("LEFT", child.Member1, "LEFT", 200, 0)
		ScoreLabel:SetTextColor(0.5,0.5,0.5,1)
		ScoreLabel:SetParent(child.Member1)
		ScoreLabel:SetText("Unknown")
	end	
end
-- UpdateLFG Score
local function updateLFG()
	premadeLocal = {}
	local children = { LFGListApplicationViewerScrollFrameScrollChild:GetChildren() };
	for _, child in ipairs(children) do
		local applicantName = child.Member1.Name:GetText()
		if applicantName ~= "Name" then
			appID = child.Member1:GetParent().applicantID
			Idx = child.Member1.memberIdx
			if appID ~= nil and Idx ~= nil then 
				name, class, localizedClass, level, itemLevel, honorLevel, tank, healer, damage, assignedRole, relationship = C_LFGList.GetApplicantMemberInfo(appID, Idx);
				child.Member1.ScoreLabel:SetTextColor(0.5,0.5,0.5,1)
				child.Member1.ScoreLabel:SetText(getScoreString(name))
			end
		end
	end
end

function updateLFGVisibility(wide) 
	if wide == true then
		ScoreHeaderButton:Show()
		ScoreHeaderButton:SetSize(90,24)
		PVEFrame:SetWidth(685)
		LFGListPVEStub:SetWidth(460)
		local applicantSpace = { LFGListApplicationViewerScrollFrameScrollChild:GetChildren() }
		for _, child in ipairs(applicantSpace) do
			child:SetWidth(415)
			ScoreLabel  = child.Member1.ScoreLabel
			ScoreLabel:Show()

		end
	else
		ScoreHeaderButton:Hide()
		ScoreHeaderButton:SetSize(75,24)
		PVEFrame:SetWidth(563)
		LFGListPVEStub:SetWidth(338)
		local applicantSpace = { LFGListApplicationViewerScrollFrameScrollChild:GetChildren() }
		for _, child in ipairs(applicantSpace) do
			child:SetWidth(309)
			ScoreLabel  = child.Member1.ScoreLabel
			ScoreLabel:Hide()

		end
	end
end

function getScoreString(name)
	local characterName = name:match('[%a]+[-]*')
	local realm = name:match('[-][%a]+')
	if  realm == "" or realm == nil then
		realm = GetRealmName()
	end
	characterName = characterName:gsub('[%-]', "")
	realm = realm:gsub("%-", "")
	fixedCharacterRealm = string.gsub(realm, "%W", "_")
	index = "eu_alliance_" .. fixedCharacterRealm
	for i, name in ipairs(localDatabase.characters[index]) do
		if name == characterName then
			temp = localDatabase.scores_karma[index][i]
				score = temp:match('[%d]+[_]')
				karma = temp:match('[_][%d]+')
					return "Score: " ..score:gsub('[%W]', "") .. " Karma: " .. karma:gsub('[%W]', "")
		end 
	end 
	return "No Score available" 
end
-- HandelEvents here
local function onevent(self, event, arg1, ...)
    if(login and ((event == "ADDON_LOADED" and name == arg1) or (event == "PLAYER_LOGIN"))) then
        login = nil
        frame:UnregisterEvent("ADDON_LOADED")
        frame:UnregisterEvent("PLAYER_LOGIN")
        init()
	end
	if event == 'LFG_LIST_APPLICANT_LIST_UPDATED' then
		updateLFG(self)
	end
	if event == 'GROUP_ROSTER_UPDATE' and GetNumGroupMembers() >= 5 then
		Score_DeleteData()
	end
end


-- SetHooks and EventScripts here 
ScoreCheckButton:SetScript("OnShow", function()
	ScoreCheckButton:SetChecked(showScore)
	if showScore == true then
		updateLFGVisibility(true)
		updateLFG()
	else
		updateLFGVisibility(false)
	end
end)
ScoreCheckButton:SetScript("OnHide", function()
	updateLFGVisibility(false)
	local children = { LFGListApplicationViewerScrollFrameScrollChild:GetChildren() };
	for _, child in ipairs(children) do
		child.Member1.ScoreLabel:SetTextColor(0.5,0.5,0.5,1)
		child.Member1.ScoreLabel:SetText("Unknown")
	end
end)
ScoreCheckButton:SetScript("OnClick", function()
	showScore = not showScore
	if showScore == true then
		updateLFGVisibility(true)
	else
		updateLFGVisibility(false)
	end
end)
GameTooltip:HookScript("OnTooltipSetUnit", getCharacterInfo)
frame:SetScript("OnEvent", onevent)

-- DB Global Handler declaration
_G.MplusGG = {}
_G.MplusGG.AddDatabase = AddDatabase