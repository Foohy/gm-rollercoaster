AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )
include( "mesh_physics.lua")

ENT.Segment = -1
ENT.Controller = nil

function ENT:Initialize()

	self:SetModel("models/props_junk/PopCan01a.mdl")
	self.Model = "models/props_junk/PopCan01a.mdl"


	self:PhysicsInit(SOLID_CUSTOM)
	self:GetPhysicsObject():EnableMotion( false )
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_VPHYSICS)

	self:DrawShadow( false )

	self:SetAngles( Angle( 0, 0, 0 ) )

	timer.Simple(0.5, function()
		self.Initialized = true
		self:BuildMesh()
	end )
end

concommand.Add("update_phyasdsmesh", function()
	for k, v in pairs( ents.FindByClass("physmesh_test")) do
		v:BuildPhysicsMesh()
	end
end )

//Build the mesh for the specific segment
//This function is NOT controller only, call it on the segment you want to update the mesh on
function ENT:BuildMesh()
	//If we aren't yet initialized when this function is called stay the fuck still
	if !self.Initialized then return end

	local Tri_Width = 30
	local Tri_Height = 30
	local Resolution = 10 //how many 'splines' in the catmull to do

	//If we have no controller, we really should not exist
	if !IsValid( self.Controller ) then self:Remove() end

	//Make sure our segment has actual infromation 
	if self.Segment < 2 or self.Segment >= #self.Controller.Nodes - 1 then return end

	//We're starting up making a beam of cylinders
	physmesh_builder.Start( Tri_Width, Tri_Height ) 

	//Create some variables
	local CurNode = self.Controller.Nodes[ self.Segment ]
	local NextNode = self.Controller.Nodes[ self.Segment + 1 ]

	local LastAngle = Angle( 0, 0, 0 )
	local ThisAngle = Angle( 0, 0, 0 )

	local ThisPos = Vector( 0, 0, 0 )
	local NextPos = Vector( 0, 0, 0 )
	for i = 1, Resolution do
		ThisPos = self.Controller.CatmullRom:Point(self.Segment, i/Resolution)
		NextPos = self.Controller.CatmullRom:Point(self.Segment, (i+1)/Resolution)

		local ThisAngleVector = ThisPos - NextPos
		ThisAngle = ThisAngleVector:Angle()

		if IsValid( CurNode ) && IsValid( NextNode ) && CurNode.GetRoll && NextNode.GetRoll then
			local Roll = -Lerp( i/Resolution, math.NormalizeAngle( CurNode:GetRoll() ), NextNode:GetRoll() )	
			ThisAngle.r = Roll
		end

		if i==1 then LastAngle = ThisAngle end

		physmesh_builder.AddBeam(ThisPos, LastAngle, NextPos, ThisAngle, Radius )

		LastAngle = ThisAngle
	end

	local Remaining = physmesh_builder.EndBeam()

	//move all the positions so they are relative to ourselves
	for i=1, #Remaining do
		Remaining[i].pos = Remaining[i].pos - self:GetPos()
	end

	local oldangs = self:GetAngles()
	self:SetAngles( Angle( 0, 0, 0 ) )
	self:PhysicsFromMesh( Remaining ) //THIS MOTHERFUCKER
	self:GetPhysicsObject():EnableMotion( false )
	self:EnableCustomCollisions( )

	self:SetCollisionGroup( COLLISION_GROUP_NONE)

end

//Remove the velocity if the player grabs it with the physgun
//TODO: be able to move/fling cart with the physgun
function ENT:PhysicsUpdate(physobj)
	if !IsValid( self.Controller ) then return end
	//self:SetPos( self.Controller:GetPos() )
	//self:SetAngles( Angle( 0, 0, 0 ) )
end

function ENT:Think()
	if IsValid( self.Controller ) then
		self:SetPos( self.Controller:GetPos() )
	end
end

function ENT:OnRemove()

end
