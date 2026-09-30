-- ===========================================================================
--  Auto Production Queue - UI Script
--  Hooks events for the Production Build Queue functionality.
-- ===========================================================================

print("=== Auto Production Queue (UI) Loading ===")

include("AutoProductionQueue_Managers")

function UpdateItemsInQueue(playerID)
    if playerID == nil then
        playerID = Game.GetLocalPlayer()
    end

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
            local hash = nil
            if obj:FirstQueueItemNeedsReplaced(
                hasBorderControlEffects, currentEraIndex
            ) then
                local paramType, replaceHash, plotID = obj:GetNewItemToWork(
                    hasBorderControlEffects, currentEraIndex
                )
                hash = replaceHash
                ReplaceIndexInQueue(city, 0, replaceHash, paramType, plotID)
            end
            if obj:NeedsNewItemToWork() then
                local paramType, newHash, plotID = obj:GetNewItemToWork(
                    hasBorderControlEffects, currentEraIndex, hash
                )
                AppendItemToQueue(city, newHash, paramType, plotID)
            end
        end
        local paramType, hash = obj:FindItemToPrependQueue()
        if paramType ~= nil and hash ~= nil then
            PrependItemToQueue(city, hash, paramType)
            if hash == BUILDER_HASH then
                obj:RemoveBuilderMapPin()
            end
        end
    end
end

function OnPreTurnEnd(playerID)
    if not IsFirstTurnOfNewEra() then
        return
    end

    UpdateItemsInQueue(playerID)
end

LuaEvents.PreTurnEnd.Add(OnPreTurnEnd)

function OnPlayerTurnActivated(playerID)
    if IsFirstTurnOfNewEra() then
        return
    end

    UpdateItemsInQueue(playerID)
end

Events.PlayerTurnActivated.Add(OnPlayerTurnActivated)

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
