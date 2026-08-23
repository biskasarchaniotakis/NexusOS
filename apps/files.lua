-- NexusOS Files
-- Graphical file manager
--
-- Defensive version:
-- * Never trusts term.getSize() to return valid numbers
-- * Never passes nil coordinates to terminal functions
-- * Does not require shell.dir() to start
-- * Handles tiny application windows
-- * Supports keyboard navigation
-- * Supports mouse selection / double click
-- * Supports directories and basic file viewing

--------------------------------------------------
-- Terminal setup
--------------------------------------------------

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.setCursorBlink(false)

--------------------------------------------------
-- State
--------------------------------------------------

local currentPath = "/"
local selected = 1
local scroll = 0
local entries = {}

local lastClickTime = 0
local lastClickIndex = nil

--------------------------------------------------
-- Safe terminal size
--------------------------------------------------

local function getSize()
    local w, h = term.getSize()

    w = tonumber(w)
    h = tonumber(h)

    if not w or w < 1 then
        w = 1
    end

    if not h or h < 1 then
        h = 1
    end

    return math.floor(w), math.floor(h)
end

--------------------------------------------------
-- Safe number
--------------------------------------------------

local function number(value, fallback)
    value = tonumber(value)

    if not value then
        return fallback or 1
    end

    return math.floor(value)
end

--------------------------------------------------
-- Safe cursor position
--------------------------------------------------

local function cursor(x, y)
    local width, height = getSize()

    x = number(x, 1)
    y = number(y, 1)

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
-- Safe text
--------------------------------------------------

local function writeAt(x, y, text)
    local width = getSize()

    cursor(x, y)

    text = tostring(text or "")

    if #text > width - x + 1 then
        text = text:sub(1, math.max(0, width - x + 1))
    end

    if #text > 0 then
        term.write(text)
    end
end

--------------------------------------------------
-- Normalize path
--------------------------------------------------

local function normalizePath(path)

    if not path or path == "" then
        return "/"
    end

    path = tostring(path)

    -- Convert backslashes just in case.
    path = path:gsub("\\", "/")

    -- Make absolute.
    if path:sub(1, 1) ~= "/" then
        path = "/" .. path
    end

    -- Resolve ., .. manually.
    local parts = {}

    for part in path:gmatch("[^/]+") do

        if part == ".." then

            if #parts > 0 then
                table.remove(parts)
            end

        elseif part ~= "." and part ~= "" then
            table.insert(parts, part)
        end
    end

    if #parts == 0 then
        return "/"
    end

    return "/" .. table.concat(parts, "/")
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

    return normalizePath(parent)
end

--------------------------------------------------
-- List height
--------------------------------------------------

local function getListHeight()

    local _, height = getSize()

    return math.max(
        1,
        height - 4
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
    -- Contents
    --------------------------------------------------

    local ok, list = pcall(
        fs.list,
        currentPath
    )

    if not ok or type(list) ~= "table" then
        list = {}
    end

    --------------------------------------------------
    -- Sort
    --------------------------------------------------

    table.sort(
        list,
        function(a, b)

            local pathA =
                fs.combine(
                    currentPath,
                    a
                )

            local pathB =
                fs.combine(
                    currentPath,
                    b
                )

            local dirA = false
            local dirB = false

            pcall(
                function()
                    dirA = fs.isDir(pathA)
                end
            )

            pcall(
                function()
                    dirB = fs.isDir(pathB)
                end
            )

            if dirA ~= dirB then
                return dirA
            end

            return tostring(a):lower()
                < tostring(b):lower()
        end
    )

    --------------------------------------------------
    -- Create entries
    --------------------------------------------------

    for _, name in ipairs(list) do

        local path =
            fs.combine(
                currentPath,
                name
            )

        local directory = false

        pcall(
            function()
                directory = fs.isDir(path)
            end
        )

        table.insert(
            entries,
            {
                name = tostring(name),
                path = path,
                directory = directory,
                parent = false
            }
        )
    end

    --------------------------------------------------
    -- Fix selection
    --------------------------------------------------

    if #entries == 0 then

        selected = 1
        scroll = 0

        return
    end

    selected = math.max(
        1,
        math.min(
            selected,
            #entries
        )
    )

    --------------------------------------------------
    -- Fix scroll
    --------------------------------------------------

    local listHeight =
        getListHeight()

    local maxScroll =
        math.max(
            0,
            #entries - listHeight
        )

    scroll = math.max(
        0,
        math.min(
            scroll,
            maxScroll
        )
    )
end

--------------------------------------------------
-- Keep selection visible
--------------------------------------------------

local function ensureSelectedVisible()

    if #entries == 0 then
        selected = 1
        scroll = 0
        return
    end

    selected = math.max(
        1,
        math.min(
            selected,
            #entries
        )
    )

    local height =
        getListHeight()

    if selected <= scroll then
        scroll = selected - 1
    end

    if selected > scroll + height then
        scroll = selected - height
    end

    scroll = math.max(
        0,
        math.min(
            scroll,
            math.max(
                0,
                #entries - height
            )
        )
    )
end

--------------------------------------------------
-- Clear line
--------------------------------------------------

local function clearLine(y, color)

    local width = getSize()

    cursor(1, y)

    term.setBackgroundColor(
        color or colors.black
    )

    term.write(
        string.rep(
            " ",
            width
        )
    )
end

--------------------------------------------------
-- Draw header
--------------------------------------------------

local function drawHeader()

    local width = getSize()

    term.setBackgroundColor(
        colors.gray
    )

    term.setTextColor(
        colors.white
    )

    clearLine(
        1,
        colors.gray
    )

    --------------------------------------------------
    -- Back
    --------------------------------------------------

    cursor(1, 1)

    if currentPath == "/" then
        term.setTextColor(colors.darkGray)
    else
        term.setTextColor(colors.white)
    end

    term.write("[<]")

    --------------------------------------------------
    -- Path
    --------------------------------------------------

    local pathText =
        tostring(currentPath)

    local available =
        math.max(
            1,
            width - 9
        )

    if #pathText > available then

        if available <= 3 then

            pathText =
                pathText:sub(
                    1,
                    available
                )

        else

            pathText =
                "..." ..
                pathText:sub(
                    math.max(
                        1,
                        #pathText -
                        available + 4
                    )
                )
        end
    end

    cursor(5, 1)

    term.setTextColor(
        colors.white
    )

    term.write(pathText)

    --------------------------------------------------
    -- Refresh
    --------------------------------------------------

    if width >= 5 then

        cursor(
            math.max(
                1,
                width - 3
            ),
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
        getSize()

    local visible =
        getListHeight()

    --------------------------------------------------
    -- Clear content area
    --------------------------------------------------

    term.setBackgroundColor(
        colors.black
    )

    term.setTextColor(
        colors.white
    )

    if height >= 2 then

        for y = 2, height - 1 do

            cursor(1, y)

            term.write(
                string.rep(
                    " ",
                    width
                )
            )
        end
    end

    --------------------------------------------------
    -- Entries
    --------------------------------------------------

    for row = 1, visible do

        local index =
            scroll + row

        local entry =
            entries[index]

        if not entry then
            break
        end

        local y =
            row + 1

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
        -- Full row
        --------------------------------------------------

        cursor(1, y)

        term.write(
            string.rep(
                " ",
                width
            )
        )

        --------------------------------------------------
        -- Icon
        --------------------------------------------------

        cursor(2, y)

        if entry.directory then
            term.write("[DIR]")
        else
            term.write("[FILE]")
        end

        --------------------------------------------------
        -- Name
        --------------------------------------------------

        local name =
            tostring(entry.name or "")

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

        cursor(8, y)

        term.write(name)
    end
end

--------------------------------------------------
-- Draw footer
--------------------------------------------------

local function drawFooter()

    local width, height =
        getSize()

    if height < 1 then
        return
    end

    term.setBackgroundColor(
        colors.gray
    )

    term.setTextColor(
        colors.white
    )

    clearLine(
        height,
        colors.gray
    )

    cursor(
        2,
        height
    )

    term.write(
        tostring(#entries)
        .. " items"
    )

    if width >= 20 then

        cursor(
            width - 17,
            height
        )

        term.write(
            "Enter: Open"
        )
    end
end

--------------------------------------------------
-- Draw
--------------------------------------------------

local function draw()

    drawHeader()
    drawEntries()
    drawFooter()
end

--------------------------------------------------
-- Show error message
--------------------------------------------------

local function showMessage(message)

    local width, height =
        getSize()

    term.setBackgroundColor(
        colors.black
    )

    term.setTextColor(
        colors.red
    )

    clearLine(
        math.max(1, height - 1),
        colors.black
    )

    cursor(
        1,
        math.max(1, height - 1)
    )

    local text =
        tostring(message or "Error")

    if #text > width then
        text = text:sub(1, width)
    end

    term.write(text)

    sleep(0.8)

    draw()
end

--------------------------------------------------
-- Open selected
--------------------------------------------------

local function openSelected()

    if #entries == 0 then
        return
    end

    if selected < 1
        or selected > #entries
    then
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
    -- File viewer
    --------------------------------------------------

    local ok, file =
        pcall(
            fs.open,
            entry.path,
            "r"
        )

    if not ok or not file then

        showMessage(
            "Unable to open "
            .. tostring(entry.name)
        )

        return
    end

    local okRead, content =
        pcall(
            function()
                return file.readAll()
            end
        )

    pcall(
        function()
            file.close()
        end
    )

    if not okRead then

        showMessage(
            "Unable to read "
            .. tostring(entry.name)
        )

        return
    end

    content =
        tostring(content or "")

    --------------------------------------------------
    -- Viewer
    --------------------------------------------------

    local width, height =
        getSize()

    term.setBackgroundColor(
        colors.black
    )

    term.setTextColor(
        colors.white
    )

    term.clear()

    cursor(1, 1)

    term.setTextColor(
        colors.yellow
    )

    local title =
        "File: "
        .. tostring(entry.name)

    if #title > width then
        title = title:sub(1, width)
    end

    term.write(title)

    term.setTextColor(
        colors.white
    )

    local lineNumber = 3

    for textLine in (
        content .. "\n"
    ):gmatch("(.-)\n") do

        if lineNumber >= height then
            break
        end

        cursor(
            1,
            lineNumber
        )

        local line =
            tostring(textLine)

        if #line > width then
            line =
                line:sub(
                    1,
                    width
                )
        end

        term.write(line)

        lineNumber =
            lineNumber + 1
    end

    --------------------------------------------------
    -- Return message
    --------------------------------------------------

    if height >= 1 then

        cursor(
            1,
            height
        )

        term.setTextColor(
            colors.gray
        )

        local message =
            "Press any key to return"

        if #message <= width then
            term.write(message)
        end
    end

    term.setTextColor(
        colors.white
    )

    --------------------------------------------------
    -- Wait
    --------------------------------------------------

    os.pullEvent("key")

    draw()
end

--------------------------------------------------
-- Mouse click
--------------------------------------------------

local function handleMouse(
    button,
    x,
    y
)

    local width, height =
        getSize()

    x = number(x, 0)
    y = number(y, 0)

    --------------------------------------------------
    -- Back
    --------------------------------------------------

    if y == 1
        and x >= 1
        and x <= 3
    then

        if currentPath ~= "/" then

            changeDirectory(
                getParent(currentPath)
            )

            loadDirectory()
            draw()
        end

        return
    end

    --------------------------------------------------
    -- Refresh
    --------------------------------------------------

    if y == 1
        and width >= 5
        and x >= math.max(1, width - 4)
        and x <= width
    then

        loadDirectory()
        draw()

        return
    end

    --------------------------------------------------
    -- File list
    --------------------------------------------------

    if y >= 2
        and y < height
    then

        local row =
            y - 1

        local index =
            scroll + row

        if index < 1
            or index > #entries
        then
            return
        end

        --------------------------------------------------
        -- Double click
        --------------------------------------------------

        if selected == index then

            local now =
                os.epoch("utc")

            if lastClickIndex == index
                and now - lastClickTime < 500
            then

                lastClickIndex = nil
                lastClickTime = 0

                openSelected()

                return
            end

            lastClickTime = now
            lastClickIndex = index

        else

            selected = index

            lastClickTime =
                os.epoch("utc")

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
    -- Up
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
    -- Down
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
    -- Enter
    --------------------------------------------------

    elseif key == keys.enter then

        openSelected()

    --------------------------------------------------
    -- Backspace
    --------------------------------------------------

    elseif key == keys.backspace then

        if currentPath ~= "/" then

            changeDirectory(
                getParent(currentPath)
            )

            loadDirectory()
            draw()
        end

    --------------------------------------------------
    -- Home
    --------------------------------------------------

    elseif key == keys.home then

        selected = 1
        scroll = 0

        draw()

    --------------------------------------------------
    -- End
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

-- Always start at root.
--
-- We intentionally do NOT call shell.dir()
-- here. The application should still start even
-- if the kernel's application environment does
-- not provide shell.

currentPath = "/"

changeDirectory("/")

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

    local eventName =
        event[1]

    --------------------------------------------------
    -- Mouse
    --------------------------------------------------

    if eventName == "mouse_click" then

        handleMouse(
            event[2],
            event[3],
            event[4]
        )

    --------------------------------------------------
    -- Keyboard
    --------------------------------------------------

    elseif eventName == "key" then

        handleKey(
            event[2]
        )

    --------------------------------------------------
    -- Terminal resize
    --------------------------------------------------

    elseif eventName == "term_resize" then

        loadDirectory()
        ensureSelectedVisible()
        draw()
    end
end
