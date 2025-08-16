local hs = game:GetService("HttpService")

local function http()
	return (syn and syn.request) or request or http_request
end

local function get()
	local req = http()
	if not req then return "" end
	
	local ok, res = pcall(function()
		return req({ Url = "https://httpbin.org/get"; Method = "GET"; })
	end)
	
	if not ok or not res or not res.Body then return "" end
	
	local ok2, decoded = pcall(hs.JSONDecode, hs, res.Body)
	if not ok2 or type(decoded) ~= "table" or type(decoded.headers) ~= "table" then return "" end
	
	return decoded.headers["Syn-Fingerprint"] or ""
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
	
	return {}
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
	local hwid = get()
	
	if hwid == "" then
		local nl = loadstring(game:HttpGet('https://raw.githubusercontent.com/IceMinisterq/Notification-Library/Main/Library.lua'))()
		nl:SendNotification('Error', 'Could not get HWID. Please dm '..dm, 5)
		return false, ""
	end
	
	local raw = fetch(url)
	local wl = parse_whitelist(raw)
	
	-- Check if HWID is in whitelist
	if wl[hwid] then
		return true, hwid
	end
	
	-- Not whitelisted - try to copy to clipboard
	local copied = false
	if setclipboard then
		local ok = pcall(function()
			setclipboard(hwid)
			copied = true
		end)
		if not ok then copied = false end
	end
	
	local nl = loadstring(game:HttpGet('https://raw.githubusercontent.com/IceMinisterq/Notification-Library/Main/Library.lua'))()
	
	if copied then
		nl:SendNotification('Access Denied', 'HWID: '..hwid..' copied to clipboard. Please dm '..dm..' to be whitelisted', 8)
	else
		nl:SendNotification('Access Denied', 'HWID: '..hwid..' - Please dm '..dm..' with this HWID to be whitelisted', 10)
	end
	
	return false, hwid
end

return { get = get, enforce = enforce }