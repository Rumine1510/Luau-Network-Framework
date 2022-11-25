--!strict

--// Services \\--

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

--// Requiring Modules \\--

local Connection = require(script.Connection)
local Trove = require(script.Parent.Trove)


--// Types \\--

type customConnection = Connection.customConnection
type func = (...any) -> (...any)

type trove = Trove.trove

--// Variables \\--

local IsServer = RunService:IsServer()

--// Tables

local weakMeta = {
	__mode = "k"
}

local lockMeta = {
	__newindex = function() end,
	__metatable = "Locked"
}

local SignalParamsList = {} :: {[signalParams]: true}
local SignalPropertyList = {} :: {[signalProperty]: true}

setmetatable(SignalParamsList, weakMeta)
setmetatable(SignalPropertyList, weakMeta)

--// Main Module \\--

local Signal = {}
local SignalMethods = {}

local SignalMeta = {

	__index = SignalMethods,
	__newindex = function(t,k,v) if k == "OnInvoke" then rawset(t,k,v) end end,
	__metatable = "Locked"

}


--// Private Functions \\--


local function waitForChildOfClass(instance: Instance, className: string, timeOut: number?): Instance

	local target = instance:FindFirstChildOfClass(className)
	if target then return target end

	if timeOut then
		
		local thread = coroutine.running()

		local connection = instance.ChildAdded:Connect(function(child)
			if child.ClassName == className then
				task.spawn(thread, child)
			end
		end)

		task.delay(timeOut, thread)
		
		return coroutine.yield()

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
	assert(id < 65537, "Integer provided can't be larger than 2^16")

	id -= 1

	if id == -1 then
		return ''
	elseif id < 256 then

		return string.char(id)

	else

		local n = math.floor(id/256)
		local m = id%256

		return string.char(n) .. string.char(m)

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


function Signal.new(signalID: number, signalName: string?, signalProperty: signalProperty?): customSignal
	
	assert(signalProperty == nil or SignalPropertyList[signalProperty], "Invalid SignalProperty.")

	local Identifier = signalName or HttpService:GenerateGUID()

	local newSignal = {}

	newSignal.Network = false :: any
	newSignal.Name = Identifier :: string
	newSignal.ID = signalID :: number
	newSignal.Key = generateSignalID(signalID) :: string
	newSignal.Property = signalProperty or Signal.newProperty() :: signalProperty

	newSignal.Connections = {} :: {(...any) -> (...any)}
	newSignal.ConnectionList = {} :: {customConnection}
	newSignal.ThreadList = {} :: {thread}

	newSignal.SignalInfo = {
		
		Signal = newSignal,
		ID = newSignal.ID,
		Key = newSignal.Key,
		EventName = newSignal.Name,
		Property = newSignal.Property

	} :: signalInfo

	newSignal.OnInvoke = nil :: func?
	newSignal.Active = true :: boolean
	
	newSignal.__Replicate = true :: boolean
	
	newSignal._trove = Trove.new() :: trove
	newSignal._trove.Parent = newSignal

	setmetatable(newSignal, SignalMeta)

	return newSignal

end


function Signal.newProperty(): signalProperty

	local signalProperty = {}
	signalProperty.Once = false :: boolean
	signalProperty.MainRemote = false :: RemoteEvent | false
	signalProperty.MainInvoke = false :: RemoteFunction | false

	lock(signalProperty)

	SignalPropertyList[signalProperty] = true

	return signalProperty

end


function Signal.newParams(): signalParams

	local newParams = {}
	newParams.Target = nil :: (Player | {Player} | "All")?
	newParams.Remote = nil :: RemoteEvent?

	--lock(newParams)

	SignalParamsList[newParams] = true

	return newParams

end


function Signal.__RegisterProperty(property: signalProperty): signalProperty
	SignalPropertyList[property] = true
	return property
end


--// Private Methods \\--

function SignalMethods.__Fired(self: customSignal, ...: any)

	for _, connection in self.Connections do
		task.spawn(connection, ...) 
	end

	for _, thread in self.ThreadList do
		task.spawn(thread, ...)
	end

	table.clear(self.ThreadList)

	if self.Property.Once then
		self:Destroy()
	end

end


--// Methods \\--


function SignalMethods.Connect(self: customSignal,  func: func): customConnection

	assert(type(self) == "table", "Expected ':' not '.' calling member function Connect")
	assert(self.Active, "Signal is no longer active.")
	assert(typeof(func) == "function", "First argument provided must be function.")

	local newConnection = Connection.new(func)
	newConnection.Signal = self

	table.insert(self.Connections, func)
	table.insert(self.ConnectionList, newConnection)

	return newConnection

end


function SignalMethods.Disconnect(self: customSignal)

	assert(self.Active, "Signal is no longer active.")

	for _, connection in self.ConnectionList do
		connection:Disconnect()
	end

	for _, thread in self.ThreadList do
		task.spawn(thread)
	end

end


function SignalMethods.Fire(self: customSignal, params: signalParams?, ...: any)
	
	assert(self.Active, "Signal is no longer active.")
	
	local signalParams, addArg
	
	if not params or not SignalParamsList[params] then
		signalParams = Signal.newParams()
		addArg = true
	else
		signalParams = params
	end
	
	if IsServer then

		if signalParams.Target then

			if type(signalParams.Target) == "table" then

				for _, player in signalParams.Target do
					assert(typeof(player) == "Instance" and player:IsA("Player"), "All value in Target must be a player.")
				end

			elseif signalParams.Target ~= "All" then
				
				assert(typeof(signalParams.Target) == "Instance" and signalParams.Target:IsA("Player"), "Target must be either a player, an array of player, or \"All\".")
				
			end

		else	

			signalParams.Target = "All"

		end

	end
	
	if self.Network and self.__Replicate then

		if IsServer then

			local target = self.Network.ConnectedClient
			if type(target) ~= "table" or #target == 0 then return end

		end
		
		local remote = self.Property.MainRemote
		
		if typeof(remote) == "Instance" and remote:IsA("RemoteEvent") then
			signalParams.Remote = remote
		end
		
		self.Network:__AddQueue(self.Key, signalParams, addArg and {params, ...} or {...})

	end
	
	if addArg then
		self:__Fired(params, ...)
	else
		self:__Fired(...)
	end
	
end


function SignalMethods.Invoke(self: customSignal, params: signalParams?, ...: any): unknown

	assert(self.Active, "Signal is no longer active.")
	
	local signalParams, addArg

	if not params or not SignalParamsList[params] then
		signalParams = Signal.newParams()
		addArg = true
	else
		signalParams = params
	end
	
	if self.OnInvoke then
		
		if addArg then
			return self.OnInvoke(params, ...)
		else
			return self.OnInvoke(...)
		end

	elseif self.Network then
		
		local remote = self.Property.MainInvoke

		if IsServer then

			assert(typeof(signalParams.Target) == "Instance" and signalParams.Target:IsA("Player"), "Target must be a player.")
			
			if typeof(remote) == "Instance" and remote:IsA("RemoteFunction") then
				
				if addArg then
					return remote:InvokeClient(signalParams.Target, params, ...)
				else
					return remote:InvokeClient(signalParams.Target, ...)
				end
				
			else
				
				if addArg then
					return self.Network.__MainInvoke:InvokeClient(signalParams.Target, params, self.Key, ...)
				else
					return self.Network.__MainInvoke:InvokeClient(signalParams.Target, self.Key, ...)
				end
				
			end

		else

			if typeof(remote) == "Instance" and remote:IsA("RemoteFunction") then
				
				if addArg then
					return remote:InvokeServer(params, ...)
				else
					return remote:InvokeServer(...)
				end
				
			else
				
				if addArg then
					return self.Network.__MainInvoke:InvokeServer(self.Key, params, ...)
				else
					return self.Network.__MainInvoke:InvokeServer(self.Key, ...)
				end
				
			end

		end

	end

	return warn("No target for invoking, did you forget to implement OnInvoke for signal " .. self.Name :: string .. "?")

end


function SignalMethods.Wait(self: customSignal)

	assert(self.Active, "Signal is no longer active.")

	local thread = coroutine.running()
	table.insert(self.ThreadList, thread)

	return coroutine.yield()

end


function SignalMethods.AddRemotes(self: customSignal, remote1: RemoteEvent | RemoteFunction, remote2: RemoteEvent | RemoteFunction)
	
end


function SignalMethods.Destroy(self: customSignal)

	if not self.Active then return warn("Signal is no longer active.") end

	self:Disconnect()
	self.Active = false

	if self.Network then

		if IsServer and self.__Replicate then

			local target = self.Network.ConnectedClient

			if type(target) == "table" and #target > 0 then
				
				self.Network:__AddQueue('', {Target = target}, {self.Key})
				
			end

		end

	end
	
	self._trove:CleanUp()

end


--// Return \\--

export type customSignal = typeof(Signal.new(0))
export type signalProperty = typeof(Signal.newProperty())
export type signalParams = typeof(Signal.newParams())
export type signalInfo = {Signal: customSignal, ID: number, Key: string, EventName: string, Property: signalProperty}

return Signal
