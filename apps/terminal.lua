while true do
    write("$ ")
    local command = read()

    if command == "exit" then
        break

    elseif command == "clear" then
        term.clear()
        term.setCursorPos(1, 1)

    elseif command ~= "" then
        local program = shell.resolveProgram(command)

        if program == nil then
            print("Command not found: " .. command)

        elseif fs.getName(program) == "shell.lua" then
            print("Access denied.")

        else
            shell.run(program)
        end
    end
end
