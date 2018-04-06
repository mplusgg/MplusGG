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
local region 
local AddDatabase
local dataBaseQueue = {}
local localDatabase = {
	scores_karma = {},
	characters = {}
}
local login = nil
local loaded = nil
local playerFaction
local playerFactionString
local wipe = table.wipe
local showScore = true
local startTime = 0
local dbLoaded = 0
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
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

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
		MplusGG_Config = {}
		MplusGG_Config.showRate = nil
	end
	if MplusGG_Meta == nil then
		MplusGG_Meta = {}
	end
end

-- Initializes the localDatabase from files
-- Loads only playerFaction and Region Data 
function init()
	factionGroup, factionName = UnitFactionGroup("player")
	local guid = UnitGUID("player")
	local _, server_id, _ = strsplit("-",guid);
	playerFaction = factionID[factionGroup]
	playerFactionString = faction[factionGroup]
	region = db.realmRegionMap[tonumber(server_id)]
	for i = #dataBaseQueue, 1 , -1 do
		local data = dataBaseQueue[i]
		if	data.faction == playerFaction and data.region == region then
			if data.characters ~= nil then
				localDatabase.characters = data.characters
				dbLoaded = dbLoaded + 1
			end
			if data.scores_karma ~= nil then
				localDatabase.scores_karma = data.scores_karma
				dbLoaded = dbLoaded + 1
			end
		end
		dataBaseQueue[i] = nil
		data = nil
	end
	_G.MplusGG.AddDatabase = nil
	collectgarbage()
end

local function getScoreColor(score) 
	iscore = tonumber(score)
	if iscore >= tonumber(db.percentile["95+"]) then
		return 1, 0.501, 0,"|cffff8000"					-- Legendary #ff8000
	elseif iscore >= tonumber(db.percentile["75+"]) then
		return 0.639, 0.207, 0.933,"|cffa335ee"			-- Epic #a335ee
	elseif iscore >= tonumber(db.percentile["50+"]) then 
		return 0, 0.439, 0.866,"|cff0070dd"				-- Rare #0070dd
	elseif iscore >= tonumber(db.percentile["30+"]) then
		return 0.117, 1, 0,"|cff1eff00"					-- Uncommon #1eff00
	elseif iscore >= 0 then 
		return 1, 1, 1,"|cffffffff"						-- Common #ffffff
	end
end

local function getKarmaColor(karma)
	ikarma = tonumber(karma)
	if ikarma >= 0 then
		return 0, 1, 0,"|cff00ff00"	
	else 
		return 1, 0, 0,"|cffff0000"	
	end
end

-- Adds Score and Karma to the ToolTip
-- Checking if player is logged in and data is loaded
-- Updates Data only for same faction
-- Decodes score and karma from table
local function updateTooltip(characterName, characterRealm, factionGroup)
	if login == nil and playerFaction == factionID[factionGroup]  and characterRealm ~= "" and characterRealm ~= nil then
		fixedCharacterRealm = string.gsub(characterRealm, "%s", "");
		index = region .. faction[factionGroup] .. db.realmMap[fixedCharacterRealm]
		for i, name in ipairs(localDatabase.characters[index]) do
			if name == characterName then
				temp = localDatabase.scores_karma[index][i]
				score, karma = string.match(temp,"(.*)_(.*)")
				r,g,b = getScoreColor(score)
				--GameTooltip:AddLine("Score: " .. score)
				GameTooltip:AddDoubleLine("Score:", score, 1,1,1, r,g,b)
				--GameTooltip:AddLine("Karma: " .. karma)
				r,g,b = getKarmaColor(karma) 
				GameTooltip:AddDoubleLine("Karma:", karma, 1,1,1, r,g,b)
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
	if UnitIsPlayer(unit) or UnitIsPlayer("mouseover") and dbLoaded >= 2 then
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
	index = region .. playerFactionString .. db.realmMap[fixedCharacterRealm]
	for i, name in ipairs(localDatabase.characters[index]) do
		if name == characterName then
			temp = localDatabase.scores_karma[index][i]
			score, karma = string.match(temp,"(.*)_(.*)")
			_, _, _, scoreColorCode = getScoreColor(score)
			_, _, _, karmaColorCode = getKarmaColor(karma)
			return "Score: " .. scoreColorCode .. score .. "|r" .. " Karma: " .. karmaColorCode .. karma .. "|r"
		end 
	end 
	return "No Score available" 
end

-- Handel Runs and save to Savedvariables
function getStartTime()
	startTime = GetServerTime()
	SetMapToCurrentZone()
	local mapID, _ = select(8,GetInstanceInfo())
	MplusGG_Meta["region"] = region
	MplusGG_Meta["startTime"] = startTime
	MplusGG_Meta["Group"] = {}
	if (generateVoteFrame()) then
		for groupindex = 1,MAX_PARTY_MEMBERS do
			if (UnitExists("party"..groupindex)) then
				MplusGG_Meta["Group"][groupindex] = {}
				characterName, characterRealm = UnitName("party" .. groupindex);
				if characterRealm == nil or characterRealm == "" then
					characterRealm = GetRealmName();
				end
				MplusGG_Meta["Group"][groupindex]["name"] = characterName
				MplusGG_Meta["Group"][groupindex]["guid"] = UnitGUID("party" .. groupindex)
				MplusGG_Meta["Group"][groupindex]["slug"] = characterRealm
			end
		end
	end
end

function updatePartyString()
	characterRealm = GetRealmName()
	fixedCharacterRealm = string.gsub(characterRealm, "%s", "");
	local string,_ = UnitName("player")
	string = string .. "," .. UnitGUID("player") .. "," .. db.realmMap[fixedCharacterRealm]
	for groupindex = 1,#MplusGG_Meta["Group"] do
			fixedRealm = string.gsub(MplusGG_Meta["Group"][groupindex]["slug"], "%s", "")
			string = string .. ";" .. MplusGG_Meta["Group"][groupindex]["name"] .. "," .. MplusGG_Meta["Group"][groupindex]["guid"] .. "," .. db.realmMap[fixedRealm] .. "," .. rating[groupindex]
	end
	return string
end

function saveRunData()
	local _, level, _, _, _ = C_ChallengeMode.GetCompletionInfo()
	SetMapToCurrentZone()
	local mapID = select(8,GetInstanceInfo())
	local partyString = updatePartyString()
	local startTime = MplusGG_Meta["startTime"]
	MplusGG_Runs[startTime .. "_" .. mapID .. "_" .. level] = partyString

end
--Create Vote Frame
-------------------
--MainFrame
-------------------
function createMainFrame()
	Vote = CreateFrame("Frame", "Vote_Frame", UIParent, "BasicFrameTemplateWithInset");
	Vote:SetSize(250, 240);
	Vote:SetPoint("CENTER"); -- Doesn't need to be ("CENTER", UIParent, "CENTER")
		
	Vote.title = Vote:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	Vote.title:SetPoint("LEFT", Vote.TitleBg, "LEFT", 5, 0);
	Vote.title:SetText("Rate your Teammates");
	Vote:SetMovable(true)
	Vote:EnableMouse(true)
	Vote:RegisterForDrag("LeftButton")
	Vote:SetScript("OnDragStart", Vote.StartMoving)
	Vote:SetScript("OnDragStop", Vote.StopMovingOrSizing)
	--Vote:SetScript("OnHide", saveRunData)
	
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
	Vote.upVote1:SetScript("OnClick", function() rating[1] = 1 Vote.upVote1:Disable() Vote.downVote1:Enable() end)


	Vote.downVote1 = CreateFrame("Button", nil, Vote, "GameMenuButtonTemplate");
	Vote.downVote1:SetPoint("CENTER", Vote.upVote1, "RIGHT", 20, 0);
	Vote.downVote1:SetSize(iconSize, iconSize);
	Vote.downVote1:SetNormalTexture(icon_down)
	Vote.downVote1:SetScript("OnClick", function() rating[1] = -1 Vote.upVote1:Enable() Vote.downVote1:Disable() end)

	Vote.name1 = Vote:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	Vote.name1:SetPoint("CENTER", Vote, "TOP", -80, -55);
	Vote.name1:SetText("Member1")

--PartyMember 2

	Vote.upVote2 = CreateFrame("Button", nil, Vote, "GameMenuButtonTemplate");
	Vote.upVote2:SetPoint("CENTER", Vote.upVote1, "TOP", 0, -50);
	Vote.upVote2:SetSize(iconSize, iconSize);
	Vote.upVote2:SetNormalTexture(icon_up)
	Vote.upVote2:SetScript("OnClick", function() rating[2] = 1 Vote.upVote2:Disable() Vote.downVote2:Enable() end)


	Vote.downVote2 = CreateFrame("Button", nil, Vote, "GameMenuButtonTemplate");
	Vote.downVote2:SetPoint("CENTER", Vote.upVote2, "RIGHT", 20, 0);
	Vote.downVote2:SetSize(iconSize, iconSize);
	Vote.downVote2:SetNormalTexture(icon_down)
	Vote.downVote2:SetScript("OnClick", function() rating[2] = -1 Vote.upVote2:Enable() Vote.downVote2:Disable() end)

	Vote.name2 = Vote:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	Vote.name2:SetPoint("CENTER", Vote.name1, "TOP", 0, -45);
	Vote.name2:SetText("Member2")

--PartyMember 3

	Vote.upVote3 = CreateFrame("Button", nil, Vote, "GameMenuButtonTemplate");
	Vote.upVote3:SetPoint("CENTER", Vote.upVote2, "TOP", 0, -50);
	Vote.upVote3:SetSize(iconSize, iconSize);
	Vote.upVote3:SetNormalTexture(icon_up)
	Vote.upVote3:SetScript("OnClick", function() rating[3] = 1 Vote.upVote3:Disable() Vote.downVote3:Enable() end)


	Vote.downVote3 = CreateFrame("Button", nil, Vote, "GameMenuButtonTemplate");
	Vote.downVote3:SetPoint("CENTER", Vote.upVote3, "RIGHT", 20, 0);
	Vote.downVote3:SetSize(iconSize, iconSize);
	Vote.downVote3:SetNormalTexture(icon_down)
	Vote.downVote3:SetScript("OnClick", function() rating[3] = -1 Vote.upVote3:Enable() Vote.downVote3:Disable() end)

	Vote.name3 = Vote:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	Vote.name3:SetPoint("CENTER", Vote.name2, "TOP", 0, -41);
	Vote.name3:SetText("Member3")

--PartyMember 4

	Vote.upVote4 = CreateFrame("Button", nil, Vote, "GameMenuButtonTemplate");
	Vote.upVote4:SetPoint("CENTER", Vote.upVote3, "TOP", 0, -50);
	Vote.upVote4:SetSize(iconSize, iconSize);
	Vote.upVote4:SetNormalTexture(icon_up)
	Vote.upVote4:SetScript("OnClick", function() rating[4] = 1 Vote.upVote4:Disable() Vote.downVote4:Enable() end)



	Vote.downVote4 = CreateFrame("Button", nil, Vote, "GameMenuButtonTemplate");
	Vote.downVote4:SetPoint("CENTER", Vote.upVote4, "RIGHT", 20, 0);
	Vote.downVote4:SetSize(iconSize, iconSize);
	Vote.downVote4:SetNormalTexture(icon_down)
	Vote.downVote4:SetScript("OnClick", function() rating[4] = -1 Vote.upVote4:Enable() Vote.downVote4:Disable() end)

	Vote.name4 = Vote:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	Vote.name4:SetPoint("CENTER", Vote.name3, "TOP", 0, -44);
	Vote.name4:SetText("Member4")
	

	-- SaveButton
	Vote.saveVote = CreateFrame("Button", nil, Vote, "GameMenuButtonTemplate");
	Vote.saveVote:SetPoint("CENTER", Vote, "TOP", 0, -210);
	Vote.saveVote:SetWidth(220)
	Vote.saveVote:SetHeight(30)
	Vote.saveVote:SetText("Save!")
    Vote.saveVote:SetNormalFontObject("GameFontNormalSmall")
	Vote.saveVote:SetScript("OnClick", function() saveRunData() Vote:Hide() end)

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
			Vote.upVote1:Enable()
			Vote.downVote1:Enable()
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
			Vote.upVote2:Enable()
			Vote.downVote2:Enable()
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
			Vote.upVote3:Enable()
			Vote.downVote3:Enable()
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
			Vote.upVote4:Enable()
			Vote.downVote4:Enable()
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
	if event == "CHALLENGE_MODE_COMPLETED" then
		if MplusGG_Config.showRate == true then
			Vote:Show()
		end
	end
	if event == "CHALLENGE_MODE_START" then
		getStartTime()
	end
	if event == "PLAYER_ENTERING_WORLD" and MplusGG_Config.showRate == true then
		_, instanceType = IsInInstance()
		if instanceType == "party" then
			LoggingCombat(1)
			print("MplusGG started CombatLogging")
		elseif instanceType == "none" and LoggingCombat() then
			LoggingCombat(0)
			print("MplusGG stopped CombatLogging")
		end
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
		Vote:Show()
	elseif msg == "activate" then
		MplusGG_Config.showRate = true
		print("Addon is now showing Ratescreen after Challenge")
	elseif msg == "disable" then
		MplusGG_Config.showRate = nil
		print("Addon is not showing Ratescreen after Challenge anymore")
	end
 end 

-- DB Global Handler declaration
_G.MplusGG = {}
_G.MplusGG.AddDatabase = AddDatabase
