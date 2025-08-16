-- Air Command system by Arctic Fox --
-- AMBUSHCAP mission --

local defs = require("Defs")
local class = require("Class")
local CAP = require("Missions.CAP")
---------------------------------------------------------------------------------------------------------------------------
--[[
	Mission data for packages or flights
	Parameters:
    type - mission identifier
    flightOptions - DCS group controller options to be set for a flight on this mission
    escortTarget - flight to be escorted
]]--
local AMBUSHCAP = class(CAP)

AMBUSHCAP.flightOptions = {
    [AI.Option.Air.id.ROE] = AI.Option.Air.val.ROE.RETURN_FIRE,
    [AI.Option.Air.id.REACTION_ON_THREAT] = AI.Option.Air.val.REACTION_ON_THREAT.EVADE_FIRE,
    [AI.Option.Air.id.ECM_USING] = AI.Option.Air.val.ECM_USING.USE_IF_ONLY_LOCK_BY_RADAR,
    [AI.Option.Air.id.RADAR_USING] = AI.Option.Air.val.RADAR_USING.NEVER,
    [AI.Option.Air.id.MISSILE_ATTACK] = AI.Option.Air.val.MISSILE_ATTACK.RANDOM_RANGE, -- TODO: More complex decision making maybe
    [AI.Option.Air.id.FORMATION] = defs.fixedWingFormation.LABSClose,
    [AI.Option.Air.id.ALLOW_FORMATION_SIDE_SWAP] = true,
    [AI.Option.Air.id.FORCED_ATTACK] = true,
    [AI.Option.Air.id.PROHIBIT_AG] = true,
    [AI.Option.Air.id.JETT_TANKS_IF_EMPTY] = false,
    [AI.Option.Air.id.RTB_ON_BINGO] = false
}

function AMBUSHCAP:getAltitudeType(flight)
    return "RADIO"
end

function AMBUSHCAP:getAltitude(flight)
	local altitude = flight.parameters.ambushAltitude
	return altitude
end

function AMBUSHCAP:getSpeed(flight)
	local speed = flight.parameters.ambushSpeed
	return speed
end

function AMBUSHCAP:init(orbit)
    self.type = defs.missionType.AMBUSHCAP
    self.flightOptions = AMBUSHCAP.flightOptions
    self.orbit = orbit
end

return AMBUSHCAP