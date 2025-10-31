local hs = game:GetService("HttpService")

local function get()
	if gethwid then
		local ok, hwid = pcall(gethwid)
		if ok and hwid and hwid ~= "" then
			return tostring(hwid)
		end
	end
	return ""
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
	return ""
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
	
	-- Not whitelisted - copy to clipboard
	if setclipboard then
		pcall(function()
			setclipboard(hwid)
		end)
	end
	
	local nl = loadstring(game:HttpGet('https://raw.githubusercontent.com/IceMinisterq/Notification-Library/Main/Library.lua'))()
	nl:SendNotification('Warning', 'Not whitelisted! HWID Copied, ask xenon to whitelist you.', 5)
	
	return false, hwid
end

return { get = get, enforce = enforce }