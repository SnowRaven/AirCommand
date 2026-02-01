-- Air Command system by Arctic Fox --
-- air tasking and interception system --

local utils = require("Utils")
local defs = require("Defs")
local class = require("Class")
local Orbit = require("Positions.Orbit")
local Zone = require("Positions.Zone")
local PatrolZone = require("Positions.PatrolZone")
local SquadronAirbase = require("Airbase.SquadronAirbase")
local Package = require("Flights.Package")
local Flight = require("Flights.Flight")
local Intercept = require("Missions.Intercept")
local QRA = require("Missions.QRA")
local CAP = require("Missions.CAP")
local AMBUSHCAP = require("Missions.AMBUSHCAP")
local Escort = require("Missions.Escort")
local HAVCAP = require("Missions.HAVCAP")
local Tanker = require("Missions.Tanker")
local AEW = require("Missions.AEW")
---------------------------------------------------------------------------------------------------------------------------
--[[
	System handling package and flight tasking and dispatch
	Parameters:
	side - current coalition
	airbases - list of airbases
	packages - list of currently active packages
	orbits - list of available support orbits
	patrolZones - list of available patrol zones
	ADZExclusion - list of air defence exclusion zones
]]--
local AirTaskingOrder = class()

function AirTaskingOrder:addAirbase(airbaseData)
	local airbase = SquadronAirbase:new(airbaseData.name, airbaseData.takeoffHeading)
	-- create squadrons if data exists
	if airbaseData.squadrons ~= nil then
		for key, squadronData in pairs(airbaseData.squadrons) do
			airbase:addSquadron(squadronData)
		end
	end
	table.insert(self.airbases, airbase)
end

function AirTaskingOrder:addPatrolZone(zoneData)
	local zone = PatrolZone:new(zoneData)
	table.insert(self.patrolZones, zone)
end

function AirTaskingOrder:addADZExclusion(zoneData)
	local zone = Zone:new(zoneData)
	table.insert(self.ADZExclusion, zone)
end

function AirTaskingOrder:addOrbit(orbitData)
	local orbit = Orbit:new(orbitData)
	table.insert(self.orbits, orbit)
end

-- get modified intercept range between a minimum and maximum based on track quality between 0 and 1
function AirTaskingOrder:getInterceptRange(minRange, maxRange, trackQuality)
	-- if maximum range is lower than minimum for some reason, return it unmodified
	if maxRange < minRange then
		return maxRange
	end
	local range = minRange + ((maxRange - minRange) * trackQuality)
	return range
end

function AirTaskingOrder:launchSortie(airbase, squadron, mission)
	local flightSize = squadron.baseFlightSize -- how many airframes we want to launch
	-- random chance for more aircraft
	for i = flightSize + 1, squadron.maxFlightSize do
		local rand = math.random(10)
		if rand > 9 then
			flightSize = flightSize + 1
		end
	end
	-- launch the flight
	-- force ground start for non-intercepts
	local groundStart = true
	if mission.type == defs.missionType.Intercept or mission.type == defs.missionType.QRA then
		groundStart = false
	end
	local flight = Flight:launch(airbase, squadron, mission, flightSize, groundStart)
	if flight ~= nil then
		-- assign aircraft parameters
		flight:setParameters(self.aircraftParameters[flight:getCategory()])
		-- set airfield readiness time for next intercept
		if mission.type == defs.missionType.Intercept or mission.type == defs.missionType.QRA then
			airbase:setPreparation(self.parameters.preparationTime)
		end
		-- return flight
		return flight
	else
		-- if our flight didn't launch for whatever reason, mark airfield skip so next time we'll try again from a different one
		airbase:skip(defs.skipResetTime)
		return nil
	end
end

-- return a random squadron for intercept mission
function AirTaskingOrder:selectInterceptorSquadron(track)
	local trackPosition = track:getPosition()
	local availableAirbases = {}
	for key, airbase in pairs(self.airbases) do
		if airbase:isActive(self.side) and timer.getTime() > airbase.readiness then
			local airbaseLocation = airbase:getLocation()
			local airbaseData = {
				["airbase"] = airbase,
				["distance"] = utils.getDistance(trackPosition.x, trackPosition.y, airbaseLocation.x, airbaseLocation.y)
			}
			table.insert(availableAirbases, airbaseData)
		end
	end
	table.sort(availableAirbases, utils.sortByDistance)
	-- find an applicable squadron, randomizing from the closest airbases in order
	for key, airbaseData in ipairs(availableAirbases) do
		local airbase = airbaseData.airbase
		local airbaseLocation = airbase:getLocation()
		local interceptSquadrons = {}
		-- add up all the squadrons in the airbase and select a random one
		for key, squadron in pairs(airbase.squadrons) do
			local missionCapable
			if squadron.missions[defs.missionType.Intercept] == true or (squadron.missions[defs.missionType.QRA] == true and airbaseData.distance < self.parameters.QRARadius) then
				missionCapable = true
			end
			if missionCapable and squadron.targetCategories[track.category] then
				if utils.getDistance(trackPosition.x, trackPosition.y, airbaseLocation.x, airbaseLocation.y) < self:getInterceptRange(self.parameters.minScrambleRange, squadron.interceptRadius, track:getQuality()) then
					-- select squadron if appropriate for track threat type
					local threatAllowed
					for threatType, value in pairs(track.threatTypes) do
						if value == true and squadron.threatTypes[threatType] == true then
							threatAllowed = true
						end
					end
					if threatAllowed then
						table.insert(interceptSquadrons, squadron)
					end
				end
			end
		end
		if utils.getTableSize(interceptSquadrons) > 0 then
			local squadron = interceptSquadrons[math.random(utils.getTableSize(interceptSquadrons))]
			local squadronData = {
				["airbase"] = airbase,
				["squadron"] = squadron
			}
			return squadronData
		end
	end
	return nil
end

-- return a random squadron for a given mission
function AirTaskingOrder:selectSquadron(missionType, allowedTypes)
	-- TODO: Sort by closest
	local availableSquadrons = {}
	for key, airbase in pairs(self.airbases) do
		if airbase:isActive(self.side) ~= false then
			for key, squadron in pairs(airbase.squadrons) do
				if squadron.missions[missionType] == true then
					if allowedTypes == nil or allowedTypes[squadron.type] == true then
						local squadronData = {
							["airbase"] = airbase,
							["squadron"] = squadron
						}
						table.insert(availableSquadrons, squadronData)
					end
				end
			end
		end
	end
	local squadronCount = utils.getTableSize(availableSquadrons)
	if squadronCount > 0 then
		-- return a table containing the airbase and squadron to be used
		return availableSquadrons[math.random(utils.getTableSize(availableSquadrons))]
	else
		return nil
	end
end

-- launch escort flight
function AirTaskingOrder:escortMission(escortTarget, package, isHAVCAP)
	-- select regular escort or HAVCAP
	local missionType = defs.missionType.Escort
	if isHAVCAP then
		missionType = defs.missionType.HAVCAP
	end
	-- select a random squadron to provide escort
	local squadronData = self:selectSquadron(missionType)
	if squadronData ~= nil then
		local airbase = squadronData.airbase
		local squadron = squadronData.squadron
		local mission
		if missionType == defs.missionType.Escort then
			mission = Escort:new(escortTarget)
		else
			mission = HAVCAP:new(escortTarget)
		end
		local flight = self:launchSortie(airbase, squadron, mission)
		if flight ~= nil then
			package:addFlight(flight)
		end
	end
end

-- tanker or C2 mission
function AirTaskingOrder:supportMission(missionType)
	-- find all unoccupied orbits available and pick one at random
	local openOrbits = {}
	for key, orbit in pairs(self.orbits) do
		local assigned = false
		for key, package in pairs(self.packages) do
			if package.aborted ~= true and package.mission.orbit == orbit then
				assigned = true
			end
		end
		if assigned == false then
			-- pick compatible squadron to dispatch if this orbit is selected
			local squadronData = self:selectSquadron(missionType, orbit.airframes)
			if squadronData ~= nil then
				local orbitData = {
					["orbit"] = orbit,
					["squadronData"] = squadronData
				}
				table.insert(openOrbits, orbitData)
			end
		end
	end
	if utils.getTableSize(openOrbits) > 0 then
		-- select orbit to dispatch mission to
		local orbitData = openOrbits[math.random(utils.getTableSize(openOrbits))]
		-- create mission
		local mission
		if missionType == defs.missionType.Tanker then
			mission = Tanker:new(orbitData.orbit)
		elseif missionType == defs.missionType.AEW then
			mission = AEW:new(orbitData.orbit)
		end
		-- launch support flight
		local flight = self:launchSortie(orbitData.squadronData.airbase, orbitData.squadronData.squadron, mission)
		-- create package
		if flight ~= nil then
			local package = Package:new(mission)
			package:addFlight(flight)
			table.insert(self.packages, package)
		end
	end
end

function AirTaskingOrder:patrolMission(missionType)
	local orbit
	-- select CAP type and zone
	local zone = self.patrolZones[math.random(utils.getTableSize(self.patrolZones))]
	-- build patrol track points
	-- regular CAP faces the reference point, AMBUSHCAP runs perpendicular
	if missionType ~= defs.missionType.AMBUSHCAP then
		orbit = zone:getOrbit(self.parameters.CAPTrackLength)
	else
		orbit = zone:getPerpendicularOrbit(self.parameters.CAPTrackLength)
	end
	-- pick random squadron to dispatch
	local squadronData = self:selectSquadron(missionType, zone.airframes)
	if squadronData ~= nil then
		-- create mission
		local mission
		if missionType == defs.missionType.CAP then
			mission = CAP:new(orbit)
		elseif missionType == defs.missionType.AMBUSHCAP then
			mission = AMBUSHCAP:new(orbit)
		end
		-- launch flight
		local flight = self:launchSortie(squadronData.airbase, squadronData.squadron, mission)
		-- create package
		if flight ~= nil then
			local package = Package:new(mission)
			package:addFlight(flight)
			table.insert(self.packages, package)
		end
	end
end

function AirTaskingOrder:strikeMission(target)
	local squadronData = self:selectInterceptorSquadron(target)
	if squadronData ~= nil then
		-- decide regular intercept or QRA based on distance
		local mission
		local airbaseLocation = squadronData.airbase:getLocation()
		local distance = utils.getDistance(target.x, target.y, airbaseLocation.x, airbaseLocation.y)
		if distance > self.parameters.QRARadius then
			mission = Intercept:new(target)
		else
			mission = QRA:new(target)
		end
		-- launch flight
		local flight = self:launchSortie(squadronData.airbase, squadronData.squadron, mission)
		-- create package
		if flight ~= nil then
			local package = Package:new(mission)
			package:addFlight(flight)
			table.insert(self.packages, package)
		end
	end
end

function AirTaskingOrder:interceptMission(target)
	local squadronData = self:selectInterceptorSquadron(target)
	if squadronData ~= nil then
		-- decide regular intercept or QRA based on distance
		local mission
		local airbaseLocation = squadronData.airbase:getLocation()
		local distance = utils.getDistance(target.x, target.y, airbaseLocation.x, airbaseLocation.y)
		if distance > self.parameters.QRARadius then
			mission = Intercept:new(target)
		else
			mission = QRA:new(target)
		end
		-- launch flight
		local flight = self:launchSortie(squadronData.airbase, squadronData.squadron, mission)
		-- create package
		if flight ~= nil then
			local package = Package:new(mission)
			package:addFlight(flight)
			table.insert(self.packages, package)
		end
	end
end

-- loop for assigning command and control packages
function AirTaskingOrder:C2ATO()
	-- dispatch C2 missions
	if math.random(100) <= self.parameters.AEWChance then
		self:supportMission(defs.missionType.AEW)
	end

	timer.scheduleFunction(self.C2ATO, self, timer.getTime() + math.random(self.parameters.minPackageTime, self.parameters.maxPackageTime))
end

-- loop for assigning logistics packages
function AirTaskingOrder:logisticsATO()
	-- dispatch tanker missions
	if math.random(100) <= self.parameters.tankerChance then
		self:supportMission(defs.missionType.Tanker)
	end

	timer.scheduleFunction(self.logisticsATO, self, timer.getTime() + math.random(self.parameters.minPackageTime, self.parameters.maxPackageTime))
end

-- loop for assigning air patrol packages
function AirTaskingOrder:patrolATO()
	-- dispatch CAP missions
	if math.random(100) < self.parameters.CAPChance then
		if math.random(100) < self.parameters.AMBUSHChance then
			self:patrolMission(defs.missionType.AMBUSHCAP)
		else
			self:patrolMission(defs.missionType.CAP)
		end
	end

	timer.scheduleFunction(self.patrolATO, self, timer.getTime() + math.random(self.parameters.minPackageTime, self.parameters.maxPackageTime))
end

-- main loop for dispatching interceptors
function AirTaskingOrder:interceptATO()
	-- find unengaged targets and assign interceptors
	for key, track in pairs(self.trackingSystem.tracks) do
		-- check if track is in an ADZ exclusion zone or engaged by other interceptors
		local excluded = false
		local engaged = false
		for key, zone in pairs(self.ADZExclusion) do
			if zone:inZone(track.x, track.y) then
				excluded = true
				break
			end
		end
		for key, package in pairs(self.packages) do
			for key, flight in pairs(package.flights) do
				if flight.mission.targetTrack == track then
					engaged = true
					break
				end
			end
		end
		-- find any available escort or CAP flight for intercept before scrambling
		if excluded ~= true then
			for key, package in pairs(self.packages) do
				for key, flight in pairs(package.flights) do
					local flightTarget = flight.mission.targetTrack
					if flightTarget == nil then
						local flightAirborne =  flight:isAirborne()
						if flightAirborne and flight:allowedTargetCategory(track.category) then
							local targetRange
							local targetInRange = false
							if flight.mission.type == defs.missionType.Escort or flight.mission.type == defs.missionType.HAVCAP then
								targetRange = package:getDistance(track.x, track.y)
								if targetRange < self:getInterceptRange(flight.parameters.emergencyCommitRange, flight.parameters.escortCommitRange, track:getQuality()) then
									targetInRange = true
								end
							elseif flight.mission.type == defs.missionType.CAP then
								targetRange = flight:getClosestDistance(track.x, track.y)
								if targetRange < self:getInterceptRange(flight.parameters.emergencyCommitRange, flight.parameters.commitRange, track:getQuality()) then
									targetInRange = true
								end
							elseif flight.mission.type == defs.missionType.AMBUSHCAP then
								targetRange = flight:getClosestDistance(track.x, track.y)
								if targetRange < self:getInterceptRange(flight.parameters.emergencyCommitRange, flight.parameters.ambushCommitRange, track:getQuality()) then
									targetInRange = true
								end
							end
							if engaged ~= true and targetInRange then
								flight.mission.targetTrack = track
								flight:intercept()
								engaged = true
							-- if target is extremely close, intercept regardless of whether it's engaged already
							elseif targetRange ~= nil and targetRange < flight.parameters.emergencyCommitRange then
								flight.mission.targetTrack = track
								flight:intercept()
								engaged = true
							end
						end
					end
				end
			end
			-- if an existing flight isn't available, launch interceptors
			if engaged ~= true then
				self:interceptMission(track)
			end
		end
	end

	timer.scheduleFunction(self.interceptATO, self, timer.getTime() + 15)
end

-- retasks interceptors to a CAP near their location
function AirTaskingOrder:retaskInterceptors(flight)
	local lowestDistance
	local patrolZone
	for key, zone in pairs(self.patrolZones) do
		local distance = flight:getDistance(zone.x, zone.y)
		if lowestDistance == nil or distance < lowestDistance then
			lowestDistance = distance
			patrolZone = zone
		end
	end
	if patrolZone == nil then
		flight:ReturnToBase()
		return nil
	end
	local orbit = patrolZone:getOrbit(self.parameters.CAPTrackLength)
	return CAP:new(orbit)
end

-- TODO: Sort out this and the flight control function under package
-- loop for handling package behaviour
function AirTaskingOrder:handlePackages()
	for key, package in pairs(self.packages) do
		-- clean up package if there are no more flights in it
		if utils.getTableSize(package.flights) < 1 then
			self.packages[key] = nil
		else
			-- abort package if main flight is gone or refresh HAVCAP is needed
			local mainFlight
			local HAVCAPFlight = false
			for key, flight in pairs(package.flights) do
				if flight.group:isExist() ~= true then
					package.flights[key] = nil
				-- check if the primary flight exists
				else
					if flight.mission.type == package.mission.type then
						mainFlight = flight
					end
					-- check if the HAVCAP exists
					if flight.mission.type == defs.missionType.HAVCAP then
						HAVCAPFlight = true
					-- check if interceptors need to be retasked
					elseif flight.mission.type == defs.missionType.Intercept or flight.mission.type == defs.missionType.QRA then
						if flight.mission.targetTrack == nil then
							local mission = self:retaskInterceptors(flight)
							if mission ~= nil then
								flight.mission = mission
								package.mission = mission
								flight:assignMission()
							end
						end
					end
				end
			end
			-- if there's no primary flight, abort the package
			if mainFlight == nil then
				if package.aborted ~= true then
					package:abort()
				end
			-- if package requires HAVCAP but none is on station, launch new HAVCAP
			else
				local HAVCAPRequired = true
				if HAVCAPFlight == true then
					HAVCAPRequired = false
				elseif defs.HAVCAPRequired[package.mission.type] ~= true then
					HAVCAPRequired = false
				elseif package.mission.orbit ~= nil and package.mission.orbit.HAVCAP ~= true then
					HAVCAPRequired = false
				end
				if HAVCAPRequired then
					self:escortMission(mainFlight, package, true)
				end
			end
		end
	end

	timer.scheduleFunction(self.handlePackages, self, timer.getTime() + 30)
end

function AirTaskingOrder:activate(immediate)
	if immediate then
		self:logisticsATO()
		self:C2ATO()
	else
		timer.scheduleFunction(self.logisticsATO, self, timer.getTime() + math.random(self.parameters.minPackageTime, self.parameters.maxPackageTime))
		timer.scheduleFunction(self.C2ATO, self, timer.getTime() + math.random(self.parameters.minPackageTime, self.parameters.maxPackageTime))
	end
	timer.scheduleFunction(self.patrolATO, self, timer.getTime() + math.random(self.parameters.minPackageTime, self.parameters.maxPackageTime))
	timer.scheduleFunction(self.interceptATO, self, timer.getTime() + 15)
	timer.scheduleFunction(self.handlePackages, self, timer.getTime() + 30)
end

-- TODO: When initiating squadrons, check if any squadron is AMBUSHCAP capable - if not, disable the AMBUSHCAP check 
-- (otherwise CAP flights will be unintentionally reduced)
function AirTaskingOrder:init(side, parameters, aircraftParameters, trackingSystem)
	self.side = side
	self.parameters = parameters
	self.aircraftParameters = aircraftParameters
	self.trackingSystem = trackingSystem
	self.airbases = {}
	self.packages = {}
	self.orbits = {}
	self.patrolZones = {}
	self.ADZExclusion = {}
end

return AirTaskingOrder