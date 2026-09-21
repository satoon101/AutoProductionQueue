include("AutoProductionQueue_Constants")

UnitPromotionClassCounts = {
    PROMOTION_CLASS_SIEGE = 3,
    PROMOTION_CLASS_HEAVY_CAVALRY = 32
}

-- set to the number of eras to offset from
--      discovery era to when it should be completed
-- The default for this is 2, so only add if that should be different
-- Example:
--      Stonehenge is discovered in the Ancient Era
--      By default, it would be completed in the Medieval Era
--      By setting it to 1, it will be completed in the Classical Era
WONDER_ERA_OFFSET_EXCEPTIONS = {
    BUILDING_STONEHENGE = 1,
    BUILDING_PYRAMIDS = 1,
    BUILDING_ORACLE = 1,
    BUILDING_BIG_BEN = 1
}

DistrictBuildOrder = {
    "DISTRICT_DAM",
    "DISTRICT_GOVERNMENT",
    "DISTRICT_DIPLOMATIC_QUARTER",
    "DISTRICT_ENCAMPMENT",
    "DISTRICT_HOLY_SITE",
    "DISTRICT_HARBOR",
    "DISTRICT_COMMERCIAL_HUB",
    "DISTRICT_CITY_CENTER",
    "DISTRICT_ENTERTAINMENT_COMPLEX",
    "DISTRICT_WATER_ENTERTAINMENT_COMPLEX",
    "DISTRICT_INDUSTRIAL_ZONE",
    "DISTRICT_CAMPUS",
    "DISTRICT_THEATER",
}

print("=== Auto Production Queue (Config) Loaded ===")
