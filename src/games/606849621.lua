local isfile = isfile or function(file)
	local suc, res = pcall(function() return readfile(file) end)
	return suc and res ~= nil and res ~= ''
end
local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function() return game:HttpGet('https://raw.githubusercontent.com/Sharpie837/vapev4/main/src/'..select(1, path:gsub('newvape/', '')), true) end)
		if not suc or res == '404: Not Found' then error(res) end
		if path:find('.lua') then res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

if isfile('newvape/games/jailbreak/606849621 - main/base.lua') then
	loadstring(readfile('newvape/games/jailbreak/606849621 - main/base.lua'), 'jailbreak')(...)
else
	loadstring(downloadFile('newvape/games/jailbreak/606849621 - main/base.lua'), 'jailbreak')(...)
end
