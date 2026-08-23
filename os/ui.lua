-- NexusOS UI
-- Stable window manager
--
-- IMPORTANT:
-- Each application gets ONE buffered window.
-- The UI draws the window chrome INTO that buffer.
-- The application gets a child terminal inside it.
--
-- This avoids the old:
--   native screen -> chrome -> terminal -> clear -> blue box
-- problem.

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

UI.minWidth = 12
UI.minHeight = 6

--------------------------------------------------
-- Screen
--------------------------------------------------

local function screen()
    return term.native()
end

--------------------------------------------------
-- Safe number
--
-- Prevents "bad argument #1 (number expected, got nil)"
-- from propagating through window operations.
--------------------------------------------------

local function number(value, fallback)
    if type(value) == "number" then
        return value
    end

    return fallback
end

--------------------------------------------------
-- Clamp
--------------------------------------------------

local function clamp(value, minimum, maximum)

    if maximum < minimum then
        return minimum
    end

    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
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
-- Is window alive?
--------------------------------------------------

local function containsWindow(win)

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
-- Reposition application terminal
--------------------------------------------------

local function repositionTerminal(win)

    if not win then
        return
    end

    if not win.terminal then
        return
    end

    local contentWidth =
        math.max(
            1,
            win.width - 2
        )

    local contentHeight =
        math.max(
            1,
            win.height - 3
        )

    --------------------------------------------------
    -- IMPORTANT:
    --
    -- The application terminal belongs to the
    -- application window.
    --
    -- Its coordinates are relative to that window.
    --------------------------------------------------

    win.terminal.reposition(
        2,
        3,
        contentWidth,
        contentHeight
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

    local t = screen()

    local sw, sh =
        t.getSize()

    sw = number(sw, 51)
    sh = number(sh, 19)

    width =
        number(width, 30)

    height =
        number(height, 12)

    x =
        number(x, 2)

    y =
        number(y, 2)

    --------------------------------------------------
    -- Window size
    --------------------------------------------------

    width =
        clamp(
            width,
            UI.minWidth,
            sw
        )

    height =
        clamp(
            height,
            UI.minHeight,
            math.max(
                UI.minHeight,
                sh - 1
            )
        )

    --------------------------------------------------
    -- Window position
    --------------------------------------------------

    x =
        clamp(
            x,
            1,
            math.max(
                1,
                sw - width + 1
            )
        )

    y =
        clamp(
            y,
            1,
            math.max(
                1,
                sh - height
            )
        )

    --------------------------------------------------
    -- Create application window.
    --
    -- This is the actual buffered window.
    --------------------------------------------------

    local surface =
        window.create(
            t,
            x,
            y,
            width,
            height,
            false
        )

    local win = {

        id = UI.nextID,

        title = title or "Window",

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

    UI.nextID =
        UI.nextID + 1

    --------------------------------------------------
    -- Draw surface background.
    --------------------------------------------------

    surface.setBackgroundColor(
        colors.black
    )

    surface.setTextColor(
        colors.white
    )

    surface.clear()

    --------------------------------------------------
    -- Create application terminal INSIDE the
    -- buffered window.
    --------------------------------------------------

    win.terminal =
        window.create(
            surface,
            2,
            3,
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

    --------------------------------------------------
    -- Add window.
    --------------------------------------------------

    table.insert(
        UI.windows,
        win
    )

    --------------------------------------------------
    -- Draw chrome BEFORE showing it.
    --------------------------------------------------

    UI.drawWindow(win)

    surface.setVisible(true)

    --------------------------------------------------
    -- Focus without accidentally restoring a
    -- minimized window.
    --------------------------------------------------

    UI.setFocus(win)

    return win
end

--------------------------------------------------
-- Set focus
--
-- IMPORTANT:
-- This does NOT change minimized state.
--------------------------------------------------

function UI.setFocus(win)

    if not win then
        return
    end

    if not containsWindow(win) then
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
    -- Put selected window on top.
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

    win.focused = true

    UI.focused = win

    --------------------------------------------------
    -- Make visible.
    --------------------------------------------------

    if win.surface then
        win.surface.setVisible(true)
    end

    UI.draw()
end

--------------------------------------------------
-- Compatibility alias
--------------------------------------------------

UI.focus = UI.setFocus

--------------------------------------------------
-- Explicit restore
--------------------------------------------------

function UI.restoreWindow(win)

    if not win then
        return
    end

    if not containsWindow(win) then
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

    UI.setFocus(win)
end

--------------------------------------------------
-- Find window at screen position
--------------------------------------------------

function UI.getWindowAt(x, y)

    x = number(x, 0)
    y = number(y, 0)

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

    width =
        number(width, 51)

    height =
        number(height, 19)

    t.setBackgroundColor(
        UI.desktopColor
    )

    t.setTextColor(
        colors.white
    )

    t.clear()
end

--------------------------------------------------
-- Draw window chrome
--------------------------------------------------

function UI.drawWindow(win)

    if not win then
        return
    end

    if not win.surface then
        return
    end

    if not win.visible
        or win.minimized then

        return
    end

    local w =
        win.surface

    local width =
        math.max(
            1,
            win.width
        )

    local height =
        math.max(
            1,
            win.height
        )

    --------------------------------------------------
    -- Draw entire window background.
    --
    -- This is drawn INTO the window buffer,
    -- not onto the native screen.
    --------------------------------------------------

    w.setBackgroundColor(
        colors.black
    )

    w.setTextColor(
        colors.white
    )

    w.clear()

    --------------------------------------------------
    -- Title bar
    --------------------------------------------------

    if win.focused then

        w.setBackgroundColor(
            UI.activeTitleColor
        )

    else

        w.setBackgroundColor(
            UI.titleColor
        )
    end

    w.setTextColor(
        colors.white
    )

    w.setCursorPos(
        1,
        1
    )

    w.write(
        string.rep(
            " ",
            width
        )
    )

    --------------------------------------------------
    -- Title
    --------------------------------------------------

    local title =
        tostring(
            win.title or "Window"
        )

    local maxTitle =
        math.max(
            1,
            width - 9
        )

    if #title > maxTitle then

        title =
            title:sub(
                1,
                maxTitle
            )
    end

    w.setCursorPos(
        2,
        1
    )

    w.setTextColor(
        colors.white
    )

    w.write(title)

    --------------------------------------------------
    -- Minimize button
    --------------------------------------------------

    w.setBackgroundColor(
        win.focused
            and UI.activeTitleColor
            or UI.titleColor
    )

    w.setCursorPos(
        math.max(
            1,
            width - 5
        ),
        1
    )

    w.write("_")

    --------------------------------------------------
    -- Close button
    --------------------------------------------------

    w.setBackgroundColor(
        UI.closeColor
    )

    w.setCursorPos(
        math.max(
            1,
            width - 2
        ),
        1
    )

    w.write("X")

    --------------------------------------------------
    -- Separator
    --------------------------------------------------

    if height >= 2 then

        w.setBackgroundColor(
            colors.black
        )

        w.setTextColor(
            colors.white
        )

        w.setCursorPos(
            1,
            2
        )

        w.write(
            string.rep(
                "-",
                width
            )
        )
    end

    --------------------------------------------------
    -- Sides
    --------------------------------------------------

    if height >= 5
        and width >= 2 then

        for row = 3, height - 2 do

            w.setBackgroundColor(
                colors.black
            )

            w.setCursorPos(
                1,
                row
            )

            w.write("|")

            w.setCursorPos(
                width,
                row
            )

            w.write("|")
        end
    end

    --------------------------------------------------
    -- Bottom border
    --------------------------------------------------

    if height >= 3 then

        w.setBackgroundColor(
            colors.black
        )

        w.setCursorPos(
            1,
            height
        )

        w.write(
            string.rep(
                "-",
                width
            )
        )
    end

    --------------------------------------------------
    -- Resize handle
    --------------------------------------------------

    if width >= 2
        and height >= 2 then

        w.setBackgroundColor(
            colors.gray
        )

        w.setTextColor(
            colors.white
        )

        w.setCursorPos(
            width,
            height
        )

        w.write("+")
    end
end

--------------------------------------------------
-- Draw taskbar
--------------------------------------------------

function UI.drawTaskbar()

    local t = screen()

    local width, height =
        t.getSize()

    width =
        number(width, 51)

    height =
        number(height, 19)

    --------------------------------------------------
    -- Taskbar
    --------------------------------------------------

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
    -- Start button
    --------------------------------------------------

    t.setBackgroundColor(
        colors.gray
    )

    t.setCursorPos(
        2,
        height
    )

    t.write(
        "[ NexusOS ]"
    )

    --------------------------------------------------
    -- Applications
    --------------------------------------------------

    local currentX = 15

    for _, win in ipairs(UI.windows) do

        if win.visible then

            local label =
                "[ "
                .. tostring(win.title or "Window")
                .. " ]"

            if currentX + #label <= width then

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

                t.setCursorPos(
                    currentX,
                    height
                )

                t.write(label)

                currentX =
                    currentX
                    + #label
                    + 1
            end
        end
    end
end

--------------------------------------------------
-- Start menu
--------------------------------------------------

function UI.drawStartMenu()

    local t = screen()

    local width, height =
        t.getSize()

    width =
        number(width, 51)

    height =
        number(height, 19)

    local menuWidth =
        math.min(
            24,
            width
        )

    local menuHeight =
        math.min(
            8,
            math.max(
                1,
                height - 1
            )
        )

    local x = 2

    local y =
        math.max(
            1,
            height - menuHeight
        )

    t.setBackgroundColor(
        colors.gray
    )

    t.setTextColor(
        colors.white
    )

    for row = 0, menuHeight - 1 do

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

    if menuHeight >= 2 then

        t.setCursorPos(
            x + 2,
            y + 1
        )

        t.setTextColor(
            colors.yellow
        )

        t.write("NexusOS")
    end

    t.setTextColor(
        colors.white
    )

    if menuHeight >= 4 then

        t.setCursorPos(
            x + 2,
            y + 3
        )

        t.write("Terminal")
    end

    if menuHeight >= 5 then

        t.setCursorPos(
            x + 2,
            y + 4
        )

        t.write("Files")
    end

    if menuHeight >= 6 then

        t.setCursorPos(
            x + 2,
            y + 5
        )

        t.write("Settings")
    end

    if menuHeight >= 7 then

        t.setCursorPos(
            x + 2,
            y + 6
        )

        t.write("Close Menu")
    end
end

--------------------------------------------------
-- Draw everything
--------------------------------------------------

function UI.draw()

    local t = screen()

    --------------------------------------------------
    -- Hide all application surfaces while the native
    -- desktop is being rebuilt.
    --
    -- This prevents the native desktop clear from
    -- fighting with application buffers.
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
    -- Windows
    --
    -- Bottom -> top.
    --------------------------------------------------

    for _, win in ipairs(UI.windows) do

        if win.visible
            and not win.minimized then

            UI.drawWindow(win)

            if win.surface then
                win.surface.setVisible(true)
            end
        end
    end

    --------------------------------------------------
    -- Taskbar
    --
    -- Drawn AFTER windows so it remains on top.
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

    if not containsWindow(win) then
        return
    end

    win.dragging = false
    win.resizing = false

    if win.surface then
        win.surface.setVisible(false)
    end

    win.visible = false
    win.minimized = false
    win.focused = false

    --------------------------------------------------
    -- Remove from list.
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

    if UI.focused == win then
        UI.focused = nil
    end

    --------------------------------------------------
    -- Find next window.
    --------------------------------------------------

    for i = #UI.windows, 1, -1 do

        local other =
            UI.windows[i]

        if other.visible
            and not other.minimized then

            UI.setFocus(other)

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

    if not containsWindow(win) then
        return
    end

    --------------------------------------------------
    -- Stop movement.
    --------------------------------------------------

    win.dragging = false
    win.resizing = false

    --------------------------------------------------
    -- Mark minimized.
    --
    -- visible stays TRUE so the taskbar still knows
    -- the application exists.
    --------------------------------------------------

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
    -- Find another window to focus.
    --------------------------------------------------

    for i = #UI.windows, 1, -1 do

        local other =
            UI.windows[i]

        if other ~= win
            and other.visible
            and not other.minimized then

            UI.setFocus(other)

            return
        end
    end

    --------------------------------------------------
    -- No other window.
    --------------------------------------------------

    UI.draw()
end

--------------------------------------------------
-- Taskbar lookup
--------------------------------------------------

function UI.getTaskbarWindowAt(
    x,
    y
)

    local t = screen()

    local width, height =
        t.getSize()

    width =
        number(width, 51)

    height =
        number(height, 19)

    x = number(x, 0)
    y = number(y, 0)

    if y ~= height then
        return nil
    end

    local currentX = 15

    for _, win in ipairs(UI.windows) do

        if win.visible then

            local label =
                "[ "
                .. tostring(win.title or "Window")
                .. " ]"

            if currentX + #label <= width then

                if x >= currentX
                    and x < currentX + #label then

                    return win
                end

                currentX =
                    currentX
                    + #label
                    + 1
            end
        end
    end

    return nil
end

--------------------------------------------------
-- Start dragging
--------------------------------------------------

function UI.startDrag(
    win,
    mouseX,
    mouseY
)

    if not win then
        return
    end

    if win.minimized then
        return
    end

    mouseX = number(mouseX, win.x)
    mouseY = number(mouseY, win.y)

    --------------------------------------------------
    -- Focus first.
    --------------------------------------------------

    UI.setFocus(win)

    --------------------------------------------------
    -- Start operation.
    --------------------------------------------------

    UI.activeMode = "drag"
    UI.activeWindow = win

    win.dragging = true
    win.resizing = false

    win.dragX =
        mouseX - win.x

    win.dragY =
        mouseY - win.y
end

--------------------------------------------------
-- Drag
--------------------------------------------------

function UI.drag(
    win,
    mouseX,
    mouseY
)

    if not win then
        return
    end

    if not win.dragging then
        return
    end

    mouseX =
        number(
            mouseX,
            win.x + win.dragX
        )

    mouseY =
        number(
            mouseY,
            win.y + win.dragY
        )

    local t = screen()

    local screenWidth,
        screenHeight =
        t.getSize()

    screenWidth =
        number(
            screenWidth,
            51
        )

    screenHeight =
        number(
            screenHeight,
            19
        )

    --------------------------------------------------
    -- Calculate position.
    --------------------------------------------------

    local newX =
        mouseX - win.dragX

    local newY =
        mouseY - win.dragY

    --------------------------------------------------
    -- Keep inside screen.
    --------------------------------------------------

    newX =
        clamp(
            newX,
            1,
            math.max(
                1,
                screenWidth - win.width + 1
            )
        )

    newY =
        clamp(
            newY,
            1,
            math.max(
                1,
                screenHeight - win.height
            )
        )

    --------------------------------------------------
    -- Save position.
    --------------------------------------------------

    win.x = newX
    win.y = newY

    --------------------------------------------------
    -- MOVE THE ACTUAL BUFFERED WINDOW.
    --
    -- The application terminal is a child of this
    -- surface, so it moves with the window.
    --------------------------------------------------

    if win.surface then

        win.surface.reposition(
            win.x,
            win.y,
            win.width,
            win.height
        )
    end

    --------------------------------------------------
    -- No terminal clearing.
    -- No terminal recreation.
    -- No content redraw.
    --
    -- The buffered application contents remain.
    --------------------------------------------------

    UI.draw()
end

--------------------------------------------------
-- Start resize
--------------------------------------------------

function UI.startResize(win)

    if not win then
        return
    end

    if win.minimized then
        return
    end

    UI.setFocus(win)

    UI.activeMode = "resize"
    UI.activeWindow = win

    win.resizing = true
    win.dragging = false
end

--------------------------------------------------
-- Resize
--------------------------------------------------

function UI.resize(
    win,
    mouseX,
    mouseY
)

    if not win then
        return
    end

    if not win.resizing then
        return
    end

    mouseX =
        number(
            mouseX,
            win.x + win.width - 1
        )

    mouseY =
        number(
            mouseY,
            win.y + win.height - 1
        )

    local t = screen()

    local screenWidth,
        screenHeight =
        t.getSize()

    screenWidth =
        number(
            screenWidth,
            51
        )

    screenHeight =
        number(
            screenHeight,
            19
        )

    --------------------------------------------------
    -- New dimensions.
    --------------------------------------------------

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

    --------------------------------------------------
    -- Don't go beyond screen.
    --------------------------------------------------

    newWidth =
        math.min(
            newWidth,
            screenWidth - win.x + 1
        )

    newHeight =
        math.min(
            newHeight,
            screenHeight - win.y
        )

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
    -- Save.
    --------------------------------------------------

    win.width = newWidth
    win.height = newHeight

    --------------------------------------------------
    -- Resize actual buffered surface.
    --------------------------------------------------

    if win.surface then

        win.surface.reposition(
            win.x,
            win.y,
            win.width,
            win.height
        )
    end

    --------------------------------------------------
    -- Resize application child.
    --------------------------------------------------

    repositionTerminal(win)

    --------------------------------------------------
    -- Redraw chrome.
    --------------------------------------------------

    UI.drawWindow(win)

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

    width =
        number(width, 51)

    height =
        number(height, 19)

    x = number(x, 0)
    y = number(y, 0)

    --------------------------------------------------
    -- Start button
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
    -- Taskbar
    --------------------------------------------------

    if y == height then

        local taskWindow =
            UI.getTaskbarWindowAt(
                x,
                y
            )

        if taskWindow then

            --------------------------------------------------
            -- Minimized -> restore.
            --------------------------------------------------

            if taskWindow.minimized then

                UI.restoreWindow(
                    taskWindow
                )

                return true
            end

            --------------------------------------------------
            -- Normal -> focus.
            --------------------------------------------------

            if UI.focused ~= taskWindow then

                UI.setFocus(
                    taskWindow
                )

            else

                UI.draw()
            end

            return true
        end
    end

    --------------------------------------------------
    -- Start menu
    --------------------------------------------------

    if UI.startMenu then

        local menuX = 2

        local menuHeight = 8

        local menuY =
            math.max(
                1,
                height - menuHeight
            )

        --------------------------------------------------
        -- Terminal
        --------------------------------------------------

        if y == menuY + 3 then

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

        if y == menuY + 4 then

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

        if y == menuY + 5 then

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
    -- Find window.
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
    -- Focus.
    --------------------------------------------------

    UI.setFocus(win)

    --------------------------------------------------
    -- Close button.
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
    -- Minimize button.
    --------------------------------------------------

    if y == win.y
        and x >= win.x + win.width - 5
        and x <= win.x + win.width - 4 then

        UI.minimize(win)

        return true
    end

    --------------------------------------------------
    -- Resize handle.
    --------------------------------------------------

    if x == win.x + win.width - 1
        and y == win.y + win.height - 1 then

        UI.startResize(win)

        return true
    end

    --------------------------------------------------
    -- Title bar.
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
    -- Content.
    --
    -- Tell kernel/application that this click was
    -- inside the application.
    --------------------------------------------------

    if UI.onContentClick then

        return UI.onContentClick(
            win,
            button,
            x - win.x - 1,
            y - win.y - 2
        ) or false
    end

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

    x = number(x, 0)
    y = number(y, 0)

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
-- Redirect to application
--------------------------------------------------

function UI.redirect(win)

    if not win then
        return false
    end

    if not win.terminal then
        return false
    end

    --------------------------------------------------
    -- Never redirect into a minimized window.
    --------------------------------------------------

    if win.minimized then
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

--------------------------------------------------
-- Get application terminal
--------------------------------------------------

function UI.getTerminal(win)

    if not win then
        return nil
    end

    return win.terminal
end

--------------------------------------------------
-- Get focused window
--------------------------------------------------

function UI.getFocused()

    return UI.focused
end

--------------------------------------------------
-- Return UI
--------------------------------------------------

return UI
