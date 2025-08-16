-- Air Command system by Arctic Fox --
-- patrol zone --

local utils = require("Utils")
local class = require("Class")
local Orbit = require("Positions.Orbit")
local Zone = require ("Positions.Zone")
---------------------------------------------------------------------------------------------------------------------------
--[[
	Combat air patrol zone
	Parameters:
	x - X coordinate of the zone's center
	y - Z coordinate of the zone's center
	radius - zone radius around its center
	reference - point towards which patrols will be oriented
	airframes - table of allowed airframes (if nil all are allowed)
]]--
local PatrolZone = class(Zone)

-- return an orbit inside the zone oriented towards the reference point
function PatrolZone:getOrbit(length, center)
	if center == nil then
		center = self:getRandomPoint()
	end
	local points = {}
	points[1] = utils.getPointOnLine(center, self.reference, (length / 2))
	points[2] = utils.getPointOnLine(center, self.reference, -(length / 2))
	return Orbit:new(points)
end

-- return an orbit inside the zone oriented perpendicular to the reference point
function PatrolZone:getPerpendicularOrbit(length, center)
	if center == nil then
		center = self:getRandomPoint()
	end
	local points = utils.getPerpendicularPoints(center, self.reference, (length / 2))
	return Orbit:new(points)
end

function PatrolZone:init(zoneData)
    self.x = zoneData.x
    self.y = zoneData.y
    self.radius = zoneData.radius
	self.reference = {
		["x"] = zoneData.reference.x,
		["y"] = zoneData.reference.y
	}
	if zoneData.airframes ~= nil then
        self.airframes = {}
        for airframeID, value in pairs(zoneData.airframes) do
            self.airframes[airframeID] = value
        end
    end
end

return PatrolZone