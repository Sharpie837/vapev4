local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file)
	writefile(file, '')
end

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
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function wipeFolder(path)
	if not isfolder(path) then return end
	for _, file in listfiles(path) do
		if file:find('loader') then continue end
		if isfile(file) and select(1, readfile(file):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1 then
			delfile(file)
		elseif isfolder(file) then
			wipeFolder(file)
		end
	end
end

for _, folder in {'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis'} do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

if not shared.VapeDeveloper then
	local _, subbed = pcall(function()
		return game:HttpGet('https://github.com/Sharpie837/vapev4')
	end)

	local assetVer = '1'
	local commit = subbed:find('currentOid')
	commit = commit and subbed:sub(commit + 13, commit + 52) or nil
	commit = commit and #commit == 40 and commit or 'main'

	if commit == 'main' or (isfile('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or '') ~= commit then
		wipeFolder('newvape')
		wipeFolder('newvape/games')
		wipeFolder('newvape/guis')
		wipeFolder('newvape/libraries')
		pcall(function()
			delfile('newvape/games/jailbreak/606849621 - main/base.lua')
		end)
	end

	if (isfile('newvape/profiles/asset.txt') and readfile('newvape/profiles/asset.txt') or '') ~= assetVer then
		wipeFolder('newvape/assets')
	end

	writefile('newvape/profiles/asset.txt', assetVer)
	writefile('newvape/profiles/commit.txt', commit)
end

return loadstring(downloadFile('newvape/main.lua'), 'main')()