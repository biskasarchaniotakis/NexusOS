-- NexusOS Kernel

--------------------------------------------------
-- Load UI
--------------------------------------------------

local UI = dofile("/os/ui.lua")

--------------------------------------------------
-- Start UI
--------------------------------------------------

UI.init()

--------------------------------------------------
-- Desktop
--------------------------------------------------

local screen = term.native()

local width, height =
    screen.getSize()

--------------------------------------------------
-- Open Terminal
--------------------------------------------------

local terminalWindow =
    UI.createWindow(
        "Terminal",
        5,
        3,
        math.min(50, width - 2),
        math.min(18, height - 2)
    )

--------------------------------------------------
-- Run an application
--------------------------------------------------

local function runApp(win, path)
    if not fs.exists(path) then

        local old = term.current()

        term.redirect(
            win.terminal
        )

        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.red)

        term.clear()
        term.setCursorPos(1, 1)

        print("Application not found:")
        print(path)

        term.redirect(old)

        return
    end

    --------------------------------------------------
    -- Run app in its window
    --------------------------------------------------

    local old = term.current()

    term.redirect(
        win.terminal
    )

    local ok, err =
        pcall(
            function()
                shell.run(path)
            end
        )

    term.redirect(old)

    --------------------------------------------------
    -- Application crashed
    --------------------------------------------------

    if not ok then

        term.redirect(
            win.terminal
        )

        win.terminal.setTextColor(
            colors.red
        )

        win.terminal.setCursorPos(
            1,
            win.terminal.getCursorPos()
        )

        win.terminal.write(
            "Application crashed: "
                .. tostring(err)
        )

        term.redirect(old)
    end
end

--------------------------------------------------
-- Start Terminal
--------------------------------------------------

runApp(
    terminalWindow,
    "/apps/terminal.lua"
)

--------------------------------------------------
-- Main NexusOS event loop
--------------------------------------------------

while true do

    local event = {
        os.pullEvent()
    }

    --------------------------------------------------
    -- Mouse click
    --------------------------------------------------

    if event[1] == "mouse_click" then

        UI.handleEvent(
            table.unpack(event)
        )

    --------------------------------------------------
    -- Mouse drag
    --------------------------------------------------

    elseif event[1] == "mouse_drag" then

        UI.handleEvent(
            table.unpack(event)
        )

    --------------------------------------------------
    -- Mouse release
    --------------------------------------------------

    elseif event[1] == "mouse_up" then

        UI.handleEvent(
            table.unpack(event)
        )

    --------------------------------------------------
    -- Keyboard
    --------------------------------------------------

    elseif event[1] == "key" then

        --------------------------------------------------
        -- F2 = new terminal
        --------------------------------------------------

        if event[2] == keys.f2 then

            local newTerminal =
                UI.createWindow(
                    "Terminal",
                    8,
                    5,
                    math.min(50, width - 2),
                    math.min(18, height - 2)
                )

            --------------------------------------------------
            -- Start terminal
            --
            -- NOTE:
            -- This runs synchronously.
            --------------------------------------------------

            runApp(
                newTerminal,
                "/apps/terminal.lua"
            )
        end
    end
end
