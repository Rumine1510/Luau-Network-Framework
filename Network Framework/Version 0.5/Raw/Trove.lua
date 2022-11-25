--!strict

--// Main Module \\--

local Trove = {}
local TroveMethods = {}

local TroveMeta = {

	__index = TroveMethods,
	__newindex = function() end,
	__metatable = "Locked"

}

--// Types \\--

type func = (...any) -> (...any)

--// Constructor \\--


function Trove.new(): trove

	local newTrove = {}
	newTrove.Instances = {} :: {[Instance]: boolean}
	newTrove.ConnectionArray = {} :: {RBXScriptConnection}
	newTrove.KeyConnections = {} :: {[string]: RBXScriptConnection}
	newTrove.Keys = {} :: {[any]: {any}}
	
	newTrove.Parent = false :: any

	setmetatable(newTrove, TroveMeta)

	return newTrove

end


--// Methods


function TroveMethods.Add(self: trove, item: Instance)

	assert(typeof(item) == "Instance", "First argument provided must be an instance.")

	self.Instances[item] = true

	return item

end


function TroveMethods.Set(self: trove, tbl: any, key: any, value: any)
	
	if type(tbl) ~= "table" and typeof(tbl) ~= "Instance" then
		error("First argument provided must be a table")
	end
	
	assert(key ~= nil, "Second argument (key) must be provided for table.")
	
	if value then

		if not self.Keys[key] then self.Keys[key] = {} end
		table.insert(self.Keys[key], tbl)

	end
	
	tbl[key] = value

end


function TroveMethods.Insert(self: trove, tbl: {any}, value: any): number
	
	assert(type(tbl) == "table", "First argument provided must be a table.")
	
	local index = #tbl+1
	self:Set(tbl, index, value)
	
	return index
	
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
	
	if self.Parent then
		table.clear(self.Parent)
	end
	
end


--// Return \\--

export type trove = typeof(Trove.new())

return Trove
