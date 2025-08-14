local lib = getgenv().Library
if not lib then error("load Library.lua first") end

local hs = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local synx
pcall(function()
    synx = loadstring(game:HttpGet("https://raw.githubusercontent.com/clippyarchives/Obsidian/feature/ide-extension/IDESyntaxExtension.lua"))()
end)

local function color_to_hex(c)
    local r = math.clamp(math.floor((c.R or 0)*255+0.5),0,255)
    local g = math.clamp(math.floor((c.G or 0)*255+0.5),0,255)
    local b = math.clamp(math.floor((c.B or 0)*255+0.5),0,255)
    return string.format("#%02X%02X%02X", r, g, b)
end

local ACCENT_HEX = color_to_hex(lib.Scheme.AccentColor or Color3.fromRGB(157,125,255))

local function ensure_style()
    local s = getgenv().obs_chat_style
    if type(s) ~= "table" then s = {}; getgenv().obs_chat_style = s end
    s.ai_color = s.ai_color or Color3.fromRGB(180,220,255)
    s.user_color = s.user_color or Color3.fromRGB(220,220,220)
    s.use_model_prefix = (s.use_model_prefix ~= false)
    s.ai_label = s.ai_label or "AI"
    return s
end

local function add_lbl(parent, txt, color)
    local l = Instance.new("TextLabel")
    l.BackgroundColor3 = lib.Scheme.BackgroundColor
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Top
    l.TextWrapped = true
    l.FontFace = lib.Scheme.Font
    l.TextSize = 14
    l.TextColor3 = color or lib.Scheme.FontColor
    l.AutomaticSize = Enum.AutomaticSize.Y
    l.Size = UDim2.new(1,-12,0,0)
    l.Text = txt
    l.RichText = false
    l.Parent = parent
    return l
end

local function add_line_with_prefix(parent, prefix_kind, body, style_model)
    local s = ensure_style()
    local txt
    local color
    if prefix_kind == "ai" then
        local head = s.use_model_prefix and tostring(style_model or "AI") or (s.ai_label or "AI")
        txt = head.." > "..(body or "")
        color = s.ai_color
    else
        local dn = "user"
        local lp = Players.LocalPlayer
        if lp and lp.DisplayName and lp.DisplayName ~= "" then dn = lp.DisplayName end
        txt = "["..dn.."] > "..(body or "")
        color = s.user_color
    end
    local l = add_lbl(parent, txt, color)
    return l
end

local function add_code_block(gui, code)
    local t = code:gsub("\r","")
    local first = t:match("^%s*([%w%-_]*)\n")
    if first and (#first<=5) and (first:lower()=="lua" or first:lower()=="luau") then
        t = t:gsub("^%s*[%w%-_]*\n", "", 1)
    end
    if synx and synx.syn and synx.syn.hl then
        local ok, res = pcall(function()
            return synx.syn.hl(t)
        end)
        if ok and type(res) == "string" then
            gui.Text = res
            gui.RichText = true
        else
            gui.Text = t
            gui.RichText = false
        end
    else
        gui.Text = t
        gui.RichText = false
    end
    return t
end

local function instance_path(inst)
    local segs = {}
    local cur = inst
    while cur and cur ~= game do
        table.insert(segs, 1, cur.Name)
        cur = cur.Parent
    end
    return table.concat(segs, ".")
end

-- rest of file unchanged below ...
