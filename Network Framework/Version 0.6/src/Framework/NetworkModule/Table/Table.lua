--!strict

local EventTable = {}

local function tostringTable(tbl): string
	
	local str = "{\n"
	
	for k,v in tbl do

		if typeof(k) == "table" then
			str = str .. tostringTable(k) .. " = "
		else
			str = str .. "[" .. tostring(k) .. "] = "
		end
		
		if typeof(v) == "table" then 
			str = str .. tostringTable(v) .. ",\n"
		else
			str = str .. tostring(v) .. ",\n"
		end
		
	end
	
	return str .. "}"
	
end

function EventTable.new(func: (...any) -> (...any)): eventTable

	local MainTable = {}
	local ViewTable = {}

	ViewTable.__index = MainTable
	ViewTable.__newindex = function(t,k,v)

		if MainTable[k] == v then return end

		local OldValue = MainTable[k]
		MainTable[k] = v

		if func then
			func(k, OldValue, v)
		end

	end

	ViewTable.__iter = function()
		return next, MainTable
	end

	ViewTable.__len = function()
		return #MainTable
	end

	ViewTable.__tostring = function()
		return tostringTable(MainTable)
	end


	setmetatable(ViewTable,ViewTable)

	return ViewTable

end

export type eventTable = typeof(EventTable.new(print))

return EventTable