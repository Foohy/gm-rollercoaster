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

	//Triangulate that shit
	local Verts = {}
	
	//Front triangle
	Verts[1] = {
		pos = F_Right,
	}
	Verts[2] = {
		pos = F_Bottom,
	}
	Verts[3] = {
		pos = F_Left,
	}

	//Back triangle
	Verts[4] = {
		pos = B_Left,
	}
	Verts[5] = {
		pos = B_Bottom,
	}
	Verts[6] = {
		pos = B_Right,
	}

	//Top Quad
	Verts[7] = {
		pos = B_Left,
	}
	Verts[8] = {
		pos = B_Right,
	}
	Verts[9] = {
		pos = F_Right,
	}

	Verts[10] = {
		pos = F_Right,
	}
	Verts[11] = {
		pos = F_Left,
	}
	Verts[12] = {
		pos = B_Left,
	}

	//Left Quad
	Verts[13] = {
		pos = F_Bottom,
	}
	Verts[14] = {
		pos = B_Bottom,
	}
	Verts[15] = {
		pos = B_Left,
	}

	Verts[16] = {
		pos = B_Left,
	}
	Verts[17] = {
		pos = F_Left,
	}
	Verts[18] = {
		pos = F_Bottom,
	}

	//Right Quad
	Verts[19] = {
		pos = F_Bottom,
	}
	Verts[20] = {
		pos = F_Right,
	}
	Verts[21] = {
		pos = B_Right,
	}

	Verts[22] = {
		pos = B_Right,
	}
	Verts[23] = {
		pos = B_Bottom,
	}
	Verts[24] = {
		pos = F_Bottom,
	}
	
	table.Add(Vertices, Verts) //Add these new verts to the table

end

function EndBeam()
	return Vertices
end