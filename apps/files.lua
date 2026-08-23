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
-- Safe size
--------------------------------------------------

local function size()

    local w, h =
        term.getSize()

    w = tonumber(w) or 1
    h = tonumber(h) or 1

    return math.max(1, w),
           math.max(1, h)
end

--------------------------------------------------
-- Safe cursor
--------------------------------------------------

local function cursor(x, y)

    local w, h =
        size()

    x = math.floor(
        tonumber(x) or 1
    )

    y = math.floor(
        tonumber(y) or 1
    )

    x = math.max(
        1,
        math.min(w, x)
    )

    y = math.max(
        1,
        math.min(h, y)
    )

    term.setCursorPos(x, y)
end

--------------------------------------------------
-- Normalize
--------------------------------------------------

local function normalize(path)

    if not path or path == "" then
        return "/"
    end

    local resolved =
        shell.resolve(path)

    if not resolved or resolved == "" then
        return "/"
    end

    if resolved:sub(1, 1) ~= "/" then
        resolved = "/" .. resolved
    end

    return resolved
end

--------------------------------------------------
-- Parent
--------------------------------------------------

local function parent(path)

    path =
        normalize(path)

    if path == "/" then
        return "/"
    end

    local p =
        fs.getDir(path)

    if not p or p == "" then
        return "/"
    end

    if p:sub(1, 1) ~= "/" then
        p = "/" .. p
    end

    return p
end

--------------------------------------------------
-- List height
--------------------------------------------------

local function listHeight()

    local _, h =
        size()

    return math.max(
        1,
        h - 4
    )
end

--------------------------------------------------
-- Change directory
--------------------------------------------------

local function changeDirectory(path)

    path =
        normalize(path)

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
-- Load
--------------------------------------------------

local function loadDirectory()

    entries = {}

    --------------------------------------------------
    -- Parent entry
    --------------------------------------------------

    if currentPath ~= "/" then

        table.insert(
            entries,
            {
                name = "..",
                path = parent(currentPath),
                directory = true,
                parent = true
            }
        )
    end

    --------------------------------------------------
    -- Contents
    --------------------------------------------------

    local list =
        fs.list(currentPath)

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

            return a:lower()
                < b:lower()
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

    if #entries == 0 then

        selected = 1
        scroll = 0

        return
    end

    selected =
        math.max(
            1,
            math.min(
                selected,
                #entries
            )
        )

    local maxScroll =
        math.max(
            0,
            #entries - listHeight()
        )

    scroll =
        math.max(
            0,
            math.min(
                scroll,
                maxScroll
            )
        )
end

--------------------------------------------------
-- Keep selected visible
--------------------------------------------------

local function ensureVisible()

    if #entries == 0 then

        selected = 1
        scroll = 0

        return
    end

    selected =
        math.max(
            1,
            math.min(
                selected,
                #entries
            )
        )

    local height =
        listHeight()

    if selected <= scroll then

        scroll =
            selected - 1

    elseif selected > scroll + height then

        scroll =
            selected - height
    end

    scroll =
        math.max(
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
-- Draw header
--------------------------------------------------

local function drawHeader()

    local width, height =
        size()

    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)

    cursor(1, 1)

    term.write(
        string.rep(
            " ",
            width
        )
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

    local path =
        currentPath

    local available =
        math.max(
            1,
            width - 9
        )

    if #path > available then

        path =
            "..." ..
            path:sub(
                math.max(
                    1,
                    #path - available + 4
                )
            )
    end

    cursor(5, 1)

    term.setTextColor(colors.white)

    term.write(path)

    --------------------------------------------------
    -- Refresh
    --------------------------------------------------

    if width >= 5 then

        cursor(
            width - 4,
            1
        )

        term.write("[R]")
    end
end

--------------------------------------------------
-- Draw entries
--------------------------------------------------

local function drawEntries()

    local width, height =
        size()

    local visible =
        listHeight()

    --------------------------------------------------
    -- Clear content
    --------------------------------------------------

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)

    for y = 2, height - 1 do

        cursor(1, y)

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

        cursor(1, y)

        term.write(
            string.rep(
                " ",
                width
            )
        )

        cursor(2, y)

        if entry.directory then
            term.write("[DIR]")
        else
            term.write("[FILE]")
        end

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

        cursor(8, y)

        term.write(name)
    end
end

--------------------------------------------------
-- Footer
--------------------------------------------------

local function drawFooter()

    local width, height =
        size()

    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)

    cursor(1, height)

    term.write(
        string.rep(
            " ",
            width
        )
    )

    cursor(2, height)

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
-- Open
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
    -- Basic file viewer.
    --------------------------------------------------

    local file =
        fs.open(
            entry.path,
            "r"
        )

    if not file then

        print(
            "Unable to open "
            .. entry.name
        )

        sleep(1)

        draw()

        return
    end

    local content =
        file.readAll()

    file.close()

    term.clear()
    cursor(1, 1)

    term.setTextColor(colors.yellow)

    print(
        "File: "
        .. entry.name
    )

    term.setTextColor(colors.white)

    print("")

    local width, height =
        size()

    local line = 3

    for textLine in (
        content .. "\n"
    ):gmatch("(.-)\n") do

        if line >= height then
            break
        end

        cursor(1, line)

        term.write(
            textLine:sub(
                1,
                width
            )
        )

        line = line + 1
    end

    cursor(
        1,
        height
    )

    term.setTextColor(colors.gray)

    term.write(
        "Press any key to return"
    )

    term.setTextColor(colors.white)

    os.pullEvent("key")

    draw()
end

--------------------------------------------------
-- Mouse
--------------------------------------------------

local function mouseClick(
    button,
    x,
    y
)

    local width, height =
        size()

    x = tonumber(x) or 0
    y = tonumber(y) or 0

    --------------------------------------------------
    -- Back
    --------------------------------------------------

    if y == 1
        and x >= 1
        and x <= 3
    then

        if currentPath ~= "/" then

            changeDirectory(
                parent(currentPath)
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
        and x >= width - 4
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

        if selected == index then

            local now =
                os.epoch("utc")

            if lastClickIndex == index
                and now - lastClickTime < 500
            then

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
                os.epoch("utc")

            lastClickIndex = index
        end

        draw()
    end
end

--------------------------------------------------
-- Keyboard
--------------------------------------------------

local function key(key)

    if key == keys.up then

        selected =
            math.max(
                1,
                selected - 1
            )

        ensureVisible()
        draw()

    elseif key == keys.down then

        selected =
            math.min(
                #entries,
                selected + 1
            )

        ensureVisible()
        draw()

    elseif key == keys.enter then

        openSelected()

    elseif key == keys.backspace then

        if currentPath ~= "/" then

            changeDirectory(
                parent(currentPath)
            )

            loadDirectory()
            draw()
        end

    elseif key == keys.home then

        selected = 1
        scroll = 0

        draw()

    elseif key == keys["end"] then

        if #entries > 0 then

            selected =
                #entries

            ensureVisible()
            draw()
        end

    elseif key == keys.r then

        loadDirectory()
        draw()
    end
end

--------------------------------------------------
-- Initialize
--------------------------------------------------

changeDirectory(currentPath)

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

    if event[1] == "mouse_click" then

        mouseClick(
            event[2],
            event[3],
            event[4]
        )

    elseif event[1] == "key" then

        key(event[2])

    elseif event[1] == "term_resize" then

        loadDirectory()
        draw()
    end
end
