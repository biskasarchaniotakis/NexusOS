-- NexusOS UI
-- Window manager + app launcher + resizing

local UI = {}

--------------------------------------------------
-- State
--------------------------------------------------

UI.windows = {}
UI.nextID = 1
UI.focused = nil
UI.startMenu = false

-- Current window-manager mouse operation.
--
-- nil       = no operation
-- "drag"    = moving a window
-- "resize"  = resizing a window
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

--------------------------------------------------
-- Window limits
--------------------------------------------------

UI.minWidth = 10
UI.minHeight = 5

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

    UI.activeMode = nil
    UI.activeWindow = nil

    UI.draw()
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

    local t = screen()

    local sw, sh =
        t.getSize()

    width =
        math.max(
            UI.minWidth,
            math.min(
                width or 30,
                sw
            )
        )

    height =
        math.max(
            UI.minHeight,
            math.min(
                height or 15,
                sh - 1
            )
        )

    x =
        math.max(
            1,
            math.min(
                x or 2,
                sw - width + 1
            )
        )

    y =
        math.max(
            1,
            math.min(
                y or 2,
                sh - height
            )
        )

    local win = {

        id = UI.nextID,

        title =
            title or "Window",

        x = x,
        y = y,

        width = width,
        height = height,

        visible = true,
        minimized = false,
        focused = false,

        dragging = false,
        resizing = false,

        dragX = 0,
        dragY = 0
    }

    UI.nextID =
        UI.nextID + 1

    --------------------------------------------------
    -- Window terminal
    --------------------------------------------------

    win.terminal =
        window.create(
            t,

            x + 1,
            y + 2,

            width - 2,
            height - 3,

            true
        )

    win.terminal.setBackgroundColor(
        colors.black
    )

    win.terminal.setTextColor(
        colors.white
    )

    win.terminal.clear()

    win.terminal.setCursorPos(
        1,
        1
    )

    table.insert(
        UI.windows,
        win
    )

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

            table.remove(
                UI.windows,
                i
            )

            break
        end
    end

    table.insert(
        UI.windows,
        win
    )

    --------------------------------------------------
    -- Update focus
    --------------------------------------------------

    for _, w in ipairs(UI.windows) do
        w.focused = false
    end

    win.focused = true
    win.minimized = false

    --------------------------------------------------
    -- Restore terminal visibility
    --------------------------------------------------

    if win.terminal then
        win.terminal.setVisible(true)
    end

    UI.focused = win

    UI.draw()
end

--------------------------------------------------
-- Find window at screen coordinates
--------------------------------------------------

function UI.getWindowAt(x, y)

    for i = #UI.windows, 1, -1 do

        local win =
            UI.windows[i]

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

        t.setCursorPos(
            1,
            y
        )

        t.write(
            string.rep(
                " ",
                width
            )
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

    t.setTextColor(
        colors.white
    )

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

    local title =
        win.title

    local maxTitle =
        math.max(
            1,
            win.width - 8
        )

    if #title > maxTitle then

        title =
            title:sub(
                1,
                maxTitle
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
        win.y + win.height - 2
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
    -- Bottom border
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

    --------------------------------------------------
    -- Resize handle
    --
    -- Bottom-right corner.
    --------------------------------------------------

    t.setBackgroundColor(
        colors.gray
    )

    t.setTextColor(
        colors.white
    )

    t.setCursorPos(
        win.x + win.width - 1,
        win.y + win.height - 1
    )

    t.write("+")
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

    local y =
        height - menuHeight

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

    if win.terminal then
        win.terminal.setVisible(false)
    end

    for i, w in ipairs(UI.windows) do

        if w == win then

            table.remove(
                UI.windows,
                i
            )

            break
        end
    end

    if UI.focused == win then
        UI.focused = nil
    end

    --------------------------------------------------
    -- Find another focused window
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
-- Minimize
--------------------------------------------------

function UI.minimize(win)

    if not win then
        return
    end

    win.minimized = true
    win.focused = false

    if win.terminal then
        win.terminal.setVisible(false)
    end

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

    UI.activeMode = "drag"
    UI.activeWindow = win

    win.dragging = true
    win.resizing = false

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
-- Start resizing
--------------------------------------------------

function UI.startResize(win)

    UI.activeMode = "resize"
    UI.activeWindow = win

    win.resizing = true
    win.dragging = false

    UI.focus(win)
end

--------------------------------------------------
-- Resize window
--------------------------------------------------

function UI.resize(
    win,
    mouseX,
    mouseY
)

    if not win
        or not win.resizing then

        return
    end

    local t = screen()

    local screenWidth,
        screenHeight =
        t.getSize()

    --------------------------------------------------
    -- Calculate desired size.
    --
    -- The window's top-left corner stays fixed.
    --------------------------------------------------

    local newWidth =
        mouseX - win.x + 1

    local newHeight =
        mouseY - win.y + 1

    --------------------------------------------------
    -- Minimum size
    --------------------------------------------------

    newWidth =
        math.max(
            UI.minWidth,
            newWidth
        )

    newHeight =
        math.max(
            UI.minHeight,
            newHeight
        )

    --------------------------------------------------
    -- Screen width limit
    --------------------------------------------------

    local maxWidth =
        screenWidth - win.x + 1

    if newWidth > maxWidth then
        newWidth = maxWidth
    end

    --------------------------------------------------
    -- Taskbar / screen height limit
    --
    -- The taskbar occupies the final row.
    --------------------------------------------------

    local maxHeight =
        screenHeight - win.y

    if newHeight > maxHeight then
        newHeight = maxHeight
    end

    --------------------------------------------------
    -- Did anything actually change?
    --------------------------------------------------

    if newWidth == win.width
        and newHeight == win.height then

        return
    end

    win.width = newWidth
    win.height = newHeight

    --------------------------------------------------
    -- Resize terminal
    --------------------------------------------------

    if win.terminal then

        win.terminal.reposition(
            win.x + 1,
            win.y + 2,
            win.width - 2,
            win.height - 3
        )
    end

    --------------------------------------------------
    -- Tell kernel/application manager
    -- that the terminal size changed.
    --------------------------------------------------

    if UI.onResize then
        UI.onResize(win)
    end

    UI.draw()
end

--------------------------------------------------
-- Stop current mouse operation
--------------------------------------------------

function UI.stopMouseOperation()

    local wasActive =
        UI.activeMode ~= nil

    if UI.activeWindow then

        UI.activeWindow.dragging = false
        UI.activeWindow.resizing = false
    end

    UI.activeMode = nil
    UI.activeWindow = nil

    return wasActive
end

--------------------------------------------------
-- Find taskbar window at coordinate
--------------------------------------------------

function UI.getTaskbarWindowAt(x, y)

    local t = screen()

    local width, height =
        t.getSize()

    if y ~= height then
        return nil
    end

    local currentX = 15

    for _, win in ipairs(UI.windows) do

        if win.visible then

            local label =
                "[ " .. win.title .. " ]"

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
-- Restore window
--------------------------------------------------

function UI.restoreWindow(win)

    if not win then
        return
    end

    UI.focus(win)
end

--------------------------------------------------
-- Mouse click
--
-- Returns true when the UI consumed the event.
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
    -- NexusOS / Start button
    --------------------------------------------------

    if y == height
        and x >= 2
        and x <= 13 then

        UI.startMenu =
            not UI.startMenu

        UI.draw()

        return true
    end

    --------------------------------------------------
    -- Taskbar application
    --------------------------------------------------

    if y == height then

        local taskWindow =
            UI.getTaskbarWindowAt(
                x,
                y
            )

        if taskWindow then

            if taskWindow.minimized then

                UI.restoreWindow(
                    taskWindow
                )

            elseif UI.focused ~= taskWindow then

                UI.focus(taskWindow)

            end

            return true
        end
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

            return true
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

            return true
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

            return true
        end

        --------------------------------------------------
        -- Close menu
        --------------------------------------------------

        if y == menuY + 6 then

            UI.startMenu = false

            UI.draw()

            return true
        end
    end

    --------------------------------------------------
    -- Window
    --------------------------------------------------

    local win =
        UI.getWindowAt(
            x,
            y
        )

    if not win then
        return false
    end

    --------------------------------------------------
    -- Focus clicked window
    --------------------------------------------------

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
    -- Resize handle
    --
    -- Bottom-right corner.
    --------------------------------------------------

    if x == win.x + win.width - 1
        and y == win.y + win.height - 1 then

        UI.startResize(win)

        return true
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

        return true
    end

    --------------------------------------------------
    -- Window content.
    --
    -- Not consumed by UI.
    -- Kernel may send it to the app.
    --------------------------------------------------

    return false
end

--------------------------------------------------
-- Mouse drag
--
-- Returns true when window manager owns drag.
--------------------------------------------------

function UI.mouseDrag(
    button,
    x,
    y
)

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
-- Mouse release
--------------------------------------------------

function UI.mouseUp()

    return UI.stopMouseOperation()
end

--------------------------------------------------
-- Event handler
--
-- Returns true if UI consumed event.
--------------------------------------------------

function UI.handleEvent(
    event,
    ...
)

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
