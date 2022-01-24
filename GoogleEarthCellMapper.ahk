
SetTitleMatchMode, 2

#if WinActive("- Cellular Coverage and Tower Map - Google Chrome") and (WinExist("Google Earth - Edit Placemark") or WinExist("Google Earth - New Placemark"))
    #!Space::
        
        ClipboardBackup := ClipboardAll
        Clipboard =
        SetTitleMatchMode, 2
        ChromeWindow := WinActive(" - Cellular Coverage and Tower Map - Google Chrome")

        if WinExist("Google Earth - Edit Placemark") {
            WinActivate, Google Earth - Edit Placemark
            ControlClick, x59 y70, Google Earth - Edit Placemark
        } else {
            WinActivate, Google Earth - New Placemark
            ControlClick, x59 y70, Google Earth - New Placemark            
        }
        Sleep, 50
        Send, {Tab}{Tab}^c
        Sleep, 200
        Latitude := Clipboard
        Latitude := StrReplace(Latitude, " ", "")
        Latitude := StrReplace(Latitude, chr(176), "")

        Send, {Tab}^c
        Sleep, 200
        Longitude := Clipboard
        Longitude := StrReplace(Longitude, " ", "")
        Longitude := StrReplace(Longitude, chr(176), "")

        WinActivate, ahk_id %ChromeWindow%
        Send, ^a
        Sleep, 40
        Send, %Latitude%{Tab}%Longitude%{Tab 2}

        Clipboard := ClipboardBackup
        ClipboardBackup =
    return
#If

#IfWinActive Google Earth - Edit Placemark
    ^!c::
        SetTitleMatchMode, 2

        ControlClick, x59 y70, Google Earth - Edit Placemark
        Sleep, 50
        Send, {Tab}{Tab}^c
        Sleep, 200
        Latitude := Clipboard
        Latitude := StrReplace(Latitude, " ", "")
        Latitude := StrReplace(Latitude, chr(176), "")

        Send, {Tab}^c
        Sleep, 200
        Longitude := Clipboard
        Longitude := StrReplace(Longitude, " ", "")
        Longitude := StrReplace(Longitude, chr(176), "")

        Clipboard := Latitude . "," . Longitude

    return
#IfWinActive

#IfWinActive Google Earth - New Placemark
    ^!c::
        SetTitleMatchMode, 2

        ControlClick, x59 y70, Google Earth - New Placemark
        Sleep, 50
        Send, {Tab}{Tab}^c
        Sleep, 200
        Latitude := Clipboard
        Latitude := StrReplace(Latitude, " ", "")
        Latitude := StrReplace(Latitude, chr(176), "")

        Send, {Tab}^c
        Sleep, 200
        Longitude := Clipboard
        Longitude := StrReplace(Longitude, " ", "")
        Longitude := StrReplace(Longitude, chr(176), "")

        Clipboard := Latitude . "," . Longitude

    return
#IfWinActive

#IfWinActive, Google Earth Pro
    NumpadEnter::Enter
#IfWinActive