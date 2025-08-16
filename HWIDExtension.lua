local hs = game:GetService("HttpService")

local function http()
	return (syn and syn.request) or request or http_request
end

local function get()
	-- Try to get fingerprint from httpbin first
	local req = http()
	if req then
		local ok, res = pcall(function()
			return req({ Url = "https://httpbin.org/get"; Method = "GET"; })
		end)
		if ok and res and res.Body then
			local ok2, dec = pcall(hs.JSONDecode, hs, res.Body)
			if ok2 and type(dec) == "table" and type(dec.headers) == "table" then
				for k,v in pairs(dec.headers) do
					local n = tostring(k):lower()
					if n:find("fingerprint") or n:find("hwid") then 
						local hw = tostring(v or "")
						if hw ~= "" then return hw end
					end
				end
			end
		end
	end
	
	-- Fallback: generate based on game and executor info
	local plr = game:GetService("Players").LocalPlayer
	local userid = plr and plr.UserId or 0
	local username = plr and plr.Name or "Unknown"
	local exec = identifyexecutor and identifyexecutor() or "Unknown"
	local jobid = game.JobId or "LocalServer"
	
	-- Create a unique identifier
	local raw = string.format("%s_%s_%s_%s", username, userid, exec, jobid:sub(1,8))
	local hash = ""
	for i = 1, #raw do
		hash = hash .. string.format("%02x", string.byte(raw, i))
	end
	
	return "HWID_" .. hash:sub(1, 16):upper()
end

local function parse_whitelist(s)
	if type(s) ~= "string" or #s == 0 then return {} end
	
	-- Try as lua table first (return {...})
	local ok, fn = pcall(loadstring, s)
	if ok and fn then
		local ok2, tbl = pcall(fn)
		if ok2 and type(tbl) == "table" then
			local m = {}
			for _,x in ipairs(tbl) do 
				if type(x) == "string" and x ~= "" then m[x] = true end 
			end
			return m
		end
	end
	
	-- Fallback to JSON array
	if s:sub(1,1) == "[" then
		local ok, arr = pcall(hs.JSONDecode, hs, s)
		if ok and type(arr) == "table" then
			local m = {}
			for _,x in ipairs(arr) do if type(x) == "string" and x ~= "" then m[x] = true end end
			return m
		end
	end
	
	-- Fallback to newline separated
	local m = {}
	for line in s:gmatch("([^\r\n]+)") do
		local t = line:gsub("^%s+",""):gsub("%s+$","")
		if t ~= "" and not t:match("^%-%-") and not t:match("^#") then m[t] = true end
	end
	return m
end

local function fetch(url)
	local ok, body = pcall(game.HttpGet, game, url)
	if ok and type(body) == "string" and #body > 0 then return body end
	local r = http()
	if not r then return "" end
	local ok2, res = pcall(function()
		return r({ Url = url; Method = "GET"; })
	end)
	return (ok2 and res and res.Body) and res.Body or ""
end

local function enforce(opt)
	opt = opt or {}
	local url = opt.url or "https://raw.githubusercontent.com/clippyarchives/Obsidian/feature/ide-extension/hwids.txt"
	local dm = opt.dm or "xenon9012"
	local hw = get()
	local raw = fetch(url)
	local wl = parse_whitelist(raw)
	local cnt = 0; for _ in pairs(wl) do cnt = cnt + 1 end
	local ok = (cnt == 0) or (wl[hw] == true)
	
	if not ok then
		-- Copy HWID to clipboard
		if setclipboard and hw ~= "" then
			setclipboard(hw)
		end
		
		-- Show notification
		local nl = loadstring(game:HttpGet('https://raw.githubusercontent.com/IceMinisterq/Notification-Library/Main/Library.lua'))()
		if hw ~= "" then
			nl:SendNotification('Access Denied', 'HWID: '..hw..' not registered. Please dm '..dm..' to be whitelisted. HWID copied to clipboard.', 8)
		else
			nl:SendNotification('Access Denied', 'Could not generate HWID. Please dm '..dm..' for manual whitelist.', 8)
		end
	end
	return ok, hw
end

return { get = get, enforce = enforce }