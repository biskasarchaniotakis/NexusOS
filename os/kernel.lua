-- NexusOS Kernel
-- Simple cooperative application manager

--------------------------------------------------
-- Load UI
--------------------------------------------------

local UI = dofile("/os/ui.lua")

UI.init()

local native = term.native()

--------------------------------------------------
-- Applications
--------------------------------------------------

local apps = {}

--------------------------------------------------
-- Screen size
--------------------------------------------------

local function screenSize()

    local w, h = native.getSize()

    w = tonumber(w) or 51
    h = tonumber(h) or 19

    return w, h
end

--------------------------------------------------
-- Find app
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
-- Draw crash screen
--------------------------------------------------

local function showCrash(app, err)

    if not app or not app.window then
        return
    end

    local terminal =
        app.window.terminal

    if not terminal then
        return
    end

    terminal.setBackgroundColor(colors.black)
    terminal.setTextColor(colors.red)

    terminal.clear()
    terminal.setCursorPos(1, 1)

    terminal.write("APPLICATION CRASHED")

    terminal.setTextColor(colors.white)

    terminal.setCursorPos(1, 3)
    terminal.write("Application: " .. tostring(app.title))

    terminal.setCursorPos(1, 4)
    terminal.write("File: " .. tostring(app.path))

    terminal.setCursorPos(1, 6)
    terminal.setTextColor(colors.red)
    terminal.write("Error:")

    terminal.setTextColor(colors.white)

    --------------------------------------------------
    -- Print wrapped error.
    --------------------------------------------------

    local width, height =
        terminal.getSize()

    width = math.max(1, tonumber(width) or 1)
    height = math.max(1, tonumber(height) or 1)

    local text = tostring(err or "Unknown error")

    local line = 7

    while #text > 0 and line <= height do

        local part = text:sub(1, width)

        terminal.setCursorPos(1, line)
        terminal.write(part)

        text = text:sub(#part + 1)

        line = line + 1
    end

    terminal.setCursorPos(1, math.min(height, line + 1))

    terminal.setTextColor(colors.yellow)
    terminal.write("The application has stopped.")

    terminal.setTextColor(colors.white)

    app.dead = true
    app.crashed = true
    app.error = tostring(err or "Unknown error")

    --------------------------------------------------
    -- Keep window alive.
    --------------------------------------------------

    app.window.visible = true
    app.window.minimized = false

    UI.focus(app.window)
end

--------------------------------------------------
-- Queue event
--------------------------------------------------

local function queue(app, event)

    if not app then
        return
    end

    if app.dead then
        return
    end

    table.insert(
        app.queue,
        event
    )
end

--------------------------------------------------
-- Create application
--------------------------------------------------

local function createApp(path, title)

    if not fs.exists(path) then

        local t = native

        t.setBackgroundColor(colors.black)
        t.setTextColor(colors.red)

        t.setCursorPos(1, 1)

        t.write(
            "Application not found: "
            .. path
        )

        return nil
    end

    local sw, sh =
        screenSize()

    local count =
        #UI.windows

    local offset =
        (count % 4) * 3

    local width =
        math.min(
            46,
            math.max(
                20,
                sw - 4
            )
        )

    local height =
        math.min(
            14,
            math.max(
                8,
                sh - 3
            )
        )

    local x =
        math.max(
            1,
            3 + offset
        )

    local y =
        math.max(
            1,
            2 + offset
        )

    if x + width - 1 > sw then
        x = math.max(1, sw - width + 1)
    end

    if y + height > sh then
        y = math.max(1, sh - height)
    end

    local win =
        UI.createWindow(
            title or fs.getName(path),
            x,
            y,
            width,
            height
        )

    local app = {

        path = path,
        title = title or fs.getName(path),

        window = win,

        queue = {},

        co = nil,

        dead = false,
        crashed = false,
        closing = false,

        error = nil
    }

    --------------------------------------------------
    -- Application coroutine.
    --------------------------------------------------

    app.co = coroutine.create(
        function(firstEvent)

            UI.redirect(win)

            local ok, err =
                pcall(
                    function()

                        local fn =
                            assert(
                                loadfile(path)
                            )

                        fn()

                    end
                )

            UI.restore()

            if not ok then
                error(err)
            end
        end
    )

    table.insert(
        apps,
        app
    )

    --------------------------------------------------
    -- Start application.
    --------------------------------------------------

    local ok, err =
        coroutine.resume(
            app.co
        )

    if not ok then

        showCrash(
            app,
            err
        )

    end

    return app
end

--------------------------------------------------
-- Close application
--------------------------------------------------

local function closeApp(app)

    if not app then
        return
    end

    app.closing = true

    if app.co
        and coroutine.status(app.co) ~= "dead"
    then

        queue(
            app,
            {
                "terminate"
            }
        )
    end

    UI.removeWindow(
        app.window
    )

    for i, a in ipairs(apps) do

        if a == app then

            table.remove(
                apps,
                i
            )

            break
        end
    end
end

--------------------------------------------------
-- Launch
--------------------------------------------------

local function launch(name)

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

        createApp(
            "/apps/settings.lua",
            "Settings"
        )
    end

    UI.draw()
end

UI.onLaunch = launch

--------------------------------------------------
-- Close callback
--------------------------------------------------

UI.onClose = function(win)

    local app = getApp(win)

    if app then
        closeApp(app)
    else
        UI.removeWindow(win)
    end
end

--------------------------------------------------
-- Send event to app
--------------------------------------------------

local function sendToApp(app, event)

    if not app then
        return
    end

    if app.dead then
        return
    end

    if app.closing then
        return
    end

    if not app.window.visible then
        return
    end

    if app.window.minimized then
        return
    end

    local e = {}

    for i = 1, #event do
        e[i] = event[i]
    end

    --------------------------------------------------
    -- Convert screen mouse coordinates into
    -- application-terminal coordinates.
    --------------------------------------------------

    if e[1] == "mouse_click"
        or e[1] == "mouse_drag"
        or e[1] == "mouse_up"
    then

        local sx =
            tonumber(e[3]) or 1

        local sy =
            tonumber(e[4]) or 1

        local tx =
            sx - app.window.x - 1

        local ty =
            sy - app.window.y - 2

        e[3] = tx
        e[4] = ty
    end

    table.insert(
        app.queue,
        e
    )
end

--------------------------------------------------
-- Resume one app
--------------------------------------------------

local function resumeApp(app)

    if not app then
        return
    end

    if app.dead then
        return
    end

    if #app.queue == 0 then
        return
    end

    if not app.co then
        return
    end

    if coroutine.status(app.co) == "dead" then
        return
    end

    local event =
        table.remove(
            app.queue,
            1
        )

    --------------------------------------------------
    -- Give application its terminal.
    --------------------------------------------------

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

        showCrash(
            app,
            err
        )

    elseif coroutine.status(app.co) == "dead" then

        --------------------------------------------------
        -- Normal application exit.
        --------------------------------------------------

        if not app.closing
            and not app.crashed
        then

            app.dead = true

            UI.removeWindow(
                app.window
            )
        end
    end
end

--------------------------------------------------
-- Route mouse
--------------------------------------------------

local function handleMouse(event)

    --------------------------------------------------
    -- UI gets first chance.
    --------------------------------------------------

    local consumed =
        UI.handleEvent(
            table.unpack(event)
        )

    if consumed then
        return
    end

    --------------------------------------------------
    -- Focused app.
    --------------------------------------------------

    local win =
        UI.focused

    if not win then
        return
    end

    if not win.visible
        or win.minimized then
        return
    end

    local app =
        getApp(win)

    if not app then
        return
    end

    --------------------------------------------------
    -- Only application content.
    --------------------------------------------------

    local x =
        tonumber(event[3]) or 0

    local y =
        tonumber(event[4]) or 0

    local inside =
        x >= win.x + 1
        and x < win.x + win.width - 1
        and y >= win.y + 2
        and y < win.y + win.height - 1

    if not inside then
        return
    end

    sendToApp(
        app,
        event
    )
end

--------------------------------------------------
-- Keyboard
--------------------------------------------------

local function handleKeyboard(event)

    local win =
        UI.focused

    if not win then
        return
    end

    if not win.visible
        or win.minimized then
        return
    end

    local app =
        getApp(win)

    if not app then
        return
    end

    sendToApp(
        app,
        event
    )
end

--------------------------------------------------
-- Character
--------------------------------------------------

local function handleChar(event)

    handleKeyboard(event)
end

--------------------------------------------------
-- Timer / paste / other events
--------------------------------------------------

local function broadcast(event)

    for _, app in ipairs(apps) do

        if not app.dead
            and not app.closing
        then

            --------------------------------------------------
            -- Only send general events to the focused app.
            --------------------------------------------------

            if app.window == UI.focused then

                sendToApp(
                    app,
                    event
                )
            end
        end
    end
end

--------------------------------------------------
-- Resize screen
--------------------------------------------------

local function handleResize()

    local sw, sh =
        screenSize()

    for _, app in ipairs(apps) do

        if not app.dead then

            local win =
                app.window

            if win.x + win.width - 1 > sw then

                win.x =
                    math.max(
                        1,
                        sw - win.width + 1
                    )
            end

            if win.y + win.height > sh then

                win.y =
                    math.max(
                        1,
                        sh - win.height
                    )
            end

            if win.surface then

                win.surface.reposition(
                    win.x,
                    win.y,
                    win.width,
                    win.height
                )
            end

            UI.onResize =
                function(resized)

                    local appForResize =
                        getApp(resized)

                    if appForResize then
                        queue(
                            appForResize,
                            {
                                "term_resize"
                            }
                        )
                    end
                end

            if app.window == UI.focused then
                queue(
                    app,
                    {
                        "term_resize"
                    }
                )
            end
        end
    end

    UI.draw()
end

--------------------------------------------------
-- Initial apps
--------------------------------------------------

launch("terminal")

--------------------------------------------------
-- Main loop
--------------------------------------------------

while true do

    --------------------------------------------------
    -- Let queued application events run.
    --------------------------------------------------

    for _, app in ipairs(apps) do
        resumeApp(app)
    end

    --------------------------------------------------
    -- Get next OS event.
    --------------------------------------------------

    local event =
        table.pack(
            os.pullEvent()
        )

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
    then

        handleKeyboard(event)

    --------------------------------------------------
    -- Character
    --------------------------------------------------

    elseif name == "char" then

        handleChar(event)

    --------------------------------------------------
    -- Paste
    --------------------------------------------------

    elseif name == "paste" then

        handleKeyboard(event)

    --------------------------------------------------
    -- Term resize
    --------------------------------------------------

    elseif name == "term_resize" then

        handleResize()

    --------------------------------------------------
    -- Timer
    --------------------------------------------------

    elseif name == "timer"
        or name == "alarm"
        or name == "redstone"
        or name == "disk"
        or name == "disk_eject"
        or name == "modem_message"
        or name == "http_success"
        or name == "http_failure"
        or name == "http_check"
    then

        broadcast(event)
    end

    --------------------------------------------------
    -- Redraw GUI after events.
    --------------------------------------------------

    UI.draw()
end
