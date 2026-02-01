-- Air Command system by Arctic Fox --
-- air target tracking system --

local utils = require("Utils")
local defs = require("Defs")
local class = require("Class")
local AirborneTrack = require("Tracking.AirborneTrack")
---------------------------------------------------------------------------------------------------------------------------
--[[
	System handling unit airborne detection and tracking
	Parameters:
	primaryTrackers - list of active primary tracking systems (EWRs, search radars, AWACS and so forth)
	secondaryTrackers - list of active secondary trackers (infantry, SHORAD), currently no difference in functionality to primary trackers
	trackerParameters - settings affecting tracker performance
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

function TrackingSystem:getDetectionProbability(height)
	local threshold = self.trackerParameters.altitudeThreshold
	local max = self.trackerParameters.maxDetectionProbability
	local min = self.trackerParameters.minDetectionProbability
	local probability = max
	if height < threshold then
		probability = min + ((max - min) / (threshold / height))
	end
	return probability
end

-- check if a detected target is valid for tracking
function TrackingSystem:checkValidTarget(object)
	if object == nil then
		return false
	end
	if object:getCategory() ~= Object.Category.UNIT then
		return false
	end
	if object:getCoalition() == self.side then
		return false
	end
	return true
end

-- sort units detected by trackers and assign them to tracks
-- TODO: Detection chance based on unit
function TrackingSystem:detectTargets()
	local targets = {}
	-- find all valid targets detected by primary trackers
	for trackerID, tracker in pairs(self.primaryTrackers) do
		if tracker:isExist() then
			-- keep track if the targets were already detected with visual/EO so we don't count them twice
			local trackerTargets = {}
			-- check all non-radar targets
			local detectedTargets = tracker:getController():getDetectedTargets(Controller.Detection.VISUAL, Controller.Detection.OPTIC, Controller.Detection.IRST)
			for key, target in pairs(detectedTargets) do
				if self:checkValidTarget(target.object) then
					if targets[target.object] == nil then
						targets[target.object] = defs.primaryTrackerWeight
					else
						targets[target.object] = targets[target.object] + defs.primaryTrackerWeight
					end
					trackerTargets[target.object] = true
				end
			end
			-- check radar targets
			detectedTargets = tracker:getController():getDetectedTargets(Controller.Detection.RADAR)
			for key, target in pairs(detectedTargets) do
				if self:checkValidTarget(target.object) then
					if trackerTargets[target.object] ~= true then
						local detectionProbability = self:getDetectionProbability(utils.getAGL(target.object))
						if math.random(100) <= detectionProbability then
							if targets[target.object] == nil then
								targets[target.object] = defs.primaryTrackerWeight
							else
								targets[target.object] = targets[target.object] + defs.primaryTrackerWeight
							end
						end
					end
				end
			end
		else
			-- remove tracker from list if it no longer exists
			self.primaryTrackers[trackerID] = nil
		end
	end
	-- same for secondary targets
	for trackerID, tracker in pairs(self.secondaryTrackers) do
		if tracker:isExist() then
			-- keep track if the targets were already detected with visual/EO so we don't count them twice
			local trackerTargets = {}
			-- check all non-radar targets
			local detectedTargets = tracker:getController():getDetectedTargets(Controller.Detection.VISUAL, Controller.Detection.OPTIC, Controller.Detection.IRST)
			for key, target in pairs(detectedTargets) do
				if self:checkValidTarget(target.object) then
					if targets[target.object] == nil then
						targets[target.object] = defs.secondaryTrackerWeight
					else
						targets[target.object] = targets[target.object] + defs.secondaryTrackerWeight
					end
					trackerTargets[target.object] = true
				end
			end
			-- check radar targets
			detectedTargets = tracker:getController():getDetectedTargets(Controller.Detection.RADAR)
			for key, target in pairs(detectedTargets) do
				if self:checkValidTarget(target.object) then
					if trackerTargets[target.object] ~= true then
						local detectionProbability = self:getDetectionProbability(utils.getAGL(target.object))
						if math.random(100) <= detectionProbability then
							if targets[target.object] == nil then
								targets[target.object] = defs.secondaryTrackerWeight
							else
								targets[target.object] = targets[target.object] + defs.secondaryTrackerWeight
							end
						end
					end
				end
			end
		else
			-- remove tracker from list if it no longer exists
			self.secondaryTrackers[trackerID] = nil
		end
	end
	local correlatedTargets = {}
	-- correlate targets to tracks
	for target, weight in pairs(targets) do
		local correlated = nil
		for key, track in pairs(self.tracks) do
			if track:correlate(target) then
				if correlatedTargets[track] == nil then
					correlatedTargets[track] = {}
				end
				correlatedTargets[track][target] = weight
				local typeName = target:getTypeName()
				local threatType = defs.threatType.Standard
				if self.threatTypes[typeName] ~= nil then
					threatType = self.threatTypes[typeName]
				end
				track:setThreatType(threatType)
				-- merge tracks if the target was correlated to another track already
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
			table.insert(self.tracks, AirborneTrack:new(target, weight))
		end
	end
	-- update all tracks with correlated targets
	for key, track in pairs(self.tracks) do
		if correlatedTargets[track] ~= nil then
			track:update(correlatedTargets[track])
		else
			track:missedObservation()
		end
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

function TrackingSystem:init(side, ADZExclusion, threatTypes, trackerParameters)
	self.side = side
	self.ADZExclusion = ADZExclusion
	self.threatTypes = threatTypes
	self.trackerParameters = trackerParameters
	self.primaryTrackers = {}
    self.secondaryTrackers = {}
    self.tracks = {}
    self:initTrackers()
	timer.scheduleFunction(TrackingSystem.detectTargets, self, timer.getTime() + 3)
	timer.scheduleFunction(TrackingSystem.timeoutTracks, self, timer.getTime() + 7)
end

return TrackingSystem