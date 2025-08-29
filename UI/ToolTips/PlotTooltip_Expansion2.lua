include("BanditsPlotTooltip.lua");
mod_tooltip_isActive_Expansion2 = true;

-- Bandit: the code below is untouched parts of Firaxis' code

-- Copyright 2018, Firaxis Games

-- ===========================================================================
-- CACHE BASE FUNCTIONS
-- ===========================================================================
BASE_FetchData = FetchData;

-- ===========================================================================
-- OVERRIDE BASE FUNCTIONS
-- ===========================================================================
function FetchData( pPlot:table )
	local data :table = BASE_FetchData(pPlot);

	data.IsVolcano = MapFeatureManager.IsVolcano(pPlot);
	data.RiverNames	= RiverManager.GetRiverName(pPlot);
	data.VolcanoName = MapFeatureManager.GetVolcanoName(pPlot);
	data.Active = MapFeatureManager.IsActiveVolcano(pPlot);
	data.Erupting = MapFeatureManager.IsVolcanoErupting(pPlot);
	data.Storm = GameClimate.GetActiveStormTypeAtPlot(pPlot);
	data.Drought = GameClimate.GetActiveDroughtTypeAtPlot(pPlot);
	data.DroughtTurns = GameClimate.GetDroughtTurnsAtPlot(pPlot);
	data.CoastalLowland = TerrainManager.GetCoastalLowlandType(pPlot);
	local territory = Territories.GetTerritoryAt(pPlot:GetIndex());
	if (territory) then
		data.TerritoryName = territory:GetName();
	else
		data.TerritoryName = nil;
	end
	if (data.CoastalLowland ~= -1) then
		data.Flooded = TerrainManager.IsFlooded(pPlot);
		data.Submerged = TerrainManager.IsSubmerged(pPlot);
	else
		data.Flooded = false;
		data.Submerged = false;
	end

	return data;
end
