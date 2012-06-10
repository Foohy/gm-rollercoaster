ENT.Type 		= "anim"
ENT.Base 		= "base_anim"
ENT.PrintName		= "BEZIER TEST"
ENT.Author		= "Foohy"
ENT.Information		= "Spawns a node for a rollercoaster"
ENT.Category		= "Foohy"

ENT.Spawnable		= false
ENT.AdminSpawnable	= true

ENT.Model			= Model( "models/Combine_Helicopter/helicopter_bomb01.mdl" )

function ENT:SetupDataTables()
	self:DTVar("Bool", 0, "IsController")
	self:DTVar("Bool", 1, "Chained")
	self:DTVar("Int", 0, "FirstNode")
	self:DTVar("Int", 1, "NextNode")
	self:DTVar("Float", 0, "Roll")
	self:DTVar("Vector", 0, "TrackColor")
	self:DTVar("Vector", 1, "SupportColor")
	self:DTVar("Vector", 2, "Control1")
	self:DTVar("Vector", 3, "Control2")
end

function ENT:SetController(bController)
	self.dt.IsController = bController
end

function ENT:IsController()
	return self.dt.IsController or false
end

function ENT:SetChains(bChained)
	self.dt.Chained = bChained
end

function ENT:HasChains()
	return self.dt.Chained or false
end

function ENT:SetFirstNode(node)
	self.dt.FirstNode = node:EntIndex()
end

function ENT:GetFirstNode()
	return Entity(self.dt.FirstNode)
end

function ENT:SetNextNode(node)
	self.dt.NextNode = node:EntIndex()
end

function ENT:GetNextNode()
	return Entity(self.dt.NextNode)
end

function ENT:SetRoll(roll) //Not to be confused with CLuaParticle's SetRoll()
	self.dt.Roll = roll
end

function ENT:GetRoll() //Not to be confused with CLuaParticle's GetRoll()
	return self.dt.Roll or 0
end

function ENT:SetControls( vec1, vec2 )
	self.dt.Control1 = vec1
	self.dt.Control2 = vec2
end

function ENT:GetControls()
	return self.dt.Control1 or Vector( 0, 0, 0 ), self.dt.Control2 or Vector( 0, 0, 0)
end
