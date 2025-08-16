-- Air Command system by Arctic Fox --

local class = require("Class")
local TrackingSystem = require("Tracking.TrackingSystem")
local AirTaskingOrder = require("AirTaskingOrder")
---------------------------------------------------------------------------------------------------------------------------
--[[
	Air tasking system handling target tracking, interception and package operations
]]--
local AirCommand = class()

-- add DCS event handler
function AirCommand:onEvent(event)
	-- add air defence tracking units when spawned
	if event.id == world.event.S_EVENT_BIRTH then
		if event.initiator:isExist() ~= false and event.initiator:getCategory() == Object.Category.UNIT then
			if event.initiator:getGroup():getCoalition() == self.side then
				self.trackingSystem:addTracker(event.initiator)
			end
		end
	end
end

function AirCommand:setParameters(parameters)
	for key, value in pairs(parameters) do
		self.parameters[key] = value
	end
end

function AirCommand:setAircraftParameters(aircraftParameters)
	for category, categoryParameters in pairs(aircraftParameters) do
		for key, value in pairs(categoryParameters) do
			if type(value) ~= "table" then
				self.aircraftParameters[category][key] = value
			else
				local aircraftType = key
				self.aircraftParameters[category][aircraftType] = {}
				for parameter, value in pairs(value) do
					self.aircraftParameters[category][aircraftType][parameter] = value
				end
			end
		end
	end
end

function AirCommand:setThreatTypes(threatTypes)
	for key, value in pairs(threatTypes) do
		self.threatTypes[key] = value
	end
end

function AirCommand:enableDebug()
	local debugName = "Neutral"
	if self.name ~= nil then
		debugName = self.name
	elseif self.side == 1 then
		debugName = "Red"
	elseif self.side == 2 then
		debugName = "Blue"
	end
	-- list tracks
	for key, track in pairs(self.trackingSystem.tracks) do
		local heading = math.deg(track.heading)
		if heading <= 0 then
			heading = heading + 360
		end
		env.info(debugName .. " Air Command: Track " .. key .. " position - X: " .. tostring(track.x) .. " - Z: " .. tostring(track.y) .. " - Altitude: " .. tostring(track.alt), 0)
		env.info(debugName .. " Air Command: Heading: " .. tostring(heading) .. " - Velocity: " .. tostring(track.velocity * 3.6) .. "km/h - Time since update: " .. tostring(timer.getTime() - track.lastUpdate), 0)
		env.info(debugName .. " Air Command: Category: " .. tostring(track.category), 0)
		for threatType, value in pairs(track.threatTypes) do
			env.info(debugName .. " Air Command: Threat Type: " .. tostring(threatType), 0)
		end
	end
	timer.scheduleFunction(AirCommand.enableDebug, self, timer.getTime() + 15)
end

function AirCommand:activate(OOB, orbits, patrolZones, ADZExclusion, immediate)
	self.trackingSystem = TrackingSystem:new(self.side, self.ADZExclusion, self.threatTypes)
	self.ATO = AirTaskingOrder:new(self.side, self.parameters, self.aircraftParameters, self.trackingSystem)
	for key, airbaseData in pairs(OOB) do
		self.ATO:addAirbase(airbaseData)
	end
	for key, orbitData in pairs(orbits) do
		self.ATO:addOrbit(orbitData)
	end
	for key, zoneData in pairs(patrolZones) do
		self.ATO:addPatrolZone(zoneData)
	end
	for key, zoneData in pairs(ADZExclusion) do
		self.ATO:addADZExclusion(zoneData)
	end
	world.addEventHandler(self)
	self.ATO:activate(immediate)
end

function AirCommand:init(side, name)
	self.side = side
	self.name = name -- specific name for debug purposes, if not defined coalition name will be used
	self.parameters = {
		["minPackageTime"] = 3600, -- minimum number of seconds before the package ATO reactivates
		["maxPackageTime"] = 7200,-- maximum number of seconds before the package ATO reactivates
		["preparationTime"] = 1800, -- time in seconds it takes to prepare the next interceptors from an airbase
		["tankerChance"] = 20, -- chance to launch a tanker mission
		["AEWChance"] = 20, -- chance to launch an AEW mission
		["CAPChance"] = 80, -- chance to launch a CAP mission
		["AMBUSHChance"] = 60, -- chance for a CAP tasking to be an AMBUSHCAP
		["QRARadius"] = 60000, -- radius in meters for emergency scramble
		["CAPTrackLength"] = 30000, -- length of CAP racetracks in meters
	}
	self.aircraftParameters = {
		[Unit.Category.AIRPLANE] = {
			["commitRange"] = 180000, -- radius in meters around which uncommitted fighters will intercept tracks
			["escortCommitRange"] = 60000, -- radius in meters around uncommitted escort units at which targets will be intercepted
			["ambushCommitRange"] = 90000, -- radius in meters around uncommitted escort units at which targets will be intercepted
			["emergencyCommitRange"] = 30000, -- radius in meters around a flight to emergency intercept a track regardless of whether it's targeted by others
			["bingoLevel"] = 0.25, -- fuel level (in fraction from full internal) for a flight to RTB
			["maxAltitude"] = 9144,
			["standardAltitude"] = 7620,
			["returnAltitude"] = 9144,
			["ambushAltitude"] = 183,
			["standardSpeed"] = 250,
			["ambushSpeed"] = 200
		},
		[Unit.Category.HELICOPTER] = {
			["commitRange"] = 30000, -- radius in meters around which uncommitted fighters will intercept tracks
			["escortCommitRange"] = 10000, -- radius in meters around uncommitted escort units at which targets will be intercepted
			["ambushCommitRange"] = 30000, -- radius in meters around uncommitted escort units at which targets will be intercepted
			["emergencyCommitRange"] = 5000, -- radius in meters around a flight to emergency intercept a track regardless of whether it's targeted by others
			["bingoLevel"] = 0.25, -- fuel level (in fraction from full internal) for a flight to RTB
			["maxAltitude"] = 150,
			["standardAltitude"] = 60,
			["returnAltitude"] = 60,
			["ambushAltitude"] = 30,
			["standardSpeed"] = 42,
			["ambushSpeed"] = 28
		},
	}
	self.threatTypes = {}
end

return AirCommand