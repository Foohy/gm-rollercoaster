ENT.Type 			= "anim"
ENT.Base 			= "base_anim"
ENT.PrintName		= "Rollercoaster cart"
ENT.Author			= "Foohy"

ENT.Spawnable		= false
ENT.AdminSpawnable	= false

ENT.Model			= Model( "models/XQM/coastertrain2seat.mdl" )

function ENT:SetupDataTables()
	self:DTVar("Int", 0, "CurrentNode")
end

function ENT:SetCurrentNode(node)
	self.dt.CurrentNode = node:EntIndex()
end

function ENT:GetCurrentNode()
	return Entity( self.dt.CurrentNode )
end