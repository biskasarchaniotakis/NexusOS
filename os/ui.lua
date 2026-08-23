-- NexusOS UI
-- Simple stable window manager

local UI = {}

--------------------------------------------------
-- State
--------------------------------------------------

UI.windows = {}
UI.nextID = 1
UI.focused = nil

UI.startMenu = false

UI.activeMode = nil
UI.activeWindow = nil

--------------------------------------------------
-- Colors
--------------------------------------------------

UI.desktopColor = colors.blue
UI.taskbarColor = colors.gray
UI.titleColor = colors.gray
UI.activeTitleColor = colors.lightBlue
UI.closeColor = colors.red

UI.minWidth = 14
UI.minHeight = 7

--------------------------------------------------
-- Native screen
--------------------------------------------------

local function screen()
    return term.native()
end

--------------------------------------------------
-- Safe number
--------------------------------------------------

local function num(value, fallback)
    if type(value) == "number" then
        return value
    end

    return fallback
end

--------------------------------------------------
-- Clamp
--------------------------------------------------

local function clamp(value, low, high)
    value = num(value, low)

    if high < low then
        return low
    end

    if value < low then
        return low
    end

    if value > high then
        return high
    end

    return value
end

--------------------------------------------------
-- Window exists
--------------------------------------------------

local function contains(win)
    if not win then
        return false
    end

    for _, w in ipairs(UI.windows) do
        if w == win then
            return true
        end
    end

    return false
end

--------------------------------------------------
-- Get screen size
--------------------------------------------------

local function getScreenSize()
    local t = screen()

    local w, h = t.getSize()

    w = math.max(1, num(w, 51))
    h = math.max(2, num(h, 19))

    return w, h
end

--------------------------------------------------
-- Resize application terminal
--------------------------------------------------

local function resizeTerminal(win)
    if not win or not win.terminal then
        return
    end

    local cw = math.max(1, win.width - 2)
    local ch = math.max(1, win.height - 3)

    win.terminal.reposition(
        2,
        3,
        cw,
        ch
    )
end

--------------------------------------------------
-- Create window
--------------------------------------------------

function UI.createWindow(
    title,
    x,
    y,
    width,
    height
)

    local sw, sh = getScreenSize()

    width = clamp(
        width or 36,
        UI.minWidth,
        sw
    )

    height = clamp(
        height or 12,
        UI.minHeight,
        math.max(UI.minHeight, sh - 1)
    )

    x = clamp(
        x or 2,
        1,
        math.max(1, sw - width + 1)
    )

    y = clamp(
        y or 2,
        1,
        math.max(1, sh - height)
    )

    --------------------------------------------------
    -- Parent window.
    --
    -- IMPORTANT:
    -- The application owns the inside of this buffer.
    -- The UI only draws the chrome.
    --------------------------------------------------

    local surface = window.create(
        screen(),
        x,
        y,
        width,
        height,
        false
    )

    surface.setBackgroundColor(colors.black)
    surface.setTextColor(colors.white)
    surface.clear()

    local win = {
        id = UI.nextID,

        title = tostring(title or "Window"),

        x = x,
        y = y,

        width = width,
        height = height,

        surface = surface,
        terminal = nil,

        visible = true,
        minimized = false,
        focused = false,

        dragging = false,
        resizing = false,

        dragX = 0,
        dragY = 0
    }

    UI.nextID = UI.nextID + 1

    --------------------------------------------------
    -- Application terminal.
    --
    -- It starts at (2,3) inside the window:
    --
    -- row 1 = title
    -- row 2 = separator
    -- row 3+ = application
    --------------------------------------------------

    win.terminal = window.create(
        surface,
        2,
        3,
        math.max(1, width - 2),
        math.max(1, height - 3),
        true
    )

    win.terminal.setBackgroundColor(colors.black)
    win.terminal.setTextColor(colors.white)
    win.terminal.clear()
    win.terminal.setCursorPos(1, 1)

    table.insert(UI.windows, win)

    UI.drawWindow(win)

    surface.setVisible(true)

    UI.focus(win)

    return win
end

--------------------------------------------------
-- Focus
--------------------------------------------------

function UI.focus(win)
    if not win then
        return
    end

    if not contains(win) then
        return
    end

    if win.minimized then
        return
    end

    --------------------------------------------------
    -- Clear focus.
    --------------------------------------------------

    for _, w in ipairs(UI.windows) do
        w.focused = false
    end

    --------------------------------------------------
    -- Move window to top.
    --------------------------------------------------

    for i, w in ipairs(UI.windows) do
        if w == win then
            table.remove(UI.windows, i)
            break
        end
    end

    table.insert(UI.windows, win)

    win.focused = true

    UI.focused = win

    if win.surface then
        win.surface.setVisible(true)
    end

    UI.draw()
end

UI.setFocus = UI.focus

--------------------------------------------------
-- Restore
--------------------------------------------------

function UI.restoreWindow(win)
    if not win then
        return
    end

    if not contains(win) then
        return
    end

    win.minimized = false
    win.visible = true
    win.dragging = false
    win.resizing = false

    if win.surface then
        win.surface.setVisible(true)
    end

    if win.terminal then
        win.terminal.setVisible(true)
    end

    UI.focus(win)
end

--------------------------------------------------
-- Find window
--------------------------------------------------

function UI.getWindowAt(x, y)
    x = num(x, 0)
    y = num(y, 0)

    for i = #UI.windows, 1, -1 do

        local win = UI.windows[i]

        if win.visible
            and not win.minimized
            and x >= win.x
            and x < win.x + win.width
            and y >= win.y
            and y < win.y + win.height then

            return win
        end
    end

    return nil
end

--------------------------------------------------
-- Desktop
--------------------------------------------------

function UI.drawDesktop()

    local t = screen()

    local width, height = getScreenSize()

    t.setBackgroundColor(UI.desktopColor)
    t.setTextColor(colors.white)

    t.clear()

    --------------------------------------------------
    -- Desktop title
    --------------------------------------------------

    t.setCursorPos(2, 1)

    t.write("NexusOS")
end

--------------------------------------------------
-- Window chrome
--
-- IMPORTANT:
-- We NEVER clear the application area here.
--------------------------------------------------

function UI.drawWindow(win)

    if not win then
        return
    end

    if not win.surface then
        return
    end

    if not win.visible or win.minimized then
        return
    end

    local w = win.surface

    local width = math.max(1, win.width)
    local height = math.max(1, win.height)

    --------------------------------------------------
    -- Title
    --------------------------------------------------

    if win.focused then
        w.setBackgroundColor(UI.activeTitleColor)
    else
        w.setBackgroundColor(UI.titleColor)
    end

    w.setTextColor(colors.white)

    w.setCursorPos(1, 1)
    w.write(string.rep(" ", width))

    --------------------------------------------------
    -- Title text
    --------------------------------------------------

    local title = tostring(win.title or "Window")

    local maxTitle = math.max(
        1,
        width - 10
    )

    if #title > maxTitle then
        title = title:sub(1, maxTitle)
    end

    w.setCursorPos(2, 1)
    w.write(title)

    --------------------------------------------------
    -- Minimize
    --------------------------------------------------

    w.setBackgroundColor(
        win.focused
            and UI.activeTitleColor
            or UI.titleColor
    )

    w.setCursorPos(
        math.max(1, width - 5),
        1
    )

    w.write("_")

    --------------------------------------------------
    -- Close
    --------------------------------------------------

    w.setBackgroundColor(UI.closeColor)

    w.setCursorPos(
        math.max(1, width - 2),
        1
    )

    w.write("X")

    --------------------------------------------------
    -- Separator
    --------------------------------------------------

    if height >= 2 then

        w.setBackgroundColor(colors.black)
        w.setTextColor(colors.white)

        w.setCursorPos(1, 2)

        w.write(
            string.rep("-", width)
        )
    end

    --------------------------------------------------
    -- Left/right borders
    --
    -- Do NOT touch application terminal area
    -- except for the two border columns.
    --------------------------------------------------

    if width >= 2 and height >= 5 then

        for row = 3, height - 2 do

            w.setBackgroundColor(colors.black)

            w.setCursorPos(1, row)
            w.write("|")

            w.setCursorPos(width, row)
            w.write("|")
        end
    end

    --------------------------------------------------
    -- Bottom border
    --------------------------------------------------

    if height >= 3 then

        w.setBackgroundColor(colors.black)

        w.setCursorPos(1, height)

        w.write(
            string.rep("-", width)
        )
    end

    --------------------------------------------------
    -- Resize handle
    --------------------------------------------------

    if width >= 2 and height >= 2 then

        w.setBackgroundColor(colors.gray)
        w.setTextColor(colors.white)

        w.setCursorPos(width, height)

        w.write("+")
    end
end

--------------------------------------------------
-- Taskbar
--------------------------------------------------

function UI.drawTaskbar()

    local t = screen()

    local width, height = getScreenSize()

    t.setBackgroundColor(UI.taskbarColor)
    t.setTextColor(colors.white)

    t.setCursorPos(1, height)

    t.write(
        string.rep(" ", width)
    )

    --------------------------------------------------
    -- Start
    --------------------------------------------------

    t.setBackgroundColor(colors.gray)

    t.setCursorPos(2, height)

    t.write("[ NexusOS ]")

    --------------------------------------------------
    -- Applications
    --------------------------------------------------

    local x = 15

    for _, win in ipairs(UI.windows) do

        if win.visible then

            local label =
                "[ " .. tostring(win.title) .. " ]"

            if x + #label <= width then

                if win.minimized then

                    t.setBackgroundColor(
                        colors.darkGray
                    )

                elseif win.focused then

                    t.setBackgroundColor(
                        colors.lightBlue
                    )

                else

                    t.setBackgroundColor(
                        colors.gray
                    )
                end

                t.setCursorPos(x, height)

                t.write(label)

                x = x + #label + 1
            end
        end
    end
end

--------------------------------------------------
-- Start menu
--------------------------------------------------

function UI.drawStartMenu()

    local t = screen()

    local width, height = getScreenSize()

    local menuWidth = math.min(25, width - 2)
    local menuHeight = 9

    local x = 2

    local y = math.max(
        1,
        height - menuHeight
    )

    t.setBackgroundColor(colors.gray)
    t.setTextColor(colors.white)

    for row = 0, menuHeight - 1 do

        if y + row < height then

            t.setCursorPos(
                x,
                y + row
            )

            t.write(
                string.rep(" ", menuWidth)
            )
        end
    end

    t.setCursorPos(x + 2, y + 1)

    t.setTextColor(colors.yellow)
    t.write("NexusOS")

    t.setTextColor(colors.white)

    t.setCursorPos(x + 2, y + 3)
    t.write("Terminal")

    t.setCursorPos(x + 2, y + 4)
    t.write("Files")

    t.setCursorPos(x + 2, y + 5)
    t.write("Settings")

    t.setCursorPos(x + 2, y + 6)
    t.write("Close Menu")
end

--------------------------------------------------
-- Draw
--------------------------------------------------

function UI.draw()

    local t = screen()

    --------------------------------------------------
    -- Hide application surfaces while desktop
    -- is redrawn.
    --------------------------------------------------

    for _, win in ipairs(UI.windows) do

        if win.surface then
            win.surface.setVisible(false)
        end
    end

    --------------------------------------------------
    -- Desktop
    --------------------------------------------------

    UI.drawDesktop()

    --------------------------------------------------
    -- Window chrome
    --------------------------------------------------

    for _, win in ipairs(UI.windows) do

        if win.visible
            and not win.minimized then

            UI.drawWindow(win)
        end
    end

    --------------------------------------------------
    -- Show windows in correct order.
    --------------------------------------------------

    for _, win in ipairs(UI.windows) do

        if win.visible
            and not win.minimized
            and win.surface then

            win.surface.setVisible(true)
        end
    end

    --------------------------------------------------
    -- Taskbar must be last on native screen.
    --------------------------------------------------

    UI.drawTaskbar()

    if UI.startMenu then
        UI.drawStartMenu()
    end
end

--------------------------------------------------
-- Remove
--------------------------------------------------

function UI.removeWindow(win)

    if not win then
        return
    end

    if not contains(win) then
        return
    end

    win.dragging = false
    win.resizing = false

    if win.surface then
        win.surface.setVisible(false)
    end

    for i, w in ipairs(UI.windows) do

        if w == win then

            table.remove(UI.windows, i)

            break
        end
    end

    if UI.focused == win then
        UI.focused = nil
    end

    --------------------------------------------------
    -- Focus newest remaining window.
    --------------------------------------------------

    for i = #UI.windows, 1, -1 do

        local other = UI.windows[i]

        if other.visible
            and not other.minimized then

            UI.focus(other)

            return
        end
    end

    UI.draw()
end

--------------------------------------------------
-- Minimize
--------------------------------------------------

function UI.minimize(win)

    if not win then
        return
    end

    if not contains(win) then
        return
    end

    win.dragging = false
    win.resizing = false

    win.minimized = true
    win.visible = true
    win.focused = false

    if win.surface then
        win.surface.setVisible(false)
    end

    if UI.focused == win then
        UI.focused = nil
    end

    --------------------------------------------------
    -- Focus another window.
    --------------------------------------------------

    for i = #UI.windows, 1, -1 do

        local other = UI.windows[i]

        if other ~= win
            and other.visible
            and not other.minimized then

            UI.focus(other)

            return
        end
    end

    UI.draw()
end

--------------------------------------------------
-- Taskbar hit
--------------------------------------------------

function UI.getTaskbarWindowAt(x, y)

    local width, height = getScreenSize()

    if y ~= height then
        return nil
    end

    local currentX = 15

    for _, win in ipairs(UI.windows) do

        if win.visible then

            local label =
                "[ " .. tostring(win.title) .. " ]"

            if currentX + #label <= width then

                if x >= currentX
                    and x < currentX + #label then

                    return win
                end

                currentX =
                    currentX + #label + 1
            end
        end
    end

    return nil
end

--------------------------------------------------
-- Start drag
--------------------------------------------------

function UI.startDrag(win, mouseX, mouseY)

    if not win then
        return
    end

    UI.focus(win)

    UI.activeMode = "drag"
    UI.activeWindow = win

    win.dragging = true
    win.resizing = false

    win.dragX = mouseX - win.x
    win.dragY = mouseY - win.y
end

--------------------------------------------------
-- Drag
--------------------------------------------------

function UI.drag(win, mouseX, mouseY)

    if not win then
        return
    end

    if not win.dragging then
        return
    end

    local sw, sh = getScreenSize()

    local newX =
        mouseX - win.dragX

    local newY =
        mouseY - win.dragY

    newX = clamp(
        newX,
        1,
        math.max(1, sw - win.width + 1)
    )

    newY = clamp(
        newY,
        1,
        math.max(1, sh - win.height)
    )

    if newX == win.x and newY == win.y then
        return
    end

    win.x = newX
    win.y = newY

    --------------------------------------------------
    -- Moving the parent moves the application.
    --------------------------------------------------

    if win.surface then

        win.surface.reposition(
            win.x,
            win.y,
            win.width,
            win.height
        )
    end

    UI.draw()
end

--------------------------------------------------
-- Start resize
--------------------------------------------------

function UI.startResize(win)

    if not win then
        return
    end

    UI.focus(win)

    UI.activeMode = "resize"
    UI.activeWindow = win

    win.resizing = true
    win.dragging = false
end

--------------------------------------------------
-- Resize
--------------------------------------------------

function UI.resize(win, mouseX, mouseY)

    if not win then
        return
    end

    if not win.resizing then
        return
    end

    local sw, sh = getScreenSize()

    local newWidth =
        mouseX - win.x + 1

    local newHeight =
        mouseY - win.y + 1

    newWidth = math.max(
        UI.minWidth,
        newWidth
    )

    newHeight = math.max(
        UI.minHeight,
        newHeight
    )

    local maxWidth =
        math.max(1, sw - win.x + 1)

    local maxHeight =
        math.max(1, sh - win.y)

    newWidth =
        math.min(
            newWidth,
            maxWidth
        )

    newHeight =
        math.min(
            newHeight,
            maxHeight
        )

    win.width = newWidth
    win.height = newHeight

    if win.surface then

        win.surface.reposition(
            win.x,
            win.y,
            win.width,
            win.height
        )
    end

    resizeTerminal(win)

    UI.draw()

    if UI.onResize then
        UI.onResize(win)
    end
end

--------------------------------------------------
-- Stop mouse
--------------------------------------------------

function UI.stopMouseOperation()

    local active =
        UI.activeMode ~= nil

    if UI.activeWindow then

        UI.activeWindow.dragging = false
        UI.activeWindow.resizing = false
    end

    UI.activeMode = nil
    UI.activeWindow = nil

    return active
end

--------------------------------------------------
-- Mouse
--------------------------------------------------

function UI.mouseClick(button, x, y)

    local width, height = getScreenSize()

    --------------------------------------------------
    -- Start button
    --------------------------------------------------

    if y == height
        and x >= 2
        and x <= 13 then

        UI.startMenu = not UI.startMenu

        UI.draw()

        return true
    end

    --------------------------------------------------
    -- Taskbar
    --------------------------------------------------

    if y == height then

        local task =
            UI.getTaskbarWindowAt(x, y)

        if task then

            if task.minimized then

                UI.restoreWindow(task)

            elseif UI.focused ~= task then

                UI.focus(task)

            end

            return true
        end
    end

    --------------------------------------------------
    -- Start menu
    --------------------------------------------------

    if UI.startMenu then

        local menuX = 2
        local menuY = math.max(1, height - 9)

        if x >= menuX
            and x <= menuX + 25
            and y == menuY + 3 then

            UI.startMenu = false

            if UI.onLaunch then
                UI.onLaunch("terminal")
            end

            UI.draw()

            return true
        end

        if x >= menuX
            and x <= menuX + 25
            and y == menuY + 4 then

            UI.startMenu = false

            if UI.onLaunch then
                UI.onLaunch("files")
            end

            UI.draw()

            return true
        end

        if x >= menuX
            and x <= menuX + 25
            and y == menuY + 5 then

            UI.startMenu = false

            if UI.onLaunch then
                UI.onLaunch("settings")
            end

            UI.draw()

            return true
        end

        if y == menuY + 6 then

            UI.startMenu = false

            UI.draw()

            return true
        end

        --------------------------------------------------
        -- Don't click through the menu.
        --------------------------------------------------

        if x >= menuX
            and x <= menuX + 25
            and y >= menuY
            and y < height then

            return true
        end
    end

    --------------------------------------------------
    -- Window
    --------------------------------------------------

    local win =
        UI.getWindowAt(x, y)

    if not win then
        return false
    end

    --------------------------------------------------
    -- Focus.
    --------------------------------------------------

    UI.focus(win)

    --------------------------------------------------
    -- Close
    --------------------------------------------------

    if y == win.y
        and x == win.x + win.width - 2 then

        if UI.onClose then
            UI.onClose(win)
        else
            UI.removeWindow(win)
        end

        return true
    end

    --------------------------------------------------
    -- Minimize
    --------------------------------------------------

    if y == win.y
        and x >= win.x + win.width - 5
        and x <= win.x + win.width - 4 then

        UI.minimize(win)

        return true
    end

    --------------------------------------------------
    -- Resize
    --------------------------------------------------

    if x == win.x + win.width - 1
        and y == win.y + win.height - 1 then

        UI.startResize(win)

        return true
    end

    --------------------------------------------------
    -- Title bar
    --------------------------------------------------

    if y == win.y then

        UI.startDrag(
            win,
            x,
            y
        )

        return true
    end

    --------------------------------------------------
    -- Content is for app.
    --------------------------------------------------

    return false
end

--------------------------------------------------
-- Mouse drag
--------------------------------------------------

function UI.mouseDrag(button, x, y)

    if UI.activeMode == "drag"
        and UI.activeWindow then

        UI.drag(
            UI.activeWindow,
            x,
            y
        )

        return true
    end

    if UI.activeMode == "resize"
        and UI.activeWindow then

        UI.resize(
            UI.activeWindow,
            x,
            y
        )

        return true
    end

    return false
end

--------------------------------------------------
-- Mouse up
--------------------------------------------------

function UI.mouseUp()

    return UI.stopMouseOperation()
end

--------------------------------------------------
-- Event handler
--------------------------------------------------

function UI.handleEvent(event, ...)

    if event == "mouse_click" then

        return UI.mouseClick(...)

    elseif event == "mouse_drag" then

        return UI.mouseDrag(...)

    elseif event == "mouse_up" then

        return UI.mouseUp(...)
    end

    return false
end

--------------------------------------------------
-- Redirect
--------------------------------------------------

function UI.redirect(win)

    if not win then
        return false
    end

    if not win.terminal then
        return false
    end

    term.redirect(win.terminal)

    return true
end

--------------------------------------------------
-- Restore native
--------------------------------------------------

function UI.restore()

    term.redirect(
        term.native()
    )
end

--------------------------------------------------
-- Init
--------------------------------------------------

function UI.init()

    UI.windows = {}
    UI.nextID = 1
    UI.focused = nil

    UI.startMenu = false

    UI.activeMode = nil
    UI.activeWindow = nil

    UI.draw()
end

return UI
