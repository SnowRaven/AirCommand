-- Air Command system by Arctic Fox --
-- aircraft package --
local class = require("Class")
---------------------------------------------------------------------------------------------------------------------------
--[[
	Package of multiple flights executing a primary missions
    Parameters:
    mission - primary package mission
    flights - list of flights assigned to the package
	aborted - true if package mission is aborted
]]--
local Package = class()

-- get closest distance from any flight in package
function Package:getDistance(x, y)
	local closestDistance
	for key, flight in pairs(self.flights) do
		if flight.group:isExist() ~= false then
			local flightDistance = flight:getClosestDistance(x, y)
			if closestDistance == nil or flightDistance < closestDistance then
				closestDistance = flightDistance
			end
		end
	end
	if closestDistance ~= nil then
		return closestDistance
    end
	return 0
end

function Package:addFlight(flight)
    table.insert(self.flights, flight)
end

-- loop for controlling flights in the package
function Package:controlFlights()
	local packageActive = false
	for key, flight in pairs(self.flights) do
		local flightActive = flight:control()
		if flightActive == false then
			self.flights[key] = nil
		else
			-- if we have one flight active, package is still active
			packageActive = true
		end
	end
	-- continue if package is still active
	if packageActive then
		timer.scheduleFunction(self.controlFlights, self, timer.getTime() + 20)
	end
end

function Package:abort()
	for key, flight in pairs(self.flights) do
		flight:ReturnToBase()
	end
	self.aborted = true
end

function Package:init(mission)
    self.mission = mission
    self.flights = {}
	self.aborted = false
	timer.scheduleFunction(self.controlFlights, self, timer.getTime() + 20)
end

return Package