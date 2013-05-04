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
	self:NetworkVar("Bool", 0, "IsController")
	self:NetworkVar("Bool", 2, "Looped")
	self:NetworkVar("Entity", 0, "NextNode")
	self:NetworkVar("Entity", 1, "Controller")
	self:NetworkVar("Int", 0, "Type")
	self:NetworkVar("Int", 1, "TrackType")
	self:NetworkVar("Float", 0, "Roll")
	self:NetworkVar("Vector", 0, "TrackColor")
	self:NetworkVar("String", 0, "CoasterID") --The string is STEAMID_ID (ex: STEAM_0:1:18712009_3 )

	self:DTVar("Int", 2, "Order") -- Backwards compatability 
	self:DTVar("Int", 3, "NumCoasterNodes") -- Backwards compatability
end

-- The clients should always know about the nodes
function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end