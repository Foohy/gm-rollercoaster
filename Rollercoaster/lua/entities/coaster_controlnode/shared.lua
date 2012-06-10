ENT.Type 		= "anim"
ENT.Base 		= "base_anim"
ENT.PrintName		= "BEZIER TEST 2"
ENT.Author		= "Foohy"
ENT.Information		= "Spawns a node for a rollercoaster"
ENT.Category		= "Foohy"

ENT.Spawnable		= false
ENT.AdminSpawnable	= false

ENT.Model			= Model( "models/Combine_Helicopter/helicopter_bomb01.mdl" )


function ENT:SetupDataTables()
	self:DTVar("Entity", 0, "MainNode")
end

function ENT:SetMainNode(node)
	self.dt.MainNode = node
end

function ENT:GetMainNode()
	return self.dt.MainNode 
end