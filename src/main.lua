repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

local function stripBOM(str)
	if type(str) == 'string' and str:sub(1, 3) == '\239\187\191' then
		return str:sub(4)
	end
	return str
end

local vape
local loadstring = function(source, chunk)
	local cleanSource = stripBOM(source)
	local res, err = loadstring(cleanSource, chunk)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
	end
	return res or function() end
end
local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file)
	pcall(function() writefile(file, '') end)
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))

local function is404(res)
	return type(res) ~= 'string' or (#res < 50 and (res:sub(1, 14) == '404: Not Found' or res:sub(1, 13) == '404 Not Found'))
end

local function downloadFile(path, func)
	if not isfile(path) then
		local rel = select(1, path:gsub('newvape/', ''))
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/Sharpie837/vapev4/main/src/'..rel, true)
		end)
		if (not suc or is404(res)) and rel:find('assets/new/') then
			suc, res = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/Sharpie837/vapev4/main/src/'..rel:gsub('assets/new/', 'guis/new/assets/'), true)
			end)
		end
		if not suc or is404(res) then
			error(res or '404: Not Found')
		end
		if path:find('.lua') then
			res = stripBOM(res)
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function finishLoading()
	vape.Init = nil
	vape:Load()
	task.spawn(function()
		repeat
			vape:Save()
			task.wait(10)
		until not vape.Loaded
	end)

	local teleportedServers
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not teleportedServers) and (not shared.VapeIndependent) then
			teleportedServers = true
			local teleportScript = [[
				shared.vapereload = true
				if shared.VapeDeveloper then
					loadstring(readfile('newvape/loader.lua'), 'loader')()
				else
					loadstring(game:HttpGet('https://raw.githubusercontent.com/Sharpie837/vapev4/main/src/loader.lua', true), 'loader')()
				end
			]]
			if shared.VapeDeveloper then
				teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
			end
			if shared.VapeCustomProfile then
				teleportScript = 'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'..teleportScript
			end
			vape:Save()
			queue_on_teleport(teleportScript)
		end
	end))

	if not shared.vapereload then
		if not vape.Categories then return end
		if vape.Settings.GUI.Options['GUI bind indicator'].Enabled then
			vape:CreateNotification('Finished Loading', vape.VapeButton and 'Press the button in the top right to open GUI' or 'Press '..table.concat(vape.GUIBind.Keys, ' + '):upper()..' to open GUI', 5)
		end
	end
end

if not isfile('newvape/profiles/gui.txt') then
	writefile('newvape/profiles/gui.txt', 'new')
end
local gui = 'new'--readfile('newvape/profiles/gui.txt')

if not isfolder('newvape/assets/'..gui) then
	makefolder('newvape/assets/'..gui)
end
vape = loadstring(downloadFile('newvape/guis/'..gui..'.lua'), 'gui')()
shared.vape = vape

if not shared.VapeIndependent then
	local isJailbreak = game.PlaceId == 606849621 or game.PlaceId == 17190407811 or game.GameId == 245662005
	if not isJailbreak then
		local universal = loadstring(downloadFile('newvape/games/universal.lua'), 'universal')
		if type(universal) == 'function' then universal() end
		local gamePath = 'newvape/games/'..game.PlaceId..'.lua'
		if isfile(gamePath) then
			local content = readfile(gamePath)
			if is404(content) then
				delfile(gamePath)
			else
				local gameFunc = loadstring(content, tostring(game.PlaceId))
				if type(gameFunc) == 'function' then
					gameFunc(...)
				end
			end
		else
			if not shared.VapeDeveloper then
				local success, data = pcall(downloadFile, gamePath)
				if success and not is404(data) then
					local gameFunc = loadstring(data, tostring(game.PlaceId))
					if type(gameFunc) == 'function' then
						gameFunc(...)
					end
				end
			end
		end
	else
		pcall(function()
			delfile('newvape/games/jailbreak/606849621 - main/base.lua')
		end)
		local place = (game.PlaceId == 17190407811 and '17190407811' or '606849621')
		local cacheFile = 'newvape/games/'..place..'.lua'
		if isfile(cacheFile) then
			local suc, content = pcall(readfile, cacheFile)
			if (not suc) or (not content:find('entitylibrary')) or is404(content) then
				delfile(cacheFile)
			end
		end
		if isfile(cacheFile) and readfile(cacheFile) ~= '' then
			local func = loadstring(readfile(cacheFile), place)
			if type(func) == 'function' then
				func(...)
			end
		else
			local success, data = pcall(downloadFile, cacheFile)
			if success and not is404(data) then
				local func = loadstring(data, place)
				if type(func) == 'function' then
					func(...)
				end
			end
		end
	end
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end