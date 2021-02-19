local function PopulateSBXToolMenu(pnl)
    pnl:CheckBox("Enabled", "fedhoria_enabled")
    pnl:ControlHelp("Enable or disable the addon.")

    pnl:CheckBox("Players", "fedhoria_players")
    pnl:ControlHelp("Enable or disable effect for players.")

    pnl:CheckBox("NPCs", "fedhoria_npcs")
    pnl:ControlHelp("Enable or disable effect for NPCs.")
end

if engine.ActiveGamemode() == "sandbox" then
    hook.Add("AddToolMenuCategories", "FedhoriaCategory", function() 
        spawnmenu.AddToolCategory("Utilities", "Fedhoria", "Fedhoria")
    end)

    hook.Add("PopulateToolMenu", "FedhoriaMenuSettings", function() 
        spawnmenu.AddToolMenuOption("Utilities", "Fedhoria", "FedhoriaSettings", "Settings", "", "", function(pnl)
            pnl:ClearControls()
            PopulateSBXToolMenu(pnl)
        end)
    end)
end