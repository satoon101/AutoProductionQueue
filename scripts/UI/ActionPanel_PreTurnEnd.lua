print("=== Auto Production Queue (ActionPanel) Loading ===")

include("ActionPanel_Expansion2");

BASE_DoEndTurn = DoEndTurn

function DoEndTurn()
    local playerID = Game.GetLocalPlayer()
    LuaEvents.PreTurnEnd(playerID)
    BASE_DoEndTurn()
end

print("=== Auto Production Queue (ActionPanel) Loaded ===")
