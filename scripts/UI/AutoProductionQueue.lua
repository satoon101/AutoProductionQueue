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

            -- Does the first item in the queue need to wait to be finished?
            if obj:FirstQueueItemNeedsReplaced(
                hasBorderControlEffects, currentEraIndex
            ) then

                -- Find a replacement item
                local paramType, replaceHash, plotID = obj:GetNewItemToWork(
                    hasBorderControlEffects, currentEraIndex
                )
                ReplaceIndexInQueue(city, 0, replaceHash, paramType, plotID)
            end

            -- Does a second item need added to the queue?
            -- This is done so that no queue is ever empty
            if obj:NeedsNewItemToWork() then
                local paramType, newHash, plotID = obj:GetNewItemToWork(
                    hasBorderControlEffects, currentEraIndex
                )
                AppendItemToQueue(city, newHash, paramType, plotID)
            end
        end

        -- Is there an item that needs pushed to the front of the queue?
        local paramType, hash = obj:FindItemToPrependQueue(currentEraIndex)
        if paramType ~= nil and hash ~= nil then
            local index = obj:GetItemIndexFromCurrentQueue(hash)

            -- If the item is NOT already in the queue, prepend it
            if index == nil then
                PrependItemToQueue(city, hash, paramType)

            -- If the item IS already in the queue, make sure it is first
            elseif index > 0 then
                SwapItemsInQueue(city, 0, index)
            end

            -- If we're adding a builder, it is due to the map pin
            --      so we need to remove the pin
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
