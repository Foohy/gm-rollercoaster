include("autorun/sh_enums.lua")

local TRACK = TRACK && TRACK:Create()
if !TRACK then return end

TRACK.Name = "Wooden Track"
TRACK.Description = "A wooden track"
TRACK.PhysWidth = 50 //How wide the physics mesh should be
TRACK.SupportOverride = true  //Override track supports (we're making our own)

trackmanager.Register( EnumNames.Tracks[COASTER_TRACK_WOOD], TRACK )

if !CLIENT then return end

TRACK.MaterialMetal = Material("coaster/track_wooden_metalrails")
TRACK.MaterialWood = Material("coaster/track_wooden_woodbeams")
TRACK.MaterialWoodNocull = CreateMaterial( "CoasterWoodRailMaterialBeam", "UnlitGeneric", { //VertexLitGeneric
	["$basetexture"] 		= "coaster/wood", //models/debug/debugwhite
	["$vertexcolor"] 		= 1,
	["$nocull"]				= 1, } )

local RailOffset = 25 //Distance track beams away from eachother
TRACK.WoodRailWidth = 25 //Width of the wood rails

TRACK.CylinderRadius = 10 //Radius of the circular track beams
TRACK.BeamWidth = 8.5 //The width of the wooden supports
TRACK.CylinderPointCount = 4 //How many points make the cylinder of the track mesh
TRACK.HorizontalSpacing = 0.8 //how far apart vertical beams should be spaced
TRACK.VerticalSpacing = 80 //how far apart horizontal beams should be spaced
TRACK.InnerStrutsNum = 2 //how densely the inner struts should be placed

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
		if !v.GetController  || !IsValid( v:GetController() ) || v:GetController():GetCoasterID() != controller:GetCoasterID() || v.Segment != segment then
			if v.Segment < segment - 1 || v.Segment > segment + 1 then 
				table.insert(whitelist, v) 
			end
		end
		
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

	self.Cylinder = Cylinder:Create()
	
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
			//Rotated around axis
			//This takes roll into account in the angle so far
			ang:RotateAroundAxis( AngVec, Roll ) 

			//Now do it for the segment just ahead of us
			local perc2 = controller:PercAlongNode( i + 1, true ) //We have to do a quickfix so the function can handle how to end the track
			local Roll2 = -Lerp( perc2, math.NormalizeAngle( ThisSegment:GetRoll() ), NextSegment:GetRoll() )
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

			local color = ThisSegment:GetActualTrackColor()
			//Main center beam
			//Cylinder.AddBeam(controller.CatmullRom.Spline[i] + (ang:Up() * -Offset), LastAng, controller.CatmullRom.Spline[i+1] + (ang2:Up() * -Offset), NewAng, Radius )
			if i==1 then
				local FirstLeft = controller:GetPos() + ang:Right() * -RailOffset
				local FirstRight = controller:GetPos() + ang:Right() * RailOffset

				if controller:GetLooped() then
					FirstLeft = controller.CatmullRom.PointsList[2] + ang:Right() * -RailOffset
					FirstRight = controller.CatmullRom.PointsList[2] + ang:Right() * RailOffset
				end

				self.Cylinder:AddBeam( FirstLeft, LastAng, posL, NewAng, 4, color )
				self.Cylinder:AddBeam( FirstRight, LastAng, posR, NewAng, 4, color )

			end

			//Side rails
			self.Cylinder:AddBeam( posL, LastAng, nPosL, NewAng, 4, color)
			self.Cylinder:AddBeam( posR, LastAng, nPosR, NewAng, 4, color )

			if #self.Cylinder.Vertices > 50000 then// some arbitrary limit to split up the verts into seperate meshes. It's surprisingly easy to hit that limit

				Vertices[self.ModelCount] = self.Cylinder.Vertices
				self.ModelCount = self.ModelCount + 1
				print( self.ModelCount )

				self.Cylinder.Vertices = {}
				self.Cylinder.TriCount = 1
			end
			LastAng = NewAng

			self:CoroutineCheck( controller, 1, nil, i / (#controller.CatmullRom.Spline) )
		end
	end	

	local verts = self.Cylinder:EndBeam()
	Vertices[self.ModelCount] = verts //Dump the remaining vertices into its own model

	return Vertices
end

function TRACK:PassWoodRails(controller)
	local Vertices = {} //Create an array that will hold an array of vertices (This is to split up the model)

	self.Cylinder = Cylinder:Create( self.Cylinder )

	local LastPoints = {} //Last angle so previous cylinder matches with the next cylinder

	local leftV = 0
	local rightV = 0

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

			//Rotated around axis
			//This takes roll into account in the angle so far
			ang:RotateAroundAxis( AngVec, Roll ) 

			//Now do it for the segment just ahead of us
			local perc2 = controller:PercAlongNode( i + 1, true ) //We have to do a quickfix so the function can handle how to end the track
			local Roll2 = -Lerp( perc2, math.NormalizeAngle( ThisSegment:GetRoll() ), NextSegment:GetRoll() )
			ang2:RotateAroundAxis( AngVec2, Roll2 )
		end

		//If the current spline is not the very last one
		if i+1 <= #controller.CatmullRom.Spline then
			//Get the positions now so it isn't super mess in the code
			local posL = controller.CatmullRom.Spline[i] + ang:Right() * -RailOffset
			local OposL = posL + ang:Right() * -self.WoodRailWidth
			local nPosL = controller.CatmullRom.Spline[i+1] + ang2:Right() * -RailOffset
			local OnposL = nPosL + ang:Right() * -self.WoodRailWidth

			local posR = controller.CatmullRom.Spline[i] + ang:Right() * RailOffset
			local nPosR = controller.CatmullRom.Spline[i+1] + ang2:Right() * RailOffset
			local OposR = posR + ang:Right() * self.WoodRailWidth
			local OnposR = nPosR + ang:Right() * self.WoodRailWidth

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
			LastPoints.LeftIn = LastPoints.LeftIn or nPosL
			LastPoints.LeftOut = LastPoints.LeftOut or OnposL
			LastPoints.RightIn = LastPoints.RightIn or nPosR
			LastPoints.RightOut = LastPoints.RightOut or OnposR

			local color = ThisSegment:GetActualTrackColor()

			if i==1 then
				local FirstLeft = controller:GetPos() + ang:Right() * -RailOffset
				local FarLeft = FirstLeft + ang:Right() * -self.WoodRailWidth

				local FirstRight = controller:GetPos() + ang:Right() * RailOffset
				local FarRight = FirstRight + ang:Right() * self.WoodRailWidth

				if controller:GetLooped() then
					FirstLeft = controller.CatmullRom.PointsList[2] + ang:Right() * -RailOffset
					FarLeft = FirstLeft + ang:Right() * -self.WoodRailWidth

					FirstRight = controller.CatmullRom.PointsList[2] + ang:Right() * RailOffset
					FarRight = FirstRight + ang:Right() * self.WoodRailWidth
				end
				self.Cylinder.TotalV = leftV
				leftV = self.Cylinder:CreateSquare(FirstLeft, FarLeft, OnposL, nPosL, ang:Up(), color)

				self.Cylinder.TotalV = rightV
				rightV = self.Cylinder:CreateSquare(FirstRight, FarRight, OnposR, nPosR, ang:Up(), color )

			end


			//Side rails
			self.Cylinder.TotalV = leftV
			leftV = self.Cylinder:CreateSquare(LastPoints.LeftIn, LastPoints.LeftOut, OnposL, nPosL, ang:Up(), color )

			self.Cylinder.TotalV = rightV
			rightV = self.Cylinder:CreateSquare(LastPoints.RightIn, LastPoints.RightOut, OnposR, nPosR, ang:Up(), color )

			if #self.Cylinder.Vertices > 50000 then// some arbitrary limit to split up the verts into seperate meshes. It's surprisingly easy to hit that limit

				self.Vertices[self.ModelCount] = self.Cylinder.Vertices
				self.ModelCount = self.ModelCount + 1

				self.Cylinder.Vertices = {}
				self.Cylinder.TriCount = 1
			end
			LastPoints.LeftIn = nPosL
			LastPoints.LeftOut = OnposL
			LastPoints.RightIn = nPosR
			LastPoints.RightOut = OnposR

			self:CoroutineCheck( controller, 2, nil, i / (#controller.CatmullRom.Spline) )
		end
	end	

	local verts = self.Cylinder:EndBeam()
	Vertices[self.ModelCount] = verts //Dump the remaining vertices into its own model

	return Vertices
end

function TRACK:PassVerticalSupports( controller )
	local WoodModels = {}
	local ModelCount = 1

	self.Cylinder = Cylinder:Create(self.Cylinder )
	//For every single spline segment 
	for i = 1, #self.FixedSplines do
		ang = self.FixedSplines[i].Ang

		local posL = self.FixedSplines[i].Pos + ang:Right() * -(RailOffset + self.WoodRailWidth - (self.BeamWidth/2)) 
		local posR = self.FixedSplines[i].Pos + ang:Right() * (RailOffset + self.WoodRailWidth - (self.BeamWidth/2))
		self.FixedSplines[i].PosLeft = posL
		self.FixedSplines[i].PosRight = posR
		local traceL = util.TraceLine({start = posL, endpos = posL + Vector( 0, 0, -100000), filter = BuildTraceWhitelist(self.FixedSplines[i].Segment, controller) } )
		local traceR = util.TraceLine({start = posR, endpos = posR + Vector( 0, 0, -100000), filter = BuildTraceWhitelist(self.FixedSplines[i].Segment, controller) } )
		self.FixedSplines[i].PosLeftBottom = traceL.HitPos
		self.FixedSplines[i].PosRightBottom = traceR.HitPos

		local OffsetL = Vector( 0, 0, 10 )
		local OffsetR = Vector( 0, 0, 10 )

		if IsValid( traceL.Entity ) && IsValid(traceR.Entity) && ( traceL.Entity:GetClass() == "coaster_physmesh" || traceR.Entity:GetClass() == "coaster_physmesh" ) then
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

		self.Cylinder:AddBeamSquare( posL - Vector( 0, 0, 2), ang, OffsetL, Angle( 0, ang.y, 0 ), self.BeamWidth )
		self.Cylinder:AddBeamSquare( posR - Vector( 0, 0, 2), ang, OffsetR, Angle( 0, ang.y, 0 ), self.BeamWidth )

		for n=1, self.InnerStrutsNum + 1 do 
			if !self.FixedSplines[i].SubItems[n] then continue end
			
			self.Cylinder:AddBeamSquare( self.FixedSplines[i].SubItems[n].Pos + ang:Right() * -(RailOffset + self.WoodRailWidth - (self.BeamWidth/2)) - Vector( 0, 0, self.CylinderRadius), 
				angBeam, 
				self.FixedSplines[i].SubItems[n].Pos + ang:Right() * (RailOffset + self.WoodRailWidth - (self.BeamWidth/2)) - Vector( 0, 0, self.CylinderRadius), 
				angBeam, 
				5 
			)
		end
		
		if #self.Cylinder.Vertices > 50000 then //some arbitrary limit to split up the verts into seperate meshes. It's surprisingly easy to hit that limit

			WoodModels[ModelCount] = self.Cylinder.Vertices
			ModelCount = ModelCount + 1

			self.Cylinder.Vertices = {}
			self.Cylinder.TriCount = 1
		end

		self:CoroutineCheck( controller, 3, nil, i / (#self.FixedSplines ) )

		local verts = self.Cylinder:EndBeam()
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
	self.Cylinder = Cylinder:Create( self.Cylinder )

	local Models = {}
	local ModelCount = 1
	local lowestPos, heighestPos = GetLowestPosition(self.FixedSplines)

	local level = 1
	while lowestPos < heighestPos do
		lowestPos = lowestPos + self.VerticalSpacing
		level = level + 1

		for i = 1, #self.FixedSplines - 1 do
			if self.FixedSplines[i].Pos.z - self.BeamWidth > lowestPos && self.FixedSplines[i].PosLeftBottom.z < lowestPos &&
				self.FixedSplines[i+1].Pos.z - self.BeamWidth > lowestPos && self.FixedSplines[i+1].PosLeftBottom.z < lowestPos then
					
				if (self:GetValidHeight(i, lowestPos)) then 
					ang = self.FixedSplines[i].Ang
					ang2 = self.FixedSplines[i+1].Ang

					local angBeam = Angle( 0, ang.y, 0)
					angBeam:RotateAroundAxis( angBeam:Right(), -90 )

					local angBeam2 = Angle( 0, ang2.y, 0 )
					angBeam2:RotateAroundAxis( angBeam:Right(), -90 )

					self.Cylinder:AddBeamSquare( Vector(self.FixedSplines[i].PosLeft.x, self.FixedSplines[i].PosLeft.y, lowestPos), angBeam, Vector(self.FixedSplines[i+1].PosLeft.x, self.FixedSplines[i+1].PosLeft.y, lowestPos), angBeam2, self.BeamWidth )
					self.Cylinder:AddBeamSquare( Vector(self.FixedSplines[i].PosRight.x, self.FixedSplines[i].PosRight.y, lowestPos), angBeam, Vector(self.FixedSplines[i+1].PosRight.x, self.FixedSplines[i+1].PosRight.y, lowestPos), angBeam2, self.BeamWidth )
				end 

				if #self.Cylinder.Vertices > 50000 then //some arbitrary limit to split up the verts into seperate meshes. It's surprisingly easy to hit that limit
					Models[ModelCount] = self.Cylinder.Vertices
					ModelCount = ModelCount + 1

					self.Cylinder.Vertices = {}
					self.Cylinder.TriCount = 1
				end
			end
		end

		self:CoroutineCheck( controller, 4, nil, lowestPos / (heighestPos ) )
	end

	local verts = self.Cylinder:EndBeam()
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
	local sub = 1

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
		Percent = Percent + ( Multiplier * self.HorizontalSpacing / self.InnerStrutsNum )

		//Manage moving between nodes
		if Percent > 1 then
			CurSegment = CurSegment + 1
			if CurSegment > #controller.Nodes - 2 then 			
				break
			end	
			Percent = 0
		end

		if !self.FixedSplines[num] then self.FixedSplines[num] = {} end
		if !self.FixedSplines[num].SubItems then self.FixedSplines[num].SubItems = {} end

		self.FixedSplines[num].SubItems[sub] = {}
		self.FixedSplines[num].SubItems[sub].Pos = Position 
		self.FixedSplines[num].SubItems[sub].Ang = ang
		self.FixedSplines[num].SubItems[sub].Roll = Roll 
		self.FixedSplines[num].SubItems[sub].Segment = CurSegment

		if sub == 1 then
			self.FixedSplines[num].Pos = Position 
			self.FixedSplines[num].Ang = ang
			self.FixedSplines[num].Roll = Roll 
			self.FixedSplines[num].Segment = CurSegment
		end

		if sub > self.InnerStrutsNum then
			num = num + 1 //NEWSECTION
			sub = 0
		end

		sub = sub + 1
	end

	//PrintTable( self.FixedSplines )
end

function TRACK:Generate( controller )
	if !IsValid( controller ) || !controller:GetIsController() then return end
	self.ModelCount = 1

	local Models = {}
	local WoodModels = {}
	local WoodRailModels = {}
	local Meshes = {}
	local WoodMeshes = {}
	local WoodRailMeshes = {}

	self:CreateFixedPointTable( controller )

	table.Add( Models, self:PassRails( controller ) )
	table.Add( WoodRailModels, self:PassWoodRails(controller))

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

	for i=1, #WoodRailModels do
		if #WoodRailModels[i] > 2 then
			WoodRailMeshes[i] = Mesh()
			WoodRailMeshes[i]:BuildFromTriangles( WoodRailModels[i] )
		end
	end

	//Create a new variable that will hold each section of the mesh
	local Sections = {}
	Sections[1] = Meshes //The siderails
	Sections[2] = WoodMeshes //Anything wooden
	Sections[3] = WoodRailMeshes //the wooden walky bit of the siderails

	self:CoroutineCheck( controller, 5, Sections )
end

function TRACK:Draw()

	-- Metal siderails
	render.SetMaterial(self.MaterialMetal)
	self:DrawSection( 1 )

	-- Wood beams/supports
	render.SetMaterial(self.MaterialWood)
	self:DrawSection( 2 )

	-- The flat 'walkable' area that is visible from both sides
	render.SetMaterial( self.MaterialWoodNocull )
	self:DrawSection( 3 )

end

