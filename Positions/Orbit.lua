-- Air Command system by Arctic Fox --
-- racetrack orbit --
local class = require("Class")
---------------------------------------------------------------------------------------------------------------------------
--[[
	Two point racetrack orbit
	Parameters:
	p1 - First point of the orbit
	p2 - Second point of the orbit
    speed - speed of the aircraft in the orbit in m/s (optional)
	alt - altitude of the orbit in meters (optional)
    recoveryGroup - group for a tanker to follow as a recovery tanker
    callsigns - list of callsigns to be used by flights, entry name will be used for flight name and value for DCS callsign ID (optional)
    comm - comm data to be used for the aircraft, represented in a two part table (optional): {
        ["frequency"] - comm frequency of an aircraft assigned to the orbit 
        ["modulation"] - selects whether AM (0) or FM (1) will be used
    }
    beacon - TACAN data to be used for the aircraft, represented in four part table (optional): {
        ["channel"] = TACAN channel of an aircraft assigned to the orbit
        ["band"] = TACAN band of an aircraft assigned to the orbit, "X" or "Y"
        ["bearing"] = Selects whether TACAN bearing is allowed
        ["callsign"] = TACAN callsign of an aircraft assigned to the orbi
    }
    airframes - table of allowed airframes (if nil all are allowed)
    HAVCAP - whether this orbit requires a HAVCAP escort
]]--
local Orbit = class()

function Orbit:init(orbitData)
    self.p1 = {
        ["x"] = orbitData[1].x,
        ["y"] = orbitData[1].y
    }
    self.p2 = {
        ["x"] = orbitData[2].x,
        ["y"] = orbitData[2].y
    }
    self.speed = orbitData.speed
    self.alt = orbitData.alt
    if orbitData.recoveryGroup ~= nil then
        self.recoveryGroup = Group.getByName(orbitData.recoveryGroup)
    end
    if orbitData.comm ~= nil then
        self.comm = {
            ["frequency"] = orbitData.comm.frequency,
            ["modulation"] = orbitData.comm.modulation
        }
    end
    if orbitData.beacon ~= nil then
        self.beacon = {
            ["channel"] = orbitData.beacon.channel,
            ["band"] = orbitData.beacon.band,
            ["frequency"] = orbitData.beacon.frequency,
            ["bearing"] = orbitData.beacon.bearing,
            ["callsign"] = orbitData.beacon.callsign
        }
    end
    if orbitData.callsigns ~= nil then
        self.callsigns = {}
        for callsign, callsignID in pairs(orbitData.callsigns) do
            self.callsigns[callsign] = callsignID
        end
    end
    if orbitData.airframes ~= nil then
        self.airframes = {}
        for airframeID, value in pairs(orbitData.airframes) do
            self.airframes[airframeID] = value
        end
    end
    self.HAVCAP = false
    if orbitData.HAVCAP ~= nil then
        self.HAVCAP = orbitData.HAVCAP
    end
end

return Orbit