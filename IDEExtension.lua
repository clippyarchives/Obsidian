-- IDE Extension for Obsidian Library
-- Adds in-UI code editor (multiline), run/save/load helpers, and groupbox APIs

local uis = game:GetService("UserInputService")
local ts = game:GetService("TweenService")

local lib = getgenv().Library
if not lib then error("Library not found! Load Library.lua first.") end

local editors = {}

local function make_textbox(parent, text)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = lib.Scheme.MainColor
    f.BackgroundTransparency = 0
    f.Size = UDim2.new(1, 0, 0, 180)
    f.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, lib.CornerRadius or 4)
    corner.Parent = f

    local stroke = Instance.new("UIStroke")
    stroke.Color = lib.Scheme.OutlineColor
    stroke.Parent = f

    local tb = Instance.new("TextBox")
    tb.RichText = false
    tb.MultiLine = true
    tb.ClearTextOnFocus = false
    tb.TextXAlignment = Enum.TextXAlignment.Left
    tb.TextYAlignment = Enum.TextYAlignment.Top
    tb.TextWrapped = false
    tb.BackgroundTransparency = 1
    tb.TextEditable = true
    tb.Text = text or ""
    tb.FontFace = lib.Scheme.Font or Font.fromEnum(Enum.Font.Code)
    tb.TextSize = 14
    tb.TextColor3 = lib.Scheme.FontColor
    tb.Size = UDim2.fromScale(1, 1)
    tb.Parent = f

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = f

    return f, tb
end

function lib:CreateCodeEditor(info)
    info = info or {}

    local size = info.Size or UDim2.fromOffset(460, 260)
    local pos = info.Position or UDim2.fromOffset(12, 12)
    local parent = info.Parent or self.ScreenGui
    local visible = info.Visible ~= false
    local value = info.Default or ""
    local readonly = info.ReadOnly or false

    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.Size = size
    holder.Position = pos
    holder.Visible = visible
    holder.Parent = parent

    local titlebar = Instance.new("TextLabel")
    titlebar.BackgroundTransparency = 1
    titlebar.Text = info.Title or "code editor"
    titlebar.FontFace = lib.Scheme.Font or Font.fromEnum(Enum.Font.Gotham)
    titlebar.TextColor3 = lib.Scheme.FontColor
    titlebar.TextSize = 14
    titlebar.TextXAlignment = Enum.TextXAlignment.Left
    titlebar.Size = UDim2.new(1, 0, 0, 20)
    titlebar.Parent = holder

    local editor_frame, textbox = make_textbox(holder, value)
    editor_frame.Position = UDim2.new(0, 0, 0, 24)
    editor_frame.Size = UDim2.new(1, 0, 1, -58)
    textbox.TextEditable = not readonly

    local btnrow = Instance.new("Frame")
    btnrow.BackgroundTransparency = 1
    btnrow.Size = UDim2.new(1, 0, 0, 30)
    btnrow.Position = UDim2.new(0, 0, 1, -30)
    btnrow.Parent = holder

    local ui_list = Instance.new("UIListLayout")
    ui_list.FillDirection = Enum.FillDirection.Horizontal
    ui_list.HorizontalAlignment = Enum.HorizontalAlignment.Right
    ui_list.Padding = UDim.new(0, 6)
    ui_list.Parent = btnrow

    local function mkbtn(txt, cb)
        local b = Instance.new("TextButton")
        b.AutoButtonColor = true
        b.Text = txt
        b.FontFace = lib.Scheme.Font or Font.fromEnum(Enum.Font.Gotham)
        b.TextSize = 14
        b.TextColor3 = lib.Scheme.FontColor
        b.BackgroundColor3 = lib.Scheme.MainColor
        b.Size = UDim2.fromOffset(90, 28)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, lib.CornerRadius or 4)
        c.Parent = b
        local s = Instance.new("UIStroke")
        s.Color = lib.Scheme.OutlineColor
        s.Parent = b
        b.Parent = btnrow
        b.MouseButton1Click:Connect(function()
            cb()
        end)
        return b
    end

    local ed = {
        Holder = holder,
        TextBox = textbox,
        Title = titlebar,
        Type = "CodeEditor",
        Visible = visible
    }

    function ed:SetText(t)
        textbox.Text = t or ""
    end

    function ed:GetText()
        return textbox.Text
    end

    function ed:SetVisible(v)
        self.Visible = v
        holder.Visible = v
    end

    function ed:SetSize(s)
        holder.Size = s
    end

    function ed:SetPosition(p)
        holder.Position = p
    end

    function ed:SetReadOnly(v)
        textbox.TextEditable = not v
    end

    function ed:Destroy()
        editors[self] = nil
        holder:Destroy()
    end

    local path = info.Path or "obsidian_editor.lua"

    mkbtn("run", function()
        local src = textbox.Text
        local f = (getgenv().loadstring or loadstring)(src)
        if typeof(f) == "function" then
            local ok, err = pcall(f)
            if not ok and lib.NotifyOnError then
                lib:Notify({Title = "error", Description = tostring(err), Time = 4})
            end
        end
    end)

    mkbtn("save", function()
        if writefile then
            writefile(path, textbox.Text)
            lib:Notify("saved: " .. path, 3)
        else
            lib:Notify("writefile unsupported", 3)
        end
    end)

    mkbtn("load", function()
        if readfile and isfile and isfile(path) then
            local c = readfile(path)
            textbox.Text = c or ""
            lib:Notify("loaded: " .. path, 3)
        else
            lib:Notify("no file: " .. path, 3)
        end
    end)

    editors[ed] = true
    return ed
end

local function add_code_editor_to_groupbox(gb)
    function gb:AddCodeEditor(info)
        info = info or {}
        local cont = self.Container
        local size = info.Size or UDim2.new(1, 0, 0, 220)
        local visible = info.Visible ~= false

        local holder = Instance.new("Frame")
        holder.BackgroundTransparency = 1
        holder.Size = size
        holder.Visible = visible
        holder.Parent = cont

        local ed = lib:CreateCodeEditor({
            Parent = holder,
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.fromOffset(0, 0),
            Default = info.Default or "",
            Title = info.Title or "code editor",
            Path = info.Path,
            ReadOnly = info.ReadOnly,
            Visible = visible
        })

        self:Resize()
        table.insert(self.Elements, ed)
        return ed
    end
end

for _, t in pairs(lib.Tabs) do
    if t.Groupboxes then
        for _, g in pairs(t.Groupboxes) do
            add_code_editor_to_groupbox(g)
        end
    end
    if t.Tabboxes then
        for _, tb in pairs(t.Tabboxes) do
            if tb.Tabs then
                for _, st in pairs(tb.Tabs) do
                    add_code_editor_to_groupbox(st)
                end
            end
        end
    end
end

local orig_unload = lib.Unload
function lib:Unload()
    for ed, _ in pairs(editors) do
        ed:Destroy()
    end
    orig_unload(self)
end

return { Editors = editors }
