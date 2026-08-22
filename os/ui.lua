-- NexusOS UI
-- Window manager + app launcher

local UI = {}

--------------------------------------------------
-- State
--------------------------------------------------

UI.windows = {}
UI.nextID = 1
UI.focused = nil
UI.startMenu = false

--------------------------------------------------
-- Colors
--------------------------------------------------

UI.desktopColor = colors.blue
UI.taskbarColor = colors.gray
UI.titleColor = colors.gray
UI.activeTitleColor = colors.lightBlue
UI.closeColor = colors.red

--------------------------------------------------
-- Screen
--------------------------------------------------

local function screen()
    return term.native()
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

--------------------------------------------------
-- Create window
--------------------------------------------------

function UI.createWindow(title, x, y, width, height)

    local t = screen()

    local sw, sh = t.getSize()

    width = math.max(10, math.min(width or 30, sw))
    height = math.max(5, math.min(height or 15, sh - 1))

    x = math.max(1, math.min(x or 2, sw - width + 1))
    y = math.max(1, math.min(y or 2, sh - height))

    local win = {
        id = UI.nextID,

        title = title or "Window",

        x = x,
        y = y,

        width = width,
        height = height,

        visible = true,
        minimized = false,
        focused = false,

        dragging = false,
        dragX = 0,
        dragY = 0
    }

    UI.nextID = UI.nextID + 1

    --------------------------------------------------
    -- Window terminal
    --------------------------------------------------

    win.terminal = window.create(
        t,
        x + 1,
        y + 2,
        width - 2,
        height - 3,
        true
    )

    win.terminal.setBackgroundColor(colors.black)
    win.terminal.setTextColor(colors.white)
    win.terminal.clear()
    win.terminal.setCursorPos(1, 1)

    table.insert(UI.windows, win)

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

    --------------------------------------------------
    -- Move to top
    --------------------------------------------------

    for i, w in ipairs(UI.windows) do

        if w == win then

            table.remove(UI.windows, i)
            break
        end
    end

    table.insert(UI.windows, win)

    --------------------------------------------------
    -- Update focus
    --------------------------------------------------

    for _, w in ipairs(UI.windows) do
        w.focused = false
    end

    win.focused = true
    win.minimized = false

    UI.focused = win

    UI.draw()
end

--------------------------------------------------
-- Find window
--------------------------------------------------

function UI.getWindowAt(x, y)

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
-- Draw desktop
--------------------------------------------------

function UI.drawDesktop()

    local t = screen()

    local width, height =
        t.getSize()

    t.setBackgroundColor(
        UI.desktopColor
    )

    t.setTextColor(
        colors.white
    )

    t.clear()

    --------------------------------------------------
    -- Desktop fill
    --------------------------------------------------

    for y = 1, height - 1 do

        t.setCursorPos(1, y)

        t.write(
            string.rep(" ", width)
        )
    end
end

--------------------------------------------------
-- Draw window
--------------------------------------------------

function UI.drawWindow(win)

    if not win.visible
        or win.minimized then

        return
    end

    local t = screen()

    --------------------------------------------------
    -- Title bar
    --------------------------------------------------

    if win.focused then

        t.setBackgroundColor(
            UI.activeTitleColor
        )

    else

        t.setBackgroundColor(
            UI.titleColor
        )
    end

    t.setTextColor(colors.white)

    t.setCursorPos(
        win.x,
        win.y
    )

    t.write(
        string.rep(
            " ",
            win.width
        )
    )

    --------------------------------------------------
    -- Title
    --------------------------------------------------

    local title = win.title

    if #title > win.width - 8 then

        title =
            title:sub(
                1,
                win.width - 8
            )
    end

    t.setCursorPos(
        win.x + 1,
        win.y
    )

    t.write(title)

    --------------------------------------------------
    -- Minimize button
    --------------------------------------------------

    t.setBackgroundColor(
        win.focused
        and UI.activeTitleColor
        or UI.titleColor
    )

    t.setCursorPos(
        win.x + win.width - 5,
        win.y
    )

    t.write("_")

    --------------------------------------------------
    -- Close button
    --------------------------------------------------

    t.setBackgroundColor(
        UI.closeColor
    )

    t.setCursorPos(
        win.x + win.width - 2,
        win.y
    )

    t.write("X")

    --------------------------------------------------
    -- Border
    --------------------------------------------------

    t.setBackgroundColor(
        colors.black
    )

    t.setTextColor(
        colors.white
    )

    --------------------------------------------------
    -- Separator
    --------------------------------------------------

    t.setCursorPos(
        win.x,
        win.y + 1
    )

    t.write(
        string.rep(
            "-",
            win.width
        )
    )

    --------------------------------------------------
    -- Sides
    --------------------------------------------------

    for y =
        win.y + 2,
        win.y + win.height - 1
    do

        t.setCursorPos(
            win.x,
            y
        )

        t.write("|")

        t.setCursorPos(
            win.x + win.width - 1,
            y
        )

        t.write("|")
    end

    --------------------------------------------------
    -- Bottom
    --------------------------------------------------

    t.setCursorPos(
        win.x,
        win.y + win.height - 1
    )

    t.write(
        string.rep(
            "-",
            win.width
        )
    )
end

--------------------------------------------------
-- Draw taskbar
--------------------------------------------------

function UI.drawTaskbar()

    local t = screen()

    local width, height =
        t.getSize()

    --------------------------------------------------
    -- Background
    --------------------------------------------------

    t.setBackgroundColor(
        UI.taskbarColor
    )

    t.setCursorPos(
        1,
        height
    )

    t.write(
        string.rep(
            " ",
            width
        )
    )

    --------------------------------------------------
    -- NexusOS button
    --------------------------------------------------

    t.setCursorPos(
        2,
        height
    )

    t.setBackgroundColor(
        colors.gray
    )

    t.write(
        "[ NexusOS ]"
    )

    --------------------------------------------------
    -- Windows
    --------------------------------------------------

    local x = 15

    for _, win in ipairs(UI.windows) do

        if win.visible then

            local label =
                "[ " .. win.title .. " ]"

            if x + #label <= width then

                if win.focused
                    and not win.minimized then

                    t.setBackgroundColor(
                        colors.lightBlue
                    )

                else

                    t.setBackgroundColor(
                        colors.gray
                    )
                end

                t.setCursorPos(
                    x,
                    height
                )

                t.write(label)

                x =
                    x + #label + 1
            end
        end
    end
end

--------------------------------------------------
-- Draw Start Menu
--------------------------------------------------

function UI.drawStartMenu()

    local t = screen()

    local width, height =
        t.getSize()

    local menuWidth = 24
    local menuHeight = 8

    local x = 2
    local y = height - menuHeight

    --------------------------------------------------
    -- Background
    --------------------------------------------------

    t.setBackgroundColor(
        colors.gray
    )

    t.setTextColor(
        colors.white
    )

    for row = 0,
        menuHeight - 1
    do

        t.setCursorPos(
            x,
            y + row
        )

        t.write(
            string.rep(
                " ",
                menuWidth
            )
        )
    end

    --------------------------------------------------
    -- Header
    --------------------------------------------------

    t.setCursorPos(
        x + 2,
        y + 1
    )

    t.setTextColor(
        colors.yellow
    )

    t.write(
        "NexusOS"
    )

    --------------------------------------------------
    -- Terminal
    --------------------------------------------------

    t.setTextColor(
        colors.white
    )

    t.setCursorPos(
        x + 2,
        y + 3
    )

    t.write(
        "Terminal"
    )

    --------------------------------------------------
    -- Files
    --------------------------------------------------

    t.setCursorPos(
        x + 2,
        y + 4
    )

    t.write(
        "Files"
    )

    --------------------------------------------------
    -- Settings
    --------------------------------------------------

    t.setCursorPos(
        x + 2,
        y + 5
    )

    t.write(
        "Settings"
    )

    --------------------------------------------------
    -- Close menu
    --------------------------------------------------

    t.setCursorPos(
        x + 2,
        y + 6
    )

    t.write(
        "Close Menu"
    )
end

--------------------------------------------------
-- Draw everything
--------------------------------------------------

function UI.draw()

    UI.drawDesktop()

    --------------------------------------------------
    -- Windows
    --------------------------------------------------

    for _, win in ipairs(UI.windows) do

        UI.drawWindow(win)
    end

    --------------------------------------------------
    -- Taskbar
    --------------------------------------------------

    UI.drawTaskbar()

    --------------------------------------------------
    -- Start menu
    --------------------------------------------------

    if UI.startMenu then
        UI.drawStartMenu()
    end
end

--------------------------------------------------
-- Remove window
--------------------------------------------------

function UI.removeWindow(win)

    if not win then
        return
    end

    win.visible = false

    for i, w in ipairs(UI.windows) do

        if w == win then

            table.remove(
                UI.windows,
                i
            )

            break
        end
    end

    --------------------------------------------------
    -- Find another focused window
    --------------------------------------------------

    UI.focused = nil

    for i =
        #UI.windows,
        1,
        -1
    do

        local other =
            UI.windows[i]

        if other.visible
            and not other.minimized then

            UI.focus(other)
            break
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

    win.minimized = true
    win.focused = false

    if UI.focused == win then
        UI.focused = nil
    end

    --------------------------------------------------
    -- Focus another window
    --------------------------------------------------

    for i =
        #UI.windows,
        1,
        -1
    do

        local other =
            UI.windows[i]

        if other.visible
            and not other.minimized then

            UI.focus(other)
            return
        end
    end

    UI.draw()
end

--------------------------------------------------
-- Start dragging
--------------------------------------------------

function UI.startDrag(
    win,
    mouseX,
    mouseY
)

    win.dragging = true

    win.dragX =
        mouseX - win.x

    win.dragY =
        mouseY - win.y

    UI.focus(win)
end

--------------------------------------------------
-- Drag window
--------------------------------------------------

function UI.drag(
    win,
    mouseX,
    mouseY
)

    if not win
        or not win.dragging then

        return
    end

    local t = screen()

    local width, height =
        t.getSize()

    --------------------------------------------------
    -- New position
    --------------------------------------------------

    win.x =
        mouseX - win.dragX

    win.y =
        mouseY - win.dragY

    --------------------------------------------------
    -- Screen boundaries
    --------------------------------------------------

    if win.x < 1 then
        win.x = 1
    end

    if win.y < 1 then
        win.y = 1
    end

    if win.x + win.width - 1 >
        width then

        win.x =
            width - win.width + 1
    end

    if win.y + win.height >
        height then

        win.y =
            height - win.height
    end

    --------------------------------------------------
    -- Move terminal
    --------------------------------------------------

    if win.terminal then

        win.terminal.reposition(
            win.x + 1,
            win.y + 2,
            win.width - 2,
            win.height - 3
        )
    end

    UI.draw()
end

--------------------------------------------------
-- Stop dragging
--------------------------------------------------

function UI.stopDrag()

    if UI.focused then

        UI.focused.dragging = false
    end
end

--------------------------------------------------
-- Mouse click
--------------------------------------------------

function UI.mouseClick(
    button,
    x,
    y
)

    local t = screen()

    local width, height =
        t.getSize()

    --------------------------------------------------
    -- Taskbar / Start
    --------------------------------------------------

    if y == height
        and x >= 2
        and x <= 13 then

        UI.startMenu =
            not UI.startMenu

        UI.draw()

        return
    end

    --------------------------------------------------
    -- Start menu
    --------------------------------------------------

    if UI.startMenu then

        local menuX = 2
        local menuY =
            height - 8

        --------------------------------------------------
        -- Terminal
        --------------------------------------------------

        if x >= menuX
            and x <= menuX + 24
            and y == menuY + 3 then

            UI.startMenu = false

            if UI.onLaunch then
                UI.onLaunch(
                    "terminal"
                )
            end

            UI.draw()

            return
        end

        --------------------------------------------------
        -- Files
        --------------------------------------------------

        if x >= menuX
            and x <= menuX + 24
            and y == menuY + 4 then

            UI.startMenu = false

            if UI.onLaunch then
                UI.onLaunch(
                    "files"
                )
            end

            UI.draw()

            return
        end

        --------------------------------------------------
        -- Settings
        --------------------------------------------------

        if x >= menuX
            and x <= menuX + 24
            and y == menuY + 5 then

            UI.startMenu = false

            if UI.onLaunch then
                UI.onLaunch(
                    "settings"
                )
            end

            UI.draw()

            return
        end

        --------------------------------------------------
        -- Close menu
        --------------------------------------------------

        if y == menuY + 6 then

            UI.startMenu = false

            UI.draw()

            return
        end
    end

    --------------------------------------------------
    -- Window
    --------------------------------------------------

    local win =
        UI.getWindowAt(x, y)

    if not win then
        return
    end

    UI.focus(win)

    --------------------------------------------------
    -- Close X
    --------------------------------------------------

    if y == win.y
        and x == win.x + win.width - 2 then

        if UI.onClose then

            UI.onClose(win)

        else

            UI.removeWindow(win)

        end

        return
    end

    --------------------------------------------------
    -- Minimize
    --------------------------------------------------

    if y == win.y
        and x >= win.x + win.width - 5
        and x <= win.x + win.width - 4 then

        UI.minimize(win)

        return
    end

    --------------------------------------------------
    -- Title bar drag
    --------------------------------------------------

    if y == win.y then

        UI.startDrag(
            win,
            x,
            y
        )

        return
    end
end

--------------------------------------------------
-- Mouse drag
--------------------------------------------------

function UI.mouseDrag(
    button,
    x,
    y
)

    if UI.focused
        and UI.focused.dragging then

        UI.drag(
            UI.focused,
            x,
            y
        )
    end
end

--------------------------------------------------
-- Mouse release
--------------------------------------------------

function UI.mouseUp()

    UI.stopDrag()
end

--------------------------------------------------
-- Event handler
--------------------------------------------------

function UI.handleEvent(
    event,
    ...
)

    if event == "mouse_click" then

        UI.mouseClick(...)

    elseif event == "mouse_drag" then

        UI.mouseDrag(...)

    elseif event == "mouse_up" then

        UI.mouseUp(...)
    end
end

--------------------------------------------------
-- Redirect to window
--------------------------------------------------

function UI.redirect(win)

    if not win
        or not win.terminal then

        return false
    end

    term.redirect(
        win.terminal
    )

    return true
end

--------------------------------------------------
-- Restore native terminal
--------------------------------------------------

function UI.restore()

    term.redirect(
        term.native()
    )
end

return UI
