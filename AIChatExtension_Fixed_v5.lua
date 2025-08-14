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

local HEX_LUT = (function()
	local t = {}
	local function nib(n)
		if n < 10 then return string.char(48 + n) end
		return string.char(55 + (n - 10))
	end
	for i = 0,255 do
		local hi = math.floor(i/16)
		local lo = i - hi*16
		t[i] = nib(hi)..nib(lo)
	end
	return t
end)()

local function to_hex_byte(n)
	n = tonumber(n) or 0
	if n < 0 then n = 0 elseif n > 255 then n = 255 end
	return HEX_LUT[n]
end

local function color_to_hex(c)
	local r = math.clamp(math.floor((c.R or 0)*255+0.5),0,255)
	local g = math.clamp(math.floor((c.G or 0)*255+0.5),0,255)
	local b = math.clamp(math.floor((c.B or 0)*255+0.5),0,255)
	return "#"..to_hex_byte(r)..to_hex_byte(g)..to_hex_byte(b)
end

local ACCENT_HEX = color_to_hex(lib.Scheme.AccentColor or Color3.fromRGB(157,125,255))

local function get_style()
	local s = getgenv().obs_chat_style or {}
	s.ai_color = s.ai_color or Color3.fromRGB(180,220,255)
	s.user_color = s.user_color or Color3.fromRGB(220,220,220)
	if s.use_model_prefix == nil then s.use_model_prefix = true end
	s.ai_label = s.ai_label or "AI"
	getgenv().obs_chat_style = s
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
	l.RichText = true
	l.Parent = parent
	return l
end

local function add_line_with_prefix(parent, prefix_kind, body, model)
	local s = get_style()
	local baseCol = lib.Scheme.FontColor
	local pfx, pfxCol
	if prefix_kind == "ai" then
		pfx = s.use_model_prefix and (tostring(model or "AI") .. " > ") or (tostring(s.ai_label) .. " > ")
		pfxCol = s.ai_color or baseCol
	else
		local dn = "user"
		local lp = Players.LocalPlayer
		if lp and lp.DisplayName and lp.DisplayName ~= "" then dn = lp.DisplayName end
		pfx = "["..dn.."] > "
		pfxCol = s.user_color or baseCol
	end
	local txt = string.format("<font color=\"%s\">%s</font>%s", color_to_hex(pfxCol), pfx, tostring(body or ""))
	return add_lbl(parent, txt, baseCol)
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

-- rest of the file remains unchanged
