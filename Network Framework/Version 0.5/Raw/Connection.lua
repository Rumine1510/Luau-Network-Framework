--!strict

--// Types \\--

type func = (...any) -> (...any)

--// Main Module \\--

local Connection = {}
local ConnectionMethods = {}

local ConnectionMeta = {

	__index = ConnectionMethods,
	__newindex = function() end,
	__metatable = "Locked"

}

--// Constructor \\--


function Connection.new(func: func): customConnection

	local newConnection = {}
	newConnection.Signal = false :: any
	newConnection.Connected = true :: boolean
	newConnection.Function = func :: func

	setmetatable(newConnection, ConnectionMeta)

	return newConnection

end


--// Methods \\--


function ConnectionMethods.Disconnect(self: customConnection)

	local tbl = self.Signal.Connections

	local index = table.find(tbl, self.Function)

	if index then
		
		table.remove(tbl, index)
		self.Connected = false

	else

		warn("Unable to find index for function")

	end

end


--// Return \\--


export type customConnection = typeof(Connection.new(function() end))

return Connection