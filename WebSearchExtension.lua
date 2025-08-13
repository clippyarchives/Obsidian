local lib = getgenv().Library
if not lib then error("load Library.lua first") end

local hs = game:GetService("HttpService")

local function add_lbl(p,t)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextWrapped = true
	l.FontFace = lib.Scheme.Font
	l.TextSize = 14
	l.TextColor3 = lib.Scheme.FontColor
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.Size = UDim2.new(1,-12,0,0)
	l.Text = t
	l.Parent = p
	return l
end

local function extract_answer(data)
	if type(data) ~= "table" then return nil end
	if type(data.output_text) == "string" and #data.output_text > 0 then
		return data.output_text
	end
	if type(data.output) == "table" then
		for _, item in ipairs(data.output) do
			if item and item.type == "message" and type(item.content) == "table" then
				for _, c in ipairs(item.content) do
					if type(c) == "table" then
						if c.type == "output_text" and type(c.text) == "string" and #c.text > 0 then
							return c.text
						end
						if c.type == "text" and c.text and c.text.value then
							return tostring(c.text.value)
						end
					end
				end
			end
		end
	end
	if type(data.choices) == "table" and data.choices[1] and data.choices[1].message and type(data.choices[1].message.content) == "string" then
		return data.choices[1].message.content
	end
	return nil
end

local function attach(win,opt)
	opt = opt or {}
	local key = opt.key or getgenv().ai_key or ""
	local model = opt.model or getgenv().ai_model or "gpt-5"

	local tab = win:AddKeyTab("Web Search")

	local hold = Instance.new("Frame")
	hold.BackgroundTransparency = 1
	hold.Size = UDim2.new(1,0,1,0)
	hold.Parent = tab.Container

	local box = Instance.new("ScrollingFrame")
	box.BackgroundColor3 = lib.Scheme.MainColor
	box.BorderColor3 = lib.Scheme.OutlineColor
	box.AutomaticCanvasSize = Enum.AutomaticSize.Y
	box.CanvasSize = UDim2.fromOffset(0,0)
	box.ScrollBarThickness = 2
	box.Size = UDim2.new(1,-12,1,-66)
	box.Position = UDim2.fromOffset(6,6)
	box.Parent = hold

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0,6)
	list.Parent = box

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1,-12,0,44)
	row.Position = UDim2.new(0,6,1,-50)
	row.Parent = hold

	local inp = Instance.new("TextBox")
	inp.BackgroundColor3 = lib.Scheme.MainColor
	inp.BorderColor3 = lib.Scheme.OutlineColor
	inp.ClearTextOnFocus = false
	inp.TextXAlignment = Enum.TextXAlignment.Left
	inp.TextYAlignment = Enum.TextYAlignment.Center
	inp.FontFace = lib.Scheme.Font
	inp.TextColor3 = lib.Scheme.FontColor
	inp.TextSize = 14
	inp.PlaceholderText = "search…"
	inp.Size = UDim2.new(1,-110,1,0)
	inp.Parent = row

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0,8)
	pad.Parent = inp

	local btn = Instance.new("TextButton")
	btn.BackgroundColor3 = lib.Scheme.MainColor
	btn.BorderColor3 = lib.Scheme.OutlineColor
	btn.Text = "search"
	btn.FontFace = lib.Scheme.Font
	btn.TextSize = 14
	btn.TextColor3 = lib.Scheme.FontColor
	btn.Size = UDim2.new(0,96,1,0)
	btn.Position = UDim2.new(1,-96,0,0)
	btn.Parent = row

	local busy = false
	local function send()
		if busy then return end
		local q = inp.Text
		if q == "" then return end
		inp.Text = ""
		add_lbl(box, "> "..q)
		local waitlbl = add_lbl(box, "…")
		busy = true

		local body = {
			model = model,
			tools = { { type = "web_search_preview" } },
			input = q,
		}

		if getgenv().mcp_github_url then
			body.mcp = { servers = { github = { transport = "http", url = getgenv().mcp_github_url } } }
		end

		local ok,res = pcall(function()
			return (request or http_request or (syn and syn.request))({
				Url = "https://api.openai.com/v1/responses",
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json",
					["Authorization"] = "Bearer "..key
				},
				Body = hs:JSONEncode(body)
			})
		end)

		local out = "request failed"
		if ok and res and res.Body then
			local pok, data = pcall(hs.JSONDecode, hs, res.Body)
			if pok then
				local txt = extract_answer(data)
				if type(txt) == "string" and #txt > 0 then
					out = txt
				else
					out = "no answer text"
				end
			else
				out = "json parse error"
			end
		else
			out = ok and "empty response" or tostring(res)
		end

		waitlbl:Destroy()
		add_lbl(box, out)
		busy = false
	end

	btn.MouseButton1Click:Connect(send)
	inp.FocusLost:Connect(function(enter) if enter then send() end end)

	return { tab = tab }
end

return { attach = attach }
