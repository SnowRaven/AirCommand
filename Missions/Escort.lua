-- Air Command system by Arctic Fox --
-- escort mission --

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
local Escort = class(Mission)

Escort.flightOptions = {
    [AI.Option.Air.id.ROE] = AI.Option.Air.val.ROE.RETURN_FIRE,
    [AI.Option.Air.id.REACTION_ON_THREAT] = AI.Option.Air.val.REACTION_ON_THREAT.EVADE_FIRE,
    [AI.Option.Air.id.ECM_USING] = AI.Option.Air.val.ECM_USING.USE_IF_ONLY_LOCK_BY_RADAR,
    [AI.Option.Air.id.RADAR_USING] = AI.Option.Air.val.RADAR_USING.FOR_SEARCH_IF_REQUIRED,
    [AI.Option.Air.id.MISSILE_ATTACK] = AI.Option.Air.val.MISSILE_ATTACK.RANDOM_RANGE, -- TODO: More complex decision making maybe
    [AI.Option.Air.id.FORMATION] = defs.fixedWingFormation.LABSClose,
    [AI.Option.Air.id.PROHIBIT_AG] = true,
    [AI.Option.Air.id.JETT_TANKS_IF_EMPTY] = false,
    [AI.Option.Air.id.RTB_ON_BINGO] = false
}

function Escort:assignFlightOptions(flight)
	local controller = flight:getController()
	for option, value in pairs(self.flightOptions) do
		controller:setOption(option, value)
	end
    if flight:getCategory() == Group.Category.HELICOPTER then
        controller:setOption(AI.Option.Air.id.FORMATION, defs.rotaryFormation.FrontRightClose)
        controller:setOption(AI.Option.Air.id.MISSILE_ATTACK, AI.Option.Air.val.MISSILE_ATTACK.MAX_RANGE)
    end
end

-- TODO: Task assignment

function Escort:init(escortTarget)
    self.type = defs.missionType.Escort
    self.flightOptions = Escort.flightOptions
    self.escortTarget = escortTarget
end

return Escort