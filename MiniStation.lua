-- =============================================================================
--  MiniStation
--    by SexySteak
-- =============================================================================

require "math"
require "table"
require "unicode"
require "lib/lib_Callback2"
require "lib/lib_ChatLib"
require "lib/lib_Debug"
require "lib/lib_InterfaceOptions"
require "lib/lib_PanelManager"
require "lib/lib_Slash"
require "lib/lib_UserKeybinds"

require "./lib_RedBand"

Debug.EnableLogging(false)


-- =============================================================================
--  Variables
-- =============================================================================

local TERMINAL_FRAME = Component.GetFrame("Terminal_Frame")
local TITLE_TEXT = Component.GetWidget("TitleText")
local CLOSE_BUTTON = Component.GetWidget("Close")
local BODY = Component.GetWidget("Body")

local KEYBINDS_FRAME = Component.GetFrame("Keybinds_Frame")
local KEYBINDS_TITLE_TEXT = Component.GetWidget("Keybinds_TitleText")
local KEYBINDS_CLOSE_BUTTON = Component.GetWidget("Keybinds_Close")
local KEYBINDS_BODY = Component.GetWidget("Keybinds_Body")

local KEYCATCHER = Component.GetWidget("KeyCatch")

local FOSTER_FRAME = Component.GetFrame("FosterFrame")
local FOSTER_BUTTON

local c_ChassisToFrame = {
    -- Assault
    [76164] = "Assault",
    [76133] = "Firecat",
    [76132] = "Tigerclaw",
    -- Biotech
    [75774] = "Biotech",
    [76335] = "Dragonfly",
    [76336] = "Recluse",
    -- Dreadnaught
    [75772] = "Dreadnaught",
    [82360] = "Arsenal",
    [76331] = "Mammoth",
    [76332] = "Rhino",
    -- Engineer
    [75775] = "Engineer",
    [76338] = "Bastion",
    [76337] = "Electron",
    -- Recon
    [75773] = "Recon",
    [76333] = "Nighthawk",
    [76334] = "Raptor"
}
local c_FrameInfo = {
    berzerker = {
        Assault = {id = 1, icon = 231826},
        Firecat = {id = 2, icon = 231670},
        Tigerclaw = {id = 3, icon = 231410}
    },
    medic = {
        Biotech = {id = 1, icon = 231827},
        Dragonfly = {id = 2, icon = 231698},
        Recluse = {id = 3, icon = 231527}
    },
    guardian = {
        Dreadnaught = {id = 1, icon = 231825},
        Arsenal = {id = 2, icon = 231645},
        Mammoth = {id = 3, icon = 231644},
        Rhino = {id = 4, icon = 231425}
    },
    bunker = {
        Engineer = {id = 1, icon = 231824},
        Bastion = {id = 2, icon = 231805},
        Electron = {id = 3, icon = 231694}
    },
    recon = {
        Recon = {id = 1, icon = 231823},
        Nighthawk = {id = 2, icon = 231544},
        Raptor = {id = 3, icon = 231528}
    }
}
local c_KeybindsMax = 16
local c_SystemKeybindGroups = {
    "Combat",
    "Interface",
    "Movement",
    "Social",
    "Vehicle"
}

local d_ActionName

local g_CanSwitch = false
local g_Keybinds = {}
local g_KeybindsEnabled = true
local g_KeybindsOpened = false
local g_KeybindsRestrict = true
local g_LoadoutIDs = {}
local g_Opened = false
local g_UserKeybinds

local w_Groups = {}
local w_KeybindButtons = {}
local w_KeybindGroups = {}


-- =============================================================================
--  Interface Options
-- =============================================================================

function OnOptionChanged(id, value)
    if (id == "DEBUG_ENABLE") then
        Debug.EnableLogging(value)
    elseif (id == "GENERAL_ENABLE") then
        g_KeybindsEnabled = value
        Updatekeybinds()
    elseif (id == "KEYBINDS_RESTRICT") then
        g_KeybindsRestrict = value
    elseif (id == "KEYBINDS_EDIT") then
        PanelManager.CloseActivePanel()
        ToggleKeybindsUI(true)
    end
end

do
    InterfaceOptions.SaveVersion(3)

    InterfaceOptions.AddCheckBox({id = "DEBUG_ENABLE", label = "Debug mode", tooltip = "Prints various debug messages into console while enabled", default = false})
    InterfaceOptions.AddCheckBox({id = "GENERAL_ENABLE", label = "Enable keybinds", default = true})
    InterfaceOptions.AddCheckBox({id = "KEYBINDS_RESTRICT", label = "Restrict keybinds", tooltip = "While enabled, prevents the addon from binding keys already in use by the game", default = true})
    InterfaceOptions.AddButton({id = "KEYBINDS_EDIT", label = "Edit keybinds"})
end


-- =============================================================================
--  Functions
-- =============================================================================

function Notification(message)
    ChatLib.Notification({text = "[MiniStation] " .. tostring(message)})
end

function ToggleUI(showFrame)
    if (showFrame) then
        ToggleKeybindsUI(false)
        TERMINAL_FRAME:Show(true)
        TERMINAL_FRAME:ParamTo("alpha", 1, 0.2)
        TITLE_TEXT:ParamTo("alpha", 1, 0.1, 0.15)
        TERMINAL_FRAME:MoveTo("center-x: 50%; center-y: 50%; width: 300; height: 504", 0.2, 0, "ease-in")
        Callback2.FireAndForget(CreateButtons, nil, 0.2)
        Component.SetInputMode("cursor")
    else
        TITLE_TEXT:ParamTo("alpha", 0, 0.1)
        TERMINAL_FRAME:MoveTo("center-x: 50%; center-y: 50%; width: 1; height: 1", 0.1)
        TERMINAL_FRAME:ParamTo("alpha", 0, 0.1)
        TERMINAL_FRAME:Hide(true, 0.1)
        FreeButtons()
        Component.SetInputMode(nil)
        Component.GenerateEvent("MY_BATTLEFRAME_TERMINAL", {show = false})
    end

    g_Opened = showFrame
end

function CreateButtons()
    local Archtypes = {}
    local Loadouts = {}

    for k, frame in ipairs(Player.GetLoadoutList()) do
        local info = Game.GetItemInfoByType(frame.item_types.chassis)
        if (Loadouts[frame.archtype] == nil) then
            table.insert(Archtypes, {name = frame.archtype})
            Loadouts[frame.archtype] = {}
        end
        Debug.Table("loadoutInfo", {name = info.name, icon = info.web_icon})
        table.insert(Loadouts[frame.archtype], {id = tonumber(frame.id), sdb_id = frame.item_types.chassis, name = info.name, web_icon = info.web_icon_id})
    end
    table.sort(Archtypes, function(a, b) return a.name < b.name end)
    Debug.Table("Archtypes", Archtypes)

    local MyLoadoutId = tonumber(Player.GetCurrentLoadoutId())
    local all_unlocks = Game.GetProgressionUnlocks()

    local Progression = Player.GetAllProgressionXp()
    local maxLevel = #all_unlocks

    local Height = 12
    for i = 1, #Archtypes do
        local GROUP = Component.CreateWidget("FramesGroup", BODY)
        GROUP:SetDims("left: 12; right: 100%-12; top: " .. Height .. "; height: 78")
        Height = Height + 90
        GROUP:GetChild("Archtype"):SetTextKey(unicode.upper(Archtypes[i].name))
        table.insert(w_Groups, GROUP)

        local TOOLTIP = GROUP:GetChild("tooltip")
        local BUTTONS_LIST = GROUP:GetChild("Buttons")

        local Left = 0
        table.sort(Loadouts[Archtypes[i].name], function(a, b) return (a.id < b.id) end)
        for j = 1, #(Loadouts[Archtypes[i].name]) do
            local BUTTON = Component.CreateWidget("Button", BUTTONS_LIST)
            BUTTON:SetDims("left: ".. Left .. "; width: 48; center-y: 50%; height: 48")
            Left = Left + 60

            BUTTON:GetChild("icon"):SetIcon(Loadouts[Archtypes[i].name][j].web_icon)

            local level = 1
            local elite = 0

            for k = 1, #Progression do
                if (tostring(Progression[k].sdb_id) == tostring(Loadouts[Archtypes[i].name][j].sdb_id)) then
                    level = Progression[k].level
                    elite = Progression[k].elite_level
                    break
                end
            end
            BUTTON:GetChild("level"):SetText(level)
            if (level == 1) then BUTTON:GetChild("level"):SetTextColor("FFFFFF")
            elseif (level == 40) then BUTTON:GetChild("level"):SetTextColor("00FF00")
            else BUTTON:GetChild("level"):SetTextColor("FFC000") end

            local BOX = BUTTON:GetChild("box")
            if (Loadouts[Archtypes[i].name][j].id == MyLoadoutId) then
                BUTTON:GetChild("border"):SetParam("tint", "2277AA")
                BUTTON:GetChild("plate"):SetParam("tint", "2277AA")
                BUTTON:GetChild("fade"):SetParam("tint", "002244")
                BOX:BindEvent("OnMouseUp", function() OnClose() end)
            else
                local BORDER = BUTTON:GetChild("border")
                local PLATE = BUTTON:GetChild("plate")
                local FADE = BUTTON:GetChild("fade")
                local name = GetFrameName(Loadouts[Archtypes[i].name][j].name)
                BOX:BindEvent("OnMouseEnter", function()
                    BORDER:ParamTo("tint", "C07822", 0.15)
                    PLATE:ParamTo("tint", "C07822", 0.1)
                    FADE:ParamTo("tint", "402000", 0.1)
                    if (name ~= "Accord") then
                        if (elite > 0) then
                            TOOLTIP:SetText(name .. " (ER " .. tostring(elite) .. ")")
                        else
                            TOOLTIP:SetText(name)
                        end

                        TOOLTIP:ParamTo("alpha", 1, 0.15)
                    end
                end)
                BOX:BindEvent("OnMouseLeave", function()
                    BORDER:ParamTo("tint", "50575D", 0.1)
                    PLATE:ParamTo("tint", "50575D", 0.1)
                    FADE:ParamTo("tint", "1C2023", 0.1)
                    TOOLTIP:ParamTo("alpha", 0, 0.15)
                end)
                BOX:BindEvent("OnMouseUp", function() Player.EquipLoadout(Loadouts[Archtypes[i].name][j].id) OnClose() end)
            end
        end
    end

    TERMINAL_FRAME:MoveTo("height: " .. (Height + 48), 0.1, 0, "ease-in")
end

-- Accord if Accord
-- if there are quotation marks, grab the name inside
-- else just grab the last word
function GetFrameName(chassis_name)
    return (unicode.match(chassis_name, "Accord") or unicode.match(chassis_name, "\"(.*)\"") or unicode.match(chassis_name, "([^ ]*)$"))
end

function FreeButtons()
    for k, v in pairs(w_Groups) do
        Component.RemoveWidget(v)
        table.remove(w_Groups, k)
    end
end

function OnClose()
    ToggleUI(false)
end

function CreateKeybindButtons()
    local Archtypes = {}
    local Loadouts = {}

    for archetype, frames in pairs(c_FrameInfo) do
        if (Loadouts[archetype] == nil) then
            table.insert(Archtypes, {name = archetype})
            Loadouts[archetype] = {}
        end

        for name, info in pairs(frames) do
            table.insert(Loadouts[archetype], {id = info.id, name = name, web_icon = info.icon})
        end
    end

    table.sort(Archtypes, function(a, b) return a.name < b.name end)

    local Height = 12

    for i = 1, #Archtypes do
        local GROUP = Component.CreateWidget("FramesGroup", KEYBINDS_BODY)
        GROUP:SetDims("left: 12; right: 100%-12; top: " .. Height .. "; height: 78")
        Height = Height + 90
        GROUP:GetChild("Archtype"):SetTextKey(unicode.upper(Archtypes[i].name))
        table.insert(w_KeybindGroups, GROUP)

        local TOOLTIP = GROUP:GetChild("tooltip")
        local BUTTONS_LIST = GROUP:GetChild("Buttons")
        local Left = 0

        table.sort(Loadouts[Archtypes[i].name], function(a, b) return (a.id < b.id) end)

        for j = 1, #(Loadouts[Archtypes[i].name]) do
            local BUTTON = Component.CreateWidget("Button", BUTTONS_LIST)
            BUTTON:SetDims("left: ".. Left .. "; width: 48; center-y: 50%; height: 48")
            Left = Left + 60

            BUTTON:GetChild("icon"):SetIcon(Loadouts[Archtypes[i].name][j].web_icon)
            BUTTON:GetChild("level"):SetText("")

            local BOX = BUTTON:GetChild("box")
            local BORDER = BUTTON:GetChild("border")
            local PLATE = BUTTON:GetChild("plate")
            local FADE = BUTTON:GetChild("fade")
            local name = Loadouts[Archtypes[i].name][j].name

            if (not g_LoadoutIDs[name]) then
                BORDER:ParamTo("alpha", 0.1, 0.1)
                PLATE:ParamTo("alpha", 0.1, 0.1)
                FADE:ParamTo("alpha", 0.1, 0.1)
            end

            if (g_Keybinds[name]) then
                local keycodeString = tostring(System.GetKeycodeString(g_Keybinds[name]))
                Debug.Log("keycodeString", keycodeString)

                -- if the keycode string is > 5 characters, cut it off
                if (unicode.len(keycodeString) > 5) then
                    BUTTON:GetChild("level"):SetText(unicode.sub(keycodeString, 1, 5) .. "...")
                else
                    BUTTON:GetChild("level"):SetText(keycodeString)
                end
            end

            BOX:BindEvent("OnMouseEnter", function()
                BORDER:ParamTo("tint", "C07822", 0.15)
                PLATE:ParamTo("tint", "C07822", 0.1)
                FADE:ParamTo("tint", "402000", 0.1)
                TOOLTIP:SetText(name)
                TOOLTIP:ParamTo("alpha", 1, 0.15)
            end)

            BOX:BindEvent("OnMouseLeave", function()
                BORDER:ParamTo("tint", "50575D", 0.1)
                PLATE:ParamTo("tint", "50575D", 0.1)
                FADE:ParamTo("tint", "1C2023", 0.1)
                TOOLTIP:ParamTo("alpha", 0, 0.15)
            end)

            w_KeybindButtons[name] = BUTTON

            BOX:SetTag(name)
            BOX:BindEvent("OnMouseDown", ProcessBind)
        end
    end

    KEYBINDS_FRAME:MoveTo("height: " .. (Height + 48), 0.1, 0, "ease-in")
end

function FreeKeybindButtons()
    for k, v in pairs(w_KeybindGroups) do
        Component.RemoveWidget(v)
        table.remove(w_KeybindGroups, k)
    end

    w_KeybindButtons = {}
end

function ToggleKeybindsUI(showFrame)
    if (showFrame) then
        ToggleUI(false)
        KEYBINDS_FRAME:Show(true)
        KEYBINDS_FRAME:ParamTo("alpha", 1, 0.2)
        KEYBINDS_TITLE_TEXT:ParamTo("alpha", 1, 0.1, 0.15)
        KEYBINDS_FRAME:MoveTo("center-x: 50%; center-y: 50%; width: 300; height: 504", 0.2, 0, "ease-in")
        Callback2.FireAndForget(CreateKeybindButtons, nil, 0.2)
        RedBand.GenericMessage("Click on a frame icon and press a key to set a keybinding", 3)
        Component.SetInputMode("cursor")
    else
        TITLE_TEXT:ParamTo("alpha", 0, 0.1)
        KEYBINDS_FRAME:MoveTo("center-x: 50%; center-y: 50%; width: 1; height: 1", 0.1)
        KEYBINDS_FRAME:ParamTo("alpha", 0, 0.1)
        KEYBINDS_FRAME:Hide(true, 0.1)
        FreeKeybindButtons()
        Component.SetInputMode(nil)
    end

    g_KeybindsOpened = showFrame
end

function UpdateLoadoutList()
    local loadoutList = Player.GetLoadoutList()

    g_LoadoutIDs = {}

    for _, loadout in pairs(loadoutList) do
        if (loadout.items and loadout.items.chassis and c_ChassisToFrame[tonumber(loadout.items.chassis)]) then
            local frame = c_ChassisToFrame[tonumber(loadout.items.chassis)]
            Debug.Table("loadoutInfo", {chassis = loadout.items.chassis, name = frame})
            g_LoadoutIDs[frame] = loadout.id
        end
    end

    Debug.Table("g_LoadoutIDs", g_LoadoutIDs)
end

function SwitchFrame(args)
    Debug.Table("SwitchFrame()", args)
    local frame = false

    -- don't try to switch if we have no terminal authorization
    if (not g_CanSwitch) then
        return
    end

    -- grab the frame name of the action
    if (args and args.name) then
        frame = unicode.match(args.name, "^MiniStation_Keybind_(%a+)$")
    end

    -- if the action has a valid frame name, hide the UI and switch to that frame
    if (frame and g_LoadoutIDs[frame]) then
        PanelManager.CloseActivePanel()
        OnClose()

        -- only switch if we're not already using that loadout
        if (not (g_LoadoutIDs[frame] == Player.GetCurrentLoadoutId())) then
            Player.EquipLoadout(g_LoadoutIDs[frame])
        end
    end
end

function Updatekeybinds()
    Debug.Table("Updatekeybinds()", g_Keybinds)

    -- remove keybinds from all actions
    for _, frame in pairs(c_ChassisToFrame) do
        g_UserKeybinds:BindKey("MiniStation_Keybind_"  .. frame, nil)
    end

    -- apply stored keybinds from g_Keybinds to all actions, if addon is enabled
    if (g_KeybindsEnabled) then
        for frame, keycode in pairs (g_Keybinds) do
            g_UserKeybinds:BindKey("MiniStation_Keybind_"  .. frame, keycode)
        end
    end

    -- create a keytable for the debug message
    local keyTable = {}

    for action, indices in pairs(g_UserKeybinds:ExportKeybinds()) do
        for index, key in pairs(indices) do
            if (key ~= 0) then
                keyTable[action .. " index:" .. index] = key
            end
        end
    end

    Debug.Table("keyTable", keyTable)
end

-- straight copied from CalldownHotkeys and then modified a bit - thanks Obama
function GetAllBindings()
    local keyTable = {}

    for _, group in pairs(c_SystemKeybindGroups) do
        local useTable = System.GetKeyBindings(group, false)

        for k in pairs(useTable) do
            for v in pairs(useTable[k]) do
                if (useTable[k][v].keycode ~= 0) then
                    keyTable[k .. " index:" .. v] = useTable[k][v].keycode
                end
            end
        end
    end

    for action, indices in pairs(g_UserKeybinds:ExportKeybinds()) do
        for index, key in pairs(indices) do
            if (key ~= 0) then
                keyTable[action .. " index:" .. index] = key
            end
        end
    end

    keyTable["Escape"] = 27
    keyTable["PrintScrn"] = 44

    Debug.Table("keyTable", keyTable)

    return keyTable
end

-- straight copied from CalldownHotkeys and then modified a bit - thanks Obama
function CanBindKey(keyCode)
    local restrictedKeys = GetAllBindings()

    if (g_KeybindsRestrict) then
        for k in pairs(restrictedKeys) do
            if (tostring(keyCode) == tostring(restrictedKeys[k])) then
                RedBand.ErrorMessage("You cannot bind: " .. System.GetKeycodeString(keyCode) .. ", conflict: " .. k, 3)
                return false
            end
        end
    end

    if (tonumber(keyCode) == 256 or tonumber(keyCode) == 257) then
        RedBand.ErrorMessage("LMB and RMB cannot be bound to.", 3)
        return false
    end

    return true
end

function ProcessBind(args)
    Debug.Table("ProcessBind()", args.widget:GetTag())
    RedBand.GenericMessage("Press a key to bind this frame to, or Escape to clear", 3)

    -- set action name for OnKeyCaught() and setup the key catcher
    d_ActionName = args.widget:GetTag()
    KEYCATCHER:BindEvent("OnKeyCatch", OnKeyCaught)
    KEYCATCHER:ListenForKey()
end

function OnSlashCommand(args)
    ToggleKeybindsUI(not g_KeybindsOpened)
end


-- ================================================================
--  UI Events
-- ================================================================

function OnComponentLoad()
    LIB_SLASH.BindCallback({
        slash_list = "ministation, mstation",
        description = "[MiniStation] Toggles the MiniStation keybinds UI",
        func = OnSlashCommand
    })

    -- create a button and foster it into the garage UI because I prefer MiniStation over the Battleframes panel
    FOSTER_BUTTON = Component.CreateWidget('<Group dimensions="left: 6; top: -32; width: 32; height: 26" />', FOSTER_FRAME)
    local BUTTON = Component.CreateWidget('LibButton', FOSTER_BUTTON):GetChild("Button")
    BUTTON:SetText("MiniStation")
    BUTTON:BindEvent("OnSubmit", function()
        PanelManager.CloseActivePanel()
        ToggleUI(true)
    end)
    BUTTON:Autosize("left")
    Component.FosterWidget(FOSTER_BUTTON, "Garage:main.{1}")
    FOSTER_BUTTON:Show(false)

    PanelManager.RegisterFrame(TERMINAL_FRAME, ToggleUI, false)
    TERMINAL_FRAME:SetDims("center-x: 50%; center-y: 50%; width: 1; height: 1")
    TERMINAL_FRAME:SetParam("alpha", 0)

    local X = CLOSE_BUTTON:GetChild("X")
    CLOSE_BUTTON:BindEvent("OnMouseEnter", function() X:ParamTo("exposure", 1, 0.15) end)
    CLOSE_BUTTON:BindEvent("OnMouseLeave", function() X:ParamTo("exposure", 0, 0.15) end)


    PanelManager.RegisterFrame(KEYBINDS_FRAME, ToggleKeybindsUI, false)
    KEYBINDS_FRAME:SetDims("center-x: 50%; center-y: 50%; width: 1; height: 1")
    KEYBINDS_FRAME:SetParam("alpha", 0)

    local KEYBINDS_X = KEYBINDS_CLOSE_BUTTON:GetChild("Keybinds_X")
    KEYBINDS_CLOSE_BUTTON:BindEvent("OnMouseEnter", function() KEYBINDS_X:ParamTo("exposure", 1, 0.15) end)
    KEYBINDS_CLOSE_BUTTON:BindEvent("OnMouseLeave", function() KEYBINDS_X:ParamTo("exposure", 0, 0.15) end)

    g_UserKeybinds = UserKeybinds.Create()

    -- create all keybind actions for the battleframes
    for _, name in pairs(c_ChassisToFrame) do
        g_UserKeybinds:RegisterAction("MiniStation_Keybind_" .. name, SwitchFrame)
    end

    if (Component.GetSetting("g_Keybinds")) then
        g_Keybinds = Component.GetSetting("g_Keybinds")
    end

    Updatekeybinds()
    InterfaceOptions.SetCallbackFunc(OnOptionChanged)
end

function OnLoadoutsChanged()
    UpdateLoadoutList()
end

function OnPlayerReady()
    UpdateLoadoutList()
end

function OnTerminalAuthorized(args)
    FOSTER_BUTTON:Show(false)
    g_CanSwitch = false

    if (args.terminal_type == "LOADOUT_SELECTOR") then
        g_CanSwitch = true
        Component.GenerateEvent("MY_BATTLEFRAME_TERMINAL", {show = false})
        ToggleUI(true)
    elseif (args.terminal_type == "GARAGE") then
        g_CanSwitch = true
        FOSTER_BUTTON:Show(true)
        ToggleKeybindsUI(false)
    elseif (g_Opened) then
        OnClose()
    end
end

function OnEscape()
    OnClose()
end

function OnEscapeKeybinds()
    ToggleKeybindsUI(false)
end

function OnKeyCaught(args)
    Debug.Table("OnKeyCaught()", args)

    if (args and args.widget and d_ActionName) then
        args.widget:StopListening()
        local keyCode = tonumber(args.widget:GetKeyCode())
        Debug.Log("keyCode", keyCode)

        if (keyCode == 27) then
            Debug.Log("Clearing hotkey for", d_ActionName)
            RedBand.GenericMessage("Clearing keybind for " .. d_ActionName, 3)
            g_Keybinds[d_ActionName] = nil
        elseif (not CanBindKey(keyCode)) then
            Debug.Warn("CanBindKey() returned false")
        else
            Debug.Table("Setting hotkey for", {name = d_ActionName, key = keyCode})
            RedBand.GenericMessage("Keybind for " .. d_ActionName .. " set to " .. System.GetKeycodeString(keyCode), 3)
            g_Keybinds[d_ActionName] = keyCode

            -- remove previous bindings of the key
            for frame, key in pairs(g_Keybinds) do
                if (frame ~= d_ActionName and key == keyCode) then
                    Debug.Log("Removing", key, frame)
                    g_Keybinds[frame] = nil
                end
            end
        end

        -- update all buttons texts
        for frame, BUTTON in pairs(w_KeybindButtons) do
            if (g_Keybinds[frame]) then
                local keycodeString = tostring(System.GetKeycodeString(g_Keybinds[frame]))
                Debug.Log("keycodeString", keycodeString)

                -- if the keycode string is > 5 characters, cut it off
                if (unicode.len(keycodeString) > 5) then
                    BUTTON:GetChild("level"):SetText(unicode.sub(keycodeString, 1, 5) .. "...")
                else
                    BUTTON:GetChild("level"):SetText(keycodeString)
                end
            else
                BUTTON:GetChild("level"):SetText("")
            end
        end
    end

    d_ActionName = nil

    Updatekeybinds()
    Component.SaveSetting("g_Keybinds", g_Keybinds)
end
