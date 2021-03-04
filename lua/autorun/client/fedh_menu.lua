local function PopulateSBXToolMenu(pnl)
    pnl:CheckBox("Enabled", "fedhoria_enabled")
    pnl:ControlHelp("Enable or disable the addon.")

    pnl:CheckBox("Players", "fedhoria_players")
    pnl:ControlHelp("Enable or disable effect for players.")

    pnl:CheckBox("NPCs", "fedhoria_npcs")
    pnl:ControlHelp("Enable or disable effect for NPCs.")

    pnl:NumSlider("Stumble time", "fedhoria_stumble_time", 0, 10, 3)
    pnl:ControlHelp("How long the ragdoll should stumble for.")

    pnl:NumSlider("Die time", "fedhoria_dietime", 0, 10, 3)
    pnl:ControlHelp("How long before the ragdoll dies after drowning/being still for too long.")

    pnl:NumSlider("Wound grab chance", "fedhoria_woundgrab_chance", 0, 1, 3)
    pnl:ControlHelp("The chance the ragdoll will grab it's wound when shot.")

    pnl:NumSlider("Wound grab time", "fedhoria_woundgrab_time", 0, 10, 3)
    pnl:ControlHelp("How long the ragdoll should hold its wound.")
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