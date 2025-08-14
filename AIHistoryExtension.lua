local lib = getgenv().Library
if not lib then error("load Library.lua first") end

local hs = game:GetService("HttpService")

local function ensure_mem()
    if type(getgenv().obs_mem) ~= "table" then
        getgenv().obs_mem = { enabled = true; max_turns = 10; chat = {}; }
    else
        if getgenv().obs_mem.enabled == nil then getgenv().obs_mem.enabled = true end
        getgenv().obs_mem.max_turns = tonumber(getgenv().obs_mem.max_turns) or 10
        getgenv().obs_mem.chat = getgenv().obs_mem.chat or {}
    end
    return getgenv().obs_mem
end

local dir = "obsidian/chat_histories"

local function fs_ok()
    return typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(makefolder) == "function" and typeof(listfiles) == "function" and typeof(isfolder) == "function" and typeof(delfile) == "function"
end

local function ensure_dir()
    if not fs_ok() then return false end
    if not isfolder(dir) then pcall(makefolder, dir) end
    return isfolder(dir)
end

local function sanitize_name(s)
    s = tostring(s or "session")
    s = s:gsub("[^%w%-%._]+","_")
    if #s == 0 then s = "session" end
    return s
end

local function save_history(name)
    local mem = ensure_mem()
    if not ensure_dir() then lib:Notify("fs unsupported", 2); return end
    local ts = tostring(os.time())
    local fn = dir.."/"..ts.."_"..sanitize_name(name)..".json"
    local data = { chat = mem.chat; max_turns = mem.max_turns; enabled = mem.enabled }
    local ok, enc = pcall(hs.JSONEncode, hs, data)
    if not ok then lib:Notify("json err",2) return end
    writefile(fn, enc)
    lib:Notify("saved",2)
end

local function list_histories()
    if not ensure_dir() then return {} end
    local files = {}
    for _,p in ipairs(listfiles(dir) or {}) do
        if p:lower():sub(-5) == ".json" then table.insert(files, p) end
    end
    table.sort(files, function(a,b) return a > b end)
    return files
end

local function load_history_file(path)
    if not fs_ok() then return nil end
    local ok, raw = pcall(readfile, path)
    if not ok then return nil end
    local ok2, data = pcall(hs.JSONDecode, hs, raw)
    if not ok2 then return nil end
    if type(data) == "table" and type(data.chat) == "table" then return data end
    if type(data) == "table" then return { chat = data } end
    return nil
end

local function join_chat(tbl)
    local lines = {}
    for _,m in ipairs(tbl or {}) do
        table.insert(lines, (m.role or "user")..": "..tostring(m.content or ""))
    end
    return table.concat(lines, "\n")
end

local function attach(win)
    ensure_mem()
    local tab = win:AddTab("AI History", "save")

    local left = tab:AddLeftGroupbox("save/load")
    local right = tab:AddRightGroupbox("preview")

    local name_inp
    name_inp = left:AddInput("hist_name", { Text = "name"; Default = "session"; Finished = true; ClearTextOnFocus = false; Callback = function() end })

    left:AddButton({ Text = "save current"; Func = function()
        local n = name_inp and name_inp.Value or "session"
        save_history(n)
        task.delay(0.15, function() if refresh then refresh() end end)
    end })

    local files_box = right:AddLabel({ Text = ""; DoesWrap = true })
    right:AddDivider()
    local prev_box = right:AddLabel({ Text = ""; DoesWrap = true })

    local selected

    local function show_preview(path)
        local data = load_history_file(path)
        if not data then prev_box:SetText("(failed to read)") return end
        local text = join_chat(data.chat)
        if #text == 0 then text = "(empty)" end
        prev_box:SetText(text)
    end

    local function rebuild_list()
        local files = list_histories()
        if #files == 0 then files_box:SetText("no histories") selected = nil prev_box:SetText("") return end
        local lines = {}
        for i,p in ipairs(files) do
            table.insert(lines, tostring(i)..". "..p)
        end
        files_box:SetText(table.concat(lines, "\n"))
        selected = files[1]
        show_preview(selected)
    end

    right:AddButton({ Text = "refresh"; Func = rebuild_list })

    right:AddButton({ Text = "append to memory"; Func = function()
        if not selected then return end
        local data = load_history_file(selected)
        if not data then return end
        local mem = ensure_mem()
        for _,m in ipairs(data.chat) do table.insert(mem.chat, m) end
        while #mem.chat > (tonumber(mem.max_turns) or 10)*2 do table.remove(mem.chat,1) end
        if type(getgenv().obs_mem_refresh) == "function" then pcall(getgenv().obs_mem_refresh) end
        lib:Notify("uploaded",2)
    end })

    right:AddButton({ Text = "replace memory"; Func = function()
        if not selected then return end
        local data = load_history_file(selected)
        if not data then return end
        local mem = ensure_mem()
        mem.chat = data.chat
        while #mem.chat > (tonumber(mem.max_turns) or 10)*2 do table.remove(mem.chat,1) end
        if type(getgenv().obs_mem_refresh) == "function" then pcall(getgenv().obs_mem_refresh) end
        lib:Notify("loaded",2)
    end })

    right:AddButton({ Text = "delete selected"; Func = function()
        if not selected or not fs_ok() then return end
        pcall(delfile, selected)
        rebuild_list()
    end })

    right:AddInput("select_path", { Text = "select index or path"; Default = "1"; Finished = true; ClearTextOnFocus = false; Callback = function(v)
        local files = list_histories()
        local idx = tonumber(v)
        if idx and files[idx] then selected = files[idx] show_preview(selected) return end
        if type(v) == "string" and v ~= "" then selected = v show_preview(selected) end
    end })

    function refresh()
        rebuild_list()
    end

    rebuild_list()

    return { tab = tab }
end

print("ai_history_ext v1")
return { attach = attach }