/*
	This is a render.Addbeam() equivalent for Triangle meshes, 
	and it returns the vertices in triangles to be put into a mesh manually.

	This is just to make creating meshes easier

	NOTE: This is not meant to run real-time. It returns the vertices for use with an IMesh/PhysicsFromMesh
*/
AddCSLuaFile("mesh_physics.lua")

module( "physmesh_builder", package.seeall )

Width = 15
Height = 10
Vertices = {}


function Start(new_width, new_height) //Width of triangle (left to right side of track), Height of the triangle (how far down to put the third vert)
	Vertices = {} //Table holding all of the current vertices in the correct format

	Width = new_width //Radius of the points
	Height  = new_height //Number of points

end

function AddBeam( Pos1, Ang1, Pos2, Ang2 )
	if Pos1 == nil || Ang1 == nil || Pos2 == nil || Ang2 == nil then 
		Error("FAILED TO CREATE MESH, NIL VALUE (" .. Pos1 .. ", " .. Ang1 .. ", " .. Pos2 .. ", " .. Ang2 .. ")")
		return
	end

	//Previous tri
	local F_Right = Pos1 + Ang1:Right() * Width
	local F_Bottom = Pos1 + Ang1:Up() * -Height
	local F_Left = Pos1 + Ang1:Right() * -Width

	//Next tri
	local B_Right = Pos2 + Ang2:Right() * Width
	local B_Bottom = Pos2 + Ang2:Up() * -Height
	local B_Left = Pos2 + Ang2:Right() * -Width

	local NormLeft = F_Bottom - F_Left
	NormLeft:Normalize()
	local NormRight = F_Bottom - F_Right
	NormRight:Normalize()


	local NormTop = Ang1:Up()

	//Triangulate that shit
	local Verts = {}

	//Top Quad

	Verts[1] = {
		pos = F_Right,
		u = 1,
		v = 0,
		normal = NormTop
	}
	Verts[2] = {
		pos = B_Right,
		u = 0,
		v = 0,
		normal = NormTop
	}
	Verts[3] = {
		pos = B_Left,
		u = 0,
		v = 1,
		normal = NormTop
	}


	Verts[4] = {
		pos = B_Left,
		u = 0,
		v = 1,
		normal = NormTop
	}
	Verts[5] = {
		pos = F_Left,
		u = 1,
		v = 1,
		normal = NormTop
	}
	Verts[6] = {
		pos = F_Right,
		u = 1,
		v = 0,
		normal = NormTop
	}

	//Left Quad
	Verts[9] = {
		pos = F_Bottom,
		u = 1,
		v = 0,
		normal = NormLeft
	}
	Verts[8] = {
		pos = B_Bottom,
		u = 0,
		v = 0,
		normal = NormLeft
	}
	Verts[7] = {
		pos = B_Left,
		u = 0,
		v = 1,
		normal = NormLeft
	}

	Verts[12] = {
		pos = B_Left,
		u = 0,
		v = 1,
		normal = NormLeft
	}
	Verts[11] = {
		pos = F_Left,
		u = 1,
		v = 1,
		normal = NormLeft
	}
	Verts[10] = {
		pos = F_Bottom,
		u = 1,
		v = 0,
		normal = NormLeft
	}

	//Right Quad
	Verts[15] = {
		pos = F_Bottom,
		u = 1,
		v = 0,
		normal = NormRight
	}
	Verts[14] = {
		pos = F_Right,
		u = 0,
		v = 0,
		normal = NormRight
	}
	Verts[13] = {
		pos = B_Right,
		u = 0,
		v = 1,
		normal = NormRight
	}

	Verts[18] = {
		pos = B_Right,
		u = 0,
		v = 1,
		normal = NormRight
	}
	Verts[17] = {
		pos = B_Bottom,
		u = 1,
		v = 1,
		normal = NormRight
	}
	Verts[16] = {
		pos = F_Bottom,
		u = 1,
		v = 0,
		normal = NormRight
	}
	
	table.Add(Vertices, Verts) //Add these new verts to the table

end


function EndBeam()
	return Vertices
end