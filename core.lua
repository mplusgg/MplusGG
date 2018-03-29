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
local login = nil
local loaded = nil
local playerFaction
local playerFactionString
local wipe = table.wipe
local showScore = true
local startTime = 0
function saveRunData()
end
-- RatingArray
local rating = {
	[1] = 0,
	[2] = 0,
	[3] = 0,
	[4] = 0
}

-- Frame for Evenets 
local frame = CreateFrame("Frame")
local Vote


-- RegisterEvents here
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent('LFG_LIST_APPLICANT_LIST_UPDATED')
frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
frame:RegisterEvent("CHALLENGE_MODE_START")

-- Array for incoming Data
function AddDatabase(data)
	dataBaseQueue[#dataBaseQueue + 1] = data
end

-- Initializes SavedRuns if nil
function InitializeSavedruns()
	if MplusGG_Runs == nil then
		MplusGG_Runs = {}
	end
	if MplusGG_Config == nil then
		MplusGG_Config.showRate = nil
	end
end

-- Initializes the localDatabase from files
-- Loads only playerFaction and Region Data 
function init()
	for i = #dataBaseQueue, 1 , -1 do
		local data = dataBaseQueue[i]
		factionGroup, factionName = UnitFactionGroup("player")
		playerFaction = factionID[factionGroup]
		playerFactionString = faction[factionGroup]
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
	if login == nil and playerFaction == factionID[factionGroup]  and characterRealm ~= "" and characterRealm ~= nil then
		fixedCharacterRealm = string.gsub(characterRealm, "%s", "");
		index = "eu" .. faction[factionGroup] .. db.realmMap[fixedCharacterRealm]
		for i, name in ipairs(localDatabase.characters[index]) do
			if name == characterName then
				temp = localDatabase.scores_karma[index][i]
				score, karma = string.match(temp,"(.*)_(.*)")
				GameTooltip:AddLine("Score: " .. score)
				GameTooltip:AddLine("Karma: " .. karma)
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
	local characterName, realm = string.match(name, "(.*)-(.*)")
	if  realm == "" or realm == nil then
		realm = GetRealmName()
		characterName = name
	end
	fixedCharacterRealm = string.gsub(realm, "%s", "")
	index = "eu" .. playerFactionString .. db.realmMap[fixedCharacterRealm]
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

-- Handel Runs and save to Savedvariables
function getStartTime()
	startTime = GetServerTime()
end

function updatePartyString()
	local string,_ = UnitName("player")
	for groupindex = 1,MAX_PARTY_MEMBERS do
		if (UnitExists("party"..groupindex)) then
			string = string .. "," .. UnitGUID("party" .. groupindex) .. ";" .. rating[groupindex]
		end
	end
	return string
end

-- Only if not Soloing 
function updateRunData()
	if (generateVoteFrame()) then
		Vote:Show()
	end
end

function saveRunData()
	local mapID, level, time, onTime, keystoneUpgradeLevels = C_ChallengeMode.GetCompletionInfo()
	local instanceId = select(8,GetInstanceInfo())
	local partyString = updatePartyString()

	MplusGG_Runs[startTime .. "_" .. mapID .. "_" .. instanceId .. "_" .. level] = partyString

end
--Create Vote Frame
-------------------
--MainFrame
-------------------
function createMainFrame()
	Vote = CreateFrame("Frame", "Vote_Frame", UIParent, "BasicFrameTemplateWithInset");
	Vote:SetSize(250, 200);
	Vote:SetPoint("CENTER"); -- Doesn't need to be ("CENTER", UIParent, "CENTER")
		
	Vote.title = Vote:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	Vote.title:SetPoint("LEFT", Vote.TitleBg, "LEFT", 5, 0);
	Vote.title:SetText("Rate your Teammates");
	Vote:SetMovable(true)
	Vote:EnableMouse(true)
	Vote:RegisterForDrag("LeftButton")
	Vote:SetScript("OnDragStart", Vote.StartMoving)
	Vote:SetScript("OnDragStop", Vote.StopMovingOrSizing)
	Vote:SetScript("OnHide", saveRunData)
	
-------------------
-- Buttons
-------------------
	local _, _, icon_up = GetSpellInfo(149539)
	local _, _, icon_down = GetSpellInfo(150068)
	local iconSize = 25

--[[ GET CLASSColor
local _, Class = UnitClass("player")
local r,g,b,_ = GetClassColor(Class)
:SetTextColor(r,g,b)
]]

--PartyMember 1
	Vote.upVote1 = CreateFrame("Button", nil, Vote, "GameMenuButtonTemplate");
	Vote.upVote1:SetPoint("CENTER", Vote, "TOP", 60, -55);
	Vote.upVote1:SetSize(iconSize, iconSize);
	Vote.upVote1:SetNormalTexture(icon_up)
	Vote.upVote1:SetScript("OnClick", function() rating[1] = 1 end)


	Vote.downVote1 = CreateFrame("Button", nil, Vote, "GameMenuButtonTemplate");
	Vote.downVote1:SetPoint("CENTER", Vote.upVote1, "RIGHT", 20, 0);
	Vote.downVote1:SetSize(iconSize, iconSize);
	Vote.downVote1:SetNormalTexture(icon_down)
	Vote.downVote1:SetScript("OnClick", function() rating[1] = -1 end)

	Vote.name1 = Vote:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	Vote.name1:SetPoint("CENTER", Vote, "TOP", -80, -55);
	Vote.name1:SetText("Member1")

--PartyMember 2

	Vote.upVote2 = CreateFrame("Button", nil, Vote, "GameMenuButtonTemplate");
	Vote.upVote2:SetPoint("CENTER", Vote.upVote1, "TOP", 0, -50);
	Vote.upVote2:SetSize(iconSize, iconSize);
	Vote.upVote2:SetNormalTexture(icon_up)
	Vote.upVote2:SetScript("OnClick", function() rating[2] = 1 end)


	Vote.downVote2 = CreateFrame("Button", nil, Vote, "GameMenuButtonTemplate");
	Vote.downVote2:SetPoint("CENTER", Vote.upVote2, "RIGHT", 20, 0);
	Vote.downVote2:SetSize(iconSize, iconSize);
	Vote.downVote2:SetNormalTexture(icon_down)
	Vote.downVote2:SetScript("OnClick", function() rating[2] = -1 end)

	Vote.name2 = Vote:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	Vote.name2:SetPoint("CENTER", Vote.name1, "TOP", 0, -45);
	Vote.name2:SetText("Member2")

--PartyMember 3

	Vote.upVote3 = CreateFrame("Button", nil, Vote, "GameMenuButtonTemplate");
	Vote.upVote3:SetPoint("CENTER", Vote.upVote2, "TOP", 0, -50);
	Vote.upVote3:SetSize(iconSize, iconSize);
	Vote.upVote3:SetNormalTexture(icon_up)
	Vote.upVote3:SetScript("OnClick", function() rating[3] = 1 end)


	Vote.downVote3 = CreateFrame("Button", nil, Vote, "GameMenuButtonTemplate");
	Vote.downVote3:SetPoint("CENTER", Vote.upVote3, "RIGHT", 20, 0);
	Vote.downVote3:SetSize(iconSize, iconSize);
	Vote.downVote3:SetNormalTexture(icon_down)
	Vote.downVote3:SetScript("OnClick", function() rating[3] = -1 end)

	Vote.name3 = Vote:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	Vote.name3:SetPoint("CENTER", Vote.name2, "TOP", 0, -41);
	Vote.name3:SetText("Member3")

--PartyMember 4

	Vote.upVote4 = CreateFrame("Button", nil, Vote, "GameMenuButtonTemplate");
	Vote.upVote4:SetPoint("CENTER", Vote.upVote3, "TOP", 0, -50);
	Vote.upVote4:SetSize(iconSize, iconSize);
	Vote.upVote4:SetNormalTexture(icon_up)
	Vote.upVote4:SetScript("OnClick", function() rating[4] = 1 end)



	Vote.downVote4 = CreateFrame("Button", nil, Vote, "GameMenuButtonTemplate");
	Vote.downVote4:SetPoint("CENTER", Vote.upVote4, "RIGHT", 20, 0);
	Vote.downVote4:SetSize(iconSize, iconSize);
	Vote.downVote4:SetNormalTexture(icon_down)
	Vote.downVote4:SetScript("OnClick", function() rating[4] = -1 end)

	Vote.name4 = Vote:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	Vote.name4:SetPoint("CENTER", Vote.name3, "TOP", 0, -44);
	Vote.name4:SetText("Member4")
	Vote:Hide()
end
-- Generate VoteFrame, Sets Party PlayerName and ClassColor also hide Name and Buttons if player not exists
function generateVoteFrame()
	for groupindex = 1,MAX_PARTY_MEMBERS do
		if (UnitExists("party".. groupindex)) then
			name,_ = UnitName("party1")
			_, Class = UnitClass("party1")
			r,g,b,_ = GetClassColor(Class)
			Vote.name1:SetTextColor(r,g,b)
			Vote.name1:SetText(name)
			Vote.name1:Show()
			Vote.upVote1:Show()
			Vote.downVote1:Show()
		elseif (not UnitExists("party".. groupindex) and groupindex == 1) then
			Vote.name1:Hide()
			Vote.upVote1:Hide()
			Vote.downVote1:Hide()
		end
		if (UnitExists("party"..groupindex)) then
			name,_ = UnitName("party2")
			_, Class = UnitClass("party2")
			r,g,b,_ = GetClassColor(Class)
			Vote.name2:SetTextColor(r,g,b)
			Vote.name2:SetText(name)
			Vote.name2:Show()
			Vote.upVote2:Show()
			Vote.downVote2:Show()
		elseif (not UnitExists("party".. groupindex) and groupindex == 2) then
			Vote.name2:Hide()
			Vote.upVote2:Hide()
			Vote.downVote2:Hide()
		end
		if (UnitExists("party"..groupindex)) then
			name,_ = UnitName("party3")
			_, Class = UnitClass("party3")
			r,g,b,_ = GetClassColor(Class)
			Vote.name3:SetTextColor(r,g,b)
			Vote.name3:SetText(name)
			Vote.name3:Show()
			Vote.upVote3:Show()
			Vote.downVote3:Show()
		elseif (not UnitExists("party".. groupindex) and groupindex == 3) then
			Vote.name3:Hide()
			Vote.upVote3:Hide()
			Vote.downVote3:Hide()
		end
		if (UnitExists("party"..groupindex)) then
			name,_ = UnitName("party4")
			_, Class = UnitClass("party4")
			r,g,b,_ = GetClassColor(Class)
			Vote.name4:SetTextColor(r,g,b)
			Vote.name4:SetText(name)
			Vote.name4:Show()
			Vote.upVote4:Show()
			Vote.downVote4:Show()
		elseif (not UnitExists("party".. groupindex) and groupindex == 4) then
			Vote.name4:Hide()
			Vote.upVote4:Hide()
			Vote.downVote4:Hide()
		end
	end
	return UnitExists("party1")
end
-- HandelEvents here
local function onevent(self, event, arg1, ...)
	if event == "ADDON_LOADED" then
		frame:UnregisterEvent("ADDON_LOADED")
		loaded = true
	end
	if event == "PLAYER_LOGIN" then
		frame:UnregisterEvent("PLAYER_LOGIN")
		login = true
	end
    if(login and loaded) then
        login = nil
        loaded = nil
		InitializeSavedruns()
		init()
		createMainFrame()
	end
	if event == 'LFG_LIST_APPLICANT_LIST_UPDATED' then
		updateLFG(self)
	end
	if event == 'GROUP_ROSTER_UPDATE' and GetNumGroupMembers() >= 5 then
		Score_DeleteData()
	end
	if event == "CHALLENGE_MODE_COMPLETED" and MplusGG_Config.showRate == true then
		updateRunData()
	end
	if event == "CHALLENGE_MODE_START" then
		getStartTime()
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

-- SHLASH for Test
SLASH_Mplus_GG1 = "/mplus"
SlashCmdList["Mplus_GG"] = function(msg)
	if msg == "test" then
		updateRunData()
	elseif msg == "activate" then
		MplusGG_Config.showRate = true
	elseif msg == "disable" then
		MplusGG_Config.showRate = nil
	end
 end 

-- DB Global Handler declaration
_G.MplusGG = {}
_G.MplusGG.AddDatabase = AddDatabase