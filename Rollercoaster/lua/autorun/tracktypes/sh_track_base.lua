include("autorun/sh_enums.lua")

TRACK = {}

TRACK.Name = "BASETRACK"
TRACK.Description = "BASE"
TRACK.PhysWidth = 20 //How wide the physics mesh should be
TRACK.SupportOverride = false  //Override track supports (we're making our own)
TRACK.StepsPerCycle = 0

function TRACK:Create( class )
	class = class or {}
	setmetatable(class, self)
	self.__index = self
	return class
end

-- Called by the trackclass to do some coroutine logic
function TRACK:CoroutineCheck( Controller, Stage, Sections, Percent )
	self.StepsPerCycle = self.StepsPerCycle + 1

	if self.StepsPerCycle >= GetConVar("coaster_stepspercycle"):GetInt() && !Sections then
		hook.Call("CoasterBuildProgress", GAMEMODE, Controller:GetCoasterID(), Stage, Percent or 1)
		coroutine.yield()
	end

	-- If we were returned a mesh, it's done generating
	if Sections then
		Controller.TrackMeshes = Sections
		Controller.BuildingMesh = false

		Controller:ValidateNodes()

		-- One more update can't hurt
		Controller:SupportFullUpdate()

		//Tell the track panel to update itself
		UpdateTrackPanel( controlpanel.Get("coaster_supertool").CoasterList )
	end
end

function TRACK:Generate( controller )
	return nil
end

function TRACK:Draw( controller, Meshes )
	if !IsValid( controller ) || !controller:IsController() then return end
end

