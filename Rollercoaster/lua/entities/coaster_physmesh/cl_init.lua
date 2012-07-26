include("shared.lua")
include("mesh_physics.lua")

ENT.Segment = -1
ENT.Controller = nil

ENT.RenderGroup 	= RENDERGROUP_TRANSLUCENT

//Build the mesh for the specific segment
//This function is NOT controller only, call it on the segment you want to update the mesh on
function ENT:BuildMesh()
	//If we have no controller, we really should not exist
	if !IsValid( self.Controller ) then return end

	self.Segment = self:GetSegment()
	//Make sure our segment has actual information
	if self.Segment < 2 or self.Segment >= #self.Controller.Nodes - 1 then return end

	//We're starting up making a beam of cylinders
	physmesh_builder.Start( self.Tri_Width, self.Tri_Height ) 

	//Create some variables
	local CurNode = self.Controller.Nodes[ self.Segment ]
	local NextNode = self.Controller.Nodes[ self.Segment + 1 ]

	local LastAngle = Angle( 0, 0, 0 )
	local ThisAngle = Angle( 0, 0, 0 )

	local ThisPos = Vector( 0, 0, 0 )
	local NextPos = Vector( 0, 0, 0 )
	for i = 0, self.Resolution - 1 do
		ThisPos = self.Controller.CatmullRom:Point(self.Segment, i/self.Resolution)
		NextPos = self.Controller.CatmullRom:Point(self.Segment, (i+1)/self.Resolution)

		local ThisAngleVector = ThisPos - NextPos
		ThisAngle = ThisAngleVector:Angle()

		if IsValid( CurNode ) && IsValid( NextNode ) && CurNode.GetRoll && NextNode.GetRoll then
			local Roll = -Lerp( i/self.Resolution, math.NormalizeAngle( CurNode:GetRoll() ), NextNode:GetRoll() )	
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

	self:PhysicsFromMesh( Remaining ) //THIS MOTHERFUCKER
	self:EnableCustomCollisions( )

end
