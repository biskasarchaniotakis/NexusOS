-- NexusOS Settings

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.setCursorBlink(false)

--------------------------------------------------
-- State
--------------------------------------------------

local settings = {
    desktopColor = colors.blue,
    accentColor = colors.lightBlue,
    showClock = true
}

--------------------------------------------------
-- Draw
--------------------------------------------------

local function draw()

    local width, height =
        term.getSize()

    width =
        tonumber(width) or 1

    height =
        tonumber(height) or 1

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)

    term.clear()
    term.setCursorPos(1, 1)

    term.setBackgroundColor(
        settings.accentColor
    )

    term.write(
        string.rep(
            " ",
            width
        )
    )

    term.setCursorPos(2, 1)
    term.write("NexusOS Settings")

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)

    term.setCursorPos(3, 3)

    term.write(
        "Desktop color"
    )

    term.setCursorPos(3, 4)

    term.write(
        "[1] Blue"
    )

    term.setCursorPos(3, 5)

    term.write(
        "[2] Black"
    )

    term.setCursorPos(3, 6)

    term.write(
        "[3] Green"
    )

    term.setCursorPos(3, 8)

    term.write(
        "Accent color"
    )

    term.setCursorPos(3, 9)

    term.write(
        "[4] Light Blue"
    )

    term.setCursorPos(3, 10)

    term.write(
        "[5] Cyan"
    )

    term.setCursorPos(3, 12)

    term.write(
        "Clock: "
        .. (
            settings.showClock
                and "ON"
                or "OFF"
        )
    )

    term.setCursorPos(3, 13)

    term.write(
        "[6] Toggle clock"
    )

    term.setCursorPos(
        3,
        math.max(1, height - 2)
    )

    term.setTextColor(colors.gray)

    term.write(
        "Press Q to close"
    )

    term.setTextColor(colors.white)
end

--------------------------------------------------
-- Apply
--------------------------------------------------

local function apply()

    local ok, ui =
        pcall(
            function()
                return require("os.ui")
            end
        )

    --------------------------------------------------
    -- The kernel/UI is not required to be directly
    -- changed by settings. We keep this app safe.
    --------------------------------------------------

    draw()
end

--------------------------------------------------
-- Main
--------------------------------------------------

draw()

while true do

    local event =
        table.pack(
            os.pullEvent()
        )

    if event[1] == "key" then

        local key =
            event[2]

        if key == keys.q
            or key == keys.escape
        then

            break

        elseif key == keys.one then

            settings.desktopColor =
                colors.blue

            draw()

        elseif key == keys.two then

            settings.desktopColor =
                colors.black

            draw()

        elseif key == keys.three then

            settings.desktopColor =
                colors.green

            draw()

        elseif key == keys.four then

            settings.accentColor =
                colors.lightBlue

            draw()

        elseif key == keys.five then

            settings.accentColor =
                colors.cyan

            draw()

        elseif key == keys.six then

            settings.showClock =
                not settings.showClock

            draw()
        end
    end
end
