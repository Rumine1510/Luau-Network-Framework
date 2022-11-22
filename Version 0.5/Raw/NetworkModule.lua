--!strict

--// Services \\--

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

--// Requiring Modules \\--

local Trove = require(script.Trove)
local Signal = require(script.Signal)

--// Types \\--

type func = (...any) -> (...any)

type customSignal = Signal.customSignal
type signalParams = Signal.signalParams
type signalProperty = Signal.signalProperty
type signalInfo = Signal.signalInfo

type trove = Trove.trove

--// Variables \\--

local networkEvent = Instance.new("BindableEvent")
local IsServer = RunService:IsServer()

--// Tables

local weakMeta = {
	__mode = "k"
}

local lockMeta = {
	__newindex = function() end,
	__metatable = "Locked"
}

local NetworkList = {} :: {[string]: network}
local PlayerList = {} :: {[Player]: {network}}

--// Main Module \\--

--// Network

local Network = {}
local NetworkPrototype = {}

local NetworkMeta = {

	__index = NetworkPrototype,
	__newindex = function() end,
	__metatable = "Locked"

}


--// Private Functions \\--


local function waitForChildOfClass(instance: Instance, className: string, timeOut: number?): Instance

	local target = instance:FindFirstChildOfClass(className)
	if target then return target end

	if timeOut then

		local bindable = Instance.new("BindableEvent")

		local connection = instance.ChildAdded:Connect(function(child)
			if child.ClassName == className then
				bindable:Fire(child)
			end
		end)

		task.delay(timeOut, bindable.Fire, bindable)
		return bindable.Event:Wait(), connection:Disconnect()

	else

		repeat
			target = instance.ChildAdded:Wait()
		until target.ClassName == className

		return target
	end

end


local function generateSignalID(id: number): string

	assert(type(id) == "number", "First argument provided must be a number.")
	assert(id > -1, "Number provided can't be lower than 0.")
	assert(id % 1 == 0, "Number provided must be an integer.")
	assert(id < 16777217, "Integer provided can't be larger than 2^24")

	id -= 1

	if id == -1 then
		return ''
	elseif id < 256 then

		return string.char(id)

	elseif id < 65536 then

		local n = math.floor(id/256)
		local m = id%256

		return string.char(n) .. string.char(m)

	else

		local a,b,c = math.floor(id/65536), math.floor(id/256)%256, id%256

		return string.char(a) .. string.char(b) .. string.char(c)

	end

end


local function decodeKey(key: string): number

	assert(type(key) == "string", "The key provided must be a string.")

	if #key == 0 then return 0 end

	local n = 1

	for i = 1, #key do

		n += key:sub(i,i):byte() * 256 ^ (#key-i)

	end

	return n

end


local function lock(t)
	return setmetatable(t, lockMeta)
end


--// Constructor \\--

--// Network


function Network.Register(name: string, property: networkProperty?, folder: Instance?)

	assert(type(name) == "string", "Network.Register(name) required a string as first argument.")
	assert(not NetworkList[name], "Network |" .. name .. "| already exist.")

	property = property or Network.newNetworkProperty()

	assert(property, "Unable to set property to default.")

	local newNetwork = {}
	newNetwork.Name = name
	newNetwork.Events = {} :: {[string]: customSignal}
	newNetwork.Property = property :: networkProperty
	newNetwork.LocalEvents = {} :: {[string]: customSignal}
	newNetwork.RemoteQueue = {} :: {{Key: string, Params: signalParams, Args: {any}}}

	newNetwork.SignalArray = {} :: {signalInfo}
	newNetwork.LocalSignalArray = {} :: {signalInfo}
	newNetwork.SignalCount = 0 :: number
	newNetwork.SignalIDCount = 0 :: number

	newNetwork.__Init = Instance.new("BindableEvent") :: boolean | BindableEvent
	newNetwork._internalEvent = Instance.new("BindableEvent")
	newNetwork._trove = Trove.new() :: trove
	newNetwork._trove.Parent = newNetwork

	newNetwork.ConnectedClient = false :: false | {Player}
	newNetwork.Active = true

	do

		if folder then

			local remoteEvent = folder:FindFirstChildOfClass("RemoteEvent")
			local remoteFunction = folder:FindFirstChildOfClass("RemoteFunction")

			assert(remoteEvent and remoteFunction, "Folder provided are required to have RemoteEvent and RemoteFunction")

			newNetwork.__MainFolder = folder
			newNetwork.__MainRemote = remoteEvent
			newNetwork.__MainInvoke = remoteFunction

			if property.AllowSignalRemote then
				newNetwork.__SignalFolder = Instance.new("Folder", newNetwork.__MainFolder)
			end

		elseif IsServer then

			newNetwork.__MainFolder = newNetwork._trove:Add(Instance.new("Folder"))
			newNetwork.__MainRemote = Instance.new("RemoteEvent", newNetwork.__MainFolder)
			newNetwork.__MainInvoke = Instance.new("RemoteFunction", newNetwork.__MainFolder)

			newNetwork.__MainFolder.Name = name
			newNetwork.__MainFolder.Parent = script

		end

	end

	newNetwork._trove:Set(NetworkList,name, newNetwork)

	setmetatable(newNetwork, NetworkMeta)

	networkEvent:Fire()

	return newNetwork

end


function Network.newNetworkProperty(): networkProperty

	local params = {}
	params.AllowCrossCommunication = true :: boolean
	params.AllowSignalRemote = false :: boolean
	params.DefaultCreateSignalRemote = false :: boolean
	params.QueueInterval = 1 :: number

	return params

end


Network.newSignalParams = Signal.newParams
Network.newSignalProperty = Signal.newProperty


type network = typeof(Network.Register("Type"))
type networkProperty = typeof(Network.newNetworkProperty())


--// Functions \\--


function Network.GetNetwork(identifier: string): network

	assert(type(identifier) == "string", "String expected as first argument")

	local network = NetworkList[identifier]

	assert(network, "Network doesn't exist.")

	return network

end


function Network.FindNetwork(identifier: string): network?

	assert(type(identifier) == "string", "String expected as first argument")

	if NetworkList[identifier] then
		return NetworkList[identifier]
	end

	local networkFolder = script:FindFirstChild(identifier)

	if networkFolder then

		if IsServer then return warn("Network folder exist but unable to find network table. Identifier key: " .. identifier) end

		waitForChildOfClass(networkFolder, "RemoteEvent")
		waitForChildOfClass(networkFolder, "RemoteFunction")

		local newNetwork = Network.Register(identifier, nil, networkFolder)

		return newNetwork

	end

	return nil

end


function Network.WaitForNetwork(identifier: string): network

	assert(type(identifier) == "string", "String expected as first argument")

	if NetworkList[identifier] then
		return NetworkList[identifier]
	end

	if IsServer then

		repeat
			networkEvent.Event:Wait()
		until NetworkList[identifier]

		return NetworkList[identifier]

	else

		local networkFolder = script:FindFirstChild(identifier)

		if networkFolder then

			waitForChildOfClass(networkFolder, "RemoteEvent")
			waitForChildOfClass(networkFolder, "RemoteFunction")

			return Network.Register(identifier, nil, networkFolder)

		end

		local thread = coroutine.running()

		local c1, c2

		c1 = script.ChildAdded:Connect(function(folder)
			if folder.Name == identifier then

				c1:Disconnect()
				c2:Disconnect()

				waitForChildOfClass(folder, "RemoteEvent")
				waitForChildOfClass(folder, "RemoteFunction")

				task.spawn(thread, Network.Register(identifier, nil, folder))

			end
		end)

		c2 = networkEvent.Event:Connect(function()
			if NetworkList[identifier] then

				c1:Disconnect()
				c2:Disconnect()

				task.spawn(thread, NetworkList[identifier])

			end
		end)

		return coroutine.yield()

	end

end


--// Private Methods \\--


--// Network


function NetworkPrototype.__AddQueue(self: network, key: string, params: signalParams, args: {any})

	if #self.RemoteQueue == 0 then
		
		for i = 2, self.Property.QueueInterval do
			task.wait()
		end
		
		if self.Property.QueueInterval == 1 then
			task.defer(self.__ReleaseQueue, self)
		else
			task.spawn(self.__ReleaseQueue, self)
		end
		
	end

	local remote = {
		Key = key,
		Params = params,
		Args = args,
	}

	table.insert(self.RemoteQueue, remote)

end


function NetworkPrototype.__ReleaseQueue(self: network)
	
	local remotes = {} :: {[string]: RemoteEvent?}
	local data = {} :: {[Player | string]: any}

	local cost = 0

	for _, remote in self.RemoteQueue do

		local property = remote.Params

		if IsServer then

			if not property.Target or property.Target == "All" then
				property.Target = Players:GetPlayers()
			end

			if type(property.Target) == "table" then

				for _,player in property.Target do

					if not data[player] then data[player] = {} end
					if not data[player][remote.Key] then data[player][remote.Key] = {} end
					
					remotes[remote.Key] = property.Remote
					
					table.insert(data[player][remote.Key], remote.Args)
					cost += #remote.Key

				end

			elseif typeof(property.Target) == "Instance" and property.Target:IsA("Player") then

				if not data[property.Target] then data[property.Target] = {} end
				if not data[property.Target][remote.Key] then data[property.Target][remote.Key] = {} end
				
				remotes[remote.Key] = property.Remote

				table.insert(data[property.Target][remote.Key], remote.Args)
				cost += #remote.Key

			else

				warn("Unable to find target for signal " .. decodeKey(remote.Key))

			end

		else

			if not data[remote.Key] then data[remote.Key] = {} end

			table.insert(data[remote.Key], remote.Args)
			cost += #remote.Key

		end

	end
	
	if self.Property.AllowSignalRemote and cost + 9 > #self.RemoteQueue * 9 then
		
		if IsServer then

			for player, info in data do

				if typeof(player) == "Instance" and player:IsA("Player") then
									
					for key, args in info do
						
						local remote = remotes[key]
						
						if remote then
							
							remote:FireClient(player, args)
							info[key] = nil
							
						else
							
							warn("No remote for key: " .. key)
							
						end
						
					end

				else

					warn("Target is not a player.")

				end

			end

		else
			
			for key, args in data do
				
				if type(key) == "string" then
					
					local remote = remotes[key]

					if remote then

						remote:FireServer(args)
						data[key] = nil

					else

						warn("No remote for key: " .. key)

					end
					
				else
					
					warn("Invalid key: " .. tostring(key))
					
				end

			end

		end
		
	end
	
	if self.__MainFolder then

		if IsServer then

			for player, info in data do

				if typeof(player) == "Instance" and player:IsA("Player") then

					self.__MainRemote:FireClient(player, info)

				else

					warn("Target is not a player.")

				end

			end

		elseif next(data) then

			self.__MainRemote:FireServer(data)

		end

	end
	
	table.clear(self.RemoteQueue)

end


function NetworkPrototype.__SetConnection(self: network)

	if IsServer then

		self.ConnectedClient = {}

		self.__MainRemote.OnServerEvent:Connect(function(player, data)

			for key, info in data do

				local id = decodeKey(key)

				local signalInfo = self.SignalArray[id] :: signalInfo?

				if signalInfo then

					local event = self.Events[signalInfo.EventName]
					if not event then warn("Event " .. signalInfo.EventName .. " doesn't exist.") continue end

					for _, args in info do

						event:__Fired(unpack(args))

					end

				else

					warn("No signal for id: " .. id)

				end

			end

		end)
		
		self._trove:Set(self.__MainInvoke, "OnServerInvoke", function(player, key, ...)

			if not key then

				if type(self.ConnectedClient) == "table" then
					table.insert(PlayerList[player], self)
					table.insert(self.ConnectedClient, player)
				end

				local returnTable = {}
				
				for _, v in self.SignalArray do
					
					if v.Signal.__Replicate then
						
						local info = {v.EventName :: string, v.Property :: any, v.ID :: any}
						
						table.insert(returnTable, info)
						
					end
				end

				return returnTable :: any

			else

				local id = decodeKey(key)

				local signalInfo = self.SignalArray[id] :: signalInfo?

				if signalInfo then

					local event = self.Events[signalInfo.EventName]
					if not event then error("Event " .. tostring(signalInfo.EventName) .. " doesn't exist.") end

					if event.OnInvoke then
						return event.OnInvoke(...)
					end

				else

					warn("No signal for id: " .. id)

				end
				
				return nil

			end
			
		end)

	else

		if self.__MainFolder then

			local signalArray = self.__MainInvoke:InvokeServer()

			if signalArray then

				for _, info in signalArray do

					self:CreateSignal(info[1], info[2], info[3])

				end

			else
				warn("Unable to find signal array")
			end


			self._trove:Connect(self.__MainRemote.OnClientEvent, function(data: {[string]: {{signalInfo}}})

				if data[''] then

					for _, v in data[''] do
						for _, signalInfo in v do

							if type(signalInfo) == "table" then

								self:CreateSignal(signalInfo.EventName, signalInfo.Property, signalInfo.ID)

							else

								local signal = self:GetSignalFromID(signalInfo)
								if signal then signal:Destroy() end

							end

						end
					end

					data[''] = nil

				end

				for key, info in data do

					local id = decodeKey(key)

					local signalInfo = self.SignalArray[id]
					if not signalInfo then warn("No signal for id: " .. id) continue end

					local event = self.Events[signalInfo.EventName]
					if not event then warn("Event " .. tostring(signalInfo.EventName) .. " doesn't exist.") continue end

					for _, args in info do

						event:__Fired(unpack(args))
						table.clear(event.ThreadList)

					end

				end

				return

			end)


			self._trove:Set(self.__MainInvoke, "OnClientInvoke", function(key, ...)

				local id = decodeKey(key)

				local signalInfo = self.SignalArray[id]
				if not signalInfo then warn("No signal for id: " .. tostring(id)) return end

				local event = self.Events[signalInfo.EventName]
				if not event then warn("Event " .. tostring(signalInfo.EventName) .. " doesn't exist.") return end

				if event.OnInvoke then
					return event.OnInvoke(...)
				else
					warn("OnInvoke function doesn't exist for event \"" .. signalInfo.EventName .."\". Did you forget to implement OnInvoke?")
					return
				end

			end)


		else

			print("Network doesn't have a main folder. Only local communication will be avaliable.")

		end

	end

end


--// Methods \\--


NetworkPrototype.newSignalParams = Signal.newParams
NetworkPrototype.newSignalProperty = Signal.newProperty


--// Signal


function NetworkPrototype.CreateSignal(self: network, eventName: string, property: signalProperty?, eventID: number?): customSignal

	assert(self.Active, "This network is no longer active.")
	assert(IsServer, "Clients are only allowed to create LocalSignal.")
	assert(type(eventName) == "string", "First argument provided must be string.")
	assert(self.SignalIDCount < 65537, "Signal limit is 65537 signals.")

	if self.Events[eventName] then
		warn("Event " .. eventName .. " already exist, returning the existing signal...")
		return self.Events[eventName]
	end

	self.SignalIDCount += 1

	local newSignal = Signal.new(eventID or self.SignalIDCount, eventName, property)
	
	newSignal.Network = self
	
	newSignal._trove:Insert(self.SignalArray, newSignal.SignalInfo)
	newSignal._trove:Set(self.Events, eventName, newSignal)

	if self.Property.AllowSignalRemote and self.Property.DefaultCreateSignalRemote then

		newSignal.__MainRemote = Instance.new("RemoteEvent", self.__SignalFolder)
		newSignal.__MainInvoke = Instance.new("RemoteFunction", self.__SignalFolder)

	end

	self._internalEvent:Fire()

	local target = self.ConnectedClient

	if type(target) == "table" and #target > 0 then
		self:__AddQueue('', {Target = target}, {newSignal.SignalInfo})
	end

	return newSignal

end


function NetworkPrototype.GetSignal(self: network, eventName: string): customSignal?
	
	assert(self.Active, "This network is no longer active.")
	assert(type(eventName) == "string", "First argument provided must be string.")

	return self.Events[eventName]
end


function NetworkPrototype.GetSignalFromID(self: network, signalID: number): customSignal?

	assert(self.Active, "This network is no longer active.")
	assert(type(signalID) == "number", "The ID provided must be a number.")

	local signalInfo = self.SignalArray[signalID]

	if signalInfo then
		return self.Events[signalInfo.EventName]
	end

	return warn("Unable to find signal from id " .. signalID)

end


function NetworkPrototype.WaitForSignal(self: network, eventName: string): customSignal

	assert(self.Active, "This network is no longer active.")
	assert(type(eventName) == "string", "First argument provided must be string.")

	local tbl = self.Events
	if tbl[eventName] then return tbl[eventName] end

	repeat
		self._internalEvent.Event:Wait()
	until tbl[eventName]

	return tbl[eventName]

end


function NetworkPrototype.WaitForSignalWithID(self: network, signalID: number): customSignal

	assert(self.Active, "This network is no longer active.")
	assert(signalID, "The ID provided must be a number.")
	
	local array = self.SignalArray
	local signalInfo = array[signalID]

	if signalInfo then return self.Events[signalInfo.EventName] end

	repeat
		self._internalEvent.Event:Wait()
	until array[signalID]

	return self.Events[array[signalID].EventName]

end


function NetworkPrototype.ConnectSignal(self: network, eventName: string, func: func)

	assert(self.Active, "This network is no longer active.")
	assert(type(eventName) == "string", "First argument provided must be string.")
	assert(self.Events[eventName], "Event " .. eventName .. " doesn't exist.")

	return self.Events[eventName]:Connect(func)

end


function NetworkPrototype.DisconnectSignal(self: network, eventName: string)

	assert(self.Active, "This network is no longer active.")
	assert(type(eventName) == "string", "First argument provided must be string.")
	assert(self.Events[eventName], "Event " .. eventName .. " doesn't exist.")

	self.Events[eventName]:Disconnect()

end


function NetworkPrototype.DeleteSignal(self: network, eventName: string)

	assert(self.Active, "This network is no longer active.")
	assert(type(eventName) == "string", "First argument provided must be string.")
	assert(self.Events[eventName], "Event " .. eventName .. " doesn't exist.")

	self.Events[eventName]:Destroy()

end


function NetworkPrototype.FireSignal(self: network, eventName: string, params: signalParams?, ...: any)

	assert(self.Active, "This network is no longer active.")
	assert(type(eventName) == "string", "First argument provided must be string.")
	assert(self.Events[eventName], "Event " .. eventName .. " doesn't exist.")

	return self.Events[eventName]:Fire(params, ...)

end


function NetworkPrototype.InvokeSignal(self: network, eventName: string, params: signalParams?, ...: any)

	assert(self.Active, "This network is no longer active.")
	assert(type(eventName) == "string", "First argument provided must be string.")
	assert(self.Events[eventName], "Event " .. eventName .. " doesn't exist.")

	return self.Events[eventName]:Invoke(params, ...)

end


--// Local Signal


function NetworkPrototype.CreateLocalSignal(self: network, eventName: string, property: signalProperty?): customSignal

	assert(self.Active, "This network is no longer active.")
	assert(typeof(eventName) == "string", "First argument provided must be string.")

	if self.LocalEvents[eventName] then
		warn("LocalEvent " .. eventName .. " already exist, returning the existing signal...")
		return self.LocalEvents[eventName]
	end

	local newSignal = Signal.new(0, eventName, property)
	newSignal.Network = self
	newSignal.__Replicate = false

	newSignal._trove:Insert(self.LocalSignalArray, newSignal.SignalInfo)
	newSignal._trove:Set(self.LocalEvents, eventName, newSignal)

	self._internalEvent:Fire()

	return newSignal

end


function NetworkPrototype.GetLocalSignal(self: network, eventName: string): customSignal?
	
	assert(self.Active, "This network is no longer active.")
	assert(typeof(eventName) == "string", "First argument provided must be string.")

	return self.LocalEvents[eventName]
	
end


function NetworkPrototype.GetLocalSignalFromID(self: network, signalID: number): customSignal?

	assert(self.Active, "This network is no longer active.")
	assert(type(signalID) == "number", "The ID provided must be a number.")

	local signalInfo = self.LocalSignalArray[signalID]

	if signalInfo then
		return self.LocalEvents[signalInfo.EventName]
	end

	return warn("Unable to find local signal from id " .. signalID)

end


function NetworkPrototype.WaitForLocalSignal(self: network, eventName: string): customSignal

	assert(self.Active, "This network is no longer active.")
	assert(typeof(eventName) == "string", "First argument provided must be string.")

	local tbl = self.LocalEvents
	if tbl[eventName] then return tbl[eventName] end

	repeat
		self._internalEvent.Event:Wait()
	until tbl[eventName]

	return tbl[eventName]

end


function NetworkPrototype.WaitForLocalSignalWithID(self: network, signalID: number): customSignal

	assert(self.Active, "This network is no longer active.")
	assert(type(signalID) == "number", "The ID provided must be a number.")
	
	local array = self.LocalSignalArray
	local signalInfo = array[signalID]

	if signalInfo then return self.LocalEvents[signalInfo.EventName] end

	repeat
		self._internalEvent.Event:Wait()
	until array[signalID]

	return self.Events[array[signalID].EventName]

end


function NetworkPrototype.ConnectLocalSignal(self: network, eventName: string, func: func)

	assert(self.Active, "This network is no longer active.")
	assert(typeof(eventName) == "string", "First argument provided must be string.")
	assert(self.LocalEvents[eventName], "LocalEvent " .. eventName .. " doesn't exist.")

	return self.LocalEvents[eventName]:Connect(func)

end


function NetworkPrototype.DisconnectLocalSignal(self: network, eventName: string)

	assert(self.Active, "This network is no longer active.")
	assert(typeof(eventName) == "string", "First argument provided must be string.")
	assert(self.LocalEvents[eventName], "LocalEvent " .. eventName .. " doesn't exist.")

	self.Events[eventName]:Disconnect()

end


function NetworkPrototype.DeleteLocalSignal(self: network, eventName: string)

	assert(self.Active, "This network is no longer active.")
	assert(typeof(eventName) == "string", "First argument provided must be string.")
	assert(self.LocalEvents[eventName], "LocalEvent " .. eventName .. " doesn't exist.")

	self.Events[eventName]:Destroy()

end


function NetworkPrototype.FireLocalSignal(self: network, eventName: string, params: signalParams?, ...: any)

	assert(self.Active, "This network is no longer active.")
	assert(typeof(eventName) == "string", "First argument provided must be string.")
	assert(self.LocalEvents[eventName], "LocalEvent " .. eventName .. " doesn't exist.")

	return self.Events[eventName]:Fire(params, ...)

end


function NetworkPrototype.InvokeLocalSignal(self: network, eventName: string, params: signalParams?, ...: any)

	assert(self.Active, "This network is no longer active.")
	assert(typeof(eventName) == "string", "First argument provided must be string.")
	assert(self.LocalEvents[eventName], "LocalEvent " .. eventName .. " doesn't exist.")

	return self.Events[eventName]:Invoke(params, ...)

end


--// Network


function NetworkPrototype.DisconnectClient(self: network, player: Player, left: boolean)
	
	assert(IsServer, "You can only disconnect client from server.")
	assert(typeof(player) == "Instance" and player:IsA("Player"), "First argument provided must be a player.")
	
	local connectedClient = self.ConnectedClient
	
	if type(connectedClient) == "table" then
		
		local index = table.find(connectedClient, player)
		if index then
			
			local len = #connectedClient
			connectedClient[index], connectedClient[len] = connectedClient[len], nil
			
			if not left then
				
			end
			
		else
			warn("Client is not connected.")
		end
		
	end

end


function NetworkPrototype.Disconnect(self: network)
	
	assert(not IsServer, "This method can only be called from client.")
	print("idk")
	
end


function NetworkPrototype.Destroy(self: network)

	assert(self.Active, "This network is no longer active.")

	NetworkList[self.Name] = nil
	self._trove:CleanUp()

end


function NetworkPrototype.Init(self: network): network

	assert(self.Active, "This network is no longer active.")

	if self.__Init == true then return self, warn("Network already initialised.") end

	if self.Property.AllowCrossCommunication then
		self:__SetConnection()
	end

	assert(typeof(self.__Init) == "Instance" and self.__Init:IsA("BindableEvent"), "Invalid initializing variable")

	self.__Init:Fire()
	self.__Init = true

	return self

end


--// Connections \\--


if IsServer then

	Players.PlayerAdded:Connect(function(player)
		PlayerList[player] = {}
	end)

	Players.PlayerRemoving:Connect(function(player)

		for _, network in PlayerList[player] do
			network:DisconnectClient(player, true)
		end

	end)

	for _, player in Players:GetPlayers() do
		PlayerList[player] = {}
	end

end


--// Return \\--

return Network