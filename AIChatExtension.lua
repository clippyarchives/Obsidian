local lib = getgenv().Library
if not lib then error("load Library.lua first") end

local hs = game:GetService("HttpService")

local function add_msg(parent, txt)
    local l = Instance.new("TextLabel")
    l.BackgroundColor3 = lib.Scheme.BackgroundColor
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true
    l.FontFace = lib.Scheme.Font
    l.TextSize = 14
    l.TextColor3 = lib.Scheme.FontColor
    l.AutomaticSize = Enum.AutomaticSize.Y
    l.Size = UDim2.new(1,-12,0,0)
    l.Text = txt
    l.Parent = parent
    return l
end

local function attach(win, opt)
    opt = opt or {}
    local key = opt.key or ""
    local model = opt.model or "gpt-5"
    local sys = opt.system or "you are a helpful assistant"

    local tab = win:AddKeyTab("AI Chat")

    local root = Instance.new("Frame")
    root.BackgroundTransparency = 1
    root.Size = UDim2.new(1,0,1,0)
    root.Parent = tab.Container

    local box = Instance.new("ScrollingFrame")
    box.BackgroundColor3 = lib.Scheme.MainColor
    box.BorderColor3 = lib.Scheme.OutlineColor
    box.AutomaticCanvasSize = Enum.AutomaticSize.Y
    box.CanvasSize = UDim2.fromOffset(0,0)
    box.ScrollBarThickness = 2
    box.Size = UDim2.new(1,-12,1,-60)
    box.Position = UDim2.fromOffset(6,6)
    box.Parent = root

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0,6)
    list.Parent = box

    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1,-12,0,44)
    row.Position = UDim2.new(0,6,1,-50)
    row.Parent = root

    local inp = Instance.new("TextBox")
    inp.BackgroundColor3 = lib.Scheme.MainColor
    inp.BorderColor3 = lib.Scheme.OutlineColor
    inp.ClearTextOnFocus = false
    inp.TextXAlignment = Enum.TextXAlignment.Left
    inp.TextYAlignment = Enum.TextYAlignment.Center
    inp.FontFace = lib.Scheme.Font
    inp.TextColor3 = lib.Scheme.FontColor
    inp.TextSize = 14
    inp.PlaceholderText = "type..."
    inp.Size = UDim2.new(1,-110,1,0)
    inp.Parent = row

    local ip = Instance.new("UIPadding")
    ip.PaddingLeft = UDim.new(0,8)
    ip.Parent = inp

    local btn = Instance.new("TextButton")
    btn.BackgroundColor3 = lib.Scheme.MainColor
    btn.BorderColor3 = lib.Scheme.OutlineColor
    btn.Text = "send"
    btn.FontFace = lib.Scheme.Font
    btn.TextSize = 14
    btn.TextColor3 = lib.Scheme.FontColor
    btn.Size = UDim2.new(0,96,1,0)
    btn.Position = UDim2.new(1,-96,0,0)
    btn.Parent = row

    local msgs = { { role = "system", content = sys } }

    local busy = false
    local function send()
        if busy then return end
        local q = inp.Text
        if q == "" then return end
        inp.Text = ""
        add_msg(box, "> "..q)
        local waitlbl = add_msg(box, "...")
        table.insert(msgs, { role = "user", content = q })
        busy = true
        local r = request({
            Url = "https://api.openai.com/v1/chat/completions";
            Method = "POST";
            Headers = {
                ["Content-Type"] = "application/json";
                ["Authorization"] = "Bearer "..key;
            };
            Body = hs:JSONEncode({ model = model; messages = msgs; });
        })
        local ok, data = pcall(hs.JSONDecode, hs, r and r.Body or "{}")
        local out = (ok and data and data.choices and data.choices[1] and data.choices[1].message and data.choices[1].message.content) or "error"
        waitlbl.Text = out
        table.insert(msgs, { role = "assistant", content = out })
        busy = false
    end

    btn.MouseButton1Click:Connect(send)
    inp.FocusLost:Connect(function(enter) if enter then send() end end)

    return { tab = tab, send = send }
end

return { attach = attach }
