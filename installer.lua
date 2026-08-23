-- NexusOS Installer
-- Downloads NexusOS directly from GitHub

local BASE =
    "https://raw.githubusercontent.com/biskasarchaniotakis/NexusOS/main/"

local files = {
    {
        remote = "startup.lua",
        localPath = "/startup.lua"
    },

    {
        remote = "os/kernel.lua",
        localPath = "/os/kernel.lua"
    },

    {
        remote = "os/ui.lua",
        localPath = "/os/ui.lua"
    },

    {
        remote = "apps/files.lua",
        localPath = "/apps/files.lua"
    },

    {
        remote = "apps/terminal.lua",
        localPath = "/apps/terminal.lua"
    }
}

local function println(text)
    print("[NexusOS] " .. text)
end

local function download(remote, localPath)
    local url = BASE .. remote

    println("Downloading " .. remote .. "...")

    local ok, err = pcall(function()
        shell.run(
            "wget",
            url,
            localPath
        )
    end)

    if not ok then
        println("ERROR: " .. tostring(err))
        return false
    end

    if not fs.exists(localPath) then
        println("ERROR: file was not created:")
        println(localPath)
        return false
    end

    println("OK: " .. localPath)
    return true
end

--------------------------------------------------
-- Start
--------------------------------------------------

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)

print("================================")
print("       NexusOS Installer")
print("================================")
print()

println("Creating directories...")

if not fs.exists("/os") then
    fs.makeDir("/os")
end

if not fs.exists("/apps") then
    fs.makeDir("/apps")
end

print()

--------------------------------------------------
-- Download files
--------------------------------------------------

local failed = 0

for _, file in ipairs(files) do
    if not download(file.remote, file.localPath) then
        failed = failed + 1
    end
end

print()
print("================================")

if failed == 0 then
    print(" NexusOS installed successfully!")
    print("================================")
    print()
    print("Files installed:")
    print("  /startup.lua")
    print("  /os/kernel.lua")
    print("  /os/ui.lua")
    print("  /apps/files.lua")
    print("  /apps/terminal.lua")
    print()
    print("Rebooting in 3 seconds...")
    sleep(3)

    os.reboot()
else
    print(" INSTALLATION FAILED")
    print("================================")
    print()
    print("Failed files: " .. failed)
    print()
    print("Nothing has been deleted.")
    print("Check your internet connection.")
    print()
    print("Press any key to return.")

    os.pullEvent("key")
end
