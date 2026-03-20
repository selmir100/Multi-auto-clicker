#NoEnv
#SingleInstance Force
SetBatchLines -1
CoordMode, Mouse, Screen

; ===== STATE =====
positions := []
running := false
capturePending := false

; ===== GUI =====
Gui, Add, Text, x10 y10, Max Positions:
Gui, Add, Edit, vEditMaxPositions x150 y8 w80, 5

Gui, Add, Text, x10 y40, Clicks per Position:
Gui, Add, Edit, vEditClicksPerPosition x150 y38 w80, 3

Gui, Add, Text, x10 y70, Delay Between Clicks (ms):
Gui, Add, Edit, vEditDelayClicks x150 y68 w80, 200

Gui, Add, Text, x10 y100, Delay Between Positions (ms):
Gui, Add, Edit, vEditDelayPositions x150 y98 w80, 500


Gui, Add, Checkbox, vChkSmoothMove x10 y130, Smooth Mouse Movement
Gui, Add, Text, x22 y145 cRed, Warning: may slow down delay between positions


Gui, Add, Text, x10 y160, Click order (top to bottom):
Gui, Add, ListView, vPositionList x10 y180 w390 h180 Grid, Order|X|Y

Gui, Add, Button, vBtnAdd gAddPositionStart x410 y180 w140 h30, Add Position (3s)
Gui, Add, Button, vBtnRemove gRemoveSelected x410 y215 w140 h30, Remove Selected
Gui, Add, Button, vBtnUp gMoveSelectedUp x410 y250 w140 h30, Move Up
Gui, Add, Button, vBtnDown gMoveSelectedDown x410 y285 w140 h30, Move Down
Gui, Add, Button, vBtnClear gClearAllPositions x410 y320 w140 h30, Clear All

Gui, Add, Button, vBtnStart gStartClicking x10 y370 w100 h30, Start (F6)
Gui, Add, Button, vBtnStop gStopClicking x120 y370 w100 h30, Stop (F7)
GuiControl, Disable, BtnStop

Gui, Add, Text, vStatusText x10 y410 w540, Status: Idle

Gui, Show, w560 h450, Smart Auto Clicker
Gosub, RefreshPositionList
return

; ===== HOTKEYS =====
F8::Gosub, AddPositionStart
F6::Gosub, StartClicking
F7::Gosub, StopClicking

; ===== ADD POSITION =====
AddPositionStart:
if (running)
    return

if (capturePending)
{
    GuiControl,, StatusText, Status: Position capture already pending
    return
}

Gui, Submit, NoHide
maxPositions := ToInt(EditMaxPositions, 5)

if (maxPositions < 1)
{
    GuiControl,, StatusText, Status: Max Positions must be at least 1
    SoundBeep, 900, 80
    return
}

if (GetPositionCount() >= maxPositions)
{
    GuiControl,, StatusText, Status: Max Positions reached
    SoundBeep, 1000, 80
    return
}

capturePending := true
GuiControl, Disable, BtnAdd
GuiControl,, StatusText, Status: Move the mouse to the target spot. Capturing in 3 seconds...
SetTimer, CapturePosition, -3000
return

CapturePosition:
capturePending := false
GuiControl, Enable, BtnAdd

if (running)
{
    GuiControl,, StatusText, Status: Cannot save while clicking is running
    return
}

Gui, Submit, NoHide
maxPositions := ToInt(EditMaxPositions, 5)

if (GetPositionCount() >= maxPositions)
{
    GuiControl,, StatusText, Status: Max Positions reached
    SoundBeep, 900, 80
    return
}

MouseGetPos, mx, my
positions.Push({x: mx, y: my})
SoundBeep, 1500, 70
Gosub, RefreshPositionList
GuiControl,, StatusText, % "Status: Saved position " . GetPositionCount() . "/" . maxPositions
return

; ===== REFRESH LIST =====
RefreshPositionList:
Gui, ListView, PositionList
LV_Delete()

count := GetPositionCount()
if (count > 0)
{
    for index, pos in positions
        LV_Add("", index, pos.x, pos.y)
}

LV_ModifyCol(1, 55)
LV_ModifyCol(2, 110)
LV_ModifyCol(3, 110)
return

; ===== REMOVE SELECTED =====
RemoveSelected:
if (running || capturePending)
{
    GuiControl,, StatusText, Status: Stop clicking or wait for capture to finish first
    return
}

Gui, ListView, PositionList
row := LV_GetNext()

if (!row)
{
    GuiControl,, StatusText, Status: Select a position to remove
    return
}

RemovePositionAt(row)
Gosub, RefreshPositionList
GuiControl,, StatusText, % "Status: Removed position " . row
return

; ===== MOVE UP =====
MoveSelectedUp:
if (running || capturePending)
{
    GuiControl,, StatusText, Status: Stop clicking or wait for capture to finish first
    return
}

Gui, ListView, PositionList
row := LV_GetNext()

if (!row)
{
    GuiControl,, StatusText, Status: Select a position to move
    return
}

if (row = 1)
{
    GuiControl,, StatusText, Status: That position is already first
    return
}

SwapPositions(row, row - 1)
Gosub, RefreshPositionList
Gui, ListView, PositionList
LV_Modify(row - 1, "Select Focus Vis")
GuiControl,, StatusText, % "Status: Moved position to order " . (row - 1)
return

; ===== MOVE DOWN =====
MoveSelectedDown:
if (running || capturePending)
{
    GuiControl,, StatusText, Status: Stop clicking or wait for capture to finish first
    return
}

Gui, ListView, PositionList
row := LV_GetNext()
count := GetPositionCount()

if (!row)
{
    GuiControl,, StatusText, Status: Select a position to move
    return
}

if (row = count)
{
    GuiControl,, StatusText, Status: That position is already last
    return
}

SwapPositions(row, row + 1)
Gosub, RefreshPositionList
Gui, ListView, PositionList
LV_Modify(row + 1, "Select Focus Vis")
GuiControl,, StatusText, % "Status: Moved position to order " . (row + 1)
return

; ===== CLEAR ALL =====
ClearAllPositions:
if (running || capturePending)
{
    GuiControl,, StatusText, Status: Stop clicking or wait for capture to finish first
    return
}

positions := []
Gosub, RefreshPositionList
GuiControl,, StatusText, Status: Cleared all positions
SoundBeep, 800, 60
return

; ===== START =====
StartClicking:
if (running)
    return

if (capturePending)
{
    GuiControl,, StatusText, Status: Finish the pending capture first
    return
}

Gui, Submit, NoHide

clicksPerPos := ToInt(EditClicksPerPosition, 3)
delayClicks := ToInt(EditDelayClicks, 200)
delayPositions := ToInt(EditDelayPositions, 500)
smoothSpeed := ChkSmoothMove ? 10 : 0

if (clicksPerPos < 1)
{
    GuiControl,, StatusText, Status: Clicks per Position must be at least 1
    return
}

if (delayClicks < 0)
    delayClicks := 0
if (delayPositions < 0)
    delayPositions := 0

if (GetPositionCount() < 1)
{
    GuiControl,, StatusText, Status: No positions saved
    SoundBeep, 900, 80
    return
}

running := true

GuiControl, Disable, BtnStart
GuiControl, Enable, BtnStop
GuiControl, Disable, BtnAdd
GuiControl, Disable, BtnRemove
GuiControl, Disable, BtnUp
GuiControl, Disable, BtnDown
GuiControl, Disable, BtnClear
GuiControl, Disable, EditMaxPositions
GuiControl, Disable, EditClicksPerPosition
GuiControl, Disable, EditDelayClicks
GuiControl, Disable, EditDelayPositions
GuiControl, Disable, ChkSmoothMove

GuiControl,, StatusText, Status: Running
Gosub, ClickLoop
return

; ===== STOP =====
StopClicking:
running := false
capturePending := false
SetTimer, CapturePosition, Off

GuiControl, Enable, BtnStart
GuiControl, Disable, BtnStop
GuiControl, Enable, BtnAdd
GuiControl, Enable, BtnRemove
GuiControl, Enable, BtnUp
GuiControl, Enable, BtnDown
GuiControl, Enable, BtnClear
GuiControl, Enable, EditMaxPositions
GuiControl, Enable, EditClicksPerPosition
GuiControl, Enable, EditDelayClicks
GuiControl, Enable, EditDelayPositions
GuiControl, Enable, ChkSmoothMove

GuiControl,, StatusText, Status: Stopped
ToolTip
return

; ===== CLICK LOOP =====
ClickLoop:
while (running)
{
    count := GetPositionCount()
    if (count < 1)
        break

    for index, pos in positions
    {
        if (!running)
            break

        MouseMove, pos.x, pos.y, %smoothSpeed%

        Loop, %clicksPerPos%
        {
            if (!running)
                break
            Click
            Sleep, %delayClicks%
        }

        if (!running)
            break

        Sleep, %delayPositions%
    }
}

if (running)
    Gosub, StopClicking
return

; ===== HELPERS =====
GetPositionCount() {
    global positions
    count := positions.MaxIndex()
    if (!count)
        return 0
    return count
}

SwapPositions(indexA, indexB) {
    global positions
    temp := positions[indexA]
    positions[indexA] := positions[indexB]
    positions[indexB] := temp
}

RemovePositionAt(index) {
    global positions
    newPositions := []

    for i, pos in positions
    {
        if (i = index)
            continue
        newPositions.Push({x: pos.x, y: pos.y})
    }

    positions := newPositions
}

ToInt(value, default := 0) {
    if (value is integer)
        return value + 0
    return default
}

GuiClose:
running := false
capturePending := false
SetTimer, CapturePosition, Off
ExitApp