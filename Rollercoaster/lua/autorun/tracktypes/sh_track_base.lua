include("autorun/sh_enums.lua")

TRACK = {}

TRACK.Name = "BASETRACK"
TRACK.Description = "BASE"
TRACK.PhysWidth = 20 //How wide the physics mesh should be
TRACK.SupportOverride = false  //Override track supports (we're making our own)
TRACK.StepsPerCycle = 0
TRACK.TrackMeshes = {}

function TRACK:Create( class )
	class = class or {}
	setmetatable(class, self)
	self.__index = self
	class.TrackMeshes = {}
	return class
end

-- Called by the trackclass to do some coroutine logic
function TRACK:CoroutineCheck( Controller, Stage, Sections, Percent )
	self.StepsPerCycle = self.StepsPerCycle + 1

	if self.StepsPerCycle >= GetConVar("coaster_stepspercycle"):GetInt() && !Sections then
		self.StepsPerCycle = 0
		hook.Call("CoasterBuildProgress", GAMEMODE, Controller:GetCoasterID(), Stage, Percent or 1)
		coroutine.yield()
	end

	-- If we were returned a mesh, it's done generating
	if Sections then
		self.TrackMeshes = Sections
		Controller.BuildingMesh = false

		-- Remove the previous type's mesh now that we're done
		if Controller.PreviousTrackClass then
			Controller.PreviousTrackClass:Remove()
		end

		Controller:ValidateNodes()

		-- One more update can't hurt
		Controller:SupportFullUpdate()

		--Tell the track panel to update itself
		UpdateTrackPanel( controlpanel.Get("coaster_supertool").CoasterList )
	end
end

-- Generate the track mesh
function TRACK:Generate( controller )
	return nil
end

-- Remove the existing mesh, most likely to be replaced
function TRACK:Remove()
	if !istable(self.TrackMeshes) || #self.TrackMeshes < 1 then return end 

	if self.TrackMeshes then
		-- For each track section (usually things that share a material)
		for k,v in pairs( self.TrackMeshes ) do
			-- For each actual model of that section (since they are split due to size)
			for x, y in pairs( v ) do 
				if IsValid ( y ) then
					y:Destroy() 
					y = nil
				end
			end
		end
	end
end

function TRACK:Draw()
	return
end

/****************************
Utility function for drawing all of the sections within a section
****************************/
function TRACK:DrawSection( num )
	if !self.TrackMeshes then return end
	if !istable( self.TrackMeshes[num]) then return end

	for _, v in pairs( self.TrackMeshes[num] ) do
		if v then v:Draw() end
	end
end