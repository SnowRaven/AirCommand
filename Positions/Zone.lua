-- Air Command system by Arctic Fox --
-- zone --

local utils = require("Utils")
local class = require("Class")
---------------------------------------------------------------------------------------------------------------------------
--[[
	Circular zone
	Parameters:
	x - X coordinate of the zone's center
	y - Z coordinate of the zone's center
	radius - zone radius around its center
]]--
local Zone = class()

-- return a random point inside the zone
function Zone:getRandomPoint()
    local distance = math.sqrt(math.random()) * self.radius
	local angle = math.random() * (2 * math.pi)
	local x = self.x + (math.sin(angle) * distance)
	local y = self.y + (math.cos(angle) * distance)
	local point = {
		["x"] = x,
		["y"] = y
	}
	return point
end

-- check if a point is located inside the zone
function Zone:inZone(x, y)
    if utils.getDistance(self.x, self.y, x, y) < self.radius then
        return true
    end
    return false
end

function Zone:init(zoneData)
    self.x = zoneData.x
    self.y = zoneData.y
    self.radius = zoneData.radius
end

return Zone