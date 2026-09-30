include("AutoProductionQueue_Helpers")

CityProductionQueueManager = {}
CityProductionQueueManager.__index = CityProductionQueueManager
CityProductionQueueManager.Registry = {}

function CityProductionQueueManager:new(playerID, cityID)
    local city = CityManager.GetCity(playerID, cityID)
    local x1 = city:GetX()
    local y1 = city:GetY()
    local plotID = Map.GetPlot(x1, y1):GetIndex()

    if CityProductionQueueManager.Registry[plotID] then
        return CityProductionQueueManager.Registry[plotID]
    end

    local wonderName = nil
    local wonderInfo = nil
    local eraToComplete = 0
    local config = PlayerConfigurations[playerID]
    if config ~= nil then
        local pins = config:GetMapPins()
        for _, pin in pairs(pins) do
            local iconName = pin:GetIconName():gsub("^ICON_", "")
            local info = GameInfo.Buildings[iconName]
            if (
                (info ~= nil and info.IsWonder)
                or iconName == "DISTRICT_DIPLOMATIC_QUARTER"
            ) then
                local x2 = pin:GetHexX()
                local y2 = pin:GetHexY()
                local distance = Map.GetPlotDistance(x1, y1, x2, y2)
                if distance <= 3 then
                    wonderName = iconName
                    wonderInfo = info
                    break
                end
            end
        end
    end

    -- We only need these prereqs if there is still a map pin
    local prereqDistrict = nil
    local prereqBuildings = nil
    local prereqBuildingHashes = nil
    if wonderName ~= nil and wonderInfo ~= nil then
        prereqDistrict = wonderInfo.AdjacentDistrict
        if (
            prereqDistrict == nil and
            #wonderInfo.PrereqBuildingCollection > 0
        ) then
            local prereqInfo = wonderInfo.PrereqBuildingCollection[1]
            local districtInfo = GameInfo.Districts[prereqInfo.prereqDistrict]
            prereqDistrict = districtInfo.DistrictType
            prereqBuildings = {}
            prereqBuildingHashes = {}
            local function StorePrereqsForBuilding(info)
                if #info.PrereqBuildingCollection > 0 then
                    for i = 1, #info.PrereqBuildingCollection do
                        local newInfo = info.PrereqBuildingCollection[i]
                        prereqBuildingHashes[newInfo.Hash] = true
                        table.insert(prereqBuildings, newInfo.BuildingType)
                        StorePrereqsForBuilding(newInfo)
                    end
                end
            end
            StorePrereqsForBuilding(wonderInfo)
        end
    end

    local districts = city:GetDistricts()
    local buildings = city:GetBuildings()
    local queue = city:GetBuildQueue()
    if wonderName == nil then
        local district = districts:GetDistrict(WONDER_INDEX)
        if district ~= nil then
            local buildingType = nil
            local location = district:GetLocation()
            local buildings2 = buildings:GetBuildingsAtLocation(location)
            local buildings3 = queue:GetConstructionsAtLocation(location)
            if #buildings2 > 0 then
                buildingType = buildings2[1]
            elseif #buildings3 > 0 then
                buildingType = buildings3[1]
            end

            if buildingType ~= nil then
                wonderInfo = GameInfo.Buildings[buildingType]
                wonderName = wonderInfo.BuildingType
            end
        elseif (
            districts:GetDistrict(DIPLOMATIC_QUARTER_DISTRICT_INDEX)
        ) then
            wonderName = "DISTRICT_DIPLOMATIC_QUARTER"
        end
    end

    if wonderInfo ~= nil then
        local eraOffset = (
            WONDER_ERA_OFFSET_EXCEPTIONS[wonderInfo.BuildingType]
            or 2
        )
        local prereq = (
            GameInfo.Civics[wonderInfo.PrereqCivic] or
            GameInfo.Technologies[wonderInfo.PrereqTech]
        )
        if prereq ~= nil then
            local prereqEra = GameInfo.Eras[prereq.EraType].Index
            eraToComplete = prereqEra + eraOffset
        end
    end

    local instance = {
        playerID = playerID,
        plotID = plotID,
        cityID = cityID,
        wonderName = wonderName,
        eraToComplete = eraToComplete,
        city = city,
        queue = queue,
        districts = districts,
        buildings = buildings,
        prereqDistrict = prereqDistrict,
        prereqBuildings = prereqBuildings,
        prereqBuildingHashes = prereqBuildingHashes,
        mapPinPlotsByName = {}
    }

    setmetatable(instance, self)
    CityProductionQueueManager.Registry[plotID] = instance
    return instance
end

function CityProductionQueueManager:RefreshMapPinMapping()
    local config = PlayerConfigurations[self.playerID]
    local pins = config:GetMapPins()
    for _, pin in pairs(pins) do
        local plot = Map.GetPlot(pin:GetHexX(), pin:GetHexY())
        local plotID = plot:GetIndex()
        local city = Cities.GetPlotPurchaseCity(plot)
        if (
            city ~= nil and
            city:GetOwner() == self.playerID
            and city:GetID() == self.cityID
        ) then
            local iconName = pin:GetIconName():gsub("^ICON_", "")
            if self.mapPinPlotsByName[iconName] == nil then
                self.mapPinPlotsByName[iconName] = plotID
            end
        end
    end
end

function CityProductionQueueManager:NeedsNewItemToWork()
    local size = self.queue:GetSize()
    if size > 1 then
        return
    end

    if size == 0 then
        return true
    end

    local item = self.queue:GetAt(0)
    local info = (
        GameInfo.Buildings[item.BuildingType]
        or GameInfo.Districts[item.DistrictType]
        or GameInfo.Projects[item.ProjectType]
        or GameInfo.Units[item.UnitType]
    )
    local turnsLeft = self.queue:GetTurnsLeft(info.Hash)
    if turnsLeft <= 2 then
        return true
    end
    return false
end

function CityProductionQueueManager:FirstQueueItemNeedsReplaced(
    hasBorderControlEffects, currentEraIndex
)
    local size = self.queue:GetSize()
    if size == 0 then
        return false
    end

    local item = self.queue:GetAt(0)
    local info = (
        GameInfo.Buildings[item.BuildingType]
        or GameInfo.Districts[item.DistrictType]
    )
    if info == nil then
        return false
    end

    if currentEraIndex == CLASSICAL_ERA_INDEX then
        -- Stonehenge, Pyramids, and Ancestral Hall should be completed
        --      asap in the Classical era.
        if (
            self.wonderName == "BUILDING_STONEHENGE" or
            self.wonderName == "BUILDING_PYRAMIDS"
        ) then
            local hash = GameInfo.Buildings[self.wonderName].Hash
            if (
                self.queue:CanProduce(hash) and
                self.queue:GetCurrentProductionTypeHash() ~= hash
            ) then
                return true
            end
        elseif self.wonderName == "BUILDING_CASA_DE_CONTRATACION" then
            if (
                self.queue:CanProduce(GOV_WIDE_HASH) and
                self.queue:GetCurrentProductionTypeHash() ~= GOV_WIDE_HASH
            ) then
                return true
            end
        end
    end

    -- TODO: this needs testing when an example of a wonder
    --      with 2 turns left is built the following turn.
    if self.queue:GetTurnsLeft(info.Hash) > 1 then
        return false
    end

    if item.DistrictType ~= nil and not hasBorderControlEffects then
        if (
            item.DistrictType == HOLY_SITE_DISTRICT_INDEX
            and (
                self.city:IsCapital() or
                self.wonderName == "BUILDING_STONEHENGE"
            )
        ) then
            return false
        end

        return true
    end

    if item.BuildingType ~= nil and info.IsWonder then
        if self.eraToComplete > currentEraIndex then
            return true
        end
    end

    return false
end

function CityProductionQueueManager:FindItemToPrependQueue()
    -- reactor
    if self:ShouldReactorBeRecommissioned() then
        return PARAM_PROJECT_TYPE, RECOMMISSION_REACTOR_HASH
    end

    -- repair
    local paramType, hash = self:FindRepairable()
    if paramType ~= nil and hash ~= nil then
        return paramType, hash
    end

    -- builder
    if (
        self.mapPinPlotsByName["UNIT_BUILDER"] ~= nil and
        self.mapPinPlotsByName["UNIT_BUILDER"] == self.plotID
    ) then
        return PARAM_UNIT_TYPE, BUILDER_HASH
    end

    return nil, nil
end

function CityProductionQueueManager:CanProduceDistrict(districtType)
    if districtType == "DISTRICT_HARBOR" then
        local plotID = self.mapPinPlotsByName[districtType]
        local x1 = self.city:GetX()
        local y1 = self.city:GetY()
        local plot = Map.GetPlotByIndex(plotID)
        local x2 = plot:GetX()
        local y2 = plot:GetY()
        local distance = Map.GetPlotDistance(x1, y1, x2, y2)
        if (
            distance > 1 and
            not self.districts:HasDistrict(COMMERCIAL_HUB_DISTRICT_INDEX)
        ) then
            return false
        end
    end

    if districtType == "DISTRICT_ENCAMPMENT" then
        return self.districts:HasDistrict(HOLY_SITE_DISTRICT_INDEX)
    end

    return true
end

function CityProductionQueueManager:GetNewItemToWork(
    hasBorderControlEffects, currentEraIndex, newHash
)
    -- first turn of the classical era
    if currentEraIndex == CLASSICAL_ERA_INDEX then
        if (
            self.wonderName == "BUILDING_STONEHENGE" or
            self.wonderName == "BUILDING_PYRAMIDS"
        ) then
            local hash = GameInfo.Buildings[self.wonderName].Hash
            if (
                hash ~= newHash and
                self.queue:CanProduce(hash) and
                self.queue:GetCurrentProductionTypeHash() ~= hash
            ) then
                return PARAM_BUILDING_TYPE, hash
            end
        elseif self.wonderName == "BUILDING_CASA_DE_CONTRATACION" then
            if (
                newHash ~= GOV_WIDE_HASH and
                self.queue:CanProduce(GOV_WIDE_HASH) and
                self.queue:GetCurrentProductionTypeHash() ~= GOV_WIDE_HASH
            ) then
                return PARAM_BUILDING_TYPE, GOV_WIDE_HASH
            end
        end
    end

    -- repair
    local paramType, hash = self:FindRepairable(newHash)
    if paramType ~= nil and hash ~= nil then
        return paramType, hash
    end

    self:RefreshMapPinMapping()

    -- district for wonder
    if self:CanBuildDistrictForWonder(newHash) then
        local info = GameInfo.Districts[self.prereqDistrict]
        local plotID = self.mapPinPlotsByName[self.prereqDistrict]
        return PARAM_DISTRICT_TYPE, info.Hash, plotID
    end

    -- building for wonder
    hash = self:GetBuildingToBuildForWonder(newHash)
    if hash ~= nil then
        return PARAM_BUILDING_TYPE, hash
    end

    -- wonder
    if self:CanBuildWonder(newHash) then
        local info = GameInfo.Buildings[self.wonderName]
        local plotID = self.mapPinPlotsByName[self.wonderName]
        return PARAM_BUILDING_TYPE, info.Hash, plotID
    end

    -- finish district
    if hasBorderControlEffects then
        local districtType = self:GetFinishDistrictBuild(newHash)
        if districtType ~= nil then
            local info = GameInfo.Districts[districtType]
            return PARAM_DISTRICT_TYPE, info.Hash
        end
    end

    -- finish wonder
    if self:CanFinishWonder(currentEraIndex, newHash) then
        return PARAM_BUILDING_TYPE, GameInfo.Buildings[self.wonderName].Hash
    end

    -- new district
    local districtType = self:GetBuildNewDistrictType(newHash)
    if districtType ~= nil then
        local info = GameInfo.Districts[districtType]
        local plotID = self.mapPinPlotsByName[districtType]
        return PARAM_DISTRICT_TYPE, info.Hash, plotID
    end

    -- new building
    local buildingType = self:GetBuildNewBuildingType(newHash)
    if buildingType ~= nil then
        local info = GameInfo.Buildings[buildingType]
        return PARAM_BUILDING_TYPE, info.Hash
    end

    -- siege
    hash = self:GetUnitToBuild("PROMOTION_CLASS_SIEGE", newHash)
    if hash ~= nil then
        return PARAM_UNIT_TYPE, hash
    end

    -- heavy cavalry
    hash = self:GetUnitToBuild("PROMOTION_CLASS_HEAVY_CAVALRY", newHash)
    if hash ~= nil then
        return PARAM_UNIT_TYPE, hash
    end

    -- bread and circuses
    if (
        newHash ~= BREAD_AND_CIRCUSES_HASH and
        self.queue:CanProduce(BREAD_AND_CIRCUSES_HASH)
    ) then
        return PARAM_PROJECT_TYPE, BREAD_AND_CIRCUSES_HASH
    end

    --  or builder
    return PARAM_UNIT_TYPE, BUILDER_HASH
end

function CityProductionQueueManager:ShouldReactorBeRecommissioned()
    local canRecommission = self.queue:CanProduce(RECOMMISSION_REACTOR_HASH)
    if not canRecommission then
        return false
    end

    local reactorAge = Game.GetFalloutManager():GetReactorAge(self.city)
    local turnsToRecommission = self.queue:GetTurnsLeft(
        RECOMMISSION_REACTOR_HASH
    )
    if 10 - reactorAge <= turnsToRecommission then
        return true
    end

    return false
end

function CityProductionQueueManager:FindRepairable(newHash)
    for _, district in self.districts:Members() do
        local location = district:GetLocation()
        local districtBuildings = self.buildings:GetBuildingsAtLocation(
            location
        )
        for _, building in ipairs(districtBuildings) do
            local info = GameInfo.Buildings[building]
            if (
                info.Hash ~= newHash and
                self.buildings:IsPillaged(info.BuildingType)
                and self.queue:CanProduce(info.Hash)
            ) then
                return PARAM_BUILDING_TYPE, info.Hash
            end
        end

        local info = GameInfo.Districts[district:GetType()]
        if (
            info.Hash ~= newHash and
            district:IsPillaged() and
            self.queue:CanProduce(info.Hash)
        ) then
            return PARAM_DISTRICT_TYPE, info.Hash
        end
    end
end

function CityProductionQueueManager:HasBuilderMapPin(newHash)
    return (
        newHash ~= BUILDER_HASH and
        self.mapPinPlotsByName["UNIT_BUILDER"] ~= nil
    )
end

function CityProductionQueueManager:CanBuildDistrictForWonder(newHash)
    if self.prereqDistrict == nil then
        return false
    end

    local info = GameInfo.Districts[self.prereqDistrict]
    if info.Hash == newHash then
        return false
    end

    local districtType = info.DistrictType
    if not HasPrerequisiteCivicOrTech(self.playerID, info) then
        return false
    end

    return self.mapPinPlotsByName[districtType] ~= nil
end

function CityProductionQueueManager:GetBuildingToBuildForWonder(newHash)
    if self.prereqBuildings == nil or #self.prereqBuildings == 0 then
        return nil
    end

    if self.prereqBuildingHashes[newHash] ~= nil then
        return nil
    end

    for i = 1, #self.prereqBuildings do
        local building = self.prereqBuildings[i]
        local info = GameInfo.Buildings[building]
        if (
            info.Hash ~= newHash and
            self.queue:CanProduce(info.Hash)
        ) then
            if not ExposedMembers.ProductionPanel.IsBuildingBlocked(
                self.playerID, self.cityID, info.prereqDistrict,
                building, false
            ) then
                if HasPrerequisiteCivicOrTech(self.playerID, info) then
                    return info.Hash
                end
            end
        end
    end

    return nil
end

function CityProductionQueueManager:CanFinishWonder(currentEraIndex, newHash)
    local wonderInfo = GameInfo.Buildings[self.wonderName]
    if (
        wonderInfo ~= nil and
        wonderInfo.Hash ~= newHash
    ) then
        local district = self.districts:GetDistrict(WONDER_INDEX)
        if district ~= nil then
            local location = district:GetLocation()
            local buildings = self.queue:GetConstructionsAtLocation(location)
            if (
                #buildings > 0 and
                self.eraToComplete <= currentEraIndex
            ) then
                wonderInfo = GameInfo.Buildings[buildings[1]]
                return true
            end
        end
    end

    return false
end

function CityProductionQueueManager:CanBuildWonder(newHash)
    local plotID = self.mapPinPlotsByName[self.wonderName]
    if plotID == nil then
        return false
    end

    local city = Cities.GetPlotPurchaseCity(plotID)
    if (
        city == nil or
        city:GetOwner() ~= self.playerID
        or city:GetID() ~= self.cityID
    ) then
        return false
    end

    local row = GameInfo.Buildings[self.wonderName]
    if row.Hash == newHash then
        return
    end

    local hasPrereq = HasPrerequisiteCivicOrTech(self.playerID, row)
    if not hasPrereq then
        return false
    end

    return self.queue:CanProduce(row.Hash)
end

function CityProductionQueueManager:GetFinishDistrictBuild(newHash)
    for _, district in self.districts:Members() do
        if not district:IsComplete() then
            local districtType = district:GetType()
            local info = GameInfo.Districts[districtType]
            if info.Hash ~= newHash then
                return districtType
            end
        end
    end

    return nil
end

function CityProductionQueueManager:GetBuildNewDistrictType(newHash)
    for i = 1, #DistrictBuildOrder do
        local districtType = DistrictBuildOrder[i]
        local info = GameInfo.Districts[districtType]
        local plotID = self.mapPinPlotsByName[districtType]
        if plotID ~= nil then
            local plot = Map.GetPlotByIndex(plotID)
            local city = Cities.GetPlotPurchaseCity(plot)
            if (
                city ~= nil and
                city:GetOwner() == self.playerID
                and city:GetID() == self.cityID
            ) then
                if (
                    info.Hash ~= newHash and
                    self.queue:CanProduce(info.Hash) and
                    self:CanProduceDistrict(districtType) and
                    not ExposedMembers.ProductionPanel.IsDistrictBlocked(
                        self.playerID, self.cityID, districtType
                    )
                ) then
                    if HasPrerequisiteCivicOrTech(self.playerID, info) then
                        return districtType
                    end
                end
            end
        end
    end

    return nil
end

function CityProductionQueueManager:GetBuildNewBuildingType(newHash)
    for i = 1, #DistrictBuildOrder do
        local districtType = DistrictBuildOrder[i]
        local info = GameInfo.Districts[districtType]
        if #info.BuildingCollectionReference > 0 then
            for n = 1, #info.BuildingCollectionReference do
                local row = info.BuildingCollectionReference[n]
                if (
                    row.Hash ~= newHash and
                    not row.InternalOnly and
                    self.queue:CanProduce(row.Hash) and
                    not ExposedMembers.ProductionPanel.IsBuildingBlocked(
                        self.playerID, self.cityID, districtType,
                        row.BuildingType, false
                    )
                ) then
                    if (
                        row.Hash ~= MONUMENT_HASH and
                        HasPrerequisiteCivicOrTech(self.playerID, row)
                    ) then
                        return row.BuildingType
                    end
                end
            end
        end
    end
end

function CityProductionQueueManager:GetUnitToBuild(promotionClass, newHash)
    local allowedCount = UnitPromotionClassCounts[promotionClass]
    if allowedCount == nil then
        return nil
    end

    local currentCount = GetUnitCountForPromotionClass(
        self.playerID, promotionClass
    )
    if currentCount >= allowedCount then
        return nil
    end

    for row in GameInfo.Units() do
        if (
            row.Hash ~= newHash and
            row.PromotionClass == promotionClass
            and self.queue:CanProduce(row.Hash)
        ) then
            return row.Hash
        end
    end
end

function CityProductionQueueManager:RemoveBuilderMapPin()
    local plotID = self.mapPinPlotsByName["UNIT_BUILDER"]
    if plotID ~= nil and plotID == self.plotID then
        local config = PlayerConfigurations[self.playerID]
        for pinID, pin in pairs(config:GetMapPins()) do
            local x = pin:GetHexX()
            local y = pin:GetHexY()
            local pinPlot = Map.GetPlot(x, y)
            local pinPlotID = pinPlot:GetIndex()
            if pinPlotID == plotID then
                config:DeleteMapPin(pinID)
                Network.BroadcastPlayerInfo()
                LuaEvents.MapPinPopup_OnDelete(
                    self.playerID, pinID, pin:GetIconName(), x, y
                )
            end
        end
    end
end

print("=== Auto Production Queue (Managers) Loaded ===")
