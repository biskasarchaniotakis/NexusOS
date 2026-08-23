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
-- Helpers
--------------------------------------------------

local function normalizePath(path)

    if path == nil or path == "" then
        return "/"
    end

    local resolved =
        shell.resolve(path)

    if resolved == "" then
        return "/"
    end

    return "/" .. resolved:gsub("^/+", "")
end

--------------------------------------------------
-- Parent directory
--------------------------------------------------

local function getParent(path)

    path =
        normalizePath(path)

    if path == "/" then
        return "/"
    end

    local parent =
        fs.getDir(path)

    if parent == "" then
        return "/"
    end

    return "/" .. parent
end

--------------------------------------------------
-- Change directory
--------------------------------------------------

local function changeDirectory(path)

    path =
        normalizePath(path)

    if not fs.exists(path) then
        return false
    end

    if not fs.isDir(path) then
        return false
    end

    currentPath = path

    --------------------------------------------------
    -- Keep the shell directory in sync.
    --------------------------------------------------

    shell.setDir(
        path
    )

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
    -- Parent entry
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

            --------------------------------------------------
            -- Folders first.
            --------------------------------------------------

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
    -- Keep selection valid.
    --------------------------------------------------

    if #entries == 0 then

        selected = 1

    elseif selected > #entries then

        selected = #entries
    end

    --------------------------------------------------
    -- Keep scroll valid.
    --------------------------------------------------

    if scroll > math.max(
        0,
        #entries - getListHeight()
    ) then

        scroll =
            math.max(
                0,
                #entries - getListHeight()
            )
    end
end

--------------------------------------------------
-- List height
--------------------------------------------------

function getListHeight()

    local _, height =
        term.getSize()

    return math.max(
        1,
        height - 4
    )
end

--------------------------------------------------
-- Format path
--------------------------------------------------

local function displayPath()

    if currentPath == "/" then
        return "/"
    end

    return currentPath
end

--------------------------------------------------
-- Draw header
--------------------------------------------------

local function drawHeader()

    local width =
        term.getSize()

    --------------------------------------------------
    -- Top bar
    --------------------------------------------------

    term.setBackgroundColor(
        colors.gray
    )

    term.setTextColor(
        colors.white
    )

    term.setCursorPos(
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

    term.setCursorPos(
        1,
        1
    )

    if currentPath == "/" then

        term.setTextColor(
            colors.darkGray
        )

        term.write(
            "[<]"
        )

    else

        term.setTextColor(
            colors.white
        )

        term.write(
            "[<]"
        )
    end

    --------------------------------------------------
    -- Path
    --------------------------------------------------

    local pathText =
        displayPath()

    local available =
        width - 10

    if #pathText > available then

        pathText =
            "..." ..
            pathText:sub(
                #pathText - available + 4
            )
    end

    term.setCursorPos(
        5,
        1
    )

    term.setTextColor(
        colors.white
    )

    term.write(
        pathText
    )

    --------------------------------------------------
    -- Refresh button
    --------------------------------------------------

    term.setCursorPos(
        width - 5,
        1
    )

    term.setTextColor(
        colors.white
    )

    term.write(
        "[R]"
    )
end

--------------------------------------------------
-- Draw entries
--------------------------------------------------

local function drawEntries()

    local width, height =
        term.getSize()

    local listHeight =
        getListHeight()

    --------------------------------------------------
    -- Clear list area
    --------------------------------------------------

    term.setBackgroundColor(
        colors.black
    )

    for y = 2, height - 2 do

        term.setCursorPos(
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

        term.setCursorPos(
            1,
            y
        )

        term.write(
            string.rep(
                " ",
                width
            )
        )

        term.setCursorPos(
            2,
            y
        )

        --------------------------------------------------
        -- Icon
        --------------------------------------------------

        if entry.directory then

            term.write(
                "[DIR]"
            )

        else

            term.write(
                "[FILE]"
            )
        end

        --------------------------------------------------
        -- Name
        --------------------------------------------------

        local name =
            entry.name

        local maxName =
            width - 9

        if #name > maxName then

            name =
                name:sub(
                    1,
                    math.max(
                        1,
                        maxName - 3
                    )
                ) ..
                "..."
        end

        term.setCursorPos(
            8,
            y
        )

        term.write(
            name
        )
    end
end

--------------------------------------------------
-- Draw footer
--------------------------------------------------

local function drawFooter()

    local width, height =
        term.getSize()

    term.setBackgroundColor(
        colors.gray
    )

    term.setTextColor(
        colors.white
    )

    term.setCursorPos(
        1,
        height
    )

    term.write(
        string.rep(
            " ",
            width
        )
    )

    term.setCursorPos(
        2,
        height
    )

    term.write(
        tostring(#entries)
        .. " items"
    )

    term.setCursorPos(
        math.max(
            1,
            width - 18
        ),
        height
    )

    term.write(
        "Enter: Open"
    )
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
-- Ensure selected item visible
--------------------------------------------------

local function ensureSelectedVisible()

    local listHeight =
        getListHeight()

    if selected <= scroll then

        scroll =
            selected - 1

    elseif selected >
        scroll + listHeight then

        scroll =
            selected - listHeight
    end

    if scroll < 0 then
        scroll = 0
    end
end

--------------------------------------------------
-- Open selected
--------------------------------------------------

local function openSelected()

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

    --------------------------------------------------
    -- Files are not automatically executed yet.
    --
    -- We can add "Open With" later.
    --------------------------------------------------

    term.setBackgroundColor(
        colors.black
    )

    term.setTextColor(
        colors.white
    )

    local width, height =
        term.getSize()

    term.setCursorPos(
        1,
        height - 1
    )

    term.write(
        string.rep(
            " ",
            width
        )
    )

    term.setCursorPos(
        2,
        height - 1
    )

    term.write(
        "File: "
        .. entry.name
    )

    sleep(0.8)

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
        term.getSize()

    --------------------------------------------------
    -- Back
    --------------------------------------------------

    if y == 1
        and x >= 1
        and x <= 3 then

        if currentPath ~= "/" then

            changeDirectory(
                getParent(
                    currentPath
                )
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
        and x >= width - 5
        and x <= width - 1 then

        loadDirectory()
        draw()

        return
    end

    --------------------------------------------------
    -- File list
    --------------------------------------------------

    if y >= 2
        and y <= height - 2 then

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

            --------------------------------------------------
            -- Double click
            --------------------------------------------------

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

local function handleKey(
    key
)

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

            changeDirectory(
                getParent(
                    currentPath
                )
            )

            loadDirectory()
            draw()
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

changeDirectory(
    currentPath
)

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

    --------------------------------------------------
    -- Mouse
    --------------------------------------------------

    if name == "mouse_click" then

        handleMouse(
            event[2],
            event[3],
            event[4]
        )

    --------------------------------------------------
    -- Keyboard
    --------------------------------------------------

    elseif name == "key" then

        handleKey(
            event[2]
        )

    --------------------------------------------------
    -- Term resize
    --------------------------------------------------

    elseif name == "term_resize" then

        draw()
    end
end
