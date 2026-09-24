print("=== Auto Production Queue (ActionPanel) Loading ===")

include("ActionPanel_Expansion2");

BASE_DoEndTurn = DoEndTurn

function DoEndTurn(optionalNewBlocker)
    local playerID = Game.GetLocalPlayer()
    LuaEvents.PreTurnEnd(playerID)
    BASE_DoEndTurn(optionalNewBlocker)
end

print("=== Auto Production Queue (ActionPanel) Loaded ===")
