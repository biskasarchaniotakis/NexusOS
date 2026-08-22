

local function button(x, y, width, text)

    term.setCursorPos(x, y)

    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)

    term.write(" " .. text .. " ")

end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)

term.clear()
term.setCursorPos(1, 1)

button(5, 5, 15, "Terminal")
button(5, 7, 15, "Files")
button(5, 9, 15, "Settings")

while true do

    local event, button, x, y = os.pullEvent()

    if event == "mouse_click" then

        if x >= 5 and x <= 20 and y == 5 then
            term.setBackgroundColor(colors.black)
            shell.run("clear")
            shell.run("apps/terminal.lua")
        end

    end

end
