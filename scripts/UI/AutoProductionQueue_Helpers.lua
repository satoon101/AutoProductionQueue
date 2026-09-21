include("AutoProductionQueue_Config")

function DoesPlayerHaveBorderControlEffects(playerID)
    local worldCongress = Game.GetWorldCongress()
    local resolutions = worldCongress:GetResolutions()
    for i, resolution in pairs(resolutions) do
        if (
            type(i) == "number" and
            resolution.Type == BORDER_CONTROL_HASH
            and resolution.ChosenLabel == "A"
            and resolution.Winner == playerID
        ) then
            return true
        end
    end

    return false
end

function GetCoordinateParamsFromPlot(plotID)
    if plotID == nil then
        return {}
    end

    local plot = Map.GetPlotByIndex(plotID)
    return {
        [PARAM_X] = plot:GetX(),
        [PARAM_Y] = plot:GetY(),
    }
end

function GetUnitCountForPromotionClass(playerID, promotionClass)
    local count = 0
    local player = Players[playerID]
    local units = player:GetUnits()
    for _, unit in units:Members() do
        local info = GameInfo.Units[unit:GetType()]
        if info.PromotionClass == promotionClass then
            count = count + 1
        end
    end

    local cities = player:GetCities()
    for _, city in cities:Members() do
        local queue = city:GetBuildQueue()
        local length = queue:GetSize()
        for i = 0, length - 1 do
            local item = queue:GetAt(i)
            local info = GameInfo.Units[item.UnitType]
            if (
                info ~= nil and
                info.PromotionClass == promotionClass
            ) then
                count = count + 1
            end
        end
    end

    return count
end

function HasPrerequisiteCivicOrTech(playerID, row)
    local player = Players[playerID]
    if player == nil or not player:IsHuman() then
        return true
    end

    if row.PrereqCivic then
        local info = GameInfo.Civics[row.PrereqCivic]
        local civics = player:GetCulture()
        return civics:HasCivic(info.Index)
    elseif row.PrereqTech then
        local info = GameInfo.Technologies[row.PrereqTech]
        local techs = player:GetTechs()
        return techs:HasTech(info.Index)
    end

    return true
end

function PurchaseMonument(city)
    local params = {}
    params[PARAM_BUILDING_TYPE] = MONUMENT_HASH
    params[CityCommandTypes.PARAM_YIELD_TYPE] = YIELD_GOLD
    CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, params)
end

function AppendItemToQueue(
    city, newItemHash, paramType, plotID
)
    local params = GetCoordinateParamsFromPlot(plotID)
    params[paramType] = newItemHash
    params[PARAM_INSERT_MODE] = VALUE_APPEND
    CityManager.RequestOperation(city, CityOperationTypes.BUILD, params)
end

function PrependItemToQueue(
    city, newItemHash, paramType, plotID
)
    local params = GetCoordinateParamsFromPlot(plotID)
    params[paramType] = newItemHash
    params[PARAM_INSERT_MODE] = VALUE_PREPEND
    CityManager.RequestOperation(city, CityOperationTypes.BUILD, params)
end

function ReplaceIndexInQueue(
    city, index, newItemHash, paramType, plotID
)
    local params = GetCoordinateParamsFromPlot(plotID)
    params[paramType] = newItemHash
    params[PARAM_INSERT_MODE] = VALUE_REPLACE_AT
    params[PARAM_QUEUE_DESTINATION_LOCATION] = index
    CityManager.RequestOperation(city, CityOperationTypes.BUILD, params)
end

print("=== Auto Production Queue (Helpers) Loaded ===")
