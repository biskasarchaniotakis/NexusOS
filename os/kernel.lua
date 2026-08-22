-- NexusOS Kernel

term.clear()
term.setCursorPos(1, 1)
term.setCursorBlink(true)

print("Starting NEXUS OS...")
sleep(1)

--------------------------------------------------
-- Load UI
--------------------------------------------------

local UI = dofile("/os/ui.lua")

UI.init()

--------------------------------------------------
-- Screen
--------------------------------------------------

local native = term.native()
local sw, sh = native.getSize()

--------------------------------------------------
-- Terminal process
--------------------------------------------------

local function runTerminal(win)

    local old = term.current()

    term.redirect(win.terminal)

    local ok, err = pcall(function()
        shell.run("/apps/terminal.lua")
    end)

    term.redirect(old)

    if not ok and win.visible then
        win.terminal.setTextColor(colors.red)
        win.terminal.setCursorPos(1, 1)
        win.terminal.write("Terminal error:")
        win.terminal.setCursorPos(1, 2)
        win.terminal.write(tostring(err))
    end
end

--------------------------------------------------
-- Create terminal
--------------------------------------------------

local function createTerminal()

    local offset = (#UI.windows % 4) * 3

    local win = UI.createWindow(
        "Terminal",
        4 + offset,
        3 + offset,
        math.min(52, sw - 2),
        math.min(18, sh - 2)
    )

    return win
end

--------------------------------------------------
-- Start menu launcher
--------------------------------------------------

UI.onLaunch = function(app)

    if app == "terminal" then

        local win = createTerminal()

        -- Run terminal in a coroutine
        -- without stopping the UI.
        parallel.waitForAny(
            function()
                runTerminal(win)
            end,

            function()
                while win.visible do
                    os.pullEvent()
                end
            end
        )

    end
end

--------------------------------------------------
-- Window close
--------------------------------------------------

UI.onClose = function(win)

    win.visible = false

    if win.terminal then
        win.terminal.setVisible(false)
    end

    for i, w in ipairs(UI.windows) do
        if w == win then
            table.remove(UI.windows, i)
            break
        end
    end

    UI.focused = nil

    -- Focus another window
    for i = #UI.windows, 1, -1 do

        local other = UI.windows[i]

        if other.visible
            and not other.minimized then

            UI.focus(other)
            break
        end
    end

    UI.draw()
end

--------------------------------------------------
-- Initial terminal
--------------------------------------------------

local firstTerminal = createTerminal()

--------------------------------------------------
-- GUI event loop
--------------------------------------------------

local function guiLoop()

    while true do

        local event = {
            os.pullEvent()
        }

        if event[1] == "mouse_click"
            or event[1] == "mouse_drag"
            or event[1] == "mouse_up" then

            UI.handleEvent(
                table.unpack(event)
            )
        end
    end
end

--------------------------------------------------
-- Run terminal + GUI together
--------------------------------------------------

parallel.waitForAny(

    guiLoop,

    function()
        runTerminal(firstTerminal)
    end

)
