term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)

term.clear()
term.setCursorPos(1, 1)

print("NEXUS Terminal")
print("Type 'help' for help.")
print()

while true do
    write("$ ")
    local command = read()

    if command == "help" then
        print("Available commands:")
        print("  help   - Show this help")
        print("  clear  - Clear the screen")
        print("  exit   - Return to NEXUS")

    elseif command == "clear" then
        term.clear()
        term.setCursorPos(1, 1)

    elseif command == "exit" then
        break

    elseif command ~= "" then
        print("Unknown command: " .. command)
    end
end
