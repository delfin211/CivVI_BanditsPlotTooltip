include("PlotToolTip");

-- Bandit: I copied these constants because modified "View" function depends on these.
local SIZE_WIDTH_MARGIN		:number = 20;
local SIZE_HEIGHT_PADDING	:number = 20;

-- Bandit: also had to copy these local variables because the "View" function also depends on these.
local m_isShowDebug    = (Options.GetAppOption("Debug", "EnableDebugPlotInfo") == 1);
local m_isWorldBuilder = GameConfiguration.IsWorldBuilderEditor();

-- Bandit: these consts are needed for tracking if any component is active to execute related code
local mod_tooltip_isActive_Expansion2         = Modding.IsModActive("4873eb62-8ccc-4574-b784-dda455e74e68");
local mod_tooltip_isActive_BarbarianClans     = Modding.IsModActive("19ED1A36-D744-4A58-8F8B-0376C2BA86E5");
local mod_tooltip_isActive_PiratesScenario    = Modding.IsModActive("A55FAFB4-9070-4597-9453-B28A99910CDA");
local mod_tooltip_isActive_BlackDeathScenario = Modding.IsModActive("C1F775D8-59B5-401B-B86D-78FAF3446EC7");

-- Bandit: custom colors
local Palette:table = {
	Regular = "COLOR_MEDIUM_GREEN",
	WarningLow = "219,109,23,255",
	WarningHigh = "Civ6Red",
	Water = "8,81,140,255",
	Land = "67,71,63,255"
};

-- Bandit: this is needed for simple language processing, punctuation
local Language:string = Options.GetAppOption("Language", "DisplayLanguage");

local PUNC_ROUND_BRACKETS:string = "PUNCTUATION_ROUND_BRACKETS";
local PUNC_SEPARATOR_COLON:string = ": ";
local PUNC_SEPARATOR_COMMA:string = ", ";
local PUNC_SEPARATOR_ENUMERATION_COMMA:string = ", "; -- Bandit: some asian languages use a different comma for enumeration (aka lists of things)
local PUNC_SEPARATOR_SEMICOLON:string = "; ";
local PUNC_FULL_STOP:string = ".";
local PUNC_SPACE:string = " ";
local PUNC_SPACE_YIELDS:string = " "; -- Bandit: (probably) temporal

if (Language == "fr_FR") then
	PUNC_SEPARATOR_COLON = " : ";
elseif (Language == "ja_JP") then
	PUNC_ROUND_BRACKETS = "PUNCTUATION_FULLWIDTH_ROUND_BRACKETS";
	PUNC_SEPARATOR_COMMA = Locale.Lookup("PUNCTUATION_IDEOGRAPHIC_COMMA");
	PUNC_SEPARATOR_SEMICOLON = Locale.Lookup("PUNCTUATION_FULLWIDTH_SEMICOLON");
	PUNC_SPACE = "";
elseif (Language == "zh_Hant_HK" or Language == "zh_Hans_CN") then
	PUNC_ROUND_BRACKETS = "PUNCTUATION_FULLWIDTH_ROUND_BRACKETS";
	PUNC_SEPARATOR_COLON = Locale.Lookup("PUNCTUATION_FULLWIDTH_COLON");
	PUNC_SEPARATOR_COMMA = Locale.Lookup("PUNCTUATION_IDEOGRAPHIC_COMMA");
	PUNC_SEPARATOR_SEMICOLON = Locale.Lookup("PUNCTUATION_FULLWIDTH_SEMICOLON");
	PUNC_FULL_STOP = Locale.Lookup("PUNCTUATION_IDEOGRAPHIC_FULL_STOP");
	PUNC_SPACE = "";
	PUNC_SPACE_YIELDS = "";
end

-- Bandit: custom functions, needed for readability
local function CreateHeading(text)
	return Locale.Lookup("LOC_MOD_TOOLTIP_COLORTAG_CUSTOM", text, Palette.Regular)..PUNC_SEPARATOR_COLON;
end

local function CreateHeading_Color(text, color)
	return Locale.Lookup("LOC_MOD_TOOLTIP_COLORTAG_CUSTOM", text, color)..PUNC_SEPARATOR_COLON;
end

local function ColorText(text, color)
	return Locale.Lookup("LOC_MOD_TOOLTIP_COLORTAG_CUSTOM", text, color);
end

-- Bandit: ...

-- 1   Ownership
-- 2   National Park
-- 3   District    or    Natural wonder    or    Improvement
-- 4   Buildings    or    Wonder    [Great works in the according biuldings]
-- 5   Resource
-- 6   Terrain
-- 7   Movement Cost [Impassable]
-- 8   Appeal
-- 9   Defence Modifier
-- 10  Continent
-- 11  Yields [from district] [from specialists]
-- 12  Worked
-- 13  Natural Wonder description
-- 14  Contamination

-- ===========================================================================
function GetDetails(data)
	local details = {};

	-- Bandit: the purpose of these vaiables is that you can easily reorder the rows in the tooltip if needed
	local RowOwnership:string = "";
	local RowNationalPark:string = "";
	local RowNaturalWonder:string = "";
	local RowNaturalWonderDescription:string = "";
	local RowDistrict:string = "";
	local RowBuildings:string = ""; -- Bandit: World wonders are considered building in wonder district
	local RowImprovement:string = "";
	local RowResource:string = "";
	local RowTerrain:string = "";
	local RowMovementCost:string = "";
	local RowAppeal:string = "";
	local RowDefenceModifier:string = "";
	local RowContinent:string = "";
	local RowWorked:string = "";
	local RowYields:string = "";
	local RowContamination:string = "";

	-- Bandit: Expansion 2
	local RowCoastalLowland:string = "";
	local RowDisaster:string = "";
	local RowNamedArea:string = "";
	local ResourceExtraction:string = "";

	-- Bandit: used for scenarios
	local RowAddition:string = "";

	local localPlayer = Players[Game.GetLocalPlayer()];

	-- Bandit: Ownership
	if (data.Owner ~= nil) then

		local szOwnerString;

		local pPlayerConfig = PlayerConfigurations[data.Owner];
		if (pPlayerConfig ~= nil) then
			szOwnerString = Locale.Lookup(pPlayerConfig:GetCivilizationShortDescription());
		end

		if (szOwnerString == nil or string.len(szOwnerString) == 0) then
			szOwnerString = Locale.Lookup("LOC_TOOLTIP_PLAYER_ID", data.Owner);
		end

		local pPlayer = Players[data.Owner];
		if(GameConfiguration:IsAnyMultiplayer() and pPlayer:IsHuman()) then
			szOwnerString = szOwnerString..PUNC_SEPARATOR_COMMA..Locale.Lookup(pPlayerConfig:GetPlayerName());
		end

		RowOwnership = CreateHeading("LOC_MOD_TOOLTIP_OWNER")..Locale.Lookup(data.OwningCityName)..PUNC_SEPARATOR_COMMA..szOwnerString;
	end

	-- Bandit: National Park
	if (data.NationalPark ~= "") then
		RowNationalPark = CreateHeading("LOC_HUD_MAP_SEARCH_TERMS_NATIONAL_PARK")..Locale.Lookup(data.NationalPark);
	end

	-- Bandit: Resource
	if (data.ResourceType ~= nil) then
		--if it's a resource that requires a tech to improve, let the player know that in the tooltip
		local resourceType = data.ResourceType;
		local resource = GameInfo.Resources[resourceType];

		local resourceTechType;
		local resourceHash = GameInfo.Resources[resourceType].Hash;

		local terrainType = data.TerrainType;
		local featureType = data.FeatureType;

		local valid_feature = false;
		local valid_terrain = false;
		local valid_resources = false;

		local requiredImprovement = "";

		-- Are there any improvements that specifically require this resource?
		for row in GameInfo.Improvement_ValidResources() do
			if (row.ResourceType == resourceType) then
				-- Found one!  Now.  Can it be constructed on this terrain/feature
				local improvementType = row.ImprovementType;
				local has_feature = false;
				for inner_row in GameInfo.Improvement_ValidFeatures() do
					if(inner_row.ImprovementType == improvementType) then
						has_feature = true;
						if(inner_row.FeatureType == featureType) then
							valid_feature = true;
						end
					end
				end
				valid_feature = not has_feature or valid_feature;

				local has_terrain = false;
				for inner_row in GameInfo.Improvement_ValidTerrains() do
					if(inner_row.ImprovementType == improvementType) then
						has_terrain = true;
						if(inner_row.TerrainType == terrainType) then
							valid_terrain = true;
						end
					end
				end
				valid_terrain = not has_terrain or valid_terrain;
				
				-- if we match the resource in Improvement_ValidResources it's a get-out-of-jail-free card for feature and terrain checks
				for inner_row in GameInfo.Improvement_ValidResources() do
					if (inner_row.ImprovementType == improvementType) then
						if (inner_row.ResourceType == resourceType) then
							requiredImprovement = inner_row.ImprovementType;
							valid_resources = true;
							break;
						end
					end
				end

				if (GameInfo.Terrains[terrainType].TerrainType == "TERRAIN_COAST") then
					if ("DOMAIN_SEA" == GameInfo.Improvements[improvementType].Domain) then
						valid_terrain = true;
					elseif ("DOMAIN_LAND" == GameInfo.Improvements[improvementType].Domain) then
						valid_terrain = false;
					end
				else
					if ("DOMAIN_SEA" == GameInfo.Improvements[improvementType].Domain) then
						valid_terrain = false;
					elseif ("DOMAIN_LAND" == GameInfo.Improvements[improvementType].Domain) then
						valid_terrain = true;
					end
				end

				if ((valid_feature == true and valid_terrain == true) or valid_resources == true) then
					resourceTechType = GameInfo.Improvements[improvementType].PrereqTech;
					break;
				end
			end
		end

		if (localPlayer ~= nil) then
			local playerResources = localPlayer:GetResources();
			if (playerResources:IsResourceVisible(resourceHash)) then
				RowResource = Locale.Lookup(resource.Name);
				if (resourceTechType ~= nil) then
					local playerTechs = localPlayer:GetTechs();
					local techType = GameInfo.Technologies[resourceTechType];
					if (techType ~= nil) then
						if (playerTechs:HasTech(techType.Index)) then
							if (mod_tooltip_isActive_Expansion2 and (data.DistrictType ~= nil or (data.ImprovementType and not data.ImprovementPillaged and data.ImprovementType == requiredImprovement))) then
								local kConsumption:table = GameInfo.Resource_Consumption[data.ResourceType];
								if (kConsumption ~= nil and data.Owner ~= nil) then
									if (kConsumption.Accumulate and Players[data.Owner]:GetTechs():HasTech(techType.Index)) then
										local iExtraction = kConsumption.ImprovedExtractionRate;
										if (iExtraction > 0) then
											ResourceExtraction = iExtraction.."[ICON_"..data.ResourceType.."]";
										end
									end
								end
							end
						else
							if ((valid_feature == true and valid_terrain == true) or valid_resources == true) then
								RowResource = RowResource..PUNC_SPACE..Locale.Lookup("LOC_MOD_TOOLTIP_REQUIRED_TECH", techType.Name, Palette.WarningHigh);
							end
						end
					end
				end
			end
		elseif m_isWorldBuilder then
			RowResource = Locale.Lookup(resource.Name);
			if (resourceTechType ~= nil and ((valid_feature == true and valid_terrain == true) or valid_resources == true)) then
				local techType = GameInfo.Technologies[resourceTechType];
				if (techType ~= nil) then
					RowResource = RowResource..PUNC_SPACE..Locale.Lookup("LOC_MOD_TOOLTIP_REQUIRED_TECH", techType.Name, Palette.WarningLow);
				end
			end
		end
		if (RowResource ~= "") then
			RowResource = CreateHeading("LOC_RESOURCE_NAME").."[ICON_"..resourceType.."]"..RowResource;
		end
	end

	local function ParseYields(data)
		local yields:string = "";
		local i = 0;
		for yieldType, v in pairs(data) do
			local yield = GameInfo.Yields[yieldType].Name;
			local yieldicon = GameInfo.Yields[yieldType].IconString;
			local str = tostring(v) .. Locale.Lookup(yieldicon);
			if (i == 0) then
				yields = yields..str;
				i = 1;
			else
				yields = yields..PUNC_SEPARATOR_COMMA..str;
			end
		end
		return yields;
	end -- function ParseYields

	local function ParseTourism()
		local tourism = localPlayer:GetCulture():GetTourismAt(data.Index);
		if (tourism > 0) then
			if (RowYields ~= "") then RowYields = RowYields..PUNC_SEPARATOR_COMMA end
			RowYields = RowYields..tourism.."[ICON_Tourism]";
		end
	end -- function ParseTourism

	-- CITY TILE
	if (data.IsCity == true and data.DistrictType ~= nil) then
		RowDistrict = CreateHeading("LOC_DISTRICT_NAME")..Locale.Lookup(GameInfo.Districts[data.DistrictType].Name);

		if (table.count(data.Yields) > 0) then RowYields = ParseYields(data.Yields) end
		if (ResourceExtraction ~= "")     then
			if (RowYields ~= "") then RowYields = RowYields..PUNC_SEPARATOR_COMMA end
			RowYields = RowYields..ResourceExtraction;
		end
		ParseTourism();
		if (RowYields ~= "")              then RowYields = ColorText("LOC_MOD_TOOLTIP_YIELDS", Palette.Regular)..PUNC_SPACE_YIELDS..Locale.Lookup("LOC_MOD_TOOLTIP_YIELDS_FROM_DISTRICT", RowYields) end

	-- DISTRICT TILE
	elseif (data.DistrictID ~= -1 and data.DistrictType ~= nil) then
		if (not GameInfo.Districts[data.DistrictType].InternalOnly) then	--Ignore 'Wonder' districts
			-- Inherent district yields
			RowDistrict = CreateHeading("LOC_DISTRICT_NAME")..Locale.Lookup(GameInfo.Districts[data.DistrictType].Name);
			if (data.DistrictPillaged) then
				RowDistrict = RowDistrict .. PUNC_SPACE .. ColorText("LOC_TOOLTIP_PLOT_PILLAGED_TEXT", Palette.WarningHigh);
			elseif (not data.DistrictComplete) then
				RowDistrict = RowDistrict..PUNC_SPACE..Locale.Lookup("LOC_TOOLTIP_PLOT_CONSTRUCTION_TEXT");
			end

			if (data.DistrictYields ~= nil) and (table.count(data.DistrictYields) > 0) then RowYields = ParseYields(data.DistrictYields) end
			if (ResourceExtraction ~= "") then
				if (RowYields ~= "") then RowYields = RowYields..PUNC_SEPARATOR_COMMA end
				RowYields = RowYields..ResourceExtraction;
			end
			ParseTourism();
			if (RowYields ~= "") then RowYields = Locale.Lookup("LOC_MOD_TOOLTIP_YIELDS_FROM_DISTRICT", RowYields) end

			-- Plot yields (ie. from Specialists)
			-- Don't show specialist info to other players
			if (data.Owner ~= nil) and (data.Owner == Game.GetLocalPlayer()) then
				if (data.Yields ~= nil and table.count(data.Yields) > 0) then
					if (RowYields ~= "") then RowYields = RowYields..PUNC_SEPARATOR_SEMICOLON; end
					RowYields = RowYields..Locale.Lookup("LOC_MOD_TOOLTIP_YIELDS_FROM_SPECIALISTS", ParseYields(data.Yields));
				end
			end
			if (RowYields ~= "") then RowYields = ColorText("LOC_MOD_TOOLTIP_YIELDS", Palette.Regular)..PUNC_SPACE_YIELDS..RowYields; end
		end

	-- OTHER TILE
	else
		if (data.ImprovementType ~= nil) then
			-- Barbarian Clan Info
			if (mod_tooltip_isActive_BarbarianClans and data.ImprovementType == "IMPROVEMENT_BARBARIAN_CAMP") then
				local pBarbManager = Game.GetBarbarianManager();
				local iTribeIndex = pBarbManager:GetTribeIndexAtLocation(data.X, data.Y);
				if (iTribeIndex >= 0) then
					local eTribeName = pBarbManager:GetTribeNameType(iTribeIndex);
					if (GameInfo.BarbarianTribeNames[eTribeName] ~= nil) then
						--local tribeNameStr = Locale.Lookup("LOC_TOOLTIP_BARBARIAN_CLAN_NAME", GameInfo.BarbarianTribeNames[eTribeName].TribeDisplayName);
						if (RowOwnership ~= "") then RowOwnership = RowOwnership.."[NEWLINE]"; end
						RowOwnership = RowOwnership..CreateHeading_Color("LOC_MOD_TOOLTIP_CLAN", Palette.WarningLow)..Locale.Lookup(GameInfo.BarbarianTribeNames[eTribeName].TribeDisplayName);
					end
				end
			end
			if (data.ImprovementType == "IMPROVEMENT_BARBARIAN_CAMP") then
				RowImprovement = CreateHeading_Color("LOC_IMPROVEMENT_NAME", Palette.WarningLow)..Locale.Lookup(GameInfo.Improvements[data.ImprovementType].Name);
			else
				RowImprovement = CreateHeading("LOC_IMPROVEMENT_NAME")..Locale.Lookup(GameInfo.Improvements[data.ImprovementType].Name);
			end
			if (data.ImprovementPillaged) then
				RowImprovement = RowImprovement..PUNC_SPACE..ColorText("LOC_TOOLTIP_PLOT_PILLAGED_TEXT", Palette.WarningHigh);
			end
		end

		if (table.count(data.Yields) > 0) then RowYields = ParseYields(data.Yields) end
		if (ResourceExtraction ~= "")     then
			if (RowYields ~= "") then RowYields = RowYields..PUNC_SEPARATOR_COMMA end
			RowYields = RowYields..ResourceExtraction;
		end
		if (localPlayer ~= nil)           then ParseTourism(); end
		if (RowYields ~= "")              then RowYields = CreateHeading("LOC_MOD_TOOLTIP_YIELDS")..RowYields end

	end

	-- For districts, city center show all building info including Great Works
	-- For wonders, just show Great Work info
	if (data.IsCity or data.WonderType ~= nil or data.DistrictID ~= -1) then
		if (data.WonderType ~= nil) then
			RowBuildings = CreateHeading("LOC_WONDER_NAME")..Locale.Lookup(GameInfo.Buildings[data.WonderType].Name);
			if (data.WonderComplete == false) then RowBuildings = RowBuildings..PUNC_SPACE..Locale.Lookup("LOC_TOOLTIP_PLOT_CONSTRUCTION_TEXT"); end
			if (ResourceExtraction ~= "") then RowYields = ResourceExtraction end
			ParseTourism();
			if (RowYields ~= "") then RowYields = CreateHeading("LOC_MOD_TOOLTIP_YIELDS")..RowYields end
		end

		if (data.BuildingNames ~= nil and table.count(data.BuildingNames) > 0) then
			if (data.WonderType == nil) then RowBuildings = CreateHeading("LOC_MOD_TOOLTIP_BUILDINGS"); end
			local cityBuildings = data.OwnerCity:GetBuildings();
			for i, v in ipairs(data.BuildingNames) do
				--print(i, v);
				--print(GameInfo.Buildings[v]);
				--if (not GameInfo.Buildings[v].InternalOnly) then
					if (data.WonderType == nil) then
						-- Bandit: buildings index begins with 1
						if (i > 1) then RowBuildings = RowBuildings..PUNC_SEPARATOR_COMMA; end
						RowBuildings = RowBuildings..Locale.Lookup(v);
						if (data.BuildingsPillaged[i]) then RowBuildings = RowBuildings..PUNC_SPACE..ColorText("LOC_TOOLTIP_PLOT_PILLAGED_TEXT", Palette.WarningHigh); end
					end
					local iSlots = cityBuildings:GetNumGreatWorkSlots(data.BuildingTypes[i]);
					local greatWorks:string = "";
					local iter = 0;
					-- Bandit: great works in slots index begins with 0
					for j = 0, iSlots - 1, 1 do
						local greatWorkIndex:number = cityBuildings:GetGreatWorkInSlot(data.BuildingTypes[i], j);
						if (greatWorkIndex ~= -1) then
							local greatWorkType:number = cityBuildings:GetGreatWorkTypeFromIndex(greatWorkIndex);
							local greatWorkIcon:string = Locale.Lookup("ICON_"..GameInfo.GreatWorks[greatWorkType].GreatWorkObjectType);
							if (iter == 0) then iter = 1 else greatWorks = greatWorks..PUNC_SEPARATOR_COMMA end
							-- Bandit: the space is essential here, its absence causes wrap issues and sometimes great work icon might overflow the tooltip border
							-- Bandit: non-breaking space doesn't work
							greatWorks = greatWorks..greatWorkIcon.." "..Locale.Lookup(GameInfo.GreatWorks[greatWorkType].Name);
						end
					end
					if (greatWorks ~= "") then RowBuildings = RowBuildings..PUNC_SPACE..Locale.Lookup(PUNC_ROUND_BRACKETS, greatWorks); end
				--end
			end
		end
	end

	RowTerrain = CreateHeading("LOC_MOD_TOOLTIP_TERRAIN");

	if (data.IsLake) then
		RowTerrain = RowTerrain..Locale.Lookup("LOC_TOOLTIP_LAKE");
	elseif (data.TerrainTypeName == "LOC_TERRAIN_COAST_NAME") then
		RowTerrain = RowTerrain..Locale.Lookup("LOC_TOOLTIP_COAST");
	elseif (string.find(data.TerrainType, "_HILLS") ~= nil or string.find(data.TerrainType, "_MOUNTAIN") ~= nil) then
		RowTerrain = RowTerrain..Locale.Lookup(data.TerrainTypeName.."_MOD");
	else
		RowTerrain = RowTerrain..Locale.Lookup(data.TerrainTypeName);
	end

	if (data.FeatureType ~= nil) then
		if (GameInfo.Features[data.FeatureType].NaturalWonder) then
			RowNaturalWonder = CreateHeading("LOC_NATURAL_WONDER_NAME")..Locale.Lookup(GameInfo.Features[data.FeatureType].Name);
			RowNaturalWonderDescription = CreateHeading("LOC_MOD_TOOLTIP_DESCRIPTION")..Locale.Lookup(GameInfo.Features[data.FeatureType].Description);
			if (data.IsVolcano) then RowTerrain = RowTerrain..PUNC_SEPARATOR_COMMA..Locale.Lookup("LOC_FEATURE_VOLCANO_NAME") end
		else
			local szFeatureString = Locale.Lookup(GameInfo.Features[data.FeatureType].Name);
			local addCivicName = GameInfo.Features[data.FeatureType].AddCivic;
			if (localPlayer ~= nil and addCivicName ~= nil) then
				local civicIndex = GameInfo.Civics[addCivicName].Index;
				if (localPlayer:GetCulture():HasCivic(civicIndex)) then
				    local szAdditionalString;
					if (not data.FeatureAdded) then
						szAdditionalString = Locale.Lookup("LOC_TOOLTIP_PLOT_WOODS_OLD_GROWTH");
					else
						szAdditionalString = Locale.Lookup("LOC_TOOLTIP_PLOT_WOODS_SECONDARY");
					end
					szFeatureString = szFeatureString .. PUNC_SPACE .. szAdditionalString;
				end
			end
			RowTerrain = RowTerrain..PUNC_SEPARATOR_COMMA..szFeatureString;
		end
	end

	if (data.IsRiver) then
		RowTerrain = RowTerrain..PUNC_SEPARATOR_COMMA..Locale.Lookup("LOC_TOOLTIP_RIVER");
	end

	if (data.IsNWOfCliff or data.IsWOfCliff or data.IsNEOfCliff) then
		RowTerrain = RowTerrain..PUNC_SEPARATOR_COMMA..Locale.Lookup("LOC_TOOLTIP_CLIFF");
	end

	-- Bandit: Gathering Storm thingies
	if (mod_tooltip_isActive_Expansion2) then

		if (data.IsVolcano) then
			if (data.VolcanoName ~= "") then
				RowNamedArea = CreateHeading_Color("LOC_FEATURE_VOLCANO_NAME", Palette.Land)..data.VolcanoName;
			else
				RowNamedArea = CreateHeading_Color("LOC_FEATURE_VOLCANO_NAME", Palette.Land)..Locale.Lookup("LOC_MOD_VOLCANO_UNNAMED");
			end
			if (data.Erupting) then
				RowNamedArea = RowNamedArea..PUNC_SPACE..Locale.Lookup("LOC_VOLCANO_ERUPTING_STRING");
			elseif (data.Active) then
				RowNamedArea = RowNamedArea..PUNC_SPACE..Locale.Lookup("LOC_VOLCANO_ACTIVE_STRING");
			else
				RowNamedArea = RowNamedArea..PUNC_SPACE..Locale.Lookup("LOC_VOLCANO_INACTIVE_STRING");
			end
		end

		if (data.TerritoryName ~= nil) then

			local TerritoryClass = Territories.GetTerritoryAt(data.Index):GetTerrainClass();
			-- Territory classes:
			-- 0 Grassland
			-- 1 Mountains and Volcanoes regardless of the base terrain
			-- 2 Plains
			-- 3 Desert
			-- 4 Tundra
			-- 5 Snow
			-- 6 water area

			if (TerritoryClass == 1) then
				if (RowNamedArea ~= "") then RowNamedArea = RowNamedArea.."[NEWLINE]"; end
				RowNamedArea = RowNamedArea..CreateHeading_Color("LOC_MOD_TOOLTIP_MOUNTAIN_AREA", Palette.Land)..data.TerritoryName;
			elseif (TerritoryClass == 3) then
				RowNamedArea = RowNamedArea..CreateHeading_Color("LOC_TERRAIN_DESERT_NAME", Palette.Land)..data.TerritoryName;
			elseif (TerritoryClass == 6) then
				RowNamedArea = RowNamedArea..CreateHeading_Color("LOC_MOD_TOOLTIP_WATER_AREA", Palette.Water)..data.TerritoryName;
			else --Bandit: fallback for modded stuff
				RowNamedArea = RowNamedArea..CreateHeading_Color("LOC_MOD_TOOLTIP_LAND_AREA", Palette.Land)..data.TerritoryName;
			end
		end

		if (data.RiverNames) then
			if (RowNamedArea ~= "") then RowNamedArea = RowNamedArea.."[NEWLINE]"; end
			local Rivers = RiverManager.EnumerateRivers(data.Index);
			if (#Rivers > 1) then
				RowNamedArea = RowNamedArea..CreateHeading_Color("LOC_MOD_TOOLTIP_RIVERS", Palette.Water);
			else
				RowNamedArea = RowNamedArea..CreateHeading_Color("LOC_TOOLTIP_RIVER", Palette.Water);
			end
			-- Bandit: the game puts fullwidhth comma in chinese between river names instead of enumerating comma so this is why I made a custom iteration
			for i, v in ipairs(Rivers) do
				if (i > 1) then RowNamedArea = RowNamedArea..PUNC_SEPARATOR_COMMA end
				RowNamedArea = RowNamedArea..Rivers[i].Name;
				--print(i, v);
				--for key, val in pairs(v) do
				--	print(key, val);
				--end
			end
			-- print(RiverManager.IsFlooded(data.Index), RiverManager.GetRiverTypeAtIndex(data.Index));
		end

		if (data.Storm ~= -1) then
			RowDisaster = Locale.Lookup(GameInfo.RandomEvents[data.Storm].Name);
		end

		if (data.Drought ~= -1) then
			if (RowDisaster ~= "") then RowDisaster = RowDisaster..PUNC_SEPARATOR_COMMA; end
			RowDisaster = RowDisaster..Locale.Lookup("LOC_DROUGHT_TOOLTIP_STRING", GameInfo.RandomEvents[data.Drought].Name, data.DroughtTurns);
		end

		if (RowDisaster ~= "") then
			RowDisaster = CreateHeading_Color("LOC_MOD_TOOLTIP_DISASTER", Palette.WarningLow)..RowDisaster;
		end

		if (data.CoastalLowland ~= -1) then
			RowCoastalLowland = CreateHeading("LOC_MOD_TOOLTIP_COASTAL_LOWLAND")..Locale.Lookup("LOC_MOD_TOOLTIP_HEIGHT", data.CoastalLowland+1);
			if (data.Submerged) then
				RowCoastalLowland = RowCoastalLowland..PUNC_SPACE..Locale.Lookup("LOC_COASTAL_LOWLAND_SUBMERGED");
			elseif (data.Flooded) then
				RowCoastalLowland = RowCoastalLowland..PUNC_SPACE..Locale.Lookup("LOC_COASTAL_LOWLAND_FLOODED");
			end
		end
	end

	-- Movement Cost
	if (not data.Impassable) then
		if (data.MovementCost > 0) then
			RowMovementCost = Locale.Lookup("LOC_MOD_TOOLTIP_MOVEMENT_COST", data.MovementCost, Palette.Regular);
		end

		if (data.IsRoute) then
			local routeInfo = GameInfo.Routes[data.RouteType];
			if (routeInfo ~= nil and routeInfo.MovementCost ~= nil and routeInfo.Name ~= nil) then
				if(data.RoutePillaged) then
					-- Bandit: tags order:                                                                                  1_Amount                2_RouteName     3_ColorHeading   4_ColorWarning
					RowMovementCost = RowMovementCost..PUNC_SPACE..Locale.Lookup("LOC_MOD_TOOLTIP_ROUTE_MOVEMENT_PILLAGED", routeInfo.MovementCost, routeInfo.Name, Palette.Regular, Palette.WarningHigh);
				else
					-- Bandit: tags order:                                                                         1_Amount                2_RouteName     3_ColorHeading
					RowMovementCost = RowMovementCost..PUNC_SPACE..Locale.Lookup("LOC_MOD_TOOLTIP_ROUTE_MOVEMENT", routeInfo.MovementCost, routeInfo.Name, Palette.Regular);
				end
			end
		end
	end

	-- Defense Modifier
	if (data.DefenseModifier ~= 0) then
		RowDefenceModifier = CreateHeading("LOC_MOD_TOOLTIP_DEFENSE_MODIFIER")..data.DefenseModifier;
	end

	-- Appeal
	local feature = nil;
	if (data.FeatureType ~= nil) then
		feature = GameInfo.Features[data.FeatureType];
	end
		
	if GameCapabilities.HasCapability("CAPABILITY_LENS_APPEAL") then
		if ((data.FeatureType ~= nil and feature.NaturalWonder) or not data.IsWater) then
			local strAppealDescriptor;
			for row in GameInfo.AppealHousingChanges() do
				local iMinimumValue = row.MinimumValue;
				local szDescription = row.Description;
				if (data.Appeal >= iMinimumValue) then
					strAppealDescriptor = Locale.Lookup(szDescription);
					break;
				end
			end
			if (strAppealDescriptor) then
				RowAppeal = Locale.Lookup("LOC_MOD_TOOLTIP_APPEAL", strAppealDescriptor, data.Appeal, Palette.Regular);
			end
		end
	end

	-- Do not include ('none') continent line unless continent plot. #35955
	if (data.Continent ~= nil) then
		RowContinent = CreateHeading("LOC_MOD_TOOLTIP_CONTINENT")..Locale.Lookup(GameInfo.Continents[data.Continent].Description);
	end

	-- Show number of civilians working here
	if (data.Owner == Game.GetLocalPlayer() and data.Workers > 0) then
		RowWorked = Locale.Lookup("LOC_MOD_TOOLTIP_WORKERS", data.Workers);
	end

	if (data.Fallout > 0) then
		if (mod_tooltip_isActive_BlackDeathScenario) then
			-- Bandit: I did this as a workaround, for some reason localization file was failing to parse with CONTAMINATED tag and I have absolutely no idea why
			-- Issue https://forums.civfanatics.com/threads/error-parsing-xml-file-cant-make-localization-files-work-as-supposed.699775/
			RowContamination = Locale.Lookup("LOC_MOD_TOOLTIP_PLOT_PLAGUE_TEXT", data.Fallout, Palette.WarningHigh);
		else
			RowContamination = Locale.Lookup("LOC_MOD_TOOLTIP_PLOT_CONTAMINATED_TEXT", data.Fallout, Palette.WarningHigh);
		end
	end

	if (mod_tooltip_isActive_PiratesScenario) then
		if (data.TreasureFleetTooltip ~= nil) then
			RowAddition = data.TreasureFleetTooltip;
		end

		if (data.TreasureSearchTooltip ~= nil) then
			if (RowAddition ~= "") then RowAddition = RowAddition.."[NEWLINE]" end
			RowAddition = RowAddition..data.TreasureSearchTooltip;
		end

		if (data.InfamousPirateTooltip ~= nil) then
			if (RowAddition ~= "") then RowAddition = RowAddition.."[NEWLINE]" end
			RowAddition = RowAddition..data.InfamousPirateTooltip;
		end

		if (data.TreasureOwnerTooltip ~= nil)then
			if (RowOwnership ~= "") then RowOwnership = RowOwnership.."[NEWLINE]" end
			RowOwnership = RowOwnership..Locale.Lookup("LOC_MOD_PIRATES_PLOT_TOOLTIP_TREASURE_OWNER", data.TreasureOwnerTooltip, Palette.Regular);
		end
	end

	if (mod_tooltip_isActive_BlackDeathScenario) then
		if (data.Owner == Game.GetLocalPlayer()) then
			local pPlayerConfig = PlayerConfigurations[data.Owner];
			if (pPlayerConfig ~= nil) then
				-- England UA: show Coerced tiles
				if (pPlayerConfig:GetCivilizationTypeName() == RULES.EnglandTypeString) then
					if (data.CoerceTurns ~= nil) then
						RowAddition = Locale.Lookup("LOC_MOD_PLOTINFO_COERCED_TURNS_LABEL", data.CoerceTurns, Palette.WarningLow);
					end
				end
			end
		end
	end

	-- Bandit: I know it would be probably better to put these in table and cycle but here you can just simply select the needed row and put in another order
	if (RowOwnership ~= "") then table.insert(details, RowOwnership); end
	if (RowNationalPark ~= "") then table.insert(details, RowNationalPark); end
	if (RowNaturalWonder ~= "") then table.insert(details, RowNaturalWonder); end
	if (RowDistrict ~= "") then table.insert(details, RowDistrict); end
	if (RowBuildings ~= "") then table.insert(details, RowBuildings); end
	if (RowImprovement ~= "") then table.insert(details, RowImprovement); end
	if (RowResource ~= "") then table.insert(details, RowResource); end
	if (RowTerrain ~= "") then table.insert(details, RowTerrain); end
	if (RowNamedArea ~= "") then table.insert(details, RowNamedArea); end
	if (RowMovementCost ~= "") then table.insert(details, RowMovementCost); end
	if (RowAppeal ~= "") then table.insert(details, RowAppeal); end
	if (RowDefenceModifier ~= "") then table.insert(details, RowDefenceModifier); end
	if (RowContinent ~= "") then table.insert(details, RowContinent); end
	if (RowNaturalWonderDescription ~= "") then table.insert(details, RowNaturalWonderDescription); end
	if (RowYields ~= "") then table.insert(details, RowYields); end
	if (RowWorked ~= "") then table.insert(details, RowWorked); end
	if (RowCoastalLowland ~= "") then table.insert(details, RowCoastalLowland); end
	if (RowDisaster ~= "") then table.insert(details, RowDisaster); end
	if (RowContamination ~= "") then table.insert(details, RowContamination); end
	if (RowAddition ~= "") then table.insert(details, RowAddition); end

	return details;
end

-- ===========================================================================
--	Update the layout based on the view model
-- ===========================================================================
function View(data:table)
	-- Build a string that contains all plot details.
	local details = GetDetails(data);

	-- Add debug information in here:
	local debugInfo = {};
	if m_isShowDebug or m_isWorldBuilder then
		-- Show plot x,y, id and vis count
		local iVisCount = 0;
		if (Game.GetLocalPlayer() ~= -1) then
			local pLocalPlayerVis = PlayerVisibilityManager.GetPlayerVisibility(Game.GetLocalPlayer());
			if (pLocalPlayerVis ~= nil) then
				iVisCount = pLocalPlayerVis:GetLayerValue(VisibilityLayerTypes.TERRAIN, data.X, data.Y);
			end
		end
		if m_isWorldBuilder then
			table.insert(debugInfo, "Hex #"..tostring(data.Index)..PUNC_SPACE..Locale.Lookup(PUNC_ROUND_BRACKETS, tostring(data.X)..","..tostring(data.Y)));
		else
			table.insert(debugInfo, "Debug #"..tostring(data.Index)..PUNC_SPACE..Locale.Lookup(PUNC_ROUND_BRACKETS, tostring(data.X)..","..tostring(data.Y))..", vis:"..tostring(iVisCount));
		end
	end
	
	Controls.PlotDetails:SetText(table.concat(details, "[NEWLINE]"));

	-- If manager object has Aspyr addition, use that for tooltips. (This interface will likely change in the future.)
	if (UIManager["IsGamepadActive"]~=nil and UIManager:IsGamepadActive()) then
		
		-- Since using a gamepad, assume plot tooltip behavior should mimic Forge-wide tooltips.
		local toolTipBehavior:number = Options.GetAppOption("UI", "TooltipBehavior");
		if toolTipBehavior == TooltipBehavior.AlwaysShowing then		
			Controls.TooltipMain:SetPauseTime( 0 );
		elseif toolTipBehavior == TooltipBehavior.ShowAfterDelay then	
			Controls.TooltipMain:SetPauseTime( 2.0 );
		elseif toolTipBehavior == TooltipBehavior.ShowOnButton then
			Controls.TooltipMain:SetPauseTime( 0 );
		end
		
	else
		-- Some conditions, jump past "pause" and show immediately
		if m_isShiftDown or UserConfiguration.GetValue("PlotToolTipFollowsMouse") == 0 then
			Controls.TooltipMain:SetPauseTime( 0 );
		else
			-- Pause time is shorter when using touch.
			local pauseTime = UserConfiguration.GetPlotTooltipDelay() or TIME_DEFAULT_PAUSE;
			Controls.TooltipMain:SetPauseTime( m_isUsingMouse and pauseTime or (pauseTime/3.0) );
		end
	end

	Controls.TooltipMain:SetToBeginning();
	Controls.TooltipMain:Play();	

	-- Resize the background to wrap the content 
	-- local plotName_width :number, plotName_height :number		= Controls.PlotName:GetSizeVal();
	-- local nameHeight :number									= Controls.PlotName:GetSizeY();
	local plotDetails_width :number, plotDetails_height :number = Controls.PlotDetails:GetSizeVal();
	-- local max_width :number = math.max(plotName_width, plotDetails_width);
	local max_width :number = math.max(plotDetails_width);

	if m_isShowDebug or m_isWorldBuilder then
		Controls.DebugTxt:SetText(table.concat(debugInfo, "[NEWLINE]"));
		local debugInfoWidth, debugInfoHeight :number			= Controls.DebugTxt:GetSizeVal();		
		max_width = math.max(max_width, debugInfoWidth);
	end
	
	Controls.InfoStack:CalculateSize();
	local stackHeight = Controls.InfoStack:GetSizeY();
	Controls.PlotInfo:SetSizeVal(max_width + SIZE_WIDTH_MARGIN, stackHeight + SIZE_HEIGHT_PADDING);	
	
	m_ttWidth, m_ttHeight = Controls.InfoStack:GetSizeVal();
	Controls.TooltipMain:SetSizeVal(m_ttWidth, m_ttHeight);
	Controls.TooltipMain:SetHide(false);
end

print("Bandit's tooltip loaded!");
