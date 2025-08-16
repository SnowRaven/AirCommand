-- Air Command system by Arctic Fox --
-- squadron airbase --
local class = require("Class")
local Squadron = require("Airbase.Squadron")
---------------------------------------------------------------------------------------------------------------------------
--[[
	Airbase containing squadrons for use in the air tasking system
	Parameters:
    name - DCS airbase name
    object - DCS airbase object
    takeoffHeading - direction for air-started aircraft to start in in radians
    skip - flag indicating the airbase should be temporarily not used
	squadrons - list of active squadrons based at the airbase
	readiness - time after which the next set of interceptors will be ready
]]--
local SquadronAirbase = class()

function SquadronAirbase:addSquadron(squadronData)
    local squadron = Squadron:new(squadronData)
    table.insert(self.squadrons, squadron)
end

function SquadronAirbase:setPreparation(time)
    self.readiness = timer.getTime() + time
end

function SquadronAirbase:resetSkip()
    self.skip = false
end

function SquadronAirbase:skip(time)
    self.skip = true
    timer.scheduleFunction(SquadronAirbase.resetSkip, self, timer.getTime() + time)
end

function SquadronAirbase:getLocation()
    -- convert from DCS XYZ coordinates to 2D XY coordinates for ease of use
    local point = self.object:getPoint()
    local location = {
        ["x"] = point.x,
        ["y"] = point.z,
        ["alt"] = point.y
    }
    return location
end

-- function checking whether the airbase is not skipped, exists and belongs to the current coalition
function SquadronAirbase:isActive(side)
    if self.skip == true then
        return false
    end
    if self.object:isExist() ~= true then
        return false
    end
    if self.object:getCoalition() ~= side then
        return false
    end
    return true
end

function SquadronAirbase:init(name, takeoffHeading)
    self.name = name
    self.object = Airbase.getByName(self.name)
    self.takeoffHeading = takeoffHeading
    self.skip = false
    self.readiness = timer.getTime()
    self.squadrons = {}
end

return SquadronAirbase