-- NexusOS Kernel
-- Event-routed application manager

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

local native = term.native()
local screenW, screenH = native.getSize()

--------------------------------------------------
-- Application processes
--------------------------------------------------

local apps = {}

--------------------------------------------------
-- Create an application
--------------------------------------------------

local function createApp(path, title)

    if not fs.exists(path) then
        print("App not found: " .. path)
        return nil
    end

    local offset = (#UI.windows % 4) * 3

    local win = UI.createWindow(
        title or fs.getName(path),
        4 + offset,
        3 + offset,
        math.min(52, screenW - 2),
        math.min(18, screenH - 2)
    )

    local app = {
        window = win,
        path = path,
        queue = {},
        dead = false
    }

    table.insert(apps, app)

    --------------------------------------------------
    -- Application coroutine
    --------------------------------------------------

    app.co = coroutine.create(function()

        local old = term.current()

        term.redirect(win.terminal)

        local ok, err = pcall(function()
            shell.run(path)
        end)

        term.redirect(old)

        if not ok and win.visible then

            win.terminal.setTextColor(colors.red)
            win.terminal.setCursorPos(1, 1)

            win.terminal.write(
                "Application error:"
            )

            win.terminal.setCursorPos(1, 2)

            win.terminal.write(
                tostring(err)
            )

            sleep(2)
        end

        app.dead = true
    end)

    --------------------------------------------------
    -- Start application
    --------------------------------------------------

    local old = term.current()

    term.redirect(win.terminal)

    local ok, err =
        coroutine.resume(app.co)

    term.redirect(old)

    if not ok then
        print("Failed to start " .. path)
        print(err)
        app.dead = true
    end

    return app
end

--------------------------------------------------
-- Remove dead applications
--------------------------------------------------

local function cleanupApps()

    for i = #apps, 1, -1 do

        local app = apps[i]

        if app.dead
            or not app.window.visible then

            table.remove(apps, i)
        end
    end
end

--------------------------------------------------
-- Find app belonging to window
--------------------------------------------------

local function getAppForWindow(win)

    for _, app in ipairs(apps) do

        if app.window == win then
            return app
        end
    end

    return nil
end

--------------------------------------------------
-- Send event to application
--------------------------------------------------

local function sendToApp(app, event)

    if not app
        or app.dead
        or not app.window.visible
        or app.window.minimized then

        return
    end

    --------------------------------------------------
    -- Translate mouse coordinates
    --------------------------------------------------

    if event[1] == "mouse_click"
        or event[1] == "mouse_up"
        or event[1] == "mouse_drag" then

        local button = event[2]

        local x =
            event[3] - app.window.x - 1

        local y =
            event[4] - app.window.y - 2

        event = {
            event[1],
            button,
            x,
            y
        }
    end

    table.insert(
        app.queue,
        event
    )
end

--------------------------------------------------
-- Resume applications
--------------------------------------------------

local function resumeApps()

    for _, app in ipairs(apps) do

        if not app.dead
            and #app.queue > 0 then

            local event =
                table.remove(
                    app.queue,
                    1
                )

            if coroutine.status(app.co)
                ~= "dead" then

                local old = term.current()

                --------------------------------------------------
                -- Give application its terminal
                --------------------------------------------------

                term.redirect(
                    app.window.terminal
                )

                local ok, err =
                    coroutine.resume(
                        app.co,
                        table.unpack(event)
                    )

                --------------------------------------------------
                -- Restore native screen
                --------------------------------------------------

                term.redirect(old)

                if not ok then

                    app.dead = true

                    if app.window.visible then

                        app.window.terminal.setTextColor(
                            colors.red
                        )

                        app.window.terminal.setCursorPos(
                            1,
                            1
                        )

                        app.window.terminal.write(
                            "Application crashed:"
                        )

                        app.window.terminal.setCursorPos(
                            1,
                            2
                        )

                        app.window.terminal.write(
                            tostring(err)
                        )
                    end
                end
            end
        end
    end
end

--------------------------------------------------
-- Launch apps from Start Menu
--------------------------------------------------

UI.onLaunch = function(appName)

    if appName == "terminal" then

        createApp(
            "/apps/terminal.lua",
            "Terminal"
        )

    elseif appName == "files" then

        if fs.exists("/apps/files.lua") then

            createApp(
                "/apps/files.lua",
                "Files"
            )

        else

            print("Files app not found.")
        end

    elseif appName == "settings" then

        if fs.exists("/apps/settings.lua") then

            createApp(
                "/apps/settings.lua",
                "Settings"
            )

        else

            print("Settings app not found.")
        end
    end

    UI.draw()
end

--------------------------------------------------
-- Close window
--------------------------------------------------

UI.onClose = function(win)

    local app = getAppForWindow(win)

    --------------------------------------------------
    -- Tell application to terminate
    --------------------------------------------------

    if app and not app.dead then

        table.insert(
            app.queue,
            {
                "terminate"
            }
        )

        app.dead = true
    end

    --------------------------------------------------
    -- Remove window
    --------------------------------------------------

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

    --------------------------------------------------
    -- Remove app
    --------------------------------------------------

    for i, a in ipairs(apps) do

        if a.window == win then

            table.remove(
                apps,
                i
            )

            break
        end
    end

    UI.focused = nil

    --------------------------------------------------
    -- Focus another window
    --------------------------------------------------

    for i = #UI.windows, 1, -1 do

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
-- Mouse event routing
--------------------------------------------------

local function handleMouse(event)

    local name = event[1]

    local button = event[2]
    local x = event[3]
    local y = event[4]

    --------------------------------------------------
    -- First give UI the event
    --
    -- This handles:
    -- X
    -- minimize
    -- dragging
    -- taskbar
    -- start menu
    --------------------------------------------------

    UI.handleEvent(
        table.unpack(event)
    )

    --------------------------------------------------
    -- Mouse click / drag inside focused window
    --------------------------------------------------

    local focused =
        UI.focused

    if not focused
        or not focused.visible
        or focused.minimized then

        return
    end

    --------------------------------------------------
    -- Check whether mouse is inside app area
    --------------------------------------------------

    local inside =
        x >= focused.x + 1
        and x < focused.x + focused.width - 1
        and y >= focused.y + 2
        and y < focused.y + focused.height - 1

    if not inside then
        return
    end

    --------------------------------------------------
    -- Don't send window-manager actions to app
    --------------------------------------------------

    if name == "mouse_click"
        or name == "mouse_drag"
        or name == "mouse_up" then

        local app =
            getAppForWindow(focused)

        if app then

            sendToApp(
                app,
                event
            )
        end
    end
end

--------------------------------------------------
-- Keyboard routing
--------------------------------------------------

local function handleKeyboard(event)

    local focused =
        UI.focused

    if not focused
        or not focused.visible
        or focused.minimized then

        return
    end

    local app =
        getAppForWindow(focused)

    if app then

        sendToApp(
            app,
            event
        )
    end
end

--------------------------------------------------
-- Start first terminal
--------------------------------------------------

createApp(
    "/apps/terminal.lua",
    "Terminal"
)

UI.draw()

--------------------------------------------------
-- MAIN NEXUSOS LOOP
--------------------------------------------------

while true do

    local event = {
        os.pullEvent()
    }

    local name = event[1]

    --------------------------------------------------
    -- Mouse
    --------------------------------------------------

    if name == "mouse_click"
        or name == "mouse_drag"
        or name == "mouse_up" then

        handleMouse(event)

    --------------------------------------------------
    -- Keyboard
    --------------------------------------------------

    elseif name == "key"
        or name == "key_up"
        or name == "char"
        or name == "paste" then

        handleKeyboard(event)

    --------------------------------------------------
    -- Timer
    --------------------------------------------------

    elseif name == "timer" then

        handleKeyboard(event)

    end

    --------------------------------------------------
    -- Let applications process queued events
    --------------------------------------------------

    resumeApps()

    --------------------------------------------------
    -- Clean dead applications
    --------------------------------------------------

    cleanupApps()

end
