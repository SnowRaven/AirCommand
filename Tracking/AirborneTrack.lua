-- Air Command system by Arctic Fox --
-- airborne track --

local utils = require("Utils")
local defs = require("Defs")
local class = require("Class")
---------------------------------------------------------------------------------------------------------------------------
--[[
	Track containing target data for airborne units in the tracking system
	Parameters:
	active - track is timed out or not
	merged - other track to be merged into
	category - target category
	threatType - list of threat types associated with this track
	x - X position
	y - Y/Z position
	alt - altitude
	heading - heading in radians
	velocity - velocity in m/s
	observations - amount of times the track has been detected, for track quality determination
	lastUpdate - time at which the track was last updated with target information
]]--
local AirborneTrack = class()

-- get current or future extrapolated track position
function AirborneTrack:getPosition(time)
	local distance
	if time == nil then
		distance = (timer.getTime() - self.lastUpdate) * self.velocity
	else
		distance = (timer.getTime() - self.lastUpdate + time) * self.velocity
	end
	local position = {
		x = self.x + (math.cos(self.heading) * distance),
		y = self.y + (math.sin(self.heading) * distance)
	}
	return position
end

-- returns the position for a lead intercept vector
function AirborneTrack:getInterceptVector(flight)
	local interceptPoint
	local interceptorPosition = flight:getPosition()
	local distance = utils.getDistance(interceptorPosition.x, interceptorPosition.y, self.x, self.y)
	local angle = utils.getAbsoluteAngle(self, interceptorPosition)
	local relativeVelocityVector = {
		x = self.velocity * math.cos(angle),
		y = self.velocity * math.sin(angle) -- actually Y but this is easier
	}
	local relativeVelocity = utils.getVelocityMagnitude(relativeVelocityVector) + flight:getSpeed()
	-- iterate to find a good approximation of the intercept point
	local time
	for i = 1, 2 do
		time = distance / relativeVelocity
		interceptPoint = self:getPosition(time)
		distance = utils.getDistance(interceptorPosition.x, interceptorPosition.y, interceptPoint.x, interceptPoint.y)
	end
	interceptPoint = self:getPosition(time)
	return interceptPoint
end

-- correlate target object to track
function AirborneTrack:correlate(target)
    if self.category ~= target:getDesc().category then
		return false
	end
	local distance = utils.getDistance(self.x, self.y, target:getPoint().x, target:getPoint().z)
	if distance < defs.trackCorrelationDistance then
		if math.abs(target:getPoint().y - self.alt) < defs.trackCorrelationAltitude then
			return true
		end
	end
	local targetPoint = {
		x = target:getPoint().x,
		y = target:getPoint().z
	}
	if math.abs(utils.getAspectAngle(self.heading, self, targetPoint)) < 0.785398 then
		local trackMotionPotential = (self.velocity * (timer.getTime() - self.lastUpdate)) * 1.5
		if distance < trackMotionPotential and math.abs(target:getPoint().y - self.alt) < defs.trackCorrelationAltitude then
			return true
		end
	end
	return false
end

function AirborneTrack:update(targets)
	-- find the maximum weight of any target in the list to later add to the observation counter
	local observationWeight = 0
    -- get average position of all correlated targets
    local newPosition = {
        x = 0,
        y = 0,
        alt = 0
    }
    local targetNumber = 0
    for target, weight in pairs(targets) do
		-- calculate average position of targets
        newPosition.x = newPosition.x + target:getPoint().x
        newPosition.y = newPosition.y + target:getPoint().z
        newPosition.alt = newPosition.alt + target:getPoint().y
        targetNumber = targetNumber + 1
		-- find the maximum observation weight
		if weight > observationWeight then
			observationWeight = weight
		end
    end
    newPosition.x = newPosition.x / targetNumber
    newPosition.y = newPosition.y / targetNumber
    newPosition.alt = newPosition.alt / targetNumber
    -- calculate target heading and velocity
    if self.x == nil or self.y == nil then
		-- if a track was just created we don't know velocity and heading
		self.velocity = 0
		self.heading = 0
	else
		-- calculate track velocity based on previous position data
		local distance = utils.getDistance(self.x, self.y, newPosition.x, newPosition.y)
		self.velocity = distance / (timer.getTime() - self.lastUpdate)
		self.heading = math.atan2(newPosition.y - self.y, newPosition.x - self.x)
	end
    -- update track position
	self.x = newPosition.x
	self.y = newPosition.y
	self.alt = newPosition.alt
	-- add the observation value listed or the maximum allowed if it exceeds it
	if observationWeight < defs.maxObservationWeight then
		self.observations = self.observations + observationWeight
	else
		self.observations = self.observations + defs.maxObservationWeight
	end
	-- check if our observation count is above the maximum and cap it if it is 
	if self.observations > defs.maxObservations then
		self.observations = defs.maxObservations
	end
	self.lastUpdate = timer.getTime()
end

-- set threat type
function AirborneTrack:setThreatType(type, value)
	if value == nil then
		self.threatTypes[type] = true
	else
		self.threatTypes[type] = value
	end
end

function AirborneTrack:merge(track)
	self.merged = track
end

-- reduce number of observations if one is missed
function AirborneTrack:missedObservation()
	self.observations = self.observations / defs.observationMissFactor
end

-- return track quality value between 0 and 1
function AirborneTrack:getQuality()
	local quality = (self.observations^2) / (self.observations^2 + (self.observations * 6) + 24)
	return quality
end

function AirborneTrack:timeout()
	self.active = false
end

function AirborneTrack:isActive()
	return self.active
end

function AirborneTrack:init(target, weight)
	self.active = true
	self.merged = nil
    self.category = target:getDesc().category
	self.threatTypes = {}
	self.observations = 0
    self:update({[target] = weight})
end

return AirborneTrack