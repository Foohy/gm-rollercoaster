include("autorun/sh_enums.lua")

local TRACK = TRACK && TRACK:Create()
if !TRACK then return end

TRACK.Name = "B&M Track"
TRACK.Description = "The upright design of Bolliger & Mabillard"
TRACK.PhysWidth = 25 -- How wide the physics mesh should be
TRACK.SupportScale = 0.65 -- How 'thin' the supports should be

trackmanager.Register( EnumNames.Tracks[COASTER_TRACK_BM], TRACK )

if !CLIENT then return end

TRACK.Material = Material( "coaster/track_metal_clean")

-- Distance track beams away from eachother
local RailOffset = 20
local CenterBeamOffset = 15
local CenterBeamWidth = 14
local StrutOffset = 0.5

TRACK.CylinderRadius = 3 -- Radius of the circular track beams
TRACK.CylinderPointCount = 7 -- How many points make the cylinder of the track mesh

local function GetAngleOfSubsegment( Controller, subsegment )
	local SubAngle = Angle( 0, 0, 0 )
	local NearSub = Controller.CatmullRom.Spline[subsegment+1] -- Get a subsegment that's just next to us
	local Reverse = Controller.CatmullRom.Spline[subsegment+1] == nil 
	if Reverse then NearSub = Controller.CatmullRom.Spline[subsegment-1] end -- If there isn't a next node, get a previous one

	local NextNode = Controller.Nodes[Controller:GetSplineSegment(subsegment) + 1]
	local CurrentNode = Controller.Nodes[ Controller:GetSplineSegment(subsegment) ]

	local Normal = NearSub - Controller.CatmullRom.Spline[subsegment]
	if Reverse then Normal = -Normal end 

	Normal:Normalize()
	SubAngle = Normal:Angle()

	//Get the percent along this segment, to calculate how much we'll roll
	local perc = Controller:PercAlongNode( subsegment )
	
	//Note all Lerps are negated. This is because the actual roll value from the gun is backwards.
	local Roll = Lerp( perc, math.NormalizeAngle( CurrentNode:GetRoll() ), NextNode:GetRoll())	

	-- Take into account roll
	SubAngle:RotateAroundAxis( Normal, Roll ) 

	return SubAngle, Normal
end 

//I can't retrieve the triangles from a compiled model, SO LET'S MAKE OUR OWN
//These are the triangular struts of the metal beam mesh track
local function CreateStrutsMesh(pos, ang, TrackColor)
	local width = 5
	local Offset = 15

	//Front tri
	local F_Right = pos + ang:Right() * RailOffset
	local F_Bottom = pos + ang:Up() * -Offset
	local F_Left = pos + ang:Right() * -RailOffset

	//Back tri
	local B_Right = F_Right + ( ang:Forward() * width )
	local B_Bottom = F_Bottom + ( ang:Forward() * width )
	local B_Left = F_Left + ( ang:Forward() * width )

	local Vertices = {}

	//Vars to get the proper normal of the left/right bits of the struts
	local angLeft = F_Bottom - F_Left
	angLeft:Normalize()
	local angRight = F_Bottom - F_Right
	angRight:Normalize()

	local NormTop = ang:Up()
	local NormFwd = -ang:Forward()
	local NormBkwd = ang:Forward()
	local NormLeft = angLeft
	local NormRight = angRight

	local colVec = Vector( 0, 0, 0 )

	//And the user selected color too
	local UserColor = Vector( 1, 1, 1 )
	if TrackColor then
		UserColor = Vector( TrackColor.r / 255, TrackColor.g / 255, TrackColor.b / 255 ) 
	end

	//Front triangle
	colVec = render.ComputeLighting(F_Right, NormFwd )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(F_Right, NormFwd)
	Vertices[1] = {
		pos = F_Right,
		normal = NormFwd,
		u = 0,
		v = 0,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}
	colVec = render.ComputeLighting(F_Bottom, NormFwd )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(F_Bottom, NormFwd)
	Vertices[2] = {
		pos = F_Bottom,
		normal = NormFwd,
		u = 0.5,
		v = 1,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}
	colVec = render.ComputeLighting(F_Left, NormFwd )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(F_Left, NormFwd)
	Vertices[3] = {
		pos = F_Left,
		normal = NormFwd,
		u = 1,
		v = 0,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}

	//Back triangle
	colVec = render.ComputeLighting(B_Left, NormBkwd )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(B_Left, NormBkwd)
	Vertices[4] = {
		pos = B_Left,
		normal = NormBkwd,
		u = 0,
		v = 0,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}
	colVec = render.ComputeLighting(B_Bottom, NormBkwd )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(B_Bottom, NormBkwd)
	Vertices[5] = {
		pos = B_Bottom,
		normal = NormBkwd,
		u = 0.5,
		v = 1,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}
	colVec = render.ComputeLighting(B_Right, NormBkwd )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(B_Right, NormBkwd)
	Vertices[6] = {
		pos = B_Right,
		normal = NormBkwd,
		u = 1,
		v = 0,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}

	//Top Quad
	colVec = render.ComputeLighting(B_Left, NormTop )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(B_Left, NormTop)
	Vertices[7] = {
		pos = B_Left,
		normal = NormTop,
		u = 0,
		v = 0,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}
	colVec = render.ComputeLighting(B_Right, NormTop )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(B_Right, NormTop)
	Vertices[8] = {
		pos = B_Right,
		normal = NormTop,
		u = 0.5,
		v = 1,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}
	colVec = render.ComputeLighting(F_Right, NormTop )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(F_Right, NormTop)
	Vertices[9] = {
		pos = F_Right,
		normal = NormTop,
		u = 1,
		v = 0,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}

	colVec = render.ComputeLighting(F_Right, NormTop )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(F_Right, NormTop)
	Vertices[10] = {
		pos = F_Right,
		normal = NormTop,
		u = 0,
		v = 0,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}
	colVec = render.ComputeLighting(F_Left, NormTop )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(F_Left, NormTop)
	Vertices[11] = {
		pos = F_Left,
		normal = NormTop,
		u = 0.5,
		v = 1,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}
	colVec = render.ComputeLighting(B_Left, NormTop )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(B_Left, NormTop)
	Vertices[12] = {
		pos = B_Left,
		normal = NormTop,
		u = 1,
		v = 0,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}

	//Left Quad
	colVec = render.ComputeLighting(F_Bottom, NormLeft )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(F_Bottom, NormLeft)
	Vertices[13] = {
		pos = F_Bottom,
		normal = NormLeft,
		u = 0,
		v = 0,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}
	colVec = render.ComputeLighting(B_Bottom, NormLeft )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(B_Bottom, NormLeft)
	Vertices[14] = {
		pos = B_Bottom,
		normal = NormLeft,
		u = 0.5,
		v = 1,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}
	colVec = render.ComputeLighting(B_Left, NormLeft )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(B_Left, NormLeft)
	Vertices[15] = {
		pos = B_Left,
		normal = NormLeft,
		u = 1,
		v = 0,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}

	colVec = render.ComputeLighting(B_Left, NormLeft )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(B_Left, NormLeft)
	Vertices[16] = {
		pos = B_Left,
		normal = NormLeft,
		u = 0,
		v = 0,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}
	colVec = render.ComputeLighting(F_Left, NormLeft )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(F_Left, NormLeft)
	Vertices[17] = {
		pos = F_Left,
		normal = NormLeft,
		u = 0.5,
		v = 1,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}
	colVec = render.ComputeLighting(F_Bottom, NormLeft )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(F_Bottom, NormLeft)
	Vertices[18] = {
		pos = F_Bottom,
		normal = NormLeft,
		u = 1,
		v = 0,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}

	//Right Quad
	colVec = render.ComputeLighting(F_Bottom, NormRight )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(F_Bottom, NormRight)
	Vertices[19] = {
		pos = F_Bottom,
		normal = NormRight,
		u = 0,
		v = 0,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}
	colVec = render.ComputeLighting(F_Right, NormRight )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(F_Right, NormRight)
	Vertices[20] = {
		pos = F_Right,
		normal = NormRight,
		u = 0.5,
		v = 1,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}
	colVec = render.ComputeLighting(B_Right, NormRight )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(B_Right, NormRight)
	Vertices[21] = {
		pos = B_Right,
		normal = NormRight,
		u = 1,
		v = 0,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}

	colVec = render.ComputeLighting(B_Right, NormRight )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(B_Right, NormRight)
	Vertices[22] = {
		pos = B_Right,
		normal = NormRight,
		u = 0,
		v = 0,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}
	colVec = render.ComputeLighting(B_Bottom, NormRight )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(B_Bottom, NormRight)
	Vertices[23] = {
		pos = B_Bottom,
		normal = NormRight,
		u = 0.5,
		v = 1,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}
	colVec = render.ComputeLighting(F_Bottom, NormRight )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(F_Bottom, NormRight)
	Vertices[24] = {
		pos = F_Bottom,
		normal = NormRight,
		u = 1,
		v = 0,
		color = Color( colVec.x*UserColor.x*255, colVec.y*UserColor.y*255, colVec.z*UserColor.z*255)
	}


	return Vertices
end

function TRACK:CreateSideBeams( Position, Angle, Position2, Angle2, Node, CurrentCylinderAngle )
	//Side rails
	self.Cylinder:AddBeam( Position + Angle:Right() * -RailOffset, -- Position of beginning of cylinder
		self.LastCylinderAngle, -- The angle of the first radius of the cylinder
		Position2 + Angle2:Right() * -RailOffset, -- Position of end of cylinder
		CurrentCylinderAngle, 
		self.CylinderRadius, -- Radius of cylinder
		Node:GetTrackColor() ) -- Color

	self.Cylinder:AddBeam( Position + Angle:Right() * RailOffset, 
		self.LastCylinderAngle, 
		Position2 + Angle2:Right() * RailOffset, 
		CurrentCylinderAngle, 
		self.CylinderRadius, 
		Node:GetTrackColor() ) 

end

function TRACK:CreateCenterBeam( Position, Angle1, Position2, Angle2, Node, CurrentCylinderAngle )
	self.Cylinder:AddBeamSquareSimple(Position - Angle1:Up() * CenterBeamOffset, Angle1, Position2 - Angle2:Up() * CenterBeamOffset, Angle2, CenterBeamWidth, Node:GetTrackColor() )
end

function TRACK:PassRails( Controller )
	if !IsValid( Controller ) || !Controller:IsController() then return end

	local Models = {}
	local ModelCount = 1

	local Vertices = {} //Create an array that will hold an array of vertices (This is to split up the model)
	Meshes = {} //If we hit the maximum for the number of vertices of a model, split it up into several

	self.BeginningSegmentAngle = nil
	self.BeginningSegmentCylinderAngle = nil 

	self.LastAngle = nil //Last angle so previous cylinder matches with the next cylinder
	self.LastNormal = nil
	self.LastCylinderAngle = nil

	//For every single spline segment 
	for i = 1, #Controller.CatmullRom.Spline do
		local CurrentNode = Controller.Nodes[ Controller:GetSplineSegment(i-1) ]
		local SubsegmentAngle, SubsegmentNormal = GetAngleOfSubsegment( Controller, i )

		if i == 1 then
			local CylinderAngle = SubsegmentNormal:Angle()
			CylinderAngle:RotateAroundAxis(SubsegmentNormal:Angle():Up(), 90 )

			self.LastCylinderAngle = CylinderAngle -- Since there was no 'last', this is the closest we have
			self.BeginningSegmentAngle = SubsegmentAngle -- Store the angle for the very last subsegment to match to
			self.BeginningSegmentCylinderAngle = CylinderAngle -- Ditto

			-- Here we have a special case. The first subsegment is after the first node, so we'll have to slap that in now
			self:CreateSideBeams( CurrentNode:GetPos(), SubsegmentAngle, Controller.CatmullRom.Spline[i], SubsegmentAngle, CurrentNode, CylinderAngle )
			self:CreateCenterBeam( CurrentNode:GetPos(), SubsegmentAngle, Controller.CatmullRom.Spline[i], SubsegmentAngle, CurrentNode )
		end

		if self.LastAngle && self.LastNormal then

			-- Calculate the angle of the circle for the end of the cylinder
			local CylinderAngle = self.LastNormal:Angle()
			CylinderAngle:RotateAroundAxis(SubsegmentNormal:Angle():Up(), 90 )

			-- If this is the last segment, adjust the angles so it will seamlessly fit with the beginning of the track (if it's looped)
			if i == #Controller.CatmullRom.Spline && Controller:Looped() then
				SubsegmentAngle = self.BeginningSegmentAngle
				CylinderAngle = self.BeginningSegmentCylinderAngle
			end

			-- Create the beams
			self:CreateSideBeams( Controller.CatmullRom.Spline[i-1], self.LastAngle, Controller.CatmullRom.Spline[i], SubsegmentAngle, CurrentNode, CylinderAngle )
			self:CreateCenterBeam( Controller.CatmullRom.Spline[i-1], self.LastAngle, Controller.CatmullRom.Spline[i], SubsegmentAngle, CurrentNode )

			self.LastCylinderAngle = CylinderAngle
		end


		-- Split the model into multiple meshes if it gets large
		if #self.Cylinder.Vertices > 50000 then

			Models[ModelCount] = self.Cylinder.Vertices
			ModelCount = ModelCount + 1

			self.Cylinder.Vertices = {}
			self.Cylinder.TriCount = 1
		end
		
		self.LastAngle = SubsegmentAngle
		self.LastNormal = SubsegmentNormal

		-- Check if we need to yield, and report some information
		self:CoroutineCheck( Controller, 1, nil, i / #Controller.CatmullRom.Spline)
	end	

	local verts = self.Cylinder:EndBeam()
	Models[ModelCount] = verts

	return Models
end

function TRACK:PassStruts( Controller )
	if !IsValid( Controller ) || !Controller:IsController() then return end
	local Models = {}
	local ModelCount = 1

	local Vertices = {} //Create an array that will hold an array of vertices (This is to split up the model)
	Meshes = {} //If we hit the maximum for the number of vertices of a model, split it up into several

	local CurSegment = 2
	local Percent = 0
	local Multiplier = 1
	local StrutVerts = {} //mmm yeah strut those verts

	while CurSegment < #Controller.CatmullRom.PointsList - 1 do
		local CurNode = Controller.Nodes[CurSegment]
		local NextNode = Controller.Nodes[CurSegment + 1]

		local Position = Controller.CatmullRom:Point(CurSegment, Percent)

		local ang = Controller:AngleAt(CurSegment, Percent)

		//Change the roll depending on the track
		local Roll = -Lerp( Percent, math.NormalizeAngle( CurNode:GetRoll() ), NextNode:GetRoll())	
		
		//Set the roll for the current track peice
		ang.r = Roll
		//ang:RotateAroundAxis( controller:AngleAt(CurSegment, Percent), Roll ) //BAM

		//Now... manage moving throughout the track evenly
		//Each spline has a certain multiplier so the cart travel at a constant speed throughout the track
		Multiplier = Controller:GetMultiplier(CurSegment, Percent)

		//Move ourselves forward along the track
		Percent = Percent + ( Multiplier * StrutOffset )

		//Manage moving between nodes
		if Percent > 1 then
			CurSegment = CurSegment + 1
			if CurSegment > #Controller.Nodes - 2 then 			
				break
			end	
			Percent = 0
		end


		local verts = CreateStrutsMesh(Position, ang, CurNode:GetTrackColor())
		table.Add( StrutVerts, verts )

		-- Split the model into multiple meshes if it gets large
		if #StrutVerts > 50000 then

			Models[ModelCount] = StrutVerts
			ModelCount = ModelCount + 1
		end

		self:CoroutineCheck( Controller, 2, nil, CurSegment / (#Controller.CatmullRom.PointsList - 1) )
	end

	//put the struts into the big vertices table
	Models[ModelCount] = StrutVerts

	return Models
end

function TRACK:Generate( Controller )
	if !IsValid( Controller ) || !Controller:IsController() then return end

	local Rails = {}
	local Struts = {}
	local RailMeshes = {}
	local StrutsMeshes = {}

	-- Create the cylinder object that will assist in mesh generation
	self.Cylinder = Cylinder:Create()

	table.Add( Rails, self:PassRails( Controller ) )
	table.Add( Struts, self:PassStruts(Controller))

	for i=1, #Rails do
		if #Rails[i] > 2 then
			RailMeshes[i] = Mesh()
			RailMeshes[i]:BuildFromTriangles( Rails[i] )
		end
	end

	for i=1, #Struts do
		if #Struts[i] > 2 then
			StrutsMeshes[i] = Mesh()
			StrutsMeshes[i]:BuildFromTriangles( Struts[i] )
		end
	end

	//Create a new variable that will hold each section of the mesh
	local Sections = {}
	Sections[1] = RailMeshes
	Sections[2] = StrutsMeshes

	-- Let's exit the thread, but give them our finalized sections too
	self:CoroutineCheck( Controller, 3, Sections )
	-- return Sections
end

function TRACK:Draw()

	-- Draw the rails (side, center)
	render.SetMaterial(self.Material)
	self:DrawSection( 1 )

	-- Draw the center struts
	self:DrawSection( 2 )

end

