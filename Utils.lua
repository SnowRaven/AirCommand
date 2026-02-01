-- Air Command system by Arctic Fox --
-- helpful functions --

---------------------------------------------------------------------------------------------------------------------------
-- get 2D magnitude from a velocity vector
local Utils = {}

-- get zone data from DCS mission marker
function Utils.getZoneData(markerName)
	local zone = trigger.misc.getZone(markerName)
	return {
		["x"] = zone.point.x,
		["y"] = zone.point.z,
		["radius"] = zone.radius
	}
end

-- get absolute velocity
function Utils.getVelocityMagnitude(vector)
	return math.sqrt((vector.x^2) + (vector.y^2))
end

-- get distance between two points using the power of Pythagoras
function Utils.getDistance(x1, y1, x2, y2)
	return math.sqrt(((x1 - x2) * (x1 - x2)) + ((y1 - y2) * (y1 - y2)))
end

-- get a point on a line between two points at a certain distance from the first point
-- if distance is nil get mid-way point
function Utils.getPointOnLine(a, b, distance)
	local distanceRatio
	if distance ~= nil then
		distanceRatio = Utils.getDistance(a.x, a.y, b.x, b.y) / distance
	else
		distanceRatio = 2
	end
	local x = a.x + ((b.x - a.x) / distanceRatio)
	local y = a.y + ((b.y - a.y) / distanceRatio)
	local point = {
		["x"] = x,
		["y"] = y
	}
	return point
end

-- get two points perpendicular to a line at a certain distance from point a
function Utils.getPerpendicularPoints(a, b, distance)
	local angle = math.atan2(b.y - a.y, b.x - a.x)
	local points = {}
	points[1] = {
		["x"] = a.x + (math.cos(angle + (math.pi / 2)) * distance),
		["y"] = a.y + (math.sin(angle + (math.pi / 2)) * distance)
	}
	points[2] = {
		["x"] = a.x + (math.cos(angle - (math.pi / 2)) * distance),
		["y"] = a.y + (math.sin(angle - (math.pi / 2)) * distance)
	}
	return points
end


-- get two points a certain distance abeam an object with a given heading
function Utils.getBeamPoints(position, heading, distance)
	local p1 = {
		["x"] = position.x + (math.cos(heading + (math.pi / 2)) * distance),
		["y"] = position.y + (math.sin(heading + (math.pi / 2)) * distance)
	}
	local p2 = {
		["x"] = position.x + (math.cos(heading - (math.pi / 2)) * distance),
		["y"] = position.y + (math.sin(heading - (math.pi / 2)) * distance)
	}
	return {p1, p2}
end

-- get a point directly behind an object at a given distance
function Utils.getSternPoint(position, heading, distance)
	local point = {
		["x"] = position.x + (math.cos(-heading) * distance),
		["y"] = position.y + (math.sin(-heading) * distance)
	}
	return point
end

-- get absolute angle from a position and heading to a point
function Utils.getAbsoluteAngle(position, point)
	local angle = math.atan2(point.y - position.y, point.x - position.x)
	return angle
end

-- get aspect angle from a position and heading to a point
function Utils.getAspectAngle(heading, position, point)
	local angle = math.atan2(point.y - position.y, point.x - position.x)
	return (angle - heading)
end

-- get the size of a given table
function Utils.getTableSize(table)
	local size = 0
	for key in pairs(table) do
		size = size + 1
	end
	return size
end

-- get a randomized skill level from a given baseline
-- TODO: replace with percentage-based tables that can be defined per squadron
function Utils.getSkill(baseline)
	local adjustment = math.random(10)
	if baseline == "Average" then
		if adjustment > 6 then
			return "Good"
		end
		return "Average"
	elseif baseline == "Good" then
		if adjustment <= 2 then
			return "Average"
		elseif adjustment > 6 then
			return "Good"
		end
		return "Good"
	elseif baseline == "High" then
		if adjustment <= 2 then
			return "Good"
		elseif adjustment > 6 then
			return "Excellent"
		end
		return "High"
	elseif baseline == "Excellent" then
		if adjustment < 5 then
			return "High"
		end
		return "Excellent"
	end
	-- I dunno what's going on if we get here
	return "High"
end

-- see if any player is within a certain distance in meters to a point
function Utils.playerInRange(distance, x, y)
	for key, sideIndex in pairs(coalition.side) do
		for key, player in pairs(coalition.getPlayers(sideIndex)) do
			if Utils.getDistance(player:getPoint().x, player:getPoint().z, x, y) < distance then
				return true
			end
		end
	end
	return false
end

-- function to sort by distance to a location
function Utils.sortByDistance(first, second)
	if first.distance < second.distance then
		return true
	else
		return false
	end
end

-- get altitude above ground of an object
function Utils.getAGL(object)
	local objectPosition = object:getPoint()
	local position = {
		x = objectPosition.x,
		y = objectPosition.z
	}
	local height = objectPosition.y - land.getHeight(position)
	-- I don't know if it's possible but just in case
	if height < 0 then
		return 0
	else
		return height
	end
end

-- get number of  players on mission or coalition
function Utils.getPlayerNumber(coalition)
	local players = 0
	if coalition ~= nil then
		for key, unit in pairs(coalition.getPlayers(coalition)) do
			players = players + 1
		end
	else
		for coalition, coalitionID in pairs(coalition.side) do
			for key, unit in pairs(coalition.getPlayers(coalitionID)) do
				players = players + 1
			end
		end
	end
	return players
end

-- generate random STN
function Utils.randomSTN()
	local stn = ""
	for i = 1, 5 do
		local number = math.random(0, 7)
		stn = stn .. tostring(number)
	end
	return stn
end

return Utils