#SingleInstance force
#Requires AutoHotKey v2

; ==================================
; ON LOAD
; ==================================

global availableKeys := GenerateAllPossibleKeybinds()
global usedKeys := []

global SETTINGS_WINDOW_NAME := "Cubase Available Keybinds - Settings"
global MAIN_WINDOW_NAME := "Cubase Available Keybinds"
global MAIN_WINDOW_WIDTH := 500
global GUI_BACKGROUND_COLOR := "0x474747"
global SELECTED_ROW_BG_COLOR := "0x9fc7ff"
global ini := "cubase_available_keycommands.ini" ; name of .ini file

Init() {
    global
    try {
        FileRead(ini)
    } catch {
        SettingsGUI('', 0, '') ;if no ini file, automatically load settings
    } else {    
        LoadKeyBindXML('', 0, '') ; parse the keybind file
        CreateGui()
    }
}

Init()

CreateGui() {
    global
    myGui := Gui()
    myGui.OnEvent("Close", GuiClose)
    myGui.OnEvent("Escape", GuiClose)
    myGui.SetFont("s14", "Segoe UI")

    Tab := MyGui.Add("Tab3",, ["Available keybinds","Used Keybinds"])
    mainKeyBindsLV := MyGui.Add("ListView", "-0x08 Count2300 -Multi h600 " . "w" . MAIN_WINDOW_WIDTH, ["Keybind", "Length"])
    Tab.UseTab(2)
    usedKeyBindsLV := MyGui.Add("ListView", "-0x08 Count2300 -Multi h600 " . "w" . MAIN_WINDOW_WIDTH, ["Keybind", "Length", "Command"])
    ; add keys to the listview
    for key in availableKeys {
        keyisused := false
        for usedkey in usedKeys {
            if StrLower(key.key) == StrLower(usedkey.key) {
                keyisused := true
            }
        }
        if (!keyisused)
            mainKeyBindsLV.Add(, key.key, Format("{:03}",key.length))
    }
    for key in usedKeys {
        usedKeyBindsLV.Add(, key.key, Format("{:03}",StrLen(key.key)), key.command)
    }

    mainKeyBindsLV.ModifyCol(2, "Sort")
    mainKeyBindsLV.ModifyCol(1, 300)
    mainKeyBindsLV.ModifyCol(2, 0)

    usedKeyBindsLV.ModifyCol()
    usedKeyBindsLV.ModifyCol(2, "Sort")
    usedKeyBindsLV.ModifyCol(2, 0)

    myGui.Title := MAIN_WINDOW_NAME
    isGuiCreated := true
    myGui.Show("Center")

}

; CLOSE FUNCTION
GuiClose(*) {
    global
    MyGui.Hide()
    ExitApp
}

GenerateAllPossibleKeybinds() {
    ; Define base keys
    baseKeys := StrSplit("ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-=[];'\,.")
    baseKeys.Push(StrSplit("F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,F11,F12,Insert,Home,End,Del,Return,Enter,Space,Pad0,Pad1,Pad2,Pad3,Pad4,Pad5,Pad6,Pad7,Pad8,Pad9,Pad *,Pad -,Pad +,Pad /,Left Arrow,Right Arrow,Up Arrow,Down Arrow,Backspace", ",")*)

    ; Define modifiers
    modifiers := ["Ctrl", "Alt", "Shift", "Ctrl+Shift", "Ctrl+Alt", "Alt+Shift", "Ctrl+Alt+Shift"]

    ; Generate all key combinations
    result := []
    for key in baseKeys {
        result.Push({key: key, length: StrLen(key)}) ; Add base key
        for mod in modifiers {
            combo := mod . "+" . key
            result.Push({key: combo, length: StrLen(combo)}) ; Add modified key
        }
    }

    return result
}

LoadKeybindXML(*) {
    global
    keyCommandsXmlPath := IniRead('cubase_available_keycommands.ini', "keycommands_path", "key", "-1")

    if (keyCommandsXmlPath = "-1") {
        MsgBox('No path selected, please check settings or the .ini file')
        ExitApp
    }

    try {
        KeyCommandsXmlData := FileRead(keyCommandsXmlPath)
    } catch {
        MsgBox('Cannot find Key Commands.Xml, please check settings or the .ini file')
        ExitApp
    }
    
    doc := loadXML(KeyCommandsXmlData)
    nodesPerCategory := doc.SelectNodes("//KeyCommands/list[@name='Categories']/item")

    ; PARSE KEY COMMMANDS XML DATA
    for categoryNode in nodesPerCategory {
        nodes := categoryNode.selectNodes(".//item[string[@name='Name'] and not(list)]")
        category := categoryNode.selectSingleNode("string[@name='Name']").getAttribute("value")

        for node in nodes {
            nameNode := node.selectSingleNode("string[@name='Name']").getAttribute("value")
            keyNode := node.selectSingleNode("string[@name='Key']")
            local key := " "
            if (keyNode) {
                key := keyNode.getAttribute("value")
                usedKeys.Push({key: key, command: category . " > " . nameNode})
            }


        }
    }

}

LoadXML(data) {
    o := ComObject("msxml2.DOMDocument.6.0") ; may need to be 3.0 depending on the XML
    o.async := False
    o.LoadXML(data)
    if o.parseError.errorCode {
        MsgBox "Unable to load XML data"
            . "`nError: " . o.parseError.errorCode
            . "`nReason: " . o.parseError.reason
            , "XML Load Error"
            , 16
        ExitApp
    }
    return o
}

; ADD TRAY MENU ITEM FOR SELECTING DEFAULT HOTKEY
A_TrayMenu.Add()  ; Creates a separator line.
A_TrayMenu.Add("Settings", SettingsGUI)  ; Creates a new menu item.
Persistent
;JumpBarSettingsGui('', 0, '') ; debugging, loads settings onload

SettingsGUI(ItemName, ItemPos, MyMenu) {
    global

    settings := {
        xmlFilePath: IniRead(ini, "keycommands_path", "key", "Path to your Key Commands.xml"),
    }

    sGui := Gui() ; CREATE THE MAIN SETTINGS GUI

    ; KEYCOMMANDS.XML FILE SELECT
    sGui.Add("GroupBox", "w600 h50 x10 y+20", "Select the location of your KeyCommands.xml: ")
    fileSelectBtn := sGui.Add("Button", "-Default w80 xp+10 yp+20", "Select File")
    fileSelectBtn.OnEvent("Click", selectXMLfile)
    xmlPathText := sGui.Add("Text","vpathText w500 YP YP+5", settings.xmlFilePath)
    xmlPathText.SetFont("italic", )

    ; SAVE BUTTON
    sGui.Add("Button", "default xp-10 y+30", "Save Settings").OnEvent("Click", processSettings)

    sGui.Title := SETTINGS_WINDOW_NAME
    sGui.OnEvent("Close", settingsGuiClose)
    sGui.Show("H350")
}

settingsGuiClose(*) {
    unsavedSettings := settings.xmlFilePath == xmlPathText.Text
    if (!unsavedSettings) {
        if (MsgBox("You have unsaved changes, are you sure you want to close the GUI?", "", "y/n") == "No")
            return true  ; true = 1
    }
}

processSettings(*) {
    IniWrite(xmlPathText.Text, ini, "keycommands_path", "key")
    MsgBox("Settings saved to " . ini)
    sGui.Hide()
    Init()
}

selectXMLfile(*) {
    global
    selectedFile := FileSelect(3, "%\AppData\Roaming\Steinberg\Cubase13_64\", "Select your Cubase Keybinds", "XML Source File (*.xml)")
    if selectedFile = ""
        return
    SplitPath(selectedFile, &name)
    if (name == "Key Commands.xml") {
        xmlPathText.Text := selectedFile
    } else {
        result := MsgBox("Incorrect file selected: " . name, "Invalid file", "RetryCancel")
        if (result == "Retry") {
            selectXMLfile()
        }
        else
            return
    }

}