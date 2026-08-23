-- NexusOS Terminal

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.setCursorBlink(true)

--------------------------------------------------
-- Ensure /apps is in PATH
--------------------------------------------------

do
    local path = shell.path()

    local found = false

    for entry in path:gmatch("[^:]+") do

        if entry == "/apps" then
            found = true
            break
        end
    end

    if not found then
        shell.setPath(
            path .. ":/apps"
        )
    end
end

--------------------------------------------------
-- History
--------------------------------------------------

local history = {}
local historyIndex = 0

--------------------------------------------------
-- Prompt
--------------------------------------------------

local function prompt()

    local dir = shell.dir()

    if dir == "" then
        dir = "/"
    else
        dir = "/" .. dir
    end

    return dir .. ":$ "
end

--------------------------------------------------
-- Split
--------------------------------------------------

local function split(line)

    local args = {}
    local current = ""
    local quoted = false

    for i = 1, #line do

        local c =
            line:sub(i, i)

        if c == '"' then

            quoted = not quoted

        elseif c == " "
            and not quoted
        then

            if current ~= "" then

                table.insert(
                    args,
                    current
                )

                current = ""
            end

        else

            current =
                current .. c
        end
    end

    if current ~= "" then

        table.insert(
            args,
            current
        )
    end

    return args
end

--------------------------------------------------
-- Read line
--------------------------------------------------

local function readLine()

    local p = prompt()

    term.setTextColor(colors.lime)
    write(p)

    term.setTextColor(colors.white)

    local text =
        read(
            nil,
            history
        )

    return text or ""
end

--------------------------------------------------
-- Run command
--------------------------------------------------

local function runCommand(line)

    local args =
        split(line)

    local command =
        args[1]

    if not command then
        return
    end

    --------------------------------------------------
    -- clear
    --------------------------------------------------

    if command == "clear" then

        term.clear()
        term.setCursorPos(1, 1)

        return
    end

    --------------------------------------------------
    -- exit
    --------------------------------------------------

    if command == "exit" then

        return "exit"
    end

    --------------------------------------------------
    -- cd
    --------------------------------------------------

    if command == "cd" then

        local path =
            args[2] or "/"

        local resolved =
            shell.resolve(path)

        if fs.exists(resolved)
            and fs.isDir(resolved)
        then

            shell.setDir(resolved)

        else

            print(
                "cd: directory not found: "
                .. path
            )
        end

        return
    end

    --------------------------------------------------
    -- pwd
    --------------------------------------------------

    if command == "pwd" then

        local dir =
            shell.dir()

        if dir == "" then
            dir = "/"
        else
            dir = "/" .. dir
        end

        print(dir)

        return
    end

    --------------------------------------------------
    -- ls
    --------------------------------------------------

    if command == "ls" then

        local path =
            args[2] or "."

        local resolved =
            shell.resolve(path)

        if not fs.exists(resolved) then

            print(
                "ls: not found: "
                .. path
            )

            return
        end

        if not fs.isDir(resolved) then

            print(
                fs.getName(resolved)
            )

            return
        end

        local list =
            fs.list(resolved)

        table.sort(
            list,
            function(a, b)

                return a:lower()
                    < b:lower()
            end
        )

        for _, name in ipairs(list) do

            if fs.isDir(
                fs.combine(
                    resolved,
                    name
                )
            ) then

                term.setTextColor(colors.yellow)

                print(
                    name .. "/"
                )

                term.setTextColor(colors.white)

            else

                print(name)
            end
        end

        return
    end

    --------------------------------------------------
    -- help
    --------------------------------------------------

    if command == "help" then

        print("NexusOS Terminal")
        print("")
        print("Built in:")
        print("  cd <dir>")
        print("  pwd")
        print("  ls")
        print("  clear")
        print("  exit")
        print("  help")
        print("")
        print("Other commands are run normally.")

        return
    end

    --------------------------------------------------
    -- Normal program
    --------------------------------------------------

    local program =
        shell.resolveProgram(command)

    if not program then

        print(
            command .. ": command not found"
        )

        return
    end

    --------------------------------------------------
    -- Pass remaining arguments.
    --------------------------------------------------

    local ok, err =
        pcall(
            function()

                shell.run(
                    program,
                    table.unpack(
                        args,
                        2
                    )
                )

            end
        )

    if not ok then

        term.setTextColor(colors.red)

        print(
            "Error: "
            .. tostring(err)
        )

        term.setTextColor(colors.white)
    end
end

--------------------------------------------------
-- Main loop
--------------------------------------------------

print("NexusOS Terminal")
print("Type 'help' for help.")
print("")

while true do

    local line =
        readLine()

    if line ~= "" then

        table.insert(
            history,
            line
        )

        if #history > 50 then

            table.remove(
                history,
                1
            )
        end
    end

    local result =
        runCommand(line)

    if result == "exit" then
        break
    end
end
