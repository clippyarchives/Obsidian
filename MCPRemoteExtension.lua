local hs = game:GetService("HttpService")

local function parse_list(s)
	local t = {}
	if type(s) ~= "string" then return t end
	for item in string.gmatch(s, "[^,]+") do
		local x = item:gsub("^%s+",""):gsub("%s+$","")
		if #x > 0 then table.insert(t, x) end
	end
	return t
end

local function safe_json_decode(s)
	if type(s) ~= "string" or s == "" then return nil end
	local ok, obj = pcall(hs.JSONDecode, hs, s)
	if ok and type(obj) == "table" then return obj end
	return nil
end

local function attach(win, opt)
	opt = opt or {}
	getgenv().mcp_servers = getgenv().mcp_servers or {}
	local sv = getgenv().mcp_servers

	local tab = win:AddTab("MCP", "globe")
	local left = tab:AddLeftGroupbox("Add Server")
	local right = tab:AddRightGroupbox("Servers")

	local state = {
		label = "",
		url = "",
		headers = {},
		allowed = {},
		req = "",
		enabled = true
	}

	local lbl = left:AddInput("mcp_label", { Text = "server label"; Default = ""; Finished = true; ClearTextOnFocus = false; Callback = function(v) state.label = v end })
	local url = left:AddInput("mcp_url", { Text = "server url"; Default = ""; Finished = true; ClearTextOnFocus = false; Callback = function(v) state.url = v end })
	local hdr = left:AddInput("mcp_headers", { Text = "headers (json obj)"; Default = ""; Finished = true; ClearTextOnFocus = false; Callback = function(v) state.headers = safe_json_decode(v) or {} end })
	local allow = left:AddInput("mcp_allowed", { Text = "allowed_tools (comma)"; Default = ""; Finished = true; ClearTextOnFocus = false; Callback = function(v) state.allowed = parse_list(v) end })
	local req = left:AddDropdown("mcp_req", { Text = "require_approval"; Values = {"", "never"}; Default = 1; Callback = function(v) state.req = v end })
	local en = left:AddToggle("mcp_enabled", { Text = "enabled"; Default = true; Callback = function(v) state.enabled = v end })

	left:AddButton({ Text = "Add Server"; Func = function()
		if state.label == "" or state.url == "" then return end
		local entry = { label = state.label; url = state.url; headers = state.headers; allowed_tools = (#state.allowed>0 and state.allowed or nil); require_approval = (state.req ~= "" and state.req or nil); enabled = state.enabled ~= false }
		table.insert(sv, entry)
		rebuild()
	end })

	local list_holder = {}
	local function clear()
		if not list_holder or not list_holder.Elements then return end
		for _, el in ipairs(list_holder.Elements) do if el.Holder then el.Holder:Destroy() end end
		list_holder.Elements = {}
	end

	local function add_row(idx, entry)
		right:AddLabel(string.format("%s (%s)", entry.label or "", entry.url or ""))
		right:AddToggle("mcp_en_"..idx, { Text = "enabled"; Default = entry.enabled == nil and true or not not entry.enabled; Callback = function(v) entry.enabled = v end })
		right:AddButton({ Text = "remove"; Func = function()
			table.remove(sv, idx)
			rebuild()
		end })
	end

	rebuild = function()
		clear()
		for i, e in ipairs(sv) do add_row(i, e) end
		if #sv == 0 then right:AddLabel("no servers added") end
	end

	rebuild()

	return { tab = tab }
end

return { attach = attach }
