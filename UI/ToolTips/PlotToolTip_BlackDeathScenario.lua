include("PlotTooltip_Expansion2.lua");

-- Bandit: the code below is untouched parts of Firaxis' code

-- ===========================================================================
--	Plot ToolTip Replacement/Extension
--	Black Death Scenario
-- ===========================================================================

-- ===========================================================================
-- INCLUDES
-- ===========================================================================
include "BlackDeathScenario_Rules";

-- ===========================================================================
-- CACHE BASE FUNCTIONS
-- ===========================================================================
XP2_FetchData = FetchData;

-- ===========================================================================
-- OVERRIDE BASE FUNCTIONS
-- ===========================================================================
function FetchData(pPlot)
	local data = XP2_FetchData(pPlot);

	local iCoerceTurns : number = RefreshObjectState(pPlot, g_PropertyKeys.CoerceTurns);
	if (iCoerceTurns ~= nil) then
		data.CoerceTurns = iCoerceTurns; 
	end

	return data;
end
