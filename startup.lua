-- NexusOS startup

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)

shell.run("/os/kernel.lua")
