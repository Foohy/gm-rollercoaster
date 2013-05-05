include("autorun/sh_enums.lua")

local TRACK = TRACK && TRACK:Create()
if !TRACK then return end

TRACK.Name = "Vekoma Track"
TRACK.Description = "The unique design of Vekoma rollercoasters"
TRACK.PhysWidth = 28 -- How wide the physics mesh should be
TRACK.SupportScale = 0.65 -- How 'thin' the supports should be

trackmanager.Register( EnumNames.Tracks[COASTER_TRACK_VEKOMA], TRACK )

if !CLIENT then return end

TRACK.Material = Material( "coaster/track_metal_clean")

-- Distance track beams away from eachother
local RailOffset = 20
local CenterBeamOffset = 20
local CenterBeamWidth = 9
local StrutOffset = 0.4

TRACK.CylinderRadius = 3.28 -- Radius of the circular track beams
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

-- Utility function for creating vertices
local function Vertex( Position, Normal, Col, U, V )
	U = U or 0
	V = V or 0
	local colVec = render.ComputeLighting(Position, Normal )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(Position, Normal)
	local Vert = {
		pos = Position,
		normal = Normal,
		u = U,
		v = V,
		color = Color( colVec.x*Col.x*255, colVec.y*Col.y*255, colVec.z*Col.z*255)
	}

	return Vert
end

local StrutThickness = 5
local function Create3DTri( P1, P2, P3, Ang, TrackColor, Hide12, Hide23, Hide13 )
	local Offset = Ang:Forward() * -StrutThickness
	local B1 = P1 + Offset
	local B2 = P2 + Offset 
	local B3 = P3 + Offset 

	local NormFront = Ang:Forward()
	local Norm12 = (P2 - P1):Cross( B2 - P1 ):GetNormal()
	local Norm23 = (P3 - P2):Cross( B3 - P2 ):GetNormal()
	local Norm13 = (P1 - P3):Cross( B1 - P3 ):GetNormal()


	//And the user selected color too
	local UserColor = Vector( 1, 1, 1 )
	if TrackColor then
		UserColor = Vector( TrackColor.r / 255, TrackColor.g / 255, TrackColor.b / 255 ) 
	end

	local Vertices = {}

	-- Front triangle
	table.insert( Vertices, Vertex(P1, NormFront, UserColor ))
	table.insert( Vertices, Vertex(P2, NormFront, UserColor ))
	table.insert( Vertices, Vertex(P3, NormFront, UserColor ))

	-- Back triangle 
	table.insert( Vertices, Vertex(B3, -NormFront, UserColor ))
	table.insert( Vertices, Vertex(B2, -NormFront, UserColor ))
	table.insert( Vertices, Vertex(B1, -NormFront, UserColor ))

	-- Square 1-2
	if !Hide12 then
		table.insert( Vertices, Vertex(P1, Norm12, UserColor ))
		table.insert( Vertices, Vertex(B2, Norm12, UserColor ))
		table.insert( Vertices, Vertex(P2, Norm12, UserColor ))

		table.insert( Vertices, Vertex(B1, Norm12, UserColor ))
		table.insert( Vertices, Vertex(B2, Norm12, UserColor ))
		table.insert( Vertices, Vertex(P1, Norm12, UserColor ))
	end

	-- Square 2-3
	if !Hide23 then
		table.insert( Vertices, Vertex(B3, Norm23, UserColor ))
		table.insert( Vertices, Vertex(P2, Norm23, UserColor ))
		table.insert( Vertices, Vertex(B2, Norm23, UserColor ))

		table.insert( Vertices, Vertex(P3, Norm23, UserColor ))
		table.insert( Vertices, Vertex(P2, Norm23, UserColor ))
		table.insert( Vertices, Vertex(B3, Norm23, UserColor ))
	end

	-- Square 1-3
	if !Hide13 then
		table.insert( Vertices, Vertex(P3, Norm13, UserColor ))
		table.insert( Vertices, Vertex(B1, Norm13, UserColor ))
		table.insert( Vertices, Vertex(P1, Norm13, UserColor ))

		table.insert( Vertices, Vertex(B3, Norm13, UserColor ))
		table.insert( Vertices, Vertex(B1, Norm13, UserColor ))
		table.insert( Vertices, Vertex(P3, Norm13, UserColor ))
	end


	return Vertices
end

local function Create3DSquare( P1, P2, P3, P4, Ang, TrackColor, Hide12, Hide23, Hide34, Hide41 )
	local Vertices = {}

	table.Add( Vertices, Create3DTri(P2, P1, P4, Ang, TrackColor, false, false, true ) )
	table.Add( Vertices, Create3DTri(P4, P3, P2, Ang, TrackColor , false, false, true ) )
	return Vertices 
end

-- Jeeze at this point I might as well make my own model importer christ.
local StrutsMesh = {
	--Right side
	Vector( 44.75, 0, -10.5),
	Vector( 38.75, 0, -12.5),
	Vector( 32.25, 0, 2.000),

	Vector( 28.25, 0, -2.00),
	Vector( 32.25, 0, 2.000),
	Vector( 38.75, 0, -12.5),


	Vector( 38.75, 0, -12.5),
	Vector( 44.75, 0, -10.5),
	Vector( 38.75, 0, -26.0),

	Vector( 44.75, 0, -10.5),
	Vector( 44.75, 0, -44),
	Vector( 38.75, 0, -26.0),


	Vector( 44.75, 0, -44),
	Vector( 27.75, 0, -37.5),
	Vector( 38.75, 0, -26.0),

	-- Middle connecting bar
	Vector( -44.75, 0, -44),
	Vector( -27.75, 0, -37.5),
	Vector( 27.75, 0, -37.5),
	Vector( 27.75, 0, -37.5),
	Vector( 44.75, 0, -44),
	Vector( -44.75, 0, -44),


	-- Left side
	Vector( -38.75, 0, -12.5),
	Vector( -44.75, 0, -10.5),
	Vector( -32.25, 0, 2.000),

	Vector( -38.75, 0, -12.5),
	Vector( -32.25, 0, 2.000),
	Vector( -28.25, 0, -2.00),


	Vector( -38.75, 0, -26.0),
	Vector( -44.75, 0, -10.5),
	Vector( -38.75, 0, -12.5),

	Vector( -38.75, 0, -26.0),
	Vector( -44.75, 0, -44),
	Vector( -44.75, 0, -10.5),


	Vector( -38.75, 0, -26.0),
	Vector( -27.75, 0, -37.5),
	Vector( -44.75, 0, -44),
}


local function CreateStrutsMesh(pos, ang, TrackColor)
	local TransformedVerts = {}

	-- Transform the vertices to their proper scale/angle
	for i = 1, #StrutsMesh do
		local ang2 = Angle( ang.p, ang.y, ang.r )
		ang2:RotateAroundAxis( ang:Up(), 90)
		TransformedVerts[i] = (StrutsMesh[i] * 0.7)
		TransformedVerts[i]:Rotate( ang2 )
	end

	local Vertices = {}

	-- Normal direction
	for i=1, #TransformedVerts, 3 do
		table.Add( Vertices, Create3DTri(TransformedVerts[i] + pos, TransformedVerts[i+1] + pos, TransformedVerts[i+2] + pos, ang, TrackColor ) )
	end

	return Vertices
end

function TRACK:CreateSideBeams( Position, Angle, Position2, Angle2, Node, CurrentCylinderAngle )
	local color = Node:GetActualTrackColor()
	//Side rails
	self.Cylinder:AddBeam( Position + Angle:Right() * -RailOffset, -- Position of beginning of cylinder
		self.LastCylinderAngle, -- The angle of the first radius of the cylinder
		Position2 + Angle2:Right() * -RailOffset, -- Position of end of cylinder
		CurrentCylinderAngle, 
		self.CylinderRadius, -- Radius of cylinder
		color ) -- Color

	self.Cylinder:AddBeam( Position + Angle:Right() * RailOffset, 
		self.LastCylinderAngle, 
		Position2 + Angle2:Right() * RailOffset, 
		CurrentCylinderAngle, 
		self.CylinderRadius, 
		color ) 

end

function TRACK:CreateCenterBeam( Position, Angle1, Position2, Angle2, Node, CurrentCylinderAngle )
	 self.Cylinder:AddBeam(Position + Angle1:Up() * -CenterBeamOffset, 
	 	self.LastCylinderAngle, 
	 	Position2 + Angle2:Up() * -CenterBeamOffset, 
	 	CurrentCylinderAngle, 
	 	CenterBeamWidth, 
	 	Node:GetActualTrackColor() )
end

function TRACK:PassRails( Controller )
	if !IsValid( Controller ) || !Controller:GetIsController() then return end

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
			self:CreateCenterBeam( CurrentNode:GetPos(), SubsegmentAngle, Controller.CatmullRom.Spline[i], SubsegmentAngle, CurrentNode, CylinderAngle )
		end

		if self.LastAngle && self.LastNormal then

			-- Calculate the angle of the circle for the end of the cylinder
			local CylinderAngle = self.LastNormal:Angle()
			CylinderAngle:RotateAroundAxis(SubsegmentNormal:Angle():Up(), 90 )

			-- If this is the last segment, adjust the angles so it will seamlessly fit with the beginning of the track (if it's looped)
			if i == #Controller.CatmullRom.Spline && Controller:GetLooped() then
				SubsegmentAngle = self.BeginningSegmentAngle
				CylinderAngle = self.BeginningSegmentCylinderAngle
			end

			-- Create the beams
			self:CreateSideBeams( Controller.CatmullRom.Spline[i-1], self.LastAngle, Controller.CatmullRom.Spline[i], SubsegmentAngle, CurrentNode, CylinderAngle )
			self:CreateCenterBeam( Controller.CatmullRom.Spline[i-1], self.LastAngle, Controller.CatmullRom.Spline[i], SubsegmentAngle, CurrentNode, CylinderAngle )

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
	if !IsValid( Controller ) || !Controller:GetIsController() then return end
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

		local verts = CreateStrutsMesh(Position, ang, CurNode:GetActualTrackColor())

		table.Add( StrutVerts, verts )

		-- Split the model into multiple meshes if it gets large
		if #StrutVerts > 50000 then

			Models[ModelCount] = StrutVerts
			ModelCount = ModelCount + 1
			StrutVerts = {}
		end

		self:CoroutineCheck( Controller, 2, nil, CurSegment / (#Controller.CatmullRom.PointsList - 1) )
	end

	//put the struts into the big vertices table
	Models[ModelCount] = StrutVerts

	return Models
end

function TRACK:Generate( Controller )
	if !IsValid( Controller ) || !Controller:GetIsController() then return end

	local Rails = {}
	local Struts = {}
	local RailMeshes = {}
	local StrutsMeshes = {}

	-- Create the cylinder object that will assist in mesh generation
	self.Cylinder = Cylinder:Create()
	self.Cylinder.Count = self.CylinderPointCount

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
end

function TRACK:Draw()

	render.SetMaterial(self.Material)
	-- Draw the rails (side, center)
	self:DrawSection( 1 )

	-- Draw the center struts
	self:DrawSection( 2 )
end

