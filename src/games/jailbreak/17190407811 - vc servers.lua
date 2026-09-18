local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert') end
	return res
end
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
local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local textService = cloneref(game:GetService('TextService'))
local tweenService = cloneref(game:GetService('TweenService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local contextService = cloneref(game:GetService('ContextActionService'))
local httpService = cloneref(game:GetService('HttpService'))
local teams = cloneref(game:GetService('Teams'))

local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer

local vape = shared.vape
local hash = vape.Libraries.hash or loadstring(downloadFile('newvape/libraries/hash.lua'), 'hash')()
local prediction = vape.Libraries.prediction or loadstring(downloadFile('newvape/libraries/prediction.lua'), 'prediction')()
local entitylib = vape.Libraries.entity or loadstring(downloadFile('newvape/libraries/entity.lua'), 'entitylibrary')()
local whitelist = vape.Libraries.whitelist or {
	alreadychecked = {},
	customtags = {},
	tagcallback = {},
	data = {WhitelistedUsers = {}},
	hashes = setmetatable({}, {
		__index = function(_, data)
			return hash and hash.sha512(data..'SelfReport') or ''
		end
	}),
	get = function() return 0, true end,
	hooked = false,
	loaded = false,
	localprio = 0,
	said = {}
}
vape.Libraries.entity = entitylib
vape.Libraries.whitelist = whitelist
vape.Libraries.prediction = prediction
vape.Libraries.hash = hash
local targetinfo = vape.Libraries.targetinfo or {Targets = {}}
vape.Libraries.targetinfo = targetinfo
local sessioninfo = vape.Libraries.sessioninfo or {AddItem = function() end, Objects = {}}
vape.Libraries.sessioninfo = sessioninfo
local vm = loadstring(downloadFile('newvape/libraries/vm.lua'), 'vm')()

local jb = {}
local Spring = {}
local InfNitro = {Enabled = false}
local LazerGodmode = {Enabled = false}
local InvTracker = {Inventories = {}, Connections = {}}
local oldBulletUpdate
local aimTimer, shootTimer, aimVec = os.clock(), os.clock()

local function getTableSize(dict)
	local size = 0
	for _ in dict do
		size += 1
	end

	return size
end

local function getVehicle(entity)
	if entity.Player then
		for _, car in collectionService:GetTagged('Vehicle') do
			for _, seat in car:GetChildren() do
				if (seat.Name == 'Seat' or seat.Name == 'Passenger') then
					seat = seat:FindFirstChild('PlayerName')
					if seat and seat.Value == entity.Player.Name then
						return car
					end
				end
			end
		end
	end
end

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end

	return nil
end

local function isIllegal(entity, teamCheck)
	if entity.Character:GetAttribute('HasHandcuffs') then
		return false
	end

	if entity.Player and entity.Player.Team == teams.Prisoner then
		for tool in InvTracker.Inventories[entity.Player] do
			if tool ~= 'MansionInvite' and tool ~= 'Donut' then
				return true
			end
		end

		return entity.InVehicle
	end

	return not teamCheck
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function notif(...)
	return vape:CreateNotification(...)
end

local frictionTable, oldfrict = {}, {}
local function updateVelocity()
	if getTableSize(frictionTable) > 0 then
		if entitylib.isAlive then
			for _, part in entitylib.character.Character:GetChildren() do
				if part:IsA('BasePart') and part.Name ~= 'HumanoidRootPart' and not oldfrict[part] then
					oldfrict[part] = part.CustomPhysicalProperties or 'none'
					part.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
				end
			end
		end
	else
		for part, data in oldfrict do
			part.CustomPhysicalProperties = data ~= 'none' and data or nil
		end

		table.clear(oldfrict)
	end
end

local OriginScanner = {Cache = {}}
run(function()
	local rayParams = RaycastParams.new()
	local overlapParams = OverlapParams.new()
	rayParams.RespectCanCollide = true
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.RespectCanCollide = true
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	OriginScanner.Ray = rayParams

	local positions = {
		Vector3.new(0, 1, 0),
		Vector3.new(1, 0, 0),
		Vector3.new(0.7, -0.5, -0.5),
		Vector3.new(-0.1, -0.8, -0.8),
		Vector3.new(-0.8, -0.5, -0.5),
		Vector3.new(-1, 0, 0),
		Vector3.new(-0.8, 0.4, 0.4),
		Vector3.new(0, 0.7, 0.7),
		Vector3.new(0.7, 0.5, 0.5),
		Vector3.new(1, 0, 0),
		Vector3.new(0.7, 0, -0.8),
		Vector3.new(-0.1, 0, -1),
		Vector3.new(-0.8, 0, -0.8),
		Vector3.new(-1, 0, 0),
		Vector3.new(-0.8, 0, 0.7),
		Vector3.new(0, 0, 1),
		Vector3.new(0.7, 0, 0.7),
		Vector3.new(1, 0, 0),
		Vector3.new(0.7, 0.4, -0.5),
		Vector3.new(-0.1, 0.7, -0.8),
		Vector3.new(-0.8, 0.4, -0.5),
		Vector3.new(-1, -0.1, 0),
		Vector3.new(-0.8, -0.5, 0.4),
		Vector3.new(0, -0.8, 0.7),
		Vector3.new(0.7, -0.6, 0.5),
		Vector3.new(0, -1, 0)
	}

	local function checkPoint(pos, params)
		for _, part in workspace:GetPartBoundsInRadius(pos, 0, params) do
			if part.CanCollide and (part:GetClosestPointOnSurface(pos) - pos).Magnitude <= 0.0001 then
				return false
			end
		end

		local _, occu = workspace.Terrain:ReadVoxels(Region3.new(pos - Vector3.one * 0.1, pos + Vector3.one * 0.1):ExpandToGrid(4), 4)
		return occu[1][1][1] == 0
	end

	function OriginScanner:Scan(origin, target, extra, part, entity)
		if self.Cache[part] then
			return table.unpack(self.Cache[part])
		end

		local hitboxPositions = {target}
		if extra and (origin - extra).Magnitude < 14 then
			self.Cache[part] = {extra}
			return extra
		end

		local scanPositions = {origin}
		local diff = CFrame.lookAt(origin * Vector3.new(1, 0, 1), target * Vector3.new(1, 0, 1)).LookVector
		for _, normal in Enum.NormalId:GetEnumItems() do
			local offset = Vector3.fromNormalId(normal)

			if (offset * Vector3.new(1, 0, 1)):Dot(-diff) > -0.5 then
				local pos = entity.RootPart.Position + offset * 20

				if checkPoint(pos, overlapParams) then
					table.insert(hitboxPositions, pos)
				end
			end
		end

		for _, offset in positions do
			if (offset * Vector3.new(1, 0, 1)):Dot(diff) > -0.5 then
				local pos = origin + offset * 14

				if checkPoint(pos, overlapParams) then
					table.insert(scanPositions, pos)
				end
			end
		end

		for _, hitbox in hitboxPositions do
			for _, pos in scanPositions do
				local ray = workspace:Raycast(hitbox, (pos - hitbox), rayParams)

				if not ray then
					self.Cache[part] = {pos, hitbox ~= target and hitbox or nil}
					return pos, hitbox
				end
			end
		end
	end

	function OriginScanner:UpdateIgnore(data)
		local ignore = {lplr.Character, workspace.Items, unpack(data)}
		for _, entity in entitylib.List do
			table.insert(ignore, entity.Character)
		end

		rayParams.FilterDescendantsInstances = ignore
		overlapParams.FilterDescendantsInstances = ignore
	end
end)

run(function()
	function InvTracker:AddInventory(inventory)
		local plr = inventory.Parent
		if plr and plr:IsA('Player') then
			self.Inventories[plr] = {}
			self.Connections[inventory] = {
				inventory.ChildAdded:Connect(function(tool)
					self.Inventories[plr][tool.Name] = tool

					if plr == lplr then
						vapeEvents.ItemAdded:Fire(tool)
					else
						local entity = entitylib.getEntity(plr)
						if entity then
							entitylib.Events.EntityUpdated:Fire(entity)
						end
					end
				end),
				inventory.ChildRemoved:Connect(function(tool)
					self.Inventories[plr][tool.Name] = nil

					if plr ~= lplr then
						local entity = entitylib.getEntity(plr)
						if entity then
							entitylib.Events.EntityUpdated:Fire(entity)
						end
					end
				end),
				inventory.Destroying:Once(function()
					for _, connection in self.Connections[inventory] do
						connection:Disconnect()
					end

					table.clear(self.Connections[inventory])
					table.clear(self.Inventories[plr])
					self.Inventories[plr] = nil
				end)
			}

			for _, tool in inventory:GetChildren() do
				self.Inventories[plr][tool.Name] = tool
			end
		end
	end

	for _, inventory in collectionService:GetTagged('Inventory') do
		InvTracker:AddInventory(inventory)
	end

	vape:Clean(collectionService:GetInstanceAddedSignal('Inventory'):Connect(function(inventory)
		InvTracker:AddInventory(inventory)
	end))

	vape:Clean(function()
		for _, connections in InvTracker.Connections do
			for _, connection in connections do
				connection:Disconnect()
			end
		end

		table.clear(InvTracker.Connections)
		table.clear(InvTracker.Inventories)
	end)
end)

local BountyTracker = {Data = {}, List = {}}
run(function()
	function BountyTracker:UpdateData(data, update)
		table.clear(self.Data)
		table.clear(self.List)

		for _, entry in data do
			self.Data[entry.Name] = entry.Bounty
			table.insert(self.List, {entry.Name, entry.Bounty})
		end

		table.sort(self.List, function(a, b)
			return a[2] > b[2]
		end)

		if update then
			for _, entity in entitylib.List do
				entitylib.Events.EntityUpdated:Fire(entity)
			end
		end
	end

	BountyTracker:UpdateData(httpService:JSONDecode(replicatedStorage.BountyData.Value))
	vape:Clean(replicatedStorage.BountyData:GetPropertyChangedSignal('Value'):Connect(function()
		BountyTracker:UpdateData(httpService:JSONDecode(replicatedStorage.BountyData.Value), true)
	end))
end)

run(function()
	local function getMousePosition()
		if inputService.TouchEnabled then
			return gameCamera.ViewportSize / 2
		end

		return inputService:GetMouseLocation()
	end

	entitylib.getUpdateConnections = function(entity)
		local hum = entity.Humanoid
		entity.InVehicle = not entity.Character:GetAttribute('HasHandcuffs') and (entity.Character:GetAttribute('InVehicle') or entity.InVehicle)
		entity.Illegal = isIllegal(entity, true)

		return {
			hum:GetPropertyChangedSignal('Health'),
			hum:GetPropertyChangedSignal('MaxHealth'),
			entity.Character:GetAttributeChangedSignal('InVehicle'),
			entity.Character:GetAttributeChangedSignal('HasHandcuffs'),
			{
				Connect = function()
					entity.Friend = entity.Player and isFriend(entity.Player) or nil
					entity.Target = entity.Player and isTarget(entity.Player) or nil
					return {Disconnect = function() end}
				end
			}
		}
	end

	entitylib.targetCheck = function(entity)
		if entity.TeamCheck then return entity:TeamCheck() end
		if entity.NPC then return true end
		if isFriend(entity.Player) then return false end
		if not select(2, whitelist:get(entity.Player)) then return false end

		if lplr.Team == teams.Police then
			return entity.Player.Team ~= teams.Police
		else
			return entity.Player.Team == teams.Police
		end

		return true
	end

	entitylib.EntityMouse = function(entitysettings)
		if entitylib.isAlive then
			local mouseLocation, sortingTable = entitysettings.MouseOrigin or getMousePosition(), {}
			local localPosition = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position
			for _, entity in entitylib.List do
				if not entitysettings.Players and entity.Player then continue end
				if not entitysettings.NPCs and entity.NPC then continue end
				if not entity.Targetable then continue end
				local position, vis = gameCamera.WorldToViewportPoint(gameCamera, entity[entitysettings.Part].Position)
				if not vis then continue end
				local mag = (mouseLocation - Vector2.new(position.x, position.y)).Magnitude
				if mag > entitysettings.Range then continue end
				if entitylib.isVulnerable(entity, entitysettings.AttackCheck) then
					if entitysettings.RangePosition then
						local pmag = (entity[entitysettings.Part].Position - localPosition).Magnitude
						if pmag > entitysettings.RangePosition then continue end
					end

					table.insert(sortingTable, {
						Entity = entity,
						Magnitude = entity.Target and -1 or mag
					})
				end
			end

			table.sort(sortingTable, entitysettings.Sort or function(a, b)
				return a.Magnitude < b.Magnitude
			end)

			for _, v in sortingTable do
				if entitysettings.Wallcheck then
					if entitylib.Wallcheck(entitysettings.Origin, v.Entity[entitysettings.Part].Position, entitysettings.Wallbang, v.Entity[entitysettings.Part], v.Entity) then continue end
				end
				table.clear(entitysettings)
				table.clear(sortingTable)
				return v.Entity
			end
			table.clear(sortingTable)
		end
		table.clear(entitysettings)
	end

	entitylib.EntityPosition = function(entitysettings)
		if entitylib.isAlive then
			local localPosition, sortingTable = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position, {}
			for _, entity in entitylib.List do
				if not entitysettings.Players and entity.Player then continue end
				if not entitysettings.NPCs and entity.NPC then continue end
				if not entity.Targetable then continue end
				local mag = (entity[entitysettings.Part].Position - localPosition).Magnitude
				if mag > entitysettings.Range then continue end
				if entitylib.isVulnerable(entity, entitysettings.AttackCheck) then
					table.insert(sortingTable, {
						Entity = entity,
						Magnitude = entity.Target and -1 or mag
					})
				end
			end

			table.sort(sortingTable, entitysettings.Sort or function(a, b)
				return a.Magnitude < b.Magnitude
			end)

			for _, v in sortingTable do
				if entitysettings.Wallcheck then
					if entitylib.Wallcheck(localPosition, v.Entity[entitysettings.Part].Position, entitysettings.Wallbang, v.Entity[entitysettings.Part], v.Entity) then continue end
				end
				table.clear(entitysettings)
				table.clear(sortingTable)
				return v.Entity
			end
			table.clear(sortingTable)
		end
		table.clear(entitysettings)
	end

	entitylib.AllPosition = function(entitysettings)
		local returned = {}
		if entitylib.isAlive then
			local localPosition, sortingTable = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position, {}
			for _, entity in entitylib.List do
				if not entitysettings.Players and entity.Player then continue end
				if not entitysettings.NPCs and entity.NPC then continue end
				if not entity.Targetable then continue end
				local mag = (entity[entitysettings.Part].Position - localPosition).Magnitude
				if mag > entitysettings.Range then continue end
				if entitylib.isVulnerable(entity, entitysettings.AttackCheck) then
					table.insert(sortingTable, {
						Entity = entity,
						Magnitude = entity.Target and -1 or mag
					})
				end
			end

			table.sort(sortingTable, entitysettings.Sort or function(a, b)
				return a.Magnitude < b.Magnitude
			end)

			for _, v in sortingTable do
				if entitysettings.Wallcheck then
					if entitylib.Wallcheck(localPosition, v.Entity[entitysettings.Part].Position, entitysettings.Wallbang, v.Entity[entitysettings.Part], v.Entity) then continue end
				end
				table.insert(returned, v.Entity)
				if #returned >= (entitysettings.Limit or math.huge) then break end
			end
			table.clear(sortingTable)
		end
		table.clear(entitysettings)
		return returned
	end

	entitylib.Wallcheck = function(origin, position, checkPosition, part, entity)
		local ray = workspace.Raycast(workspace, position, (origin - position), OriginScanner.Ray)
		if ray then
			return not checkPosition or not OriginScanner:Scan(checkPosition, position, ray and ray.Position + ray.Normal * 0.01 or nil, part, entity)
		end

		return false
	end

	local oldstart = entitylib.start
	local function customEntity(ent)
		local plr = playersService:GetPlayerFromCharacter(ent.Parent)
		if not plr then
			entitylib.addEntity(ent.Parent)
		end
	end

	entitylib.start = function()
		oldstart()
		if entitylib.Running then
			for _, ent in collectionService:GetTagged('Humanoid') do
				customEntity(ent)
			end

			table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('Humanoid'):Connect(customEntity))
			table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('Humanoid'):Connect(function(ent)
				entitylib.removeEntity(ent.Parent)
			end))
		end
	end
end)
entitylib.start()

run(function()
	local function dumpRemotes(scripts, renamed)
		local returned = {}

		for _, scr in scripts do
			local deserializedcode = vm.luau_deserialize(getscriptbytecode(scr))

			for _, proto in deserializedcode.protoList do
				local stack, top, code = {}, -1, proto.code
				for i, inst in code do
					if inst.opcode == 4 then -- LOADN
						stack[inst.A] = inst.D
					elseif inst.opcode == 5 then -- LOADK
						stack[inst.A] = inst.K
					elseif inst.opcode == 6 then -- MOVE
						stack[inst.A] = stack[inst.B]
					elseif inst.opcode == 12 then -- GETIMPORT
						local count, import = inst.KC, getrenv()[inst.K0]

						if count == 1 then
							stack[inst.A] = import
						elseif count == 2 then
							stack[inst.A] = import[inst.K1]
						elseif count == 3 then
							stack[inst.A] = import[inst.K1][inst.K2]
						end
					elseif inst.opcode == 20 then -- NAMECALL
						local A, B, kv = inst.A, inst.B, inst.K
						stack[A + 1] = stack[B]

						local callInst = code[i + 2]
						local callA, callB, callC = callInst.A, callInst.B, callInst.C
						local params = if callB == 0 then top - callA else callB - 1
						if kv == 'sub' or kv == 'reverse' then
							local arg1, arg2, arg3 = table.unpack(stack, callA + 1, callA + params)
							if kv == 'reverse' and not arg1 then arg1 = 'a' end

							local ret_list = table.pack(string[kv](arg1, arg2, arg3))
							local ret_num = ret_list.n - 1
							if callC == 0 then
								top = callA + ret_num - 1
							else
								ret_num = callC - 1
							end

							table.move(ret_list, 1, ret_num, callA, stack)
						elseif kv == 'FireServer' then
							local name, val = proto.debugname == '(??)' and scr.Name or proto.debugname, stack[callA + 2]
							if name == val then table.insert(returned, val) continue end
							if returned[name] then
								for i = 1, 10 do
									if not returned[name..i] then name ..= i break end
								end
							end

							returned[name] = val
						end
					elseif inst.opcode == 49 then -- CONCAT
						local s = ""
						for i = inst.B, inst.C do
							if type(stack[i]) ~= 'string' then continue end
							s ..= stack[i]
						end
						stack[inst.A] = s
					end
				end
			end
		end

		for i, v in table.clone(returned) do
			if renamed[i] then
				returned[i] = nil
				returned[renamed[i]] = v
			end
		end

		return returned
	end

	local function getAwardEvent()
		for _, callback in debug.getupvalue(jb.TeamChooseController.Init, 2) do
			if type(callback) == 'function' then
				for _, const in debug.getconstants(callback) do
					if tostring(const):find('PlusCash') then
						return callback
					end
				end
			end
		end
	end

	local function toMoney(num)
		local one, two, three = string.match(tostring(num), '^([^%d]*%d)(%d*)(.-)$')
		return one .. (two:reverse():gsub('(%d%d%d)', '%1,'):reverse() .. three)..'$'
	end

	jb = {
		AlexChassis = require(replicatedStorage.Module.AlexChassis),
		Audio = require(replicatedStorage.Std.Audio),
		BulletEmitter = require(replicatedStorage.Game.ItemSystem.BulletEmitter),
		CircleAction = require(replicatedStorage.Module.UI).CircleAction,
		FallingController = require(replicatedStorage.Game.Falling),
		GunController = require(replicatedStorage.Game.Item.Gun),
		GunUtils = require(replicatedStorage.Game.GunShop.GunUtils),
		InventoryItemBinder = require(replicatedStorage.Inventory.InventoryItemBinder),
		InventoryItemSystem = require(replicatedStorage.Inventory.InventoryItemSystem),
		ItemSystemController = require(replicatedStorage.Game.ItemSystem.ItemSystem),
		LightningUtils = require(replicatedStorage.Game.LightningUtils),
		PlayerUtils = require(replicatedStorage.Game.PlayerUtils),
		TeamChooseController = require(replicatedStorage.TeamSelect.TeamChooseUI),
		VehicleController = require(replicatedStorage.Vehicle.VehicleUtils),
		VehicleSystem = require(replicatedStorage.Game.VehicleSystem)
	}

	if not jb.VehicleController.toggleLocalLocked or not jb.VehicleController.NitroShopVisible then
		repeat
			task.wait()
		until (jb.VehicleController.toggleLocalLocked and jb.VehicleController.NitroShopVisible) or vape.Loaded == nil

		if vape.Loaded == nil then
			return
		end
	end

	local remotetable = debug.getupvalue(jb.VehicleController.toggleLocalLocked, 2)
	local fireserver, hook = remotetable.FireServer

	remotes = dumpRemotes({
		replicatedStorage.Game.TrainSystem.LocomotiveFront,
		replicatedStorage.Game.ItemSystem.ItemSystem,
		replicatedStorage.Game.CashBuyUI,
		replicatedStorage.Game.GunShop.GunShopUI,
		replicatedStorage.Game.Item.Taser,
		replicatedStorage.Game.Item.Donut,
		replicatedStorage.Game.Item.Gun,
		replicatedStorage.Game.Falling,
		lplr.PlayerScripts.LocalScript
	}, {
		Action3 = 'Pickup',
		AttemptArrest = 'Arrest',
		attemptPunch = 'Punch',
		AttemptPickPocket = 'Pickpocket',
		AttemptVehicleEject = 'Eject',
		AttemptVehicleEnter = 'GetIn',
		BroadcastInputBegan = 'InputBegan',
		BroadcastInputEnded = 'InputEnded',
		CalculateDelta = 'UseNitro',
		Draw = 'TaseReplicate',
		Gun = 'PopTires',
		GunShopUI = 'UnequipItem',
		GunShopUI1 = 'EquipItem',
		LocalScript2 = 'LookAngle',
		LocalScript = 'SelfDamage',
		onPressed = 'FlipVehicle',
		OnJump = 'GetOut',
		OnJump1 = 'GetOut',
		UpdateMousePosition = 'AimPosition'
	})

	local function FireServerHook(...)
		local self, id = ...
		local remote
		for name, key in remotes do
			if key == id then
				remote = name
			end
		end

		if InfNitro.Enabled and remote == 'UseNitro' then return end
		if LazerGodmode.Enabled and remote == 'SelfDamage' then return end
		if remote ~= 'LookAngle' and remote ~= 'AimPosition' and shared.VapeDeveloper then
			local called = getfenv(3)
			called = called and called.script
			if called and (not remote) then
				print(id, 'called with', called:GetFullName())
			end

			print(id, remote or id, ...)
		end

		return hook(...)
	end

	hook = hookfunction(fireserver, function(...)
		return FireServerHook(...)
	end)

	function jb:FireServer(id, ...)
		if not remotes[id] then
			notif('Vape', 'Failed to find remote ('..id..')', 10, 'alert')
			return
		end

		return hook(remotetable, remotes[id], ...)
	end

	local arrests = sessioninfo:AddItem('Arrested')
	local moneymade = sessioninfo:AddItem('Money Made', 0, toMoney, true)
	local bounty = sessioninfo:AddItem('Bounty List', '', function()
		local text = ''

		for _, data in BountyTracker.List do
			text = text..'\n'..data[1]..': '..toMoney(tostring(data[2]))
		end

		return text
	end, false)

	local awardCallback = getAwardEvent()
	if awardCallback then
		local hook
		hook = hookfunction(awardCallback, function(amount, text, ...)
			moneymade:Increment(amount)
			if text == 'Arrest' then
				arrests:Increment()
			end

			return hook(amount, text, ...)
		end)

		vape:Clean(function()
			restorefunction(awardCallback)
		end)
	end

	for _, connection in getconnections(runService.Heartbeat) do
		if connection.Function and islclosure(connection.Function) and #debug.getupvalues(connection.Function) > 5 then
			local upval = debug.getupvalue(connection.Function, 6)
			if type(upval) == 'function' and debug.info(upval, 'n') == 'WalkSpeedFun' then
				jb.WalkSpeedFun = upval
				break
			end
		end
	end

	table.insert(whitelist.tagcallback, function(plr, plrtag, rich)
		if plr then
			local entity = entitylib.getEntity(plr)
			if entity then
				if plr.Team == teams.Prisoner and entity.Illegal then
					table.insert(plrtag, {text = rich and '💢' or 'Hostile'})
				end

				if BountyTracker.Data[plr.Name] then
					table.insert(plrtag, {
						text = toMoney(tostring(BountyTracker.Data[plr.Name])),
						color = Color3.fromHSV(0.4, 0.89, 0.75)
					})
				end
			end
		end
	end)

	vape:Clean(runService.RenderStepped:Connect(function()
		table.clear(OriginScanner.Cache)
	end))

	vape:Clean(entitylib.Events.EntityUpdated:Connect(function(entity)
		local isInVehicle = entity.Character:GetAttribute('InVehicle')
		if entity.VehicleState ~= isInVehicle and not isInVehicle then
			entity.VehicleTimer = os.clock() + 0.3
		end

		entity.VehicleState = isInVehicle
		entity.InVehicle = not entity.Character:GetAttribute('HasHandcuffs') and (isInVehicle or entity.InVehicle)
		entity.Illegal = isIllegal(entity, true)

		if entity.Player and entity.Player.Team == teams.Prisoner then
			entity.Pickpocket = nil
		end
	end))

	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))

	vape:Clean(function()
		table.clear(remotes)
		table.clear(jb)
		restorefunction(fireserver)
	end)
end)

run(function()
	-- https://github.com/J1ck/roblox-spring/blob/main/src/roblox-spring.luau
	Spring.__index = Spring

	function Spring.new(Properties)
		local TypeRefined = Properties or {}

		local self = setmetatable({
			Target = Vector3.new(),
			Position = Vector3.new(),
			Velocity = Vector3.new(),

			Mass = TypeRefined.Mass or 5,
			Force = TypeRefined.Force or 50,
			Damping	= TypeRefined.Damping or 4,
			Speed = TypeRefined.Speed or 4,
		}, Spring)

		return self
	end

	function Spring:Update(DeltaTime)
		local IterationsThisFrame = DeltaTime / ((1 / 60) / 8)
		local ScaledDeltaTime = DeltaTime * self.Speed / IterationsThisFrame

		for i = 1, math.round(IterationsThisFrame) do
			local IterationForce = self.Target - self.Position
			local Acceleration = (IterationForce * self.Force) / self.Mass

			Acceleration -= self.Velocity * self.Damping

			self.Velocity += Acceleration * ScaledDeltaTime
			self.Position += self.Velocity * ScaledDeltaTime
		end

		return self.Position
	end
end)

for _, v in {'Reach', 'TriggerBot', 'Disabler', 'AntiFall', 'HitBoxes', 'Killaura', 'MurderMystery', 'Utility', 'World', 'Inventory'} do
	vape:Remove(v)
end

if vape.Legit and vape.Legit.Window then
	vape.Legit.Window.Visible = false
end
if vape.Categories and vape.Categories.Main and vape.Categories.Main.Object and vape.Categories.Main.Object:FindFirstChild('Search') then
	local search = vape.Categories.Main.Object.Search
	if search:FindFirstChild('Legit') then search.Legit.Visible = false end
	if search:FindFirstChild('LegitDivider') then search.LegitDivider.Visible = false end
	local box = search:FindFirstChildWhichIsA('TextBox')
	if box then box.Position = UDim2.fromOffset(10, 0) end
end

local Fly

-- Blatant/Speed
run(function()
local Speed
local Value
local CustomProperties

Speed = vape.Categories.Blatant:CreateModule({
	Name = 'Speed',
	Function = function(callback)
		frictionTable.Speed = callback and CustomProperties.Enabled or nil
		updateVelocity()
		if callback then
			Speed:Clean(runService.PreSimulation:Connect(function(dt)
				if entitylib.isAlive and not (Fly and Fly.Enabled) then
					local hum = entitylib.character.Humanoid
					local state = entitylib.character.Humanoid:GetState()
					if state == Enum.HumanoidStateType.Climbing then return end
					if hum.Sit then return end

					local root = entitylib.character.RootPart
					root.AssemblyLinearVelocity = (hum.MoveDirection * Value.Value) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
				end
			end))
		end
	end,
	Tooltip = 'Increases your movement with various methods.'
})
Value = Speed:CreateSlider({
	Name = 'Speed',
	Min = 1,
	Max = 150,
	Default = 50,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
CustomProperties = Speed:CreateToggle({
	Name = 'Custom Properties',
	Function = function()
		if Speed.Enabled then
			Speed:Toggle()
			Speed:Toggle()
		end
	end,
	Default = true
})
end)

-- Blatant/Fly
local LongJump
run(function()
	local Value
	local UpKey
	local DownKey
	local VerticalValue
	local CustomProperties
	local PlatformStanding
	local Platform, YLevel, OldYLevel
	local up, down = 0, 0

	Fly = vape.Categories.Blatant:CreateModule({
		Name = 'Fly',
		Function = function(callback)
			frictionTable.Fly = callback and CustomProperties.Enabled or nil
			updateVelocity()
			if callback then
				Platform = Instance.new('Part')
				Platform.CanQuery = false
				Platform.Anchored = true
				Platform.Size = Vector3.new(100, 1, 100)
				Platform.Transparency = 1

				Fly:Clean(Platform)
				Fly:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						if PlatformStanding.Enabled then
							entitylib.character.Humanoid.PlatformStand = true
							entitylib.character.RootPart.AssemblyAngularVelocity = Vector3.zero
							entitylib.character.RootPart.CFrame = CFrame.lookAlong(entitylib.character.RootPart.CFrame.Position, gameCamera.CFrame.LookVector)
						end

						local hum = entitylib.character.Humanoid
						local root = entitylib.character.RootPart
						if hum.Sit then
							local packet = jb.VehicleController.GetLocalVehiclePacket()
							local wheel = packet and packet.EngineThrusters[1]

							if wheel then
								local suspension = (packet.Model:GetAttribute('GarageSuspensionHeight') or 0) + packet.Height
								lplr.Character:SetAttribute('DoNotAllowVehicleExit', table.find(UpKey.Keys, 'Space') and true or false)
								packet.Seat.CFrame += Vector3.new(0, (up + down) * VerticalValue.Value * dt, 0)
								Platform.Position = wheel.Engine.Position + Vector3.new(0, -suspension, 0)
								Platform.Parent = gameCamera
							end

							return
						else
							Platform.Parent = nil
						end

						root.AssemblyLinearVelocity = (hum.MoveDirection * Value.Value) + Vector3.new(0, 2.25 + ((up + down) * VerticalValue.Value), 0)
					else
						YLevel = nil
						OldYLevel = nil
					end
				end))

				up, down = 0, 0

				Fly:Clean(UpKey.Triggered:Connect(function(isDown)
					up = isDown and 1 or 0
				end))

				Fly:Clean(DownKey.Triggered:Connect(function(isDown)
					down = isDown and -1 or 0
				end))

				if inputService.TouchEnabled then
					pcall(function()
						local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
						Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
							up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
						end))
					end)
				end
			else
				YLevel, OldYLevel = nil, nil
				if entitylib.isAlive then
					if PlatformStanding.Enabled then
						entitylib.character.Humanoid.PlatformStand = false
					end

					lplr.Character:SetAttribute('DoNotAllowVehicleExit', nil)
				end
			end
		end,
		Tooltip = 'Makes you go zoom.'
	})
	UpKey = Fly:CreateBind({
		Name = 'Up Key',
		Default = {'Space'},
		Hold = true,
		Tooltip = 'Keybind to fly upwards'
	})
	DownKey = Fly:CreateBind({
		Name = 'Down Key',
		Default = {'LeftControl'},
		Hold = true,
		Tooltip = 'Keybind to fly downwards'
	})
	Value = Fly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	VerticalValue = Fly:CreateSlider({
		Name = 'Vertical Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	PlatformStanding = Fly:CreateToggle({
		Name = 'PlatformStand',
		Function = function(callback)
			if Fly.Enabled then
				entitylib.character.Humanoid.PlatformStand = callback
			end
		end,
		Tooltip = 'Forces the character to look infront of the camera'
	})
	CustomProperties = Fly:CreateToggle({
		Name = 'Custom Properties',
		Function = function()
			if Fly.Enabled then
				Fly:Toggle()
				Fly:Toggle()
			end
		end,
		Default = true
	})
end)

-- Blatant/Jesus
run(function()
local Jesus
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include

Jesus = vape.Categories.Blatant:CreateModule({
	Name = 'Jesus',
	Function = function(callback)
		if callback then
			local terrain = workspace:FindFirstChildWhichIsA('Terrain')
			params.FilterDescendantsInstances = {terrain}
			local Platform = Instance.new('Part')
			Platform.CanQuery = false
			Platform.CanTouch = false
			Platform.Anchored = true
			Platform.Size = Vector3.new(3, 1, 3)
			Platform.Transparency = 1
			Platform.Parent = gameCamera

			Jesus:Clean(Platform)
			Jesus:Clean(runService.PreSimulation:Connect(function()
				if entitylib.isAlive then
					local root = entitylib.character.RootPart
					local ray = workspace:Raycast(root.Position, Vector3.new(0, -((root.Size.Y / 2) + entitylib.character.HipHeight + math.abs(root.AssemblyLinearVelocity.Y * 0.032)), 0), params)

					if ray and ray.Material == Enum.Material.Water then
						Platform.CFrame = CFrame.new(ray.Position)
					else
						Platform.CFrame = CFrame.new(10000, 10000, 10000)
					end
				end
			end))
		end
	end,
	Tooltip = 'Allow you to stand on terrain water'
})
end)

-- Combat/SilentAim
run(function()
local SilentAim
local Target
local Mode
local Range
local HitChance
local HeadshotChance
local Wallbang
local CircleColor
local CircleTransparency
local CircleFilled
local CircleObject
local rand = Random.new()
local old
local ProjectileRaycast = RaycastParams.new()
ProjectileRaycast.RespectCanCollide = true

local function getMousePosition()
	if inputService.TouchEnabled then
		return gameCamera.ViewportSize / 2
	end

	return inputService:GetMouseLocation()
end

local function getTarget(origin, limit, attackcheck)
	if rand.NextNumber(rand, 0, 100) > HitChance.Value then
		return
	end

	local targetPart = (rand.NextNumber(rand, 0, 100) < HeadshotChance.Value) and 'Head' or 'RootPart'
	local entity = entitylib['Entity'..Mode.Value]({
		Range = Mode.Value == 'Position' and math.min(Range.Value, limit) or Range.Value,
		RangePosition = limit,
		Wallcheck = Target.Walls.Enabled and true or nil,
		Wallbang = Wallbang.Enabled and entitylib.character.RootPart.Position or nil,
		Part = targetPart,
		Origin = origin.Position,
		Players = Target.Players.Enabled,
		NPCs = Target.NPCs.Enabled
	})

	if entity then
		targetinfo.Targets[entity] = tick() + 1
	end

	return entity, entity and entity[targetPart], origin
end

local function Hook(...)
	local item = ...

	if item.Local then
		OriginScanner:UpdateIgnore(item.BulletEmitter.IgnoreList)
		shootTimer = os.clock() + 0.1
		local entity, targetPart, origin = getTarget(item.Tip.CFrame, (item.Config.BulletSpeed or 1000) * item.BulletEmitter.LifeSpan)

		if entity then
			local oldTip
			local aimSpot = targetPart.Position

			if Wallbang.Enabled then
				local ray = workspace:Raycast(targetPart.Position, (origin.Position - targetPart.Position), OriginScanner.Ray)

				if ray then
					local newOrigin, hit = OriginScanner:Scan(entitylib.character.RootPart.Position, targetPart.Position, ray.Position + ray.Normal * 0.01, targetPart, entity)

					if newOrigin then
						oldTip = item.Tip.CFrame
						origin = CFrame.lookAt(newOrigin, targetPart.Position)
						item.Tip.CFrame = origin

						if hit then
							local part = Instance.new('Part')
							part.Anchored = true
							part.CanCollide = false
							part.Position = hit
							part.Size = Vector3.one * 1
							part.Transparency = 1
							part.Parent = entity.Character
							task.spawn(function()
								for i = 1, 2 do
									runService.Heartbeat:Wait()
								end

								part:Destroy()
							end)

							aimSpot = hit
						end
					end
				end
			end

			ProjectileRaycast.FilterDescendantsInstances = {gameCamera, entity.Character, workspace.Vehicles}
			ProjectileRaycast.CollisionGroup = entity.RootPart.CollisionGroup

			local trajectory = oldBulletUpdate and aimSpot or prediction.SolveTrajectory(origin.Position, item.Config.BulletSpeed or 1000, math.abs(item.BulletEmitter.GravityVector.Y), targetPart.Position, entity.RootPart.AssemblyLinearVelocity, workspace.Gravity, entity.HipHeight, nil, ProjectileRaycast)
			if trajectory then
				targetinfo.Targets[entity] = tick() + 1
				item.TipDirection = CFrame.lookAt(origin.Position, trajectory).LookVector
				aimTimer = os.clock() + 0.3
				aimVec = aimSpot
			end

			if oldTip then
				local call = table.pack(old(...))
				item.Tip.CFrame = oldTip
				return unpack(call, 1, call.n)
			end
		end
	end

	return old(...)
end

SilentAim = vape.Categories.Combat:CreateModule({
	Name = 'SilentAim',
	Function = function(callback)
		if CircleObject then
			CircleObject.Visible = callback and Mode.Value == 'Mouse'
		end

		if Wallbang.Enabled then
			debug.setconstant(jb.GunController.ShootCheckConditions, 1, callback and '_Tip' or 'Tip')
		end

		if callback then
			old = hookfunction(jb.GunController.ShootOther, function(...)
				return Hook(...)
			end)

			repeat
				if CircleObject then
					CircleObject.Position = getMousePosition()
				end

				task.wait()
			until not SilentAim.Enabled
		else
			if old then
				restorefunction(jb.GunController.ShootOther)
				old = nil
			end
		end
	end,
	Tooltip = 'Silently adjusts your aim towards the enemy'
})
Target = SilentAim:CreateTargets({
	Players = true
})
Mode = SilentAim:CreateDropdown({
	Name = 'Mode',
	List = {'Mouse', 'Position'},
	Function = function(val)
		if CircleObject then
			CircleObject.Visible = SilentAim.Enabled and val == 'Mouse'
		end
	end,
	Tooltip = 'Mouse - Checks for entities near the mouses position\nPosition - Checks for entities near the local character'
})
Range = SilentAim:CreateSlider({
	Name = 'Range',
	Min = 1,
	Max = 1500,
	Default = 150,
	Function = function(val)
		if CircleObject then
			CircleObject.Radius = val
		end
	end,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
HitChance = SilentAim:CreateSlider({
	Name = 'Hit Chance',
	Min = 0,
	Max = 100,
	Default = 85,
	Suffix = '%'
})
HeadshotChance = SilentAim:CreateSlider({
	Name = 'Headshot Chance',
	Min = 0,
	Max = 100,
	Default = 65,
	Suffix = '%'
})
Wallbang = SilentAim:CreateToggle({
	Name = 'Wallbang',
	Function = function(callback)
		if SilentAim.Enabled then
			debug.setconstant(jb.GunController.ShootCheckConditions, 1, callback and '_Tip' or 'Tip')
		end
	end,
	Tooltip = 'Allow you to shoot people through walls when specific conditions are met.\n(If the entity has a valid hitbox position exposed or if the shoot position can be moved past walls (eg hugging walls))'
})
SilentAim:CreateToggle({
	Name = 'Range Circle',
	Function = function(callback)
		if callback then
			CircleObject = Drawing.new('Circle')
			CircleObject.Filled = CircleFilled.Enabled
			CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
			CircleObject.Position = vape.gui.AbsoluteSize / 2
			CircleObject.Radius = Range.Value
			CircleObject.NumSides = 100
			CircleObject.Transparency = 1 - CircleTransparency.Value
			CircleObject.Visible = SilentAim.Enabled and Mode.Value == 'Mouse'
		else
			pcall(function()
				CircleObject.Visible = false
				CircleObject:Remove()
			end)
		end
		CircleColor.Object.Visible = callback
		CircleTransparency.Object.Visible = callback
		CircleFilled.Object.Visible = callback
	end
})
CircleColor = SilentAim:CreateColorSlider({
	Name = 'Circle Color',
	Function = function(hue, sat, val)
		if CircleObject then
			CircleObject.Color = Color3.fromHSV(hue, sat, val)
		end
	end,
	Darker = true,
	Visible = false
})
CircleTransparency = SilentAim:CreateSlider({
	Name = 'Transparency',
	Min = 0,
	Max = 1,
	Decimal = 10,
	Default = 0.5,
	Function = function(val)
		if CircleObject then
			CircleObject.Transparency = 1 - val
		end
	end,
	Darker = true,
	Visible = false
})
CircleFilled = SilentAim:CreateToggle({
	Name = 'Circle Filled',
	Function = function(callback)
		if CircleObject then
			CircleObject.Filled = callback
		end
	end,
	Darker = true,
	Visible = false
})
end)

-- Combat/Sprint
run(function()
local Sprint

Sprint = vape.Categories.Combat:CreateModule({
	Name = 'Sprint',
	Function = function(callback)
		if callback then
			repeat
				debug.setupvalue(jb.WalkSpeedFun, 9, true)
				task.wait(0.05)
			until not Sprint.Enabled
		end
	end,
	Tooltip = 'Sets your sprinting to true.'
})
end)

-- Render/ESP
run(function()
local ESP
local Targets
local Color
local Method
local BoundingBox
local Filled
local HealthBar
local Name
local DisplayName
local Background
local Teammates
local Distance
local DistanceLimit
local Reference = {}
local methodused

local function ESPWorldToViewport(pos)
	local newpos = gameCamera:WorldToViewportPoint(gameCamera.CFrame:pointToWorldSpace(gameCamera.CFrame:PointToObjectSpace(pos)))
	return Vector2.new(newpos.X, newpos.Y)
end

local ESPAdded = {
	Drawing2D = function(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		local EntityESP = {}
		EntityESP.Main = Drawing.new('Square')
		EntityESP.Main.Transparency = BoundingBox.Enabled and 1 or 0
		EntityESP.Main.ZIndex = 2
		EntityESP.Main.Filled = false
		EntityESP.Main.Thickness = 1
		EntityESP.Main.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)

		if BoundingBox.Enabled then
			EntityESP.Border = Drawing.new('Square')
			EntityESP.Border.Transparency = 0.35
			EntityESP.Border.ZIndex = 1
			EntityESP.Border.Thickness = 1
			EntityESP.Border.Filled = false
			EntityESP.Border.Color = Color3.new()
			EntityESP.Border2 = Drawing.new('Square')
			EntityESP.Border2.Transparency = 0.35
			EntityESP.Border2.ZIndex = 1
			EntityESP.Border2.Thickness = 1
			EntityESP.Border2.Filled = Filled.Enabled
			EntityESP.Border2.Color = Color3.new()
		end

		if HealthBar.Enabled then
			EntityESP.HealthLine = Drawing.new('Line')
			EntityESP.HealthLine.Thickness = 1
			EntityESP.HealthLine.ZIndex = 2
			EntityESP.HealthLine.Color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
			EntityESP.HealthBorder = Drawing.new('Line')
			EntityESP.HealthBorder.Thickness = 3
			EntityESP.HealthBorder.Transparency = 0.35
			EntityESP.HealthBorder.ZIndex = 1
			EntityESP.HealthBorder.Color = Color3.new()
		end
		
		if Name.Enabled then
			if Background.Enabled then
				EntityESP.TextBKG = Drawing.new('Square')
				EntityESP.TextBKG.Transparency = 0.35
				EntityESP.TextBKG.ZIndex = 0
				EntityESP.TextBKG.Thickness = 1
				EntityESP.TextBKG.Filled = true
				EntityESP.TextBKG.Color = Color3.new()
			end
			EntityESP.Drop = Drawing.new('Text')
			EntityESP.Drop.Color = Color3.new()
			EntityESP.Drop.Text = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
			EntityESP.Drop.ZIndex = 1
			EntityESP.Drop.Center = true
			EntityESP.Drop.Size = 20
			EntityESP.Text = Drawing.new('Text')
			EntityESP.Text.Text = EntityESP.Drop.Text
			EntityESP.Text.ZIndex = 2
			EntityESP.Text.Color = EntityESP.Main.Color
			EntityESP.Text.Center = true
			EntityESP.Text.Size = 20
		end
		Reference[ent] = EntityESP
	end,
	Drawing3D = function(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		local EntityESP = {}
		EntityESP.Line1 = Drawing.new('Line')
		EntityESP.Line2 = Drawing.new('Line')
		EntityESP.Line3 = Drawing.new('Line')
		EntityESP.Line4 = Drawing.new('Line')
		EntityESP.Line5 = Drawing.new('Line')
		EntityESP.Line6 = Drawing.new('Line')
		EntityESP.Line7 = Drawing.new('Line')
		EntityESP.Line8 = Drawing.new('Line')
		EntityESP.Line9 = Drawing.new('Line')
		EntityESP.Line10 = Drawing.new('Line')
		EntityESP.Line11 = Drawing.new('Line')
		EntityESP.Line12 = Drawing.new('Line')

		local color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		for _, v in EntityESP do
			v.Thickness = 1
			v.Color = color
		end

		Reference[ent] = EntityESP
	end,
	DrawingSkeleton = function(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		local EntityESP = {}
		EntityESP.Head = Drawing.new('Line')
		EntityESP.HeadFacing = Drawing.new('Line')
		EntityESP.Torso = Drawing.new('Line')
		EntityESP.UpperTorso = Drawing.new('Line')
		EntityESP.LowerTorso = Drawing.new('Line')
		EntityESP.LeftArm = Drawing.new('Line')
		EntityESP.RightArm = Drawing.new('Line')
		EntityESP.LeftLeg = Drawing.new('Line')
		EntityESP.RightLeg = Drawing.new('Line')

		local color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		for _, v in EntityESP do
			v.Thickness = 2
			v.Color = color
		end

		Reference[ent] = EntityESP
	end
}

local ESPRemoved = {
	Drawing2D = function(ent)
		local EntityESP = Reference[ent]
		if EntityESP then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Reference[ent] = nil
			for _, v in EntityESP do
				pcall(function()
					v.Visible = false
					v:Remove()
				end)
			end
		end
	end
}
ESPRemoved.Drawing3D = ESPRemoved.Drawing2D
ESPRemoved.DrawingSkeleton = ESPRemoved.Drawing2D

local ESPUpdated = {
	Drawing2D = function(ent)
		local EntityESP = Reference[ent]
		if EntityESP then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			
			if EntityESP.HealthLine then
				EntityESP.HealthLine.Color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
			end

			if EntityESP.Text then
				EntityESP.Text.Text = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
				EntityESP.Drop.Text = EntityESP.Text.Text
			end
		end
	end
}

local ColorFunc = {
	Drawing2D = function(hue, sat, val)
		local color = Color3.fromHSV(hue, sat, val)
		for i, v in Reference do
			v.Main.Color = entitylib.getEntityColor(i) or color
			if v.Text then
				v.Text.Color = v.Main.Color
			end
		end
	end,
	Drawing3D = function(hue, sat, val)
		local color = Color3.fromHSV(hue, sat, val)
		for i, v in Reference do
			local playercolor = entitylib.getEntityColor(i) or color
			for _, v2 in v do
				v2.Color = playercolor
			end
		end
	end
}
ColorFunc.DrawingSkeleton = ColorFunc.Drawing3D

local ESPLoop = {
	Drawing2D = function()
		for ent, EntityESP in Reference do
			if Distance.Enabled then
				local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					for _, obj in EntityESP do
						obj.Visible = false
					end
					continue
				end
			end

			local rootPos, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
			for _, obj in EntityESP do
				obj.Visible = rootVis
			end
			if not rootVis then continue end

			local topPos = gameCamera:WorldToViewportPoint((CFrame.lookAlong(ent.RootPart.Position, gameCamera.CFrame.LookVector) * CFrame.new(2, ent.HipHeight, 0)).p)
			local bottomPos = gameCamera:WorldToViewportPoint((CFrame.lookAlong(ent.RootPart.Position, gameCamera.CFrame.LookVector) * CFrame.new(-2, -ent.HipHeight - 1, 0)).p)
			local sizex, sizey = topPos.X - bottomPos.X, topPos.Y - bottomPos.Y
			local posx, posy = (rootPos.X - sizex / 2),  ((rootPos.Y - sizey / 2))
			EntityESP.Main.Position = Vector2.new(posx, posy) // 1
			EntityESP.Main.Size = Vector2.new(sizex, sizey) // 1
			if EntityESP.Border then
				EntityESP.Border.Position = Vector2.new(posx - 1, posy + 1) // 1
				EntityESP.Border.Size = Vector2.new(sizex + 2, sizey - 2) // 1
				EntityESP.Border2.Position = Vector2.new(posx + 1, posy - 1) // 1
				EntityESP.Border2.Size = Vector2.new(sizex - 2, sizey + 2) // 1
			end

			if EntityESP.HealthLine then
				local healthposy = sizey * math.clamp(ent.Health / ent.MaxHealth, 0, 1)
				EntityESP.HealthLine.Visible = ent.Health > 0
				EntityESP.HealthLine.From = Vector2.new(posx - 6, posy + (sizey - (sizey - healthposy))) // 1
				EntityESP.HealthLine.To = Vector2.new(posx - 6, posy) // 1
				EntityESP.HealthBorder.From = Vector2.new(posx - 6, posy + 1) // 1
				EntityESP.HealthBorder.To = Vector2.new(posx - 6, (posy + sizey) - 1) // 1
			end

			if EntityESP.Text then
				EntityESP.Text.Position = Vector2.new(posx + (sizex / 2), posy + (sizey - 28)) // 1
				EntityESP.Drop.Position = EntityESP.Text.Position + Vector2.new(1, 1)
				if EntityESP.TextBKG then
					EntityESP.TextBKG.Size = EntityESP.Text.TextBounds + Vector2.new(8, 4)
					EntityESP.TextBKG.Position = EntityESP.Text.Position - Vector2.new(4 + (EntityESP.Text.TextBounds.X / 2), 0)
				end
			end
		end
	end,
	Drawing3D = function()
		for ent, EntityESP in Reference do
			if Distance.Enabled then
				local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					for _, obj in EntityESP do
						obj.Visible = false
					end
					continue
				end
			end

			local _, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
			for _, obj in EntityESP do
				obj.Visible = rootVis
			end
			if not rootVis then continue end

			local point1 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, ent.HipHeight, 1.5))
			local point2 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, -ent.HipHeight, 1.5))
			local point3 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, ent.HipHeight, 1.5))
			local point4 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, -ent.HipHeight, 1.5))
			local point5 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, ent.HipHeight, -1.5))
			local point6 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, -ent.HipHeight, -1.5))
			local point7 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, ent.HipHeight, -1.5))
			local point8 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, -ent.HipHeight, -1.5))
			EntityESP.Line1.From = point1
			EntityESP.Line1.To = point2
			EntityESP.Line2.From = point3
			EntityESP.Line2.To = point4
			EntityESP.Line3.From = point5
			EntityESP.Line3.To = point6
			EntityESP.Line4.From = point7
			EntityESP.Line4.To = point8
			EntityESP.Line5.From = point1
			EntityESP.Line5.To = point3
			EntityESP.Line6.From = point1
			EntityESP.Line6.To = point5
			EntityESP.Line7.From = point5
			EntityESP.Line7.To = point7
			EntityESP.Line8.From = point7
			EntityESP.Line8.To = point3
			EntityESP.Line9.From = point2
			EntityESP.Line9.To = point4
			EntityESP.Line10.From = point2
			EntityESP.Line10.To = point6
			EntityESP.Line11.From = point6
			EntityESP.Line11.To = point8
			EntityESP.Line12.From = point8
			EntityESP.Line12.To = point4
		end
	end,
	DrawingSkeleton = function()
		for ent, EntityESP in Reference do
			if Distance.Enabled then
				local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					for _, obj in EntityESP do
						obj.Visible = false
					end
					continue
				end
			end

			local _, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
			for _, obj in EntityESP do
				obj.Visible = rootVis
			end
			if not rootVis then continue end
			
			local rigcheck = ent.Humanoid.RigType == Enum.HumanoidRigType.R6
			pcall(function()
				local offset = rigcheck and CFrame.new(0, -0.8, 0) or CFrame.identity
				local head = ESPWorldToViewport((ent.Head.CFrame).p)
				local headfront = ESPWorldToViewport((ent.Head.CFrame * CFrame.new(0, 0, -0.5)).p)
				local toplefttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(-1.5, 0.8, 0)).p)
				local toprighttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(1.5, 0.8, 0)).p)
				local toptorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0, 0.8, 0)).p)
				local bottomtorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0, -0.8, 0)).p)
				local bottomlefttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(-0.5, -0.8, 0)).p)
				local bottomrighttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0.5, -0.8, 0)).p)
				local leftarm = ESPWorldToViewport((ent.Character[(rigcheck and 'Left Arm' or 'LeftHand')].CFrame * offset).p)
				local rightarm = ESPWorldToViewport((ent.Character[(rigcheck and 'Right Arm' or 'RightHand')].CFrame * offset).p)
				local leftleg = ESPWorldToViewport((ent.Character[(rigcheck and 'Left Leg' or 'LeftFoot')].CFrame * offset).p)
				local rightleg = ESPWorldToViewport((ent.Character[(rigcheck and 'Right Leg' or 'RightFoot')].CFrame * offset).p)
				EntityESP.Head.From = toptorso
				EntityESP.Head.To = head
				EntityESP.HeadFacing.From = head
				EntityESP.HeadFacing.To = headfront
				EntityESP.UpperTorso.From = toplefttorso
				EntityESP.UpperTorso.To = toprighttorso
				EntityESP.Torso.From = toptorso
				EntityESP.Torso.To = bottomtorso
				EntityESP.LowerTorso.From = bottomlefttorso
				EntityESP.LowerTorso.To = bottomrighttorso
				EntityESP.LeftArm.From = toplefttorso
				EntityESP.LeftArm.To = leftarm
				EntityESP.RightArm.From = toprighttorso
				EntityESP.RightArm.To = rightarm
				EntityESP.LeftLeg.From = bottomlefttorso
				EntityESP.LeftLeg.To = leftleg
				EntityESP.RightLeg.From = bottomrighttorso
				EntityESP.RightLeg.To = rightleg
			end)
		end
	end
}

ESP = vape.Categories.Render:CreateModule({
	Name = 'ESP',
	Function = function(callback)
		if callback then
			methodused = 'Drawing'..Method.Value
			if ESPRemoved[methodused] then
				ESP:Clean(entitylib.Events.EntityRemoved:Connect(ESPRemoved[methodused]))
			end
			if ESPAdded[methodused] then
				for _, v in entitylib.List do
					if Reference[v] then
						ESPRemoved[methodused](v)
					end
					ESPAdded[methodused](v)
				end
				ESP:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then
						ESPRemoved[methodused](ent)
					end
					ESPAdded[methodused](ent)
				end))
			end
			if ESPUpdated[methodused] then
				ESP:Clean(entitylib.Events.EntityUpdated:Connect(ESPUpdated[methodused]))
				for _, v in entitylib.List do
					ESPUpdated[methodused](v)
				end
			end
			if ColorFunc[methodused] then
				ESP:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
				end))
			end
			if ESPLoop[methodused] then
				ESP:Clean(runService.RenderStepped:Connect(ESPLoop[methodused]))
			end
		else
			if ESPRemoved[methodused] then
				for i in Reference do
					ESPRemoved[methodused](i)
				end
			end
		end
	end,
	Tooltip = 'Extra Sensory Perception\nRenders an ESP on players.'
})
Targets = ESP:CreateTargets({
	Players = true,
	Function = function()
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
	end
})
Method = ESP:CreateDropdown({
	Name = 'Mode',
	List = {'2D', '3D', 'Skeleton'},
	Function = function(val)
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
		BoundingBox.Object.Visible = (val == '2D')
		Filled.Object.Visible = (val == '2D')
		HealthBar.Object.Visible = (val == '2D')
		Name.Object.Visible = (val == '2D')
		DisplayName.Object.Visible = Name.Object.Visible and Name.Enabled
		Background.Object.Visible = Name.Object.Visible and Name.Enabled
	end,
})
Color = ESP:CreateColorSlider({
	Name = 'Player Color',
	Function = function(hue, sat, val)
		if ESP.Enabled and ColorFunc[methodused] then
			ColorFunc[methodused](hue, sat, val)
		end
	end
})
BoundingBox = ESP:CreateToggle({
	Name = 'Bounding Box',
	Function = function()
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
	end,
	Default = true,
	Darker = true
})
Filled = ESP:CreateToggle({
	Name = 'Filled',
	Function = function()
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
	end,
	Darker = true
})
HealthBar = ESP:CreateToggle({
	Name = 'Health Bar',
	Function = function()
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
	end,
	Darker = true
})
Name = ESP:CreateToggle({
	Name = 'Name',
	Function = function(callback)
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
		DisplayName.Object.Visible = callback
		Background.Object.Visible = callback
	end,
	Darker = true
})
DisplayName = ESP:CreateToggle({
	Name = 'Use Displayname',
	Function = function()
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
	end,
	Default = true,
	Darker = true
})
Background = ESP:CreateToggle({
	Name = 'Show Background',
	Function = function()
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
	end,
	Darker = true
})
Teammates = ESP:CreateToggle({
	Name = 'Priority Only',
	Function = function()
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
	end,
	Default = true,
	Tooltip = 'Hides teammates & non targetable entities'
})
Distance = ESP:CreateToggle({
	Name = 'Distance Check',
	Function = function(callback)
		DistanceLimit.Object.Visible = callback
	end
})
DistanceLimit = ESP:CreateTwoSlider({
	Name = 'Player Distance',
	Min = 0,
	Max = 256,
	DefaultMin = 0,
	DefaultMax = 64,
	Darker = true,
	Visible = false
})
end)