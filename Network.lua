--!strict

--// Types \\--

type func = (...any) -> (...any)
type signalProperty = {
	Target: (Player | {Player} | "All")?,
	Disconnect: boolean?
}

--// Services \\--

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

--// Variables \\--

local networkEvent = Instance.new("BindableEvent")
local IsServer = RunService:IsServer()

local UniqueID = {} :: {[string]: true}
local NetworkList = {} :: {[string]: network}
local Identifiers = {} :: {[network]: string}

--// Main Module \\--

--// Network

local Network = {}

local NetworkPrototype = {}

local NetworkMeta = {

	__index = NetworkPrototype,
	__newindex = function() end,
	__metatable = "Locked"

}


--// Signal

local Signal = {}
local SignalMethods = {}

local SignalMeta = {

	__index = SignalMethods,
	__newindex = function(t,k,v) if k == "OnInvoke" then rawset(t,k,v) end end,
	__metatable = "Locked"

}


--// Connection

local Connection = {}
local ConnectionMethods = {}

local ConnectionMeta = {

	__index = ConnectionMethods,
	__newindex = function() end,
	__metatable = "Locked"

}


--// Trove

local Trove = {}
local TroveMethods = {}

local TroveMeta = {

	__index = TroveMethods,
	__newindex = function() end,
	__metatable = "Locked"

}


--// Private Functions \\--


local function generateUniqueIdentifier(n: number?, retry: number?): string | false

	local identifier = ""

	for i = 1, tonumber(n) or 20 do
		identifier ..= string.char(math.random(33, 126))
	end

	if UniqueID[identifier] then

		if retry == 0 then return false, warn("Unable to generate unique identifer") end
		print("not unique, retrying...")

		return generateUniqueIdentifier(n, retry and retry-1 or 10)

	end

	UniqueID[identifier] = true

	return identifier

end


local function getIdentifier(network: network): string

	local identifier = assert(Identifiers[network], "Invalid network.")
	return identifier

end


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


--// Constructor \\--


--// Network


function Network.Register(name: string?, params: networkParams?, folder: Instance?): (network, string)

	assert(name == nil or type(name) == "string", "The first argument, if provided, must be a string.")

	local Identifier = name or generateUniqueIdentifier()

	assert(type(Identifier) == "string", "Unable to generate unique identifer")
	assert(not NetworkList[Identifier], "Network |" .. Identifier .. "| already exist.")

	params = params or Network.newNetworkParams()

	local newNetwork = {}
	newNetwork.__Init = Instance.new("BindableEvent") :: boolean | BindableEvent
	newNetwork.Events = {} :: {[string]: customSignal}
	newNetwork.RemoteQueue = {} :: {{Key: string, Properties: signalProperty, Args: {any}}}

	if IsServer then
		newNetwork.ConnectedClient = {} :: {Player}
	end

	newNetwork.SignalArray = {} :: {[number]: signalInfo}
	newNetwork.SignalCount = 0 :: number
	newNetwork.SignalIDCount = 0 :: number

	newNetwork._internalEvent = Instance.new("BindableEvent")
	newNetwork._trove = Trove.new() :: trove
	newNetwork._trove:Set(UniqueID, Identifier, true)

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
			newNetwork.__MainFolder = Instance.new("Folder")
			newNetwork.__MainRemote = Instance.new("RemoteEvent", newNetwork.__MainFolder)
			newNetwork.__MainInvoke = Instance.new("RemoteFunction", newNetwork.__MainFolder)

			newNetwork.__MainFolder.Name = Identifier
			newNetwork.__MainFolder.Parent = script

		end

	end

	setmetatable(newNetwork, NetworkMeta)

	NetworkList[Identifier] = newNetwork
	Identifiers[newNetwork] = Identifier

	networkEvent:Fire(newNetwork)

	return newNetwork, Identifier

end


function Network.newNetworkParams(): networkParams

	local params = {}

	return params

end


Network.newSignalParams = Signal.newParams

--// Signal


function Signal.new(network: network, signalName: string?, signalParams: signalParams?, signalID: number?): customSignal

	local Identifier = signalName or network._trove:Set(UniqueID, generateUniqueIdentifier(), true)

	assert(type(Identifier) == "string", "Unable to generate unique identifer")

	if network.Events[Identifier] then

		warn("Event " .. Identifier .. " already exist, returning the existing signal...")

		return network.Events[Identifier]

	end

	local signalID = signalID or network.SignalIDCount

	local newSignal = {}
	newSignal.Connections = {} :: {(...any) -> (...any)}
	newSignal.ConnectionList = {} :: {any} --:: {customConnection}
	newSignal.ThreadList = {} :: {thread}
	newSignal.Network = network
	newSignal.Name = Identifier
	newSignal.ID = signalID
	newSignal.Key = generateSignalID(signalID)
	newSignal.SignalInfo = {ID = newSignal.ID, Key = newSignal.Key, EventName = newSignal.Name, Params = signalParams or Signal.newParams()} :: signalInfo
	newSignal.OnInvoke = nil :: func?

	network.SignalArray[newSignal.ID] = newSignal.SignalInfo

	setmetatable(newSignal, SignalMeta)

	return newSignal

end


function Signal.newParams(): signalParams

	local signalParams = {}
	signalParams.Replicate = false :: boolean
	signalParams.Once = false :: boolean

	return signalParams

end


--// Connection


function Connection.new(signal: customSignal, func: func): customConnection

	local newConnection = {}
	newConnection.Signal = signal
	newConnection.Connected = true
	newConnection.__Function = func

	setmetatable(newConnection, ConnectionMeta)

	return newConnection

end


--// Trove


function Trove.new()

	local newTrove = {}
	newTrove.Instances = {} :: {[Instance]: true}
	newTrove.ConnectionArray = {} :: {RBXScriptConnection}
	newTrove.KeyConnections = {} :: {[string]: RBXScriptConnection}
	newTrove.Binding = {} :: {RemoteFunction}
	newTrove.Keys = {} :: {[any]: {any}}

	setmetatable(newTrove, TroveMeta)

	return newTrove

end


--// Declare object types


type network = typeof(Network.Register())
type customSignal = typeof(Signal.new(({Network.Register()})[1]))
type customConnection = typeof(Connection.new(Signal.new(({Network.Register()})[1]), function() return end))
type trove = typeof(Trove.new())
type signalParams = typeof(Signal.newParams())
type signalInfo = {ID: string | number, Key: string, EventName: string, Params: signalParams?}
type networkParams = typeof(Network.newNetworkParams())


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

		while not NetworkList[identifier] do
			networkEvent.Event:Wait()
		end

		return NetworkList[identifier]

	else

		local networkFolder = script:FindFirstChild(identifier)

		if networkFolder then

			waitForChildOfClass(networkFolder, "RemoteEvent")
			waitForChildOfClass(networkFolder, "RemoteFunction")

			return Network.Register(identifier, nil, networkFolder)

		end

		local bindable = Instance.new("BindableEvent")
		local nw

		local c1, c2

		c1 = script.ChildAdded:Connect(function(folder)
			if folder.Name == identifier then

				c1:Disconnect()
				c2:Disconnect()

				waitForChildOfClass(folder, "RemoteEvent")
				waitForChildOfClass(folder, "RemoteFunction")

				nw = Network.Register(identifier, nil, folder)

				bindable:Fire(nw)

			end
		end)

		c2 = networkEvent.Event:Connect(function(network : network)
			if Identifiers[network] == identifier then

				c1:Disconnect()
				c2:Disconnect()

				nw = network

				bindable:Fire()

			end
		end)

		bindable.Event:Wait()
		return nw

	end

end


--// Private Methods \\--


function NetworkPrototype.__AddQueue(self: network, Key: any, properties: signalProperty, args: {any})

	if #self.RemoteQueue == 0 then
		task.defer(self.__ReleaseQueue, self)
	end

	local remote = {
		Key = Key,
		Properties = properties,
		Args = args
	}

	table.insert(self.RemoteQueue, remote)

end


function NetworkPrototype.__ReleaseQueue(self: network)

	local data = {} :: {[any]: any}

	for _, remote in self.RemoteQueue do

		local property = remote.Properties

		if IsServer then

			if not property.Target or property.Target == "All" then
				property.Target = Players:GetPlayers()
			end

			if type(property.Target) == "table" then

				for _,player in property.Target do

					if not data[player] then data[player] = {} end
					if not data[player][remote.Key] then data[player][remote.Key] = {} end

					table.insert(data[player][remote.Key], remote.Args)
				end

			elseif typeof(property.Target) == "Instance" then

				if not data[property.Target] then data[property.Target] = {} end
				if not data[property.Target][remote.Key] then data[property.Target][remote.Key] = {} end

				table.insert(data[property.Target][remote.Key], remote.Args)

			end

		else

			if not data[remote.Key] then data[remote.Key] = {} end
			table.insert(data[remote.Key], remote.Args)

		end

	end

	table.clear(self.RemoteQueue)

	if self.__MainFolder then

		if IsServer then

			for player, info in data do
				self.__MainRemote:FireClient(player, info)
			end

		else

			self.__MainRemote:FireServer(data)

		end

	end

end


--// Methods \\--


--// Connections Methods


function ConnectionMethods.Disconnect(self: customConnection)

	local tbl = self.Signal.Connections

	local index = table.find(tbl, self.__Function)

	if index then

		tbl[index] = tbl[#tbl]
		tbl[#tbl] = nil

		self.Connected = false

	else
		return warn("Unable to find index for function")
	end

end


--// Signal Methods


function SignalMethods.Connect(self: customSignal, func: (...any) -> (...any)): customConnection

	assert(type(self) == "table", "Expected ':' not '.' calling member function Connect")
	assert(typeof(func) == "function", "First argument provided must be function.")

	local newConnection = Connection.new(self, func) :: customConnection
	table.insert(self.Connections, func)
	table.insert(self.ConnectionList, newConnection)

	return newConnection

end


function SignalMethods.Disconnect(self: customSignal)

	for _, connection in self.ConnectionList do
		connection:Disconnect()
	end

end


function SignalMethods.Fire(self: customSignal, property: signalProperty, ...: any)

	if IsServer then

		property = property or {}

		if property.Target then

			if type(property.Target) == "table" then

				for _, player in property.Target do
					assert(typeof(player) == "Instance" and player:IsA("Player"), "All value in Target must be a player.")
				end

			else
				assert(typeof(property.Target) == "Instance" and property.Target:IsA("Player"), "Target must be a player.")
			end

		else	

			property.Target = "All"

		end

	end

	for _, connection in self.Connections do
		task.spawn(connection, ...) 
	end

	for _, thread in self.ThreadList do
		task.spawn(thread, ...)
	end
	
	table.clear(self.ThreadList)

	self.Network:__AddQueue(self.Key, property, {...})

end


function SignalMethods.Invoke(self: customSignal, property: signalProperty, ...: any): unknown

	if self.OnInvoke then
		return self.OnInvoke(...)
	else

		if IsServer then

			assert(property, "SignalProperty must be provided.")
			assert(typeof(property.Target) == "Instance" and property.Target:IsA("Player"), "Target must be a player.")

			return self.Network.__MainInvoke:InvokeClient(property.Target, self.Key, ...)
		else
			return self.Network.__MainInvoke:InvokeServer(self.Key, ...)
		end

	end

end


function SignalMethods.Wait(self: customSignal)

	local thread = coroutine.running()
	table.insert(self.ThreadList, thread)

	return coroutine.yield()

end


--// Network Methods


function NetworkPrototype.newSignalParams()
	return Signal.newParams()
end


function NetworkPrototype.CreateSignal(self: network, eventName: string, params : signalParams?, eventID: number?): customSignal

	assert(type(self) == "table" and Identifiers[self], "Expected ':' not '.' calling member function Register")
	assert(typeof(eventName) == "string", "First argument provided must be string.")
	assert(self.SignalIDCount < 16777217, "Signal limit is 16777216 signals.")

	self.SignalIDCount += 1

	local newSignal = Signal.new(self, eventName, params, eventID)
	self.Events[eventName] = newSignal

	self._internalEvent:Fire()

	if IsServer then
		self:__AddQueue('', {Target = self.ConnectedClient}, {newSignal.SignalInfo})
	end

	return newSignal

end


function NetworkPrototype.GetSignal(self: network, eventName: string): customSignal?
	return self.Events[eventName]
end


function NetworkPrototype.GetSignalFromID(self: network, signalID: number): customSignal?
	local signalInfo = self.SignalArray[signalID]
	return signalInfo and self.Events[signalInfo.EventName]
end


function NetworkPrototype.WaitForSignal(self: network, eventName: string): customSignal

	if self.Events[eventName] then return self.Events[eventName] end

	repeat
		self._internalEvent.Event:Wait()
	until self.Events[eventName]

	return self.Events[eventName]

end


function NetworkPrototype.WaitForSignalWithID(self: network, signalID: number): customSignal

	local signalInfo = self.SignalArray[signalID]

	if signalInfo then return self.Events[signalInfo.EventName] end

	repeat
		self._internalEvent.Event:Wait()
	until self.SignalArray[signalID]

	return self.Events[self.SignalArray[signalID].EventName]

end


function NetworkPrototype.DisconnectSignal(self: network, eventName: string)
	assert(self.Events[eventName], "Event " .. tostring(eventName) .. " doesn't exist.")
	self.Events[eventName]:Disconnect()
end


function NetworkPrototype.ConnectSignal(self: network, eventName: string, func: func)
	assert(self.Events[eventName], "Event " .. tostring(eventName) .. " doesn't exist.")
	return self.Events[eventName]:Connect(func)
end


function NetworkPrototype.FireSignal(self: network, eventName: string, property: signalProperty, ...: any)
	assert(self.Events[eventName], "Event " .. tostring(eventName) .. " doesn't exist.")
	return self.Events[eventName]:Fire(property, ...)
end


function NetworkPrototype.InvokeSignal(self: network, eventName: string, property: signalProperty, ...: any)

	assert(self.Events[eventName], "Event " .. tostring(eventName) .. " doesn't exist.")

	return self.Events[eventName]:Invoke(property, ...)

end


function NetworkPrototype.Destroy(self: network)

	NetworkList[Identifiers[self]] = nil
	Identifiers[self] = nil

	self._trove:CleanUp()

end


function NetworkPrototype.Init(self: network): network

	if self.__Init == true then return self, warn("Network already initialised.") end

	if IsServer then

		self.__MainRemote.OnServerEvent:Connect(function(player, data)

			for key, info in data do

				local id = decodeKey(key)

				local signalInfo = self.SignalArray[id]
				if not signalInfo then warn("No signal for id: " .. id) continue end

				local event = self.Events[signalInfo.EventName]
				if not event then warn("Event " .. signalInfo.EventName .. " doesn't exist.") continue end

				for _, args in info do
					for _, connection in event.Connections do
						task.spawn(connection, unpack(args))
					end
					for _, thread in event.ThreadList do
						task.spawn(thread, unpack(args))
					end
					table.clear(event.ThreadList)
				end

			end

		end)

		function self.__MainInvoke.OnServerInvoke(player, key, ...)

			if not key then
				table.insert(self.ConnectedClient, player)
				return self.SignalArray
			else

				local id = decodeKey(key)

				local signalInfo = self.SignalArray[id]
				if not signalInfo then error("No signal for id: " .. id) return end

				local event = self.Events[signalInfo.EventName]
				if not event then error("Event " .. tostring(signalInfo.EventName) .. " doesn't exist.") return end

				if event.OnInvoke then
					return event.OnInvoke(...)
				else
					return
				end

			end

		end

	else

		if self.__MainFolder then

			local signalArray = self.__MainInvoke:InvokeServer() :: {signalInfo}

			if signalArray then

				self.SignalArray = signalArray

				for id, info in signalArray do

					self:CreateSignal(info.EventName, info.Params, id)

				end

			else
				warn("Unable to find signal array")
			end

			self._trove:Connect(self.__MainRemote.OnClientEvent, function(data: {[string]: {{any}}})

				if data[''] then

					for _, v in data[''] do
						for _, signalInfo in v do
							self:CreateSignal(signalInfo.EventName, signalInfo.Params, signalInfo.ID)
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
						for _, connection in event.Connections do
							task.spawn(connection, unpack(args))
						end
						for _, thread in event.ThreadList do
							task.spawn(thread, unpack(args))
						end
						table.clear(event.ThreadList)
					end

				end

				return

			end)

			function self.__MainInvoke.OnClientInvoke(key, ...)

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

			end


		else

			print("Network doesn't have a main folder. Only local communication will be avaliable.")

		end

	end

	assert(typeof(self.__Init) == "Instance" and self.__Init:IsA("BindableEvent"), "Invalid initializing variable")

	self.__Init:Fire()
	self.__Init = true

	return self

end


--// Trove Methods

function TroveMethods.Add(self: trove, item: Instance): Instance

	assert(typeof(item) == "Instance", "First argument provided must be an instance.")

	self.Instances[item] = true

	return item

end


function TroveMethods.Set(self: trove, tbl: {any}, key: any, value: any)

	assert(type(tbl) == "table", "First argument provided must be a table.")
	assert(key ~= nil, "Second argument (key) must be provided for table item type.")

	if value then

		if not self.Keys[key] then self.Keys[key] = {} end
		table.insert(self.Keys[key], tbl)

		tbl[key] = value

	end

end


function TroveMethods.Insert(self: trove, tbl: {any}, value: any)

	assert(type(tbl) == "table", "First argument provided must be a table.")

	local key = #tbl

	if value then

		if not self.Keys[key] then self.Keys[key] = {} end
		table.insert(self.Keys[key], tbl)

		tbl[key] = value

	end

end


function TroveMethods.Connect(self: trove, key: string | RBXScriptSignal, event: RBXScriptSignal | func, func: func?): RBXScriptConnection

	if type(key) == "string" then

		assert(typeof(event) == "RBXScriptSignal" and type(func) == "function", "Invalid argument provided.")
		assert(not self.KeyConnections[key], "Connection already exist under the same key: " .. key)

		local connection = event:Connect(func)
		self.KeyConnections[key] = connection

		return connection

	else

		assert(typeof(key) == "RBXScriptSignal" and type(event) == "function", "Invalid argument provided.")

		local connection = key:Connect(event)
		table.insert(self.ConnectionArray, connection)

		return connection

	end

end


function TroveMethods.CleanUp(self: trove)

	for _, connection in self.ConnectionArray do
		connection:Disconnect()
	end

	for _, connection in self.KeyConnections do
		connection:Disconnect()
	end

	for key, list in self.Keys do

		for _, tbl in list do
			tbl[key] = nil
		end

	end

	for instance in self.Instances do
		instance:Destroy()
	end

end


--// Return \\--

return Network
