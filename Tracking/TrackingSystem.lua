-- Air Command system by Arctic Fox --
-- air target tracking system --

local defs = require("Defs")
local class = require("Class")
local AirborneTrack = require("Tracking.AirborneTrack")
---------------------------------------------------------------------------------------------------------------------------
--[[
	System handling unit airborne detection and tracking
	Parameters:
	primaryTrackers - list of active primary tracking systems (EWRs, search radars, AWACS and so forth)
	secondaryTrackers - list of active secondary trackers (infantry, SHORAD), currently no difference in functionality to primary trackers
	tracks - list of target tracks
]]--
local TrackingSystem = class()

-- evaluate whether a unit has the necessary properties then add it to the list of trackers
function TrackingSystem:addTracker(unit)
	-- don't add units that are in ADZ exclusion zones
    if self.ADZExclusion ~= nil then
        for zoneKey, zone in pairs(self.ADZExclusion) do
            if zone:inZone(unit:getPoint().x, unit:getPoint().z) then
                return
            end
        end
    end
	-- check if unit can be a primary tracker
	local primaryTrackerAttribute = false
	for attribute, value in pairs(defs.primaryTrackerAttributes) do
		if unit:hasAttribute(attribute) then
			primaryTrackerAttribute = true
			break
		end
	end
	if primaryTrackerAttribute then
		self.primaryTrackers[unit:getID()] = unit
	else
		-- if not, check if unit can be a secondary tracker
		local secondaryTrackerAttribute = false
		for attribute, value in pairs(defs.secondaryTrackerAttributes) do
			if unit:hasAttribute(attribute) then
				primaryTrackerAttribute = true
				break
			end
		end
		if secondaryTrackerAttribute then
			self.secondaryTrackers[unit:getID()] = unit
		end
	end
end

-- build AD tracker lists at mission start
function TrackingSystem:initTrackers()
	for groupKey, group in pairs(coalition.getGroups(self.side)) do
		for unitKey, unit in pairs(group:getUnits()) do
			self:addTracker(unit)
		end
	end
end

-- sort units detected by trackers and assign them to tracks
function TrackingSystem:detectTargets()
	local targets = {}
	-- find all valid targets detected by primary trackers
	for trackerID, tracker in pairs(self.primaryTrackers) do
		if tracker:isExist() then
			local detectedTargets = tracker:getController():getDetectedTargets(Controller.Detection.RADAR, Controller.Detection.VISUAL, Controller.Detection.OPTIC, Controller.Detection.IRST)
			for key, target in pairs(detectedTargets) do
				if target.object ~= nil and target.object:getCategory() == Object.Category.UNIT and target.object:getCoalition() ~= self.side then
					targets[target.object:getID()] = target.object
				end
			end
		else
			--remove tracker from list if it no longer exists
			self.primaryTrackers[trackerID] = nil
		end
	end
	-- same for secondary targets
	for trackerID, tracker in pairs(self.secondaryTrackers) do
		if tracker:isExist() then
			local detectedTargets = tracker:getController():getDetectedTargets(Controller.Detection.RADAR, Controller.Detection.VISUAL, Controller.Detection.OPTIC, Controller.Detection.IRST)
			for key, target in pairs(detectedTargets) do
				if target.object ~= nil and target.object:getCategory() == Object.Category.UNIT and target.object:getCoalition() ~= self.side then
					targets[target.object:getID()] = target.object
				end
			end
		else
			--remove tracker from list if it no longer exists
			self.secondaryTrackers[trackerID] = nil
		end
	end
	local correlatedTargets = {}
	-- correlate targets to tracks
	for targetID, target in pairs(targets) do
		local correlated = nil
			for key, track in pairs(self.tracks) do
				if track:correlate(target) then
					if correlatedTargets[track] == nil then
						correlatedTargets[track] = {}
					end
					correlatedTargets[track][target:getID()] = target
					local typeName = target:getTypeName()
					local threatType = defs.threatType.Standard
					if self.threatTypes[typeName] ~= nil then
						threatType = self.threatTypes[typeName]
					end
					track:setThreatType(threatType)
					-- merge tracks if the target was correlated to another one already
					if correlated ~= nil then
						track.merge(correlated)
						track:timeout()
						self.tracks[key] = nil
					else
						correlated = track
					end
				end
			end
		-- create new track if target uncorrelated
		if correlated == nil then
			table.insert(self.tracks, AirborneTrack:new(target))
		end
	end
	-- update all tracks with correlated targets
	for track, targetList in pairs(correlatedTargets) do
		track:update(targetList)
	end
	timer.scheduleFunction(TrackingSystem.detectTargets, self, timer.getTime() + 3)
end

-- delete old tracks that have not been updated
function TrackingSystem:timeoutTracks()
	for key, track in pairs(self.tracks) do
		if track.lastUpdate < (timer.getTime() - defs.trackTimeout) then
			track:timeout()
			self.tracks[key] = nil
		end
	end
	timer.scheduleFunction(TrackingSystem.timeoutTracks, self, timer.getTime() + 6)
end

function TrackingSystem:init(side, ADZExclusion, threatTypes)
	self.side = side
	self.ADZExclusion = ADZExclusion
	self.threatTypes = threatTypes
	self.primaryTrackers = {}
    self.secondaryTrackers = {}
    self.tracks = {}
    self:initTrackers()
	timer.scheduleFunction(TrackingSystem.detectTargets, self, timer.getTime() + 3)
	timer.scheduleFunction(TrackingSystem.timeoutTracks, self, timer.getTime() + 7)
end

return TrackingSystem