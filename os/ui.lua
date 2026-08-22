-- NexusOS UI
-- Basic window manager for CC:Tweaked

local UI = {}

--------------------------------------------------
-- Configuration
--------------------------------------------------

UI.windows = {}
UI.nextWindowID = 1
UI.focused = nil

UI.desktopColor = colors.blue
UI.taskbarColor = colors.gray
UI.titleColor = colors.gray
UI.activeTitleColor = colors.lightBlue
UI.textColor = colors.white
UI.closeColor = colors.red

--------------------------------------------------
-- Get screen
--------------------------------------------------

local function getScreen()
    return term.native()
end

--------------------------------------------------
-- Check if point is inside window
--------------------------------------------------

local function inside(win, x, y)
    return (
        x >= win.x
        and x <= win.x + win.width - 1
        and y >= win.y
        and y <= win.y + win.height - 1
    )
end

--------------------------------------------------
-- Draw desktop
--------------------------------------------------

function UI.drawDesktop()
    local screen = getScreen()

    screen.setBackgroundColor(UI.desktopColor)
    screen.setTextColor(colors.white)

    screen.clear()
    screen.setCursorPos(1, 1)

    local width, height =
        screen.getSize()

    --------------------------------------------------
    -- Desktop
    --------------------------------------------------

    screen.setBackgroundColor(UI.desktopColor)

    for y = 1, height - 1 do
        screen.setCursorPos(1, y)
        screen.write(
            string.rep(" ", width)
        )
    end

    --------------------------------------------------
    -- Taskbar
    --------------------------------------------------

    screen.setBackgroundColor(
        UI.taskbarColor
    )

    screen.setCursorPos(1, height)

    screen.write(
        string.rep(" ", width)
    )

    screen.setTextColor(colors.white)

    screen.setCursorPos(2, height)

    screen.write("NexusOS")

    --------------------------------------------------
    -- Draw windows
    --------------------------------------------------

    UI.drawWindows()
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

    local screen = getScreen()

    local win = {
        id = UI.nextWindowID,

        title = title or "Window",

        x = x or 2,
        y = y or 2,

        width = width or 30,
        height = height or 15,

        visible = true,
        minimized = false,

        dragging = false,

        dragX = 0,
        dragY = 0,

        focused = false,

        terminal = nil,

        onEvent = nil,
        onClose = nil
    }

    UI.nextWindowID =
        UI.nextWindowID + 1

    --------------------------------------------------
    -- Create terminal
    --------------------------------------------------

    win.terminal =
        window.create(
            screen,
            win.x + 1,
            win.y + 1,
            win.width - 2,
            win.height - 2,
            true
        )

    --------------------------------------------------
    -- Add window
    --------------------------------------------------

    table.insert(
        UI.windows,
        win
    )

    --------------------------------------------------
    -- Focus
    --------------------------------------------------

    UI.focus(win)

    --------------------------------------------------
    -- Draw
    --------------------------------------------------

    UI.drawWindows()

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
    -- Move window to top
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

    UI.focused = win

    UI.drawWindows()
end

--------------------------------------------------
-- Draw one window
--------------------------------------------------

function UI.drawWindow(win)

    if not win.visible
        or win.minimized then

        return
    end

    local screen = getScreen()

    --------------------------------------------------
    -- Title bar
    --------------------------------------------------

    if win.focused then

        screen.setBackgroundColor(
            UI.activeTitleColor
        )

    else

        screen.setBackgroundColor(
            UI.titleColor
        )
    end

    screen.setTextColor(
        UI.textColor
    )

    screen.setCursorPos(
        win.x,
        win.y
    )

    screen.write(
        string.rep(
            " ",
            win.width
        )
    )

    --------------------------------------------------
    -- Title
    --------------------------------------------------

    screen.setCursorPos(
        win.x + 1,
        win.y
    )

    local title =
        win.title

    if #title >
        win.width - 6 then

        title =
            title:sub(
                1,
                win.width - 6
            )
    end

    screen.write(title)

    --------------------------------------------------
    -- Minimize button
    --------------------------------------------------

    if win.width >= 6 then

        screen.setCursorPos(
            win.x + win.width - 5,
            win.y
        )

        screen.write("_")

    end

    --------------------------------------------------
    -- Close button
    --------------------------------------------------

    if win.width >= 3 then

        screen.setBackgroundColor(
            UI.closeColor
        )

        screen.setCursorPos(
            win.x + win.width - 2,
            win.y
        )

        screen.write("X")
    end

    --------------------------------------------------
    -- Border
    --------------------------------------------------

    screen.setBackgroundColor(
        colors.black
    )

    --------------------------------------------------
    -- Top border
    --------------------------------------------------

    screen.setCursorPos(
        win.x,
        win.y + 1
    )

    screen.write(
        string.rep(
            "-",
            win.width
        )
    )

    --------------------------------------------------
    -- Bottom border
    --------------------------------------------------

    screen.setCursorPos(
        win.x,
        win.y + win.height - 1
    )

    screen.write(
        string.rep(
            "-",
            win.width
        )
    )

    --------------------------------------------------
    -- Left / right borders
    --------------------------------------------------

    for y =
        win.y + 1,
        win.y + win.height - 1
    do

        screen.setCursorPos(
            win.x,
            y
        )

        screen.write("|")

        screen.setCursorPos(
            win.x + win.width - 1,
            y
        )

        screen.write("|")
    end
end

--------------------------------------------------
-- Draw all windows
--------------------------------------------------

function UI.drawWindows()

    local screen = getScreen()

    --------------------------------------------------
    -- Desktop first
    --------------------------------------------------

    UI.drawDesktopOnly()

    --------------------------------------------------
    -- Windows
    --------------------------------------------------

    for _, win in ipairs(UI.windows) do

        if win.visible
            and not win.minimized then

            UI.drawWindow(win)
        end
    end

    --------------------------------------------------
    -- Taskbar
    --------------------------------------------------

    UI.drawTaskbar()
end

--------------------------------------------------
-- Desktop only
--------------------------------------------------

function UI.drawDesktopOnly()

    local screen = getScreen()

    local width, height =
        screen.getSize()

    screen.setBackgroundColor(
        UI.desktopColor
    )

    screen.setTextColor(
        colors.white
    )

    for y = 1, height - 1 do

        screen.setCursorPos(
            1,
            y
        )

        screen.write(
            string.rep(
                " ",
                width
            )
        )
    end
end

--------------------------------------------------
-- Draw taskbar
--------------------------------------------------

function UI.drawTaskbar()

    local screen = getScreen()

    local width, height =
        screen.getSize()

    screen.setBackgroundColor(
        UI.taskbarColor
    )

    screen.setTextColor(
        colors.white
    )

    screen.setCursorPos(
        1,
        height
    )

    screen.write(
        string.rep(
            " ",
            width
        )
    )

    --------------------------------------------------
    -- Start
    --------------------------------------------------

    screen.setCursorPos(
        2,
        height
    )

    screen.write(
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

            if x + #label <
                width then

                screen.setCursorPos(
                    x,
                    height
                )

                screen.write(label)

                x =
                    x + #label + 1
            end
        end
    end
end

--------------------------------------------------
-- Close window
--------------------------------------------------

function UI.close(win)

    if not win then
        return
    end

    --------------------------------------------------
    -- Callback
    --------------------------------------------------

    if win.onClose then
        win.onClose(win)
    end

    --------------------------------------------------
    -- Remove
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

    --------------------------------------------------
    -- Focus another window
    --------------------------------------------------

    UI.focused = nil

    if #UI.windows > 0 then

        UI.focus(
            UI.windows[#UI.windows]
        )

    else

        UI.drawDesktop()
    end
end

--------------------------------------------------
-- Minimize
--------------------------------------------------

function UI.minimize(win)

    if not win then
        return
    end

    win.minimized =
        not win.minimized

    if win.minimized
        and UI.focused == win then

        UI.focused = nil

        if #UI.windows > 0 then

            for i =
                #UI.windows,
                1,
                -1
            do

                local other =
                    UI.windows[i]

                if not other.minimized
                    and other.visible then

                    UI.focus(other)

                    break
                end
            end
        end
    end

    UI.drawWindows()
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

    if not win.dragging then
        return
    end

    local screen =
        getScreen()

    local width, height =
        screen.getSize()

    win.x =
        mouseX - win.dragX

    win.y =
        mouseY - win.dragY

    --------------------------------------------------
    -- Keep on screen
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

    if win.y + win.height - 1 >
        height - 1 then

        win.y =
            height - win.height
    end

    --------------------------------------------------
    -- Move terminal
    --------------------------------------------------

    if win.terminal then

        win.terminal.reposition(
            win.x + 1,
            win.y + 1,
            win.width - 2,
            win.height - 2
        )
    end

    UI.drawWindows()
end

--------------------------------------------------
-- Stop dragging
--------------------------------------------------

function UI.stopDrag(win)

    if win then
        win.dragging = false
    end
end

--------------------------------------------------
-- Find window at position
--------------------------------------------------

function UI.getWindowAt(
    x,
    y
)

    --------------------------------------------------
    -- Search from top to bottom
    --------------------------------------------------

    for i =
        #UI.windows,
        1,
        -1
    do

        local win =
            UI.windows[i]

        if win.visible
            and not win.minimized
            and inside(win, x, y) then

            return win
        end
    end

    return nil
end

--------------------------------------------------
-- Handle mouse event
--------------------------------------------------

function UI.handleMouse(
    button,
    x,
    y
)

    --------------------------------------------------
    -- Left click
    --------------------------------------------------

    if button == 1 then

        local win =
            UI.getWindowAt(
                x,
                y
            )

        if not win then
            return
        end

        UI.focus(win)

        --------------------------------------------------
        -- Close
        --------------------------------------------------

        if x ==
            win.x + win.width - 2
            and y == win.y then

            UI.close(win)

            return
        end

        --------------------------------------------------
        -- Minimize
        --------------------------------------------------

        if x >=
            win.x + win.width - 5
            and x <=
            win.x + win.width - 4
            and y == win.y then

            UI.minimize(win)

            return
        end

        --------------------------------------------------
        -- Title bar dragging
        --------------------------------------------------

        if y == win.y then

            UI.startDrag(
                win,
                x,
                y
            )

            return
        end

        --------------------------------------------------
        -- Send click to app
        --------------------------------------------------

        if win.onEvent then

            win.onEvent(
                "mouse_click",
                button,
                x - win.x - 1,
                y - win.y - 1
            )
        end
    end
end

--------------------------------------------------
-- Handle mouse drag
--------------------------------------------------

function UI.handleDrag(
    button,
    x,
    y
)

    local win =
        UI.focused

    if win and win.dragging then

        UI.drag(
            win,
            x,
            y
        )
    end
end

--------------------------------------------------
-- Handle mouse release
--------------------------------------------------

function UI.handleMouseUp(
    button,
    x,
    y
)

    if UI.focused then

        UI.stopDrag(
            UI.focused
        )
    end
end

--------------------------------------------------
-- Get window terminal
--------------------------------------------------

function UI.getTerminal(win)

    if not win then
        return nil
    end

    return win.terminal
end

--------------------------------------------------
-- Redirect to window
--------------------------------------------------

function UI.redirect(win)

    if not win then
        return false
    end

    if not win.terminal then
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
-- Run application in window
--------------------------------------------------

function UI.runInWindow(
    win,
    program
)

    if not win then
        return false
    end

    if not program then
        return false
    end

    local previous =
        term.current()

    --------------------------------------------------
    -- Redirect
    --------------------------------------------------

    term.redirect(
        win.terminal
    )

    --------------------------------------------------
    -- Run
    --------------------------------------------------

    local ok, err =
        pcall(
            shell.run,
            program
        )

    --------------------------------------------------
    -- Restore
    --------------------------------------------------

    term.redirect(
        previous
    )

    --------------------------------------------------
    -- Error
    --------------------------------------------------

    if not ok then

        win.terminal.setCursorPos(
            1,
            win.terminal.getCursorPos()
        )

        win.terminal.setTextColor(
            colors.red
        )

        win.terminal.write(
            tostring(err)
        )

        win.terminal.setTextColor(
            colors.white
        )

        return false
    end

    return true
end

--------------------------------------------------
-- UI event loop
--------------------------------------------------

function UI.handleEvent(event, ...)

    --------------------------------------------------
    -- Mouse
    --------------------------------------------------

    if event == "mouse_click" then

        local button, x, y =
            ...

        UI.handleMouse(
            button,
            x,
            y
        )

    --------------------------------------------------
    -- Mouse drag
    --------------------------------------------------

    elseif event == "mouse_drag" then

        local button, x, y =
            ...

        UI.handleDrag(
            button,
            x,
            y
        )

    --------------------------------------------------
    -- Mouse release
    --------------------------------------------------

    elseif event == "mouse_up" then

        local button, x, y =
            ...

        UI.handleMouseUp(
            button,
            x,
            y
        )
    end
end

--------------------------------------------------
-- Initialize UI
--------------------------------------------------

function UI.init()

    UI.windows = {}
    UI.nextWindowID = 1
    UI.focused = nil

    UI.drawDesktop()
end

--------------------------------------------------
-- Return UI
--------------------------------------------------

return UI
