local function Dummy_ToolTip()
	if UnitExists("mouseover") then
		GameTooltip:AddLine("es klappt xdd");
		GameTooltip:Show();
	end;
end;

GameTooltip:HookScript("OnTooltipSetUnit", Dummy_ToolTip);