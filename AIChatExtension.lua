local lib = getgenv().Library
if not lib then error("load Library.lua first") end

local hs = game:GetService("HttpService")

local synx
pcall(function()
    synx = loadstring(game:HttpGet("https://raw.githubusercontent.com/clippyarchives/Obsidian/feature/ide-extension/IDESyntaxExtension.lua"))()
end)

local function add_lbl(parent, txt)
    local l = Instance.new("TextLabel")
    l.BackgroundColor3 = lib.Scheme.BackgroundColor
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Top
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

local function add_code(parent, code, onadd)
    local b = Instance.new("TextButton")
    b.AutoButtonColor = true
    b.BackgroundColor3 = lib.Scheme.MainColor
    b.BorderColor3 = lib.Scheme.OutlineColor
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.TextYAlignment = Enum.TextYAlignment.Top
    b.TextWrapped = true
    b.RichText = true
    b.FontFace = lib.Scheme.Font
    b.TextSize = 14
    b.TextColor3 = lib.Scheme.FontColor
    b.AutomaticSize = Enum.AutomaticSize.Y
    b.Size = UDim2.new(1,-12,0,0)
    b.Parent = parent

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0,8)
    pad.PaddingRight = UDim.new(0,8)
    pad.PaddingTop = UDim.new(0,6)
    pad.PaddingBottom = UDim.new(0,6)
    pad.Parent = b

    local t = code:gsub("\r","")
    local first = t:match("^%s*([%w%-_]*)\n")
    if first and (#first<=5) and (first:lower()=="lua" or first:lower()=="luau") then
        t = t:gsub("^%s*[%w%-_]*\n", "", 1)
    end
    if synx and synx.syn and synx.syn.hl then
        b.Text = synx.syn.hl(t)
    else
        b.RichText = false
        b.Text = t
    end
    b.MouseButton1Click:Connect(function()
        onadd(t)
    end)
    return b
end

local function attach(win, opt)
    opt = opt or {}
    local key = opt.key or ""
    local model = opt.model or "gpt-5"
    local sys = opt.system or "you are a helpful assistant"
    local ide = opt.ide

    local function insert_code(src)
        if ide and ide.GetText and ide.SetText then
            ide:SetText((ide:GetText() or "") .. ( (#ide:GetText()>0 and "\n" or "") ) .. src)
            lib:Notify("added to ide",2)
        elseif typeof(getgenv().obs_ide_insert)=="function" then
            getgenv().obs_ide_insert(src)
            lib:Notify("sent to ide",2)
        elseif setclipboard then
            setclipboard(src)
            lib:Notify("copied",2)
        end
    end

    local tab = win:AddKeyTab("AI Chat")

    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.new(1,0,1,0)
    holder.Parent = tab.Container

    local box = Instance.new("ScrollingFrame")
    box.BackgroundColor3 = lib.Scheme.MainColor
    box.BorderColor3 = lib.Scheme.OutlineColor
    box.AutomaticCanvasSize = Enum.AutomaticSize.Y
    box.CanvasSize = UDim2.fromOffset(0,0)
    box.ScrollBarThickness = 2
    box.Size = UDim2.new(1,-12,1,-66)
    box.Position = UDim2.fromOffset(6,6)
    box.Parent = holder

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0,6)
    list.Parent = box

    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1,-12,0,44)
    row.Position = UDim2.new(0,6,1,-50)
    row.Parent = holder

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

    local function render_reply(text)
        local i = 1
        while true do
            local a,b,seg = text:find("```(.-)```", i)
            if not a then
                local tail = text:sub(i)
                if tail ~= "" then add_lbl(box, tail) end
                break
            end
            local pre = text:sub(i, a-1)
            if pre ~= "" then add_lbl(box, pre) end
            add_code(box, seg, insert_code)
            i = b + 1
        end
    end

    local busy = false
    local function send()
        if busy then return end
        local q = inp.Text
        if q == "" then return end
        inp.Text = ""
        add_lbl(box, "> "..q)
        local waitlbl = add_lbl(box, "...")
        table.insert(msgs, { role = "user", content = q })
        busy = true
        local r = request({
            Url = "https://api.openai.com/v1/chat/completions";
            Method = "POST";
            Headers = { ["Content-Type"] = "application/json"; ["Authorization"] = "Bearer "..key; };
            Body = hs:JSONEncode({ model = model; messages = msgs; });
        })
        local ok, data = pcall(hs.JSONDecode, hs, r and r.Body or "{}")
        local out = (ok and data and data.choices and data.choices[1] and data.choices[1].message and data.choices[1].message.content) or "error"
        waitlbl:Destroy()
        render_reply(out)
        table.insert(msgs, { role = "assistant", content = out })
        busy = false
    end

    btn.MouseButton1Click:Connect(send)
    inp.FocusLost:Connect(function(enter) if enter then send() end end)

    return { tab = tab, send = send }
end

return { attach = attach }
