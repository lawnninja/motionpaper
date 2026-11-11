-- Stop / Restore all / crash recovery tests for service.luau.
local state, files = {}, {}
local now = 1000000
local wallpapersEnabled = {}
local launches = 0
local processAlive = false   -- does a gslapper/holder process still own the socket?
local socketDead = false     -- socket file present but refusing connections
local live = {}              -- fake gSlapper per socket: { status, path }

if not bit32 then
    bit32 = { bxor = function(a, b) return a ~ b end }
end

local SOCKET_DIR = "/run/user/1000/noctalia-motionpaper/"
local FLAGS = "--fork --ipc-socket --no-save-state --auto-pause --auto-stop --fps-cap --gst-options --transition-type --transition-duration"

local function done(callback, code, stdout)
    if callback then
        callback({ exitCode = code, stdout = stdout or "", stderr = "", timedOut = false })
    end
end

noctalia = {
    setUpdateInterval = function() end,
    state = {
        get = function(key) return state[key] end,
        set = function(key, value) state[key] = value end,
        watch = function() end,
    },
    pluginDataDir = function() return "/data" end,
    readFile = function(path) return files[path] end,
    writeFile = function(path, contents) files[path] = contents return true end,
    renameFile = function(from, to) files[to] = files[from] files[from] = nil return true end,
    removeFile = function(path) files[path] = nil end,
    fileExists = function(path) return files[path] ~= nil end,
    fileInfo = function() return { isDir = false, size = 1, mtime = 1 } end,
    listDir = function() return {} end,
    outputs = function() return { { name = "DP-1" }, { name = "DP-2" } } end,
    setWallpaper = function() end,
    setWallpaperEnabled = function(connector, enabled) wallpapersEnabled[connector] = enabled end,
    nowMs = function() return now end,
    getenv = function() return "/run/user/1000" end,
    processMatches = function(callback) callback(processAlive) return true end,
    mkdirAll = function() return true end,
    commandExists = function() return true end,
    getConfig = function() return nil end,
    wallpaperDirectory = function() return "/w" end,
    expandPath = function(p) return p end,
    log = function() end,
    notify = function() end,
    notifyError = function() end,
    json = {
        encode = function() return "{}" end,
        decode = function() return nil end,
    },
    runAsync = function(command, callback)
        if command:find("gslapper %-%-help") then
            done(callback, 0, FLAGS)
        elseif command:find("^'gslapper' '%-%-fork'") then
            launches = launches + 1
            local socket = command:match("'%-%-ipc%-socket' '([^']+)'")
            local path = command:match("'([^']*)'$")
            files[socket] = "socket"
            live[socket] = { status = "playing", path = path }
            done(callback, 0)
        elseif command:find("socat") then
            local ipc = command:match("'([^']*)' | socat")
            local socket = command:match("UNIX%-CONNECT:'([^']+)'")
            local proc = live[socket]
            if socketDead or not proc or not files[socket] then
                done(callback, 1)
            elseif ipc == "query" then
                done(callback, 0, "STATUS: " .. proc.status .. " video " .. proc.path .. "\n")
            elseif ipc == "pause" then
                proc.status = "paused"
                done(callback, 0, "OK\n")
            elseif ipc == "resume" then
                proc.status = "playing"
                done(callback, 0, "OK\n")
            elseif ipc == "stop" then
                files[socket] = nil
                live[socket] = nil
                done(callback, 0, "OK\n")
            else
                done(callback, 0, "OK\n")
            end
        else
            done(callback, 0, "")   -- find, scheduler ticks, gst-launch
        end
        return true
    end,
}

local service = dofile("motionpaper/service.luau")
assert(service.runSelfTest(true).passed, "self-test failed: " .. tostring(service.runSelfTest(true).error))

local VIDEO = "/w/v.mp4"
local IMAGE = "/w/a.jpg"
local SOCKET = SOCKET_DIR .. "DP-1.sock"
files[VIDEO] = "video"
files[IMAGE] = "image"
files[service.stillPathFor(VIDEO)] = "still"   -- cached still: launch happens right away

local nonce = 0
local function send(action, target, extra)
    -- IPC events use time-based nonces; stay ahead of them.
    now = now + 1
    nonce = math.max(nonce, now * 1000 + 1000) + 1
    local command = { nonce = nonce, action = action, target = target }
    for key, value in pairs(extra or {}) do command[key] = value end
    return service.handleCommand(command)
end

local function settle()
    for _ = 1, 10 do
        update()
    end
end

local function crash()
    files[SOCKET] = nil
    live[SOCKET] = nil
    processAlive = false
    update()                 -- notices the missing socket
    now = now + 3000
    update()                 -- grace period over: confirm and mark crashed
end

print("=== Test 1: Stop remembers wallpaper + slideshow, Restore all brings it back playing ===")
assert(send("assign-video", "DP-1", { path = VIDEO }))
settle()
assert(service.runtime["DP-1"].status == "playing", "video did not start")
send("set-slideshow", "DP-1", { interval_sec = 300, shuffle = true })
assert(service.slideshow()["DP-1"].interval_sec == 300)

assert(send("stop", "DP-1"))
settle()
assert(service.assignments["DP-1"] == nil, "stop kept the assignment")
assert(service.slideshow()["DP-1"] == nil, "stop kept the slideshow")
assert(wallpapersEnabled["DP-1"] == true, "stop did not re-enable the native wallpaper")
local remembered = service.lastKnown()["DP-1"]
assert(remembered and remembered.path == VIDEO and remembered.desired_playback == "playing", "stop did not remember a playing video")
assert(remembered.slideshow.interval_sec == 300 and remembered.slideshow.shuffle == true, "stop did not remember the slideshow")
assert(state.last_known["DP-1"] ~= nil, "last_known not published")

assert(send("restore-all", "*"))
settle()
assert(service.assignments["DP-1"] and service.assignments["DP-1"].path == VIDEO, "restore-all did not bring the video back")
assert(service.assignments["DP-1"].desired_playback == "playing", "restored video is not playing")
assert(service.runtime["DP-1"].status == "playing", "gSlapper was not playing after restore")
assert(service.slideshow()["DP-1"].interval_sec == 300 and service.slideshow()["DP-1"].shuffle == true, "slideshow not restored")
assert(service.assignments["DP-2"] == nil, "restore-all touched an output that never had a wallpaper")

print("=== Test 1b: Stop while paused remembers paused, Restore brings it back paused ===")
assert(send("pause", "DP-1"))
settle()
assert(service.assignments["DP-1"].desired_playback == "paused", "video was not paused")
assert(send("stop", "DP-1"))
settle()
assert(service.assignments["DP-1"] == nil, "stop kept the assignment")
remembered = service.lastKnown()["DP-1"]
assert(remembered and remembered.desired_playback == "paused", "stop did not remember paused playback")
assert(send("restore-all", "*"))
settle()
assert(service.assignments["DP-1"].desired_playback == "paused", "restored video did not come back paused")
assert(service.runtime["DP-1"].status == "paused", "runtime status not paused")

print("=== Test 1c: Resume on stopped connector restores and plays it ===")
assert(send("stop", "DP-1"))
settle()
assert(service.assignments["DP-1"] == nil)
assert(send("resume", "DP-1"))
settle()
assert(service.assignments["DP-1"] and service.assignments["DP-1"].path == VIDEO, "resume did not restore stopped video")
assert(service.assignments["DP-1"].desired_playback == "playing", "resume did not restore as playing")
assert(service.runtime["DP-1"].status == "playing", "runtime status not playing after resume")
assert(send("pause", "DP-1"))
settle()

print("=== Test 2: crash while paused -> stays down, Restore all relaunches paused ===")
crash()
assert(service.runtime["DP-1"].status == "stopped", "crash not detected")
assert(wallpapersEnabled["DP-1"] == true, "crash did not re-enable the native wallpaper")
assert(service.assignments["DP-1"].desired_playback == "paused", "crash lost the assignment")
local before = launches
now = now + 400000          -- well past the slideshow interval
settle()
assert(launches == before, "crashed wallpaper came back without Restore")
assert(service.runtime["DP-1"].status == "stopped", "crashed output left stopped state on its own")

service.onIpc("restore-all")
settle()
assert(launches == before + 1, "restore-all IPC did not relaunch")
assert(service.runtime["DP-1"].status == "paused", "crashed paused video did not come back paused")
assert(service.slideshow()["DP-1"].interval_sec == 300, "crash recovery lost the slideshow")

print("=== Test 3: crash while playing -> Restore brings it back playing ===")
assert(send("resume", "DP-1"))
settle()
assert(service.runtime["DP-1"].status == "playing")
crash()
assert(service.runtime["DP-1"].status == "stopped", "crash not detected while playing")
service.onIpc("restore", "DP-1")
settle()
assert(service.runtime["DP-1"].status == "playing", "crashed playing video did not come back playing")

print("=== Test 4: auto-stop holder (socket gone, process alive) is not a crash ===")
files[SOCKET] = nil
processAlive = true
update()
now = now + 5000
update()
assert(service.runtime["DP-1"].status == "playing", "hidden auto-stop was treated as a crash")
files[SOCKET] = "socket"
live[SOCKET] = { status = "playing", path = VIDEO }
processAlive = false
settle()

print("=== Test 5: dead socket (file left behind) is detected by the periodic query ===")
now = now + 10000
update()                    -- arms the next health query
now = now + 10000
socketDead = true
update()
assert(service.runtime["DP-1"].status == "stopped", "dead socket not detected")
socketDead = false
files[SOCKET] = nil
service.onIpc("restore-all")
settle()
assert(service.runtime["DP-1"].status == "playing", "restore after dead socket failed")

print("=== Test 6: image + slideshow round trip through Stop / Restore ===")
assert(send("assign-image", "DP-2", { path = IMAGE }))
send("set-slideshow", "DP-2", { interval_sec = 60, shuffle = false })
service.onIpc("stop", "DP-2")
settle()
assert(service.assignments["DP-2"] == nil and service.slideshow()["DP-2"] == nil, "stop did not clear DP-2")
service.onIpc("restore", "DP-2")
settle()
assert(service.assignments["DP-2"] and service.assignments["DP-2"].path == IMAGE, "image not restored")
assert(service.slideshow()["DP-2"].interval_sec == 60, "image slideshow not restored")

print("=== Test 7: stop * stops everything, restore-all brings everything back ===")
service.onIpc("stop", "*")
settle()
assert(service.assignments["DP-1"] == nil and service.assignments["DP-2"] == nil, "stop * did not stop all outputs")
service.onIpc("restore-all")
settle()
assert(service.assignments["DP-1"].path == VIDEO and service.assignments["DP-1"].desired_playback == "playing",
    "stopped playing video did not come back playing")
assert(service.assignments["DP-2"].path == IMAGE, "image not restored by restore-all")

print("=== Test 8: toggle-stop on running output stops it, second toggle-stop restores it ===")
assert(service.assignments["DP-1"] ~= nil and service.runtime["DP-1"].status == "playing")
assert(send("toggle-stop", "DP-1"))
settle()
assert(service.assignments["DP-1"] == nil, "toggle-stop did not stop DP-1")
assert(wallpapersEnabled["DP-1"] == true, "native wallpaper not re-enabled on stop")
assert(send("toggle-stop", "DP-1"))
settle()
assert(service.assignments["DP-1"] and service.assignments["DP-1"].path == VIDEO, "toggle-stop did not restore DP-1")
assert(service.assignments["DP-1"].desired_playback == "playing", "toggle-stop did not restore as playing")
assert(service.runtime["DP-1"].status == "playing", "runtime status not playing")

print("=== Test 9: toggle-stop on paused output stops it, second toggle-stop restores it paused ===")
assert(send("pause", "DP-1"))
settle()
assert(service.assignments["DP-1"].desired_playback == "paused")
assert(send("toggle-stop", "DP-1"))
settle()
assert(service.assignments["DP-1"] == nil, "toggle-stop did not stop paused DP-1")
assert(send("toggle-stop", "DP-1"))
settle()
assert(service.assignments["DP-1"] and service.assignments["DP-1"].desired_playback == "paused",
    "toggle-stop did not restore as paused")
assert(service.runtime["DP-1"].status == "paused")

print("=== Test 10: onIpc toggle-stop * stops all when running, restores all when stopped ===")
assert(send("resume", "DP-1"))
settle()
assert(service.assignments["DP-1"] ~= nil and service.assignments["DP-2"] ~= nil)
service.onIpc("toggle-stop", "*")
settle()
assert(service.assignments["DP-1"] == nil and service.assignments["DP-2"] == nil, "toggle-stop * did not stop all outputs")
service.onIpc("toggle-stop", "*")
settle()
assert(service.assignments["DP-1"] ~= nil and service.assignments["DP-2"] ~= nil, "toggle-stop * did not restore all outputs")
assert(service.assignments["DP-1"].path == VIDEO and service.assignments["DP-2"].path == IMAGE)

print("=== Test 11: onIpc toggle alias works ===")
service.onIpc("toggle", "DP-2")
settle()
assert(service.assignments["DP-2"] == nil, "toggle alias did not stop DP-2")
service.onIpc("toggle", "DP-2")
settle()
assert(service.assignments["DP-2"] and service.assignments["DP-2"].path == IMAGE, "toggle alias did not restore DP-2")

print("All restore tests passed successfully!")
