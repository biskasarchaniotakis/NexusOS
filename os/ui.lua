-- NexusOS Kernel
-- Fixed application environment and event routing

--------------------------------------------------
-- Boot
--------------------------------------------------

term.clear()
term.setCursorPos(1, 1)
term.setCursorBlink(true)

print("Starting NEXUS OS...")
sleep(1)

--------------------------------------------------
-- UI
--------------------------------------------------

local UI = dofile("/os/ui.lua")

UI.init()

local native = term.native()

local screenW, screenH =
    native.getSize()

--------------------------------------------------
-- Applications
--------------------------------------------------

local apps = {}

--------------------------------------------------
-- Find app for window
--------------------------------------------------

local function getApp(win)

    for _, app in ipairs(apps) do

        if app.window == win then
            return app
        end

    end

    return nil
end

--------------------------------------------------
-- Error display
--------------------------------------------------

local function showError(app, message)

    if not app
        or not app.window
        or not app.window.terminal then
        return
    end

    local t =
        app.window.terminal

    t.setVisible(true)

    t.setBackgroundColor(
        colors.black
    )

    t.setTextColor(
        colors.red
    )

    t.clear()

    t.setCursorPos(1, 1)

    t.write(
        "APPLICATION ERROR"
    )

    local width, height =
        t.getSize()

    local text =
        tostring(message)

    local y = 3

    while #text > 0
        and y <= height
    do

        local line =
            text:sub(1, width)

        text =
            text:sub(#line + 1)

        t.setCursorPos(1, y)
        t.write(line)

        y = y + 1
    end
end

--------------------------------------------------
-- Create application
--------------------------------------------------

local function createApp(path, title)

    if not fs.exists(path) then

        print(
            "Application not found: "
            .. path
        )

        return nil
    end

    local offset =
        (#UI.windows % 4) * 3

    local width =
        math.min(
            52,
            math.max(
                10,
                screenW - 2
            )
        )

    local height =
        math.min(
            18,
            math.max(
                5,
                screenH - 2
            )
        )

    local win =
        UI.createWindow(
            title,
            4 + offset,
            3 + offset,
            width,
            height
        )

    local app = {

        window = win,

        path = path,

        queue = {},

        dead = false,

        closing = false,

        resizeQueued = false
    }

    table.insert(
        apps,
        app
    )

    --------------------------------------------------
    -- IMPORTANT:
    --
    -- Explicit CraftOS environment.
    --
    -- This prevents shell/fs/term/etc from becoming
    -- nil when the application is loaded.
    --------------------------------------------------

    local appEnv = {}

    setmetatable(
        appEnv,
        {
            __index = _G
        }
    )

    --------------------------------------------------
    -- Explicitly guarantee CraftOS APIs.
    --------------------------------------------------

    appEnv.shell = shell
    appEnv.fs = fs
    appEnv.term = term
    appEnv.colors = colors
    appEnv.keys = keys
    appEnv.os = os
    appEnv.window = window
    appEnv.peripheral = peripheral
    appEnv.redstone = redstone
    appEnv.textutils = textutils
    appEnv.paintutils = paintutils

    --------------------------------------------------
    -- Load application using explicit environment.
    --------------------------------------------------

    local program, loadError =
        loadfile(
            path,
            "t",
            appEnv
        )

    if not program then

        showError(
            app,
            loadError
        )

        app.dead = true

        return app
    end

    --------------------------------------------------
    -- Application coroutine
    --------------------------------------------------

    app.co =
        coroutine.create(
            function()

                local old =
                    term.current()

                term.redirect(
                    win.terminal
                )

                local ok, err =
                    pcall(
                        function()
                            program()
                        end
                    )

                term.redirect(old)

                if not ok then

                    if not app.closing then

                        showError(
                            app,
                            err
                        )

                    end

                end

                app.dead = true
            end
        )

    --------------------------------------------------
    -- Start program
    --------------------------------------------------

    local old =
        term.current()

    term.redirect(
        win.terminal
    )

    local ok, err =
        coroutine.resume(
            app.co
        )

    term.redirect(old)

    if not ok then

        showError(
            app,
            err
        )

        app.dead = true
    end

    return app
end

--------------------------------------------------
-- Queue event
--------------------------------------------------

local function sendEvent(app, event)

    if not app
        or app.dead
        or app.closing then
        return
    end

    if not app.window.visible
        or app.window.minimized then
        return
    end

    --------------------------------------------------
    -- Convert screen mouse coordinates into
    -- application terminal coordinates.
    --------------------------------------------------

    if event[1] == "mouse_click"
        or event[1] == "mouse_drag"
        or event[1] == "mouse_up"
    then

        local button =
            event[2]

        local x =
            event[3]
            - app.window.x
            - 1

        local y =
            event[4]
            - app.window.y
            - 2

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
            and #app.queue > 0
        then

            local event =
                table.remove(
                    app.queue,
                    1
                )

            if event[1] ==
                "term_resize"
            then
                app.resizeQueued = false
            end

            if coroutine.status(app.co)
                ~= "dead"
            then

                local old =
                    term.current()

                term.redirect(
                    app.window.terminal
                )

                local ok, err =
                    coroutine.resume(
                        app.co,
                        table.unpack(event)
                    )

                term.redirect(old)

                if not ok then

                    app.dead = true

                    if not app.closing then

                        showError(
                            app,
                            err
                        )

                    end
                end
            end
        end
    end
end

--------------------------------------------------
-- Cleanup
--------------------------------------------------

local function cleanup()

    for i = #apps, 1, -1 do

        local app =
            apps[i]

        if app.dead then

            table.remove(
                apps,
                i
            )

            if app.window then

                app.window.visible = false

                if app.window.terminal then

                    app.window.terminal.setVisible(
                        false
                    )

                end
            end
        end
    end
end

--------------------------------------------------
-- Resize callback
--------------------------------------------------

UI.onResize =
    function(win)

        local app =
            getApp(win)

        if not app then
            return
        end

        if app.resizeQueued then
            return
        end

        app.resizeQueued = true

        table.insert(
            app.queue,
            {
                "term_resize"
            }
        )
    end

--------------------------------------------------
-- Close callback
--------------------------------------------------

UI.onClose =
    function(win)

        local app =
            getApp(win)

        if app then

            app.closing = true

            table.insert(
                app.queue,
                {
                    "terminate"
                }
            )

            app.dead = true

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
        -- Focus next window.
        --------------------------------------------------

        for i =
            #UI.windows,
            1,
            -1
        do

            local other =
                UI.windows[i]

            if other.visible
                and not other.minimized
            then

                UI.focus(other)

                break
            end
        end

        UI.draw()
    end

--------------------------------------------------
-- Launch callback
--------------------------------------------------

UI.onLaunch =
    function(name)

        if name == "terminal" then

            createApp(
                "/apps/terminal.lua",
                "Terminal"
            )

        elseif name == "files" then

            createApp(
                "/apps/files.lua",
                "Files"
            )

        elseif name == "settings" then

            if fs.exists(
                "/apps/settings.lua"
            ) then

                createApp(
                    "/apps/settings.lua",
                    "Settings"
                )

            else

                print(
                    "Settings app not installed."
                )

            end
        end

        UI.draw()
    end

--------------------------------------------------
-- Mouse handling
--------------------------------------------------

local function handleMouse(event)

    --------------------------------------------------
    -- UI gets first chance.
    --
    -- This handles dragging, resizing, minimize,
    -- close, taskbar and Start menu.
    --------------------------------------------------

    local consumed =
        UI.handleEvent(
            table.unpack(event)
        )

    if consumed then
        return
    end

    --------------------------------------------------
    -- Send content clicks to focused app.
    --------------------------------------------------

    local win =
        UI.focused

    if not win
        or not win.visible
        or win.minimized
    then
        return
    end

    local x =
        event[3]

    local y =
        event[4]

    --------------------------------------------------
    -- Application content area.
    --------------------------------------------------

    if x < win.x + 1
        or x >= win.x + win.width - 1
        or y < win.y + 2
        or y >= win.y + win.height - 1
    then
        return
    end

    local app =
        getApp(win)

    if app then

        sendEvent(
            app,
            event
        )

    end
end

--------------------------------------------------
-- Keyboard handling
--------------------------------------------------

local function handleKeyboard(event)

    local win =
        UI.focused

    if not win
        or not win.visible
        or win.minimized
    then
        return
    end

    local app =
        getApp(win)

    if app then

        sendEvent(
            app,
            event
        )

    end
end

--------------------------------------------------
-- Start Terminal
--------------------------------------------------

createApp(
    "/apps/terminal.lua",
    "Terminal"
)

UI.draw()

--------------------------------------------------
-- Main event loop
--------------------------------------------------

while true do

    local event = {
        os.pullEvent()
    }

    local name =
        event[1]

    --------------------------------------------------
    -- Mouse
    --------------------------------------------------

    if name == "mouse_click"
        or name == "mouse_drag"
        or name == "mouse_up"
    then

        handleMouse(event)

    --------------------------------------------------
    -- Keyboard
    --------------------------------------------------

    elseif name == "key"
        or name == "key_up"
        or name == "char"
        or name == "paste"
    then

        handleKeyboard(event)

    --------------------------------------------------
    -- Resize
    --------------------------------------------------

    elseif name == "term_resize" then

        for _, app in ipairs(apps) do

            if not app.resizeQueued then

                app.resizeQueued = true

                table.insert(
                    app.queue,
                    {
                        "term_resize"
                    }
                )

            end
        end
    end

    --------------------------------------------------
    -- Run application events.
    --------------------------------------------------

    resumeApps()

    --------------------------------------------------
    -- Remove dead apps.
    --------------------------------------------------

    cleanup()
end
