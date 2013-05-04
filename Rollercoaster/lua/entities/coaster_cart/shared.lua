ENT.Type 			= "anim"
ENT.Base 			= "base_anim"
ENT.PrintName		= "Rollercoaster cart"
ENT.Author			= "Foohy"

ENT.Spawnable		= false
ENT.AdminSpawnable	= false

ENT.Model			= Model( "models/XQM/coastertrain2seat.mdl" )

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "CurrentNode")
end