-- Air Command system by Arctic Fox --
-- AEW mission --

local defs = require("Defs")
local class = require("Class")
local Mission = require("Missions.Mission")
---------------------------------------------------------------------------------------------------------------------------
--[[
	Mission data for packages or flights
	Parameters:
    type - mission identifier
    flightOptions - DCS group controller options to be set for a flight on this mission
    orbit - AEW orbit
]]--
local AEW = class(Mission)

AEW.flightOptions = {
    [AI.Option.Air.id.RADAR_USING] = AI.Option.Air.val.RADAR_USING.FOR_CONTINUOUS_SEARCH,
    [AI.Option.Air.id.REACTION_ON_THREAT] = AI.Option.Air.val.REACTION_ON_THREAT.NO_REACTION,
    [AI.Option.Air.id.RTB_ON_BINGO] = false
}

function AEW:getAltitude(flight)
	local altitude = flight.parameters.standardAltitude
    if self.orbit.altitude ~= nil then
        altitude = self.orbit.alt
    end
	return altitude
end

function AEW:getSpeed(flight)
	local speed = flight.parameters.standardSpeed
    if self.orbit.speed ~= nil then
        speed = self.orbit.speed
    end
	return speed
end

function AEW:assignTask(flight)
	self:assignFlightOptions(flight)
    -- create DCS task and push it to the flight controller
    local controller = flight:getController()
    local airbaseLocation = flight.home:getLocation()
    -- use orbit parameters if they exist, otherwise use standard flight parameters
    local altitude = self:getAltitude(flight)
    local speed = self:getSpeed(flight)
    local task = {
		["id"] = "Mission",
		["params"] = {
			["airborne"] = true,
			["route"] = {
				["points"] = {
					[1] = {
						["type"] = "Turning Point",
						["action"] = "Turning Point",
						["x"] = self.orbit.p1.x,
						["y"] = self.orbit.p1.y,
						["alt"] = altitude,
						["speed"] = speed,
						["task"] = {
							["id"] = "ComboTask",
							["params"] = {
								["tasks"] = {
									[1] = {
										["id"] = "AWACS",
										["params"] = {
										}
									}
								}
							}
						}
					},
					[2] = {
						["type"] = "Turning Point",
						["action"] = "Turning Point",
						["x"] = self.orbit.p1.x,
						["y"] = self.orbit.p1.y,
						["alt"] = altitude,
						["speed"] = speed,
						["task"] = {
							["id"] = "ComboTask",
							["params"] = {
								["tasks"] = {
									[1] = {
										["id"] = "Orbit",
										["params"] = {
											["pattern"] = "Race-Track",
											["point"] = {
												["x"] = self.orbit.p1.x,
												["y"] = self.orbit.p1.y
											},
											["point2"] = {
												["x"] = self.orbit.p2.x,
												["y"] = self.orbit.p2.y
											},
											["altitude"] = altitude,
											["speed"] = speed
										}
									}
								}
							}
						}
					},
					[3] = {
						["type"] = "Land",
						["action"] = "Turning Point",
						["airdromeId"] = flight.home.object:getID(),
						["x"] = airbaseLocation.x,
						["y"] = airbaseLocation.y,
						["alt"] = flight.parameters.returnAltitude,
						["speed"] = flight.parameters.standardSpeed,
						["task"] = {
							["id"] = "ComboTask",
							["params"] = {
								["tasks"] = {
								}
							}
						}
					}
				}
			}
		}
	}
	controller:setTask(task)
end

function AEW:init(orbit)
    self.type = defs.missionType.AEW
    self.flightOptions = AEW.flightOptions
    self.orbit = orbit
end

return AEW