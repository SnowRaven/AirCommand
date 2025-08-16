-- Air Command system by Arctic Fox --
-- RTB mission --

local defs = require("Defs")
local utils = require("Utils")
local class = require("Class")
local Mission = require("Missions.Mission")
---------------------------------------------------------------------------------------------------------------------------
--[[
	Mission data for packages or flights
	Parameters:
    type - mission identifier
    flightOptions - DCS group controller options to be set for a flight on this mission
    base - home base to return to
]]--
local RTB = class(Mission)

RTB.flightOptions = {
    [AI.Option.Air.id.ROE] = AI.Option.Air.val.ROE.RETURN_FIRE,
    [AI.Option.Air.id.REACTION_ON_THREAT] = AI.Option.Air.val.REACTION_ON_THREAT.EVADE_FIRE,
    [AI.Option.Air.id.ECM_USING] = AI.Option.Air.val.ECM_USING.USE_IF_ONLY_LOCK_BY_RADAR,
    [AI.Option.Air.id.RADAR_USING] = AI.Option.Air.val.RADAR_USING.FOR_SEARCH_IF_REQUIRED,
    [AI.Option.Air.id.PROHIBIT_AG] = true,
    [AI.Option.Air.id.JETT_TANKS_IF_EMPTY] = false,
    [AI.Option.Air.id.RTB_ON_BINGO] = false
}

function RTB:assignTask(flight)
	self:assignFlightOptions(flight)
    local controller = flight:getController()
	local airbaseCategory = self.base.object:getDesc().category
	local airbaseID = self.base.object:getID()
    local airbaseLocation = self.base:getLocation()
	local descentPoint = utils.getPointOnLine(airbaseLocation, flight:getPosition(), 40000)
	local task = {
		["id"] = "Mission",
		["params"] = {
			["airborne"] = true,
			["route"] = {
				["points"] = {
					[1] = {
						["type"] = "Turning Point",
						["action"] = "Turning Point",
						["x"] = descentPoint.x,
						["y"] = descentPoint.y,
						["alt"] = flight.parameters.returnAltitude,
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
						["type"] = "Land",
						["action"] = "Landing",
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
	if airbaseCategory == Airbase.Category.HELIPAD or airbaseCategory == Airbase.Category.SHIP then
		task.params.route.points[2].linkUnit = airbaseID
		task.params.route.points[2].helipadId = airbaseID
	else
		task.params.route.points[2].airdromeId = airbaseID
	end
	controller:setTask(task)
end

function RTB:init(base)
    self.type = defs.missionType.RTB
    self.flightOptions = RTB.flightOptions
	self.base = base
end

return RTB