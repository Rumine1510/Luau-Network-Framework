--!strict

type tbl = {}

local EventTable = {}
local EventTableList = {}
setmetatable(EventTableList, {__mode = "kv"})

local function tostringTable(tbl, indent: number?): string

	local str = next(tbl) == nil and "{" or "{\n"
	local indentStr = string.rep(" ", indent or 2)
	
	for k,v in tbl do

		if type(k) == "string" then
			str ..= indentStr .. "[\"".. tostring(k) .. "\"] = "
		else
			str ..= indentStr .. "  [" .. tostring(k) .. "] = "
		end

		if type(v) == "table" then
			str ..= tostringTable(v, indent and indent + 2 or 4) .. ",\n"
		else
			str ..= tostring(v) .. ",\n"
		end

	end

	return str .. "}"

end

function EventTable.new(func: ({any}, any, any) -> (...any), tbl: tbl | any): eventTable

	local MainTable = tbl or {} :: tbl
	local ViewTable = {}
	
	for k,v in MainTable do
		
		if type(v) == "table" and not EventTableList[v] then
			
			assert(getmetatable(v) == nil, "metatables are not supported in values.")

			MainTable[k] = EventTable.new(function(keys, oldValue, newValue) 
				table.insert(keys, k)
				func(keys, oldValue, newValue)
			end, v)
			
		end
		
	end

	ViewTable.__index = MainTable
	ViewTable.__newindex = function(t,k,v)

		if MainTable[k] == v then return end
		assert(type(k) ~= "table", "Tables are not supported as a key.")
		
		if type(v) == "table" and not EventTableList[v] then
			
			assert(getmetatable(v) == nil, "metatables are not supported in values.")
			
			v = EventTable.new(function(keys, oldValue, newValue) 
				table.insert(keys, k)
				func(keys, oldValue, newValue)
			end, v)

		end

		local OldValue = MainTable[k]
		MainTable[k] = v

		func({k}, OldValue, v)

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
	
	ViewTable.__metatable = "Locked"

	setmetatable(ViewTable,ViewTable)

	EventTableList[ViewTable] = MainTable

	return ViewTable

end


function EventTable.GetMainTable(viewtable: eventTable)
	
	local mainTable = EventTableList[viewtable]
	assert(mainTable, "Invalid argument provided: First argument is not eventTable.")
	
	local copy = {}

	for k,v in mainTable do
		copy[k] = type(v) == "table" and EventTable.GetMainTable(v) or v
	end

	return copy
	
end


export type eventTable = typeof(EventTable.new(print))

return EventTable