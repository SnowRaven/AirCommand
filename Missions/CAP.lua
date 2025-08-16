-- Air Command system by Arctic Fox --
-- CAP mission --

local defs = require("Defs")
local class = require("Class")
local Mission = require("Missions.Mission")
---------------------------------------------------------------------------------------------------------------------------
--[[
	Mission data for packages or flights
	Parameters:
    type - mission identifier
    flightOptions - DCS group controller options to be set for a flight on this mission
    escortTarget - flight to be escorted
]]--
local CAP = class(Mission)

CAP.flightOptions = {
    [AI.Option.Air.id.ROE] = AI.Option.Air.val.ROE.RETURN_FIRE,
    [AI.Option.Air.id.REACTION_ON_THREAT] = AI.Option.Air.val.REACTION_ON_THREAT.EVADE_FIRE,
    [AI.Option.Air.id.ECM_USING] = AI.Option.Air.val.ECM_USING.USE_IF_ONLY_LOCK_BY_RADAR,
    [AI.Option.Air.id.RADAR_USING] = AI.Option.Air.val.RADAR_USING.FOR_SEARCH_IF_REQUIRED,
    [AI.Option.Air.id.MISSILE_ATTACK] = AI.Option.Air.val.MISSILE_ATTACK.RANDOM_RANGE, -- TODO: More complex decision making maybe
    [AI.Option.Air.id.FORMATION] = defs.fixedWingFormation.LABSClose,
    [AI.Option.Air.id.ALLOW_FORMATION_SIDE_SWAP] = true,
    [AI.Option.Air.id.FORCED_ATTACK] = true,
    [AI.Option.Air.id.PROHIBIT_AG] = true,
    [AI.Option.Air.id.JETT_TANKS_IF_EMPTY] = false,
    [AI.Option.Air.id.RTB_ON_BINGO] = false
}

function CAP:assignFlightOptions(flight)
	local controller = flight:getController()
	for option, value in pairs(self.flightOptions) do
		controller:setOption(option, value)
	end
    if flight:getCategory() == Group.Category.HELICOPTER then
        controller:setOption(AI.Option.Air.id.FORMATION, defs.rotaryFormation.FrontRightClose)
        controller:setOption(AI.Option.Air.id.MISSILE_ATTACK, AI.Option.Air.val.MISSILE_ATTACK.MAX_RANGE)
    end
end

function CAP:getAltitudeType(flight)
    if flight:getCategory() ~= Group.Category.HELICOPTER then
        return "BARO"
    else
        return "RADIO"
    end
end

function CAP:getAltitude(flight)
	local altitude = flight.parameters.standardAltitude
	return altitude
end

function CAP:getSpeed(flight)
	local speed = flight.parameters.standardSpeed
	return speed
end

function CAP:assignTask(flight)
	self:assignFlightOptions(flight)
    -- create DCS task and push it to the flight controller
    local controller = flight:getController()
    local airbaseLocation = flight.home:getLocation()
    -- use orbit parameters if they exist, otherwise use standard flight parameters
    local altType = self:getAltitudeType(flight)
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
						["x"] = self.orbit.p2.x,
						["y"] = self.orbit.p2.y,
						["alt_type"] = altType,
						["alt"] = altitude,
						["speed"] = speed,
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
						["x"] = self.orbit.p1.x,
						["y"] = self.orbit.p1.y,
						["alt_type"] = altType,
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
						["alt_type"] = "BARO",
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

function CAP:init(orbit)
    self.type = defs.missionType.CAP
    self.flightOptions = CAP.flightOptions
    self.orbit = orbit
end

return CAP