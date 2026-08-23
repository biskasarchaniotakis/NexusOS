-- NexusOS Files
-- Graphical file manager

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.setCursorBlink(false)

--------------------------------------------------
-- State
--------------------------------------------------

local currentPath = shell.dir()

if currentPath == "" then
    currentPath = "/"
else
    currentPath = "/" .. currentPath
end

local selected = 1
local scroll = 0
local entries = {}

local lastClickTime = 0
local lastClickIndex = nil

--------------------------------------------------
-- Safe terminal size
--------------------------------------------------

local function getTerminalSize()
    local width, height = term.getSize()

    width = tonumber(width) or 1
    height = tonumber(height) or 1

    if width < 1 then
        width = 1
    end

    if height < 1 then
        height = 1
    end

    return width, height
end

--------------------------------------------------
-- Safe cursor positioning
--------------------------------------------------

local function safeCursor(x, y)
    local width, height = getTerminalSize()

    x = tonumber(x) or 1
    y = tonumber(y) or 1

    x = math.floor(x)
    y = math.floor(y)

    if x < 1 then
        x = 1
    elseif x > width then
        x = width
    end

    if y < 1 then
        y = 1
    elseif y > height then
        y = height
    end

    term.setCursorPos(x, y)
end

--------------------------------------------------
-- Helpers
--------------------------------------------------

local function normalizePath(path)

    if path == nil or path == "" then
        return "/"
    end

    local resolved = shell.resolve(path)

    if not resolved or resolved == "" then
        return "/"
    end

    return "/" .. resolved:gsub("^/+", "")
end

--------------------------------------------------
-- Parent directory
--------------------------------------------------

local function getParent(path)

    path = normalizePath(path)

    if path == "/" then
        return "/"
    end

    local parent = fs.getDir(path)

    if not parent or parent == "" then
        return "/"
    end

    return "/" .. parent
end

--------------------------------------------------
-- List height
--------------------------------------------------

local function getListHeight()

    local _, height = getTerminalSize()

    return math.max(
        1,
        height - 3
    )
end

--------------------------------------------------
-- Change directory
--------------------------------------------------

local function changeDirectory(path)

    path = normalizePath(path)

    if not fs.exists(path) then
        return false
    end

    if not fs.isDir(path) then
        return false
    end

    currentPath = path

    shell.setDir(path)

    selected = 1
    scroll = 0

    return true
end

--------------------------------------------------
-- Load directory
--------------------------------------------------

local function loadDirectory()

    entries = {}

    --------------------------------------------------
    -- Parent
    --------------------------------------------------

    if currentPath ~= "/" then

        table.insert(
            entries,
            {
                name = "..",
                path = getParent(currentPath),
                directory = true,
                parent = true
            }
        )
    end

    --------------------------------------------------
    -- Directory contents
    --------------------------------------------------

    local list = fs.list(currentPath)

    table.sort(
        list,
        function(a, b)

            local ap =
                fs.isDir(
                    fs.combine(
                        currentPath,
                        a
                    )
                )

            local bp =
                fs.isDir(
                    fs.combine(
                        currentPath,
                        b
                    )
                )

            if ap ~= bp then
                return ap
            end

            return a:lower() < b:lower()
        end
    )

    for _, name in ipairs(list) do

        local path =
            fs.combine(
                currentPath,
                name
            )

        table.insert(
            entries,
            {
                name = name,
                path = path,
                directory = fs.isDir(path),
                parent = false
            }
        )
    end

    --------------------------------------------------
    -- Selection
    --------------------------------------------------

    if #entries == 0 then

        selected = 1
        scroll = 0

        return
    end

    if selected < 1 then
        selected = 1
    end

    if selected > #entries then
        selected = #entries
    end

    --------------------------------------------------
    -- Scroll
    --------------------------------------------------

    local maxScroll =
        math.max(
            0,
            #entries - getListHeight()
        )

    if scroll < 0 then
        scroll = 0
    end

    if scroll > maxScroll then
        scroll = maxScroll
    end
end

--------------------------------------------------
-- Format path
--------------------------------------------------

local function displayPath()

    return currentPath
end

--------------------------------------------------
-- Draw header
--------------------------------------------------

local function drawHeader()

    local width, height =
        getTerminalSize()

    term.setBackgroundColor(
        colors.gray
    )

    term.setTextColor(
        colors.white
    )

    --------------------------------------------------
    -- Header background
    --------------------------------------------------

    safeCursor(
        1,
        1
    )

    term.write(
        string.rep(
            " ",
            width
        )
    )

    --------------------------------------------------
    -- Back button
    --------------------------------------------------

    safeCursor(
        1,
        1
    )

    if currentPath == "/" then

        term.setTextColor(
            colors.darkGray
        )

    else

        term.setTextColor(
            colors.white
        )
    end

    term.write("[<]")

    --------------------------------------------------
    -- Path
    --------------------------------------------------

    local pathText =
        displayPath()

    local available =
        math.max(
            1,
            width - 10
        )

    if #pathText > available then

        pathText =
            "..." ..
            pathText:sub(
                math.max(
                    1,
                    #pathText - available + 4
                )
            )
    end

    if width >= 5 then

        safeCursor(
            5,
            1
        )

        term.setTextColor(
            colors.white
        )

        term.write(
            pathText
        )
    end

    --------------------------------------------------
    -- Refresh
    --------------------------------------------------

    if width >= 5 then

        safeCursor(
            width - 4,
            1
        )

        term.setTextColor(
            colors.white
        )

        term.write("[R]")
    end
end

--------------------------------------------------
-- Draw entries
--------------------------------------------------

local function drawEntries()

    local width, height =
        getTerminalSize()

    local listHeight =
        getListHeight()

    term.setBackgroundColor(
        colors.black
    )

    --------------------------------------------------
    -- Clear list area
    --------------------------------------------------

    local lastListY =
        math.min(
            height - 1,
            listHeight + 1
        )

    for y = 2, lastListY do

        safeCursor(
            1,
            y
        )

        term.write(
            string.rep(
                " ",
                width
            )
        )
    end

    --------------------------------------------------
    -- Entries
    --------------------------------------------------

    for row = 1, listHeight do

        local y =
            row + 1

        if y >= height then
            break
        end

        local index =
            scroll + row

        local entry =
            entries[index]

        if not entry then
            break
        end

        --------------------------------------------------
        -- Selection
        --------------------------------------------------

        if index == selected then

            term.setBackgroundColor(
                colors.blue
            )

            term.setTextColor(
                colors.white
            )

        else

            term.setBackgroundColor(
                colors.black
            )

            if entry.directory then

                term.setTextColor(
                    colors.yellow
                )

            else

                term.setTextColor(
                    colors.white
                )
            end
        end

        --------------------------------------------------
        -- Row background
        --------------------------------------------------

        safeCursor(
            1,
            y
        )

        term.write(
            string.rep(
                " ",
                width
            )
        )

        --------------------------------------------------
        -- Icon
        --------------------------------------------------

        if width >= 5 then

            safeCursor(
                2,
                y
            )

            if entry.directory then
                term.write("[DIR]")
            else
                term.write("[FILE]")
            end
        end

        --------------------------------------------------
        -- Name
        --------------------------------------------------

        if width >= 8 then

            local name =
                entry.name

            local maxName =
                math.max(
                    1,
                    width - 9
                )

            if #name > maxName then

                if maxName <= 3 then

                    name =
                        name:sub(
                            1,
                            maxName
                        )

                else

                    name =
                        name:sub(
                            1,
                            maxName - 3
                        )
                        .. "..."
                end
            end

            safeCursor(
                8,
                y
            )

            term.write(
                name
            )
        end
    end
end

--------------------------------------------------
-- Draw footer
--------------------------------------------------

local function drawFooter()

    local width, height =
        getTerminalSize()

    term.setBackgroundColor(
        colors.gray
    )

    term.setTextColor(
        colors.white
    )

    --------------------------------------------------
    -- Footer background
    --------------------------------------------------

    safeCursor(
        1,
        height
    )

    term.write(
        string.rep(
            " ",
            width
        )
    )

    --------------------------------------------------
    -- Item count
    --------------------------------------------------

    if width >= 2 then

        safeCursor(
            2,
            height
        )

        term.write(
            tostring(
                #entries
            )
            .. " items"
        )
    end

    --------------------------------------------------
    -- Open hint
    --------------------------------------------------

    if width >= 18 then

        safeCursor(
            width - 17,
            height
        )

        term.write(
            "Enter: Open"
        )
    end
end

--------------------------------------------------
-- Draw everything
--------------------------------------------------

local function draw()

    term.setBackgroundColor(
        colors.black
    )

    term.clear()

    drawHeader()
    drawEntries()
    drawFooter()
end

--------------------------------------------------
-- Keep selection visible
--------------------------------------------------

local function ensureSelectedVisible()

    local listHeight =
        getListHeight()

    if #entries == 0 then

        selected = 1
        scroll = 0

        return
    end

    if selected < 1 then
        selected = 1
    end

    if selected > #entries then
        selected = #entries
    end

    if selected <= scroll then

        scroll =
            selected - 1
    end

    if selected >
        scroll + listHeight then

        scroll =
            selected - listHeight
    end

    if scroll < 0 then
        scroll = 0
    end

    local maxScroll =
        math.max(
            0,
            #entries - listHeight
        )

    if scroll > maxScroll then
        scroll = maxScroll
    end
end

--------------------------------------------------
-- Open selected
--------------------------------------------------

local function openSelected()

    if #entries == 0 then
        return
    end

    if selected < 1
        or selected > #entries then

        return
    end

    local entry =
        entries[selected]

    if not entry then
        return
    end

    --------------------------------------------------
    -- Directory
    --------------------------------------------------

    if entry.directory then

        if changeDirectory(
            entry.path
        ) then

            loadDirectory()
            draw()
        end

        return
    end

    --------------------------------------------------
    -- File
    --------------------------------------------------

    local width, height =
        getTerminalSize()

    term.setBackgroundColor(
        colors.black
    )

    term.setTextColor(
        colors.white
    )

    local messageY =
        math.max(
            1,
            height - 1
        )

    safeCursor(
        1,
        messageY
    )

    term.write(
        string.rep(
            " ",
            width
        )
    )

    safeCursor(
        math.min(2, width),
        messageY
    )

    term.write(
        "File: "
        .. entry.name
    )

    sleep(0.8)

    draw()
end

--------------------------------------------------
-- Mouse
--------------------------------------------------

local function handleMouse(
    button,
    x,
    y
)

    local width, height =
        getTerminalSize()

    if not x or not y then
        return
    end

    --------------------------------------------------
    -- Back
    --------------------------------------------------

    if y == 1
        and x >= 1
        and x <= 3 then

        if currentPath ~= "/" then

            if changeDirectory(
                getParent(
                    currentPath
                )
            ) then

                loadDirectory()
                draw()
            end
        end

        return
    end

    --------------------------------------------------
    -- Refresh
    --------------------------------------------------

    if width >= 5
        and y == 1
        and x >= width - 4
        and x <= width then

        loadDirectory()
        draw()

        return
    end

    --------------------------------------------------
    -- File list
    --------------------------------------------------

    if y >= 2
        and y < height then

        local row =
            y - 1

        local index =
            scroll + row

        if index < 1
            or index > #entries then

            return
        end

        --------------------------------------------------
        -- Select
        --------------------------------------------------

        if selected == index then

            local now =
                os.epoch(
                    "utc"
                )

            if lastClickIndex == index
                and now - lastClickTime < 500 then

                openSelected()

                lastClickIndex = nil
                lastClickTime = 0

                return
            end

            lastClickTime = now
            lastClickIndex = index

        else

            selected = index

            lastClickTime =
                os.epoch(
                    "utc"
                )

            lastClickIndex = index
        end

        draw()
    end
end

--------------------------------------------------
-- Keyboard
--------------------------------------------------

local function handleKey(key)

    if not key then
        return
    end

    --------------------------------------------------
    -- UP
    --------------------------------------------------

    if key == keys.up then

        if #entries > 0 then

            selected =
                math.max(
                    1,
                    selected - 1
                )

            ensureSelectedVisible()
            draw()
        end

    --------------------------------------------------
    -- DOWN
    --------------------------------------------------

    elseif key == keys.down then

        if #entries > 0 then

            selected =
                math.min(
                    #entries,
                    selected + 1
                )

            ensureSelectedVisible()
            draw()
        end

    --------------------------------------------------
    -- ENTER
    --------------------------------------------------

    elseif key == keys.enter then

        openSelected()

    --------------------------------------------------
    -- BACKSPACE
    --------------------------------------------------

    elseif key == keys.backspace then

        if currentPath ~= "/" then

            if changeDirectory(
                getParent(
                    currentPath
                )
            ) then

                loadDirectory()
                draw()
            end
        end

    --------------------------------------------------
    -- HOME
    --------------------------------------------------

    elseif key == keys.home then

        selected = 1
        scroll = 0

        draw()

    --------------------------------------------------
    -- END
    --------------------------------------------------

    elseif key == keys["end"] then

        if #entries > 0 then

            selected =
                #entries

            ensureSelectedVisible()
            draw()
        end

    --------------------------------------------------
    -- R
    --------------------------------------------------

    elseif key == keys.r then

        loadDirectory()
        draw()
    end
end

--------------------------------------------------
-- Initialize
--------------------------------------------------

if not changeDirectory(
    currentPath
) then

    currentPath = "/"

    changeDirectory("/")
end

loadDirectory()
draw()

--------------------------------------------------
-- Event loop
--------------------------------------------------

while true do

    local event =
        table.pack(
            os.pullEvent()
        )

    local name =
        event[1]

    if name == "mouse_click" then

        handleMouse(
            event[2],
            event[3],
            event[4]
        )

    elseif name == "key" then

        handleKey(
            event[2]
        )

    elseif name == "term_resize" then

        loadDirectory()
        draw()
    end
end
