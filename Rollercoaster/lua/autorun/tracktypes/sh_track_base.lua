include("autorun/sh_enums.lua")

TRACK = {}

TRACK.Name = "BASETRACK"
TRACK.Description = "BASE"
TRACK.PhysWidth = 20 //How wide the physics mesh should be
TRACK.SupportOverride = false  //Override track supports (we're making our own)
TRACK.StepsPerCycle = 0
TRACK.TrackMeshes = {}
TRACK.BuildingTrackMeshes = {}

function TRACK:Create( class )
	class = class or {}
	setmetatable(class, self)
	self.__index = self
	class.TrackMeshes = {}
	class.BuildingTrackMeshes = {}
	return class
end

-- Called by the trackclass to do some coroutine logic
function TRACK:CoroutineCheck( Controller, Stage, Sections, Percent )
	self.StepsPerCycle = self.StepsPerCycle + 1

	if self.StepsPerCycle >= GetConVar("coaster_mesh_stepspercycle"):GetInt() && !Sections then
		self.StepsPerCycle = 0
		hook.Call("CoasterBuildProgress", GAMEMODE, Controller:GetCoasterID(), Stage, Percent or 1)
		coroutine.yield()
	end
end

function TRACK:FinalizeTrack( Controller )
	-- If we were returned a mesh, it's done generating
	if self.BuildingTrackMeshes then
		self.TrackMeshes = self.BuildingTrackMeshes
		self.BuildingTrackMeshes = {} //Reset
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
	else print("TRACK:FinalizeTrack(). Track has invalid BuildingTrackMeshes!") end
end

-- Get the maximum number of vertices allowed per mesh. Make this dynamic eventually?
function TRACK:GetMaxVertices()
	local convar = GetConVar("coaster_mesh_maxvertices")
	return convar && convar:GetInt() or 50000
end

-- Add a submesh to a specific section
function TRACK:AddSubmesh( section, verttable )
	local m = Mesh()
	m:BuildFromTriangles( verttable )
	if !self.BuildingTrackMeshes[section] then self.BuildingTrackMeshes[section] = {} end

	table.insert( self.BuildingTrackMeshes[section], m )
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

function TRACK:Draw( meshdata )
	return
end

-- Called when the track is still generating
-- Override if you want to do something special!
function TRACK:DrawUnfinished( meshdata )
	self:Draw( meshdata )
end

/****************************
Utility function for drawing all of the sections within a section
****************************/
function TRACK:DrawSection( num, table )
	if !table then return end
	if !istable( table[num]) then return end

	for _, v in pairs( table[num] ) do
		if v then v:Draw() end
	end
end