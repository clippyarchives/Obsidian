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

local function ensure_defaults()
	if getgenv().mcp_enabled == nil then getgenv().mcp_enabled = false end
	if getgenv().mcp_use_in_chat == nil then getgenv().mcp_use_in_chat = false end
	getgenv().mcp_servers = getgenv().mcp_servers or {}
	if #getgenv().mcp_servers == 0 then
		table.insert(getgenv().mcp_servers, {
			label = "mem0";
			url = "https://server.smithery.ai/@big-omega/mem0-mcp/mcp";
			require_approval = "never";
			enabled = true;
		})
	end
end

local function attach(win, opt)
	opt = opt or {}
	ensure_defaults()
	local sv = getgenv().mcp_servers

	local tab = win:AddTab("MCP", "globe")
	local quick = tab:AddLeftGroupbox("Quick Start")
	local left = tab:AddLeftGroupbox("Add Server")
	local right = tab:AddRightGroupbox("Servers")

	quick:AddLabel({ Text = "1) Enable MCP"; DoesWrap = false })
	quick:AddToggle("mcp_global_enable", { Text = "Enable MCP"; Default = getgenv().mcp_enabled; Callback = function(v) getgenv().mcp_enabled = v end })
	quick:AddLabel({ Text = "2) Use MCP in AI Chat (toggle this ON)"; DoesWrap = true })
	quick:AddToggle("mcp_use_in_chat", { Text = "Use MCP in AI Chat"; Default = getgenv().mcp_use_in_chat; Callback = function(v) getgenv().mcp_use_in_chat = v end })
	quick:AddLabel({ Text = "Example server added by default: Mem0"; DoesWrap = true })
	quick:AddButton({ Text = "Re-add Example (Mem0)"; Func = function()
		local exists = false
		for _, e in ipairs(sv) do if (e.label == "mem0" or e.url == "https://server.smithery.ai/@big-omega/mem0-mcp/mcp") then exists = true break end end
		if not exists then
			table.insert(sv, { label = "mem0"; url = "https://server.smithery.ai/@big-omega/mem0-mcp/mcp"; require_approval = "never"; enabled = true })
			rebuild()
		end
	end })
	quick:AddLabel({ Text = "Docs: modelcontextprotocol.io/introduction"; DoesWrap = true })
	quick:AddLabel({ Text = "Mem0 page: smithery.ai/server/@big-omega/mem0-mcp"; DoesWrap = true })

	local state = { label = "", url = "", headers = {}, allowed = {}, req = "", enabled = true }
	left:AddInput("mcp_label", { Text = "server label"; Default = ""; Finished = true; ClearTextOnFocus = false; Callback = function(v) state.label = v end })
	left:AddInput("mcp_url", { Text = "server url"; Default = ""; Finished = true; ClearTextOnFocus = false; Callback = function(v) state.url = v end })
	left:AddInput("mcp_headers", { Text = "headers (json obj)"; Default = ""; Finished = true; ClearTextOnFocus = false; Callback = function(v) state.headers = safe_json_decode(v) or {} end })
	left:AddInput("mcp_allowed", { Text = "allowed_tools (comma)"; Default = ""; Finished = true; ClearTextOnFocus = false; Callback = function(v) state.allowed = parse_list(v) end })
	left:AddDropdown("mcp_req", { Text = "require_approval"; Values = {"", "never"}; Default = 1; Callback = function(v) state.req = v end })
	left:AddToggle("mcp_enabled", { Text = "enabled"; Default = true; Callback = function(v) state.enabled = v end })
	left:AddButton({ Text = "Add Server"; Func = function()
		if state.label == "" or state.url == "" then return end
		local entry = { label = state.label; url = state.url; headers = state.headers; allowed_tools = (#state.allowed>0 and state.allowed or nil); require_approval = (state.req ~= "" and state.req or nil); enabled = state.enabled ~= false }
		table.insert(sv, entry)
		rebuild()
	end })

	local function clear()
		if right.Elements then
			for _, el in ipairs(right.Elements) do if el.Holder then el.Holder:Destroy() end end
			right.Elements = {}
		end
	end

	rebuild = function()
		clear()
		for i, entry in ipairs(sv) do
			right:AddLabel(string.format("%s (%s)", entry.label or "", entry.url or ""))
			right:AddToggle("mcp_en_"..i, { Text = "enabled"; Default = entry.enabled ~= false; Callback = function(v) entry.enabled = v end })
			right:AddButton({ Text = "remove"; Func = function() table.remove(sv, i) rebuild() end })
			right:AddDivider()
		end
		if #sv == 0 then right:AddLabel("no servers added") end
	end

	rebuild()

	return { tab = tab }
end

return { attach = attach }
