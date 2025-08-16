-- Air Command system by Arctic Fox --
-- tanker mission --

local defs = require("Defs")
local class = require("Class")
local Mission = require("Missions.Mission")
---------------------------------------------------------------------------------------------------------------------------
--[[
	Mission data for packages or flights
	Parameters:
    type - mission identifier
    flightOptions - DCS group controller options to be set for a flight on this mission
    orbit - tanker orbit
]]--
local Tanker = class(Mission)

Tanker.flightOptions = {
    [AI.Option.Air.id.REACTION_ON_THREAT] = AI.Option.Air.val.REACTION_ON_THREAT.ALLOW_ABORT_MISSION,
    [AI.Option.Air.id.RTB_ON_BINGO] = false
}

function Tanker:getAltitude(flight)
	local altitude = flight.parameters.standardAltitude
    if self.orbit.alt ~= nil then
        altitude = self.orbit.alt
    end
	return altitude
end

function Tanker:getSpeed(flight)
	local speed = flight.parameters.standardSpeed
    if self.orbit.speed ~= nil then
        speed = self.orbit.speed
    end
	return speed
end

function Tanker:assignTask(flight)
	self:assignFlightOptions(flight)
    local controller = flight:getController()
    local airbaseLocation = flight.home:getLocation()
    -- use orbit parameters if they exist, otherwise use standard flight parameters
    local altitude = self:getAltitude(flight)
    local speed = self:getSpeed(flight)
	local orbitTask
	-- check if there's a group for the tanker to follow as a recovery unit, if not use standard orbit
	if self.orbit.recoveryGroup ~= nil and self.orbit.recoveryGroup:isExist() then
		orbitTask = {
			["id"] = "RecoveryTanker",
			["params"] = {
				["groupId"] = self.orbit.recoveryGroup:getID(),
				["lastWptIndexFlag"] = false,
				["altitude"] = altitude,
				["speed"] = speed
			}
		}
	else
		orbitTask = {
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
	end
	 -- create DCS task and push it to the flight controller
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
										["id"] = "Tanker",
										["params"] = {
										}
									},
									[2] = orbitTask
								}
							}
						}
					},
					[2] = {
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

function Tanker:init(orbit)
    self.type = defs.missionType.Tanker
    self.flightOptions = Tanker.flightOptions
    self.orbit = orbit
end

return Tanker