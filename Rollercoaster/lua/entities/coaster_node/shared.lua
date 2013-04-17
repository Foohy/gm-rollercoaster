ENT.Type 			= "anim"
ENT.Base 			= "base_anim"
ENT.PrintName		= "Rollercoaster Node"
ENT.Author			= "Foohy"
ENT.Information		= "A node for a rollercoaster"
ENT.Category		= "Foohy"

ENT.Spawnable		= false
ENT.AdminSpawnable	= false

ENT.Material 		= "hunter/myplastic"

function ENT:SetupDataTables()
	self:DTVar("Bool", 0, "IsController")
	self:DTVar("Bool", 1, "RelativeRoll")
	self:DTVar("Bool", 2, "Looped")
	self:DTVar("Entity", 0, "NextNode")
	self:DTVar("Entity", 1, "Controller")
	self:DTVar("Int", 0, "Type")
	self:DTVar("Int", 1, "TrackType")
	self:DTVar("Int", 2, "Order") -- Backwards compatability 
	self:DTVar("Int", 3, "NumCoasterNodes") -- Backwards compatability
	self:DTVar("Float", 0, "Roll")
	self:DTVar("Vector", 0, "TrackColor")
	self:DTVar("Vector", 1, "SupportColor")
	self:DTVar("String", 0, "CoasterID") --The string is STEAMID_ID (ex: STEAM_0:1:18712009_3 )
end

-- The clients should always know about the nodes
function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end