local state = {}
local toggledPanels = {}
local glyphSet = nil
local tooltipSet = nil

noctalia = {
    getConfig = function(key)
        if key == "glyph" then return "custom-glyph" end
        return nil
    end,
    tr = function(key) return "translated:" .. key end,
    nowMs = function() return 1234567 end,
    togglePanel = function(id)
        table.insert(toggledPanels, id)
    end,
    state = {
        get = function(key) return state[key] end,
        set = function(key, val) state[key] = val end,
    },
}

barWidget = {
    setGlyph = function(g) glyphSet = g end,
    setTooltip = function(t) tooltipSet = t end,
}

dofile("motionpaper/widget.luau")

assert(glyphSet == "custom-glyph", "glyph not initialized")
assert(tooltipSet == "translated:widget.tooltip", "tooltip not initialized")

print("=== Test 1: onClick toggles picker panel ===")
onClick()
assert(#toggledPanels == 1 and toggledPanels[1] == "lawnninja/motionpaper:picker", "onClick did not toggle picker panel")

print("=== Test 2: onRightClick dispatches toggle-pause command ===")
onRightClick()
assert(state["command"] ~= nil, "command not set on right click")
assert(state["command"].action == "toggle-pause", "expected action toggle-pause, got: " .. tostring(state["command"].action))
assert(state["command"].target == "*", "expected target *, got: " .. tostring(state["command"].target))
local firstNonce = state["command"].nonce

print("=== Test 3: onMiddleClick dispatches toggle-stop command ===")
onMiddleClick()
assert(state["command"] ~= nil, "command not set on middle click")
assert(state["command"].action == "toggle-stop", "expected action toggle-stop, got: " .. tostring(state["command"].action))
assert(state["command"].target == "*", "expected target *, got: " .. tostring(state["command"].target))
assert(state["command"].nonce > firstNonce, "nonce did not advance")

print("All widget tests passed successfully!")
