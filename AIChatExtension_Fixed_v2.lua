local lib = getgenv().Library
if not lib then error("load Library.lua first") end

local hs = game:GetService("HttpService")
local TextService = game:GetService("TextService")

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

local function add_code_block(gui, code)
    local t = code:gsub("\r","")
    local first = t:match("^%s*([%w%-_]*)\n")
    if first and (#first<=5) and (first:lower()=="lua" or first:lower()=="luau") then
        t = t:gsub("^%s*[%w%-_]*\n", "", 1)
    end
    if synx and synx.syn and synx.syn.hl then
        gui.Text = synx.syn.hl(t)
        gui.RichText = true
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

local function snapshot_instance(inst, depth, lines, depthLimit, maxLines, classList, nameList, path)
    if #lines >= maxLines then return end

    local classOk = true
    if classList and #classList > 0 then
        classOk = false
        for _,cls in ipairs(classList) do
            if inst:IsA(cls) or inst.ClassName == cls then classOk = true break end
        end
    end

    local nameOk = true
    if nameList and #nameList > 0 then
        nameOk = false
        local lower = tostring(inst.Name):lower()
        for _,frag in ipairs(nameList) do
            if lower:find(frag, 1, true) then nameOk = true break end
        end
    end

    if classOk and nameOk then
        local line = (path or inst.Name).." ("..inst.ClassName..")"
        if inst:IsA("BasePart") then
            local p = inst.Position
            local s = inst.Size
            line = line..string.format(" pos=(%.1f,%.1f,%.1f) size=(%.1f,%.1f,%.1f)", p.X,p.Y,p.Z, s.X,s.Y,s.Z)
        elseif inst:IsA("ValueBase") then
            local ok,val = pcall(function() return inst.Value end)
            if ok and val ~= nil then line = line.." value="..tostring(val) end
        end
        table.insert(lines, line)
    end

    if depth >= depthLimit then return end
    for _,c in ipairs(inst:GetChildren()) do
        if #lines >= maxLines then break end
        local childPath = (path and (path.."."..c.Name)) or c.Name
        snapshot_instance(c, depth+1, lines, depthLimit, maxLines, classList, nameList, childPath)
    end
end

local function parse_list(s)
    local out = {}
    if not s then return out end
    for token in string.gmatch(s, "[^,]+") do
        token = token:gsub("^%s+", ""):gsub("%s+$", "")
        if token ~= "" then table.insert(out, token) end
    end
    return out
end

local function build_service_context(selected, filter)
    local blockLines = {}
    for svcName, enabled in pairs(selected) do
        if enabled then
            local ok, svc = pcall(function() return game:GetService(svcName) end)
            if ok and svc then
                snapshot_instance(svc, 0, blockLines, 4, 800, filter.classes, filter.names, string.lower(svc.Name))
            end
        end
    end
    return table.concat(blockLines, "\n")
end

local function find_scripts()
    local foundScripts = {}
    local plrs = game:GetService("Players")
    
    local function safe_scan(container, name)
        local ok, result = pcall(function()
            if not container then return {} end
            local scripts = {}
            for _, child in ipairs(container:GetDescendants()) do
                if child:IsA("LocalScript") or child:IsA("ModuleScript") then
                    table.insert(scripts, child)
                end
                if #scripts > 50 then break end
            end
            return scripts
        end)
        return ok and result or {}
    end
    
    local containers = {
        {game:GetService("ReplicatedStorage"), "ReplicatedStorage"},
        {game:GetService("StarterGui"), "StarterGui"},
        {game:GetService("StarterPlayerScripts"), "StarterPlayerScripts"}
    }
    
    if plrs.LocalPlayer then
        local ok, playerGui = pcall(function() return plrs.LocalPlayer:FindFirstChild("PlayerGui") end)
        if ok and playerGui then
            table.insert(containers, {playerGui, "PlayerGui"})
        end
        
        local ok2, playerScripts = pcall(function() return plrs.LocalPlayer:FindFirstChild("PlayerScripts") end)
        if ok2 and playerScripts then
            table.insert(containers, {playerScripts, "PlayerScripts"})
        end
    end
    
    for _, container in ipairs(containers) do
        local scripts = safe_scan(container[1], container[2])
        for _, script in ipairs(scripts) do
            table.insert(foundScripts, script)
        end
    end
    
    return foundScripts
end

local function attach(win, opt)
    opt = opt or {}
    local key = opt.key or ""
    local model = opt.model or "gpt-5"
    local sys = opt.system or "you are a helpful assistant"
    local ide = opt.ide

    local rules = {
        sys,
        "return all code inside fenced code blocks (```lua ... ```). also tell the user that scripts are saved in the 'AI Scripts' tab where they can insert them into the IDE"
    }

    local scripts_store = {}
    local services_selected = {}
    local filter = { classes = {}, names = {} }

    local include_game_scripts = {}

    local function build_messages()
        local m = {}
        for _,r in ipairs(rules) do table.insert(m,{role="system",content=r}) end
        local ctx = build_service_context(services_selected, filter)
        if ctx ~= "" then table.insert(m, { role = "system", content = "services context:\n"..ctx }) end
        for inst, state in pairs(include_game_scripts) do
            if state and scripts_store[inst] then
                local path = instance_path(inst)
                table.insert(m, { role = "system", content = "game script: "..path.."\n```lua\n"..scripts_store[inst].."\n```" })
            end
        end
        return m
    end

    local function insert_code(src)
        if ide and ide.GetText and ide.SetText then
            local cur = ide:GetText() or ""
            ide:SetText((#cur>0 and (cur.."\n") or "") .. src)
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

    local rtab = win:AddKeyTab("AI Rules")
    local rh = Instance.new("Frame")
    rh.BackgroundTransparency = 1
    rh.Size = UDim2.new(1,0,1,0)
    rh.Parent = rtab.Container

    local rbox = Instance.new("ScrollingFrame")
    rbox.BackgroundColor3 = lib.Scheme.MainColor
    rbox.BorderColor3 = lib.Scheme.OutlineColor
    rbox.AutomaticCanvasSize = Enum.AutomaticSize.Y
    rbox.CanvasSize = UDim2.fromOffset(0,0)
    rbox.ScrollBarThickness = 2
    rbox.Size = UDim2.new(1,-12,1,-66)
    rbox.Position = UDim2.fromOffset(6,6)
    rbox.Parent = rh

    local rlist = Instance.new("UIListLayout")
    rlist.Padding = UDim.new(0,6)
    rlist.Parent = rbox

    local rrow = Instance.new("Frame")
    rrow.BackgroundTransparency = 1
    rrow.Size = UDim2.new(1,-12,0,44)
    rrow.Position = UDim2.new(0,6,1,-50)
    rrow.Parent = rh

    local rinp = Instance.new("TextBox")
    rinp.BackgroundColor3 = lib.Scheme.MainColor
    rinp.BorderColor3 = lib.Scheme.OutlineColor
    rinp.ClearTextOnFocus = false
    rinp.TextXAlignment = Enum.TextXAlignment.Left
    rinp.TextYAlignment = Enum.TextYAlignment.Center
    rinp.FontFace = lib.Scheme.Font
    rinp.TextColor3 = lib.Scheme.FontColor
    rinp.TextSize = 14
    rinp.PlaceholderText = "add rule..."
    rinp.Size = UDim2.new(1,-210,1,0)
    rinp.Parent = rrow

    local radd = Instance.new("TextButton")
    radd.BackgroundColor3 = lib.Scheme.MainColor
    radd.BorderColor3 = lib.Scheme.OutlineColor
    radd.Text = "add"
    radd.FontFace = lib.Scheme.Font
    radd.TextSize = 14
    radd.TextColor3 = lib.Scheme.FontColor
    radd.Size = UDim2.new(0,96,1,0)
    radd.Position = UDim2.new(1,-200,0,0)
    radd.Parent = rrow

    local rclear = Instance.new("TextButton")
    rclear.BackgroundColor3 = lib.Scheme.MainColor
    rclear.BorderColor3 = lib.Scheme.OutlineColor
    rclear.Text = "clear"
    rclear.FontFace = lib.Scheme.Font
    rclear.TextSize = 14
    rclear.TextColor3 = lib.Scheme.FontColor
    rclear.Size = UDim2.new(0,96,1,0)
    rclear.Position = UDim2.new(1,-96,0,0)
    rclear.Parent = rrow

    local function refresh_rules()
        for _,c in ipairs(rbox:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
        for i,r in ipairs(rules) do add_lbl(rbox, tostring(i)..". "..r) end
    end

    radd.MouseButton1Click:Connect(function()
        local t = rinp.Text
        if t=="" then return end
        rinp.Text = ""
        table.insert(rules, t)
        refresh_rules()
    end)

    rclear.MouseButton1Click:Connect(function()
        rules = {}
        refresh_rules()
    end)

    refresh_rules()

    local svctab = win:AddTab("Services", "server")
    local svcBoxLeft = svctab:AddLeftGroupbox("Services")
    local svcBoxRight = svctab:AddRightGroupbox("Selected Context")

    local preview = svcBoxRight:AddLabel({ Text = "", DoesWrap = true })

    local function update_preview()
        local ctx = build_service_context(services_selected, filter)
        preview:SetText(ctx == "" and "no services selected" or ctx)
    end

    local classInput = svcBoxRight:AddInput("svc_classes", { Text = "Class Filter(s) e.g. Model, Part"; Default = ""; Finished = true; ClearTextOnFocus = false; Callback = function(v) end })
    local nameInput = svcBoxRight:AddInput("svc_names", { Text = "Name Contains (comma list)"; Default = ""; Finished = true; ClearTextOnFocus = false; Callback = function(v) end })
    classInput:OnChanged(function(v) filter.classes = parse_list(v); update_preview() end)
    nameInput:OnChanged(function(v) local lst=parse_list(v); for i=1,#lst do lst[i]=lst[i]:lower() end filter.names=lst; update_preview() end)

    for _, svc in ipairs(game:GetChildren()) do
        local name = svc.ClassName
        svcBoxLeft:AddToggle("AI_SVC_"..name, {
            Text = name,
            Default = false,
            Callback = function(v)
                services_selected[name] = v or nil
                update_preview()
            end
        })
    end

    svctab:AddRightGroupbox("Actions"):AddButton({ Text = "Refresh Context", Func = update_preview })

    local stab = win:AddKeyTab("AI Scripts")
    local sh = Instance.new("Frame")
    sh.BackgroundTransparency = 1
    sh.Size = UDim2.new(1,0,1,0)
    sh.Parent = stab.Container

    local sbox = Instance.new("ScrollingFrame")
    sbox.BackgroundColor3 = lib.Scheme.MainColor
    sbox.BorderColor3 = lib.Scheme.OutlineColor
    sbox.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sbox.CanvasSize = UDim2.fromOffset(0,0)
    sbox.ScrollBarThickness = 2
    sbox.Size = UDim2.new(1,-12,1,-12)
    sbox.Position = UDim2.fromOffset(6,6)
    sbox.Parent = sh

    local slist = Instance.new("UIListLayout")
    slist.Padding = UDim.new(0,8)
    slist.Parent = sbox

    local function add_script(code)
        table.insert(scripts_store, code)
        local codebtn = Instance.new("TextButton")
        codebtn.AutoButtonColor = true
        codebtn.BackgroundColor3 = lib.Scheme.MainColor
        codebtn.BorderColor3 = lib.Scheme.OutlineColor
        codebtn.TextXAlignment = Enum.TextXAlignment.Left
        codebtn.TextYAlignment = Enum.TextYAlignment.Top
        codebtn.TextWrapped = true
        codebtn.FontFace = lib.Scheme.Font
        codebtn.TextSize = 14
        codebtn.TextColor3 = lib.Scheme.FontColor
        codebtn.AutomaticSize = Enum.AutomaticSize.Y
        codebtn.Size = UDim2.new(1,-12,0,0)
        codebtn.Parent = sbox
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0,8)
        pad.PaddingRight = UDim.new(0,8)
        pad.PaddingTop = UDim.new(0,6)
        pad.PaddingBottom = UDim.new(0,6)
        pad.Parent = codebtn
        local norm = add_code_block(codebtn, code)
        codebtn.MouseButton1Click:Connect(function()
            insert_code(norm)
        end)
        local ins = Instance.new("TextButton")
        ins.BackgroundColor3 = lib.Scheme.MainColor
        ins.BorderColor3 = lib.Scheme.OutlineColor
        ins.Text = "insert"
        ins.FontFace = lib.Scheme.Font
        ins.TextSize = 14
        ins.TextColor3 = lib.Scheme.FontColor
        ins.Size = UDim2.new(0,96,0,28)
        ins.Parent = sbox
        ins.MouseButton1Click:Connect(function()
            insert_code(norm)
        end)
    end

    local gtab = win:AddTab("Game Scripts", "file-text")
    local gLeft = gtab:AddLeftGroupbox("Scripts")
    local gRight = gtab:AddRightGroupbox("Decompiled")

    local currentInst
    local ed
    do
        local holder = Instance.new("Frame")
        holder.BackgroundTransparency = 1
        holder.Size = UDim2.new(1,0,1,-40)
        holder.Parent = gRight.Container
        if lib.CreateCodeEditor then
            ed = lib:CreateCodeEditor({ Parent = holder; Size = UDim2.new(1,0,1,0); Position = UDim2.fromOffset(0,0); Title = "editor"; Default = ""; })
        else
            local tb = Instance.new("TextBox"); tb.TextWrapped=true; tb.MultiLine=true; tb.ClearTextOnFocus=false; tb.TextXAlignment=Enum.TextXAlignment.Left; tb.TextYAlignment=Enum.TextYAlignment.Top; tb.Size=UDim2.new(1,0,1,0); tb.Parent=holder; ed={GetText=function()return tb.Text end, SetText=function(_,t)tb.Text=t end}
        end
        gRight:AddToggle("AI_USE_GSCRIPT", { Text = "Include in AI"; Default = false; Callback = function(v) if currentInst then include_game_scripts[currentInst]=v end end })
    end

    local function add_script_button(inst)
        local path = instance_path(inst)
        gLeft:AddButton({ 
            Text = path .. " (" .. inst.ClassName .. ")"; 
            Func = function()
                currentInst = inst;
                ed:SetText("decompiling " .. path .. "...");
                task.spawn(function()
                    local ok, src = pcall(function() 
                        return decompile(inst) 
                    end);
                    local code = ok and src or "decompile failed";
                    scripts_store[inst] = code;
                    ed:SetText(code);
                    if setclipboard then
                        setclipboard(code);
                        lib:Notify("copied to clipboard", 2);
                    end;
                end);
            end 
        });
    end

    local function rebuild_game_scripts()
        if gLeft.Elements then
            for _,el in ipairs(gLeft.Elements) do 
                if el.Holder then 
                    el.Holder:Destroy() 
                end 
            end
            gLeft.Elements = {}
        end
        
        local scripts = find_scripts();
        lib:Notify("found " .. #scripts .. " scripts", 2);
        
        for _, inst in ipairs(scripts) do
            add_script_button(inst);
        end
        
        if #scripts == 0 then
            gLeft:AddLabel("no localscript/modulescript found");
        end
    end

    gLeft:AddButton({ Text = "Refresh Scripts"; Func = rebuild_game_scripts });
    rebuild_game_scripts();

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
            add_script(seg)
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
        local base = build_messages()
        table.insert(base, { role = "user", content = q })
        busy = true
        local r = request({ Url = "https://api.openai.com/v1/chat/completions"; Method = "POST"; Headers = { ["Content-Type"] = "application/json"; ["Authorization"] = "Bearer "..key; }; Body = hs:JSONEncode({ model = model; messages = base; }); })
        local ok, data = pcall(hs.JSONDecode, hs, r and r.Body or "{}")
        local out = (ok and data and data.choices and data.choices[1] and data.choices[1].message and data.choices[1].message.content) or "error"
        waitlbl:Destroy()
        render_reply(out)
        busy = false
    end

    btn.MouseButton1Click:Connect(send)
    inp.FocusLost:Connect(function(enter) if enter then send() end end)

    return { tab = tab }
end

return { attach = attach }