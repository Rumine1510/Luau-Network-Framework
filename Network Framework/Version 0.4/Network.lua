--!strict

-- Network Framework V.04

--// Types \\--

type func = (...any) -> (...any)

type signalProperty = {
	Target: (Player | {Player} | "All")?,
	Disconnect: boolean?
}

--// Services \\--

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

--// Variables \\--

local networkEvent = Instance.new("BindableEvent")
local IsServer = RunService:IsServer()

local NetworkList = {} :: {[string]: network}

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


--// Trove


function Trove.new(): trove

	local newTrove = {}
	newTrove.Instances = {} :: {[Instance]: true}
	newTrove.ConnectionArray = {} :: {RBXScriptConnection}
	newTrove.KeyConnections = {} :: {[string]: RBXScriptConnection}
	newTrove.Binding = {} :: {RemoteFunction}
	newTrove.Keys = {} :: {[unknown]: {any}}

	local trove = setmetatable(newTrove, TroveMeta) :: trove

	return trove

end


type trove = typeof(Trove.new())


--// Signal


function Signal.new(signalID: number, signalName: string?, signalParams: signalParams?): customSignal

	local Identifier = signalName or HttpService:GenerateGUID()

	local newSignal = {}

	newSignal.Network = false :: network?
	newSignal.Name = Identifier
	newSignal.ID = signalID
	newSignal.Key = generateSignalID(signalID)
	newSignal.Params = signalParams or Signal.newParams()

	newSignal.Connections = {} :: {(...unknown) -> (...unknown)}
	newSignal.ConnectionList = {} :: {customConnection}
	newSignal.ThreadList = {} :: {thread}

	newSignal.SignalInfo = {

		ID = newSignal.ID,
		Key = newSignal.Key,
		EventName = newSignal.Name,
		Params = newSignal.Params

	} :: signalInfo

	newSignal.OnInvoke = nil :: func?
	newSignal.Active = true :: boolean

	newSignal._trove = Trove.new()

	setmetatable(newSignal, SignalMeta)

	return newSignal

end


function Signal.newParams(): signalParams

	local signalParams = {}
	signalParams.Replicate = true :: boolean
	signalParams.Once = false :: boolean

	return signalParams

end


type customSignal = typeof(Signal.new(-1))
type signalParams = typeof(Signal.newParams())
type signalInfo = {ID: number, Key: string, EventName: string, Params: signalParams}


--// Network


function Network.Register(name: string, params: networkParams?, folder: Instance?): network

	assert(type(name) == "string", "Network.Register(name) required a string as first argument.")
	assert(not NetworkList[name], "Network |" .. name .. "| already exist.")

	params = params or Network.newNetworkParams()

	local newNetwork = {}
	newNetwork.Events = {} :: {[string]: customSignal}
	newNetwork.RemoteQueue = {} :: {{Key: string, Properties: signalProperty, Args: {any}}}
	newNetwork.Name = name

	newNetwork.SignalArray = {} :: {signalInfo}
	newNetwork.SignalCount = 0 :: number
	newNetwork.SignalIDCount = 0 :: number

	newNetwork.__Init = Instance.new("BindableEvent") :: boolean | BindableEvent
	newNetwork._internalEvent = Instance.new("BindableEvent")
	newNetwork._trove = Trove.new() :: trove
	
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

			--newNetwork.__MainFolder = newNetwork._trove:Add(Instance.new("Folder"))
			newNetwork.__MainFolder = Instance.new("Folder")
			newNetwork.__MainRemote = Instance.new("RemoteEvent", newNetwork.__MainFolder)
			newNetwork.__MainInvoke = Instance.new("RemoteFunction", newNetwork.__MainFolder)

			newNetwork.__MainFolder.Name = name
			newNetwork.__MainFolder.Parent = script

		end

	end

	setmetatable(newNetwork, NetworkMeta)

	NetworkList[name] = newNetwork

	networkEvent:Fire(newNetwork)

	return newNetwork

end


function Network.newNetworkParams(): networkParams

	local params = {}

	return params

end


Network.newSignalParams = Signal.newParams


type network = typeof(Network.Register("Type"))
type networkParams = typeof(Network.newNetworkParams())


--// Connection


function Connection.new(signal: customSignal, func: func): customConnection

	local newConnection = {}
	newConnection.Signal = signal
	newConnection.Connected = true
	newConnection.Function = func

	setmetatable(newConnection, ConnectionMeta)

	return newConnection

end


type customConnection = typeof(Connection.new(Signal.new(-1), function() end))


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

		c2 = networkEvent.Event:Connect(function(network : network)
			if network.Name == identifier then

				c1:Disconnect()
				c2:Disconnect()

				task.spawn(thread, network)

			end
		end)

		return coroutine.yield()

	end

end


--// Private Methods \\--


--// Network


function NetworkPrototype:__AddQueue(Key: string, properties: signalProperty, args: {any})

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


function NetworkPrototype:__ReleaseQueue()
	
	local data = {} :: {[Player | string]: any}

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

			elseif typeof(property.Target) == "Instance" and property.Target:IsA("Player") then

				if not data[property.Target] then data[property.Target] = {} end
				if not data[property.Target][remote.Key] then data[property.Target][remote.Key] = {} end

				table.insert(data[property.Target][remote.Key], remote.Args)
				
			else
				
				warn("Unable to find target for signal " .. decodeKey(remote.Key))

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

				if typeof(player) == "Instance" and player:IsA("Player") then

					self.__MainRemote:FireClient(player, info)

				else

					warn("Target is not a player.")

				end

			end

		else

			self.__MainRemote:FireServer(data)

		end

	end
	
	print(data)
	
end


function NetworkPrototype:__SetConnection()
	
	if IsServer then

		self.ConnectedClient = {}

		self.__MainRemote.OnServerEvent:Connect(function(player, data)
			
			print(data)

			for key, info in data do

				local id = decodeKey(key)

				local signalInfo = self.SignalArray[id]
				if not signalInfo then warn("No signal for id: " .. id) continue end

				local event = self.Events[signalInfo.EventName]
				if not event then warn("Event " .. signalInfo.EventName .. " doesn't exist.") continue end

				for _, args in info do

					event:__Fired(unpack(args))

				end

			end

		end)

		function self.__MainInvoke.OnServerInvoke(player, key, ...)

			if not key then

				if type(self.ConnectedClient) == "table" then
					table.insert(self.ConnectedClient, player)
				end
				
				local returnTable = {} :: {{string | signalParams}}
				
				for i, v in self.SignalArray do
					if v.Params.Replicate then
						returnTable[i] = {v.EventName, v.Params}
					end
				end
				
				
				
				return returnTable

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
						
			local signalArray = self.__MainInvoke:InvokeServer()

			if signalArray then
				
				for id, info in signalArray do

					self:CreateSignal(info[1], info[2], id)

				end

			else
				warn("Unable to find signal array")
			end
			
			
			self._trove:Connect(self.__MainRemote.OnClientEvent, function(data: {[string]: {{signalInfo}}})
						
				if data[''] then

					for _, v in data[''] do
						for _, signalInfo in v do

							if type(signalInfo) == "table" then

								self:CreateSignal(signalInfo.EventName, signalInfo.Params, signalInfo.ID)

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
	
end


--// Signal

function SignalMethods:__Fired(...: any)

	for _, connection in self.Connections do
		task.spawn(connection, ...) 
	end

	for _, thread in self.ThreadList do
		task.spawn(thread, ...)
	end

	table.clear(self.ThreadList)

	if self.SignalInfo.Params.Once then
		self:Destroy()
	end

end


--// Methods \\--


--// Connections Methods


function ConnectionMethods:Disconnect()

	local tbl = self.Signal.Connections

	local index = table.find(tbl, self.Function)

	if index then

		tbl[index] = tbl[#tbl]
		tbl[#tbl] = nil

		self.Connected = false

	else

		warn("Unable to find index for function")

	end

end


--// Signal Methods


function SignalMethods:Connect(func: (...unknown) -> (...unknown)): customConnection

	assert(type(self) == "table", "Expected ':' not '.' calling member function Connect")
	assert(self.Active, "Signal is no longer active.")
	assert(typeof(func) == "function", "First argument provided must be function.")

	local newConnection = Connection.new(self, func) :: customConnection

	table.insert(self.Connections, func)
	table.insert(self.ConnectionList, newConnection)

	return newConnection

end


function SignalMethods:Disconnect()
	
	assert(self.Active, "Signal is no longer active.")

	for _, connection in self.ConnectionList do
		connection:Disconnect()
	end
	
	for _, thread in self.ThreadList do
		task.spawn(thread)
	end

end


function SignalMethods:Fire(property: signalProperty, ...: unknown)
	
	assert(self.Active, "Signal is no longer active.")

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

	self:__Fired(...)

	if self.Network then
		self.Network:__AddQueue(self.Key, property, {...})
	end

end


function SignalMethods:Invoke(property: signalProperty, ...: unknown): unknown
	
	assert(self.Active, "Signal is no longer active.")

	if self.OnInvoke then

		return self.OnInvoke(...)

	elseif self.Network then

		if IsServer then

			assert(property, "SignalProperty must be provided.")
			assert(typeof(property.Target) == "Instance" and property.Target:IsA("Player"), "Target must be a player.")

			return self.Network.__MainInvoke:InvokeClient(property.Target, self.Key, ...)

		else

			return self.Network.__MainInvoke:InvokeServer(self.Key, ...)

		end

	end
	
	return warn("No target for invoking, did you forget to implement OnInvoke for signal " .. self.Name .. "?")

end


function SignalMethods:Wait()
	
	assert(self.Active, "Signal is no longer active.")

	local thread = coroutine.running()
	table.insert(self.ThreadList, thread)

	return coroutine.yield()

end


function SignalMethods:Destroy()
	
	assert(self.Active, "Signal is no longer active.")
	
	self:Disconnect()
	self._trove:CleanUp()
	self.Active = false
	
	if self.Network then
		
		self.Network[self.ID] = nil
		
		if IsServer and self.Params.Replicate then
			
			local target = self.Network.ConnectedClient
			if type(target) == "table" and #target > 0 then
				self.Network:__AddQueue('', {Target = target}, {self.ID})
			end
			
		end
		
		self.Network = nil
		
	end

end

--// Network Methods


NetworkPrototype.newSignalParams = Signal.newParams


function NetworkPrototype:CreateSignal(eventName: string, params : signalParams?, eventID: number?): customSignal
	
	assert(self.Active, "This network is no longer active.")
	assert(typeof(eventName) == "string", "First argument provided must be string.")
	assert(self.SignalIDCount < 16777217, "Signal limit is 16777216 signals.")

	if self.Events[eventName] then
		warn("Event " .. eventName .. " already exist, returning the existing signal...")
		return self.Events[eventName]
	end

	self.SignalIDCount += 1

	local newSignal = Signal.new(eventID or self.SignalIDCount, eventName, params)
	newSignal.Network = self

	newSignal._trove:Set(self.SignalArray, newSignal.ID, newSignal.SignalInfo)
	newSignal._trove:Set(self.Events, eventName, newSignal)

	self._internalEvent:Fire()

	if IsServer and newSignal.Params.Replicate then
		
		local target = self.ConnectedClient
		
		if type(target) == "table" and #target > 0 then
			self:__AddQueue('', {Target = target}, {newSignal.SignalInfo})
		end
		
	end

	return newSignal

end


function NetworkPrototype:GetSignal(eventName: string): customSignal?
	assert(self.Active, "This network is no longer active.")
	return self.Events[eventName]
end


function NetworkPrototype:GetSignalFromID(signalID: number): customSignal?
	
	assert(self.Active, "This network is no longer active.")
	assert(signalID, "The ID provided must be a number.")

	local signalInfo = self.SignalArray[signalID]

	if signalInfo then
		return self.Events[signalInfo.EventName]
	end

	return warn("Unable to find signal from id " .. signalID)

end


function NetworkPrototype:WaitForSignal(eventName: string): customSignal
	
	assert(self.Active, "This network is no longer active.")

	local tbl = self.Events
	if tbl[eventName] then return tbl[eventName] end

	repeat
		self._internalEvent.Event:Wait()
	until tbl[eventName]

	return tbl[eventName]

end


function NetworkPrototype:WaitForSignalWithID(signalID: number): customSignal
	
	assert(self.Active, "This network is no longer active.")

	local signalInfo = self.SignalArray[signalID]

	if signalInfo then return self.Events[signalInfo.EventName] end

	repeat
		self._internalEvent.Event:Wait()
	until self.SignalArray[signalID]

	return self.Events[self.SignalArray[signalID].EventName]

end


function NetworkPrototype:ConnectSignal(eventName: string, func: func)
	
	assert(self.Active, "This network is no longer active.")
	assert(self.Events[eventName], "Event " .. tostring(eventName) .. " doesn't exist.")
	
	return self.Events[eventName]:Connect(func)
	
end


function NetworkPrototype:DisconnectSignal(eventName: string)
	
	assert(self.Active, "This network is no longer active.")
	assert(self.Events[eventName], "Event " .. tostring(eventName) .. " doesn't exist.")
	
	self.Events[eventName]:Disconnect()
	
end


function NetworkPrototype:DeleteSignal(eventName: string)
	
	assert(self.Active, "This network is no longer active.")
	assert(self.Events[eventName], "Event " .. tostring(eventName) .. " doesn't exist.")
	
	self.Events[eventName]:Destroy()
	
end


function NetworkPrototype:FireSignal(eventName: string, property: signalProperty, ...: unknown)
	
	assert(self.Active, "This network is no longer active.")
	assert(self.Events[eventName], "Event " .. tostring(eventName) .. " doesn't exist.")
	
	return self.Events[eventName]:Fire(property, ...)
	
end


function NetworkPrototype:InvokeSignal(eventName: string, property: signalProperty, ...: unknown)
	
	assert(self.Active, "This network is no longer active.")
	assert(self.Events[eventName], "Event " .. tostring(eventName) .. " doesn't exist.")
	
	return self.Events[eventName]:Invoke(property, ...)
	
end


function NetworkPrototype:Destroy()
	
	assert(self.Active, "This network is no longer active.")
	
	NetworkList[self.Name] = nil
	self._trove:CleanUp()
	
end


function NetworkPrototype:Init(): network
	
	assert(self.Active, "This network is no longer active.")
	
	if self.__Init == true then return self, warn("Network already initialised.") end
	
	self:__SetConnection()

	assert(typeof(self.__Init) == "Instance" and self.__Init:IsA("BindableEvent"), "Invalid initializing variable")

	self.__Init:Fire()
	self.__Init = true

	return self

end


--// Trove Methods

function TroveMethods:Add(item: Instance): Instance

	assert(typeof(item) == "Instance", "First argument provided must be an instance.")

	self.Instances[item] = true

	return item

end


function TroveMethods:Set(tbl: {[unknown]: unknown}, key: unknown, value: unknown)

	assert(type(tbl) == "table", "First argument provided must be a table.")
	assert(key ~= nil, "Second argument (key) must be provided for table.")

	if value then

		if not self.Keys[key] then self.Keys[key] = {} end
		table.insert(self.Keys[key], tbl)

		tbl[key] = value

	end

end


function TroveMethods:Insert(tbl: {unknown}, value: unknown)

	assert(type(tbl) == "table", "First argument provided must be a table.")

	local key = #tbl

	if value then

		if not self.Keys[key] then self.Keys[key] = {} end
		table.insert(self.Keys[key], tbl)

		tbl[key] = value

	end

end


function TroveMethods:Connect(key: string | RBXScriptSignal, event: RBXScriptSignal | func, func: func?): RBXScriptConnection

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


function TroveMethods:CleanUp()

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