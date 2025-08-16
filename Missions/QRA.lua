-- Air Command system by Arctic Fox --
-- QRA intercept mission --

local defs = require("Defs")
local class = require("Class")
local Intercept = require("Missions.Intercept")
---------------------------------------------------------------------------------------------------------------------------
--[[
	Mission data for packages or flights
	Parameters:
    type - mission identifier
    flightOptions - DCS group controller options to be set for a flight on this mission
    interceptTarget - track to be intercepted
]]--
local QRA = class(Intercept)

function QRA:init(interceptTarget)
    self.type = defs.missionType.QRA
    self.flightOptions = Intercept.flightOptions
    self.targetTrack = interceptTarget
end

return QRA