/*
	This is a render.Addbeam() equivalent for cylinder meshes, 
	and it returns the vertices in triangles to be put into a mesh manually.

	This is just to make creating meshes easier

	NOTE: This is not meant to run real-time. It returns the vertices for use with an IMesh
*/
AddCSLuaFile("mesh_beams.lua")
Cylinder = {}


function Cylinder:Create(obj)
	local obj = obj or {}
	obj.__index = Cylinder 
	setmetatable( obj, obj )

	obj.Vertices = {} //Table holding all of the current vertices in the correct format

	obj.CurVerts = {} //Holding the verts at the start of a cylinder
	obj.NextVerts = {} //holding all the verts at the end of a cylinder

	obj.Radius = 5 //Radius of the points
	obj.Count  = 5 //Number of points

	obj.TriCount = 1 //Number of current vertices
	obj.TotalU = 0
	obj.TotalV = 0

	obj.LastV = 0


	return obj
end

function Cylinder:CreateSquare( P1, P2, P3, P4, Normal, TrackColor )	//BACKRIGHT, BACKLEFT, FRONT LEFT, FRONT RIGHT
	local u =  ( P1:Distance( P2 ) / 200 ) //+ Cylinder.TotalU
	local v = ( P2:Distance( P3 ) / 200 ) + self.TotalV

	//Create some variables for proper lightmapped color
	local colVec = Vector( 0, 0, 0 )

	//And the user selected color too
	local SelectedColor = Vector( 1, 1, 1 )
	if TrackColor then
		SelectedColor = Vector( TrackColor.r / 255, TrackColor.g / 255, TrackColor.b / 255 ) 
	end
	
	//Create the 6 verts that make up a single quad
	colVec = render.ComputeLighting( P1, Normal )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(P1, Normal)
	self.Vertices[self.TriCount] = { 
		pos = P1, 
		normal = Normal, 
		u = u,
		v = self.TotalV,
		color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
	}
	self.TriCount = self.TriCount + 1

	colVec = render.ComputeLighting( P2, Normal )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(P2, Normal)
	self.Vertices[self.TriCount] = { 
		pos = P2, 
		normal = Normal, 
		u = 0,
		v = self.TotalV,
		color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
	}
	self.TriCount = self.TriCount + 1

	colVec = render.ComputeLighting( P3, Normal )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(P3, Normal )
	self.Vertices[self.TriCount] = { 
		pos = P3, 
		normal = Normal, 
		u = 0,
		v = v,
		color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
	}
	self.TriCount = self.TriCount + 1
	
	


	//Second tri
	colVec = render.ComputeLighting( P3, Normal )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(P3, Normal )
	self.Vertices[self.TriCount] = { 
		pos = P3, 
		normal = Normal, 
		u = 0,
		v = v,
		color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
	}
	self.TriCount = self.TriCount + 1

	colVec = render.ComputeLighting( P4, Normal )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(P4, Normal )
	self.Vertices[self.TriCount] = { 
		pos = P4, 
		normal = Normal, 
		u = u,
		v = v,
		color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
	}
	self.TriCount = self.TriCount + 1

	colVec = render.ComputeLighting( P1, Normal)
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(P1, Normal )
	self.Vertices[self.TriCount] = { 
		pos = P1, 
		normal = Normal, 
		u = u,
		v = self.TotalV,
		color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
	}
	self.TriCount = self.TriCount + 1

	return v
	
end
/*
function AdvanceTextureCoordinates()
	Cylinder.TotalV = Cylinder.TotalV + Cylinder.LastV
end
*/

local function Point( Position, Ang, Offset, Corner )
	local ang = Angle(Ang.p,Ang.y,Ang.r)
	ang:RotateAroundAxis(ang:Up(), (90 * (Corner-1)) + 45 )
	return Position + (ang:Right() * Offset)
end

local function Point2( Position, Ang, Offset, Corner )
	local ang = Angle(Ang.p,Ang.y,Ang.r)
	ang:RotateAroundAxis(ang:Forward(), (-90 * (Corner-1)) + 45 )
	return Position + (ang:Right() * Offset)
end 

function Cylinder:AddBeamSquare( Pos1, Ang1, Pos2, Ang2, Width, TrackColor )
	if Pos1 == nil || Ang1 == nil || Pos2 == nil || Ang2 == nil then 
		print("FAILED TO CREATE SQUARE BEAM, NIL VALUE")
		return
	end

	self.Radius = Width or self.Radius

	local offset = math.sqrt( 2 * math.pow(Width/2, 2) )

	//Calculate the positions
	local TopFrontLeft = Point(Pos1, Ang1, Width, 1 ) //Pos1 + Point( Vector( -offset, offset, 0), Ang1 ) // Vector( -offset, offset, 0)
	local TopFrontRight = Point(Pos1, Ang1, Width, 4 )//Pos1 + Point( Vector( offset, offset, 0), Ang1 ) //Vector( offset, offset, 0)
	local TopBackLeft = Point(Pos1, Ang1, Width, 2 )//Pos1 + Point( Vector( -offset, -offset, 0), Ang1 ) //Vector( -offset, -offset, 0)
	local TopBackRight = Point(Pos1, Ang1, Width, 3 )//Pos1 + Point( Vector( offset, -offset, 0), Ang1 ) //Vector( offset, -offset, 0)
 
	local BottomFrontLeft = Point(Pos2, Ang2, Width, 1 )//Pos2 + Vector( -offset, offset, 0)
	local BottomFrontRight = Point(Pos2, Ang2, Width, 4 )// Pos2 + Vector( offset, offset, 0)
	local BottomBackLeft = Point(Pos2, Ang2, Width, 2 )//Pos2 + Vector( -offset, -offset, 0)
	local BottomBackRight = Point(Pos2, Ang2, Width, 3 )//Pos2 + Vector( offset, -offset, 0)

	//Calculate normals
	local normtop = TopFrontLeft - BottomFrontLeft
	normtop:Normalize()
	local normLeft = TopFrontLeft - TopFrontRight
	normLeft:Normalize()
	local normFront = TopFrontLeft - TopBackLeft
	normFront:Normalize()

	//Top
	self:CreateSquare( TopBackRight, TopBackLeft, TopFrontLeft, TopFrontRight, normtop )

	//Sides
	self:CreateSquare( BottomBackLeft, BottomFrontLeft, TopFrontLeft, TopBackLeft, normLeft )
	self:CreateSquare( BottomBackRight, BottomBackLeft, TopBackLeft, TopBackRight, -normFront )
	self:CreateSquare( TopFrontRight, TopFrontLeft, BottomFrontLeft, BottomFrontRight, normFront )
	self:CreateSquare( BottomFrontRight, BottomBackRight, TopBackRight, TopFrontRight, -normLeft )

	//Bottom
	self:CreateSquare( BottomFrontRight, BottomFrontLeft, BottomBackLeft, BottomBackRight, -normtop ) //BottomBackRight, BottomBackLeft, BottomFrontLeft, BottomFrontRight 
end

function Cylinder:AddBeamSquareSimple( Pos1, Ang1, Pos2, Ang2, Width, TrackColor )
	if Pos1 == nil || Ang1 == nil || Pos2 == nil || Ang2 == nil then 
		print("FAILED TO CREATE SQUARE BEAM, NIL VALUE")
		return
	end

	self.Radius = Width or self.Radius

	//local offset = math.sqrt( 2 * math.pow(Width/2, 2) )

	//Calculate the positions
	local TopFrontLeft = Point2(Pos1, Ang1, Width, 1 ) //Pos1 + Point( Vector( -offset, offset, 0), Ang1 ) // Vector( -offset, offset, 0)
	local TopFrontRight = Point2(Pos1, Ang1, Width, 4 )//Pos1 + Point( Vector( offset, offset, 0), Ang1 ) //Vector( offset, offset, 0)
	local TopBackLeft = Point2(Pos1, Ang1, Width, 2 )//Pos1 + Point( Vector( -offset, -offset, 0), Ang1 ) //Vector( -offset, -offset, 0)
	local TopBackRight = Point2(Pos1, Ang1, Width, 3 )//Pos1 + Point( Vector( offset, -offset, 0), Ang1 ) //Vector( offset, -offset, 0)
 
	local BottomFrontLeft = Point2(Pos2, Ang2, Width, 1 )//Pos2 + Vector( -offset, offset, 0)
	local BottomFrontRight = Point2(Pos2, Ang2, Width, 4 )// Pos2 + Vector( offset, offset, 0)
	local BottomBackLeft = Point2(Pos2, Ang2, Width, 2 )//Pos2 + Vector( -offset, -offset, 0)
	local BottomBackRight = Point2(Pos2, Ang2, Width, 3 )//Pos2 + Vector( offset, -offset, 0)

	local normLeft = TopFrontLeft - TopFrontRight
	normLeft:Normalize()
	local normFront = TopFrontLeft - TopBackLeft
	normFront:Normalize()

	//Sides
	self:CreateSquare( BottomBackLeft, BottomFrontLeft, TopFrontLeft, TopBackLeft, normLeft, TrackColor )
	self:CreateSquare( BottomBackRight, BottomBackLeft, TopBackLeft, TopBackRight, -normFront, TrackColor )
	self:CreateSquare( TopFrontRight, TopFrontLeft, BottomFrontLeft, BottomFrontRight, normFront, TrackColor )
	self:CreateSquare( BottomFrontRight, BottomBackRight, TopBackRight, TopFrontRight, -normLeft, TrackColor )
end

function Cylinder:AddBeam( Pos1, Ang1, Pos2, Ang2, Radius, TrackColor )
	if Pos1 == nil || Ang1 == nil || Pos2 == nil || Ang2 == nil then 
		print("FAILED TO CREATE CYLINDER, NIL VALUE")
		return
	end
	self.Radius = Radius or self.Radius

	//Calculate the positions of the current Vertices
	for i=1, self.Count do
		local ang = Angle(Ang1.p,Ang1.y,Ang1.r) //Create a new instance of the angle so we don't modify the original (Is there a better way to do this?)
		self.CurVerts[i] = {}

		ang:RotateAroundAxis(ang:Right(), (360 / self.Count) * i )
		local pos = Pos1 + (ang:Up() * self.Radius)

		self.CurVerts[i].pos = pos
		self.CurVerts[i].norm = ang:Up()
	end

	//Calculate the positions of the next vertices
	for i=1, self.Count do
		local ang = Angle(Ang2.p,Ang2.y,Ang2.r) 
		self.NextVerts[i] = {}

		ang:RotateAroundAxis(ang:Right(), (360 / self.Count) * i )
		local pos = Pos2 + (ang:Up() * self.Radius)

		self.NextVerts[i].pos = pos
		self.NextVerts[i].norm = ang:Up()
	end

	//Variable to keep track of our triangle count
	local OldU  	= self.TotalU
	self.TotalU = self.TotalU + (self.CurVerts[1].pos:Distance( self.NextVerts[1].pos )) / 32//Get the distance so we can set the UV effectively


	local NewV      = self.TotalV


	//put them into proper triangle format
	for i=1, self.Count do
		//Set up our variables
		local CurLeft = self.CurVerts[i]
		local NextLeft = self.NextVerts[i]

		local CurRight = Vector(0)
		local NextRight = Vector(0)

		if (i+1) > self.Count then //Wrap around to 1
			CurRight = self.CurVerts[1]
			NextRight = self.NextVerts[1]
		else
			CurRight = self.CurVerts[i+1]
			NextRight = self.NextVerts[i+1]
		end

		//NewV = OldV + (i / Cylinder.Count)
		local OldV      = self.TotalV
		self.TotalV = self.TotalV + ( 1 / self.Count)

		//Create some variables for proper lightmapped color
		local colVec = Vector( 0, 0, 0 )

		//And the user selected color too
		local SelectedColor = Vector( 1, 1, 1 )
		if TrackColor then
			SelectedColor = Vector( TrackColor.r / 255, TrackColor.g / 255, TrackColor.b / 255 ) 
		end

		//Create the 6 verts that make up a single quad
		colVec = render.ComputeLighting( CurRight.pos, CurRight.norm )
		colVec = colVec + render.GetAmbientLightColor()
		colVec = colVec + render.ComputeDynamicLighting(CurRight.pos, CurRight.norm )
		self.Vertices[self.TriCount] = { 
			pos = CurRight.pos, 
			normal = CurRight.norm, 
			u = OldU,
			v = self.TotalV,
			color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
		}
		self.TriCount = self.TriCount + 1

		colVec = render.ComputeLighting( CurLeft.pos, CurLeft.norm )
		colVec = colVec + render.GetAmbientLightColor()
		colVec = colVec + render.ComputeDynamicLighting(CurLeft.pos, CurLeft.norm )
		self.Vertices[self.TriCount] = { 
			pos = CurLeft.pos, 
			normal = CurLeft.norm, 
			u = OldU,
			v = OldV,
			color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
		}
		self.TriCount = self.TriCount + 1

		colVec = render.ComputeLighting( NextLeft.pos, NextLeft.norm )
		colVec = colVec + render.GetAmbientLightColor()
		colVec = colVec + render.ComputeDynamicLighting(NextLeft.pos, NextLeft.norm )
		self.Vertices[self.TriCount] = { 
			pos = NextLeft.pos, 
			normal = NextLeft.norm, 
			u = self.TotalU,
			v = OldV,
			color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
		}
		self.TriCount = self.TriCount + 1

		//Second tri
		colVec = render.ComputeLighting( NextLeft.pos, NextLeft.norm )
		colVec = colVec + render.GetAmbientLightColor()
		colVec = colVec + render.ComputeDynamicLighting(NextLeft.pos, NextLeft.norm )
		self.Vertices[self.TriCount] = { 
			pos = NextLeft.pos, 
			normal = NextLeft.norm, 
			u = self.TotalU,
			v = OldV,
			color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
		}
		self.TriCount = self.TriCount + 1

		colVec = render.ComputeLighting( NextRight.pos, NextRight.norm )
		colVec = colVec + render.GetAmbientLightColor()
		colVec = colVec + render.ComputeDynamicLighting(NextRight.pos, NextRight.norm )
		self.Vertices[self.TriCount] = { 
			pos = NextRight.pos, 
			normal = NextRight.norm, 
			u = self.TotalU,
			v = self.TotalV,
			color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
		}
		self.TriCount = self.TriCount + 1

		colVec = render.ComputeLighting( CurRight.pos, CurRight.norm )
		colVec = colVec + render.GetAmbientLightColor()
		colVec = colVec + render.ComputeDynamicLighting(CurRight.pos, CurRight.norm )
		self.Vertices[self.TriCount] = { 
			pos = CurRight.pos, 
			normal = CurRight.norm, 
			u = OldU,
			v = self.TotalV,
			color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
		}
		self.TriCount = self.TriCount + 1

		OldV = NewV
		
	end
	self.TotalV = NewV
	//Cylinder.TotalU = 0
end

function Cylinder:EndBeam()
	return self.Vertices 
end