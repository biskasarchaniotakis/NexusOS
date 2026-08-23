-- NexusOS UI
-- Window manager + app launcher + resizing + minimization

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

        title = title or "Window",

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
    -- Application terminal
    --------------------------------------------------

    win.terminal =
        window.create(
            t,
            x + 1,
            y + 2,
            math.max(1, width - 2),
            math.max(1, height - 3),
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
-- Focus window
--------------------------------------------------

function UI.focus(win)

    if not win then
        return
    end

    --------------------------------------------------
    -- Make sure window is in the window list.
    --------------------------------------------------

    local found = false

    for i, w in ipairs(UI.windows) do

        if w == win then

            found = true

            table.remove(
                UI.windows,
                i
            )

            break
        end
    end

    if not found then
        return
    end

    --------------------------------------------------
    -- Put window on top.
    --------------------------------------------------

    table.insert(
        UI.windows,
        win
    )

    --------------------------------------------------
    -- Clear focus from all windows.
    --------------------------------------------------

    for _, w in ipairs(UI.windows) do
        w.focused = false
    end

    --------------------------------------------------
    -- Restore minimized state.
    --------------------------------------------------

    win.minimized = false
    win.visible = true
    win.focused = true

    --------------------------------------------------
    -- Restore terminal visibility.
    --------------------------------------------------

    if win.terminal then

        win.terminal.setVisible(
            true
        )
    end

    UI.focused = win

    UI.draw()
end

--------------------------------------------------
-- Explicit restore
--------------------------------------------------

function UI.restoreWindow(win)

    if not win then
        return
    end

    win.visible = true
    win.minimized = false
    win.dragging = false
    win.resizing = false

    if win.terminal then

        win.terminal.setVisible(
            true
        )
    end

    UI.focus(win)
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

    --------------------------------------------------
    -- IMPORTANT:
    --
    -- The desktop is drawn BEFORE application
    -- terminals are shown.
    --
    -- This prevents us from repeatedly clearing
    -- application window buffers.
    --------------------------------------------------

    t.clear()

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
-- Draw window chrome
--------------------------------------------------

function UI.drawWindow(win)

    if not win.visible
        or win.minimized then

        return
    end

    local t = screen()

    --------------------------------------------------
    -- IMPORTANT:
    --
    -- We ONLY draw the window chrome here.
    --
    -- We do NOT clear or draw over the application
    -- terminal area.
    --------------------------------------------------

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
    -- Separator
    --------------------------------------------------

    t.setBackgroundColor(
        colors.black
    )

    t.setTextColor(
        colors.white
    )

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
    -- Window sides
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

    t.setBackgroundColor(
        UI.taskbarColor
    )

    t.setTextColor(
        colors.white
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
    -- Application buttons
    --------------------------------------------------

    local x = 15

    for _, win in ipairs(UI.windows) do

        if win.visible
            or win.minimized then

            local label =
                "[ " .. win.title .. " ]"

            if x + #label <= width then

                if win.focused
                    and not win.minimized then

                    t.setBackgroundColor(
                        colors.lightBlue
                    )

                elseif win.minimized then

                    t.setBackgroundColor(
                        colors.darkGray
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

    t.setCursorPos(
        x + 2,
        y + 4
    )

    t.write(
        "Files"
    )

    t.setCursorPos(
        x + 2,
        y + 5
    )

    t.write(
        "Settings"
    )

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
    -- Draw windows
    --------------------------------------------------

    for _, win in ipairs(UI.windows) do

        if win.visible
            and not win.minimized then

            UI.drawWindow(win)

            --------------------------------------------------
            -- Make sure application terminal is visible
            -- at its current window position.
            --------------------------------------------------

            if win.terminal then
                win.terminal.setVisible(true)
            end
        end
    end

    UI.drawTaskbar()

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
    win.minimized = false
    win.focused = false

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
    -- Find another window.
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
    win.visible = true
    win.focused = false

    win.dragging = false
    win.resizing = false

    if win.terminal then

        win.terminal.setVisible(
            false
        )
    end

    if UI.focused == win then
        UI.focused = nil
    end

    --------------------------------------------------
    -- Find another visible window.
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
-- Find taskbar application
--------------------------------------------------

function UI.getTaskbarWindowAt(
    x,
    y
)

    local t = screen()

    local width, height =
        t.getSize()

    if y ~= height then
        return nil
    end

    local currentX = 15

    for _, win in ipairs(UI.windows) do

        if win.visible
            or win.minimized then

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
-- Start dragging
--------------------------------------------------

function UI.startDrag(win, mouseX, mouseY)

    if not win then
        return
    end

    UI.activeMode = "drag"
    UI.activeWindow = win

    win.dragging = true
    win.resizing = false

    --------------------------------------------------
    -- Remember where inside the title bar we clicked.
    --------------------------------------------------

    win.dragX =
        mouseX - win.x

    win.dragY =
        mouseY - win.y

    --------------------------------------------------
    -- Bring window to front.
    --------------------------------------------------

    UI.focus(win)
end

--------------------------------------------------
-- Drag window
--------------------------------------------------

function UI.drag(win, mouseX, mouseY)

    if not win or not win.dragging then
        return
    end

    local t = screen()

    local screenWidth, screenHeight =
        t.getSize()

    --------------------------------------------------
    -- Calculate new position
    --------------------------------------------------

    local newX =
        mouseX - win.dragX

    local newY =
        mouseY - win.dragY

    --------------------------------------------------
    -- Keep inside screen
    --------------------------------------------------

    newX =
        math.max(
            1,
            newX
        )

    newY =
        math.max(
            1,
            newY
        )

    if newX + win.width - 1 > screenWidth then

        newX =
            screenWidth - win.width + 1
    end

    if newY + win.height > screenHeight then

        newY =
            screenHeight - win.height
    end

    --------------------------------------------------
    -- Save position
    --------------------------------------------------

    win.x = newX
    win.y = newY

    --------------------------------------------------
    -- Move application terminal
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
    -- Redraw desktop and windows
    --------------------------------------------------

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

    local newWidth =
        mouseX - win.x + 1

    local newHeight =
        mouseY - win.y + 1

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

    local maxWidth =
        screenWidth - win.x + 1

    if newWidth > maxWidth then
        newWidth = maxWidth
    end

    local maxHeight =
        screenHeight - win.y

    if newHeight > maxHeight then
        newHeight = maxHeight
    end

    if newWidth == win.width
        and newHeight == win.height then

        return
    end

    win.width = newWidth
    win.height = newHeight

    if win.terminal then

        win.terminal.reposition(
            win.x + 1,
            win.y + 2,
            math.max(1, win.width - 2),
            math.max(1, win.height - 3)
        )
    end

    if UI.onResize then
        UI.onResize(win)
    end

    UI.draw()
end

--------------------------------------------------
-- Stop mouse operation
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
    -- START BUTTON
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
    -- TASKBAR
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

                return true
            end

            if UI.focused ~= taskWindow then

                UI.focus(taskWindow)

            else

                UI.draw()
            end

            return true
        end
    end

    --------------------------------------------------
    -- START MENU
    --------------------------------------------------

    if UI.startMenu then

        local menuX = 2

        local menuY =
            height - 8

        if x >= menuX
            and x <= menuX + 24
            and y == menuY + 3 then

            UI.startMenu = false

            if UI.onLaunch then
                UI.onLaunch("terminal")
            end

            UI.draw()

            return true
        end

        if x >= menuX
            and x <= menuX + 24
            and y == menuY + 4 then

            UI.startMenu = false

            if UI.onLaunch then
                UI.onLaunch("files")
            end

            UI.draw()

            return true
        end

        if x >= menuX
            and x <= menuX + 24
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
    end

    --------------------------------------------------
    -- WINDOW
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
    -- CLOSE
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
    -- MINIMIZE
    --------------------------------------------------

    if y == win.y
        and x >= win.x + win.width - 5
        and x <= win.x + win.width - 4 then

        UI.minimize(win)

        return true
    end

    --------------------------------------------------
    -- RESIZE HANDLE
    --------------------------------------------------

    if x == win.x + win.width - 1
        and y == win.y + win.height - 1 then

        UI.startResize(win)

        return true
    end

    --------------------------------------------------
    -- TITLE BAR
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
    -- CONTENT
    --------------------------------------------------

    UI.focus(win)

    return false
end

--------------------------------------------------
-- Mouse drag
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
-- Handle event
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
