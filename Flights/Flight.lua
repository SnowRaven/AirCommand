-- Air Command system by Arctic Fox --
-- flight--

local utils = require("Utils")
local defs = require("Defs")
local class = require("Class")
local RTB = require("Missions.RTB")
---------------------------------------------------------------------------------------------------------------------------
--[[
	Invidiual flight data
    Parameters:
    mission - flight mission
    group - DCS flight group
    home - home airbase for this flight
	parameters - flight parameters
	cleanupTime - time at which the flight will be cleaned up if not in the air
]]--
local Flight = class()

-- get controller for flight group
function Flight:getController()
	return self.group:getController()
end

-- get lowest fuel state in flight
function Flight:getFuelState()
	local fuelState
	for key, unit in pairs(self.group:getUnits()) do
		if fuelState == nil or unit:getFuel() < fuelState then
			fuelState = unit:getFuel()
		end
	end
	if fuelState ~= nil then
        return fuelState
	end
    return 1
end

-- get altitude of lowest element in flight
function Flight:getLowestAltitude()
	local lowestAltitude
	for key, unit in pairs(self.group:getUnits()) do
		if lowestAltitude == nil or unit:getPoint().y < lowestAltitude then
			lowestAltitude = unit:getPoint().y
		end
	end
	if lowestAltitude ~= nil then
		return lowestAltitude
    end
	return 0
end

-- get speed of the fastest member of a flight
function Flight:getSpeed()
	local highestSpeed
	for key, unit in pairs(self.group:getUnits()) do
		local unitSpeed = utils.getVelocityMagnitude(unit:getVelocity())
		if highestSpeed == nil or unitSpeed < highestSpeed then
			highestSpeed = unitSpeed
		end
	end
	if highestSpeed ~= nil then
		return highestSpeed
    end
	return 0
end

-- get distance from closest element in the flight
function Flight:getClosestDistance(x, y)
	local closestDistance
	for key, unit in pairs(self.group:getUnits()) do
		local unitDistance = utils.getDistance(unit:getPoint().x, unit:getPoint().z, x, y)
		if closestDistance == nil or unitDistance < closestDistance then
			closestDistance = unitDistance
		end
	end
	if closestDistance ~= nil then
		return closestDistance
    end
    return 0
end

-- get average flight distance from point
function Flight:getDistance(x, y)
	local flightElements = 0
	local distanceTotal = 0
	for key, unit in pairs(self.group:getUnits()) do
		flightElements = flightElements + 1
		distanceTotal = distanceTotal + utils.getDistance(unit:getPoint().x, unit:getPoint().z, x, y)
	end
	return (distanceTotal / flightElements)
end

-- get average flight position
function Flight:getPosition()
	local flightElements = 0
	local totalX = 0
	local totalY = 0
	for key, unit in pairs(self.group:getUnits()) do
		flightElements = flightElements + 1
		totalX = totalX + unit:getPoint().x
		totalY = totalY + unit:getPoint().z
	end
	local position = {
		["x"] = totalX / flightElements,
		["y"] = totalY / flightElements
	}
	return position
end

-- get aircraft type of a flight
-- since all members of a flight should be the same type, just get the type from one and return
function Flight:getType()
	return self.squadron.type
end

-- get flight category (fixed wing/helicopter)
function Flight:getCategory()
	local category = Unit.getDescByName(self:getType()).category
	return category
end

-- check if target category is allowed
function Flight:allowedTargetCategory(category)
	if self.squadron.targetCategories[category] == true then
		return true
	end
	return false
end

-- check if flight group exists
function Flight:isExist()
	return self.group:isExist()
end

-- check if entire group is airborne
function Flight:isAirborne()
	local flightAirborne = true
	if self:isExist() then
		for key, unit in pairs(self.group:getUnits()) do
			if unit:inAir() == false then
				flightAirborne = false
			end
		end
	else
		flightAirborne = false
	end
	return flightAirborne
end

-- return flight ID
function Flight:getID()
	return self.group:getID()
end

-- assign general flight parameters
function Flight:setParameters(parameters)
	for parameter, value in pairs(parameters) do
		if type(value) ~= "table" then
			self.parameters[parameter] = value
		end
		-- if special parameters exist for our specific aircraft type, override with them
		local type = self:getType()
		if parameters[type] ~= nil then
			for parameter, value in pairs(parameters[type]) do
				self.parameters[parameter] = value
			end
		end
	end
end

-- TODO: standardize magic numbers somewhere and figure out if they work for both planes and helicopters
-- decide which intercept target to employ on intercept
function Flight:decideTactic(range, aspectAngle)
	local tactic = self.tactic
	local flightCategory = self:getCategory()
	-- if we're really close just focus on engaging
	if range < 8000 or (flightCategory == Group.Category.HELICOPTER and range < 4000) then
		tactic = defs.interceptTactic.Lead
	-- turn in from beam or stern intercept
	elseif tactic == defs.interceptTactic.Beam and math.abs(aspectAngle) > 0.785398 and range < 60000 then
		tactic = defs.interceptTactic.Lead
	elseif tactic == defs.interceptTactic.Stern and math.abs(aspectAngle) > 2.79253 and range < 60000 then
		tactic = defs.interceptTactic.Lead
	-- decide which tactic to use
	elseif tactic == nil then
		if self.parameters.preferredTactic ~= nil then
			if math.random(10) < 8 then
				tactic = self.parameters.preferredTactic
			else
				if self.parameters.preferredTactic == defs.interceptTactic.Beam then
					if math.random(10) < 4 then
						tactic = defs.interceptTactic.LeadLow
					else
						tactic = defs.interceptTactic.Stern
					end
				elseif self.parameters.preferredTactic == defs.interceptTactic.Stern then
					if math.random(10) < 3 then
						tactic = defs.interceptTactic.LeadLow
					else
						tactic = defs.interceptTactic.Beam
					end
				else
					tactic = math.random(utils.getTableSize(defs.interceptTactic))
				end
			end
		else
			tactic = math.random(utils.getTableSize(defs.interceptTactic))
		end
	end
	-- stern converting on escort takes too long
	if self.mission.type == defs.missionType.Escort or self.mission.type == defs.missionType.HAVCAP then
		if tactic == defs.interceptTactic.Stern then
			tactic = defs.interceptTactic.Beam
		end
	-- stay low as AMBUSHCAP
	elseif self.mission.type == defs.missionType.AMBUSHCAP then
		if tactic == defs.interceptTactic.Lead or tactic == defs.interceptTactic.LeadHigh then
			tactic = defs.interceptTactic.LeadLow
		end
	end
	return tactic
end

-- control flight to intercept target track
function Flight:intercept()
	local targetTrack = self.mission.targetTrack
	-- if we no longer have a track to intercept, abort the intercept
	if targetTrack == nil or self:isExist() ~= true then
		return
	end
	local controller = self:getController()
	local flightCategory = self:getCategory()
	local flightPosition = self:getPosition()
	local flightAltitude = self:getLowestAltitude()
	local trackPosition = targetTrack:getPosition()
	local trackAlt = targetTrack.alt
	local trackHeading = targetTrack.heading
	local range = self:getClosestDistance(trackPosition.x, trackPosition.y)
	local aspectAngle = utils.getAspectAngle(trackHeading, trackPosition, flightPosition)
	-- decide tactic
	self.tactic = self:decideTactic(range, aspectAngle)
	-- check if we're trying to stern or beam convert or engage
	local convert = false
	if self.tactic == defs.interceptTactic.Stern or self.tactic == defs.interceptTactic.Beam then
		convert = true
	end
	local engaging = false
	-- check if expected target position is close enough to activate radar
	local targetInSearchRange = true
	if self.parameters.radarRange ~= nil and range > self.parameters.radarRange then
		targetInSearchRange = false
	end
	if targetInSearchRange and convert ~= true then
		controller:setOption(AI.Option.Air.id.RADAR_USING, AI.Option.Air.val.RADAR_USING.FOR_CONTINUOUS_SEARCH)
	else
		controller:setOption(AI.Option.Air.id.RADAR_USING, AI.Option.Air.val.RADAR_USING.NEVER)
	end
	-- check if target is detected by onboard sensors and update track
	-- we're doing this to prevent magic datalink intercepts
	local targets = controller:getDetectedTargets(Controller.Detection.RADAR, Controller.Detection.VISUAL, Controller.Detection.OPTIC, Controller.Detection.IRST)
	local targetDetected = false
	local correlatedTargets = {}
	for key, target in pairs(targets) do
		if target.object ~= nil and Object.getCategory(target.object) == Object.Category.UNIT and target.object:getCoalition() ~= self.group:getCoalition() then
			if targetTrack:correlate(target.object) then
				targetDetected = true
				table.insert(correlatedTargets, target.object)
			end
		end
	end
	if targetDetected then
		targetTrack:update(correlatedTargets)
		trackPosition = targetTrack:getPosition()
		trackAlt = targetTrack.alt
		trackHeading = targetTrack.heading
		range = self:getClosestDistance(trackPosition.x, trackPosition.y)
		aspectAngle = utils.getAspectAngle(trackHeading, trackPosition, flightPosition)
	-- special excepction in case the interceptors are really close but blind because of altitude difference and can't climb
	elseif range < 5000 and math.abs(trackAlt - self:getLowestAltitude()) > 5000 then
		targetDetected = true
	end
	-- if target detected and we're not beam or stern converting then engage
	local interceptTask
	if targetDetected and convert ~= true then
		controller:setOption(AI.Option.Air.id.ROE, AI.Option.Air.val.ROE.OPEN_FIRE_WEAPON_FREE)
		interceptTask = {
			["id"] = "ComboTask",
			["params"] = {
				["tasks"] = {
					[1] = {
						["id"] = 'EngageTargetsInZone',
						["params"] = {
							["point"] = {
								trackPosition.x,
								trackPosition.y
							},
							["zoneRadius"] = defs.trackCorrelationDistance,
							["targetTypes"] = { "Air" },
							["priority"] = 0
						}
					}
				}
			}
		}
		engaging = true
	else
		controller:setOption(AI.Option.Air.id.ROE, AI.Option.Air.val.ROE.RETURN_FIRE)
		interceptTask = {
			["id"] = "ComboTask",
			["params"] = {
				["tasks"] = {
				}
			}
		}
	end
	-- update current intercept path
	local interceptSpeed = 2000
	local path = targetTrack:getInterceptVector(self)
	path.alt = trackAlt
	local altType = "BARO"
	-- decide intercept vector based on self.tactic in use
	if convert then
		path.alt = trackAlt * 0.6
		-- if we're far enough away lead for beam points directly
		if range > 60000 or (flightCategory == Group.Category.HELICOPTER and range > 10000) then
			local beamDistance = 50000
			if flightCategory == Group.Category.HELICOPTER then
				beamDistance = 5000
			end
			local beamPoints = utils.getBeamPoints(path, trackHeading, beamDistance)
			if self:getDistance(beamPoints[1].x, beamPoints[1].y) < self:getDistance(beamPoints[2].x, beamPoints[2].y) then
				path.x = beamPoints[1].x
				path.y = beamPoints[1].y
			else
				path.x = beamPoints[2].x
				path.y = beamPoints[2].y
			end
		-- once we're close to the beam drive to stern conversion if needed
		elseif self.tactic == defs.interceptTactic.Stern and math.abs(aspectAngle) > 0.698132 then
			local sternDistance = 2500
			if flightCategory == Group.Category.HELICOPTER then
				sternDistance = 500
			end
			local sternPoint = utils.getSternPoint(trackPosition, trackHeading, sternDistance)
			path.x = sternPoint.x
			path.y = sternPoint.y
		-- if we're close and they're facing us notch to the beam or stern
		else
			local conversionPoints = utils.getPerpendicularPoints(flightPosition, path, 30000)
			if self:getDistance(conversionPoints[1].x, conversionPoints[1].y) < self:getDistance(conversionPoints[2].x, conversionPoints[2].y) then
				path.x = conversionPoints[1].x
				path.y = conversionPoints[1].y
			else
				path.x = conversionPoints[2].x
				path.y = conversionPoints[2].y
			end
		end
	else
		if self.tactic == defs.interceptTactic.LeadHigh then
			if flightCategory ~= Group.Category.HELICOPTER and self.parameters.maxAltitude > trackAlt then
				path.alt = self.parameters.maxAltitude
			end
		elseif self.tactic == defs.interceptTactic.LeadLow then
			path.alt = trackAlt * 0.6
		end
	end
	-- if ambushing go low, if not and far away go high
	local ambushDistance = 20000
	if flightCategory == Group.Category.HELICOPTER then
		ambushDistance = 5000
	end
	if self.mission.type == defs.missionType.AMBUSHCAP and range > ambushDistance then
		path.alt = self.parameters.ambushAltitude
	elseif range > 120000 then
		path.alt = self.parameters.maxAltitude
	end
	-- reduce speed while climbing to prevent DCS AI stupidity
	if flightAltitude < (path.alt - 2000) and engaging ~= true and utils.getTableSize(self.group:getUnits()) > 1 then
		interceptSpeed = 320
	end
	local task = {
		["id"] = 'Mission',
		["params"] = {
			["airborne"] = true,
			["route"] = {
				["points"] = {
					[1] = {
						["type"] = "Turning Point",
						["action"] = "Turning Point",
						["x"] = path.x,
						["y"] = path.y,
						["alt"] = path.alt,
						["alt_type"] = altType,
						["speed"] = interceptSpeed,
						["task"] = interceptTask
					}
				}
			}
		}
	}
	controller:setTask(task)

	-- control the intercept more closely as we're getting closer to the target
	local nextUpdate
	if range < 60000 then
		nextUpdate = 5
	elseif range < 160000 then
		nextUpdate = 10
	else
		nextUpdate = 15
	end
	timer.scheduleFunction(self.intercept, self, timer.getTime() + nextUpdate)
end

function Flight:ReturnToBase()
	-- deactivate any active beacon
	local beaconCommand = {
		id = 'DeactivateBeacon',
		params = {}
	}
	self:getController():setCommand(beaconCommand)
	self.mission = RTB:new(self.home)
    self:assignMission()
end

function Flight:remove()
	for key, unit in pairs(self.group:getUnits()) do
		if unit:inAir() ~= true then
			unit:destroy()
			-- if this is the last unit in a group, destroy it
			if self.group:getSize() == 0 then
				self.group:destroy()
			end
		end
	end
end

function Flight:control()
	-- if flight doesn't exist return false
	if self.group:isExist() == false then
		return false
	end
	-- clean up any units on the ground
	if self.cleanupTime ~= nil and timer.getTime() > self.cleanupTime then
		self:remove()
		if self.group:isExist() == false then
			return false
		end
		self.cleanupTime = nil
	elseif self.cleanupTime == nil and self:isAirborne() == false then
		self.cleanupTime = timer.getTime() + defs.landingCleanupTime
	end
	-- if our intercept track is no longer active, clear it out
	if self.mission.targetTrack ~= nil then
		if self.mission.targetTrack.merged ~= nil then
			self.mission.targetTrack = self.mission.targetTrack.merged
		end
		if self.mission.targetTrack:isActive() == false then
			self.mission.targetTrack = nil
			self.tactic = nil
			self:assignMission()
		end
	end
	-- RTB if we're below bingo
	local fuelState = self:getFuelState()
	if self.mission.type ~= defs.missionType.RTB and fuelState < self.parameters.bingoLevel then
		self:ReturnToBase()
	end
	return true
end

-- set comms for flight
function Flight:setComms(frequency, modulation)
	local frequencyCommand = {
		id = 'SetFrequency',
		params = {
			frequency = frequency,
			modulation = modulation,
			power = 10
		}
	}
	self:getController():setCommand(frequencyCommand)
end

-- set TACAN for flight
function Flight:setBeacon(channel, frequency, band, bearing, callsign)
	local system = 4
	if band == "Y" then
		system = 5
	end
	local beaconCommand = {
		id = 'ActivateBeacon',
		params = {
			type = 4,
			system = system,
			AA = false,
			channel = channel,
			frequency = frequency,
			modeChannel = band,
			bearing = bearing,
			callsign = callsign
		}
	}
	self:getController():setCommand(beaconCommand)
end

function Flight:assignMission()
	self.tactic = nil
    self.mission:assignTask(self)
	if self.mission.orbit ~= nil then
		if self.mission.orbit.comm ~= nil then
			local comm = self.mission.orbit.comm
			self:setComms(comm.frequency, comm.modulation)
		end
		if self.mission.orbit.beacon ~= nil then
			local beacon = self.mission.orbit.beacon
			self:setBeacon(beacon.channel, beacon.frequency, beacon.band, beacon.bearing, beacon.callsign)
		end
	end
end

function Flight:init(group, mission, home, squadron)
    self.group = group
    self.mission = mission
    self.home = home
	self.squadron = squadron
	self.parameters = {}
	self.cleanupTime = timer.getTime() + defs.takeoffCleanupTime
	 -- wonky if we don't delay it by a bit
	timer.scheduleFunction(self.assignMission, self, timer.getTime() + 1)
	-- schedule an intercept if we have a target track
	if mission.targetTrack ~= nil then
		timer.scheduleFunction(self.intercept, self, timer.getTime() + 5)
	end
end

function Flight:launch(airbase, squadron, mission, flightSize, groundStart)
	-- check if airbase exists
	if airbase.object:isExist() ~= true then
		return nil
	end
	local flightData = {}
	local loadout = {}
	local units = {}
	local route = {}
	-- get airbase coordinates and elevation from game
	local airbaseLocation = airbase:getLocation()
	-- assign callsign
	local callsignList
	local availableCallsigns = {}
	-- select orbit callsign list if available, if not use squadron's
	if mission.orbit ~= nil and mission.orbit.callsigns ~= nil then
		callsignList = mission.orbit.callsigns
	else
		callsignList = squadron.callsigns
	end
	for callsign, callsignID in pairs(callsignList) do
		local callsignData = {
			["name"] = callsign,
			["ID"] = callsignID
		}
		table.insert(availableCallsigns, callsignData)
	end
	local callsignIndex = math.random(utils.getTableSize(availableCallsigns)) -- select a callsign from the list of available ones
	local callsignName = availableCallsigns[callsignIndex].name -- text callsign for flight name
	local callsignID -- DCS callsign ID
	if availableCallsigns[callsignIndex].ID ~= 0 then
		callsignID = availableCallsigns[callsignIndex].ID
	else
		callsignID = math.random(9)
	end
	local flightNumber
	local flightName
	flightNumber = math.random(9)
	flightName = callsignName .. " " .. tostring(flightNumber)
	-- need to check if our callsign is in use so we don't delete another flight
	while Group.getByName(flightName) ~= nil and Group.getByName(flightName):isExist() == true do
		flightNumber = flightNumber + 1
		flightName = callsignName .. " " .. tostring(flightNumber)
	end
	flightData = {
		["name"] = flightName
	}
	-- see if mission specific loadout option exists and, if so, select it
	-- if not, check if one does for a similar mission profile or use general mission class loadout
	local missionType = mission.type
	local missionCategory = mission:getCategory()
	if squadron.loadouts[missionCategory][missionType] ~= nil then
		loadout = squadron.loadouts[missionCategory][missionType]
	else
		if missionType == defs.missionType.QRA and squadron.loadouts[defs.roleCategory.AA][defs.missionType.Intercept] ~= nil then
			loadout = squadron.loadouts[defs.roleCategory.AA][defs.missionType.Intercept]
		elseif missionType == defs.missionType.HAVCAP and squadron.loadouts[defs.roleCategory.AA][defs.missionType.CAP] ~= nil then
			loadout = squadron.loadouts[defs.roleCategory.AA][defs.missionType.CAP]
		elseif missionType == defs.missionType.AMBUSHCAP and squadron.loadouts[defs.roleCategory.AA][defs.missionType.CAP] ~= nil then
			loadout = squadron.loadouts[defs.roleCategory.AA][defs.missionType.CAP]
		else
			loadout = squadron.loadouts[missionCategory][defs.missionType.General]
		end
	end
	-- select flight options for mission
	flightData.task = defs.DCSTask[missionType]
	-- add flight members
	for i = 1, flightSize do
		local name
		if missionCategory == defs.roleCategory.Support and flightSize == 1 then
			name = flightName
		else
			name = flightName .. tostring(i)
		end
		units[i] = {
			["name"] = name,
			["type"] = squadron.type,
			["x"] = airbaseLocation.x,
			["y"] = airbaseLocation.y - ((i - 1) * 35),
			["alt"] = (airbaseLocation.alt + 100),
			["heading"] = airbase.takeoffHeading,
			["alt_type"] = "BARO",
			["speed"] = 120,
			["skill"] = utils.getSkill(squadron.skill),
			["livery_id"] = squadron.livery,
			["payload"] = loadout,
			["callsign"] = {
				[1] = callsignID,
				[2] = flightNumber,
				[3] = i,
				["name"] = name
			},
			["AddPropAircraft"] = {
				["VoiceCallsignLabel"] = string.sub(flightName, 1) .. string.sub(flightName, -1),
				["VoiceCallsignNumber"] = string.sub(tostring(flightNumber), -1) .. string.sub(tostring(i), -1), -- use substring for the edge case of the flight number being two digit
				["STN_L16"] = "90" .. string.sub(tostring(flightNumber), -1) .. "0" .. string.sub(tostring(i), -1),
			},
		}
		units[i].onboard_num = tostring(units[i].callsign[1]) .. tostring(units[i].callsign[2]) .. tostring(units[i].callsign[3])
	end
	flightData["units"] = units
	local airbaseID = airbase.object:getID()
	local airbaseCategory = airbase.object:getDesc().category
	-- add route waypoint for airfield launch
	route = {
		["points"] = {
			[1] = {
				["speed"] = 120,
				["x"] = airbaseLocation.x,
				["y"] = airbaseLocation.y,
				["alt"] = (airbaseLocation.alt + 100),
			}
		}
	}
	if airbaseCategory == Airbase.Category.HELIPAD or airbaseCategory == Airbase.Category.SHIP then
		route.points[1].linkUnit = airbaseID
		route.points[1].helipadId = airbaseID
	else
		route.points[1].airdromeId = airbaseID
	end
	-- check if a ground or air start is needed, force ground start if players are close enough to the airbase
	if groundStart or utils.playerInRange(defs.groundStartRadius, airbaseLocation.x, airbaseLocation.y) then
		if airbaseCategory == Airbase.Category.HELIPAD then
			route.points[1].type = "TakeOffGroundHot"
			route.points[1].action = "From Ground Area Hot"
		else
			route.points[1].type = "TakeOffParkingHot"
			route.points[1].action = "From Parking Area Hot"
		end
	else
		route.points[1].type = "Turning Point"
		route.points[1].action = "Turning Point"
	end
	flightData["route"] = route
	-- spawn unit and return
	local typeCategory = Unit.getDescByName(squadron.type).category
	local group = coalition.addGroup(squadron.country, typeCategory, flightData)
	if group:isExist() then
		return Flight:new(group, mission, airbase, squadron)
	end
	return nil
end

return Flight