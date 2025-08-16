-- Air Command system by Arctic Fox --
-- HAVCAP mission --

local defs = require("Defs")
local utils = require("Utils")
local class = require("Class")
local Escort = require("Missions.Escort")
---------------------------------------------------------------------------------------------------------------------------
--[[
	Mission data for packages or flights
	Parameters:
    type - mission identifier
    flightOptions - DCS group controller options to be set for a flight on this mission
    escortTarget - flight to be escorted
]]--
local HAVCAP = class(Escort)

function Escort:assignTask(flight)
	self:assignFlightOptions(flight)
    -- create DCS task and push it to the flight controller
    local controller = flight:getController()
    local airbaseLocation = flight.home:getLocation()
    -- get push point
	-- if escort orbit is nil (for example if the main flight RTB'd, abort the flight)
	if self.escortTarget.mission.orbit == nil then
		flight:ReturnToBase()
		return
	end
    local orbitCenter = utils.getPointOnLine(self.escortTarget.mission.orbit.p1, self.escortTarget.mission.orbit.p2)
    local pushPoint = utils.getPointOnLine(orbitCenter, airbaseLocation, 40000)
	local task = {
		["id"] = "Mission",
		["params"] = {
			["airborne"] = true,
			["route"] = {
				["points"] = {
					[1] = {
						["type"] = "Turning Point",
						["action"] = "Turning Point",
						["x"] = pushPoint.x,
						["y"] = pushPoint.y,
						["alt"] = flight.parameters.standardAltitude,
						["speed"] = flight.parameters.standardSpeed,
						["task"] = {
							["id"] = "ComboTask",
							["params"] = {
								["tasks"] = {
								}
							}
						}
					},
					[2] = {
						["type"] = "Turning Point",
						["action"] = "Turning Point",
						["x"] = pushPoint.x,
						["y"] = pushPoint.y,
						["alt"] = flight.parameters.standardAltitude,
						["speed"] = flight.parameters.standardSpeed,
						["task"] = {
							["id"] = "ComboTask",
							["params"] = {
								["tasks"] = {
									[1] = {
										["id"] = "Escort",
										["params"] = {
											["groupId"] = self.escortTarget:getID(),
											["engagementDistMax"] = flight.parameters.escortCommitRange,
											["pos"] = {
												["x"] = 0,
												["y"] = 500,
												["z"] = 1000
											},
											["lastWptIndexFlag"] = true,
											["lastWptIndex"] = 10
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

function HAVCAP:init(escortTarget)
    self.type = defs.missionType.HAVCAP
    self.flightOptions = Escort.flightOptions
    self.escortTarget = escortTarget
end

return HAVCAP