-- Air Command system by Arctic Fox --
-- squadron --
local defs = require("Defs")
local class = require("Class")
---------------------------------------------------------------------------------------------------------------------------
--[[
	Squadron containing operational and airframe data for tasking
	Parameters:
    name - squadron name
    country - squadron country (in DCS enum)
    type - aircraft type operated by squadron
    skill - general skill level of the squadron ("Average"/"Good"/"High"/"Excellent") TODO: add to defs
    livery - name of the livery to be used by the squadron's airframes
    interceptRadius - radius of action around the airbase for interceptors from this squadron in meters
    baseFlightSize - basic flight size
    maxFlightSize - maximum allowed flight size, if not defined will be same as base flight size (optional)
    missions - list of allowed mission types for this squadron and loadouts for them
    targetCategories - list of target types that squadron aircraft are allowed to be tasked against (optional)
    threatTypes - list of threat categories the squadron aircraft are allowed to launch intercepts against, if not defined all will be allowed (optional)
    loadouts - DCS loadout data to be assigned to each mission
    callsigns - list of callsigns to be used by flights, entry name will be used for flight name and value for DCS callsign ID
]]--
local Squadron = class()

function Squadron:init(squadronData)
    self.name = squadronData.name
    self.country = squadronData.country
    self.type = squadronData.type
    self.skill = squadronData.skill
    self.livery = squadronData.livery
    self.interceptRadius = squadronData.interceptRadius
    self.baseFlightSize = squadronData.baseFlightSize
    if squadronData.maxFlightSize ~= nil then
        self.maxFlightSize = squadronData.maxFlightSize
    else
        self.maxFlightSize = self.baseFlightSize
    end

    self.missions = {}
    self.targetCategories = {}
    self.threatTypes = {}
    self.callsigns = {}
    for mission, value in pairs(squadronData.missions) do
        self.missions[mission] = value
    end
    if squadronData.targetCategories ~= nil then
        for targetCategory, value in pairs(squadronData.targetCategories) do
            self.targetCategories[targetCategory] = value
        end
    end
    if squadronData.threatTypes ~= nil then
        for threatType, value in pairs(squadronData.threatTypes) do
            self.threatTypes[threatType] = value
        end
    else
        for key, threatType in pairs(defs.threatType) do
            self.threatTypes[threatType] = true
        end
    end
    for callsign, callsignID in pairs(squadronData.callsigns) do
        self.callsigns[callsign] = callsignID
    end
    self.loadouts = squadronData.loadouts -- TODO: Copy table maybe
end

return Squadron