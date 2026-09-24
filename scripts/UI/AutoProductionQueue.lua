-- ===========================================================================
--  Auto Production Queue - UI Script
--  Hooks events for the Production Build Queue functionality.
-- ===========================================================================

print("=== Auto Production Queue (UI) Loading ===")

include("AutoProductionQueue_Managers")

local function FillEmptyQueues(playerID)
    local player = Players[playerID]
    if player == nil or not player:IsHuman() then
        return
    end

    local hasBorderControlEffects = DoesPlayerHaveBorderControlEffects(
        playerID
    )
    local currentTurn = Game.GetCurrentGameTurn()
    local eras = Game.GetEras()
    local currentEraIndex = eras:GetCurrentEra()
    local currentEraStartTurn = eras:GetCurrentEraStartTurn()
    local isEraStartTurn = currentTurn == currentEraStartTurn
    local cities = player:GetCities()
    for _, city in cities:Members() do
        local obj = CityProductionQueueManager:new(playerID, city:GetID())
        if (
            obj ~= nil and obj:NeedsNewItemToWork()
        ) then
            local paramType, hash, plotID = obj:GetNewItemToWork(
                hasBorderControlEffects, currentEraIndex, isEraStartTurn
            )
            if paramType ~= nil and hash ~= nil then
                AppendItemToQueue(city, hash, paramType, plotID)
                -- If we're adding bread and circuses,
                --      try to add carbon recapture, as well
                if hash == BREAD_AND_CIRCUSES_HASH then
                    if obj.queue:CanProduce(CARBON_RECAPTURE_HASH) then
                        AppendItemToQueue(
                            city, CARBON_RECAPTURE_HASH, PARAM_PROJECT_TYPE
                        )
                    end
                end
            end
        end
    end
end

Events.PlayerTurnActivated.Add(FillEmptyQueues)

local function ReplaceItemsInQueue(playerID)
    local player = Players[playerID]
    if player == nil or not player:IsHuman() then
        return
    end

    local hasBorderControlEffects = DoesPlayerHaveBorderControlEffects(
        playerID
    )
    local eras = Game.GetEras()
    local currentEraIndex = eras:GetCurrentEra()
    local cities = player:GetCities()
    for _, city in cities:Members() do
        local obj = CityProductionQueueManager:new(playerID, city:GetID())
        if obj ~= nil then
            if obj:FirstQueueItemNeedsReplaced(
                hasBorderControlEffects, currentEraIndex
            ) then
                local paramType, hash, plotID = obj:GetNewItemToWork(
                    hasBorderControlEffects, currentEraIndex
                )
                ReplaceIndexInQueue(city, 0, hash, paramType, plotID)
            end

            local paramType, hash = obj:FindItemToPrependQueue()
            if paramType ~= nil and hash ~= nil then
                PrependItemToQueue(city, hash, paramType)
            end
        end
    end
end

LuaEvents.PreTurnEnd.Add(ReplaceItemsInQueue)

function PurchaseMonumentInCapital(playerID, civic)
    if civic ~= FOREIGN_TRADE_INDEX then
        return
    end

    local player = Players[playerID]
    if player == nil or not player:IsHuman() then
        return
    end

    local cities = player:GetCities()
    if cities == nil then
        return
    end

    local city = cities:GetCapitalCity()
    PurchaseMonument(city)
end

Events.CivicCompleted.Add(PurchaseMonumentInCapital)

print("=== Auto Production Queue (UI) Loaded ===")
