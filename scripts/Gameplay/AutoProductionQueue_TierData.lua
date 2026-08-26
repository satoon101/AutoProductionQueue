
ExposedMembers.AutoProductionQueue = ExposedMembers.AutoProductionQueue or {}

BuildingTypesByTier = {}

function GatherBuildingRelatedData()
    local prereqData = {}
    for building in GameInfo.Buildings() do
        if (
            not building.InternalOnly
            and building.TraitType == nil
            and #building.ReplacesCollection
        ) then
            if prereqData[building.PrereqDistrict] == nil then
                prereqData[building.PrereqDistrict] = {}
            end
            prereqData[building.PrereqDistrict][building.BuildingType] = true
        end
    end
    for row in GameInfo.BuildingPrereqs() do
        local districtType = GameInfo.Buildings[row.Building].PrereqDistrict
        if (
                prereqData[districtType][row.PrereqBuilding] ~= nil and
                prereqData[districtType][row.Building] ~= nil
            ) then
            prereqData[districtType][row.Building] = row.PrereqBuilding
        end
    end
    for districtType, prereqBuildings in pairs(prereqData) do
        BuildingTypesByTier[districtType] = {}
        for buildingType in pairs(prereqBuildings) do
            local tier = 1
            local currentBuildingType = buildingType
            while currentBuildingType do
                currentBuildingType = prereqBuildings[currentBuildingType]
                if currentBuildingType ~= nil and currentBuildingType ~= true then
                    tier = tier + 1
                end
            end

            if BuildingTypesByTier[districtType][tier] == nil then
                BuildingTypesByTier[districtType][tier] = {}
            end
            -- Store the result: BuildingTypesByTier["DISTRICT_CAMPUS"][1] = {"BUILDING_LIBRARY", "BUILDING_SHCOOL"}
            table.insert(BuildingTypesByTier[districtType][tier], buildingType)
        end
    end
end

function YieldBuildingTypeByTier(districtType)
    local tierData = BuildingTypesByTier[districtType]
    if tierData == nil then
        return
    end

    return coroutine.wrap(function()
        local count = #tierData
        for i = 1, count do
            for _, row in ipairs(tierData[i]) do
                coroutine.yield(row)
            end
        end
    end)
end

ExposedMembers.AutoProductionQueue.YieldBuildingTypeByTier = YieldBuildingTypeByTier
