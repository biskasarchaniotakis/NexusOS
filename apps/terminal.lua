-- NexusOS Terminal

term.setCursorBlink(true)

--------------------------------------------------
-- Add NexusOS apps to the existing shell path
--------------------------------------------------

do
    local path = shell.path()

    local hasApps = false

    for entry in path:gmatch("[^:]+") do
        if entry == "/apps" then
            hasApps = true
            break
        end
    end

    if not hasApps then
        shell.setPath(path .. ":/apps")
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

local function getPrompt()
    local pwd = shell.dir()

    if pwd == "" then
        pwd = "/"
    else
        pwd = "/" .. pwd
    end

    return pwd .. ":$ "
end

--------------------------------------------------
-- Split command into arguments
--------------------------------------------------

local function splitCommand(line)
    local args = {}
    local current = ""
    local quoted = false

    for i = 1, #line do
        local char = line:sub(i, i)

        if char == '"' then
            quoted = not quoted

        elseif char == " " and not quoted then
            if current ~= "" then
                table.insert(args, current)
                current = ""
            end

        else
            current = current .. char
        end
    end

    if current ~= "" then
        table.insert(args, current)
    end

    return args
end

--------------------------------------------------
-- Redraw input
--------------------------------------------------

local function redraw(prompt, text, cursor)
    local _, y = term.getCursorPos()
    local width = term.getSize()

    term.setCursorPos(#prompt + 1, y)

    write(string.rep(" ", math.max(0, width - #prompt)))

    term.setCursorPos(#prompt + 1, y)
    write(text)

    term.setCursorPos(
        #prompt + cursor + 1,
        y
    )
end

--------------------------------------------------
-- Get autocomplete matches
--------------------------------------------------

local function getCompletions(text)
    local matches = {}

    if text == "" then
        return matches
    end

    local args = splitCommand(text)

    --------------------------------------------------
    -- Command completion
    --------------------------------------------------

    if #args == 1 and not text:find("%s") then

        for _, program in ipairs(shell.programs()) do
            if program:sub(1, #text) == text then
                table.insert(matches, program)
            end
        end

        local builtins = {
            "cd",
            "clear",
            "exit"
        }

        for _, command in ipairs(builtins) do
            if command:sub(1, #text) == text then

                local exists = false

                for _, match in ipairs(matches) do
                    if match == command then
                        exists = true
                        break
                    end
                end

                if not exists then
                    table.insert(matches, command)
                end
            end
        end

        table.sort(matches)

        return matches
    end

    --------------------------------------------------
    -- Path completion
    --------------------------------------------------

    local lastArg = args[#args]

    if not lastArg then
        return matches
    end

    local directory = fs.getDir(lastArg)
    local partial = fs.getName(lastArg)

    if directory == "" then
        directory = "."
    end

    if not fs.exists(directory) then
        return matches
    end

    if not fs.isDir(directory) then
        return matches
    end

    for _, file in ipairs(fs.list(directory)) do

        if file:sub(1, #partial) == partial then
            table.insert(matches, file)
        end
    end

    table.sort(matches)

    return matches
end

--------------------------------------------------
-- Apply autocomplete
--------------------------------------------------

local function applyCompletion(text, matches, index)
    if #matches == 0 then
        return text
    end

    local args = splitCommand(text)

    --------------------------------------------------
    -- Command completion
    --------------------------------------------------

    if #args == 1 and not text:find("%s") then
        return matches[index]
    end

    --------------------------------------------------
    -- Path completion
    --------------------------------------------------

    local lastArg = args[#args]

    if not lastArg then
        return text
    end

    local slash = lastArg:match("^.*()/")

    local prefix

    if slash then
        prefix = lastArg:sub(1, slash)
    else
        prefix = ""
    end

    local completed =
        prefix .. matches[index]

    local beforeLast =
        text:sub(1, #text - #lastArg)

    return beforeLast .. completed
end

--------------------------------------------------
-- Show autocomplete choices
--------------------------------------------------

local function showCompletions(prompt, text, cursor, matches)
    local _, y = term.getCursorPos()

    if y < term.getSize() then
        term.setCursorPos(1, y + 1)
    else
        term.scroll(1)
        term.setCursorPos(1, y)
    end

    print(table.concat(matches, "    "))

    write(prompt)
    write(text)

    term.setCursorPos(
        #prompt + cursor + 1,
        select(2, term.getCursorPos())
    )
end

--------------------------------------------------
-- Read command
--------------------------------------------------

local function readCommand()
    local prompt = getPrompt()

    local text = ""
    local cursor = 0

    local completionMatches = {}
    local completionIndex = 0

    write(prompt)

    while true do

        local event, value = os.pullEvent()

        --------------------------------------------------
        -- Character typed
        --------------------------------------------------

        if event == "char" then

            text =
                text:sub(1, cursor)
                .. value
                .. text:sub(cursor + 1)

            cursor = cursor + 1

            completionMatches = {}
            completionIndex = 0

            redraw(
                prompt,
                text,
                cursor
            )

        --------------------------------------------------
        -- Keyboard
        --------------------------------------------------

        elseif event == "key" then

            --------------------------------------------------
            -- ENTER
            --------------------------------------------------

            if value == keys.enter then

                print()

                return text

            --------------------------------------------------
            -- BACKSPACE
            --------------------------------------------------

            elseif value == keys.backspace then

                if cursor > 0 then

                    text =
                        text:sub(1, cursor - 1)
                        .. text:sub(cursor + 1)

                    cursor = cursor - 1

                    completionMatches = {}
                    completionIndex = 0

                    redraw(
                        prompt,
                        text,
                        cursor
                    )
                end

            --------------------------------------------------
            -- LEFT
            --------------------------------------------------

            elseif value == keys.left then

                if cursor > 0 then
                    cursor = cursor - 1

                    redraw(
                        prompt,
                        text,
                        cursor
                    )
                end

            --------------------------------------------------
            -- RIGHT
            --------------------------------------------------

            elseif value == keys.right then

                if cursor < #text then
                    cursor = cursor + 1

                    redraw(
                        prompt,
                        text,
                        cursor
                    )
                end

            --------------------------------------------------
            -- TAB
            --------------------------------------------------

            elseif value == keys.tab then

                if #completionMatches == 0 then

                    completionMatches =
                        getCompletions(text)

                    completionIndex = 1

                    if #completionMatches == 0 then

                        -- Nothing to autocomplete.

                    elseif #completionMatches == 1 then

                        text =
                            applyCompletion(
                                text,
                                completionMatches,
                                1
                            )

                        cursor = #text

                        redraw(
                            prompt,
                            text,
                            cursor
                        )

                    else

                        showCompletions(
                            prompt,
                            text,
                            cursor,
                            completionMatches
                        )
                    end

                else

                    completionIndex =
                        completionIndex + 1

                    if completionIndex >
                        #completionMatches then

                        completionIndex = 1
                    end

                    text =
                        applyCompletion(
                            text,
                            completionMatches,
                            completionIndex
                        )

                    cursor = #text

                    redraw(
                        prompt,
                        text,
                        cursor
                    )
                end

            --------------------------------------------------
            -- UP
            --------------------------------------------------

            elseif value == keys.up then

                if #history > 0 then

                    historyIndex =
                        math.max(
                            1,
                            historyIndex - 1
                        )

                    text =
                        history[historyIndex]

                    cursor = #text

                    completionMatches = {}
                    completionIndex = 0

                    redraw(
                        prompt,
                        text,
                        cursor
                    )
                end

            --------------------------------------------------
            -- DOWN
            --------------------------------------------------

            elseif value == keys.down then

                if #history > 0 then

                    historyIndex =
                        math.min(
                            #history + 1,
                            historyIndex + 1
                        )

                    if historyIndex <= #history then
                        text =
                            history[historyIndex]
                    else
                        text = ""
                    end

                    cursor = #text

                    completionMatches = {}
                    completionIndex = 0

                    redraw(
                        prompt,
                        text,
                        cursor
                    )
                end
            end
        end
    end
end

--------------------------------------------------
-- Terminal main loop
--------------------------------------------------

while true do

    --------------------------------------------------
    -- Read command
    --------------------------------------------------

    local commandLine =
        readCommand()

    --------------------------------------------------
    -- History
    --------------------------------------------------

    if commandLine ~= "" then

        table.insert(
            history,
            commandLine
        )

        historyIndex =
            #history + 1
    end

    --------------------------------------------------
    -- Parse arguments
    --------------------------------------------------

    local args =
        splitCommand(commandLine)

    local command =
        args[1]

    --------------------------------------------------
    -- EXIT
    --------------------------------------------------

    if command == "exit" then

        break

    --------------------------------------------------
    -- CLEAR
    --------------------------------------------------

    elseif command == "clear" then

        term.clear()
        term.setCursorPos(1, 1)

    --------------------------------------------------
    -- CD
    --------------------------------------------------

    elseif command == "cd" then

        local path =
            args[2] or "/"

        local resolved =
            shell.resolve(path)

        if fs.exists(resolved)
            and fs.isDir(resolved) then

            shell.setDir(resolved)

        else

            print(
                "cd: directory not found: "
                .. path
            )
        end

    --------------------------------------------------
    -- COMMAND
    --------------------------------------------------

    elseif command ~= nil then

        local program =
            shell.resolveProgram(command)

        --------------------------------------------------
        -- Command doesn't exist
        --------------------------------------------------

        if program == nil then

            print(
                "Command not found: "
                .. command
            )

        --------------------------------------------------
        -- Protect shell.lua
        --------------------------------------------------

        elseif fs.getName(program) == "shell.lua" then

            print("Access denied.")

        --------------------------------------------------
        -- Execute program
        --------------------------------------------------

        else

            table.remove(args, 1)

            shell.run(
                program,
                table.unpack(args)
            )
        end
    end
end
