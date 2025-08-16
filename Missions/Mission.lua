-- Air Command system by Arctic Fox --
-- package/flight mission --

local defs = require("Defs")
local class = require("Class")
---------------------------------------------------------------------------------------------------------------------------
--[[
	Base class for packages or flight mission data
	parameters:
	type - mission identifier
	flightOptions - DCS group controller options to be set for a flight on this mission
]]--
local Mission = class()

Mission.FlightOptions = {}

-- function returning mission class
function Mission:getCategory()
    return defs.missionCategory[self.type]
end

function Mission:assignFlightOptions(flight)
	local controller = flight:getController()
	for option, value in pairs(self.flightOptions) do
		controller:setOption(option, value)
	end
end

function Mission:assignTask(flight)
	self:assignFlightOptions(flight)
end

function Mission:init()
	self.flightOptions = {}
end

return Mission