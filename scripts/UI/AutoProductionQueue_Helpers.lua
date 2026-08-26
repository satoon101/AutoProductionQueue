-- ===========================================================================
--  Auto Production Queue - UI Script
--  Provides helpful functions for the Production Build Queue functionality.
-- ===========================================================================

ActivePromotionClassCache = {}
QueuedPromotionClassCache = {}
UnitPromotionClassCounts = {
    ["PROMOTION_CLASS_SIEGE"] = 3,
    ["PROMOTION_CLASS_HEAVY_CAVALRY"] = 32
}

BUILDING_DIRECTIVE_INDEX = 1
DISTRICT_DIRECTIVE_INDEX = 2

WONDER_EXCEPTIONS = {
    ["BUILDING_STONEHENGE"] = 1,
    ["BUILDING_PYRAMIDS"] = 1,
    ["BUILDING_ORACLE"] = 1,
    ["BUILDING_BIG_BEN"] = 1
}

BREAD_AND_CIRCUSES_HASH = GameInfo.Projects["PROJECT_BREAD_AND_CIRCUSES"].Hash
CARBON_RECAPTURE_HASH = GameInfo.Projects["PROJECT_CARBON_RECAPTURE"].Hash
HOLY_SITE_DISTRICT_INDEX = GameInfo.Districts["DISTRICT_HOLY_SITE"].Index

local function ShouldRecommissionReactor(city)
    local projectName = "PROJECT_RECOMMISSION_REACTOR"
    local canRecommission = city:GetBuildQueue():CanProduce(projectName)
    if canRecommission == false then
        return false
    end

    local reactorAge = Game.GetFalloutManager():GetReactorAge(city)
    local turnsToRecommission = city:GetBuildQueue():GetTurnsLeft(projectName)
    if 10 - reactorAge <= turnsToRecommission then
        return true
    end

    return false
end

local function SwapItemsInQueue(city, sourceIndex, destIndex)
    local tParameters = {}
    tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_SWAP
    tParameters[CityOperationTypes.PARAM_QUEUE_SOURCE_LOCATION] = sourceIndex
    tParameters[CityOperationTypes.PARAM_QUEUE_DESTINATION_LOCATION] = destIndex
    CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters)
end

function AppendItemToQueue(city, newItemHash, paramType)
    local tParameters = {}
    tParameters[paramType] = newItemHash
    tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_APPEND
    CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters)
end

local function PrependItemToQueue(city, newItemHash, paramType)
    AppendItemToQueue(city, newItemHash, paramType)
    local queue = city:GetBuildQueue()
    local count = queue:GetSize()
    for i = 0, count - 2 do
        SwapItemsInQueue(city, i, count - 1)
    end
end

local function ReplaceIndexInQueue(city, index, newItemHash, paramType)
    local tParameters = {}
    tParameters[paramType] = newItemHash
    tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_REPLACE_AT
    tParameters[CityOperationTypes.PARAM_QUEUE_DESTINATION_LOCATION] = index
    CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters)
end

local function FindRepairableForCity(city)
    local queue = city:GetBuildQueue()
    local districts = city:GetDistricts()
    local buildings = city:GetBuildings()
    for _, district in districts:Members() do
        local districtBuildings = buildings:GetBuildingsAtLocation(district:GetLocation())
        for _, building in ipairs(districtBuildings) do
            local buildingInfo = GameInfo.Buildings[building]
            if buildings:IsPillaged(buildingInfo.BuildingType) and queue:CanProduce(buildingInfo.Hash) then
                return buildingInfo.Hash, CityOperationTypes.PARAM_BUILDING_TYPE
            end
        end
        local districtInfo = GameInfo.Districts[district:GetType()]
        if district:IsPillaged() and queue:CanProduce(districtInfo.Hash) then
            return districtInfo.Hash, CityOperationTypes.PARAM_DISTRICT_TYPE
        end
    end
    return nil
end

local function DoesFirstItemNeedRemoved(city)
    local eras = Game.GetEras()
    local currentEra = eras:GetCurrentEra()
    local queue = city:GetBuildQueue()
    local item = queue:GetAt(0)
    local info = GameInfo.Buildings[item.BuildingType] or GameInfo.Districts[item.DistrictType]
    if info == nil then
        return false
    end

    local turnsLeft = queue:GetTurnsLeft(info.PrimaryKey)
    if turnsLeft ~= 1 then
        return false
    end

    if item.Directive == BUILDING_DIRECTIVE_INDEX then
        if info.IsWonder == false then
            return false
        end

        local prereq = GameInfo.Technologies[info.PrereqTech] or GameInfo.Civics[info.PrereqCivic]
        local era = GameInfo.Eras[prereq.EraType].Index
        local offset = WONDER_EXCEPTIONS[info.BuildingType] or 2
        if currentEra - offset < era then
            return false
        end

        return true
    end

    if item.Directive == DISTRICT_DIRECTIVE_INDEX and currentEra < 2 then
        if city:GetDistricts():GetDistrict(item.DistrictType):IsPillaged() == true then
            return false
        end
        if info.Index == HOLY_SITE_DISTRICT_INDEX then
            if city:IsCapital() then
                return false
            end

            local wonderName = GetWonderFromCity(
                city:GetOwner(),
                city:GetID()
            )
            if wonderName == "BUILDING_STONEHENGE" then
                return false
            end
        end

        return true
    end

    return false
end

function CanCityCreateNewDistrict(city)
    local queue = city:GetBuildQueue()
    for district in GameInfo.Districts() do
        if queue:CanProduce(district.DistrictType) then
            local isRestricted = ExposedMembers.CustomDistrictRules.IsDistrictBlocked(
                city:GetOwner(),
                city:GetID(),
                district.DistrictType
            )
            if isRestricted == false then
                return true
            end
        end
    end

    return false
end

local function GetUnitCount(promotionClass)
    local queuedCount = QueuedPromotionClassCache[promotionClass] or 0
    local activeCount = ActivePromotionClassCache[promotionClass] or 0
    return queuedCount + activeCount
end

local function FindBuildUnitForPromotionClass(queue, promotionClass)
    for unitInfo in GameInfo.Units() do
        if unitInfo.PromotionClass == promotionClass then
            if queue:CanProduce(unitInfo.Hash) then
                return unitInfo.Hash
            end
        end
    end
end

function GetNewItemToWork(city, onTurnStart)
    local repairableHash, paramType = FindRepairableForCity(city)
    if repairableHash ~= nil then
        return repairableHash, paramType
    end

    local queue = city:GetBuildQueue()
    if onTurnStart == true then
        local wonderName = GetWonderFromCity(
            city:GetOwner(),
            city:GetID()
        )
        if wonderName ~= nil then
            local canProduce = queue:CanProduce(wonderName)
            local buildingProgress = queue:GetBuildingProgress(wonderName)
            local turnsRemaining = queue:GetTurnsLeft(wonderName)
            if canProduce and buildingProgress > 0 and turnsRemaining > 2 then
                local info = GameInfo.Buildings[wonderName]
                return info.Hash, CityOperationTypes.PARAM_BUILDING_TYPE
            end
        end
        if CanCityCreateNewDistrict(city) == true then
            return nil, nil
        end
    end

    for _, districtType in ipairs({
        "DISTRICT_GOVERNMENT",
        "DISTRICT_DIPLOMATIC_QUARTER",
        "DISTRICT_CITY_CENTER",
        "DISTRICT_COMMERCIAL_HUB",
        "DISTRICT_HARBOR",
        "DISTRICT_HOLY_SITE",
        "DISTRICT_ENTERTAINMENT_COMPLEX",
        "DISTRICT_WATER_ENTERTAINMENT_COMPLEX",
        "DISTRICT_INDUSTRIAL_ZONE",
        "DISTRICT_ENCAMPMENT",
        "DISTRICT_CAMPUS",
        "DISTRICT_THEATER"
    }) do
        for buildingType in ExposedMembers.AutoProductionQueue.YieldBuildingTypeByTier(
            districtType
        ) do
            if queue:CanProduce(buildingType) then
                local info = GameInfo.Buildings[buildingType]
                if ExposedMembers.CustomDistrictRules.IsBuildingBlocked(
                    city:GetOwner(),
                    city:GetID(),
                    info.PrereqDistrict,
                    buildingType,
                    info.IsWonder
                ) == false then
                    return info.Hash, CityOperationTypes.PARAM_BUILDING_TYPE
                end
            end
        end
    end

    for promotionClass, allowedCount in pairs(UnitPromotionClassCounts) do
        local currentCount = GetUnitCount(promotionClass)
        if currentCount < allowedCount then
            local hash = FindBuildUnitForPromotionClass(promotionClass)
            return hash, CityOperationTypes.PARAM_UNIT_TYPE
        end
    end

    if queue:CanProduce(BREAD_AND_CIRCUSES_HASH) then
        return BREAD_AND_CIRCUSES_HASH, CityOperationTypes.PARAM_PROJECT_TYPE
    end

    -- default to builder
    return GameInfo.Units["UNIT_BUILDER"].Hash, CityOperationTypes.PARAM_UNIT_TYPE
end

function ValidateAndAddCarbonRecaptureToQueue(city, newItemHash)
    if newItemHash == BREAD_AND_CIRCUSES_HASH then
        local queue = city:GetBuildQueue()
        local canProduce = queue:CanProduce(CARBON_RECAPTURE_HASH)
        if queue:GetAt(1) == nil and canProduce then
            local paramType = CityOperationTypes.PARAM_PROJECT_TYPE
            AppendItemToQueue(city, CARBON_RECAPTURE_HASH, paramType)
        end
    end
end

function CityQueueManipulation(city)
    if ShouldRecommissionReactor(city) then
        local info = GameInfo.Projects["PROJECT_RECOMMISSION_REACTOR"]
        PrependItemToQueue(city, info.Hash, CityOperationTypes.PARAM_PROJECT_TYPE)
        return
    end
    local hash, paramType = FindRepairableForCity(city)
    if hash ~= nil then
        PrependItemToQueue(city, hash, paramType)
        return
    end
    local needsRemoved = DoesFirstItemNeedRemoved(city)
    if needsRemoved == true then
        local newItemHash, newItemType = GetNewItemToWork(city, false)
        ReplaceIndexInQueue(city, 0, newItemHash, newItemType)
        ValidateAndAddCarbonRecaptureToQueue(city, newItemHash)
    end
end

function GetWonderFromCity(playerID, cityID)
    local city = CityManager.GetCity(playerID, cityID)
    if not city then
        return nil
    end

    local buildings = city:GetBuildings()
    local queue = city:GetBuildQueue()

    for building in GameInfo.Buildings() do
        if building.IsWonder then
            -- Has the Wonder already been built?
            if buildings:HasBuilding(building.Index) then
                return building.BuildingType
            end
            -- Has the Wonder been placed on the map?
            if queue:HasBeenPlaced(building.Index) then
                return building.BuildingType
            end
        end
    end
    -- Store all buildable plots for this city
    local plots = {}
    for _, plot in ipairs(Map.GetNeighborPlots(city:GetX(), city:GetY(), 3)) do
        local key = plot:GetX() .. "," .. plot:GetY()
        plots[key] = true
    end
    local config = PlayerConfigurations[playerID]
    local pins = config:GetMapPins()
    -- Does a pin for a Wonder exist in the city's buildable plots?
    for _, pin in pairs(pins) do
        local key = pin:GetX() .. "," .. pin:GetY()
        if plots[key] then
            local buildingType = pin:GetIconName():gsub("^ICON_", "")
            local info = GameInfo.Buildings[buildingType]
            if info and info.IsWonder then
                return info.BuildingType
            end
        end
    end
end

print("=== Auto Production Queue (ProductionQueue Helpers) Loaded ===")
