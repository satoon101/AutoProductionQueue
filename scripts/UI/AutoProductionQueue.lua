-- ===========================================================================
--  Auto Production Queue - UI Script
--  Hooks events for the Production Build Queue functionality.
-- ===========================================================================

include("AutoProductionQueue_Helpers")

local QUEUE_BUILD_UNIT_TYPE = 0
local ParamTypes = {
    [CityOperationTypes.PARAM_UNIT_TYPE] = "UNIT",
    [CityOperationTypes.PARAM_BUILDING_TYPE] = "BUILDING",
    [CityOperationTypes.PARAM_DISTRICT_TYPE] = "DISTRICT",
    [CityOperationTypes.PARAM_PROJECT_TYPE] = "PROJECT"
}

local function FillEmptyQueues(playerID)
    local player = Players[playerID]
    local cities = player:GetCities()
    for _, city in cities:Members() do
        local queue = city:GetBuildQueue()
        if queue:GetAt(0) == nil then
            print("Getting new item for city " .. Locale.Lookup(city:GetName()) .. " to work.")
            print(queue:GetAt(0), queue:GetAt(1))
            local newItemHash, paramType = GetNewItemToWork(city, true)
            print(newItemHash, ParamTypes[paramType])
            if newItemHash ~= nil then
                AppendItemToQueue(city, newItemHash, paramType)
                ValidateAndAddCarbonRecaptureToQueue(city, newItemHash)
            end
        end
    end
end

Events.PlayerTurnActivated.Add(FillEmptyQueues)

local function ReplaceItemsInQueue(playerID)
    local player = Players[playerID]
    local cities = player:GetCities()

    for _, city in cities:Members() do
        CityQueueManipulation(city)
    end
end

Events.PlayerTurnDeactivated.Add(ReplaceItemsInQueue)

QueuedUnitTypeCacheByCityID = {}

local function CityProductionChanged(playerID, cityID, prodType, prodIndex)
    local player = Players[playerID]
    if player == nil or not player:IsHuman() then
        return
    end

    local previousIndex = QueuedUnitTypeCacheByCityID[cityID]
    if previousIndex ~= nil then
        local previousClass = GameInfo.Units[previousIndex].PromotionClass
        if previousClass ~= nil then
            local count = QueuedPromotionClassCache[previousClass] or 0
            if count > 0 then
                QueuedPromotionClassCache[previousClass] = count - 1
            end
        end
        QueuedUnitTypeCacheByCityID[cityID] = nil
    end

    if prodType == QUEUE_BUILD_UNIT_TYPE then
        QueuedUnitTypeCacheByCityID[cityID] = prodIndex
        local promotionClass = GameInfo.Units[prodIndex].PromotionClass
        if promotionClass ~= nil then
            local count = QueuedPromotionClassCache[promotionClass] or 0
            QueuedPromotionClassCache[promotionClass] = count + 1
        end
    end
end

Events.CityProductionChanged.Add(CityProductionChanged)

local function IncrementActivePromotionClassCount(playerID, cityID, prodType, prodIndex)
    local player = Players[playerID]
    if player == nil or not player:IsHuman() then
        return
    end

    local city = CityManager.GetCity(playerID, cityID)
    local queue = city:GetBuildQueue()
    print("CityProductionCompleted:", Locale.Lookup(city:GetName()), queue:GetAt(0), queue:GetAt(1))
    if prodType == QUEUE_BUILD_UNIT_TYPE then
        local promotionClass = GameInfo.Units[prodIndex].PromotionClass
        if promotionClass ~= nil then
            local count = ActivePromotionClassCache[promotionClass] or 0
            ActivePromotionClassCache[promotionClass] = count + 1
            local count = QueuedPromotionClassCache[promotionClass] or 0
            if count > 0 then
                QueuedPromotionClassCache[promotionClass] = count - 1
            end
        end
    end
    QueuedPromotionClassCache[cityID] = nil
end

Events.CityProductionCompleted.Add(IncrementActivePromotionClassCount)

print("=== Auto Production Queue (ProductionQueue) Loaded ===")
