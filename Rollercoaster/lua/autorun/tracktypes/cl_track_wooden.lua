include("autorun/sh_enums.lua")

local TRACK = {}

TRACK.Name = "Wooden Track"
TRACK.Description = "A wooden track"
TRACK.Material =  CreateMaterial( "CoasterWoodMaterialRail", "UnlitGeneric", { //VertexLitGeneric
	["$basetexture"] 		= "phoenix_storms/metalset_1-2", //models/debug/debugwhite
	["$vertexcolor"] 		= 1,
	["$phong"] 				= 1,
	["$phongexponent"] 		= 20,
	["$phongboost"] 		= 2,
	["$phongfresnelranges"] = "0.5 0.8 1",
} )

TRACK.MaterialWood =  CreateMaterial( "CoasterWoodMaterialBeam", "UnlitGeneric", { //VertexLitGeneric
	["$basetexture"] 		= "phoenix_storms/wood", //models/debug/debugwhite
	["$vertexcolor"] 		= 1,
	["$phong"] 				= 1,
	["$phongexponent"] 		= 20,
	["$phongboost"] 		= 2,
	["$phongfresnelranges"] = "0.5 0.8 1",
} )

//local Offset = 20  //Downwards offset of large center beam
local RailOffset = 25 //Distance track beams away from eachother

TRACK.CylinderRadius = 10 //Radius of the circular track beams
TRACK.BeamWidth = 8.5 //The width of the wooden supports
TRACK.CylinderPointCount = 4 //How many points make the cylinder of the track mesh
TRACK.HorizontalSpacing = 1 //how far apart vertical beams should be spaced
TRACK.VerticalSpacing = 80 //how far apart horizontal beams should be spaced
TRACK.SupportOverride = true  //Override track supports (we're making our own)

TRACK.ModelCount = 1 //Keep track of how many seperate models we've created
TRACK.FixedSplines = {}

local function GetAngleAtSpline( spline, controller )
	local AngVec = Vector( 0, 0, 0 )

	//Get the angles from the current spline to next spline
	if #controller.CatmullRom.Spline >= spline + 1 then		
		AngVec = controller.CatmullRom.Spline[spline] - controller.CatmullRom.Spline[spline + 1]
		AngVec:Normalize()
	else
		AngVec = controller.CatmullRom.Spline[spline] - controller.CatmullRom.PointsList[ #controller.CatmullRom.PointsList ]
		AngVec:Normalize()
	end

	return AngVec, AngVec:Angle()
end

local function GetLowestPosition( tbl )
	local height = math.huge
	local heighest = -math.huge
	for k, v in pairs( tbl ) do
		if v.PosLeftBottom.z < height then height = v.PosLeftBottom.z end
		if v.Pos.z > heighest then heighest = v.Pos.z end
	end

	return height, heighest
end

local function BuildTraceWhitelist(segment, controller)
	//get our current physmesh
	local whitelist = {}
	for k, v in pairs( ents.FindByClass("coaster_physmesh")) do
		if v.Segment < segment - 1 || v.Segment > segment + 1 then table.insert(whitelist, v) end
	end

	local blacklist = {}
	for k, v in pairs(ents.GetAll()) do
		if !table.HasValue( whitelist, v ) then
			table.insert( blacklist, v )
		end
	end

	return blacklist
end

function TRACK:PassRails(controller)
	local Vertices = {} //Create an array that will hold an array of vertices (This is to split up the model)

	Cylinder.Start( self.CylinderRadius, self.CylinderPointCount ) //We're starting up making a beam of cylinders
	local LastAng = nil //Last angle so previous cylinder matches with the next cylinder

	//For every single spline segment 
	for i = 1, #controller.CatmullRom.Spline do
		//Some useful entities to be references
		local NexterSegment = controller.Nodes[ controller:GetSplineSegment(i) + 2]
		local NextSegment = controller.Nodes[controller:GetSplineSegment(i) + 1]
		local ThisSegment = controller.Nodes[ controller:GetSplineSegment(i) ]

		local AngVec2 = Vector( 0, 0, 0 )
		local AngVec, ang = GetAngleAtSpline( i, controller )

		if #controller.CatmullRom.Spline >= i + 2 then
			AngVec2 = controller.CatmullRom.Spline[i+1] - controller.CatmullRom.Spline[i+2]
			AngVec2:Normalize()
		else
			AngVec2 = AngVec
		end


		local ang2 = AngVec2:Angle()

		//Calculate the roll
		if IsValid( ThisSegment ) && IsValid( NextSegment ) then
			//Get the percent along this node
			local perc = controller:PercAlongNode( i )
			
			//Note all Lerps are negated. This is because the actual roll value from the gun is backwards.
			local Roll = -Lerp( perc, math.NormalizeAngle( ThisSegment:GetRoll() ),NextSegment:GetRoll())	
			if ThisSegment:RelativeRoll() then
				Roll = Roll - ( ang.p - 180 )
			end

			//Rotated around axis
			//This takes roll into account in the angle so far
			ang:RotateAroundAxis( AngVec, Roll ) 

			//Now do it for the segment just ahead of us
			local perc2 = controller:PercAlongNode( i + 1, true ) //We have to do a quickfix so the function can handle how to end the track
			local Roll2 = -Lerp( perc2, math.NormalizeAngle( ThisSegment:GetRoll() ), NextSegment:GetRoll() )
			if ThisSegment:RelativeRoll() then
				Roll2 = Roll2 - ( ang2.p - 180 )
			end
			ang2:RotateAroundAxis( AngVec2, Roll2 )
		end

		//If the current spline is not the very last one
		if i+1 <= #controller.CatmullRom.Spline then
			//Get the positions now so it isn't super mess in the code
			local posL = controller.CatmullRom.Spline[i] + ang:Right() * -RailOffset
			local posR = controller.CatmullRom.Spline[i] + ang:Right() * RailOffset
			local nPosL = controller.CatmullRom.Spline[i+1] + ang2:Right() * -RailOffset
			local nPosR = controller.CatmullRom.Spline[i+1] + ang2:Right() * RailOffset

			//Get the normal 
			local vec = controller.CatmullRom.Spline[i] - controller.CatmullRom.Spline[i+1]
			local vec2 = vec

			//if we are the second to last spline, get the normal
			if #controller.CatmullRom.Spline >= i+2 then
				vec2 = controller.CatmullRom.Spline[i+1] - controller.CatmullRom.Spline[i+2]
			end

			NewAng = vec:Angle()
			NewAng:RotateAroundAxis( vec:Angle():Right(), 90 )
			NewAng:RotateAroundAxis( vec:Angle():Up(), 270 )

			//only if LastAng is null do we set to it
			LastAng = LastAng or NewAng

			//Main center beam
			//Cylinder.AddBeam(controller.CatmullRom.Spline[i] + (ang:Up() * -Offset), LastAng, controller.CatmullRom.Spline[i+1] + (ang2:Up() * -Offset), NewAng, Radius )
			if i==1 then
				local FirstLeft = controller:GetPos() + ang:Right() * -RailOffset
				local FirstRight = controller:GetPos() + ang:Right() * RailOffset

				if controller:Looped() then
					FirstLeft = controller.CatmullRom.PointsList[2] + ang:Right() * -RailOffset
					FirstRight = controller.CatmullRom.PointsList[2] + ang:Right() * RailOffset
				end

				Cylinder.AddBeam( FirstLeft, LastAng, posL, NewAng, 4, ThisSegment:GetTrackColor() )
				Cylinder.AddBeam( FirstRight, LastAng, posR, NewAng, 4, ThisSegment:GetTrackColor() )
			end

			//Side rails
			Cylinder.AddBeam( posL, LastAng, nPosL, NewAng, 4, ThisSegment:GetTrackColor() )
			Cylinder.AddBeam( posR, LastAng, nPosR, NewAng, 4, ThisSegment:GetTrackColor() )

			if #Cylinder.Vertices > 50000 then// some arbitrary limit to split up the verts into seperate meshes. It's surprisingly easy to hit that limit

				Vertices[self.ModelCount] = Cylinder.Vertices
				self.ModelCount = self.ModelCount + 1
				print( self.ModelCount )

				Cylinder.Vertices = {}
				Cylinder.TriCount = 1
			end
			LastAng = NewAng
		end
	end	

	local verts = Cylinder.EndBeam()
	Vertices[self.ModelCount] = verts //Dump the remaining vertices into its own model

	return Vertices
end

function TRACK:PassVerticalSupports( controller )
	local WoodModels = {}
	local ModelCount = 1

	Cylinder.Start( self.CylinderRadius, self.CylinderPointCount ) //We're starting up making a beam of cylinders
	//For every single spline segment 
	for i = 1, #self.FixedSplines do
		ang = self.FixedSplines[i].Ang

		local posL = self.FixedSplines[i].Pos + ang:Right() * -RailOffset
		local posR = self.FixedSplines[i].Pos + ang:Right() * RailOffset
		self.FixedSplines[i].PosLeft = posL
		self.FixedSplines[i].PosRight = posR
		local traceL = util.TraceLine({start = posL, endpos = posL + Vector( 0, 0, -100000), filter = BuildTraceWhitelist(self.FixedSplines[i].Segment, controller) } )
		local traceR = util.TraceLine({start = posR, endpos = posR + Vector( 0, 0, -100000), filter = BuildTraceWhitelist(self.FixedSplines[i].Segment, controller) } )
		self.FixedSplines[i].PosLeftBottom = traceL.HitPos
		self.FixedSplines[i].PosRightBottom = traceR.HitPos

		local OffsetL = Vector( 0, 0, 10 )
		local OffsetR = Vector( 0, 0, 10 )

		if traceL.Entity:GetClass() == "coaster_physmesh" || traceR.Entity:GetClass() == "coaster_physmesh" then
			if traceL.HitPos.z > traceR.HitPos.z then
				OffsetL = Vector( traceL.HitPos.x, traceL.HitPos.y, math.Clamp(traceL.HitPos.z + 150, -1000000, self.FixedSplines[i].Pos.z ) )
				OffsetR = Vector( traceR.HitPos.x, traceR.HitPos.y, math.Clamp(traceR.HitPos.z + 150, -10000000, self.FixedSplines[i].Pos.z ) )
			else
				OffsetL = Vector( traceL.HitPos.x, traceL.HitPos.y, math.Clamp(traceL.HitPos.z + 150, -10000000, self.FixedSplines[i].Pos.z ) )
				OffsetR = Vector( traceR.HitPos.x, traceR.HitPos.y, math.Clamp(traceR.HitPos.z + 150, -1000000, self.FixedSplines[i].Pos.z ) )
			end

			self.FixedSplines[i].HitSelf = true
			self.FixedSplines[i].HitHeight = traceL.HitPos.z
		else
			OffsetL = traceL.HitPos - Vector( 0, 0, 10)
			OffsetR = traceR.HitPos - Vector( 0, 0, 10)

			self.FixedSplines[i].HitSelf = false
		end

		local angBeam = Angle( ang.p, ang.y, ang.r )
		angBeam:RotateAroundAxis( angBeam:Forward(), -90 )

		if math.random(1, 10 ) != 7 then
			Cylinder.AddBeamSquare( posL, ang, OffsetL, Angle( 0, ang.y, 0 ), self.BeamWidth )
		end
		if math.random(1, 10 ) != 7 then
			Cylinder.AddBeamSquare( posR, ang, OffsetR, Angle( 0, ang.y, 0 ), self.BeamWidth )
		end

		Cylinder.AddBeamSquare( posL, angBeam, posR, angBeam, 5 )

		if #Cylinder.Vertices > 50000 then //some arbitrary limit to split up the verts into seperate meshes. It's surprisingly easy to hit that limit

			WoodModels[ModelCount] = Cylinder.Vertices
			ModelCount = ModelCount + 1
			print( ModelCount )

			Cylinder.Vertices = {}
			Cylinder.TriCount = 1
		end

		local verts = Cylinder.EndBeam()
		WoodModels[ModelCount] = verts //Dump the remaining vertices into its own model
	end

	return WoodModels
end

function TRACK:GetValidHeight( i, lowestPos )

	if self.FixedSplines[i].HitSelf then
		if self.FixedSplines[i].HitHeight then
			return lowestPos - self.FixedSplines[i].HitHeight > 2 *self.VerticalSpacing
		end

		return true
	end

	if self.FixedSplines[i+1] && self.FixedSplines[i+1].HitHeight then
		return lowestPos - self.FixedSplines[i+1].HitHeight > 2 *self.VerticalSpacing
	end

	return true
end

function TRACK:PassHorizontalSupports( controller )
	Cylinder.Start( self.CylinderRadius, self.CylinderPointCount ) //We're starting up making a beam of cylinders
	local Models = {}
	local ModelCount = 1
	local lowestPos, heighestPos = GetLowestPosition(self.FixedSplines)

	local level = 1
	while lowestPos < heighestPos do
		lowestPos = lowestPos + self.VerticalSpacing
		level = level + 1

		for i = 1, #self.FixedSplines - 1 do
			if self.FixedSplines[i].Pos.z > lowestPos && self.FixedSplines[i].PosLeftBottom.z < lowestPos &&
				self.FixedSplines[i+1].Pos.z > lowestPos && self.FixedSplines[i+1].PosLeftBottom.z < lowestPos then
					
				if math.random(1, 5) != 5 && (self:GetValidHeight(i, lowestPos)) then 
					ang = self.FixedSplines[i].Ang
					ang2 = self.FixedSplines[i+1].Ang

					local angBeam = Angle( ang.p, ang.y, 0)
					angBeam:RotateAroundAxis( angBeam:Right(), -90 )

					local angBeam2 = Angle( ang2.p, ang2.y, 0 )
					angBeam2:RotateAroundAxis( angBeam:Right(), -90 )

					Cylinder.AddBeamSquare( Vector(self.FixedSplines[i].PosLeft.x, self.FixedSplines[i].PosLeft.y, lowestPos), angBeam, Vector(self.FixedSplines[i+1].PosLeft.x, self.FixedSplines[i+1].PosLeft.y, lowestPos), angBeam2, self.BeamWidth )
					Cylinder.AddBeamSquare( Vector(self.FixedSplines[i].PosRight.x, self.FixedSplines[i].PosRight.y, lowestPos), angBeam, Vector(self.FixedSplines[i+1].PosRight.x, self.FixedSplines[i+1].PosRight.y, lowestPos), angBeam2, self.BeamWidth )
				end 

				if #Cylinder.Vertices > 50000 then //some arbitrary limit to split up the verts into seperate meshes. It's surprisingly easy to hit that limit
					Models[ModelCount] = Cylinder.Vertices
					ModelCount = ModelCount + 1
					print( self.ModelCount )

					Cylinder.Vertices = {}
					Cylinder.TriCount = 1
				end
			end
		end
	end

	local verts = Cylinder.EndBeam()
	Models[ModelCount] = verts //Dump the remaining vertices into its own model

	return Models
end

function TRACK:CreateFixedPointTable( controller )
	self.FixedSplines = {}

	local CurSegment = 2
	local Percent = 0
	local Multiplier = 1
	local StrutVerts = {} //mmm yeah strut those verts
	local num = 1

	while CurSegment < #controller.CatmullRom.PointsList - 1 do
		local CurNode = controller.Nodes[CurSegment]
		local NextNode = controller.Nodes[CurSegment + 1]

		local Position = controller.CatmullRom:Point(CurSegment, Percent)

		local ang = controller:AngleAt(CurSegment, Percent)

		//Change the roll depending on the track
		local Roll = -Lerp( Percent, math.NormalizeAngle( CurNode:GetRoll() ), NextNode:GetRoll())	
		
		//Set the roll for the current track peice
		ang.r = Roll
		//ang:RotateAroundAxis( controller:AngleAt(CurSegment, Percent), Roll ) //BAM

		//Now... manage moving throughout the track evenly
		//Each spline has a certain multiplier so the cart travel at a constant speed throughout the track
		Multiplier = controller:GetMultiplier(CurSegment, Percent)

		//Move ourselves forward along the track
		Percent = Percent + ( Multiplier * self.HorizontalSpacing )

		//Manage moving between nodes
		if Percent > 1 then
			CurSegment = CurSegment + 1
			if CurSegment > #controller.Nodes - 2 then 			
				break
			end	
			Percent = 0
		end

		self.FixedSplines[num] = {}
		self.FixedSplines[num].Pos = Position 
		self.FixedSplines[num].Ang = ang
		self.FixedSplines[num].Roll = Roll 
		self.FixedSplines[num].Segment = CurSegment


		num = num + 1 //NEWSECTION
	end
end

function TRACK:Generate( controller )
	if !IsValid( controller ) || !controller:IsController() then return end
	self.ModelCount = 1

	local Models = {}
	local WoodModels = {}
	local Meshes = {}
	local WoodMeshes = {}

	self:CreateFixedPointTable( controller )

	table.Add( Models, self:PassRails( controller ) )

	table.Add( WoodModels, self:PassVerticalSupports( controller ) )
	table.Add( WoodModels, self:PassHorizontalSupports( controller ) )




	for i=1, #Models do
		if #Models[i] > 2 then
			Meshes[i] = Mesh()
			Meshes[i]:BuildFromTriangles( Models[i] )
		end
	end

	for i=1, #WoodModels do
		if #WoodModels[i] > 2 then
			WoodMeshes[i] = Mesh()
			WoodMeshes[i]:BuildFromTriangles( WoodModels[i] )
		end
	end

	//Create a new variable that will hold each section of the mesh
	local Sections = {}
	Sections[1] = Meshes //The siderails
	Sections[2] = WoodMeshes //Anything wooden

	return Sections
end

function TRACK:Draw( controller, Meshes )
	if !IsValid( controller ) || !controller:IsController() then return end

	if !Meshes || #Meshes < 1 then return end

	render.SetMaterial(self.Material)
	for k, v in pairs( Meshes[1] ) do
		if v then 
			v:Draw() 
		end
	end

	render.SetMaterial(self.MaterialWood)
	for k, v in pairs( Meshes[2] ) do
		if v then 
			v:Draw() 
		end
	end



end

trackmanager.Register( EnumNames.Tracks[COASTER_TRACK_WOOD], TRACK )