-- Air Command system by Arctic Fox --
-- enums and stuff --

---------------------------------------------------------------------------------------------------------------------------
local Definitions = {}

--[[-- DCS country IDs
    ["country"] = {
        ["USA"] = 2,
        ["Iran"] = 34,
        ["Iraq"] = 35,
        ["Pakistan"] = 39,
        ["USSR"] = 68
    },]]--

-- generic capability enum
Definitions.capability = {
    ["None"] = 1,
    ["Limited"] = 2,
    ["Full"] = 3
}

-- threat type enum
Definitions.threatType = {
    ["Standard"] = 1,
    ["High"] = 2
}

-- enum for formations
-- DCS does not have a default enum for this for some reason
Definitions.fixedWingFormation = {
    ["LABSClose"] = 65537,
    ["LABSOpen"] = 65538,
    ["LABSGroupClose"] = 65539,
    ["WedgeClose"] = 196609,
    ["WedgeOpen"] = 196610,
    ["WedgeGroupClose"] = 196611,
}
Definitions.rotaryFormation = {
    ["Wedge"] = 8,
    ["FrontRightClose"] = 655361,
    ["FrontRightOpen"] = 655362,
    ["FrontLeftClose"] = 655617,
    ["FrontLeftOpen"] = 655618
}
-- enum for intercept tactics
Definitions.interceptTactic = {
    ["Pure"] = 1,
    ["Lead"] = 2,
    ["LeadLow"] = 3,
    ["LeadHigh"] = 4,
    ["Beam"] = 5,
    ["Stern"] = 6
}

Definitions.roleCategory = {
    ["AA"] = 1,
    ["AG"] = 2,
    ["Support"] = 3,
    ["Misc"] = 4
}

Definitions.missionType = {
    ["Intercept"] = 1,
    ["QRA"] = 2,
    ["CAP"] = 3,
    ["AMBUSHCAP"] = 4,
    ["Escort"] = 5,
    ["HAVCAP"] = 6,
    ["Tanker"] = 7,
    ["AEW"] = 8,
    ["RTB"] = 9,
    ["General"] = 10
}

Definitions.DCSTask = {
    [Definitions.missionType.Intercept] = "Intercept",
    [Definitions.missionType.QRA] = "Intercept",
    [Definitions.missionType.CAP] = "CAP",
    [Definitions.missionType.AMBUSHCAP] = "CAP",
    [Definitions.missionType.Escort] = "Escort",
    [Definitions.missionType.HAVCAP] = "Escort",
    [Definitions.missionType.Tanker] = "Refueling",
    [Definitions.missionType.AEW] = "AWACS",
    [Definitions.missionType.RTB] = "Nothing"
}

-- basic category for each mission type
Definitions.missionCategory = {
    [Definitions.missionType.Intercept] = Definitions.roleCategory.AA,
    [Definitions.missionType.QRA] = Definitions.roleCategory.AA,
    [Definitions.missionType.CAP] = Definitions.roleCategory.AA,
    [Definitions.missionType.AMBUSHCAP] = Definitions.roleCategory.AA,
    [Definitions.missionType.Escort] = Definitions.roleCategory.AA,
    [Definitions.missionType.HAVCAP] = Definitions.roleCategory.AA,
    [Definitions.missionType.Tanker] = Definitions.roleCategory.Support,
    [Definitions.missionType.AEW] = Definitions.roleCategory.Support,
    [Definitions.missionType.RTB] = Definitions.roleCategory.Misc
}

-- list of missions that require a HAVCAP
Definitions.HAVCAPRequired = {
    [Definitions.missionType.Tanker] = true,
    [Definitions.missionType.AEW] = true
}

-- DCS categories for unit types
--[[Definitions.typeCategory = {
    ["F-14A-135-GR"] = Group.Category.AIRPLANE,
    ["F-14B"] = Group.Category.AIRPLANE,
    ["F-4E-45MC"] = Group.Category.AIRPLANE,
    ["F-5E-3"] = Group.Category.AIRPLANE,
    ["F-16C_50"] = Group.Category.AIRPLANE,
    ["KC-135"] = Group.Category.AIRPLANE,
    ["KC135MPRS"] = Group.Category.AIRPLANE,
    ["E-2C"] = Group.Category.AIRPLANE,
    ["AH-1W"] = Group.Category.HELICOPTER,
    ["Su-27"] = Group.Category.AIRPLANE,
    ["MiG-31"] = Group.Category.AIRPLANE,
    ["MiG-29A"] = Group.Category.AIRPLANE,
    ["MiG-23MLD"] = Group.Category.AIRPLANE,
    ["IL-78M"] = Group.Category.AIRPLANE
}--]]

-- DCS categories for weapon types
Definitions.weaponTypes = {
    ["GuidedWeapon"] = 268402702
}
-- attributes of units that will be used for air target tracking
Definitions.primaryTrackerAttributes = {
	["EWR"] = true,
	["SAM SR"] = true,
	["Aircraft Carriers"] = true,
	["Cruisers"] = true,
	["Destroyers"] = true,
	["Frigates"] = true,
	["AWACS"] = true
}
Definitions.secondaryTrackerAttributes = {
	["Infantry"] = true,
	["Air Defence"] = true,
	["Armed ships"] = true
}

Definitions.groundStartRadius = 25000       -- radius around an airfield where if a player is present, a flight will ground instead of air start
Definitions.skipResetTime = 60              -- seconds between a failed launch until airfield will be used again
Definitions.takeoffCleanupTime = 1800       -- seconds after a flight is spawned when it will be cleaned up if not in the air
Definitions.landingCleanupTime = 1200       -- seconds after a flight has landed when it will be cleaned up
Definitions.primaryTrackerWeight = 1        -- observation weight by primary tracking system
Definitions.secondaryTrackerWeight = 0.5    -- observation weight by secondary tracking system
Definitions.fighterObservationWeight = 3    -- observation weight by interceptor
Definitions.maxObservationWeight = 3        -- maximum amount by which the observation counter can be incremented at once
Definitions.maxObservations = 1024          -- maximum amount of observations on a track before the value is capped
Definitions.observationMissFactor = 2     -- value to divide a track's observation counter by if it is not detected
Definitions.trackTimeout = 60               -- amount of time before tracks are timed out
Definitions.trackCorrelationDistance = 8000 -- maximum distance in meters between which a target will correlate with a track
Definitions.trackCorrelationAltitude = 5000 -- maximum altitude difference in meters between which a target will correlate with a track

return Definitions
