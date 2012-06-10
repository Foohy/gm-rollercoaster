ENT.Type 		= "anim"
ENT.Base 		= "base_anim"
ENT.PrintName		= "Roller coaster Node"
ENT.Author		= "Foohy"
ENT.Information		= "Spawns a node for a rollercoaster"
ENT.Category		= "Foohy"

ENT.Spawnable		= false
ENT.AdminSpawnable	= false

ENT.Model			= Model( "models/Combine_Helicopter/helicopter_bomb01.mdl" )

function ENT:SetupDataTables()
	self:DTVar("Bool", 0, "IsController")
	self:DTVar("Bool", 1, "Chained")
	self:DTVar("Int", 0, "FirstNode")
	self:DTVar("Int", 1, "NextNode")
	self:DTVar("Float", 0, "Roll")
	self:DTVar("Vector", 0, "TrackColor")
	self:DTVar("Vector", 1, "SupportColor")
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

function ENT:SetTrackColor(r,g,b) 
	self.dt.TrackColor = Vector( r, g, b )
end

function ENT:GetTrackColor() 
	return self.dt.TrackColor.x, self.dt.TrackColor.y, self.dt.TrackColor.z 
end

function ENT:SetSupportColor(r,g,b) 
	self.dt.SupportColor = Vector( r, g, b )
end

function ENT:GetSupportColor() 
	return self.dt.SupportColor.x, self.dt.SupportColor.y, self.dt.SupportColor.z 
end