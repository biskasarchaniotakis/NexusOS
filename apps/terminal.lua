-- NexusOS Terminal

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
-- Redraw input line
--------------------------------------------------

local function redraw(prompt, text, cursor)
    local _, y = term.getCursorPos()

    term.setCursorPos(#prompt + 1, y)

    -- Clear old input
    write(string.rep(" ", math.max(0, term.getSize() - #prompt)))

    -- Draw new input
    term.setCursorPos(#prompt + 1, y)
    write(text)

    -- Put cursor at correct position
    term.setCursorPos(#prompt + cursor + 1, y)
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

        -- Built-in commands
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
    -- File/directory completion
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

    if not fs.exists(directory) or not fs.isDir(directory) then
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

    local directory = fs.getDir(lastArg)
    local partial = fs.getName(lastArg)

    local replacement = matches[index]

    if directory ~= "" and directory ~= "." then
        replacement = directory .. "/" .. replacement
    end

    local prefix = text:sub(1, #text - #partial)

    return prefix .. replacement
end

--------------------------------------------------
-- Show autocomplete choices
--------------------------------------------------

local function showCompletions(prompt, text, matches)
    local _, y = term.getCursorPos()

    term.setCursorPos(1, y + 1)

    print(table.concat(matches, "    "))

    -- Reprint prompt and command
    write(prompt)
    write(text)
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
        -- Character
        --------------------------------------------------

        if event == "char" then

            text =
                text:sub(1, cursor)
                .. value
                .. text:sub(cursor + 1)

            cursor = cursor + 1

            -- Reset autocomplete
            completionMatches = {}
            completionIndex = 0

            redraw(prompt, text, cursor)

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

                    redraw(prompt, text, cursor)
                end

            --------------------------------------------------
            -- LEFT
            --------------------------------------------------

            elseif value == keys.left then

                if cursor > 0 then
                    cursor = cursor - 1
                    redraw(prompt, text, cursor)
                end

            --------------------------------------------------
            -- RIGHT
            --------------------------------------------------

            elseif value == keys.right then

                if cursor < #text then
                    cursor = cursor + 1
                    redraw(prompt, text, cursor)
                end

            --------------------------------------------------
            -- TAB
            --------------------------------------------------

            elseif value == keys.tab then

                --------------------------------------------------
                -- Find completions
                --------------------------------------------------

                if #completionMatches == 0 then

                    completionMatches =
                        getCompletions(text)

                    completionIndex = 1

                    --------------------------------------------------
                    -- No matches
                    --------------------------------------------------

                    if #completionMatches == 0 then
                        -- Nothing happens

                    --------------------------------------------------
                    -- One match
                    --------------------------------------------------

                    elseif #completionMatches == 1 then

                        text =
                            applyCompletion(
                                text,
                                completionMatches,
                                1
                            )

                        cursor = #text

                        redraw(prompt, text, cursor)

                    --------------------------------------------------
                    -- Multiple matches
                    --------------------------------------------------

                    else

                        showCompletions(
                            prompt,
                            text,
                            completionMatches
                        )

                        completionIndex = 1
                    end

                --------------------------------------------------
                -- Cycle completions
                --------------------------------------------------

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

                    redraw(prompt, text, cursor)
                end

            --------------------------------------------------
            -- UP / HISTORY
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

                    redraw(prompt, text, cursor)
                end

            --------------------------------------------------
            -- DOWN / HISTORY
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

                    redraw(prompt, text, cursor)
                end
            end
        end
    end
end

--------------------------------------------------
-- Terminal main loop
--------------------------------------------------

while true do

    local commandLine = readCommand()

    --------------------------------------------------
    -- Save history
    --------------------------------------------------

    if commandLine ~= "" then
        table.insert(history, commandLine)
        historyIndex = #history + 1
    end

    --------------------------------------------------
    -- Parse arguments
    --------------------------------------------------

    local args =
        splitCommand(commandLine)

    local command = args[1]

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

        local path = args[2]

        if not path or path == "" then
            path = "/"
        end

        local resolved = shell.resolve(path)

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
        -- Not found
        --------------------------------------------------

        if program == nil then

            print(
                "Command not found: "
                .. command
            )

        --------------------------------------------------
        -- Prevent shell.lua
        --------------------------------------------------

        elseif fs.getName(program) == "shell.lua" then

            print("Access denied.")

        --------------------------------------------------
        -- Run program
        --------------------------------------------------

        else

            -- Remove command from arguments
            table.remove(args, 1)

            shell.run(
                program,
                table.unpack(args)
            )
        end
    end
end
