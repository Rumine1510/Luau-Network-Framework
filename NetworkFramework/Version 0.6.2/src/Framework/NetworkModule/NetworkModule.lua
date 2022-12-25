--!strict

--// Services \\--

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

--// Requiring Modules \\--

local Trove = require(script.Trove)
local Signal = require(script.Signal)
local EventTable = require(script.Table)

--// Types \\--

type func = (...any) -> (...any)
type tbl = {[any]: any}
type array = {any}
type interval = "Second" | "Millisecond" | "Heartbeat"

type customSignal = Signal.customSignal
type signalParams = Signal.signalParams
type signalProperty = Signal.signalProperty
type signalInfo = Signal.signalInfo

type customConnection = Signal.customConnection

type trove = Trove.trove

type eventTable = EventTable.eventTable

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


local function encodeKey(id: number): string

	assert(type(id) == "number", "First argument provided must be a number.")
	assert(id > -1, "Number provided can't be lower than 0.")
	assert(id % 1 == 0, "Number provided must be an integer.")
	assert(id < 65537, "Integer provided can't be larger than 2^16")

	id -= 1

	if id == -1 then

		return ''

	elseif id < 256 then

		--[[
		
		string.pack("h", id) is the same as string.char(id)
		
		]]

		return string.char(id)

	else

		--[[
		
		string.pack("H", id) is the same as

		local n = id%256
		
		string.char((id-n)/256) .. string.char(n)
		
		]]

		return string.pack("H", id)

	end

end


local function decodeKey(key: string): number

	assert(type(key) == "string", "The key provided must be a string.")
	assert(#key < 3, "The key provided can't be larger than 2 characters.")

	if #key == 0 then return 0
	elseif #key == 1 then
		return 1 + string.byte(key) -- same as string.unpack("B", key)
	else
		return 1 + string.unpack("H", key)
	end

end


local function lock(t)
	return setmetatable(t, lockMeta)
end


--// Constructor \\--

--// Network


function Network.Register(name: string, property: networkProperty?, folder: Instance?) --: network

	assert(type(name) == "string", "Network.Register(name) required a string as first argument.")
	assert(not NetworkList[name], "Network |" .. name .. "| already exist.")

	property = property or Network.newNetworkProperty()

	assert(property, "Unable to set property to default.")

	local newNetwork = {}
	newNetwork.Name = name
	newNetwork.Events = {} :: {[string]: customSignal}
	newNetwork.Property = property :: networkProperty
	newNetwork.LocalEvents = {} :: {[string]: customSignal}
	newNetwork.RemoteQueue = {} :: {{Key: string, Params: signalParams, Args: array}}
	newNetwork.LocalStorage = property.EnableLocalStorage and {} or nil :: tbl?
	newNetwork.ReplicatedStorage = false :: boolean | eventTable

	newNetwork.SignalArray = {} :: {signalInfo}
	newNetwork.LocalSignalArray = {} :: {signalInfo}
	newNetwork.SignalCount = 0 :: number
	newNetwork.SignalIDCount = 0 :: number

	newNetwork.__Init = false :: boolean | BindableEvent
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

		elseif IsServer then

			newNetwork.__MainFolder = newNetwork._trove:Add(Instance.new("Folder"))
			newNetwork.__MainRemote = Instance.new("RemoteEvent", newNetwork.__MainFolder)
			newNetwork.__MainInvoke = Instance.new("RemoteFunction", newNetwork.__MainFolder)

			newNetwork.__MainFolder.Name = name
			newNetwork.__MainFolder.Parent = script

		end

	end

	if IsServer and property.AllowSignalRemote then
		newNetwork.__SignalFolder = Instance.new("Folder", newNetwork.__MainFolder)
	end

	newNetwork._trove:Set(NetworkList,name, newNetwork)

	setmetatable(newNetwork, NetworkMeta)

	networkEvent:Fire()

	return newNetwork

end


function Network.newNetworkProperty(): networkProperty

	local params = {}
	params.AllowCrossCommunication = true :: boolean --// client <-> server
	params.AllowSignalRemote = true :: boolean --// use remote of each signal if it has one.
	params.DefaultCreateSignalRemote = true :: boolean --// automatically create remote for each signal, will use more memory.
	params.QueueInterval = 1 :: number --// releasing queue every n heartbeat
	params.IntervalType = "Heartbeat" :: interval --// Interval type
	params.EnableReplicatedStorage = true :: boolean --// server -> client storage, require cross communication.
	params.EnableLocalStorage = true :: boolean --// local storage, server <-> server and client <-> client

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


function NetworkPrototype:__RegisterSignal(eventName: string, property: signalProperty, eventID: number): customSignal

	assert(self.Active, "This network is no longer active.")
	assert(self.SignalIDCount < 65537, "Signal limit reached.")

	self.SignalIDCount += 1

	local newSignal = Signal.new(eventID, eventName, Signal.__RegisterProperty(property))

	newSignal.Network = self

	newSignal._trove:Insert(self.SignalArray, newSignal.SignalInfo)
	newSignal._trove:Set(self.Events, eventName, newSignal)

	if typeof(property.MainRemote) == "Instance" then

		newSignal._trove:Connect(property.MainRemote.OnClientEvent, function(data)
			for _, args in data do
				newSignal:__Fired(unpack(args))
			end
		end)

	end

	if typeof(property.MainInvoke) == "Instance" then

		self._trove:Set(property.MainInvoke, "OnClientInvoke", function(...)

			if newSignal.OnInvoke then
				return newSignal.OnInvoke(...)
			end

			warn("No target for invoking, did you forget to implement OnInvoke for signal " .. self.Name .. "?")

		end)

	end

	self._internalEvent:Fire()

	return newSignal

end


function NetworkPrototype:__AddQueue(key: string, params: signalParams, args: array)

	if #self.RemoteQueue == 0 then

		if self.Property.QueueInterval > 0 then

			if self.Property.IntervalType == "Heartbeat" then

				if self.Property.QueueInterval == 1 then

					task.defer(self.__ReleaseQueue, self)

				else

					for i = 1, self.Property.QueueInterval do
						RunService.Heartbeat:Wait()
					end

					task.spawn(self.__ReleaseQueue, self)

				end

			elseif self.Property.IntervalType == "Millisecond" then

				task.wait(self.Property.QueueInterval/1000)
				task.spawn(self.__ReleaseQueue, self)

			else

				task.wait(self.Property.QueueInterval)
				task.spawn(self.__ReleaseQueue, self)

			end

		end

	end

	local remote = {
		Key = key,
		Params = params,
		Args = args,
	}

	table.insert(self.RemoteQueue, remote)

end


function NetworkPrototype:__ReleaseQueue()

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

			remotes[remote.Key] = property.Remote

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

						print("No remote for key: " .. key)

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


function NetworkPrototype:__ReplicateStorage(keys: {any}, oldValue: any, newValue: any)

	local target = self.ConnectedClient

	if type(target) == "table" and #target > 0 then
		
		self:__AddQueue('', {Target = target}, {(#keys > 1 or newValue == nil) and keys or keys[1], newValue})

	end

end


function NetworkPrototype:__SetConnection()

	if IsServer then

		self.ConnectedClient = {}

		self._trove:Connect(self.__MainRemote.OnServerEvent, function(player, data)

			if type(data) == "table" then

				for key, argslist in data do

					local id = decodeKey(key)

					local signal = self:GetSignalFromID(id)

					if signal then

						for _, args in argslist do

							signal:__Fired(player, unpack(args))

						end

					else
						warn("No signal for id: " .. id)
						continue
					end

				end

			else

				if type(self.ConnectedClient) == "table" then

					table.remove(PlayerList[player], table.find(PlayerList[player], self))
					table.remove(self.ConnectedClient, table.find(self.ConnectedClient, player))

					if data then

						table.insert(PlayerList[player], self)
						table.insert(self.ConnectedClient, player)

					end

				end

			end

		end)

		self._trove:Set(self.__MainInvoke, "OnServerInvoke", function(player, key, ...): any

			if not key then

				if type(self.ConnectedClient) == "table" then
					table.insert(PlayerList[player], self)
					table.insert(self.ConnectedClient, player)
				end

				local signalInfoArray = {}

				for _, v in self.SignalArray do

					if v.Signal.__Replicate then

						local info = {v.EventName, v.Property, v.Key} :: {string | signalProperty}
						table.insert(signalInfoArray, info)

					end

				end

				local returnTable = {
					signalInfoArray, --// signalInfoArray
				} :: {any}
				
				if type(self.ReplicatedStorage) == "table" then
					returnTable[2] = EventTable.GetMainTable(self.ReplicatedStorage)
				end

				return returnTable

			else

				local id = decodeKey(key)

				local signal = self:GetSignalFromID(id)
				if signal then

					if signal.OnInvoke then
						return signal.OnInvoke(player, ...)
					else
						return warn("OnInvoke function doesn't exist for event \"" .. signal.Name .."\". Did you forget to implement OnInvoke?")
					end

				else
					return warn("No signal for id: " .. id)
				end

			end

		end)

	else

		if self.__MainFolder then

			local initialiseData = self.__MainInvoke:InvokeServer()

			if initialiseData then

				for _, signalInfo in initialiseData[1] do

					self:__RegisterSignal(signalInfo[1], signalInfo[2], decodeKey(signalInfo[3]))

				end

				if self.ReplicatedStorage then

					self.ReplicatedStorage = EventTable.new(function(keys, oldValue, newValue)
						-- nothing yet
					end, initialiseData[2])

				end

			else
				error("Unable to retrieve initialise data")
			end


			self._trove:Connect(self.__MainRemote.OnClientEvent, function(data: {[string]: {any}})

				if data[''] then

					for _, args in data[''] do

						local argsN = #args

						if argsN == 1 then --// Destroy signal

							local key = args[1]

							if type(key) == "table" then --// Replicate storage (nested deletion)

								local layer = self.ReplicatedStorage
								assert(type(layer) == "table", "Network's ReplicatedStorage is not enabled.")	

								for i = #key, 2, -1 do
									layer = layer[key[i]]
								end

								layer[key[1]] = nil

							else

								local signal = self:GetSignalFromKey(key)

								if signal and signal.Active then

									if data[key] then

										for _, args in data[key] do

											signal:__Fired(unpack(args))

										end

									end

									signal:Destroy()

								end

								data[key] = nil

							end

						elseif argsN == 2 then --// Replicate storage

							local layer = self.ReplicatedStorage
							assert(type(layer) == "table", "Network's ReplicatedStorage is not enabled.")	

							local keys, value = unpack(args)

							if type(keys) == "string" then

								layer[keys] = value

							else

								for i = #keys, 2, -1 do
									layer = layer[keys[i]]
								end

								layer[keys[1]] = value

							end

						elseif argsN == 3 then --// Create signal
							self:CreateSignal(unpack(args))

						end

					end

					data[''] = nil

				end

				for key, argslist in data do

					local id = decodeKey(key)

					local signal = self:GetSignalFromID(id)

					if signal then 

						for _, args in argslist do

							signal:__Fired(unpack(args))

						end

					else

						warn("No signal for id: " .. id)
						continue

					end

				end

				return

			end)


			self._trove:Set(self.__MainInvoke, "OnClientInvoke", function(key, ...)

				local id = decodeKey(key)

				local signal = self:GetSignalFromID(id)

				if signal then

					if signal.OnInvoke then
						return signal.OnInvoke(...)
					else
						return warn("OnInvoke function doesn't exist for event \"" .. signal.Name .."\". Did you forget to implement OnInvoke?")
					end

				else
					return warn("No signal for id: " .. id)
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


function NetworkPrototype:CreateSignal(eventName: string, property: signalProperty?, eventID: number?): customSignal

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

	local signalInfo =  newSignal.SignalInfo :: signalInfo

	newSignal._trove:Insert(self.SignalArray, signalInfo)
	newSignal._trove:Set(self.Events, eventName, newSignal)

	local property = newSignal.Property

	if self.Property.AllowSignalRemote and self.Property.DefaultCreateSignalRemote then

		if not property.MainRemote then
			property.MainRemote = newSignal._trove:Add(Instance.new("RemoteEvent", self.__SignalFolder)) :: RemoteEvent
		end

		if not property.MainInvoke then
			property.MainInvoke = newSignal._trove:Add(Instance.new("RemoteFunction", self.__SignalFolder)) :: RemoteFunction
		end

	end

	if typeof(property.MainRemote) == "Instance" then

		newSignal._trove:Connect(property.MainRemote.OnServerEvent, function(player, data)
			for _, args in data do
				newSignal:__Fired(player, unpack(args))
			end
		end)

	end

	if typeof(property.MainInvoke) == "Instance" then

		function property.MainInvoke.OnServerInvoke(player, ...)

			if newSignal.OnInvoke then
				return newSignal.OnInvoke(player, ...)
			end

			warn("No target for invoking, did you forget to implement OnInvoke for signal " .. self.Name .. "?")

		end

	end

	local target = self.ConnectedClient

	if type(target) == "table" and #target > 0 then
		self:__AddQueue('', {Target = target}, {signalInfo.EventName, signalInfo.Property, signalInfo.ID} :: array)
	end

	self._internalEvent:Fire()

	return newSignal

end


function NetworkPrototype:GetSignal(eventName: string): customSignal?

	assert(self.Active, "This network is no longer active.")
	assert(type(eventName) == "string", "First argument provided must be string.")

	return self.Events[eventName]

end


function NetworkPrototype:GetSignalFromID(signalID: number): customSignal?

	assert(self.Active, "This network is no longer active.")
	assert(type(signalID) == "number", "The ID provided must be a number.")

	local signalInfo = self.SignalArray[signalID]

	if signalInfo then
		return self.Events[signalInfo.EventName]
	end

	return warn("Unable to find signal from id " .. signalID)

end


function NetworkPrototype:GetSignalFromKey(key: string): customSignal?
	return self:GetSignalFromID(decodeKey(key))
end


function NetworkPrototype:WaitForSignal(eventName: string): customSignal

	assert(self.Active, "This network is no longer active.")
	assert(type(eventName) == "string", "First argument provided must be string.")

	local tbl = self.Events
	if tbl[eventName] then return tbl[eventName] end

	repeat
		self._internalEvent.Event:Wait()
	until tbl[eventName]

	return tbl[eventName]

end


function NetworkPrototype:WaitForSignalWithID(signalID: number): customSignal

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


function NetworkPrototype:ConnectSignal(eventName: string, func: func): customConnection

	assert(self.Active, "This network is no longer active.")
	assert(type(eventName) == "string", "First argument provided must be string.")
	assert(self.Events[eventName], "Event " .. eventName .. " doesn't exist.")

	return self.Events[eventName]:Connect(func)

end


function NetworkPrototype:DisconnectSignal(eventName: string)

	assert(self.Active, "This network is no longer active.")
	assert(type(eventName) == "string", "First argument provided must be string.")
	assert(self.Events[eventName], "Event " .. eventName .. " doesn't exist.")

	return self.Events[eventName]:Disconnect()

end


function NetworkPrototype:DeleteSignal(eventName: string)

	assert(self.Active, "This network is no longer active.")
	assert(type(eventName) == "string", "First argument provided must be string.")
	assert(self.Events[eventName], "Event " .. eventName .. " doesn't exist.")

	return self.Events[eventName]:Destroy()

end


function NetworkPrototype:FireSignal(eventName: string, params: signalParams?, ...: any)

	assert(self.Active, "This network is no longer active.")
	assert(type(eventName) == "string", "First argument provided must be string.")
	assert(self.Events[eventName], "Event " .. eventName .. " doesn't exist.")

	return self.Events[eventName]:Fire(params, ...)

end


function NetworkPrototype:InvokeSignal(eventName: string, params: signalParams?, ...: any): any

	assert(self.Active, "This network is no longer active.")
	assert(type(eventName) == "string", "First argument provided must be string.")
	assert(self.Events[eventName], "Event " .. eventName .. " doesn't exist.")

	return self.Events[eventName]:Invoke(params, ...)

end


--// Local Signal


function NetworkPrototype:CreateLocalSignal(eventName: string, property: signalProperty?): customSignal

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


function NetworkPrototype:GetLocalSignal(eventName: string): customSignal?

	assert(self.Active, "This network is no longer active.")
	assert(typeof(eventName) == "string", "First argument provided must be string.")

	return self.LocalEvents[eventName]

end


function NetworkPrototype:GetLocalSignalFromID(signalID: number): customSignal?

	assert(self.Active, "This network is no longer active.")
	assert(type(signalID) == "number", "The ID provided must be a number.")

	local signalInfo = self.LocalSignalArray[signalID]

	if signalInfo then
		return self.LocalEvents[signalInfo.EventName]
	end

	return warn("Unable to find local signal from id " .. signalID)

end


function NetworkPrototype:WaitForLocalSignal(eventName: string): customSignal

	assert(self.Active, "This network is no longer active.")
	assert(typeof(eventName) == "string", "First argument provided must be string.")

	local tbl = self.LocalEvents
	if tbl[eventName] then return tbl[eventName] end

	repeat
		self._internalEvent.Event:Wait()
	until tbl[eventName]

	return tbl[eventName]

end


function NetworkPrototype:WaitForLocalSignalWithID(signalID: number): customSignal

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


function NetworkPrototype:ConnectLocalSignal(eventName: string, func: func): customConnection

	assert(self.Active, "This network is no longer active.")
	assert(typeof(eventName) == "string", "First argument provided must be string.")
	assert(self.LocalEvents[eventName], "LocalEvent " .. eventName .. " doesn't exist.")

	return self.LocalEvents[eventName]:Connect(func)

end


function NetworkPrototype:DisconnectLocalSignal(eventName: string)

	assert(self.Active, "This network is no longer active.")
	assert(typeof(eventName) == "string", "First argument provided must be string.")
	assert(self.LocalEvents[eventName], "LocalEvent " .. eventName .. " doesn't exist.")

	return self.Events[eventName]:Disconnect()

end


function NetworkPrototype:DeleteLocalSignal(eventName: string)

	assert(self.Active, "This network is no longer active.")
	assert(typeof(eventName) == "string", "First argument provided must be string.")
	assert(self.LocalEvents[eventName], "LocalEvent " .. eventName .. " doesn't exist.")

	return self.Events[eventName]:Destroy()

end


function NetworkPrototype:FireLocalSignal(eventName: string, params: signalParams?, ...: any)

	assert(self.Active, "This network is no longer active.")
	assert(typeof(eventName) == "string", "First argument provided must be string.")
	assert(self.LocalEvents[eventName], "LocalEvent " .. eventName .. " doesn't exist.")

	return self.Events[eventName]:Fire(params, ...)

end


function NetworkPrototype:InvokeLocalSignal(eventName: string, params: signalParams?, ...: any): any

	assert(self.Active, "This network is no longer active.")
	assert(typeof(eventName) == "string", "First argument provided must be string.")
	assert(self.LocalEvents[eventName], "LocalEvent " .. eventName .. " doesn't exist.")

	return self.Events[eventName]:Invoke(params, ...)

end


--// Network


function NetworkPrototype:DisconnectClient(player: Player, left: boolean)

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


function NetworkPrototype:Disconnect()

	assert(not IsServer, "This method can only be called from client.")
	self.__MainRemote:FireServer()

end


function NetworkPrototype:Reconnect()

	assert(not IsServer, "This method can only be called from client.")
	self.__MainRemote:FireServer(true)

end


function NetworkPrototype:Destroy()

	assert(self.Active, "This network is no longer active.")

	NetworkList[self.Name] = nil
	self._trove:CleanUp()

end


function NetworkPrototype:Init(): network

	assert(self.Active, "This network is no longer active.")

	if self.__Init == true then warn("This network has already been initialised.") return self end

	if type(self.__Init) ~= "boolean" then
		warn("The network is initalising, this will yield until the process finish.")
		self.__Init.Event:Wait()
		return self
	end

	self.__Init = Instance.new("BindableEvent")

	if self.Property.AllowCrossCommunication then

		if self.Property.EnableReplicatedStorage then

			if IsServer then

				self.ReplicatedStorage = EventTable.new(function(keys, oldValue, newValue)
					
					if type(newValue) == "table" then
						newValue = EventTable.GetMainTable(newValue)
					end
					
					self:__ReplicateStorage(keys, oldValue, newValue)
					
				end)

			else

				self.ReplicatedStorage = true

			end

		end

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