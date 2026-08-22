-- NexusOS UI

local UI = {}

UI.windows = {}
UI.nextID = 1
UI.focused = nil
UI.startMenu = false

local function screen()
    return term.native()
end

--------------------------------------------------
-- Desktop
--------------------------------------------------

function UI.draw()
    local t = screen()
    local w, h = t.getSize()

    -- Desktop
    t.setBackgroundColor(colors.blue)
    t.setTextColor(colors.white)
    t.clear()

    -- Windows
    for _, win in ipairs(UI.windows) do
        if win.visible and not win.minimized then
            UI.drawWindow(win)
        end
    end

    UI.drawTaskbar()

    if UI.startMenu then
        UI.drawStartMenu()
    end
end

--------------------------------------------------
-- Window
--------------------------------------------------

function UI.createWindow(title, x, y, width, height)
    local t = screen()

    local win = {
        id = UI.nextID,
        title = title or "Window",
        x = x or 2,
        y = y or 2,
        width = width or 30,
        height = height or 15,
        visible = true,
        minimized = false,
        focused = false,
        dragging = false,
        dragX = 0,
        dragY = 0
    }

    UI.nextID = UI.nextID + 1

    win.terminal = window.create(
        t,
        win.x + 1,
        win.y + 2,
        win.width - 2,
        win.height - 3,
        true
    )

    table.insert(UI.windows, win)
    UI.focus(win)

    return win
end

--------------------------------------------------
-- Focus
--------------------------------------------------

function UI.focus(win)
    if not win then return end

    for i, w in ipairs(UI.windows) do
        if w == win then
            table.remove(UI.windows, i)
            break
        end
    end

    table.insert(UI.windows, win)

    for _, w in ipairs(UI.windows) do
        w.focused = false
    end

    win.focused = true
    UI.focused = win

    UI.draw()
end

--------------------------------------------------
-- Draw window
--------------------------------------------------

function UI.drawWindow(win)
    local t = screen()

    local titleColor =
        win.focused and colors.lightBlue
        or colors.gray

    -- Title bar
    t.setBackgroundColor(titleColor)
    t.setTextColor(colors.white)

    t.setCursorPos(win.x, win.y)
    t.write(string.rep(" ", win.width))

    -- Title
    t.setCursorPos(win.x + 1, win.y)

    local title = win.title

    if #title > win.width - 7 then
        title = title:sub(1, win.width - 7)
    end

    t.write(title)

    -- Minimize
    t.setCursorPos(
        win.x + win.width - 5,
        win.y
    )

    t.write("_")

    -- Close
    t.setBackgroundColor(colors.red)

    t.setCursorPos(
        win.x + win.width - 2,
        win.y
    )

    t.write("X")

    -- Border
    t.setBackgroundColor(colors.black)

    -- Top border under title
    t.setCursorPos(
        win.x,
        win.y + 1
    )

    t.write(
        string.rep("-", win.width)
    )

    -- Sides
    for y = win.y + 2,
        win.y + win.height - 1 do

        t.setCursorPos(win.x, y)
        t.write("|")

        t.setCursorPos(
            win.x + win.width - 1,
            y
        )

        t.write("|")
    end

    -- Bottom
    t.setCursorPos(
        win.x,
        win.y + win.height - 1
    )

    t.write(
        string.rep("-", win.width)
    )
end

--------------------------------------------------
-- Taskbar
--------------------------------------------------

function UI.drawTaskbar()
    local t = screen()
    local w, h = t.getSize()

    t.setBackgroundColor(colors.gray)
    t.setCursorPos(1, h)

    t.write(string.rep(" ", w))

    -- Start button
    t.setBackgroundColor(colors.gray)
    t.setCursorPos(2, h)
    t.write("[ NexusOS ]")

    -- Windows
    local x = 15

    for _, win in ipairs(UI.windows) do
        if win.visible then

            local label =
                "[ " .. win.title .. " ]"

            if x + #label <= w then

                if win.focused then
                    t.setBackgroundColor(
                        colors.lightBlue
                    )
                else
                    t.setBackgroundColor(
                        colors.gray
                    )
                end

                t.setCursorPos(x, h)
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
    local w, h = t.getSize()

    local mw = 22
    local mh = 8

    local x = 2
    local y = h - mh

    t.setBackgroundColor(colors.gray)
    t.setTextColor(colors.white)

    for row = 0, mh - 1 do
        t.setCursorPos(x, y + row)
        t.write(string.rep(" ", mw))
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
-- Mouse
--------------------------------------------------

function UI.mouseClick(button, x, y)

    local t = screen()
    local w, h = t.getSize()

    --------------------------------------------------
    -- Start button
    --------------------------------------------------

    if y == h and x >= 2 and x <= 13 then

        UI.startMenu = not UI.startMenu

        UI.draw()

        return
    end

    --------------------------------------------------
    -- Start menu
    --------------------------------------------------

    if UI.startMenu then

        local menuX = 2
        local menuY = h - 8

        -- Terminal
        if x >= menuX
            and x <= menuX + 22
            and y == menuY + 3 then

            UI.startMenu = false

            if UI.onLaunch then
                UI.onLaunch("terminal")
            end

            UI.draw()
            return
        end

        -- Files
        if y == menuY + 4 then

            UI.startMenu = false

            if UI.onLaunch then
                UI.onLaunch("files")
            end

            UI.draw()
            return
        end

        -- Settings
        if y == menuY + 5 then

            UI.startMenu = false

            if UI.onLaunch then
                UI.onLaunch("settings")
            end

            UI.draw()
            return
        end

        -- Close menu
        if y == menuY + 6 then

            UI.startMenu = false
            UI.draw()

            return
        end
    end

    --------------------------------------------------
    -- Find window
    --------------------------------------------------

    local clicked = nil

    for i = #UI.windows, 1, -1 do

        local win = UI.windows[i]

        if win.visible
            and not win.minimized
            and x >= win.x
            and x < win.x + win.width
            and y >= win.y
            and y < win.y + win.height then

            clicked = win
            break
        end
    end

    if not clicked then
        return
    end

    UI.focus(clicked)

    --------------------------------------------------
    -- Close
    --------------------------------------------------

    if y == clicked.y
        and x == clicked.x + clicked.width - 2 then

        if UI.onClose then
            UI.onClose(clicked)
        end

        return
    end

    --------------------------------------------------
    -- Minimize
    --------------------------------------------------

    if y == clicked.y
        and x >= clicked.x + clicked.width - 5
        and x <= clicked.x + clicked.width - 4 then

        clicked.minimized = true
        clicked.focused = false
        UI.focused = nil

        UI.draw()

        return
    end

    --------------------------------------------------
    -- Drag
    --------------------------------------------------

    if y == clicked.y then

        clicked.dragging = true
        clicked.dragX = x - clicked.x
        clicked.dragY = y - clicked.y

        return
    end
end

--------------------------------------------------
-- Mouse drag
--------------------------------------------------

function UI.mouseDrag(button, x, y)

    local win = UI.focused

    if not win or not win.dragging then
        return
    end

    local t = screen()
    local w, h = t.getSize()

    win.x = x - win.dragX
    win.y = y - win.dragY

    -- Keep on screen
    win.x = math.max(1, win.x)
    win.y = math.max(1, win.y)

    win.x = math.min(
        win.x,
        w - win.width + 1
    )

    win.y = math.min(
        win.y,
        h - win.height
    )

    win.terminal.reposition(
        win.x + 1,
        win.y + 2,
        win.width - 2,
        win.height - 3
    )

    UI.draw()
end

--------------------------------------------------
-- Mouse release
--------------------------------------------------

function UI.mouseUp()
    if UI.focused then
        UI.focused.dragging = false
    end
end

--------------------------------------------------
-- Event handler
--------------------------------------------------

function UI.handleEvent(event, ...)
    if event == "mouse_click" then

        UI.mouseClick(...)

    elseif event == "mouse_drag" then

        UI.mouseDrag(...)

    elseif event == "mouse_up" then

        UI.mouseUp()
    end
end

--------------------------------------------------
-- Initialize
--------------------------------------------------

function UI.init()
    UI.windows = {}
    UI.nextID = 1
    UI.focused = nil
    UI.startMenu = false

    UI.draw()
end

return UI
